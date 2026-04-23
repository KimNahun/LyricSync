import Testing
import Foundation
@testable import LyricSync

@Suite("MyTranslationSummary Tests")
struct MyTranslationSummaryTests {

    @Test("id는 appleMusicID와 동일")
    func identifiable() {
        let summary = MyTranslationSummary(
            appleMusicID: "abc123",
            title: "Test",
            artist: "Artist",
            lineCount: 5,
            createdAt: nil,
            versionCount: 1
        )
        #expect(summary.id == "abc123")
    }

    @Test("toSong → Song 모델로 변환, 필수 필드 보존")
    func toSong() {
        let summary = MyTranslationSummary(
            appleMusicID: "song-42",
            title: "My Song",
            artist: "My Artist",
            lineCount: 10,
            createdAt: Date(),
            versionCount: 2
        )

        let song = summary.toSong()

        #expect(song.id == "song-42")
        #expect(song.title == "My Song")
        #expect(song.artistName == "My Artist")
        #expect(song.albumTitle == nil)
        #expect(song.artworkURL == nil)
        #expect(song.duration == nil)
        #expect(song.rank == nil)
    }

    @Test("Hashable - 같은 appleMusicID면 동일")
    func hashable() {
        let a = MyTranslationSummary(appleMusicID: "same", title: "A", artist: "X", lineCount: 1, createdAt: nil, versionCount: 1)
        let b = MyTranslationSummary(appleMusicID: "same", title: "A", artist: "X", lineCount: 1, createdAt: nil, versionCount: 1)
        #expect(a == b)
    }
}
