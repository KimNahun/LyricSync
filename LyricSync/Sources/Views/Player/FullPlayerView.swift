import SwiftUI

/// 전체 화면 플레이어.
/// 슬라이더 seek, 가사 싱크 하이라이트, 자동 스크롤, 번역 모드를 제공한다.
struct FullPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = playerViewModel

        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    headerSection
                    sliderSection
                    playbackButton

                    // 번역 모드 토글 (번역이 있을 때만 표시)
                    if playerViewModel.hasTranslation {
                        translationModeToggle
                    }

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

    // MARK: - 번역 모드 토글

    private var translationModeToggle: some View {
        @Bindable var vm = playerViewModel

        return Picker("번역 모드", selection: $vm.translationMode) {
            Text("동시 표시").tag(TranslationMode.simultaneous)
            Text("가림 모드").tag(TranslationMode.hidden)
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 8)
        .accessibilityLabel("번역 표시 모드 선택")
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
            LazyVStack(spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    VStack(spacing: 2) {
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

    // MARK: - 번역 줄 표시

    @ViewBuilder
    private func translatedLineView(text: String, index: Int, isActive: Bool) -> some View {
        switch playerViewModel.translationMode {
        case .simultaneous:
            // 동시 표시: 항상 번역 보임
            Text(text)
                .font(.caption)
                .foregroundStyle(isActive ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)

        case .hidden:
            // 가림 모드: 눈 버튼으로 개별 공개
            HStack(spacing: 4) {
                if playerViewModel.revealedLineIndices.contains(index) {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(isActive ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                } else {
                    Text("· · · · ·")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }

                // 눈 버튼 — 자동 스크롤을 중지시키지 않음
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        playerViewModel.toggleReveal(at: index)
                    }
                } label: {
                    Image(systemName: playerViewModel.revealedLineIndices.contains(index) ? "eye.fill" : "eye.slash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playerViewModel.revealedLineIndices.contains(index) ? "번역 숨기기" : "번역 보기")
            }
            .padding(.bottom, 4)
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
        .padding(.bottom, 80)
    }
}
