import Foundation

/// 특정 곡에 대한 유저 번역의 한 버전.
struct TranslationVersion: Identifiable, Sendable, Hashable {
    let version: Int
    let lineCount: Int
    let updatedAt: Date?

    var id: Int { version }
}
