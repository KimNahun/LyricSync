import Testing
import Foundation
@testable import LyricSync

@Suite("Error Type Tests")
struct ErrorTypeTests {

    // MARK: - LyricServiceError

    @Test("LyricServiceError.invalidURL 에러 메시지")
    func lyricServiceInvalidURL() {
        let error = LyricServiceError.invalidURL
        #expect(error.errorDescription == "잘못된 URL입니다.")
    }

    @Test("LyricServiceError.networkError 에러 메시지에 원인 포함")
    func lyricServiceNetworkError() {
        let underlying = URLError(.notConnectedToInternet)
        let error = LyricServiceError.networkError(underlying)
        let desc = error.errorDescription!
        #expect(desc.contains("네트워크 오류"))
    }

    @Test("LyricServiceError.decodingError 에러 메시지")
    func lyricServiceDecodingError() {
        let underlying = NSError(domain: "decode", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad json"])
        let error = LyricServiceError.decodingError(underlying)
        let desc = error.errorDescription!
        #expect(desc.contains("파싱 오류"))
    }

    // MARK: - MusicPlayerError

    @Test("MusicPlayerError.songNotFound 에러 메시지")
    func playerSongNotFound() {
        let error = MusicPlayerError.songNotFound
        #expect(error.errorDescription == "곡을 찾을 수 없습니다.")
    }

    @Test("MusicPlayerError.playbackFailed 에러 메시지에 원인 포함")
    func playerPlaybackFailed() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "timeout"])
        let error = MusicPlayerError.playbackFailed(underlying)
        let desc = error.errorDescription!
        #expect(desc.contains("재생에 실패했습니다"))
        #expect(desc.contains("timeout"))
    }

    // MARK: - ChartServiceError

    @Test("ChartServiceError.authorizationDenied 에러 메시지")
    func chartAuthDenied() {
        let error = ChartServiceError.authorizationDenied
        #expect(error.errorDescription!.contains("권한"))
    }

    @Test("ChartServiceError.chartEmpty 에러 메시지")
    func chartEmpty() {
        let error = ChartServiceError.chartEmpty
        #expect(error.errorDescription!.contains("차트"))
    }

    @Test("ChartServiceError.networkError 에러 메시지에 원인 포함")
    func chartNetworkError() {
        let underlying = URLError(.timedOut)
        let error = ChartServiceError.networkError(underlying)
        let desc = error.errorDescription!
        #expect(desc.contains("네트워크"))
    }

    // MARK: - CredentialCheckResult

    @Test("CredentialCheckResult.valid는 userIdentifier를 보존")
    func credentialValid() {
        let result = CredentialCheckResult.valid("user-abc-123")
        if case .valid(let id) = result {
            #expect(id == "user-abc-123")
        } else {
            Issue.record("Expected .valid")
        }
    }

    @Test("CredentialCheckResult.invalid")
    func credentialInvalid() {
        let result = CredentialCheckResult.invalid
        if case .invalid = result {
            // OK
        } else {
            Issue.record("Expected .invalid")
        }
    }
}
