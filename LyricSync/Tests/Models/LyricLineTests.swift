import Testing
import Foundation
@testable import LyricSync

@Suite("LyricLine Model Tests")
struct LyricLineTests {

    @Test("기본 초기화 - 필드가 올바르게 설정됨")
    func basicInit() {
        let line = LyricLine(timestamp: 30.5, text: "Hello world")
        #expect(line.timestamp == 30.5)
        #expect(line.text == "Hello world")
    }

    @Test("각 인스턴스는 고유 ID를 가짐")
    func uniqueIDs() {
        let a = LyricLine(timestamp: 0, text: "A")
        let b = LyricLine(timestamp: 0, text: "A")
        #expect(a.id != b.id)
    }

    @Test("유니코드 텍스트 (한글, 일본어) 보존")
    func unicodeText() {
        let korean = LyricLine(timestamp: 1, text: "안녕하세요")
        #expect(korean.text == "안녕하세요")

        let japanese = LyricLine(timestamp: 2, text: "こんにちは")
        #expect(japanese.text == "こんにちは")
    }

    @Test("Hashable - 동일 텍스트+타임스탬프여도 ID 다르면 Set에서 별도 원소")
    func hashableByID() {
        let a = LyricLine(timestamp: 10, text: "Same")
        let b = LyricLine(timestamp: 10, text: "Same")
        let set: Set<LyricLine> = [a, b]
        #expect(set.count == 2)
    }
}
