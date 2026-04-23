import Testing
import Foundation
@testable import LyricSync

@Suite("TranslatedLyricService Tests", .serialized)
struct TranslatedLyricServiceTests {

    private func makeSUT() -> TranslatedLyricService {
        TranslatedLyricService(
            baseURL: "https://test.supabase.co/rest/v1",
            apiKey: "test-api-key",
            session: .mock
        )
    }

    private func stubOK(json: Any) {
        MockURLProtocol.requestHandler = { _ in
            let data = try! JSONSerialization.data(withJSONObject: json)
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        }
    }

    // MARK: - fetchLyrics

    @Test("원본 + 번역 가사 모두 있는 경우 둘 다 반환")
    func fetchLyricsWithBoth() async {
        MockURLProtocol.reset()
        stubOK(json: [[
            "id": 1,
            "title": "Test Song",
            "artist": "Test Artist",
            "lyrics": [
                ["type": "original", "lang": "en", "content": "[00:05.00] Hello", "format": "synced"],
                ["type": "translated", "lang": "ko", "content": "[00:05.00] 안녕", "format": "synced"],
            ]
        ]] as [[String: Any]])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(appleMusicID: "abc123")

        #expect(result.originalLRC == "[00:05.00] Hello")
        #expect(result.translatedLRC == "[00:05.00] 안녕")
    }

    @Test("원본만 있고 번역 없으면 translatedLRC만 nil")
    func fetchLyricsOriginalOnly() async {
        MockURLProtocol.reset()
        stubOK(json: [[
            "id": 1,
            "title": "Test",
            "artist": "Artist",
            "lyrics": [
                ["type": "original", "lang": "en", "content": "[00:05.00] Hello", "format": "synced"],
            ]
        ]] as [[String: Any]])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(appleMusicID: "abc")

        #expect(result.originalLRC != nil)
        #expect(result.translatedLRC == nil)
    }

    @Test("곡이 Supabase에 없으면 둘 다 nil")
    func fetchLyricsNotFound() async {
        MockURLProtocol.reset()
        stubOK(json: [] as [Any])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(appleMusicID: "nonexistent")

        #expect(result.originalLRC == nil)
        #expect(result.translatedLRC == nil)
    }

    @Test("서버 에러 (500) → graceful 실패, 둘 다 nil")
    func fetchLyricsServerError() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            let data = Data("error".utf8)
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!, statusCode: 500,
                httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        }

        let sut = makeSUT()
        let result = await sut.fetchLyrics(appleMusicID: "abc")

        #expect(result.originalLRC == nil)
        #expect(result.translatedLRC == nil)
    }

    @Test("네트워크 에러 → graceful 실패")
    func fetchLyricsNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }

        let sut = makeSUT()
        let result = await sut.fetchLyrics(appleMusicID: "abc")

        #expect(result.originalLRC == nil)
        #expect(result.translatedLRC == nil)
    }

    @Test("API 헤더에 apikey와 Authorization 포함 (캡처 후 검증)")
    func fetchLyricsHeaders() async {
        MockURLProtocol.reset()
        stubOK(json: [] as [Any])

        let sut = makeSUT()
        _ = await sut.fetchLyrics(appleMusicID: "abc")

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let request = MockURLProtocol.capturedRequests[0]
        #expect(request.value(forHTTPHeaderField: "apikey") == "test-api-key")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-api-key")
    }

    // MARK: - fetchTranslationStatus

    @Test("번역 상태 배치 조회 - translated+ko 있는 곡만 반환")
    func fetchTranslationStatusFilters() async {
        MockURLProtocol.reset()
        stubOK(json: [
            ["apple_music_id": "id1", "lyrics": [["type": "translated", "lang": "ko"]]],
            ["apple_music_id": "id2", "lyrics": [["type": "original", "lang": "en"]]],
            ["apple_music_id": "id3", "lyrics": [
                ["type": "translated", "lang": "ko"],
                ["type": "original", "lang": "en"]
            ]],
        ] as [[String: Any]])

        let sut = makeSUT()
        let result = await sut.fetchTranslationStatus(appleMusicIDs: ["id1", "id2", "id3"])

        #expect(result.contains("id1"))
        #expect(!result.contains("id2"))
        #expect(result.contains("id3"))
        #expect(result.count == 2)
    }

    @Test("빈 ID 배열이면 네트워크 호출 없이 빈 Set 반환")
    func fetchTranslationStatusEmpty() async {
        MockURLProtocol.reset()
        let sut = makeSUT()
        let result = await sut.fetchTranslationStatus(appleMusicIDs: [])

        #expect(result.isEmpty)
        #expect(MockURLProtocol.capturedRequests.isEmpty)
    }

    @Test("번역 상태 조회 서버 에러 → 빈 Set 반환")
    func fetchTranslationStatusServerError() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            let data = Data()
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!, statusCode: 500,
                httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        }

        let sut = makeSUT()
        let result = await sut.fetchTranslationStatus(appleMusicIDs: ["id1"])

        #expect(result.isEmpty)
    }

    // MARK: - synced format 우선순위

    @Test("original은 synced format만 사용, plain format은 무시")
    func onlySyncedFormatOriginal() async {
        MockURLProtocol.reset()
        stubOK(json: [[
            "id": 1,
            "title": "T",
            "artist": "A",
            "lyrics": [
                ["type": "original", "lang": "en", "content": "plain text", "format": "plain"],
                ["type": "translated", "lang": "ko", "content": "[00:05.00] 한글", "format": "synced"],
            ]
        ]] as [[String: Any]])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(appleMusicID: "abc")

        #expect(result.originalLRC == nil)
        #expect(result.translatedLRC == "[00:05.00] 한글")
    }
}
