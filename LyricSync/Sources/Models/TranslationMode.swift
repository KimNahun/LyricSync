import Foundation

/// 번역 가사 표시 모드.
enum TranslationMode: String, Sendable {
    /// 원본 + 번역을 동시에 표시
    case simultaneous
    /// 번역을 가리고 줄별 눈 버튼으로 개별 공개
    case hidden
}
