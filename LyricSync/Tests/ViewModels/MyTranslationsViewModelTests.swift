import Testing
import Foundation
@testable import LyricSync

@Suite("MyTranslationsViewModel Tests")
@MainActor
struct MyTranslationsViewModelTests {

    private func makeSUT(
        service: MockUserTranslationService = MockUserTranslationService()
    ) -> (MyTranslationsViewModel, MockUserTranslationService) {
        let vm = MyTranslationsViewModel(service: service)
        return (vm, service)
    }

    @Test("초기 상태 - 빈 목록, 로딩 안 함")
    func initialState() {
        let (vm, _) = makeSUT()
        #expect(vm.translations.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isEmpty == true)
    }

    @Test("fetchTranslations 성공 → 목록 업데이트")
    func fetchSuccess() async {
        let service = MockUserTranslationService()
        await service.setAllResult([
            MyTranslationSummary(appleMusicID: "id1", title: "Song 1", artist: "Artist 1", lineCount: 5, createdAt: nil, versionCount: 1),
            MyTranslationSummary(appleMusicID: "id2", title: "Song 2", artist: "Artist 2", lineCount: 3, createdAt: nil, versionCount: 1),
        ])

        let (vm, _) = makeSUT(service: service)
        await vm.fetchTranslations(userId: 1)

        #expect(vm.translations.count == 2)
        #expect(vm.translations[0].title == "Song 1")
        #expect(vm.translations[1].lineCount == 3)
        #expect(vm.isLoading == false)
        #expect(vm.isEmpty == false)
    }

    @Test("fetchTranslations 빈 결과 → isEmpty true")
    func fetchEmpty() async {
        let (vm, _) = makeSUT()
        await vm.fetchTranslations(userId: 1)

        #expect(vm.translations.isEmpty)
        #expect(vm.isEmpty == true)
    }

    @Test("fetchTranslations 완료 후 isLoading false")
    func fetchLoading() async {
        let (vm, _) = makeSUT()
        await vm.fetchTranslations(userId: 1)
        #expect(vm.isLoading == false)
    }
}
