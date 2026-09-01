import Foundation

// XCTest 없이 도는 순수 로직 테스트. Scripts/test.sh가 Models + Core + Support/L10n과 함께 컴파일해 실행한다.

// MARK: - Tiny assert harness

private var failures: [String] = []
private var checks = 0

private func expect(
    _ condition: Bool,
    _ message: @autoclosure () -> String,
    function: String = #function,
    line: Int = #line
) {
    checks += 1
    if !condition {
        failures.append("[\(function):\(line)] \(message())")
    }
}

private func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ label: String,
    function: String = #function,
    line: Int = #line
) {
    checks += 1
    if actual != expected {
        failures.append("[\(function):\(line)] \(label): 기대 \(expected), 실제 \(actual)")
    }
}

// MARK: - Date helpers

private let seoul = TimeZone(identifier: "Asia/Seoul")!
private let newYork = TimeZone(identifier: "America/New_York")!

private func makeDate(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int = 0, _ minute: Int = 0,
    in timeZone: TimeZone = seoul
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    parts.hour = hour
    parts.minute = minute
    guard let date = calendar.date(from: parts) else {
        fatalError("테스트 날짜를 만들 수 없음: \(year)-\(month)-\(day)")
    }
    return date
}

private func event(
    _ kind: AdjustmentKind,
    _ minutes: Int,
    _ date: Date,
    name: String = "테스트"
) -> AdjustmentEvent {
    AdjustmentEvent(kind: kind, name: name, minutes: minutes, date: date)
}

// 2025-08-25는 월요일. 월/일 시작 두 경우를 모두 확인하기 좋은 기준 주.
private let mondayAug25 = makeDate(2025, 8, 25)
private let sundayAug31 = makeDate(2025, 8, 31)

// MARK: - Tests

private func testDurationFormatting() {
    expectEqual(TimeFormat.hhmm(0), "00:00", "0분")
    expectEqual(TimeFormat.hhmm(108), "01:48", "108분")
    expectEqual(TimeFormat.hhmm(60), "01:00", "60분")
    expectEqual(TimeFormat.hhmm(59), "00:59", "59분")
    expectEqual(TimeFormat.hhmm(420), "07:00", "기본 420분")
    expectEqual(TimeFormat.hhmm(-150), "-02:30", "음수 잔액")
    expectEqual(TimeFormat.hhmm(-1), "-00:01", "-1분")
    expectEqual(TimeFormat.hhmm(10080), "168:00", "세 자리 시간")
    // 표시가 깨지지 않는지: 극단값에서도 크래시하지 않아야 한다.
    expectEqual(TimeFormat.hhmm(Int.min).hasPrefix("-"), true, "Int.min 부호")

    expectEqual(TimeFormat.signedMinutes(15), "+15분", "양수 라벨")
    expectEqual(TimeFormat.signedMinutes(-30), "-30분", "음수 라벨")
    expectEqual(TimeFormat.netMinutes(0), "0분", "합계 0")
    expectEqual(TimeFormat.netMinutes(-45), "-45분", "합계 음수")
}

private func testWeekIntervalMondayStart() {
    let calendar = WeekMath.calendar(weekStart: .monday, timeZone: seoul)

    // 주 한가운데(수요일)에서 시작하면 그 주 월요일 자정이 나와야 한다.
    let wednesday = makeDate(2025, 8, 27, 14, 30)
    let week = WeekMath.weekInterval(containing: wednesday, calendar: calendar)
    expectEqual(week.start, mondayAug25, "월 시작: 주 시작일")
    expectEqual(week.end, makeDate(2025, 9, 1), "월 시작: 주 종료일")

    // 일요일 23:59는 아직 같은 주, 월요일 00:00은 다음 주.
    let sundayNight = makeDate(2025, 8, 31, 23, 59)
    let mondayMidnight = makeDate(2025, 9, 1, 0, 0)
    expectEqual(
        WeekMath.weekInterval(containing: sundayNight, calendar: calendar).start,
        mondayAug25,
        "월 시작: 일요일 밤은 같은 주"
    )
    expectEqual(
        WeekMath.weekInterval(containing: mondayMidnight, calendar: calendar).start,
        makeDate(2025, 9, 1),
        "월 시작: 월요일 자정은 다음 주"
    )
}

