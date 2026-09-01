import Foundation

// MARK: - Sections

/// 히스토리 한 주 묶음.
struct WeekSection: Identifiable, Hashable {
    var id: Date { interval.start }
    let interval: DateInterval
    let days: [DaySection]
    let netMinutes: Int
}

/// 한 주 안의 하루 묶음.
struct DaySection: Identifiable, Hashable {
    var id: Date { day }
    /// 그 날의 자정(startOfDay).
    let day: Date
    let events: [AdjustmentEvent]
    let netMinutes: Int
}

// MARK: - Week math

/// 주/일 경계 계산. Foundation만 쓰므로 CLI에서 그대로 테스트할 수 있다.
enum WeekMath {

    /// 주 시작 요일 설정을 반영한 달력. 로케일에 흔들리지 않도록 그레고리력을 직접 구성한다.
    static func calendar(weekStart: WeekStart, timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = weekStart.firstWeekday
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }

    /// `date`가 속한 주의 구간. 시작은 주 첫날 자정, 끝은 다음 주 첫날 자정(반열림).
    ///
    /// 초 단위 산술(`+ 7 * 86400`)을 쓰지 않으므로 서머타임이 낀 주도 정확하다.
    static func weekInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval
        }
        // 그레고리력에서는 도달하지 않는 경로. 그래도 크래시 대신 그럴듯한 값을 돌려준다.
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    /// 반열림 판정: `start <= date < end`.
    ///
    /// `DateInterval.contains(_:)`는 끝점도 포함하기 때문에 그대로 쓰면 주 경계 자정에 찍힌 기록이
    /// 이번 주와 다음 주 양쪽에 잡힌다. 버킷 분류에는 반드시 이 함수를 쓸 것.
    static func interval(_ interval: DateInterval, contains date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }

    /// 구간 안에 들어가는 기록만 추린다.
    static func events(in interval: DateInterval, from events: [AdjustmentEvent]) -> [AdjustmentEvent] {
        events.filter { Self.interval(interval, contains: $0.date) }
    }

    /// 부호를 반영한 분 합계.
    static func net<S: Sequence>(_ events: S) -> Int where S.Element == AdjustmentEvent {
        events.reduce(0) { $0 + $1.signedMinutes }
    }

    /// 기록을 주 → 일로 묶는다. 주/일/기록 모두 최신순.
    ///
    /// 주는 저장하지 않고 항상 현재 설정의 달력으로 다시 계산한다. 그래서 주 시작 요일을 바꾸면
    /// 과거 기록의 묶음도 함께 재편성된다(총합은 그대로).
    static func groupByWeekThenDay(_ events: [AdjustmentEvent], calendar: Calendar) -> [WeekSection] {
        guard !events.isEmpty else { return [] }

        let byWeekStart = Dictionary(grouping: events) { event in
            weekInterval(containing: event.date, calendar: calendar).start
        }

        return byWeekStart.keys.sorted(by: >).map { weekStart in
            let weekEvents = byWeekStart[weekStart] ?? []
            let interval = weekInterval(containing: weekStart, calendar: calendar)

            let byDay = Dictionary(grouping: weekEvents) { calendar.startOfDay(for: $0.date) }
            let days = byDay.keys.sorted(by: >).map { day -> DaySection in
                let dayEvents = (byDay[day] ?? []).sorted { lhs, rhs in
                    // 같은 시각이면 id로 순서를 고정해 렌더링이 흔들리지 않게 한다.
                    lhs.date == rhs.date ? lhs.id.uuidString > rhs.id.uuidString : lhs.date > rhs.date
                }
                return DaySection(day: day, events: dayEvents, netMinutes: net(dayEvents))
            }

            return WeekSection(interval: interval, days: days, netMinutes: net(weekEvents))
        }
    }
}
