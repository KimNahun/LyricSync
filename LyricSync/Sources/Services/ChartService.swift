import Foundation
import MusicKit

/// ChartService가 던지는 에러 타입.
enum ChartServiceError: Error, LocalizedError {
    case authorizationDenied
    case chartEmpty
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Apple Music 접근 권한이 필요합니다. 설정에서 허용해 주세요."
        case .chartEmpty:
            return "차트 데이터를 불러올 수 없습니다."
        case .networkError(let error):
            return "네트워크 오류가 발생했습니다: \(error.localizedDescription)"
        }
    }
}

/// MusicKit을 통해 Apple Music 인기 팝 차트를 조회하는 Service.
actor ChartService {
    /// Pop 장르 ID (Apple Music 기준). 지역에 따라 다를 수 있으므로 실기기 테스트 필수.
    private let popGenreID = MusicItemID("14")

    /// Apple Music 인기 팝 차트 상위 50곡을 반환한다.
    func fetchChart() async throws -> [Song] {
        // MusicKit 권한 확인
        let authStatus = MusicAuthorization.currentStatus
        guard authStatus == .authorized else {
            throw ChartServiceError.authorizationDenied
        }

        do {
            // 1단계: Pop 장르 객체 fetch
            let genreRequest = MusicCatalogResourceRequest<Genre>(
                matching: \.id,
                equalTo: popGenreID
            )
            let genreResponse = try await genreRequest.response()
            let popGenre = genreResponse.items.first

            // 2단계: Pop 필터 + 인기곡 차트 요청
            var chartRequest = MusicCatalogChartsRequest(
                genre: popGenre,
                kinds: [.mostPlayed],
                types: [MusicKit.Song.self]
            )
            chartRequest.limit = 50

            let chartResponse = try await chartRequest.response()
            let items = chartResponse.songCharts.first?.items ?? []

            guard !items.isEmpty else {
                throw ChartServiceError.chartEmpty
            }

            // MusicKit.Song → 앱 Song 모델 변환 (rank는 1-based)
            return items.enumerated().map { index, musicKitSong in
                Song(from: musicKitSong, rank: index + 1)
            }
        } catch let error as ChartServiceError {
            throw error
        } catch {
            throw ChartServiceError.networkError(error)
        }
    }
}
