import SwiftUI

/// Apple Music 인기 팝 차트 Top 50을 표시하는 메인 화면.
/// P1 #6 — 표준 `.searchable` modifier 사용. 검색 결과는 제안(suggestion)으로 표시.
struct ChartListView: View {
    @State private var viewModel = ChartViewModel()
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(\.dbUserId) private var dbUserId

    var body: some View {
        Group {
            switch viewModel.authorizationStatus {
            case .authorized:
                authorizedContent
            case .denied, .restricted:
                deniedView
            case .notDetermined:
                ProgressView("권한 확인 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            @unknown default:
                deniedView
            }
        }
        .navigationTitle("인기 팝 차트")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.checkAuthorizationAndFetch()
            if let userId = dbUserId {
                await viewModel.fetchStudiedStatus(userId: userId)
            }
        }
    }

    // MARK: - 권한 승인 시 콘텐츠

    @ViewBuilder
    private var authorizedContent: some View {
        if viewModel.isLoading {
            ProgressView("차트 불러오는 중...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else {
            songList
                .searchable(
                    text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "곡명 또는 아티스트 검색"
                )
                .searchSuggestions {
                    if viewModel.isSearchActive {
                        searchSuggestionsContent
                    }
                }
        }
    }

    // MARK: - 차트 리스트

    private var songList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.songs) { song in
                    NavigationLink(value: song) {
                        SongRowView(
                            song: song,
                            hasStudied: viewModel.hasStudied(for: song)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 84)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationDestination(for: Song.self) { song in
            SongDetailView(song: song)
        }
    }

    // MARK: - 검색 제안 (드롭다운)

    @ViewBuilder
    private var searchSuggestionsContent: some View {
        if viewModel.isSearching {
            HStack {
                ProgressView()
                Text("검색 중...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.searchResults.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            ForEach(viewModel.searchResults) { song in
                NavigationLink(value: song) {
                    SongRowView(
                        song: song,
                        hasStudied: viewModel.hasStudied(for: song)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 에러 뷰

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("다시 시도") {
                Task { await viewModel.fetchCharts() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 권한 거부 뷰 (백업)

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Apple Music 접근 권한이 필요합니다.\n설정에서 허용해 주세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("설정 열기") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