private func testWeekIntervalSundayStart() {
    let calendar = WeekMath.calendar(weekStart: .sunday, timeZone: seoul)

    let wednesday = makeDate(2025, 8, 27, 14, 30)
    let week = WeekMath.weekInterval(containing: wednesday, calendar: calendar)
    expectEqual(week.start, makeDate(2025, 8, 24), "일 시작: 주 시작일")
    expectEqual(week.end, sundayAug31, "일 시작: 주 종료일")

    // 같은 일요일이 월 시작에선 주의 끝, 일 시작에선 주의 시작이다.
    expectEqual(
        WeekMath.weekInterval(containing: sundayAug31, calendar: calendar).start,
        sundayAug31,
        "일 시작: 일요일은 주의 첫날"
    )
}

private func testWeekIntervalAcrossYearBoundary() {
    let calendar = WeekMath.calendar(weekStart: .monday, timeZone: seoul)
    // 2025-12-29(월) ~ 2026-01-04(일) 한 주가 연도를 넘는다.
    let newYearsEve = makeDate(2025, 12, 31, 23, 0)
    let week = WeekMath.weekInterval(containing: newYearsEve, calendar: calendar)
    expectEqual(week.start, makeDate(2025, 12, 29), "연말 주 시작")
    expectEqual(week.end, makeDate(2026, 1, 5), "연말 주 종료")

    // 새해 첫날도 같은 주에 묶여야 한다.
    expectEqual(
        WeekMath.weekInterval(containing: makeDate(2026, 1, 1, 9, 0), calendar: calendar).start,
        makeDate(2025, 12, 29),
        "새해 첫날은 이전 주에 속함"
    )
}

private func testDaylightSavingWeek() {
    // 뉴욕은 2026-03-08 새벽 2시에 서머타임이 시작된다. 그 주는 168시간이 아니라 167시간이다.
    let calendar = WeekMath.calendar(weekStart: .sunday, timeZone: newYork)
    let inDSTWeek = makeDate(2026, 3, 10, 12, 0, in: newYork)
    let week = WeekMath.weekInterval(containing: inDSTWeek, calendar: calendar)

    expectEqual(week.start, makeDate(2026, 3, 8, 0, 0, in: newYork), "DST 주 시작")
    expectEqual(week.duration, 7 * 86400 - 3600, "DST 주 길이는 167시간")

    // 초 단위 산술이 아니라 달력으로 계산하므로 7일이 모두 안에 들어와야 한다.
    for offset in 0..<7 {
        let day = calendar.date(byAdding: .day, value: offset, to: week.start)!
        expect(
            WeekMath.interval(week, contains: day),
            "DST 주에 \(offset)일차가 포함되지 않음"
        )
    }
    // 8일째는 다음 주.
    let eighthDay = calendar.date(byAdding: .day, value: 7, to: week.start)!
    expect(!WeekMath.interval(week, contains: eighthDay), "DST 주에 8일차가 잘못 포함됨")
}

private func testHalfOpenContainment() {
    let calendar = WeekMath.calendar(weekStart: .monday, timeZone: seoul)
    let week = WeekMath.weekInterval(containing: mondayAug25, calendar: calendar)

    expect(WeekMath.interval(week, contains: week.start), "주 시작 순간은 포함되어야 함")
    // 이 한 줄이 핵심이다. Foundation의 DateInterval.contains는 끝점도 포함하기 때문에
    // 그대로 쓰면 경계 자정에 찍힌 기록이 두 주에 중복 집계된다.
    expect(!WeekMath.interval(week, contains: week.end), "주 종료 순간은 제외되어야 함")
    expect(WeekMath.interval(week, contains: week.end.addingTimeInterval(-1)), "종료 1초 전은 포함")

    // 경계에 찍힌 기록은 정확히 한 주에만 잡힌다.
    let boundaryEvent = event(.penalty, 30, week.end)
    let thisWeek = WeekMath.events(in: week, from: [boundaryEvent])
    let nextWeek = WeekMath.events(
        in: WeekMath.weekInterval(containing: week.end, calendar: calendar),
        from: [boundaryEvent]
    )
    expectEqual(thisWeek.count, 0, "경계 기록이 이번 주에 잡힘")
    expectEqual(nextWeek.count, 1, "경계 기록이 다음 주에 안 잡힘")
}

