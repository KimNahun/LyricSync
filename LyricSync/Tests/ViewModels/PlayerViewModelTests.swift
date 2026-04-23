import Testing
import Foundation
@testable import LyricSync

@Suite("PlayerViewModel Tests")
@MainActor
struct PlayerViewModelTests {

    private func makeSUT(
        musicPlayer: MockMusicPlayerService = MockMusicPlayerService(),
        lyricService: MockLyricService = MockLyricService(),
        translatedLyricService: MockTranslatedLyricService = MockTranslatedLyricService()
    ) -> (PlayerViewModel, MockMusicPlayerService, MockLyricService, MockTranslatedLyricService) {
        // UserDefaults 오염 방지: 테스트마다 키 초기화
        UserDefaults.standard.removeObject(forKey: "translationMode")
        let vm = PlayerViewModel(
            musicPlayerService: musicPlayer,
            lyricService: lyricService,
            translatedLyricService: translatedLyricService
        )
        return (vm, musicPlayer, lyricService, translatedLyricService)
    }

    // MARK: - 초기 상태

    @Test("초기 상태 - 미재생, 에러 없음, 번역 없음")
    func initialState() {
        let (vm, _, _, _) = makeSUT()

        #expect(vm.currentSong == nil)
        #expect(vm.isPlaying == false)
        #expect(vm.currentTime == 0)
        #expect(vm.duration == 0)
        #expect(vm.errorMessage == nil)
        #expect(vm.hasTranslation == false)
        #expect(vm.isDragging == false)
        #expect(vm.currentLyricIndex == nil)
    }

    @Test("UserDefaults에 값이 없으면 translationMode은 simultaneous")
    func defaultTranslationMode() {
        let (vm, _, _, _) = makeSUT()
        #expect(vm.translationMode == .simultaneous)
    }

    // MARK: - play()

    @Test("play 성공 → isPlaying true, duration 설정, musicPlayer.play 호출")
    func playSuccess() async {
        let (vm, musicPlayer, _, _) = makeSUT()
        let song = Song.stub(duration: 200)

        await vm.play(song: song)

        #expect(vm.currentSong == song)
        #expect(vm.isPlaying == true)
        #expect(vm.duration == 200)
        #expect(vm.errorMessage == nil)

        let callCount = await musicPlayer.playCallCount
        #expect(callCount == 1)
    }

    @Test("play 실패 → isPlaying false, errorMessage 설정")
    func playFailure() async {
        let musicPlayer = MockMusicPlayerService()
        await musicPlayer.setShouldThrow(true)
        let (vm, _, _, _) = makeSUT(musicPlayer: musicPlayer)

        await vm.play(song: Song.stub())

        #expect(vm.isPlaying == false)
        #expect(vm.errorMessage != nil)
    }

    @Test("play 시 이전 곡 상태 완전 리셋 (revealedLines, scrolling, translatedLines)")
    func playResetsState() async {
        let (vm, _, _, _) = makeSUT()

        await vm.play(song: Song.stub(id: "song1", title: "First"))
        vm.revealedLineIndices = [0, 1, 2]
        vm.isUserScrolling = true

        await vm.play(song: Song.stub(id: "song2", title: "Second"))

        #expect(vm.currentSong?.id == "song2")
        #expect(vm.revealedLineIndices.isEmpty)
        #expect(vm.isUserScrolling == false)
        #expect(vm.translatedLines == nil)
    }

    // MARK: - pause() / resume()

    @Test("pause → isPlaying false")
    func pauseSetsNotPlaying() async {
        let (vm, _, _, _) = makeSUT()
        await vm.play(song: Song.stub())

        await vm.pause()
        #expect(vm.isPlaying == false)
    }

    @Test("resume 성공 → isPlaying true")
    func resumeSuccess() async {
        let (vm, _, _, _) = makeSUT()
        await vm.play(song: Song.stub())
        await vm.pause()

        await vm.resume()
        #expect(vm.isPlaying == true)
    }

    @Test("resume 실패 → errorMessage 설정")
    func resumeFailure() async {
        let musicPlayer = MockMusicPlayerService()
        await musicPlayer.setResumeThrow(true)
        let (vm, _, _, _) = makeSUT(musicPlayer: musicPlayer)
        await vm.play(song: Song.stub())
        await vm.pause()

        await vm.resume()
        #expect(vm.errorMessage != nil)
    }

    // MARK: - seek / slider

    @Test("startDragging → isDragging true")
    func startDragging() {
        let (vm, _, _, _) = makeSUT()
        vm.startDragging()
        #expect(vm.isDragging == true)
    }

