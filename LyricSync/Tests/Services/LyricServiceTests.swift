import Testing
import Foundation
@testable import LyricSync

/// MockURLProtocol은 static 상태를 공유하므로 병렬 실행 시 경합.
/// .serialized로 직렬 실행하여 테스트 격리를 보장한다.
@Suite("LyricService Tests", .serialized)
struct LyricServiceTests {

    private func makeSUT() -> LyricService {
        LyricService(session: .mock)
    }

    private func stubResponse(statusCode: Int, json: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(
            url: URL(string: "https://lrclib.net/api/get")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        MockURLProtocol.requestHandler = { _ in (data, response) }
    }

    private func stubResponse(statusCode: Int, data: Data = Data()) {
        let response = HTTPURLResponse(
            url: URL(string: "https://lrclib.net/api/get")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        MockURLProtocol.requestHandler = { _ in (data, response) }
    }

    // MARK: - 정상 응답

    @Test("synced 가사 파싱 성공 - 타임스탬프와 텍스트가 정확히 파싱됨")
    func fetchSyncedLyrics() async {
        MockURLProtocol.reset()

        let lrc = "[00:05.00] First line\n[00:10.50] Second line\n[01:00.00] Third line"
        stubResponse(statusCode: 200, json: [
            "id": 1,
            "trackName": "Test",
            "artistName": "Artist",
            "duration": 180.0,
            "instrumental": false,
            "syncedLyrics": lrc,
            "plainLyrics": "fallback"
        ])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "Artist", track: "Test", duration: 180)

        guard case .synced(let lines) = result else {
            Issue.record("Expected .synced, got \(result)")
            return
        }
        #expect(lines.count == 3)
        #expect(lines[0].timestamp == 5.0)
        #expect(lines[0].text == "First line")
        #expect(lines[1].timestamp == 10.5)
        #expect(lines[1].text == "Second line")
        #expect(lines[2].timestamp == 60.0)
        #expect(lines[2].text == "Third line")
    }

    @Test("plain 가사 반환 - synced 없을 때 plainLyrics fallback")
    func fetchPlainLyrics() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 200, json: [
            "id": 1,
            "trackName": "Test",
            "artistName": "Artist",
            "duration": 180.0,
            "instrumental": false,
            "plainLyrics": "Line one\nLine two"
        ])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "Artist", track: "Test", duration: nil)

        guard case .plain(let text) = result else {
            Issue.record("Expected .plain, got \(result)")
            return
        }
        #expect(text == "Line one\nLine two")
    }

    @Test("instrumental 곡 → .instrumental 반환")
    func fetchInstrumental() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 200, json: [
            "id": 1,
            "trackName": "Instrumental",
            "artistName": "DJ",
            "duration": 120.0,
            "instrumental": true
        ])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "DJ", track: "Instrumental", duration: 120)

        guard case .instrumental = result else {
            Issue.record("Expected .instrumental, got \(result)")
            return
        }
    }

    // MARK: - HTTP 에러 응답

    @Test("404 → .notFound 반환")
    func fetch404() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 404)

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "X", track: "Y", duration: nil)

        guard case .notFound = result else {
            Issue.record("Expected .notFound, got \(result)")
            return
        }
    }

    @Test("429 → rate limit 에러 메시지 반환")
    func fetch429() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 429)

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "X", track: "Y", duration: nil)

        guard case .error(let msg) = result else {
            Issue.record("Expected .error, got \(result)")
            return
        }
        #expect(msg.contains("요청이 너무 많습니다"))
    }

    @Test("500 → 서버 오류 에러 메시지에 상태 코드 포함")
    func fetch500() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 500)

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "X", track: "Y", duration: nil)

        guard case .error(let msg) = result else {
            Issue.record("Expected .error, got \(result)")
            return
        }
        #expect(msg.contains("500"))
    }

    // MARK: - 네트워크 에러

    @Test("네트워크 에러 → .error 상태 반환")
    func fetchNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "X", track: "Y", duration: nil)

        guard case .error(let msg) = result else {
            Issue.record("Expected .error, got \(result)")
            return
        }
        #expect(msg.contains("불러오지 못했습니다"))
    }

    // MARK: - URL 쿼리 파라미터 (캡처 후 검증)

    @Test("URL에 artist_name, track_name 쿼리 파라미터 포함")
    func urlQueryParameters() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 404)

        let sut = makeSUT()
        _ = await sut.fetchLyrics(artist: "Test Artist", track: "Test Song", duration: nil)

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let url = MockURLProtocol.capturedRequests[0].url!.absoluteString
        #expect(url.contains("artist_name=Test%20Artist"))
        #expect(url.contains("track_name=Test%20Song"))
    }

    @Test("duration이 있으면 URL 쿼리에 포함")
    func urlWithDuration() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 404)

        let sut = makeSUT()
        _ = await sut.fetchLyrics(artist: "A", track: "B", duration: 180)

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let url = MockURLProtocol.capturedRequests[0].url!.absoluteString
        #expect(url.contains("duration=180"))
    }

    @Test("User-Agent 헤더가 'LyricSync v1.0'으로 설정됨")
    func userAgentHeader() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 404)

        let sut = makeSUT()
        _ = await sut.fetchLyrics(artist: "A", track: "B", duration: nil)

        #expect(MockURLProtocol.capturedRequests.count == 1)
        #expect(MockURLProtocol.capturedRequests[0].value(forHTTPHeaderField: "User-Agent") == "LyricSync v1.0")
    }

    // MARK: - LRC 파싱 엣지 케이스

    @Test("syncedLyrics 빈 문자열 → plainLyrics fallback")
    func emptySyncedFallsBackToPlain() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 200, json: [
            "id": 1,
            "trackName": "T",
            "artistName": "A",
            "duration": 100.0,
            "instrumental": false,
            "syncedLyrics": "",
            "plainLyrics": "Fallback text"
        ])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "A", track: "T", duration: nil)

        guard case .plain(let text) = result else {
            Issue.record("Expected .plain, got \(result)")
            return
        }
        #expect(text == "Fallback text")
    }

    @Test("syncedLyrics와 plainLyrics 모두 없으면 .notFound")
    func noLyricsAtAll() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 200, json: [
            "id": 1,
            "trackName": "T",
            "artistName": "A",
            "duration": 100.0,
            "instrumental": false
        ])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "A", track: "T", duration: nil)

        guard case .notFound = result else {
            Issue.record("Expected .notFound, got \(result)")
            return
        }
    }

    @Test("LRC 파싱 - 잘못된 형식 줄은 무시하고 유효한 줄만 파싱")
    func parseLRCInvalidLines() async {
        MockURLProtocol.reset()
        let lrc = "[00:05.00] Valid line\nInvalid line without timestamp\n[broken\n[00:10.00] Another valid"
        stubResponse(statusCode: 200, json: [
            "id": 1,
            "trackName": "T",
            "artistName": "A",
            "duration": 100.0,
            "instrumental": false,
            "syncedLyrics": lrc
        ])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "A", track: "T", duration: nil)

        guard case .synced(let lines) = result else {
            Issue.record("Expected .synced, got \(result)")
            return
        }
        #expect(lines.count == 2)
        #expect(lines[0].text == "Valid line")
        #expect(lines[1].text == "Another valid")
    }

    @Test("LRC 파싱 - 모든 줄이 잘못된 형식이면 .notFound")
    func parseLRCAllInvalid() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 200, json: [
            "id": 1,
            "trackName": "T",
            "artistName": "A",
            "duration": 100.0,
            "instrumental": false,
            "syncedLyrics": "no timestamps\njust text"
        ])

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "A", track: "T", duration: nil)

        guard case .notFound = result else {
            Issue.record("Expected .notFound, got \(result)")
            return
        }
    }

    @Test("JSON 디코딩 실패 (malformed) → .error 반환")
    func fetchMalformedJSON() async {
        MockURLProtocol.reset()
        stubResponse(statusCode: 200, data: Data("not valid json{{".utf8))

        let sut = makeSUT()
        let result = await sut.fetchLyrics(artist: "A", track: "T", duration: nil)

        guard case .error = result else {
            Issue.record("Expected .error for malformed JSON, got \(result)")
            return
        }
    }
}