private func testLedgerMath() {
    expectEqual(WeekMath.net([] as [AdjustmentEvent]), 0, "빈 목록 합계")

    let events = [
        event(.penalty, 30, mondayAug25),
        event(.benefit, 15, mondayAug25),
        event(.penalty, 60, mondayAug25),
    ]
    expectEqual(WeekMath.net(events), -75, "차감/추가 혼합 합계")
    expectEqual(420 + WeekMath.net(events), 345, "기본 420분에서의 잔액")

    // 차감이 기본 시간을 넘으면 음수가 된다.
    let heavy = [event(.penalty, 500, mondayAug25)]
    expectEqual(420 + WeekMath.net(heavy), -80, "초과 차감 시 음수 잔액")

    expectEqual(AdjustmentKind.penalty.sign, -1, "차감 부호")
    expectEqual(AdjustmentKind.benefit.sign, 1, "추가 부호")
    expectEqual(event(.penalty, 30, mondayAug25).signedMinutes, -30, "차감 signedMinutes")
    expectEqual(event(.benefit, 30, mondayAug25).signedMinutes, 30, "추가 signedMinutes")
}

private func testGrouping() {
    let calendar = WeekMath.calendar(weekStart: .monday, timeZone: seoul)
    let events = [
        event(.penalty, 30, makeDate(2025, 8, 25, 9, 0), name: "월요일 아침"),
        event(.benefit, 15, makeDate(2025, 8, 25, 20, 0), name: "월요일 저녁"),
        event(.penalty, 20, makeDate(2025, 8, 27, 18, 0), name: "수요일"),
        event(.benefit, 60, makeDate(2025, 9, 2, 10, 0), name: "다음 주"),
    ]

    let sections = WeekMath.groupByWeekThenDay(events, calendar: calendar)
    expectEqual(sections.count, 2, "주 묶음 개수")

    // 최신 주가 먼저.
    expectEqual(sections[0].interval.start, makeDate(2025, 9, 1), "첫 묶음은 최신 주")
    expectEqual(sections[0].netMinutes, 60, "최신 주 합계")
    expectEqual(sections[1].interval.start, mondayAug25, "둘째 묶음은 이전 주")
    expectEqual(sections[1].netMinutes, -35, "이전 주 합계")

    // 주 안에서도 최신 날짜가 먼저.
    let olderWeek = sections[1]
    expectEqual(olderWeek.days.count, 2, "이전 주의 일자 개수")
    expectEqual(olderWeek.days[0].day, makeDate(2025, 8, 27), "일자 최신순")
    expectEqual(olderWeek.days[1].day, mondayAug25, "일자 최신순 두번째")

    // 하루 안에서도 최신 기록이 먼저.
    let monday = olderWeek.days[1]
    expectEqual(monday.events.count, 2, "월요일 기록 개수")
    expectEqual(monday.events[0].name, "월요일 저녁", "하루 안에서 최신순")
    expectEqual(monday.events[1].name, "월요일 아침", "하루 안에서 최신순 두번째")
    expectEqual(monday.netMinutes, -15, "월요일 합계")

    expectEqual(WeekMath.groupByWeekThenDay([], calendar: calendar).count, 0, "빈 기록 묶음")
}

private func testGroupingFollowsWeekStartSetting() {
    // 같은 기록도 주 시작 요일 설정에 따라 다르게 묶인다. 총합은 변하지 않는다.
    let events = [
        event(.penalty, 30, makeDate(2025, 8, 24, 12, 0)), // 일요일
        event(.penalty, 30, makeDate(2025, 8, 25, 12, 0)), // 월요일
    ]

    let monday = WeekMath.groupByWeekThenDay(events, calendar: WeekMath.calendar(weekStart: .monday, timeZone: seoul))
    let sunday = WeekMath.groupByWeekThenDay(events, calendar: WeekMath.calendar(weekStart: .sunday, timeZone: seoul))

    expectEqual(monday.count, 2, "월 시작이면 두 주로 나뉨")
    expectEqual(sunday.count, 1, "일 시작이면 한 주로 묶임")
    expectEqual(
        monday.reduce(0) { $0 + $1.netMinutes },
        sunday.reduce(0) { $0 + $1.netMinutes },
        "묶는 방식이 달라도 총합은 동일"
    )
}

