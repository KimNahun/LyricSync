import SwiftUI

/// 드래그 가능한 원형 플로팅 플레이어 버튼.
/// 현재 재생 곡의 앨범 아트를 원형으로 표시하고, 원형 프로그레스 링을 표시한다.
/// 탭하면 FullPlayerView를 열고, 드래그로 화면 내 위치를 이동할 수 있다.
struct FloatingPlayerButton: View {
    @Environment(PlayerViewModel.self) private var playerViewModel

    @AppStorage("floatingPlayerX") private var posX: Double = -1
    @AppStorage("floatingPlayerY") private var posY: Double = -1
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    private let buttonSize: CGFloat = 56

    var body: some View {
        @Bindable var vm = playerViewModel

        GeometryReader { geo in
            let defaultX = geo.size.width - buttonSize - 16
            let defaultY = geo.size.height - buttonSize - 100
            let baseX = posX < 0 ? defaultX : posX
            let baseY = posY < 0 ? defaultY : posY

            playerButton
                .position(
                    x: baseX + dragOffset.width + buttonSize / 2,
                    y: baseY + dragOffset.height + buttonSize / 2
                )
                .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: dragOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: posX)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: posY)
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            let newX = baseX + value.translation.width
                            let newY = baseY + value.translation.height
                            let snapped = snapToEdge(
                                x: newX, y: newY,
                                screenWidth: geo.size.width,
                                screenHeight: geo.size.height
                            )
                            dragOffset = .zero
                            isDragging = false
                            posX = snapped.x
                            posY = snapped.y
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
            guard !isDragging else { return }
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
                    .stroke(Color.appAccent.opacity(0.15), lineWidth: 3)
                    .frame(width: buttonSize + 4, height: buttonSize + 4)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
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

    private func snapToEdge(x: CGFloat, y: CGFloat, screenWidth: CGFloat, screenHeight: CGFloat) -> CGPoint {
        let margin: CGFloat = 8
        let centerX = x + buttonSize / 2
        let snappedX = centerX < screenWidth / 2 ? margin : screenWidth - buttonSize - margin
        let minY: CGFloat = 60
        let maxY = screenHeight - buttonSize - 100
        let snappedY = min(max(y, minY), maxY)
        return CGPoint(x: snappedX, y: snappedY)
    }
}
