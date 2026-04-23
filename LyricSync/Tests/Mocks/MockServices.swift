import Foundation
import MusicKit
@testable import LyricSync

/// 앱의 Song 타입을 LyricSync.Song으로 명시하여 MusicKit.Song과 구분.
typealias AppSong = LyricSync.Song

// MARK: - MockLyricService

actor MockLyricService: LyricServiceProtocol {
    var fetchResult: LyricState = .notFound
    var fetchCallCount = 0
    var lastArtist: String?
    var lastTrack: String?
    var lastDuration: TimeInterval?

    func fetchLyrics(artist: String, track: String, duration: TimeInterval?) async -> LyricState {
        fetchCallCount += 1
        lastArtist = artist
        lastTrack = track
        lastDuration = duration
        return fetchResult
    }
}

// MARK: - MockMusicPlayerService

actor MockMusicPlayerService: MusicPlayerServiceProtocol {
    var shouldThrowOnPlay = false
    var shouldThrowOnResume = false
    var playError: Error = MusicPlayerError.songNotFound
    var resumeError: Error = MusicPlayerError.playbackFailed(NSError(domain: "test", code: 1))
    var _playbackTime: TimeInterval = 0
    var _playbackStatus: MusicPlayer.PlaybackStatus = .stopped
    var englishMetadata: (title: String, artist: String)?

    var playCallCount = 0
    var pauseCallCount = 0
    var resumeCallCount = 0
    var seekCallCount = 0
    var lastSeekedTime: TimeInterval?
    var lastPlayedSong: AppSong?

    func play(song: AppSong) async throws {
        playCallCount += 1
        lastPlayedSong = song
        if shouldThrowOnPlay {
            throw playError
        }
        _playbackStatus = .playing
    }

    func pause() async {
        pauseCallCount += 1
        _playbackStatus = .paused
    }

    func resume() async throws {
        resumeCallCount += 1
        if shouldThrowOnResume {
            throw resumeError
        }
        _playbackStatus = .playing
    }

    func seek(to time: TimeInterval) async {
        seekCallCount += 1
        lastSeekedTime = time
        _playbackTime = time
    }

    func fetchEnglishMetadata(for song: AppSong) async -> (title: String, artist: String)? {
        return englishMetadata
    }

    var playbackTime: TimeInterval {
        _playbackTime
    }

    var playbackStatus: MusicPlayer.PlaybackStatus {
        _playbackStatus
    }
}

// MARK: - MockChartService

actor MockChartService: ChartServiceProtocol {
    var fetchResult: [AppSong] = []
    var shouldThrow = false
    var error: Error = ChartServiceError.chartEmpty
    var fetchCallCount = 0

    func fetchChart() async throws -> [AppSong] {
        fetchCallCount += 1
        if shouldThrow {
            throw error
        }
        return fetchResult
    }
}

// MARK: - MockSearchService

actor MockSearchService: SearchServiceProtocol {
    var searchResult: [AppSong] = []
    var shouldThrow = false
    var searchCallCount = 0
    var lastTerm: String?

    func search(term: String, limit: Int) async throws -> [AppSong] {
        searchCallCount += 1
        lastTerm = term
        if shouldThrow {
            throw NSError(domain: "test", code: 1)
        }
        return searchResult
    }
}

// MARK: - MockTranslatedLyricService

actor MockTranslatedLyricService: TranslatedLyricServiceProtocol {
    var fetchResult = TranslatedLyricResult(originalLRC: nil, translatedLRC: nil)
    var translationStatusResult: Set<String> = []
    var fetchCallCount = 0
    var statusCallCount = 0
    var lastAppleMusicID: String?

    func fetchLyrics(appleMusicID: String) async -> TranslatedLyricResult {
        fetchCallCount += 1
        lastAppleMusicID = appleMusicID
        return fetchResult
    }

    func fetchTranslationStatus(appleMusicIDs: [String]) async -> Set<String> {
        statusCallCount += 1
        return translationStatusResult
    }
}

// MARK: - MockUserTranslationService

actor MockUserTranslationService: UserTranslationServiceProtocol {
    var fetchResult: [UserTranslationLine] = []
    var allResult: [MyTranslationSummary] = []
    var studiedIDsResult: Set<String> = []
    var fetchCallCount = 0
    var saveCallCount = 0

    func fetch(userId: Int, appleMusicID: String) async -> [UserTranslationLine] {
        fetchCallCount += 1
        return fetchResult
    }

    func save(userId: Int, appleMusicID: String, title: String, artist: String, lines: [UserTranslationLine]) async {
        saveCallCount += 1
    }

    func fetchAll(userId: Int) async -> [MyTranslationSummary] {
        return allResult
    }

    func fetchStudiedSongIDs(userId: Int) async -> Set<String> {
        return studiedIDsResult
    }

    func setAllResult(_ summaries: [MyTranslationSummary]) {
        allResult = summaries
    }

    func setStudiedIDs(_ ids: Set<String>) {
        studiedIDsResult = ids
    }
}

// MARK: - Mock 추가 헬퍼

extension MockLyricService {
    func setResult(_ state: LyricState) {
        fetchResult = state
    }
}

extension MockTranslatedLyricService {
    func setFetchResult(_ result: TranslatedLyricResult) {
        fetchResult = result
    }
}

extension MockMusicPlayerService {
    func setEnglishMetadata(_ metadata: (String, String)?) {
        englishMetadata = metadata.map { (title: $0.0, artist: $0.1) }
    }
}

extension MockSearchService {
    func setResult(_ songs: [AppSong]) {
        searchResult = songs
    }

    func setThrow(_ value: Bool) {
        shouldThrow = value
    }
}

extension MockTranslatedLyricService {
    func setStatusResult(_ ids: Set<String>) {
        translationStatusResult = ids
    }
}

// MARK: - Test Helpers

extension AppSong {
    /// 테스트용 Song 인스턴스 팩토리.
    static func stub(
        id: String = "test-id-1",
        title: String = "Test Song",
        artistName: String = "Test Artist",
        albumTitle: String? = "Test Album",
        artworkURL: URL? = URL(string: "https://example.com/art.jpg"),
        duration: TimeInterval? = 210,
        rank: Int? = 1,
        englishTitle: String? = nil,
        englishArtistName: String? = nil
    ) -> AppSong {
        AppSong(
            id: id,
            title: title,
            artistName: artistName,
            albumTitle: albumTitle,
            artworkURL: artworkURL,
            duration: duration,
            rank: rank,
            musicKitID: MusicItemID(id),
            englishTitle: englishTitle,
            englishArtistName: englishArtistName
        )
    }
}
