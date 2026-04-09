import Foundation
import MusicKit

/// Apple Music 차트 곡을 앱 내부에서 표현하는 모델.
/// MusicKit.Song을 래핑하여 Sendable 경계를 안전하게 넘길 수 있도록 한다.
struct Song: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String?
    let artworkURL: URL?
    let duration: TimeInterval?
    /// 차트 순위 (1-based). 차트에서 가져온 경우에만 존재.
    let rank: Int?
    /// 재생 시 MusicKit Song 재조회에 사용하는 원본 ID.
    let musicKitID: MusicItemID

    init(
        id: String,
        title: String,
        artistName: String,
        albumTitle: String?,
        artworkURL: URL?,
        duration: TimeInterval?,
        rank: Int?,
        musicKitID: MusicItemID
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.artworkURL = artworkURL
        self.duration = duration
        self.rank = rank
        self.musicKitID = musicKitID
    }
}

extension Song {
    /// MusicKit.Song으로부터 앱 Song 모델을 생성한다.
    init(from musicKitSong: MusicKit.Song, rank: Int? = nil) {
        self.id = musicKitSong.id.rawValue
        self.title = musicKitSong.title
        self.artistName = musicKitSong.artistName
        self.albumTitle = musicKitSong.albumTitle
        self.artworkURL = musicKitSong.artwork?.url(width: 300, height: 300)
        self.duration = musicKitSong.duration
        self.rank = rank
        self.musicKitID = musicKitSong.id
    }
}
