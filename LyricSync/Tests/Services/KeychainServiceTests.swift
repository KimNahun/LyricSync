import Testing
import Foundation
@testable import LyricSync

@Suite("KeychainService Tests", .serialized)
struct KeychainServiceTests {

    // 각 테스트 전 정리
    private func cleanUp() {
        KeychainService.deleteUserId()
    }

    @Test("저장 후 조회하면 동일한 값 반환")
    func saveAndGet() {
        cleanUp()

        KeychainService.saveUserId("test-user-abc")
        let result = KeychainService.getUserId()

        #expect(result == "test-user-abc")
        cleanUp()
    }

    @Test("저장 안 한 상태에서 조회하면 nil")
    func getWithoutSave() {
        cleanUp()

        let result = KeychainService.getUserId()
        #expect(result == nil)
    }

    @Test("삭제 후 조회하면 nil")
    func deleteAndGet() {
        cleanUp()

        KeychainService.saveUserId("to-be-deleted")
        KeychainService.deleteUserId()
        let result = KeychainService.getUserId()

        #expect(result == nil)
    }

    @Test("중복 저장 시 마지막 값으로 덮어씀")
    func overwrite() {
        cleanUp()

        KeychainService.saveUserId("first")
        KeychainService.saveUserId("second")
        let result = KeychainService.getUserId()

        #expect(result == "second")
        cleanUp()
    }

    @Test("빈 문자열 저장/조회")
    func emptyString() {
        cleanUp()

        KeychainService.saveUserId("")
        let result = KeychainService.getUserId()

        #expect(result == "")
        cleanUp()
    }

    @Test("긴 문자열 (UUID 형태) 저장/조회")
    func longString() {
        cleanUp()

        let longId = "001234.abcdef1234567890abcdef1234567890.1234"
        KeychainService.saveUserId(longId)
        let result = KeychainService.getUserId()

        #expect(result == longId)
        cleanUp()
    }

    @Test("삭제를 두 번 호출해도 crash 없음")
    func doubleDelete() {
        cleanUp()

        KeychainService.saveUserId("temp")
        KeychainService.deleteUserId()
        KeychainService.deleteUserId()

        #expect(KeychainService.getUserId() == nil)
    }
}
