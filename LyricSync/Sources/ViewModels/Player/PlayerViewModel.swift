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

    /// 번역된 가사 라인. Supabase에서 번역이 있을 때만 non-nil.
    private(set) var translatedLines: [LyricLine]? = nil

    /// 번역 표시 모드. UserDefaults에 저장되어 앱 재시작 후에도 유지.
    var translationMode: TranslationMode {
        didSet {
            UserDefaults.standard.set(translationMode.rawValue, forKey: "translationMode")
        }
    }

    /// 가림 모드에서 공개된 줄 인덱스. 곡 변경/풀플레이어 열기 시 리셋.
    var revealedLineIndices: Set<Int> = []

    /// 번역 가사가 있는지 여부. UI에서 모드 토글 표시 여부를 결정한다.
    var hasTranslation: Bool { translatedLines != nil }

    /// 슬라이더 드래그 상태.
    private(set) var isDragging: Bool = false
    /// 슬라이더 UI 값.
    var sliderValue: TimeInterval = 0
    /// 사용자 수동 스크롤 상태.
    var isUserScrolling: Bool = false
    /// fullScreenCover 바인딩 상태.
    var showFullPlayer: Bool = false {
        didSet {
            if showFullPlayer {
                revealedLineIndices = []
            }
        }
    }

    /// 현재 재생 시간 기준으로 활성 가사 줄 인덱스를 계산한다.
    var currentLyricIndex: Int? {
        guard case .synced(let lines) = lyricState else { return nil }
        return lines.indices.last(where: { lines[$0].timestamp <= currentTime })
    }

    private let musicPlayerService: any MusicPlayerServiceProtocol
    private let lyricService: any LyricServiceProtocol
    private let translatedLyricService: any TranslatedLyricServiceProtocol
    private var timer: Timer?
    private var userScrollTimer: Timer?

    init(
        musicPlayerService: any MusicPlayerServiceProtocol = MusicPlayerService(),
        lyricService: any LyricServiceProtocol = LyricService(),
        translatedLyricService: any TranslatedLyricServiceProtocol = TranslatedLyricService()
    ) {
        self.musicPlayerService = musicPlayerService
        self.lyricService = lyricService
        self.translatedLyricService = translatedLyricService

        let savedMode = UserDefaults.standard.string(forKey: "translationMode")
        self.translationMode = TranslationMode(rawValue: savedMode ?? "") ?? .simultaneous
    }

    /// deinit 대신 뷰의 onDisappear에서 호출하여 타이머를 정리한다.
    func stopTimers() {
        timer?.invalidate()
        timer = nil
        userScrollTimer?.invalidate()
        userScrollTimer = nil
    }

    // MARK: - 가림 모드 줄 토글

    /// 가림 모드에서 특정 줄의 번역 공개를 토글한다.
    func toggleReveal(at index: Int) {
        if revealedLineIndices.contains(index) {
            revealedLineIndices.remove(index)
        } else {
            revealedLineIndices.insert(index)
        }
    }

    // MARK: - 재생 제어

    /// 지정한 곡을 재생한다. 가사 fetch는 비동기로 재생을 블록하지 않는다.
    func play(song: Song) async {
        errorMessage = nil
        currentSong = song
        duration = song.duration ?? 0
        lyricState = .loading
        translatedLines = nil
        revealedLineIndices = []
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

    /// 슬라이더 드래그를 시작한다.
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

    func onUserScrollBegan() {
        isUserScrolling = true
        userScrollTimer?.invalidate()
        userScrollTimer = nil
    }

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

        let status = await musicPlayerService.playbackStatus
        isPlaying = status == .playing
    }

    // MARK: - 가사 Fetch

    private func fetchLyrics(song: Song) async {
        // 1차: Supabase에서 원본 + 번역 조회
        let supabaseResult = await translatedLyricService.fetchLyrics(appleMusicID: song.id)

        if let originalLRC = supabaseResult.originalLRC {
            let originalLines = parseLRC(originalLRC)
            if !originalLines.isEmpty {
                lyricState = .synced(originalLines)

                if let translatedLRC = supabaseResult.translatedLRC {
                    let tLines = parseLRC(translatedLRC)
                    if tLines.count == originalLines.count {
                        translatedLines = tLines
                    }
                }
                return
            }
        }

        // 2차: lrclib.net fallback
        let state = await lyricService.fetchLyrics(
            artist: song.artistName,
            track: song.title,
            duration: song.duration
        )
        lyricState = state
        translatedLines = nil
    }

    /// LRC 형식 문자열을 파싱하여 LyricLine 배열로 반환한다.
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        let pattern = /\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/
        return lrc.components(separatedBy: "\n").compactMap { line in
            guard let match = line.firstMatch(of: pattern) else { return nil }
            let minutes = Double(match.1) ?? 0
            let seconds = Double(match.2) ?? 0
            let timestamp = minutes * 60 + seconds
            let text = String(match.3)
            return LyricLine(timestamp: timestamp, text: text)
        }
    }
}
