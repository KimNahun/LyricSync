import Testing
import MusicKit
@testable import LyricSync

@Suite("Song Model Tests")
struct SongTests {

    // MARK: - lrcTitle / lrcArtistName (비즈니스 로직)

    @Test("lrcTitle - 영어 제목이 있으면 영어를 우선 반환")
    func lrcTitleWithEnglish() {
        let song = Song.stub(title: "노래", englishTitle: "Song")
        #expect(song.lrcTitle == "Song")
    }

    @Test("lrcTitle - 영어 제목 없으면 원래 제목으로 fallback")
    func lrcTitleFallback() {
        let song = Song.stub(title: "노래", englishTitle: nil)
        #expect(song.lrcTitle == "노래")
    }

    @Test("lrcArtistName - 영어 아티스트 있으면 영어를 우선 반환")
    func lrcArtistNameWithEnglish() {
        let song = Song.stub(artistName: "가수", englishArtistName: "Singer")
        #expect(song.lrcArtistName == "Singer")
    }

    @Test("lrcArtistName - 영어 아티스트 없으면 원래 이름으로 fallback")
    func lrcArtistNameFallback() {
        let song = Song.stub(artistName: "가수", englishArtistName: nil)
        #expect(song.lrcArtistName == "가수")
    }

    // MARK: - englishTitle/englishArtistName 변경 후 lrc 속성 반영

    @Test("englishTitle 변경 시 lrcTitle이 즉시 반영됨")
    func englishTitleMutable() {
        var song = Song.stub(title: "원본", englishTitle: nil)
        #expect(song.lrcTitle == "원본")

        song.englishTitle = "English Title"
        #expect(song.lrcTitle == "English Title")
    }

    @Test("englishArtistName 변경 시 lrcArtistName이 즉시 반영됨")
    func englishArtistNameMutable() {
        var song = Song.stub(artistName: "원본", englishArtistName: nil)
        #expect(song.lrcArtistName == "원본")

        song.englishArtistName = "English Artist"
        #expect(song.lrcArtistName == "English Artist")
    }

    // MARK: - Hashable (Set/Dictionary에서의 동작)

    @Test("동일 id의 Song은 Set에서 하나로 취급")
    func hashableEqual() {
        let a = Song.stub(id: "same")
        let b = Song.stub(id: "same")
        let set: Set<AppSong> = [a, b]
        #expect(set.count == 1)
    }

    @Test("다른 id의 Song은 Set에서 별도로 취급")
    func hashableDifferent() {
        let a = Song.stub(id: "id-1")
        let b = Song.stub(id: "id-2")
        let set: Set<AppSong> = [a, b]
        #expect(set.count == 2)
    }
}
