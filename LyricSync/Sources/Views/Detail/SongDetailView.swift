import SwiftUI

/// 선택한 곡의 상세 정보와 재생 버튼을 표시하는 화면.
/// PlayerViewModel은 @Environment로 주입받아 재생 상태를 공유한다.
struct SongDetailView: View {
    let song: Song
    @Environment(PlayerViewModel.self) private var playerViewModel

    private var isCurrentSong: Bool {
        playerViewModel.currentSong?.id == song.id
    }

    private var isPlaying: Bool {
        isCurrentSong && playerViewModel.isPlaying
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 앨범 아트 (크게)
                AsyncImage(url: song.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemFill)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 280, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
                .accessibilityLabel("\(song.title) 앨범 아트")

                // 곡 정보
                VStack(spacing: 8) {
                    Text(song.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(song.artistName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let albumTitle = song.albumTitle {
                        Text(albumTitle)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                // 재생/일시정지 버튼
                Button {
                    Task {
                        if isPlaying {
                            await playerViewModel.pause()
                        } else if isCurrentSong {
                            await playerViewModel.resume()
                        } else {
                            await playerViewModel.play(song: song)
                        }
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.accentColor)
                }
                .frame(minWidth: 72, minHeight: 72)
                .accessibilityLabel(isPlaying ? "일시정지" : "재생")
                .accessibilityHint(isPlaying ? "\(song.title) 재생 일시정지" : "\(song.title) 재생 시작")

                if let errorMessage = playerViewModel.errorMessage, isCurrentSong {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer(minLength: 80)
            }
            .padding(.top, 24)
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
