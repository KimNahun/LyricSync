import SwiftUI

/// 곡 상세 + 재생 + 가사 + 번역을 통합한 단일 화면.
struct SongDetailView: View {
    let song: Song
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(\.dbUserId) private var dbUserId

    @State private var userTranslations: [Int: String] = [:]
    @State private var editingLineIndex: Int?
    @State private var showTranslationInput = false

    /// 현재 편집 중인 번역 버전. 기본 1.
    var translationVersion: Int = 1

    private let userTranslationService = UserTranslationService()

    private var isCurrentSong: Bool {
        playerViewModel.currentSong?.id == song.id
    }

    private var isPlaying: Bool {
        isCurrentSong && playerViewModel.isPlaying
    }

    var body: some View {
        VStack(spacing: 0) {
            playerHeader

            // P1 #8 — AI 동시/AI 가림/공부 단일 segmented control
            if isCurrentSong {
                modeBar
            }

            Divider()

            if isCurrentSong {
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

                        // P1 #9 — "현재 줄로 이동" 칩
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
            } else {
                notPlayingView
            }
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUserTranslations()
        }
        .onAppear {
            // P0 #2 옵션 B — 같은 곡일 때만 detail 등록
            if isCurrentSong {
                playerViewModel.currentDetailSongID = song.id
            }
        }
        .onChange(of: isCurrentSong) { _, newValue in
            if newValue {
                playerViewModel.currentDetailSongID = song.id
            }
        }
        .onDisappear {
            if playerViewModel.currentDetailSongID == song.id {
                playerViewModel.currentDetailSongID = nil
            }
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

    // MARK: - 모드 바 (P1 #8)

    private var availableModes: [DisplayMode] {
        var modes: [DisplayMode] = []
        if playerViewModel.hasTranslation {
            modes.append(.aiSimultaneous)
            modes.append(.aiHidden)
        }
        if dbUserId != nil {
            modes.append(.study)
        }
        return modes
    }

    @ViewBuilder
    private var modeBar: some View {
        @Bindable var vm = playerViewModel
        let modes = availableModes

        if modes.count >= 2 {
            HStack {
                Picker("표시 모드", selection: $vm.displayMode) {
                    ForEach(modes) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("가사 표시 모드 선택")
                .onAppear {
                    if !modes.contains(vm.displayMode), let first = modes.first {
                        vm.displayMode = first
                    }
                }
                .onChange(of: playerViewModel.hasTranslation) { _, _ in
                    if !availableModes.contains(vm.displayMode), let first = availableModes.first {
                        vm.displayMode = first
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - 현재 줄로 이동 칩 (P1 #9)

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

    // MARK: - 유저 번역 로드/저장

    private func loadUserTranslations() async {
        guard let userId = dbUserId else { return }
        let lines = await userTranslationService.fetch(userId: userId, appleMusicID: song.id, version: translationVersion)
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
            lines: translationLines,
            version: translationVersion
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
                        .lineLimit(1...2)
                        .minimumScaleFactor(0.85)

                    Text(song.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
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
                        .foregroundStyle(Color.appAccent)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel(isPlaying ? "일시정지" : "재생")
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
                    .tint(Color.appAccent)
                    .padding(.top, 4)
                    .contentShape(Rectangle())
                    .accessibilityLabel("재생 위치")
                    .accessibilityValue("\(TimeFormatUtil.format(playerViewModel.currentTime)) / \(TimeFormatUtil.format(playerViewModel.duration))")

                    HStack {
                        // P1 #13 — caption + monospacedDigit
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
                .padding(.bottom, 6)
            }
        }
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
                        // 원본 가사
                        LyricLineView(
                            line: line,
                            isActive: playerViewModel.currentLyricIndex == index,
                            onTap: {
                                Task { await playerViewModel.seek(to: line.timestamp) }
                            }
                        )

                        switch playerViewModel.displayMode {
                        case .study:
                            // 공부: 원문 + 내 번역만
                            if let userTrans = userTranslations[index] {
                                userTranslationCard(text: userTrans, index: index)
                            } else if dbUserId != nil {
                                addTranslationButton(index: index)
                            }
                        case .aiSimultaneous, .aiHidden:
                            if let tLines = translatedLines, index < tLines.count {
                                translatedLineView(
                                    text: tLines[index].text,
                                    index: index,
                                    isActive: playerViewModel.currentLyricIndex == index
                                )
                            }
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

    // MARK: - 유저 번역 카드

    private func userTranslationCard(text: String, index: Int) -> some View {
        Button {
            editingLineIndex = index
            showTranslationInput = true
        } label: {
            VStack(spacing: 2) {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(Color.appStudy)
                    .multilineTextAlignment(.center)

                Text("탭하여 수정")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.appStudy.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("내 번역: \(text). 탭하여 수정")
    }

    // MARK: - 번역 추가 버튼

    private func addTranslationButton(index: Int) -> some View {
        Button {
            editingLineIndex = index
            showTranslationInput = true
        } label: {
            Text("번역 쓰기")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appStudy)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .strokeBorder(Color.appStudy.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("이 줄 번역 추가하기")
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

    private var notPlayingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView("재생 준비 중...")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 가사 미사용/에러 (P1 #12)

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
