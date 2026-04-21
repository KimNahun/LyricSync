import Foundation
import MusicKit
import Observation

/// Apple Music 인기 팝 차트 + 검색 + 번역 배지를 관리하는 ViewModel.
@MainActor
@Observable
final class ChartViewModel {
    private(set) var songs: [Song] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String? = nil
    private(set) var authorizationStatus: MusicAuthorization.Status = .notDetermined

    // MARK: - 검색

    var searchText: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var searchResults: [Song] = []
    private(set) var isSearching: Bool = false
    var isSearchActive: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - 번역 배지

    /// 번역이 있는 곡의 apple_music_id 집합.
    private(set) var translatedSongIDs: Set<String> = []

    private let chartService: any ChartServiceProtocol
    private let searchService: any SearchServiceProtocol
    private let translatedLyricService: any TranslatedLyricServiceProtocol
    private var searchTask: Task<Void, Never>?
    /// 이미 배치 조회한 ID. 세션 내 캐시.
    private var checkedIDs: Set<String> = []

    init(
        chartService: any ChartServiceProtocol = ChartService(),
        searchService: any SearchServiceProtocol = SearchService(),
        translatedLyricService: any TranslatedLyricServiceProtocol = TranslatedLyricService()
    ) {
        self.chartService = chartService
        self.searchService = searchService
        self.translatedLyricService = translatedLyricService
    }

    /// MusicKit 권한 상태를 확인하고, 승인 시 차트를 자동으로 fetch한다.
    func checkAuthorizationAndFetch() async {
        authorizationStatus = MusicAuthorization.currentStatus
        if authorizationStatus == .authorized && songs.isEmpty {
            await fetchCharts()
        }
    }

    /// 차트를 조회하여 songs를 업데이트한다.
    func fetchCharts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            songs = try await chartService.fetchChart()
            // 차트 로드 후 번역 배지 비동기 조회
            Task {
                await fetchTranslationStatus(for: songs)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 검색 (300ms debounce)

    private func scheduleSearch() {
        searchTask?.cancel()

        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let results = try await searchService.search(term: term, limit: 5)
                guard !Task.isCancelled else { return }
                searchResults = results
                // 검색 결과에 대해서도 번역 배지 조회
                await fetchTranslationStatus(for: results)
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
            }
            isSearching = false
        }
    }

    // MARK: - 번역 배지 배치 조회

    private func fetchTranslationStatus(for songList: [Song]) async {
        let newIDs = songList.map(\.id).filter { !checkedIDs.contains($0) }
        guard !newIDs.isEmpty else { return }

        checkedIDs.formUnion(newIDs)

        let translatedIDs = await translatedLyricService.fetchTranslationStatus(appleMusicIDs: newIDs)
        translatedSongIDs.formUnion(translatedIDs)
    }

    /// 특정 곡에 번역이 있는지 확인한다.
    func hasTranslation(for song: Song) -> Bool {
        translatedSongIDs.contains(song.id)
    }
}
