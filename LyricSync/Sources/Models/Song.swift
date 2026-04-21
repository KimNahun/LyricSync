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
    /// lrclib 가사 조회용 영어 제목. nil이면 title을 사용.
    var englishTitle: String?
    /// lrclib 가사 조회용 영어 아티스트명. nil이면 artistName을 사용.
    var englishArtistName: String?

    /// 가사 조회에 사용할 제목 (영어 우선)
    var lrcTitle: String { englishTitle ?? title }
    /// 가사 조회에 사용할 아티스트명 (영어 우선)
    var lrcArtistName: String { englishArtistName ?? artistName }

    init(
        id: String,
        title: String,
        artistName: String,
        albumTitle: String?,
        artworkURL: URL?,
        duration: TimeInterval?,
        rank: Int?,
        musicKitID: MusicItemID,
        englishTitle: String? = nil,
        englishArtistName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.artworkURL = artworkURL
        self.duration = duration
        self.rank = rank
        self.musicKitID = musicKitID
        self.englishTitle = englishTitle
        self.englishArtistName = englishArtistName
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
