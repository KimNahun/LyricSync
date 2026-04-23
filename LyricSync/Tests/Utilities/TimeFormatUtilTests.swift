import Testing
import Foundation
@testable import LyricSync

@Suite("TimeFormatUtil Tests")
struct TimeFormatUtilTests {

    // MARK: - 정상 케이스

    @Test("0초 → 0:00")
    func formatZero() {
        #expect(TimeFormatUtil.format(0) == "0:00")
    }

    @Test("30초 → 0:30")
    func formatThirtySeconds() {
        #expect(TimeFormatUtil.format(30) == "0:30")
    }

    @Test("60초 → 1:00")
    func formatOneMinute() {
        #expect(TimeFormatUtil.format(60) == "1:00")
    }

    @Test("83.5초 → 1:23")
    func formatWithDecimal() {
        #expect(TimeFormatUtil.format(83.5) == "1:23")
    }

    @Test("5초 → 0:05 (초 패딩)")
    func formatSingleDigitSeconds() {
        #expect(TimeFormatUtil.format(5) == "0:05")
    }

    @Test("3분 45초 → 3:45")
    func formatThreeMinutes() {
        #expect(TimeFormatUtil.format(225) == "3:45")
    }

    @Test("10분 → 10:00")
    func formatTenMinutes() {
        #expect(TimeFormatUtil.format(600) == "10:00")
    }

    @Test("59초 → 0:59")
    func formatFiftyNineSeconds() {
        #expect(TimeFormatUtil.format(59) == "0:59")
    }

    @Test("61초 → 1:01")
    func formatSixtyOneSeconds() {
        #expect(TimeFormatUtil.format(61) == "1:01")
    }

    // MARK: - 큰 값

    @Test("1시간 → 60:00")
    func formatOneHour() {
        #expect(TimeFormatUtil.format(3600) == "60:00")
    }

    @Test("99분 59초 → 99:59")
    func formatLargeTime() {
        #expect(TimeFormatUtil.format(5999) == "99:59")
    }

    // MARK: - 엣지 케이스

    @Test("소수점 → 버림")
    func formatTruncates() {
        #expect(TimeFormatUtil.format(0.9) == "0:00")
        #expect(TimeFormatUtil.format(59.9) == "0:59")
    }

    @Test("음수 → 0:00")
    func formatNegative() {
        #expect(TimeFormatUtil.format(-1) == "0:00")
        #expect(TimeFormatUtil.format(-100) == "0:00")
    }

    @Test("infinity → 0:00")
    func formatInfinity() {
        #expect(TimeFormatUtil.format(Double.infinity) == "0:00")
    }

    @Test("NaN → 0:00")
    func formatNaN() {
        #expect(TimeFormatUtil.format(Double.nan) == "0:00")
    }

    @Test("매우 작은 양수 → 0:00")
    func formatTinyPositive() {
        #expect(TimeFormatUtil.format(0.001) == "0:00")
    }
}
