import Testing
import Foundation
@testable import LyricSync

@Suite("UserTranslationLine Tests")
struct UserTranslationLineTests {

    @Test("기본 초기화")
    func basicInit() {
        let line = UserTranslationLine(index: 0, original: "Hello", translated: "안녕", timestamp: 5.0)
        #expect(line.index == 0)
        #expect(line.original == "Hello")
        #expect(line.translated == "안녕")
        #expect(line.timestamp == 5.0)
    }

    @Test("Identifiable - id는 index와 동일")
    func identifiableID() {
        let line = UserTranslationLine(index: 42, original: "X", translated: "Y", timestamp: 0)
        #expect(line.id == 42)
        #expect(line.id == line.index)
    }

    @Test("translated는 var - 변경 가능")
    func translatedMutable() {
        var line = UserTranslationLine(index: 0, original: "Hi", translated: "", timestamp: 0)
        #expect(line.translated.isEmpty)

        line.translated = "안녕"
        #expect(line.translated == "안녕")
    }

    @Test("Codable - JSON 인코딩/디코딩 라운드트립")
    func codableRoundTrip() throws {
        let original = UserTranslationLine(index: 3, original: "Love", translated: "사랑", timestamp: 12.5)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserTranslationLine.self, from: data)

        #expect(decoded.index == original.index)
        #expect(decoded.original == original.original)
        #expect(decoded.translated == original.translated)
        #expect(decoded.timestamp == original.timestamp)
    }

    @Test("Codable - 배열 인코딩/디코딩")
    func codableArray() throws {
        let lines = [
            UserTranslationLine(index: 0, original: "A", translated: "가", timestamp: 0),
            UserTranslationLine(index: 1, original: "B", translated: "나", timestamp: 3),
            UserTranslationLine(index: 2, original: "C", translated: "다", timestamp: 6),
        ]

        let data = try JSONEncoder().encode(lines)
        let decoded = try JSONDecoder().decode([UserTranslationLine].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[1].original == "B")
        #expect(decoded[2].translated == "다")
    }

    @Test("빈 문자열 original/translated")
    func emptyStrings() {
        let line = UserTranslationLine(index: 0, original: "", translated: "", timestamp: 0)
        #expect(line.original.isEmpty)
        #expect(line.translated.isEmpty)
    }

    @Test("유니코드 텍스트")
    func unicodeText() throws {
        let line = UserTranslationLine(
            index: 0,
            original: "桜の花びら",
            translated: "벚꽃 꽃잎",
            timestamp: 1.5
        )

        let data = try JSONEncoder().encode(line)
        let decoded = try JSONDecoder().decode(UserTranslationLine.self, from: data)
        #expect(decoded.original == "桜の花びら")
        #expect(decoded.translated == "벚꽃 꽃잎")
    }

    @Test("큰 index 값")
    func largeIndex() {
        let line = UserTranslationLine(index: 9999, original: "X", translated: "Y", timestamp: 0)
        #expect(line.id == 9999)
    }
}
