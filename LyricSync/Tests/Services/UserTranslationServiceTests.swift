import Testing
import Foundation
@testable import LyricSync

@Suite("UserTranslationService Tests", .serialized)
struct UserTranslationServiceTests {

    private func makeSUT() -> UserTranslationService {
        UserTranslationService(
            baseURL: "https://test.supabase.co/rest/v1",
            apiKey: "test-key",
            session: .mock
        )
    }

    // MARK: - fetch

    @Test("유저 번역 조회 성공 - lines 배열이 올바르게 디코딩됨")
    func fetchSuccess() async {
        MockURLProtocol.reset()
        let responseJSON: [[String: Any]] = [[
            "lines": [
                ["index": 0, "original": "Hello", "translated": "안녕", "timestamp": 5.0],
                ["index": 1, "original": "World", "translated": "세계", "timestamp": 10.0],
            ]
        ]]
        MockURLProtocol.requestHandler = { _ in
            let data = try! JSONSerialization.data(withJSONObject: responseJSON)
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!, statusCode: 200,
                httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        }

        let sut = makeSUT()
        let lines = await sut.fetch(userId: 1, appleMusicID: "song1")

        #expect(lines.count == 2)
        #expect(lines[0].original == "Hello")
        #expect(lines[0].translated == "안녕")
        #expect(lines[1].index == 1)
    }

    @Test("유저 번역 없는 경우 - 빈 배열 반환")
    func fetchEmpty() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            let data = try! JSONSerialization.data(withJSONObject: [] as [Any])
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!, statusCode: 200,
                httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        }

        let sut = makeSUT()
        let lines = await sut.fetch(userId: 1, appleMusicID: "nonexistent")

        #expect(lines.isEmpty)
    }

    @Test("유저 번역 조회 서버 에러 → 빈 배열 반환")
    func fetchServerError() async {
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
        let lines = await sut.fetch(userId: 1, appleMusicID: "song1")

        #expect(lines.isEmpty)
    }

    @Test("유저 번역 조회 네트워크 에러 → 빈 배열 반환")
    func fetchNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.networkConnectionLost)
        }

        let sut = makeSUT()
        let lines = await sut.fetch(userId: 1, appleMusicID: "song1")

        #expect(lines.isEmpty)
    }

    // MARK: - save

    @Test("유저 번역 저장 - POST 요청의 메서드/헤더/바디 검증")
    func saveRequest() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { request in
            let data = Data()
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        }

        let sut = makeSUT()
        let lines = [
            UserTranslationLine(index: 0, original: "Hi", translated: "안녕", timestamp: 0),
        ]
        await sut.save(userId: 42, appleMusicID: "song123", title: "My Song", artist: "Artist", lines: lines)

        // 캡처된 요청으로 검증
        #expect(MockURLProtocol.capturedRequests.count == 1)
        let request = MockURLProtocol.capturedRequests[0]

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Prefer") == "resolution=merge-duplicates")
        #expect(request.value(forHTTPHeaderField: "apikey") == "test-key")

        // body 반드시 존재
        let body = try! #require(request.httpBody)
        let json = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
        #expect(json["user_id"] as? Int == 42)
        #expect(json["apple_music_id"] as? String == "song123")
        #expect(json["title"] as? String == "My Song")
    }

    @Test("유저 번역 저장 네트워크 에러 → crash 없이 graceful 처리")
    func saveNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        let sut = makeSUT()
        await sut.save(
            userId: 1, appleMusicID: "song1", title: "T", artist: "A",
            lines: [UserTranslationLine(index: 0, original: "X", translated: "Y", timestamp: 0)]
        )
    }
}
