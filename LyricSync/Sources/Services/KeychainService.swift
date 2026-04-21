import Foundation
import Security

/// Keychain에 Apple userIdentifier를 저장/조회/삭제하는 유틸리티.
/// 앱 삭제 시 같이 삭제됨 (iOS 10.3+). 재설치 후 재로그인 시 동일 userIdentifier 반환.
enum KeychainService {
    private static let service = "com.nahun.LyricSync"
    private static let account = "apple_user_id"

    /// userIdentifier를 Keychain에 저장한다.
    static func saveUserId(_ userId: String) {
        // 기존 값 삭제 후 저장
        deleteUserId()

        guard let data = userId.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            AppLogger.error("Keychain 저장 실패: \(status)", category: .network)
        }
    }

    /// Keychain에서 userIdentifier를 조회한다. 없으면 nil.
    static func getUserId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let userId = String(data: data, encoding: .utf8) else {
            return nil
        }

        return userId
    }

    /// Keychain에서 userIdentifier를 삭제한다.
    static func deleteUserId() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
