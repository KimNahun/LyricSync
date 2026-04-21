import SwiftUI

/// 모든 화면 하단에 고정 표시되는 소형 플레이어.
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
                // 앨범 아트
                AsyncImage(url: playerViewModel.currentSong?.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.tertiarySystemFill)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // 곡 정보
                VStack(alignment: .leading, spacing: 1) {
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

                // 재생/일시정지
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
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .onTapGesture {
            playerViewModel.showFullPlayer = true
        }
        .fullScreenCover(isPresented: $vm.showFullPlayer) {
            FullPlayerView()
        }
    }
}
