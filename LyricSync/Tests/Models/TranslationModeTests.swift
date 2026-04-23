import Testing
@testable import LyricSync

// TranslationMode는 RawRepresentable(String) enum이며,
// rawValue 합성은 컴파일러가 보장한다.
// 여기서는 앱의 비즈니스 로직에서 실제로 사용하는 패턴만 테스트한다:
// UserDefaults에서 읽은 문자열로 복원하는 시나리오.

@Suite("TranslationMode Tests")
struct TranslationModeTests {

    @Test("유효한 rawValue로 복원 가능")
    func initFromValidRaw() {
        #expect(TranslationMode(rawValue: "simultaneous") == .simultaneous)
        #expect(TranslationMode(rawValue: "hidden") == .hidden)
    }

    @Test("잘못된 rawValue는 nil → 기본값 fallback 필요 확인")
    func initFromInvalidRaw() {
        // 앱에서 UserDefaults 값이 손상된 경우를 시뮬레이션
        #expect(TranslationMode(rawValue: "invalid") == nil)
        #expect(TranslationMode(rawValue: "") == nil)
    }
}
