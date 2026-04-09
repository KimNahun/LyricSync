import Foundation
import Observation

/// Apple Music 인기 팝 차트 데이터를 관리하는 ViewModel.
/// @MainActor + @Observable로 선언하여 Swift 6 동시성 모델을 준수한다.
@MainActor
@Observable
final class ChartViewModel {
    private(set) var songs: [Song] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String? = nil

    private let chartService: ChartService

    init(chartService: ChartService = ChartService()) {
        self.chartService = chartService
    }

    /// 차트를 조회하여 songs를 업데이트한다.
    func fetchCharts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            songs = try await chartService.fetchChart()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
