import SwiftUI

/// 모든 화면 하단에 고정 표시되는 소형 플레이어.
/// .safeAreaInset(edge: .bottom)으로 NavigationStack 밖에서 주입된다.
/// 탭하면 fullScreenCover로 FullPlayerView를 열어 보인다.
struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerViewModel

    var body: some View {
        @Bindable var vm = playerViewModel

        VStack(spacing: 0) {
            // 진행 바
            GeometryReader { geometry in
                let progress = playerViewModel.duration > 0
                    ? playerViewModel.currentTime / playerViewModel.duration
                    : 0
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 2)

            HStack(spacing: 12) {
                // 앨범 아트 (소)
                AsyncImage(url: playerViewModel.currentSong?.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemFill)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)

                // 곡 정보
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerViewModel.currentSong?.title ?? "")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(playerViewModel.currentSong?.artistName ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 재생/일시정지 버튼
                Button {
                    Task {
                        if playerViewModel.isPlaying {
                            await playerViewModel.pause()
                        } else {
                            await playerViewModel.resume()
                        }
                    }
                } label: {
                    Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(playerViewModel.isPlaying ? "일시정지" : "재생")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
        .contentShape(Rectangle())
        .onTapGesture {
            playerViewModel.showFullPlayer = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("미니 플레이어")
        .accessibilityHint("탭하면 전체 플레이어가 열립니다")
        .fullScreenCover(isPresented: $vm.showFullPlayer) {
            FullPlayerView()
        }
    }
}
