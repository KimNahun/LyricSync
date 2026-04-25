import SwiftUI

/// 하단 막대형 미니 플레이어.
/// `safeAreaInset(edge: .bottom)` 로 글로벌 하단 고정. 탭하면 풀 플레이어 sheet 등장.
/// 단, 같은 곡의 SongDetailView 가 이미 NavigationStack 에 push 된 상태면 sheet 띄우지 않음(P0 #2 옵션 B).
///
/// (파일명 `FloatingPlayerButton.swift` 는 pbxproj 안정성 위해 유지. 실제 구현은 막대형 미니플레이어.)
struct FloatingPlayerButton: View {
    @Environment(PlayerViewModel.self) private var playerViewModel

    private let barHeight: CGFloat = 64

    var body: some View {
        @Bindable var vm = playerViewModel

        VStack(spacing: 0) {
            // 상단 진행 바 (2pt)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 2)
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: geo.size.width * progress, height: 2)
                }
            }
            .frame(height: 2)

            // 본체: 아트 + 곡정보 + 재생/일시정지
            HStack(spacing: 12) {
                Button {
                    handleTap()
                } label: {
                    HStack(spacing: 12) {
                        if let url = playerViewModel.currentSong?.artworkURL {
                            CachedAsyncImage(url: url, size: 40, cornerRadius: 6)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .foregroundStyle(.secondary)
                                }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(playerViewModel.currentSong?.title ?? "")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(playerViewModel.currentSong?.artistName ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(playerViewModel.currentSong?.title ?? "재생 중"), \(playerViewModel.currentSong?.artistName ?? "")")
                .accessibilityHint("탭하면 풀 플레이어를 엽니다")

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
                        .font(.title3)
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playerViewModel.isPlaying ? "일시정지" : "재생")
            }
            .padding(.horizontal, 12)
            .frame(height: barHeight)
            .background(.regularMaterial)
        }
        .sheet(isPresented: $vm.showFullPlayer) {
            FullPlayerView()
        }
    }

    private var progress: CGFloat {
        guard playerViewModel.duration > 0 else { return 0 }
        return CGFloat(playerViewModel.currentTime / playerViewModel.duration)
    }

    /// 탭 동작: 같은 곡의 SongDetail 이 이미 push 되어 있으면 sheet 무시(자연스레 그 화면이 보임).
    private func handleTap() {
        if let detailID = playerViewModel.currentDetailSongID,
           detailID == playerViewModel.currentSong?.id {
            // 이미 같은 곡의 상세 화면을 보고 있음. sheet 안 띄움.
            return
        }
        playerViewModel.showFullPlayer = true
    }
}
