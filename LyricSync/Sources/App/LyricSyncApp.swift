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
    @State private var checkStartedAt: Date = Date()
    @State private var showRetry: Bool = false
    @State private var musicAuthStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus

    private let authService = AuthService()
    private let authTimeout: TimeInterval = 8

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingAuth {
                    authCheckingView
                } else if !isAuthenticated {
                    LoginView {
                        isAuthenticated = true
                        Task { await fetchDbUserId() }
                    }
                } else if musicAuthStatus != .authorized {
                    MusicPermissionGateView {
                        musicAuthStatus = MusicAuthorization.currentStatus
                    }
                } else {
                    mainContent
                }
            }
            .task {
                await checkAuthWithTimeout()
                if musicAuthStatus == .notDetermined {
                    musicAuthStatus = await MusicAuthorization.request()
                }
            }
        }
    }

    // MARK: - 인증 확인 진행 화면 (P0 #1)

    private var authCheckingView: some View {
        VStack(spacing: 16) {
            ProgressView("로그인 정보 확인 중...")
                .tint(Color.appAccent)
            if showRetry {
                Button("다시 시도") {
                    Task {
                        showRetry = false
                        await checkAuthWithTimeout()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // 5초 후 재시도 버튼 노출
            try? await Task.sleep(for: .seconds(5))
            if isCheckingAuth { showRetry = true }
        }
    }

    private var mainContent: some View {
        TabView {
            // 차트 탭
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
                            .accessibilityLabel("설정 열기")
                        }
                    }
            }
            .tabItem {
                Label("차트", systemImage: "chart.line.uptrend.xyaxis")
            }

            // 내 번역 탭
            NavigationStack {
                MyTranslationsListView()
                    .navigationTitle("내 번역")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("내 번역", systemImage: "character.book.closed")
            }
        }
        .tint(Color.appAccent)
        .environment(playerViewModel)
        .environment(\.dbUserId, dbUserId)
        // P0 #3 — 글로벌 하단 미니플레이어 (safeAreaInset, 64pt + 진행바 2pt)
        .safeAreaInset(edge: .bottom) {
            if playerViewModel.currentSong != nil {
                FloatingPlayerButton()
                    .environment(playerViewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - 인증 흐름

    /// P0 #1 — checkCredential 을 8초 타임아웃으로 감싸 무한 대기 차단.
    private func checkAuthWithTimeout() async {
        isCheckingAuth = true
        checkStartedAt = Date()

        let result: CredentialCheckResult = await withTimeout(seconds: authTimeout) {
            await authService.checkCredential()
        } onTimeout: {
            AppLogger.warn("인증 확인 타임아웃 (\(authTimeout)s) → invalid 처리", category: .network)
            return .invalid
        }

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

// MARK: - withTimeout helper (P0 #1)

/// 비동기 작업을 타임아웃과 함께 실행. 타임아웃 시 `onTimeout` 결과를 반환.
private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async -> T,
    onTimeout: @escaping @Sendable () -> T
) async -> T {
    await withTaskGroup(of: T.self) { group in
        group.addTask { await operation() }
        group.addTask {
            try? await Task.sleep(for: .seconds(seconds))
            return onTimeout()
        }
        let first = await group.next() ?? onTimeout()
        group.cancelAll()
        return first
    }
}
