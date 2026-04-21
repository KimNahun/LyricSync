import SwiftUI

/// 전체 화면 플레이어.
/// 슬라이더 seek, 가사 싱크 하이라이트, 자동 스크롤, 번역 모드를 제공한다.
struct FullPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = playerViewModel

        NavigationStack {
            VStack(spacing: 0) {
                // 상단: 컴팩트 플레이어 바 (아트+곡정보+슬라이더 1줄)
                compactPlayerBar

                // 번역 모드 토글 (번역이 있을 때만)
                if playerViewModel.hasTranslation {
                    translationModeToggle
                }

                Divider()

                // 가사 영역 (나머지 전체)
                ScrollViewReader { proxy in
                    lyricSection(proxy: proxy)
                        .onChange(of: playerViewModel.currentLyricIndex) { _, newIndex in
                            guard let index = newIndex,
                                  !playerViewModel.isUserScrolling,
                                  !playerViewModel.isDragging else { return }
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(index, anchor: .center)
                            }
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

    // MARK: - 컴팩트 플레이어 바 (1줄)

    private var compactPlayerBar: some View {
        @Bindable var vm = playerViewModel

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 앨범 아트 (작게)
                AsyncImage(url: playerViewModel.currentSong?.artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemFill)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // 곡 정보 + 재생 버튼
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
                    Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel(playerViewModel.isPlaying ? "일시정지" : "재생")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // 슬라이더
            VStack(spacing: 2) {
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

                HStack {
                    Text(TimeFormatUtil.format(playerViewModel.currentTime))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Spacer()

                    Text(TimeFormatUtil.format(playerViewModel.duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 번역 모드 토글

    private var translationModeToggle: some View {
        @Bindable var vm = playerViewModel

        return Picker("번역 모드", selection: $vm.translationMode) {
            Label("동시 표시", systemImage: "text.alignleft")
                .labelStyle(.titleOnly)
                .tag(TranslationMode.simultaneous)
            Label("가림 모드", systemImage: "eye.slash")
                .labelStyle(.titleOnly)
                .tag(TranslationMode.hidden)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - 가사 영역

    @ViewBuilder
    private func lyricSection(proxy: ScrollViewProxy) -> some View {
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
            lyricMessageView(icon: "pianokeys", message: "이 곡은 인스트루멘탈입니다")

        case .notFound:
            lyricMessageView(icon: "text.slash", message: "가사를 찾을 수 없습니다")

        case .error(let message):
            lyricMessageView(icon: "exclamationmark.circle", message: message)
        }
    }

    private func syncedLyricView(lines: [LyricLine], proxy: ScrollViewProxy) -> some View {
        let translatedLines = playerViewModel.translatedLines

        return ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    VStack(spacing: 3) {
                        // 원본 가사
                        LyricLineView(
                            line: line,
                            isActive: playerViewModel.currentLyricIndex == index,
                            onTap: {
                                Task {
                                    await playerViewModel.seek(to: line.timestamp)
                                }
                            }
                        )

                        // 번역 가사
                        if let tLines = translatedLines, index < tLines.count {
                            translatedLineView(
                                text: tLines[index].text,
                                index: index,
                                isActive: playerViewModel.currentLyricIndex == index
                            )
                        }
                    }
                    .id(index)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
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

    // MARK: - 번역 줄 표시

    @ViewBuilder
    private func translatedLineView(text: String, index: Int, isActive: Bool) -> some View {
        let isRevealed = playerViewModel.revealedLineIndices.contains(index)

        switch playerViewModel.translationMode {
        case .simultaneous:
            Text(text)
                .font(.footnote)
                .foregroundStyle(isActive ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)

        case .hidden:
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    playerViewModel.toggleReveal(at: index)
                }
            } label: {
                HStack(spacing: 6) {
                    if isRevealed {
                        Text(text)
                            .font(.footnote)
                            .foregroundStyle(isActive ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        Text("번역 보기")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray5))
                            )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 2)
            .accessibilityLabel(isRevealed ? "번역 숨기기" : "번역 보기")
        }
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
    }
}
