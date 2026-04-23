import Foundation
import MusicKit
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

        // MusicKit으로 앨범 아트 URL을 배치 조회하여 채운다.
        await fetchArtworkURLs()
    }

    /// 번역 곡이 있는지 여부.
    var isEmpty: Bool { translations.isEmpty }

    // MARK: - 앨범 아트 조회

    private func fetchArtworkURLs() async {
        let ids = translations.map { MusicItemID($0.appleMusicID) }
        guard !ids.isEmpty else { return }

        // MusicKit 배치 조회 (최대 25개씩)
        for startIndex in stride(from: 0, to: ids.count, by: 25) {
            let endIndex = min(startIndex + 25, ids.count)
            let batchIDs = Array(ids[startIndex..<endIndex])

            do {
                var request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, memberOf: batchIDs)
                request.limit = 25
                let response = try await request.response()

                for mkSong in response.items {
                    if let idx = translations.firstIndex(where: { $0.appleMusicID == mkSong.id.rawValue }) {
                        translations[idx].artworkURL = mkSong.artwork?.url(width: 300, height: 300)
                    }
                }
            } catch {
                AppLogger.warn("앨범 아트 배치 조회 실패: \(error.localizedDescription)", category: .network)
            }
        }
    }
}