private func testDateTitles() {
    let calendar = WeekMath.calendar(weekStart: .monday, timeZone: seoul)

    expectEqual(TimeFormat.dayTitle(makeDate(2025, 8, 27), calendar: calendar), "8월 27일 (수)", "일자 헤더")
    expectEqual(TimeFormat.dayTitle(mondayAug25, calendar: calendar), "8월 25일 (월)", "월요일 헤더")
    expectEqual(TimeFormat.dayTitle(sundayAug31, calendar: calendar), "8월 31일 (일)", "일요일 헤더")

    expectEqual(TimeFormat.time(makeDate(2025, 8, 27, 14, 32), calendar: calendar), "14:32", "24시간제 시각")
    expectEqual(TimeFormat.time(makeDate(2025, 8, 27, 9, 5), calendar: calendar), "09:05", "0 채움 시각")

    let week = WeekMath.weekInterval(containing: mondayAug25, calendar: calendar)
    expectEqual(TimeFormat.weekRange(week, calendar: calendar), "8.25 – 8.31", "주 범위 표기")

    // 현재 주/지난 주는 날짜 대신 이름으로.
    let now = makeDate(2025, 9, 3, 12, 0)
    let currentWeek = WeekMath.weekInterval(containing: now, calendar: calendar)
    expectEqual(TimeFormat.weekTitle(currentWeek, calendar: calendar, now: now), L10n.thisWeek, "이번 주 제목")
    expectEqual(TimeFormat.weekTitle(week, calendar: calendar, now: now), L10n.lastWeek, "지난 주 제목")

    let twoWeeksAgo = WeekMath.weekInterval(containing: makeDate(2025, 8, 20), calendar: calendar)
    expectEqual(TimeFormat.weekTitle(twoWeeksAgo, calendar: calendar, now: now), "8.18 – 8.24", "2주 전은 날짜로")
}

private func testSanitizing() {
    expectEqual(Preset(name: "  숙제  ", minutes: 30).sanitized()?.name, "숙제", "이름 공백 제거")
    expect(Preset(name: "   ", minutes: 30).sanitized() == nil, "빈 이름은 버려야 함")
    expectEqual(Preset(name: "과다", minutes: 99999).sanitized()?.minutes, 1440, "분 상한")
    expectEqual(Preset(name: "음수", minutes: -5).sanitized()?.minutes, 1, "분 하한")

    let messy = AppSettings(
        weeklyBaseMinutes: 999_999,
        weekStart: .sunday,
        penalties: [Preset(name: "", minutes: 10), Preset(name: "유효", minutes: 10)],
        benefits: []
    )
    let clean = messy.sanitized()
    expectEqual(clean.weeklyBaseMinutes, AppSettings.maxWeeklyBaseMinutes, "기본 시간 상한")
    expectEqual(clean.penalties.count, 1, "이름 없는 항목 제거")
}

private func testCodableRoundTrip() {
    let state = PersistedState(
        settings: .default,
        events: [
            event(.penalty, 30, mondayAug25, name: "숙제 미완료"),
            event(.benefit, 15, sundayAug31, name: "책 읽기"),
        ]
    )

    guard let data = try? Persistence.makeEncoder().encode(state),
          let decoded = try? Persistence.makeDecoder().decode(PersistedState.self, from: data) else {
        failures.append("[testCodableRoundTrip] 인코딩/디코딩 실패")
        return
    }

    expectEqual(decoded.events.count, 2, "기록 개수 보존")
    expectEqual(decoded.events[0].name, "숙제 미완료", "한글 이름 보존")
    expectEqual(decoded.events[0].date, mondayAug25, "날짜 보존")
    expectEqual(decoded.settings.weeklyBaseMinutes, 420, "설정 보존")
    expectEqual(decoded.settings.weekStart, .monday, "주 시작 보존")
    expectEqual(decoded.settings.penalties.count, AppSettings.default.penalties.count, "프리셋 보존")
}