    @Test("stopDragging → seek 호출, isDragging false, currentTime/sliderValue 갱신")
    func stopDragging() async {
        let (vm, musicPlayer, _, _) = makeSUT()
        vm.startDragging()

        await vm.stopDragging(to: 45.0)

        #expect(vm.isDragging == false)
        #expect(vm.currentTime == 45.0)
        #expect(vm.sliderValue == 45.0)

        let seekCount = await musicPlayer.seekCallCount
        #expect(seekCount == 1)
    }

    @Test("seek 직접 호출 → musicPlayer에 전달 + VM 상태 갱신")
    func seekDirect() async {
        let (vm, musicPlayer, _, _) = makeSUT()

        await vm.seek(to: 120)

        #expect(vm.currentTime == 120)
        #expect(vm.sliderValue == 120)

        let lastTime = await musicPlayer.lastSeekedTime
        #expect(lastTime == 120)
    }

    // MARK: - currentLyricIndex

    @Test("synced 가사 없으면 currentLyricIndex nil")
    func lyricIndexNoSynced() {
        let (vm, _, _, _) = makeSUT()
        #expect(vm.currentLyricIndex == nil)
    }

    // MARK: - toggleReveal

    @Test("toggleReveal - 추가 후 다시 호출하면 제거")
    func toggleReveal() {
        let (vm, _, _, _) = makeSUT()

        vm.toggleReveal(at: 3)
        #expect(vm.revealedLineIndices.contains(3))

        vm.toggleReveal(at: 3)
        #expect(!vm.revealedLineIndices.contains(3))
    }

    @Test("toggleReveal - 여러 인덱스가 독립적으로 동작")
    func toggleRevealMultiple() {
        let (vm, _, _, _) = makeSUT()

        vm.toggleReveal(at: 0)
        vm.toggleReveal(at: 5)
        vm.toggleReveal(at: 10)
        #expect(vm.revealedLineIndices.count == 3)

        vm.toggleReveal(at: 5)
        #expect(vm.revealedLineIndices.count == 2)
        #expect(!vm.revealedLineIndices.contains(5))
        #expect(vm.revealedLineIndices.contains(0))
        #expect(vm.revealedLineIndices.contains(10))
    }

    // MARK: - showFullPlayer

    @Test("showFullPlayer = true → revealedLineIndices 자동 리셋")
    func showFullPlayerResetsRevealed() {
        let (vm, _, _, _) = makeSUT()

        vm.revealedLineIndices = [1, 2, 3]
        vm.showFullPlayer = true

        #expect(vm.revealedLineIndices.isEmpty)
    }

    @Test("showFullPlayer = false → revealedLineIndices 유지")
    func hideFullPlayerKeepsRevealed() {
        let (vm, _, _, _) = makeSUT()

        vm.showFullPlayer = true
        vm.revealedLineIndices = [1, 2, 3]
        vm.showFullPlayer = false

        #expect(vm.revealedLineIndices.count == 3)
    }

    // MARK: - translationMode

    @Test("translationMode 변경 시 UserDefaults에 저장")
    func translationModeSavesToUserDefaults() {
        let (vm, _, _, _) = makeSUT()

        vm.translationMode = .hidden
        #expect(UserDefaults.standard.string(forKey: "translationMode") == "hidden")

        vm.translationMode = .simultaneous
        #expect(UserDefaults.standard.string(forKey: "translationMode") == "simultaneous")
    }

    // MARK: - 사용자 스크롤

    @Test("onUserScrollBegan → isUserScrolling true")
    func userScrollBegan() {
        let (vm, _, _, _) = makeSUT()
        vm.onUserScrollBegan()
        #expect(vm.isUserScrolling == true)
    }

    // MARK: - stopTimers

    @Test("stopTimers 중복 호출해도 crash 없음")
    func stopTimersNoCrash() {
        let (vm, _, _, _) = makeSUT()
        vm.stopTimers()
        vm.stopTimers()
    }

    // MARK: - fetchLyrics (play를 통해 간접 테스트)

    @Test("play 시 Supabase에 원본+번역 있으면 synced + translatedLines 설정")
    func playWithSupabaseLyrics() async {
        let translatedService = MockTranslatedLyricService()
        let originalLRC = "[00:05.00] Hello\n[00:10.00] World"
        let translatedLRC = "[00:05.00] 안녕\n[00:10.00] 세계"
        await translatedService.setFetchResult(
            TranslatedLyricResult(originalLRC: originalLRC, translatedLRC: translatedLRC)
        )

        let (vm, _, _, _) = makeSUT(translatedLyricService: translatedService)
        await vm.play(song: Song.stub(id: "with-lyrics"))

        // fetchLyrics는 내부 Task로 실행되므로 약간 대기
        try? await Task.sleep(for: .milliseconds(100))

        if case .synced(let lines) = vm.lyricState {
            #expect(lines.count == 2)
            #expect(lines[0].text == "Hello")
        } else {
            Issue.record("Expected .synced, got \(vm.lyricState)")
        }

        #expect(vm.hasTranslation == true)
        #expect(vm.translatedLines?.count == 2)
        #expect(vm.translatedLines?[0].text == "안녕")
    }

