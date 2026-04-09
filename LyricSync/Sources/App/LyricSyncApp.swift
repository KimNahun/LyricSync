import SwiftUI
import MusicKit

/// 앱 진입점.
/// MusicKit 권한을 앱 시작 시 요청하고, PlayerViewModel을 단일 인스턴스로 생성하여
/// @Environment로 모든 하위 뷰에 주입한다.
@main
struct LyricSyncApp: App {
    @State private var playerViewModel = PlayerViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChartListView()
            }
            .safeAreaInset(edge: .bottom) {
                if playerViewModel.currentSong != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .environment(playerViewModel)
            .task {
                _ = await MusicAuthorization.request()
            }
        }
    }
}
