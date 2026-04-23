import Testing
import Foundation
@testable import LyricSync

@Suite("TranslationVersion Tests")
struct TranslationVersionTests {

    @Test("id는 version과 동일")
    func identifiable() {
        let v = TranslationVersion(version: 3, lineCount: 10, updatedAt: Date())
        #expect(v.id == 3)
    }

    @Test("Hashable - 같은 version이면 동일")
    func hashable() {
        let a = TranslationVersion(version: 1, lineCount: 5, updatedAt: nil)
        let b = TranslationVersion(version: 1, lineCount: 5, updatedAt: nil)
        #expect(a == b)
    }
}
