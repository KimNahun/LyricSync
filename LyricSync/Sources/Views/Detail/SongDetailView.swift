import SwiftUI

/// 선택한 곡의 상세 정보 + 가사를 표시하는 화면.
/// 상단 1줄에 컴팩트 곡 정보, 나머지 전체를 가사로 채운다.
struct SongDetailView: View {
    let song: Song
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(\.dismiss) private var dismiss

    private var isCurrentSong: Bool {
        playerViewModel.currentSong?.id == song.id
    }

    private var isPlaying: Bool {
        isCurrentSong && playerViewModel.isPlaying
    }

    var body: some View {
        VStack(spacing: 0) {
            // 상단: 컴팩트 곡 정보 + 재생 버튼
            compactHeader

            Divider()

            // 가사 영역 (나머지 전체)
            if isCurrentSong {
                currentSongLyrics
            } else {
                notPlayingView
            }
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 컴팩트 헤더 (1줄)

    private var compactHeader: some View {
        HStack(spacing: 12) {
            // 앨범 아트
            AsyncImage(url: song.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.tertiarySystemFill)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 곡 정보
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 44, height: 44)
            .accessibilityLabel(isPlaying ? "일시정지" : "재생")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 현재 재생 중인 곡의 가사

    private var currentSongLyrics: some View {
        ScrollViewReader { proxy in
            Group {
                switch playerViewModel.lyricState {
                case .loading:
                    ProgressView("가사 불러오는 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .synced(let lines):
                    syncedLyricView(lines: lines, proxy: proxy)

                case .plain(let text):
                    ScrollView {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                    }

                case .instrumental:
                    lyricMessageView(icon: "pianokeys", message: "인스트루멘탈")

                case .notFound:
                    lyricMessageView(icon: "text.slash", message: "가사를 찾을 수 없습니다")

                case .error(let message):
                    lyricMessageView(icon: "exclamationmark.circle", message: message)
                }
            }
            .onChange(of: playerViewModel.currentLyricIndex) { _, newIndex in
                guard let index = newIndex,
                      !playerViewModel.isUserScrolling else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func syncedLyricView(lines: [LyricLine], proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    LyricLineView(
                        line: line,
                        isActive: playerViewModel.currentLyricIndex == index,
                        onTap: {
                            Task {
                                await playerViewModel.seek(to: line.timestamp)
                            }
                        }
                    )
                    .id(index)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .padding(.bottom, 80)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { _ in playerViewModel.onUserScrollBegan() }
                .onEnded { _ in playerViewModel.onUserScrollEnded() }
        )
    }

    // MARK: - 재생 전 안내

    private var notPlayingView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "play.circle")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)

            Text("재생 버튼을 눌러\n가사를 확인하세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func lyricMessageView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
