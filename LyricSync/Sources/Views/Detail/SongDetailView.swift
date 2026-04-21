import SwiftUI

/// 곡 상세 + 재생 + 가사 + 번역을 통합한 단일 화면.
struct SongDetailView: View {
    let song: Song
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(\.dbUserId) private var dbUserId

    @State private var userTranslations: [Int: String] = [:]  // index → 유저 번역
    @State private var editingLineIndex: Int?
    @State private var showTranslationInput = false

    private let userTranslationService = UserTranslationService()

    private var isCurrentSong: Bool {
        playerViewModel.currentSong?.id == song.id
    }

    private var isPlaying: Bool {
        isCurrentSong && playerViewModel.isPlaying
    }

    var body: some View {
        @Bindable var vm = playerViewModel

        VStack(spacing: 0) {
            playerHeader

            if isCurrentSong && playerViewModel.hasTranslation {
                translationModeToggle
            }

            Divider()

            if isCurrentSong {
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
            } else {
                notPlayingView
            }
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !isCurrentSong {
                await playerViewModel.play(song: song)
            }
            await loadUserTranslations()
        }
        .sheet(isPresented: $showTranslationInput) {
            if let index = editingLineIndex,
               case .synced(let lines) = playerViewModel.lyricState,
               index < lines.count {
                TranslationInputView(
                    originalText: lines[index].text,
                    lineIndex: index,
                    existingTranslation: userTranslations[index]
                ) { translated in
                    userTranslations[index] = translated
                    Task { await saveUserTranslations() }
                }
            }
        }
    }

    // MARK: - 유저 번역 로드/저장

    private func loadUserTranslations() async {
        guard let userId = dbUserId else { return }
        let lines = await userTranslationService.fetch(userId: userId, appleMusicID: song.id)
        for line in lines {
            userTranslations[line.index] = line.translated
        }
    }

    private func saveUserTranslations() async {
        guard let userId = dbUserId else { return }
        guard case .synced(let lines) = playerViewModel.lyricState else { return }

        let translationLines = userTranslations.compactMap { index, translated -> UserTranslationLine? in
            guard index < lines.count else { return nil }
            return UserTranslationLine(
                index: index,
                original: lines[index].text,
                translated: translated,
                timestamp: lines[index].timestamp
            )
        }.sorted { $0.index < $1.index }

        await userTranslationService.save(
            userId: userId,
            appleMusicID: song.id,
            title: song.title,
            artist: song.artistName,
            lines: translationLines
        )
    }

    // MARK: - 플레이어 헤더

    private var playerHeader: some View {
        @Bindable var vm = playerViewModel

        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.artworkURL, size: 52)

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
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if isCurrentSong {
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
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - 번역 모드 토글

    private var translationModeToggle: some View {
        @Bindable var vm = playerViewModel

        return Picker("번역 모드", selection: $vm.translationMode) {
            Text("동시 표시").tag(TranslationMode.simultaneous)
            Text("가림 모드").tag(TranslationMode.hidden)
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
            lyricMessageView(icon: "pianokeys", message: "인스트루멘탈")

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
                                Task { await playerViewModel.seek(to: line.timestamp) }
                            }
                        )
                        .onLongPressGesture {
                            editingLineIndex = index
                            showTranslationInput = true
                        }

                        // 번역 표시: 유저 번역 > AI 번역 > 번역 추가 버튼
                        if let userTrans = userTranslations[index] {
                            // 유저 번역
                            HStack(spacing: 4) {
                                Text(userTrans)
                                    .font(.footnote)
                                    .foregroundStyle(Color.green.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)

                                Image(systemName: "pencil")
                                    .font(.caption2)
                                    .foregroundStyle(Color.green.opacity(0.5))
                            }
                            .padding(.bottom, 2)
                            .onTapGesture {
                                editingLineIndex = index
                                showTranslationInput = true
                            }
                        } else if let tLines = translatedLines, index < tLines.count {
                            // AI 번역
                            translatedLineView(
                                text: tLines[index].text,
                                index: index,
                                isActive: playerViewModel.currentLyricIndex == index
                            )
                        } else if dbUserId != nil {
                            // 번역 추가 버튼
                            Button {
                                editingLineIndex = index
                                showTranslationInput = true
                            } label: {
                                Text("번역 추가")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary.opacity(0.3))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color(.systemGray6)))
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 2)
                        }
                    }
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

    // MARK: - AI 번역 줄 표시

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
                        .background(Capsule().fill(Color(.systemGray5)))
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)
        }
    }

    // MARK: - 재생 전 안내

    private var notPlayingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView("재생 준비 중...")
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
