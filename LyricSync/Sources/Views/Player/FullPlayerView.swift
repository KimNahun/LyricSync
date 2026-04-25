import SwiftUI

/// 전체 화면 플레이어 — `sheet(presentationDetents: [.large])` 로 표시.
/// 슬라이더 seek, 가사 싱크 하이라이트, 자동 스크롤, 통합 표시 모드(AI 동시/AI 가림)를 제공한다.
/// 공부 모드는 SongDetailView 에서만 동작 (사용자 번역 입력 흐름 때문).
struct FullPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(\.dbUserId) private var dbUserId
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 컴팩트 헤더 (드래그 인디케이터는 sheet가 자동 제공)
            compactPlayerBar

            // 번역 모드 토글 (번역이 있을 때만)
            if playerViewModel.hasTranslation {
                modeBar
            }

            Divider()

            // 가사 영역
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    lyricSection(proxy: proxy)
                        .onChange(of: playerViewModel.currentLyricIndex) { _, newIndex in
                            guard let index = newIndex,
                                  !playerViewModel.isUserScrolling,
                                  !playerViewModel.isDragging else { return }
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(index, anchor: .center)
                            }
                        }

                    // P1 #9 — 현재 줄로 이동 칩
                    if playerViewModel.isUserScrolling, let cur = playerViewModel.currentLyricIndex {
                        currentLineChip {
                            playerViewModel.resumeAutoScroll()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(cur, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 컴팩트 플레이어 바

    private var compactPlayerBar: some View {
        @Bindable var vm = playerViewModel

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: playerViewModel.currentSong?.artworkURL, size: 56, cornerRadius: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(playerViewModel.currentSong?.title ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1...2)
                        .minimumScaleFactor(0.85)

                    Text(playerViewModel.currentSong?.artistName ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
                        .foregroundStyle(Color.appAccent)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel(playerViewModel.isPlaying ? "일시정지" : "재생")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // P1 #13 — 슬라이더 + caption + monospaced
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
                .tint(Color.appAccent)
                .padding(.top, 4)
                .contentShape(Rectangle())
                .accessibilityLabel("재생 위치")
                .accessibilityValue("\(TimeFormatUtil.format(playerViewModel.currentTime)) / \(TimeFormatUtil.format(playerViewModel.duration))")

                HStack {
                    Text(TimeFormatUtil.format(playerViewModel.currentTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(TimeFormatUtil.format(playerViewModel.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 모드 바

    private var availableModes: [DisplayMode] {
        var modes: [DisplayMode] = [.aiSimultaneous, .aiHidden]
        // FullPlayerView 에서 study 모드 제공은 dbUserId 가 있고 가사 입력 흐름이 SongDetailView 에 있으므로 보류.
        return modes
    }

    @ViewBuilder
    private var modeBar: some View {
        @Bindable var vm = playerViewModel

        Picker("번역 모드", selection: $vm.displayMode) {
            ForEach(availableModes) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .accessibilityLabel("AI 번역 표시 모드")
        .onAppear {
            // FullPlayerView 는 study 를 지원하지 않으므로 ai* 로 보정
            if !availableModes.contains(vm.displayMode) {
                vm.displayMode = .aiSimultaneous
            }
        }
    }

    // MARK: - 현재 줄로 이동 칩

    private func currentLineChip(action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.to.line")
                    .font(.caption.weight(.semibold))
                Text("현재 줄")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.appAccent, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .accessibilityLabel("현재 재생 중인 가사 줄로 이동")
        .transition(.opacity.combined(with: .scale))
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
            lyricUnavailableView(
                title: "인스트루멘탈",
                description: "이 곡은 보컬이 없는 인스트루멘탈입니다.",
                systemImage: "pianokeys",
                showRetry: false
            )

        case .notFound:
            lyricUnavailableView(
                title: "가사를 찾을 수 없어요",
                description: "이 곡에 대한 싱크 가사가 lrclib 와 Supabase 모두에 없습니다.",
                systemImage: "text.slash",
                showRetry: true
            )

        case .error(let message):
            lyricUnavailableView(
                title: "가사를 불러올 수 없어요",
                description: message,
                systemImage: "exclamationmark.circle",
                showRetry: true
            )
        }
    }

    private func syncedLyricView(lines: [LyricLine], proxy: ScrollViewProxy) -> some View {
        let translatedLines = playerViewModel.translatedLines

        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    VStack(spacing: 4) {
                        LyricLineView(
                            line: line,
                            isActive: playerViewModel.currentLyricIndex == index,
                            onTap: {
                                Task { await playerViewModel.seek(to: line.timestamp) }
                            }
                        )

                        if let tLines = translatedLines, index < tLines.count {
                            translatedLineView(
                                text: tLines[index].text,
                                index: index,
                                isActive: playerViewModel.currentLyricIndex == index
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    .id(index)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { _ in playerViewModel.onUserScrollBegan() }
                .onEnded { _ in playerViewModel.onUserScrollEnded() }
        )
    }

    // MARK: - AI 번역 줄 표시 (P0 #4)

    @ViewBuilder
    private func translatedLineView(text: String, index: Int, isActive: Bool) -> some View {
        let isRevealed = playerViewModel.revealedLineIndices.contains(index)

        switch playerViewModel.displayMode {
        case .aiSimultaneous:
            Text(text)
                .font(.footnote)
                .foregroundStyle(isActive ? Color.appAccent : .secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

        case .aiHidden:
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    playerViewModel.toggleReveal(at: index)
                }
            } label: {
                if isRevealed {
                    HStack(spacing: 6) {
                        Text(text)
                            .font(.footnote)
                            .foregroundStyle(isActive ? Color.appAccent : .secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))

                        Image(systemName: "eye.slash")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8)
                } else {
                    Text("번역 보기")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)
            .accessibilityLabel(isRevealed ? "번역 다시 가리기" : "번역 공개")

        case .study:
            EmptyView()
        }
    }

    @ViewBuilder
    private func lyricUnavailableView(title: String, description: String, systemImage: String, showRetry: Bool) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            if showRetry {
                Button("다시 시도") {
                    playerViewModel.retryLyricFetch()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
