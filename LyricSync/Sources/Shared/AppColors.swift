import SwiftUI
import UIKit

/// 앱 전체 색상 정의. 라이트/다크 모드 별도 값으로 가독성과 대비를 보장한다.
extension Color {
    /// 메인 액센트 색상 — 코랄. 재생 버튼, 슬라이더, 배지, 프로그레스 링.
    static let appAccent = Color(
        light: UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0),
        dark: UIColor(red: 0.95, green: 0.50, blue: 0.50, alpha: 1.0)
    )

    /// 공부/번역 색상 — 민트. 유저 번역, 공부 모드, 내 번역 탭.
    static let appStudy = Color(
        light: UIColor(red: 0.31, green: 0.80, blue: 0.77, alpha: 1.0),
        dark: UIColor(red: 0.40, green: 0.85, blue: 0.80, alpha: 1.0)
    )

    /// UIKit trait 기반 light/dark 다이나믹 색상.
    fileprivate init(light: UIColor, dark: UIColor) {
        let dynamic = UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        }
        self.init(uiColor: dynamic)
    }
}
