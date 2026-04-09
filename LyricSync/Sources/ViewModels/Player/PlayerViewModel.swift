import Foundation
import Observation

/// 앱 전체 단일 인스턴스로 사용되는 재생 ViewModel.
/// LyricSyncApp에서 @State로 생성하고 @Environment로 하위 뷰에 주입한다.
@MainActor
@Observable
final class PlayerViewModel {
    private(set) var currentSong: Song? = nil
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var lyricState: LyricState = .loading
    private(set) var errorMessage: String? = nil

    /// 슬라이더 드래그 상태. true이면 Timer 폴링 결과를 currentTime에 반영하지 않는다.
    private(set) var isDragging: Bool = false
    /// 슬라이더 UI 값. 드래그 중에 UI만 업데이트하고 실제 seek은 드래그 완료 시에만 수행한다.
    var sliderValue: TimeInterval = 0
    /// 사용자 수동 스크롤 상태. true이면 가사 자동 스크롤을 멈춘다.
    var isUserScrolling: Bool = false
    /// fullScreenCover 바인딩 상태.
    var showFullPlayer: Bool = false

    /// 현재 재생 시간 기준으로 활성 가사 줄 인덱스를 계산한다.
    var currentLyricIndex: Int? {
        guard case .synced(let lines) = lyricState else { return nil }
        return lines.indices.last(where: { lines[$0].timestamp <= currentTime })
    }

    private let musicPlayerService: any MusicPlayerServiceProtocol
    private let lyricService: any LyricServiceProtocol
    private var timer: Timer?
    private var userScrollTimer: Timer?

    init(
        musicPlayerService: any MusicPlayerServiceProtocol = MusicPlayerService(),
        lyricService: any LyricServiceProtocol = LyricService()
    ) {
        self.musicPlayerService = musicPlayerService
        self.lyricService = lyricService
    }

    /// deinit 대신 뷰의 onDisappear에서 호출하여 타이머를 정리한다.
    /// (Swift 6에서 @MainActor 클래스의 deinit은 nonisolated이므로 격리 프로퍼티에 접근 불가)
    func stopTimers() {
        timer?.invalidate()
        timer = nil
        userScrollTimer?.invalidate()
        userScrollTimer = nil
    }

    // MARK: - 재생 제어

    /// 지정한 곡을 재생한다. 가사 fetch는 비동기로 재생을 블록하지 않는다.
    func play(song: Song) async {
        errorMessage = nil
        currentSong = song
        duration = song.duration ?? 0
        lyricState = .loading
        isUserScrolling = false

        do {
            try await musicPlayerService.play(song: song)
            isPlaying = true
            sliderValue = 0
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
            isPlaying = false
        }

        // 가사 fetch는 재생과 병렬로 수행 (재생 블로킹 없음)
        Task {
            await fetchLyrics(song: song)
        }
    }

    /// 재생을 일시정지한다.
    func pause() async {
        await musicPlayerService.pause()
        isPlaying = false
        stopTimer()
    }

    /// 일시정지된 재생을 재개한다.
    func resume() async {
        do {
            try await musicPlayerService.resume()
            isPlaying = true
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 슬라이더 드래그를 시작한다. 드래그 중에는 Timer 폴링 결과를 반영하지 않는다.
    func startDragging() {
        isDragging = true
    }

    /// 슬라이더 드래그를 완료하고 지정한 시간으로 seek한다.
    func stopDragging(to time: TimeInterval) async {
        await musicPlayerService.seek(to: time)
        isDragging = false
        currentTime = time
        sliderValue = time
    }

    /// 지정한 시간으로 재생 위치를 이동한다.
    func seek(to time: TimeInterval) async {
        await musicPlayerService.seek(to: time)
        isDragging = false
        currentTime = time
        sliderValue = time
    }

    // MARK: - 사용자 스크롤 제어

    /// 사용자가 가사 영역을 수동 스크롤하기 시작했을 때 호출한다.
    func onUserScrollBegan() {
        isUserScrolling = true
        userScrollTimer?.invalidate()
        userScrollTimer = nil
    }

    /// 사용자가 가사 영역 스크롤을 마쳤을 때 호출한다. 5초 후 자동 스크롤을 재개한다.
    func onUserScrollEnded() {
        userScrollTimer?.invalidate()
        userScrollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isUserScrolling = false
                self?.userScrollTimer = nil
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollPlaybackTime()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func pollPlaybackTime() async {
        guard !isDragging else { return }
        let time = await musicPlayerService.playbackTime
        currentTime = time
        sliderValue = time

        // 재생 상태도 동기화
        let status = await musicPlayerService.playbackStatus
        isPlaying = status == .playing
    }

    // MARK: - 가사 Fetch

    private func fetchLyrics(song: Song) async {
        let state = await lyricService.fetchLyrics(
            artist: song.artistName,
            track: song.title,
            duration: song.duration
        )
        lyricState = state
    }
}
