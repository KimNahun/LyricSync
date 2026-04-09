import Foundation

/// 재생 시간을 "M:SS" 형식으로 포맷하는 유틸리티.
enum TimeFormatUtil {
    /// TimeInterval을 "M:SS" 형식 문자열로 변환한다.
    /// 예: 83.5 → "1:23", 0 → "0:00"
    static func format(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
