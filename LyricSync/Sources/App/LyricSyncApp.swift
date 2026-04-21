import SwiftUI
import MusicKit

/// 앱 진입점.
/// Apple 로그인 인증 분기 + MusicKit 권한 요청 + PlayerViewModel 주입.
@main
struct LyricSyncApp: App {
    @State private var playerViewModel = PlayerViewModel()
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true

    private let authService = AuthService()

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingAuth {
                    // 인증 확인 중 스플래시
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isAuthenticated {
                    // 메인 화면
                    mainContent
                } else {
                    // 로그인 화면
                    LoginView {
                        isAuthenticated = true
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
    }

    private func checkAuth() async {
        let result = await authService.checkCredential()
        switch result {
        case .valid:
            isAuthenticated = true
        case .invalid:
            isAuthenticated = false
        }
        isCheckingAuth = false
    }
}
