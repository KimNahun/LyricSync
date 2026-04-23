import Testing
import Foundation
@testable import LyricSync

// LyricState는 associated value 없는 케이스에 대해 비즈니스 로직이 없으므로,
// associated value를 다루는 실질적 로직만 테스트한다.
// enum 구성 자체는 컴파일러가 보장하므로 tautological 테스트는 제거.

@Suite("LyricState Tests")
struct LyricStateTests {

    @Test("synced 상태 - 여러 줄의 가사 데이터를 보존함")
    func syncedPreservesLines() {
        let lines = [
            LyricLine(timestamp: 0, text: "First"),
            LyricLine(timestamp: 5, text: "Second"),
            LyricLine(timestamp: 10, text: "Third"),
        ]
        let state: LyricState = .synced(lines)
        guard case .synced(let result) = state else {
            Issue.record("Expected .synced")
            return
        }
        #expect(result.count == 3)
        #expect(result[0].text == "First")
        #expect(result[2].timestamp == 10)
    }

    @Test("plain 상태 - 텍스트 전체를 보존함")
    func plainPreservesText() {
        let lyrics = "Just plain text lyrics\nLine 2\nLine 3"
        let state: LyricState = .plain(lyrics)
        guard case .plain(let text) = state else {
            Issue.record("Expected .plain")
            return
        }
        #expect(text == lyrics)
    }

    @Test("error 상태 - 에러 메시지를 보존함")
    func errorPreservesMessage() {
        let state: LyricState = .error("Rate limit exceeded")
        guard case .error(let msg) = state else {
            Issue.record("Expected .error")
            return
        }
        #expect(msg == "Rate limit exceeded")
    }
}
