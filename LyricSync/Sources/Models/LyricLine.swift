import Foundation

/// LRC 형식에서 파싱된 가사 한 줄을 나타내는 모델.
/// timestamp는 초 단위 TimeInterval이며, text는 해당 시점의 가사 텍스트다.
struct LyricLine: Identifiable, Sendable, Hashable {
    let id: UUID
    let timestamp: TimeInterval
    let text: String

    init(timestamp: TimeInterval, text: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.text = text
    }
}
