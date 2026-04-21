import SwiftUI

/// Apple Music 인기 팝 차트 Top 50을 표시하는 메인 화면.
struct ChartListView: View {
    @State private var viewModel = ChartViewModel()
    @Environment(PlayerViewModel.self) private var playerViewModel

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
            VStack(spacing: 0) {
                // 상단 고정 검색바
                searchBar

                // 검색 결과 or 차트
                if viewModel.isSearchActive {
                    searchResultsList
                } else {
                    songList
                }
            }
        }
    }

    // MARK: - 상단 검색바

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("곡 검색", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 차트 리스트

    private var songList: some View {
        List(viewModel.songs) { song in
            NavigationLink(value: song) {
                SongRowView(
                    song: song,
                    hasTranslation: viewModel.hasTranslation(for: song)
                )
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Song.self) { song in
            SongDetailView(song: song)
        }
        .refreshable {
            await viewModel.fetchCharts()
        }
    }

    // MARK: - 검색 결과 리스트

    private var searchResultsList: some View {
        List {
            if viewModel.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if viewModel.searchResults.isEmpty {
                Text("검색 결과가 없습니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.searchResults) { song in
                    NavigationLink(value: song) {
                        SongRowView(
                            song: song,
                            hasTranslation: viewModel.hasTranslation(for: song)
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Song.self) { song in
            SongDetailView(song: song)
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
                Task {
                    await viewModel.fetchCharts()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 권한 거부 뷰

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
