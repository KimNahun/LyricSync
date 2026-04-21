import Foundation
import os

/// 앱 전체 디버그 로거.
/// DEBUG 빌드에서만 동작하며, 카테고리별로 on/off 가능.
enum AppLogger {
    /// 활성화할 카테고리. 런타임에 토글 가능.
    nonisolated(unsafe) static var enabledCategories: Set<Category> = Set(Category.allCases)

    /// 로깅 전체 on/off. false면 모든 로그 무시.
    nonisolated(unsafe) static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    enum Category: String, CaseIterable {
        case network    // API 호출/응답
        case supabase   // Supabase 관련
        case lyrics     // 가사 조회/파싱
        case player     // 재생 상태
        case search     // 검색
        case ui         // UI 상태 변경
    }

    enum Level: String {
        case debug = "🔍"
        case info  = "ℹ️"
        case warn  = "⚠️"
        case error = "❌"
    }

    static func debug(_ message: String, category: Category = .network) {
        log(message, level: .debug, category: category)
    }

    static func info(_ message: String, category: Category = .network) {
        log(message, level: .info, category: category)
    }

    static func warn(_ message: String, category: Category = .network) {
        log(message, level: .warn, category: category)
    }

    static func error(_ message: String, category: Category = .network) {
        log(message, level: .error, category: category)
    }

    private static func log(_ message: String, level: Level, category: Category) {
        #if DEBUG
        guard isEnabled, enabledCategories.contains(category) else { return }
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("\(level.rawValue) [\(timestamp)] [\(category.rawValue.uppercased())] \(message)")
        #endif
    }
}

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
