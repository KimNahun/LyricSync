import Testing
import Foundation
@testable import LyricSync

@Suite("AuthService Tests", .serialized)
struct AuthServiceTests {

    private func makeSUT() -> AuthService {
        AuthService(
            baseURL: "https://test.supabase.co/rest/v1",
            apiKey: "test-key",
            session: .mock
        )
    }

    // MARK: - registerUser

    @Test("유저 등록 - POST 요청 + upsert 헤더 + 바디 검증")
    func registerUser() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!,
                statusCode: 201, httpVersion: nil, headerFields: nil
            )!
            return (Data(), response)
        }

        let sut = makeSUT()
        await sut.registerUser(appleUserId: "apple-123", email: "test@test.com", displayName: "Tester")

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let request = MockURLProtocol.capturedRequests[0]

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Prefer") == "resolution=merge-duplicates")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "apikey") == "test-key")

        let body = try! #require(request.httpBody)
        let json = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
        #expect(json["apple_user_id"] as? String == "apple-123")
        #expect(json["email"] as? String == "test@test.com")
        #expect(json["display_name"] as? String == "Tester")
        #expect(json["last_login_at"] != nil)
    }

    @Test("유저 등록 - email/displayName nil이면 body에 미포함")
    func registerUserNilFields() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!,
                statusCode: 201, httpVersion: nil, headerFields: nil
            )!
            return (Data(), response)
        }

        let sut = makeSUT()
        await sut.registerUser(appleUserId: "apple-456", email: nil, displayName: nil)

        let body = try! #require(MockURLProtocol.capturedRequests[0].httpBody)
        let json = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
        #expect(json["email"] == nil)
        #expect(json["display_name"] == nil)
    }

    @Test("유저 등록 - 네트워크 에러도 crash 없이 처리")
    func registerUserNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }

        let sut = makeSUT()
        await sut.registerUser(appleUserId: "apple-err", email: nil, displayName: nil)
    }

    // MARK: - fetchUserId

    @Test("DB userId 조회 성공")
    func fetchUserIdSuccess() async {
        MockURLProtocol.reset()
        let responseJSON = [["id": 42]]
        MockURLProtocol.requestHandler = { _ in
            let data = try! JSONSerialization.data(withJSONObject: responseJSON)
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        }

        let sut = makeSUT()
        let userId = await sut.fetchUserId(appleUserId: "apple-123")

        #expect(userId == 42)
    }

    @Test("DB userId 조회 - 유저 없으면 nil")
    func fetchUserIdEmpty() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            let data = try! JSONSerialization.data(withJSONObject: [] as [Any])
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        }

        let sut = makeSUT()
        let userId = await sut.fetchUserId(appleUserId: "nonexistent")

        #expect(userId == nil)
    }

    @Test("DB userId 조회 - 네트워크 에러면 nil")
    func fetchUserIdNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        let sut = makeSUT()
        let userId = await sut.fetchUserId(appleUserId: "apple-123")

        #expect(userId == nil)
    }

    // MARK: - deleteUser

    @Test("유저 삭제 - DELETE 요청 검증")
    func deleteUser() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!,
                statusCode: 204, httpVersion: nil, headerFields: nil
            )!
            return (Data(), response)
        }

        let sut = makeSUT()
        await sut.deleteUser(appleUserId: "apple-del")

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let request = MockURLProtocol.capturedRequests[0]
        #expect(request.httpMethod == "DELETE")
        #expect(request.url!.absoluteString.contains("apple_user_id=eq.apple-del"))
    }

    @Test("유저 삭제 - 네트워크 에러도 crash 없이 처리")
    func deleteUserNetworkError() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }

        let sut = makeSUT()
        await sut.deleteUser(appleUserId: "apple-err")
    }

    // MARK: - URL 구성

    @Test("fetchUserId URL에 apple_user_id 쿼리 포함")
    func fetchUserIdURL() async {
        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            let data = try! JSONSerialization.data(withJSONObject: [] as [Any])
            let response = HTTPURLResponse(
                url: URL(string: "https://test.supabase.co")!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        }

        let sut = makeSUT()
        _ = await sut.fetchUserId(appleUserId: "test-apple-id")

        #expect(MockURLProtocol.capturedRequests.count == 1)
        let url = MockURLProtocol.capturedRequests[0].url!.absoluteString
        #expect(url.contains("apple_user_id=eq.test-apple-id"))
        #expect(url.contains("select=id"))
    }
}
