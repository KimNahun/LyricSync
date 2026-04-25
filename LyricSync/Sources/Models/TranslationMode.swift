import Foundation

/// 번역 가사 표시 모드.
enum TranslationMode: String, Sendable {
    /// 원본 + 번역을 동시에 표시
    case simultaneous
    /// 번역을 가리고 줄별 눈 버튼으로 개별 공개
    case hidden
}

/// 가사 디스플레이 통합 모드 — AI 번역 동시/가림 vs 공부(내 번역) 가 상호배타임을 단일 enum으로 표현.
enum DisplayMode: String, Sendable, CaseIterable, Identifiable {
    /// AI 동시 표시 (원본 + AI 번역을 같이)
    case aiSimultaneous
    /// AI 가림 모드 (원본만, 줄별 눈 버튼 공개)
    case aiHidden
    /// 공부 모드 (원본 + 내가 직접 쓴 번역만)
    case study

    var id: String { rawValue }

    /// 사용자에게 보여줄 라벨.
    var label: String {
        switch self {
        case .aiSimultaneous: return "AI 동시"
        case .aiHidden: return "AI 가림"
        case .study: return "공부"
        }
    }

    /// AI 번역 모드 인지(공부 제외).
    var isAIMode: Bool { self != .study }

    /// AI 번역 모드 → TranslationMode 변환.
    var translationMode: TranslationMode? {
        switch self {
        case .aiSimultaneous: return .simultaneous
        case .aiHidden: return .hidden
        case .study: return nil
        }
    }
}
