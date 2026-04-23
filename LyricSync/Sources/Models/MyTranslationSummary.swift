import Foundation
import MusicKit

/// 유저가 번역한 곡의 요약 정보. "내 번역" 목록에 표시한다.
struct MyTranslationSummary: Identifiable, Sendable, Hashable {
    let appleMusicID: String
    let title: String
    let artist: String
    let lineCount: Int
    let createdAt: Date?
    var artworkURL: URL?

    var id: String { appleMusicID }

    /// Song 모델로 변환. 내 번역 목록에서 SongDetailView로 이동할 때 사용.
    func toSong() -> Song {
        Song(
            id: appleMusicID,
            title: title,
            artistName: artist,
            albumTitle: nil,
            artworkURL: artworkURL,
            duration: nil,
            rank: nil,
            musicKitID: MusicItemID(appleMusicID)
        )
    }
}
