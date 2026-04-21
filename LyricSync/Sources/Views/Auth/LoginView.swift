import SwiftUI
import AuthenticationServices

/// Apple 로그인 화면.
struct LoginView: View {
    var onLoginSuccess: () -> Void

    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    private let authService = AuthService()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 앱 아이콘 + 설명
            VStack(spacing: 16) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)

                Text("LyricSync")
                    .font(.largeTitle.weight(.bold))

                Text("팝송 가사를 번역하며\n영어를 배워보세요")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // 에러 메시지
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
            }

            // Apple 로그인 버튼
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleResult(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    private func handleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "인증 정보를 가져올 수 없습니다."
                return
            }

            let userId = credential.user
            let email = credential.email
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let displayName = fullName.isEmpty ? nil : fullName

            AppLogger.info("Apple 로그인 성공: \(userId.prefix(8))..., email=\(email ?? "nil")", category: .network)

            // Keychain 저장
            KeychainService.saveUserId(userId)

            // Supabase 등록 (비동기, 실패해도 로그인은 진행)
            Task {
                await authService.registerUser(
                    appleUserId: userId,
                    email: email,
                    displayName: displayName
                )
            }

            onLoginSuccess()

        case .failure(let error):
            // 유저가 취소한 경우는 에러 표시하지 않음
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "로그인에 실패했습니다: \(error.localizedDescription)"
            AppLogger.error("Apple 로그인 실패: \(error)", category: .network)
        }
    }
}