    @Test("play 시 Supabase에 없으면 lrclib fallback 사용")
    func playWithLrclibFallback() async {
        let lyricService = MockLyricService()
        await lyricService.setResult(.synced([
            LyricLine(timestamp: 0, text: "Fallback line")
        ]))

        let (vm, _, _, _) = makeSUT(lyricService: lyricService)
        await vm.play(song: Song.stub(id: "no-supabase"))

        try? await Task.sleep(for: .milliseconds(100))

        if case .synced(let lines) = vm.lyricState {
            #expect(lines[0].text == "Fallback line")
        } else {
            Issue.record("Expected .synced from fallback, got \(vm.lyricState)")
        }
        #expect(vm.hasTranslation == false)
    }

    @Test("Supabase 원본+번역 줄 수 불일치 → 번역 무시")
    func playWithMismatchedLineCount() async {
        let translatedService = MockTranslatedLyricService()
        let originalLRC = "[00:05.00] Line1\n[00:10.00] Line2"
        let translatedLRC = "[00:05.00] 번역1" // 1줄만
        await translatedService.setFetchResult(
            TranslatedLyricResult(originalLRC: originalLRC, translatedLRC: translatedLRC)
        )

        let (vm, _, _, _) = makeSUT(translatedLyricService: translatedService)
        await vm.play(song: Song.stub())

        try? await Task.sleep(for: .milliseconds(100))

        if case .synced(let lines) = vm.lyricState {
            #expect(lines.count == 2)
        }
        // 줄 수 불일치 → 번역 무시
        #expect(vm.hasTranslation == false)
        #expect(vm.translatedLines == nil)
    }

    @Test("play 시 englishTitle 없으면 englishMetadata fetch 시도")
    func playFetchesEnglishMetadata() async {
        let musicPlayer = MockMusicPlayerService()
        await musicPlayer.setEnglishMetadata(("English Title", "English Artist"))

        let lyricService = MockLyricService()
        await lyricService.setResult(.notFound)

        let (vm, _, lyric, _) = makeSUT(musicPlayer: musicPlayer, lyricService: lyricService)
        await vm.play(song: Song.stub(englishTitle: nil, englishArtistName: nil))

        try? await Task.sleep(for: .milliseconds(100))

        // lrclib에 영어 이름으로 요청했는지 확인
        let lastArtist = await lyric.lastArtist
        let lastTrack = await lyric.lastTrack
        #expect(lastArtist == "English Artist")
        #expect(lastTrack == "English Title")
    }

    // MARK: - currentLyricIndex 계산

    @Test("synced 가사에서 currentTime 기준 올바른 인덱스 계산")
    func currentLyricIndexCalculation() async {
        let translatedService = MockTranslatedLyricService()
        let lrc = "[00:05.00] Line1\n[00:10.00] Line2\n[00:20.00] Line3"
        await translatedService.setFetchResult(
            TranslatedLyricResult(originalLRC: lrc, translatedLRC: nil)
        )

        let musicPlayer = MockMusicPlayerService()
        let (vm, _, _, _) = makeSUT(musicPlayer: musicPlayer, translatedLyricService: translatedService)
        await vm.play(song: Song.stub())

        try? await Task.sleep(for: .milliseconds(100))

        // currentTime에 따른 lyricIndex 검증
        // 수동으로 currentTime 변경 (seek 시뮬레이션)
        await vm.seek(to: 0)
        #expect(vm.currentLyricIndex == nil) // 5초 전

        await vm.seek(to: 5)
        #expect(vm.currentLyricIndex == 0) // 정확히 Line1

        await vm.seek(to: 7)
        #expect(vm.currentLyricIndex == 0) // Line1~Line2 사이

        await vm.seek(to: 10)
        #expect(vm.currentLyricIndex == 1) // 정확히 Line2

        await vm.seek(to: 25)
        #expect(vm.currentLyricIndex == 2) // Line3 이후
    }

    // MARK: - duration nil 처리

    @Test("song.duration이 nil이면 duration은 0")
    func playWithNilDuration() async {
        let (vm, _, _, _) = makeSUT()
        await vm.play(song: Song.stub(duration: nil))
        #expect(vm.duration == 0)
    }
}

// MARK: - MockMusicPlayerService 헬퍼

extension MockMusicPlayerService {
    func setShouldThrow(_ value: Bool) {
        shouldThrowOnPlay = value
    }

    func setResumeThrow(_ value: Bool) {
        shouldThrowOnResume = value
    }
}
