import SwiftUI
import MusicKit

/// 앱 진입점.
/// Apple 로그인 인증 분기 + MusicKit 권한 요청 + PlayerViewModel 주입.
@main
struct LyricSyncApp: App {
    @State private var playerViewModel = PlayerViewModel()
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true
    @State private var dbUserId: Int?

    private let authService = AuthService()

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingAuth {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isAuthenticated {
                    mainContent
                } else {
                    LoginView {
                        isAuthenticated = true
                        Task { await fetchDbUserId() }
                    }
                }
            }
            .task {
                await checkAuth()
                _ = await MusicAuthorization.request()
            }
        }
    }

    private var mainContent: some View {
        NavigationStack {
            ChartListView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView(isAuthenticated: $isAuthenticated)
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
        .safeAreaInset(edge: .bottom) {
            if playerViewModel.currentSong != nil {
                MiniPlayerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(playerViewModel)
        .environment(\.dbUserId, dbUserId)
    }

    private func checkAuth() async {
        let result = await authService.checkCredential()
        switch result {
        case .valid:
            isAuthenticated = true
            await fetchDbUserId()
        case .invalid:
            isAuthenticated = false
        }
        isCheckingAuth = false
    }

    private func fetchDbUserId() async {
        guard let appleUserId = KeychainService.getUserId() else { return }
        dbUserId = await authService.fetchUserId(appleUserId: appleUserId)
    }
}

// MARK: - dbUserId Environment Key

private struct DbUserIdKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var dbUserId: Int? {
        get { self[DbUserIdKey.self] }
        set { self[DbUserIdKey.self] = newValue }
    }
}
