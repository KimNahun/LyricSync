import Foundation

/// 유저가 번역한 가사 한 줄.
struct UserTranslationLine: Codable, Sendable, Identifiable {
    var id: Int { index }
    let index: Int
    let original: String
    var translated: String
    let timestamp: TimeInterval
}
