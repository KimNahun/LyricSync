import Foundation
import Observation

/// 유저가 번역한 곡 목록을 관리하는 ViewModel.
@MainActor
@Observable
final class MyTranslationsViewModel {
    private(set) var translations: [MyTranslationSummary] = []
    private(set) var isLoading = false

    private let service: any UserTranslationServiceProtocol

    init(service: any UserTranslationServiceProtocol = UserTranslationService()) {
        self.service = service
    }

    /// 유저의 모든 번역 곡 목록을 조회한다.
    func fetchTranslations(userId: Int) async {
        isLoading = true
        defer { isLoading = false }
        translations = await service.fetchAll(userId: userId)
    }

    /// 번역 곡이 있는지 여부.
    var isEmpty: Bool { translations.isEmpty }
}
