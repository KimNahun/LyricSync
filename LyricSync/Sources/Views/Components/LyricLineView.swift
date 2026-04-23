import SwiftUI

/// 가사 한 줄을 표시하는 컴포넌트.
/// isActive 상태에 따라 활성/비활성 스타일을 애니메이션으로 전환한다.
struct LyricLineView: View {
    let line: LyricLine
    let isActive: Bool
    let onTap: (() -> Void)?

    init(line: LyricLine, isActive: Bool, onTap: (() -> Void)? = nil) {
        self.line = line
        self.isActive = isActive
        self.onTap = onTap
    }

    var body: some View {
        Text(line.text.isEmpty ? " " : line.text)
            .font(isActive ? .body.weight(.semibold) : .body)
            .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.55))
            .multilineTextAlignment(.center)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .frame(maxWidth: .infinity, alignment: .center)
            // 최소 터치 영역 44pt 보장 (HIG)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
            .accessibilityLabel(line.text.isEmpty ? "간주" : line.text)
            .accessibilityHint(isActive ? "현재 재생 중인 가사" : "")
    }
}
