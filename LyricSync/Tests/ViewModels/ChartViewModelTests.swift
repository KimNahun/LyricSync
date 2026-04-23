import Testing
import Foundation
@testable import LyricSync

@Suite("ChartViewModel Tests")
@MainActor
struct ChartViewModelTests {

    private func makeSUT(
        chartService: MockChartService = MockChartService(),
        searchService: MockSearchService = MockSearchService(),
        translatedLyricService: MockTranslatedLyricService = MockTranslatedLyricService(),
        userTranslationService: MockUserTranslationService = MockUserTranslationService()
    ) -> (ChartViewModel, MockChartService, MockSearchService, MockTranslatedLyricService) {
        let vm = ChartViewModel(
            chartService: chartService,
            searchService: searchService,
            translatedLyricService: translatedLyricService,
            userTranslationService: userTranslationService
        )
        return (vm, chartService, searchService, translatedLyricService)
    }

    // MARK: - 초기 상태

    @Test("초기 상태 - 빈 곡 목록, 로딩 없음, 에러 없음")
    func initialState() {
        let (vm, _, _, _) = makeSUT()

        #expect(vm.songs.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.searchText.isEmpty)
        #expect(vm.searchResults.isEmpty)
        #expect(vm.isSearching == false)
        #expect(vm.isSearchActive == false)
        #expect(vm.translatedSongIDs.isEmpty)
    }

    // MARK: - fetchCharts

    @Test("차트 fetch 성공 → songs 업데이트, isLoading false, 에러 없음")
    func fetchChartsSuccess() async {
        let chartService = MockChartService()
        let songs = [
            Song.stub(id: "1", title: "Song 1", rank: 1),
            Song.stub(id: "2", title: "Song 2", rank: 2),
        ]
        await chartService.setResult(songs)

        let (vm, _, _, _) = makeSUT(chartService: chartService)
        await vm.fetchCharts()

        #expect(vm.songs.count == 2)
        #expect(vm.songs[0].title == "Song 1")
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("차트 fetch 실패 → songs 비어있음, errorMessage 설정")
    func fetchChartsFailure() async {
        let chartService = MockChartService()
        await chartService.setThrow(true)

        let (vm, _, _, _) = makeSUT(chartService: chartService)
        await vm.fetchCharts()

        #expect(vm.songs.isEmpty)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - isSearchActive

    @Test("빈 검색어 → isSearchActive false")
    func searchActiveEmpty() {
        let (vm, _, _, _) = makeSUT()
        vm.searchText = ""
        #expect(vm.isSearchActive == false)
    }

    @Test("공백만 → isSearchActive false")
    func searchActiveWhitespace() {
        let (vm, _, _, _) = makeSUT()
        vm.searchText = "   "
        #expect(vm.isSearchActive == false)
    }

    @Test("실제 텍스트 → isSearchActive true")
    func searchActiveWithText() {
        let (vm, _, _, _) = makeSUT()
        vm.searchText = "BTS"
        #expect(vm.isSearchActive == true)
    }

    // MARK: - hasTranslation

    @Test("translatedSongIDs에 없는 곡 → hasTranslation false")
    func hasTranslationFalse() {
        let (vm, _, _, _) = makeSUT()
        let song = Song.stub(id: "no-translation")
        #expect(vm.hasTranslation(for: song) == false)
    }

    // MARK: - hasStudied

    @Test("초기 상태 → hasStudied false")
    func hasStudiedInitial() {
        let (vm, _, _, _) = makeSUT()
        let song = Song.stub(id: "any")
        #expect(vm.hasStudied(for: song) == false)
    }

    @Test("fetchStudiedStatus 후 공부한 곡 배지 표시")
    func fetchStudiedStatus() async {
        let userService = MockUserTranslationService()
        await userService.setStudiedIDs(["studied-1", "studied-2"])

        let (vm, _, _, _) = makeSUT(userTranslationService: userService)
        await vm.fetchStudiedStatus(userId: 1)

        #expect(vm.hasStudied(for: Song.stub(id: "studied-1")) == true)
        #expect(vm.hasStudied(for: Song.stub(id: "studied-2")) == true)
        #expect(vm.hasStudied(for: Song.stub(id: "not-studied")) == false)
    }

    // MARK: - 검색 (scheduleSearch)

    @Test("검색어 입력 후 300ms debounce → searchResults 업데이트")
    func searchWithDebounce() async {
        let searchService = MockSearchService()
        let results = [Song.stub(id: "s1", title: "Found Song")]
        await searchService.setResult(results)

        let (vm, _, _, _) = makeSUT(searchService: searchService)
        vm.searchText = "Found"

        // debounce 300ms + 여유
        try? await Task.sleep(for: .milliseconds(500))

        #expect(vm.searchResults.count == 1)
        #expect(vm.searchResults[0].title == "Found Song")
        #expect(vm.isSearching == false)
    }

    @Test("검색어 비우면 searchResults 초기화")
    func searchClearText() async {
        let searchService = MockSearchService()
        await searchService.setResult([Song.stub(id: "s1")])

        let (vm, _, _, _) = makeSUT(searchService: searchService)
        vm.searchText = "test"
        try? await Task.sleep(for: .milliseconds(500))

        vm.searchText = ""
        // 즉시 초기화
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.searchResults.isEmpty)
        #expect(vm.isSearchActive == false)
    }

    @Test("검색 에러 시 searchResults 비어있음")
    func searchError() async {
        let searchService = MockSearchService()
        await searchService.setThrow(true)

        let (vm, _, _, _) = makeSUT(searchService: searchService)
        vm.searchText = "error-query"

        try? await Task.sleep(for: .milliseconds(500))

        #expect(vm.searchResults.isEmpty)
    }

    // MARK: - 번역 배지 배치 조회

    @Test("차트 로드 후 번역 배치 조회가 자동으로 실행됨")
    func fetchChartsTriggersBadgeQuery() async {
        let chartService = MockChartService()
        await chartService.setResult([
            Song.stub(id: "chart1"),
            Song.stub(id: "chart2"),
        ])

        let translatedService = MockTranslatedLyricService()
        await translatedService.setStatusResult(["chart1"])

        let (vm, _, _, _) = makeSUT(chartService: chartService, translatedLyricService: translatedService)
        await vm.fetchCharts()

        // 배치 조회는 내부 Task로 실행
        try? await Task.sleep(for: .milliseconds(100))

        #expect(vm.hasTranslation(for: Song.stub(id: "chart1")) == true)
        #expect(vm.hasTranslation(for: Song.stub(id: "chart2")) == false)
    }
}

// MARK: - Mock 헬퍼

extension MockChartService {
    func setResult(_ songs: [Song]) {
        fetchResult = songs
    }

    func setThrow(_ value: Bool) {
        shouldThrow = value
    }
}