private func testForwardCompatibleDecoding() {
    let decoder = Persistence.makeDecoder()

    // 1. 나중에 추가될 필드가 이미 들어 있고, 지금 필드 하나가 빠진 파일.
    let futureJSON = """
    {
      "version": 99,
      "settings": {
        "weeklyBaseMinutes": 300,
        "penalties": [{"id":"\(UUID().uuidString)","name":"지각","minutes":10}],
        "benefits": [],
        "carryOverEnabled": true
      },
      "events": [],
      "unknownTopLevelKey": {"nested": 1}
    }
    """.data(using: .utf8)!

    guard let future = try? decoder.decode(PersistedState.self, from: futureJSON) else {
        failures.append("[testForwardCompatibleDecoding] 미래 형식 디코딩 실패")
        return
    }
    expectEqual(future.settings.weeklyBaseMinutes, 300, "있는 값은 살린다")
    expectEqual(future.settings.weekStart, AppSettings.default.weekStart, "없는 값은 기본값")
    expectEqual(future.settings.penalties.count, 1, "프리셋 유지")
    expectEqual(future.settings.benefits.count, 0, "빈 배열은 기본값으로 덮지 않는다")

    // 2. 기록 한 건이 깨져도 나머지는 살아남아야 한다.
    let partiallyCorrupt = """
    {
      "version": 1,
      "settings": {"weeklyBaseMinutes": 420, "weekStart": "monday", "penalties": [], "benefits": []},
      "events": [
        {"id":"\(UUID().uuidString)","kind":"penalty","name":"정상","minutes":30,"date":"2025-08-25T00:00:00Z"},
        {"id":"not-a-uuid","kind":"???","name":123},
        {"id":"\(UUID().uuidString)","kind":"benefit","name":"정상2","minutes":15,"date":"2025-08-26T00:00:00Z"}
      ]
    }
    """.data(using: .utf8)!

    guard let salvaged = try? decoder.decode(PersistedState.self, from: partiallyCorrupt) else {
        failures.append("[testForwardCompatibleDecoding] 부분 손상 디코딩 실패")
        return
    }
    expectEqual(salvaged.events.count, 2, "깨진 한 건만 버리고 나머지 보존")
    expectEqual(salvaged.events.map(\.name), ["정상", "정상2"], "살아남은 기록 순서")

    // 3. 알 수 없는 주 시작 값이 와도 기본값으로 열린다.
    let unknownEnum = """
    {"settings": {"weekStart": "wednesday", "weeklyBaseMinutes": 100}, "events": []}
    """.data(using: .utf8)!
    guard let lenient = try? decoder.decode(PersistedState.self, from: unknownEnum) else {
        failures.append("[testForwardCompatibleDecoding] 알 수 없는 enum 디코딩 실패")
        return
    }
    expectEqual(lenient.settings.weekStart, AppSettings.default.weekStart, "모르는 enum은 기본값")
    expectEqual(lenient.settings.weeklyBaseMinutes, 100, "같은 객체의 다른 값은 유지")
}

