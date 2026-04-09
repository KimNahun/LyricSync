import SwiftUI

/// 전체 화면 플레이어.
/// 슬라이더 seek, 가사 싱크 하이라이트, 자동 스크롤을 제공한다.
struct FullPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = playerViewModel

        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // 상단: 앨범 아트 + 곡 정보
                    headerSection

                    // 슬라이더 + 시간 표시
                    sliderSection

                    // 재생/일시정지 버튼
                    playbackButton

                    // 가사 영역
                    lyricSection(proxy: proxy)
                }
                .padding(.horizontal, 20)
                .onChange(of: playerViewModel.currentLyricIndex) { _, newIndex in
                    guard let index = newIndex,
                          !playerViewModel.isUserScrolling,
                          !playerViewModel.isDragging else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("플레이어 닫기")
                }
            }
        }
    }

    // MARK: - 상단 헤더

    private var headerSection: some View {
        VStack(spacing: 12) {
            AsyncImage(url: playerViewModel.currentSong?.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemFill)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.title)
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 220, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 8)
            .padding(.top, 8)
            .accessibilityLabel("\(playerViewModel.currentSong?.title ?? "") 앨범 아트")

            VStack(spacing: 4) {
                Text(playerViewModel.currentSong?.title ?? "")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(playerViewModel.currentSong?.artistName ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 슬라이더

    private var sliderSection: some View {
        @Bindable var vm = playerViewModel

        return VStack(spacing: 4) {
            Slider(
                value: $vm.sliderValue,
                in: 0...(playerViewModel.duration > 0 ? playerViewModel.duration : 1),
                onEditingChanged: { editing in
                    if editing {
                        playerViewModel.startDragging()
                    } else {
                        Task {
                            await playerViewModel.stopDragging(to: playerViewModel.sliderValue)
                        }
                    }
                }
            )
            .tint(.accentColor)
            .accessibilityLabel("재생 위치 슬라이더")
            .accessibilityValue(TimeFormatUtil.format(playerViewModel.currentTime))

            HStack {
                Text(TimeFormatUtil.format(playerViewModel.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(TimeFormatUtil.format(playerViewModel.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.top, 16)
    }

    // MARK: - 재생 버튼

    private var playbackButton: some View {
        Button {
            Task {
                if playerViewModel.isPlaying {
                    await playerViewModel.pause()
                } else {
                    await playerViewModel.resume()
                }
            }
        } label: {
            Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(Color.accentColor)
        }
        .frame(minWidth: 60, minHeight: 60)
        .padding(.vertical, 12)
        .accessibilityLabel(playerViewModel.isPlaying ? "일시정지" : "재생")
    }

    // MARK: - 가사 영역

    @ViewBuilder
    private func lyricSection(proxy: ScrollViewProxy) -> some View {
        Divider()
            .padding(.bottom, 8)

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
                    .padding(.bottom, 80)
            }

        case .instrumental:
            lyricMessageView(
                icon: "pianokeys",
                message: "이 곡은 인스트루멘탈입니다"
            )

        case .notFound:
            lyricMessageView(
                icon: "text.slash",
                message: "가사를 찾을 수 없습니다"
            )

        case .error(let message):
            lyricMessageView(
                icon: "exclamationmark.circle",
                message: message
            )
        }
    }

    private func syncedLyricView(lines: [LyricLine], proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 4) {
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
            .padding(.vertical, 12)
            .padding(.bottom, 80)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { _ in
                    playerViewModel.onUserScrollBegan()
                }
                .onEnded { _ in
                    playerViewModel.onUserScrollEnded()
                }
        )
    }

    private func lyricMessageView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }
}
