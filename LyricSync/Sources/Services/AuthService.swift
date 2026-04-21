import Foundation
import AuthenticationServices

/// credential 상태 결과.
enum CredentialCheckResult: Sendable {
    case valid(String)   // userIdentifier
    case invalid
}

/// Apple 로그인 credential 확인 + Supabase 유저 등록/삭제를 담당하는 Service.
actor AuthService {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession

    init(
        baseURL: String = SupabaseConfig.baseURL,
        apiKey: String = SupabaseConfig.anonKey,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    /// Keychain에 저장된 userIdentifier의 credential 상태를 확인한다.
    func checkCredential() async -> CredentialCheckResult {
        guard let userId = KeychainService.getUserId() else {
            AppLogger.info("Keychain에 userId 없음", category: .network)
            return .invalid
        }

        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userId)
            switch state {
            case .authorized:
                AppLogger.info("Apple credential 유효: \(userId.prefix(8))...", category: .network)
                return .valid(userId)
            case .revoked:
                AppLogger.warn("Apple credential 취소됨", category: .network)
                KeychainService.deleteUserId()
                return .invalid
            case .notFound:
                AppLogger.warn("Apple credential 없음", category: .network)
                KeychainService.deleteUserId()
                return .invalid
            @unknown default:
                KeychainService.deleteUserId()
                return .invalid
            }
        } catch {
            AppLogger.error("credential 확인 실패: \(error.localizedDescription)", category: .network)
            // 네트워크 에러 등 → 일단 유효하다고 판단 (오프라인 지원)
            return .valid(userId)
        }
    }

    /// Supabase에 유저를 등록한다 (upsert).
    func registerUser(appleUserId: String, email: String?, displayName: String?) async {
        guard let url = URL(string: "\(baseURL)/users") else { return }

        var body: [String: Any] = ["apple_user_id": appleUserId]
        if let email { body["email"] = email }
        if let displayName { body["display_name"] = displayName }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        do {
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            AppLogger.info("유저 등록 응답: \(status)", category: .supabase)
        } catch {
            AppLogger.error("유저 등록 실패: \(error.localizedDescription)", category: .supabase)
        }
    }

    /// Supabase에서 유저를 삭제한다.
    func deleteUser(appleUserId: String) async {
        let urlString = "\(baseURL)/users?apple_user_id=eq.\(appleUserId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            AppLogger.info("유저 삭제 응답: \(status)", category: .supabase)
        } catch {
            AppLogger.error("유저 삭제 실패: \(error.localizedDescription)", category: .supabase)
        }

        KeychainService.deleteUserId()
    }
}