private func testPersistenceRoundTrip() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("gametimer-test-\(UUID().uuidString)", isDirectory: true)
    let persistence = Persistence(fileURL: directory.appendingPathComponent("store.json"))
    defer { try? FileManager.default.removeItem(at: directory) }

    // 파일이 없으면 nil(첫 실행). 이때 격리 파일을 만들면 안 된다.
    expect(persistence.load() == nil, "파일 없을 때는 nil")
    expect(!FileManager.default.fileExists(atPath: directory.path), "첫 실행에는 폴더조차 만들지 않는다")

    let state = PersistedState(settings: .default, events: [event(.penalty, 30, mondayAug25)])
    do {
        try persistence.save(state)
    } catch {
        failures.append("[testPersistenceRoundTrip] 저장 실패: \(error)")
        return
    }

    expect(FileManager.default.fileExists(atPath: persistence.fileURL.path), "저장 후 파일 존재")
    expectEqual(persistence.load()?.events.count, 1, "저장한 기록을 다시 읽음")

    // 깨진 파일은 격리하고 nil을 반환해 앱이 기본값으로 뜨게 한다.
    try? "이건 JSON이 아님".data(using: .utf8)!.write(to: persistence.fileURL)
    expect(persistence.load() == nil, "깨진 파일은 nil")
    let quarantined = (try? FileManager.default.contentsOfDirectory(atPath: directory.path))?
        .filter { $0.hasPrefix("store.corrupt-") } ?? []
    expectEqual(quarantined.count, 1, "깨진 파일이 격리됨")
    expect(!FileManager.default.fileExists(atPath: persistence.fileURL.path), "격리 후 원본은 사라짐")

    // 읽을 수 없는 파일(권한 없음)도 '첫 실행'으로 착각하지 않고 옆으로 치워 원본을 남긴다.
    // 구분하지 못하면 다음 저장이 멀쩡한 원본을 기본값으로 덮어써 버린다.
    let unreadable = PersistedState(settings: .default, events: [event(.benefit, 10, mondayAug25)])
    try? persistence.save(unreadable)
    try? FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: persistence.fileURL.path)
    expect(persistence.load() == nil, "읽을 수 없으면 nil")
    let quarantinedAfter = (try? FileManager.default.contentsOfDirectory(atPath: directory.path))?
        .filter { $0.hasPrefix("store.corrupt-") } ?? []
    expectEqual(quarantinedAfter.count, 2, "읽기 실패한 파일도 별도 이름으로 보존됨 (이름 충돌 없이)")
    expect(!FileManager.default.fileExists(atPath: persistence.fileURL.path), "치워졌으므로 다음 저장이 원본을 덮지 않는다")
    // 정리: 권한을 되돌려야 임시 폴더가 지워진다.
    for name in quarantinedAfter {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: directory.appendingPathComponent(name).path
        )
    }
}

@MainActor
private func testStoreBehavior() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("gametimer-store-\(UUID().uuidString)", isDirectory: true)
    let persistence = Persistence(fileURL: directory.appendingPathComponent("store.json"))
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = AppStore(persistence: persistence)
    let now = makeDate(2025, 8, 27, 15, 0)

    expectEqual(store.remainingMinutes(now: now), 420, "첫 실행 잔액은 기본 시간")
    expectEqual(store.events.count, 0, "첫 실행 기록 없음")

    store.apply(Preset(name: "숙제 미완료", minutes: 30), kind: .penalty, at: now)
    expectEqual(store.remainingMinutes(now: now), 390, "차감 반영")
    store.apply(Preset(name: "책 읽기", minutes: 15), kind: .benefit, at: now)
    expectEqual(store.remainingMinutes(now: now), 405, "추가 반영")
    expect(store.saveCount >= 2, "기록마다 즉시 저장")

    // 지난 주 기록은 이번 주 잔액에 영향을 주지 않는다.
    store.apply(Preset(name: "지난 주", minutes: 100), kind: .penalty, at: makeDate(2025, 8, 18, 12, 0))
    expectEqual(store.remainingMinutes(now: now), 405, "지난 주 기록은 이번 주 잔액과 무관")
    expectEqual(store.historySections(now: now).count, 2, "히스토리에는 두 주 모두 보임")

    // 주가 바뀌면 자동으로 기본 시간으로 돌아간다.
    let nextWeek = makeDate(2025, 9, 2, 10, 0)
    expectEqual(store.remainingMinutes(now: nextWeek), 420, "새 주는 기본 시간으로 리셋")

    // 기록 삭제(실수 탭 되돌리기).
    guard let toDelete = store.currentWeekEvents(now: now).first(where: { $0.name == "숙제 미완료" }) else {
        failures.append("[testStoreBehavior] 삭제할 기록을 찾지 못함")
        return
    }
    store.deleteEvent(id: toDelete.id)
    expectEqual(store.remainingMinutes(now: now), 435, "삭제 후 잔액 복구")

    // 설정 변경이 잔액에 즉시 반영된다.
    store.setWeeklyBaseMinutes(600)
    expectEqual(store.remainingMinutes(now: now), 615, "기본 시간 변경 반영")
    store.setWeeklyBaseMinutes(999_999)
    expectEqual(store.settings.weeklyBaseMinutes, AppSettings.maxWeeklyBaseMinutes, "기본 시간 상한 적용")

    // 프리셋 관리.
    let before = store.settings.penalties.count
    store.addPreset(Preset(name: "새 항목", minutes: 25), kind: .penalty)
    expectEqual(store.settings.penalties.count, before + 1, "프리셋 추가")
    store.addPreset(Preset(name: "  ", minutes: 25), kind: .penalty)
    expectEqual(store.settings.penalties.count, before + 1, "이름 없는 프리셋은 거부")

    guard var edited = store.settings.penalties.last else {
        failures.append("[testStoreBehavior] 프리셋을 찾지 못함")
        return
    }
    edited.minutes = 45
    store.updatePreset(edited, kind: .penalty)
    expectEqual(store.settings.penalties.last?.minutes, 45, "프리셋 수정")

    store.deletePresets(at: IndexSet(integer: store.settings.penalties.count - 1), kind: .penalty)
    expectEqual(store.settings.penalties.count, before, "프리셋 삭제")

    // 주 시작 요일을 바꾸면 묶음이 다시 계산된다.
    store.setWeekStart(.sunday)
    expectEqual(store.settings.weekStart, .sunday, "주 시작 변경")
    expectEqual(store.calendar.firstWeekday, 1, "달력에 반영")

    // 디스크에 실제로 남았는지 새 스토어로 확인.
    store.flushSaves()
    let reloaded = AppStore(persistence: persistence)
    expectEqual(reloaded.settings.weekStart, .sunday, "설정이 디스크에서 복원됨")
    expectEqual(reloaded.events.count, store.events.count, "기록이 디스크에서 복원됨")
    expectEqual(reloaded.settings.weeklyBaseMinutes, AppSettings.maxWeeklyBaseMinutes, "정리된 값으로 복원")
}

