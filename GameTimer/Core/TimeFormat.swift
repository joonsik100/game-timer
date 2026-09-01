import Foundation

/// 화면에 쓰는 모든 문자열 포맷. 로케일/DateFormatter에 의존하지 않고 달력 컴포넌트로 직접 만들어
/// 기기 설정이 무엇이든 같은 결과가 나오고 CLI에서 그대로 테스트할 수 있다.
enum TimeFormat {

    private static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    // MARK: - Duration

    /// 분을 `HH:MM`으로. 음수는 앞에 `-`가 붙는다. 예: 108 → "01:48", -150 → "-02:30".
    static func hhmm(_ minutes: Int) -> String {
        let total = minutes.magnitude
        let sign = minutes < 0 ? "-" : ""
        return "\(sign)\(pad(total / 60)):\(pad(total % 60))"
    }

    /// 버튼/기록에 쓰는 부호 붙은 분. 예: +15 → "+15분", -30 → "-30분".
    static func signedMinutes(_ signed: Int) -> String {
        "\(signed < 0 ? "-" : "+")\(signed.magnitude)분"
    }

    /// 주간 합계처럼 0도 부호 없이 보여주고 싶을 때. 0 → "0분".
    static func netMinutes(_ net: Int) -> String {
        net == 0 ? "0분" : signedMinutes(net)
    }

    // MARK: - Dates

    /// 24시간제 시각. 예: "14:32".
    static func time(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return "\(pad(UInt(parts.hour ?? 0))):\(pad(UInt(parts.minute ?? 0)))"
    }

    /// 히스토리 일자 헤더. 예: "8월 27일 (수)".
    static func dayTitle(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.month, .day, .weekday], from: day)
        let month = parts.month ?? 1
        let dayOfMonth = parts.day ?? 1
        let weekday = weekdaySymbols[safe: (parts.weekday ?? 1) - 1] ?? ""
        return "\(month)월 \(dayOfMonth)일 (\(weekday))"
    }

    /// 히스토리 주 헤더. 이번 주/지난 주는 이름으로, 그 이전은 날짜 범위로. 예: "8.25 – 8.31".
    static func weekTitle(_ interval: DateInterval, calendar: Calendar, now: Date) -> String {
        let currentStart = WeekMath.weekInterval(containing: now, calendar: calendar).start
        if interval.start == currentStart {
            return L10n.thisWeek
        }
        if let previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentStart),
           interval.start == previousStart {
            return L10n.lastWeek
        }
        return weekRange(interval, calendar: calendar)
    }

    /// 주 구간을 "8.25 – 8.31"로. 끝은 반열림이라 하루를 빼서 마지막 날을 구한다.
    static func weekRange(_ interval: DateInterval, calendar: Calendar) -> String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(shortDate(interval.start, calendar: calendar)) – \(shortDate(lastDay, calendar: calendar))"
    }

    private static func shortDate(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 1).\(parts.day ?? 1)"
    }

    // MARK: - Helpers

    private static func pad(_ value: UInt) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
