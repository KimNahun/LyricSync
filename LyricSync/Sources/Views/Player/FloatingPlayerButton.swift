import SwiftUI

/// 드래그 가능한 원형 플로팅 플레이어 버튼.
/// 현재 재생 곡의 앨범 아트를 원형으로 표시하고, 원형 프로그레스 링을 표시한다.
/// 탭하면 FullPlayerView를 열고, 드래그로 화면 내 위치를 이동할 수 있다.
struct FloatingPlayerButton: View {
    @Environment(PlayerViewModel.self) private var playerViewModel

    /// 버튼 위치 (화면 좌표). AppStorage로 앱 재시작 후에도 유지.
    @AppStorage("floatingPlayerX") private var posX: Double = -1
    @AppStorage("floatingPlayerY") private var posY: Double = -1
    @State private var dragOffset: CGSize = .zero

    private let buttonSize: CGFloat = 56

    var body: some View {
        @Bindable var vm = playerViewModel

        GeometryReader { geo in
            let defaultX = geo.size.width - buttonSize - 16
            let defaultY = geo.size.height - buttonSize - 100
            let x = posX < 0 ? defaultX : posX
            let y = posY < 0 ? defaultY : posY

            playerButton
                .position(
                    x: x + dragOffset.width + buttonSize / 2,
                    y: y + dragOffset.height + buttonSize / 2
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            let newX = x + value.translation.width
                            let newY = y + value.translation.height
                            let snapped = snapToEdge(
                                x: newX, y: newY,
                                screenWidth: geo.size.width,
                                screenHeight: geo.size.height
                            )
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                posX = snapped.x
                                posY = snapped.y
                            }
                            dragOffset = .zero
                        }
                )
                .fullScreenCover(isPresented: $vm.showFullPlayer) {
                    FullPlayerView()
                }
        }
        .ignoresSafeArea()
    }

    // MARK: - 버튼 UI

    private var playerButton: some View {
        Button {
            playerViewModel.showFullPlayer = true
        } label: {
            ZStack {
                // 앨범 아트 배경
                if let url = playerViewModel.currentSong?.artworkURL {
                    CachedAsyncImage(url: url, size: buttonSize, cornerRadius: buttonSize / 2)
                } else {
                    Circle()
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: buttonSize, height: buttonSize)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }

                // 원형 프로그레스 링
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 3)
                    .frame(width: buttonSize + 4, height: buttonSize + 4)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: buttonSize + 4, height: buttonSize + 4)
                    .rotationEffect(.degrees(-90))

                // 재생/일시정지 오버레이
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .offset(x: buttonSize / 2 - 4, y: buttonSize / 2 - 4)
            }
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    // MARK: - 계산

    private var progress: CGFloat {
        guard playerViewModel.duration > 0 else { return 0 }
        return playerViewModel.currentTime / playerViewModel.duration
    }

    /// 드래그 종료 시 가장 가까운 화면 가장자리로 스냅한다.
    private func snapToEdge(x: CGFloat, y: CGFloat, screenWidth: CGFloat, screenHeight: CGFloat) -> CGPoint {
        let margin: CGFloat = 8
        let centerX = x + buttonSize / 2

        // 좌우 가장자리 스냅
        let snappedX: CGFloat
        if centerX < screenWidth / 2 {
            snappedX = margin
        } else {
            snappedX = screenWidth - buttonSize - margin
        }

        // Y는 상하 범위 제한
        let minY: CGFloat = 60
        let maxY = screenHeight - buttonSize - 100
        let snappedY = min(max(y, minY), maxY)

        return CGPoint(x: snappedX, y: snappedY)
    }
}
