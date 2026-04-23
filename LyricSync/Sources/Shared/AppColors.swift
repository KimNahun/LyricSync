import SwiftUI

/// 앱 전체 색상 정의. 모든 뷰에서 이 색상을 사용한다.
extension Color {
    /// 메인 액센트 색상 — 코랄. 재생 버튼, 슬라이더, 배지, 프로그레스 링.
    static let appAccent = Color(red: 1.0, green: 0.42, blue: 0.42)

    /// 공부/번역 색상 — 민트. 유저 번역, 공부 모드, 내 번역 탭.
    static let appStudy = Color(red: 0.31, green: 0.80, blue: 0.77)
}