@MainActor
private func testPresetReordering() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("gametimer-move-\(UUID().uuidString)", isDirectory: true)
    let persistence = Persistence(fileURL: directory.appendingPathComponent("store.json"))
    defer { try? FileManager.default.removeItem(at: directory) }

    func freshStore() -> AppStore {
        try? FileManager.default.removeItem(at: directory)
        let store = AppStore(persistence: persistence)
        store.deletePresets(at: IndexSet(store.settings.penalties.indices), kind: .penalty)
        for name in ["A", "B", "C", "D"] {
            store.addPreset(Preset(name: name, minutes: 10), kind: .penalty)
        }
        return store
    }

    func names(_ store: AppStore) -> [String] { store.settings.penalties.map(\.name) }

    // 위에서 아래로: A를 C 앞자리로. SwiftUI는 제거 전 인덱스 기준으로 destination을 준다.
    var store = freshStore()
    expectEqual(names(store), ["A", "B", "C", "D"], "재정렬 전 순서")
    store.movePresets(from: IndexSet(integer: 0), to: 2, kind: .penalty)
    expectEqual(names(store), ["B", "A", "C", "D"], "앞 항목을 뒤로 이동")

    // 아래에서 위로: D를 맨 앞으로.
    store = freshStore()
    store.movePresets(from: IndexSet(integer: 3), to: 0, kind: .penalty)
    expectEqual(names(store), ["D", "A", "B", "C"], "뒤 항목을 맨 앞으로 이동")

    // 여러 개를 한 번에.
    store = freshStore()
    store.movePresets(from: IndexSet([0, 1]), to: 4, kind: .penalty)
    expectEqual(names(store), ["C", "D", "A", "B"], "두 항목을 맨 뒤로 이동")

    // 제자리 이동은 순서를 바꾸지 않는다.
    store = freshStore()
    store.movePresets(from: IndexSet(integer: 1), to: 1, kind: .penalty)
    expectEqual(names(store), ["A", "B", "C", "D"], "제자리 이동")

    // 범위를 벗어난 입력에도 크래시하지 않는다.
    store = freshStore()
    store.movePresets(from: IndexSet(integer: 99), to: 0, kind: .penalty)
    expectEqual(names(store), ["A", "B", "C", "D"], "잘못된 인덱스는 무시")
    store.deletePresets(at: IndexSet([99, 100]), kind: .penalty)
    expectEqual(names(store), ["A", "B", "C", "D"], "잘못된 삭제 인덱스는 무시")

    // 차감 목록을 건드려도 추가 목록은 그대로여야 한다.
    expectEqual(store.settings.benefits.count, AppSettings.default.benefits.count, "다른 목록은 영향 없음")
}

