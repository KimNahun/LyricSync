import Foundation
import MusicKit

/// SearchService의 프로토콜.
protocol SearchServiceProtocol: Sendable {
    func search(term: String, limit: Int) async throws -> [Song]
}

/// MusicKit 카탈로그 검색 Service.
actor SearchService: SearchServiceProtocol {

    /// 키워드로 Apple Music 곡을 검색하여 반환한다.
    func search(term: String, limit: Int = 5) async throws -> [Song] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        AppLogger.info("검색 시작: \"\(trimmed)\" (limit=\(limit))", category: .search)

        var request = MusicCatalogSearchRequest(term: trimmed, types: [MusicKit.Song.self])
        request.limit = limit

        let response = try await request.response()
        AppLogger.debug("검색 결과: \(response.songs.count)곡", category: .search)

        return response.songs.map { mkSong -> Song in
            Song(
                id: mkSong.id.rawValue,
                title: mkSong.title,
                artistName: mkSong.artistName,
                albumTitle: mkSong.albumTitle,
                artworkURL: mkSong.artwork?.url(width: 300, height: 300),
                duration: mkSong.duration,
                rank: nil,
                musicKitID: mkSong.id
            )
        }
    }
}
