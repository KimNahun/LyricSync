import Testing
import SwiftUI
@testable import LyricSync

@Suite("AppColors Tests")
struct AppColorsTests {

    @Test("appAccent 색상이 정의됨")
    func appAccentDefined() {
        let color = Color.appAccent
        #expect(color != Color.clear)
    }

    @Test("appStudy 색상이 정의됨")
    func appStudyDefined() {
        let color = Color.appStudy
        #expect(color != Color.clear)
    }
}