private func testScreenCare() {
    // 픽셀 시프트: 네 모서리를 순환하고, 같은 주기 안에서는 값이 바뀌지 않는다.
    let base = makeDate(2025, 8, 25, 0, 0)
    let interval = ScreenCare.shiftInterval
    var seen: [String] = []
    for step in 0..<4 {
        let shift = ScreenCare.pixelShift(at: base.addingTimeInterval(interval * Double(step)))
        seen.append("\(shift.x),\(shift.y)")
        expectEqual(abs(shift.x), ScreenCare.shiftAmplitude, "시프트 x 크기")
        expectEqual(abs(shift.y), ScreenCare.shiftAmplitude, "시프트 y 크기")
    }
    expectEqual(Set(seen).count, 4, "네 위치가 모두 달라야 한다")

    // 다섯 번째는 처음으로 되돌아온다.
    let wrapped = ScreenCare.pixelShift(at: base.addingTimeInterval(interval * 4))
    expectEqual("\(wrapped.x),\(wrapped.y)", seen[0], "한 바퀴 돌면 처음 위치")

    // 주기 안에서는 고정.
    let early = ScreenCare.pixelShift(at: base.addingTimeInterval(1))
    let late = ScreenCare.pixelShift(at: base.addingTimeInterval(interval - 1))
    expectEqual("\(early.x),\(early.y)", "\(late.x),\(late.y)", "같은 주기 안에서는 안 움직인다")

    // 1970년 이전 날짜에서도 인덱스가 음수로 새지 않는다.
    let ancient = ScreenCare.pixelShift(at: Date(timeIntervalSince1970: -100_000))
    expectEqual(abs(ancient.x), ScreenCare.shiftAmplitude, "과거 시각에서도 정상")

    // 유휴 판정: 임계값 경계 포함.
    let now = makeDate(2025, 8, 25, 12, 0)
    let threshold = ScreenCare.idleThreshold
    expect(!ScreenCare.isIdle(now: now, lastInteraction: now), "방금 만졌으면 유휴 아님")
    expect(
        !ScreenCare.isIdle(now: now, lastInteraction: now.addingTimeInterval(-threshold + 1)),
        "임계값 직전은 유휴 아님"
    )
    expect(
        ScreenCare.isIdle(now: now, lastInteraction: now.addingTimeInterval(-threshold)),
        "임계값에 도달하면 유휴"
    )
    expect(
        ScreenCare.isIdle(now: now, lastInteraction: now.addingTimeInterval(-3600)),
        "한참 지났으면 유휴"
    )

    // 어둡게 낮출 밝기는 화면이 꺼지지 않을 만큼은 남아 있어야 한다.
    expect(ScreenCare.dimmedBrightness > 0, "완전히 끄지는 않는다")
    expect(ScreenCare.dimmedBrightness < 0.5, "충분히 어둡다")
}

// MARK: - Runner

@main
struct LogicTests {
    @MainActor
    static func main() {
        testDurationFormatting()
        testWeekIntervalMondayStart()
        testWeekIntervalSundayStart()
        testWeekIntervalAcrossYearBoundary()
        testDaylightSavingWeek()
        testHalfOpenContainment()
        testLedgerMath()
        testGrouping()
        testGroupingFollowsWeekStartSetting()
        testDateTitles()
        testSanitizing()
        testCodableRoundTrip()
        testForwardCompatibleDecoding()
        testPersistenceRoundTrip()
        testStoreBehavior()
        testPresetReordering()
        testScreenCare()

        if failures.isEmpty {
            print("통과: \(checks)개 검사 모두 성공")
        } else {
            print("실패 \(failures.count)건 / 전체 \(checks)개 검사")
            for failure in failures {
                print("  - \(failure)")
            }
            exit(1)
        }
    }
}
