import Foundation
import Observation

/// 앱 상태 전체. 설정과 기록을 들고 있고, 화면이 필요로 하는 값은 전부 여기서 계산해 준다.
///
/// 상태를 바꾸는 길은 아래 메서드들뿐이다(`private(set)`). 덕분에 저장 시점이 한곳으로 모이고,
/// `@Observable`이 저장 프로퍼티를 계산 프로퍼티로 바꾸면서 `didSet`이 사라지는 함정도 피한다.
@MainActor
@Observable
final class AppStore {

    private(set) var settings: AppSettings
    private(set) var events: [AdjustmentEvent]

    /// 마지막 저장이 실패했는지. 실패를 조용히 삼키면 화면 숫자와 디스크가 갈라진 채로
    /// 다음 실행에서 기록이 통째로 사라지므로, 화면에 표시해서 알린다.
    private(set) var saveFailed = false

    @ObservationIgnored private let persistence: Persistence
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// 테스트에서 저장이 실제로 일어났는지 확인하는 용도.
    @ObservationIgnored private(set) var saveCount = 0

    init(persistence: Persistence = .default) {
        self.persistence = persistence
        if let state = persistence.load() {
            self.settings = state.settings.sanitized()
            self.events = state.events
        } else {
            self.settings = .default
            self.events = []
        }
    }

    // MARK: - Derived state

    /// 주 시작 요일 설정과 현재 시간대를 반영한 달력. 화면 한 번 그릴 때 한 번만 꺼내 쓰면 된다.
    var calendar: Calendar {
        WeekMath.calendar(weekStart: settings.weekStart)
    }

    func currentWeek(now: Date) -> DateInterval {
        WeekMath.weekInterval(containing: now, calendar: calendar)
    }

    /// 이번 주 기록만. 최신순.
    func currentWeekEvents(now: Date) -> [AdjustmentEvent] {
        WeekMath.events(in: currentWeek(now: now), from: events)
            .sorted { $0.date > $1.date }
    }

    /// 남은 시간. 기본 시간에 이번 주 차감/추가를 모두 반영한 값이라 음수도 나올 수 있다.
    func remainingMinutes(now: Date) -> Int {
        settings.weeklyBaseMinutes + WeekMath.net(WeekMath.events(in: currentWeek(now: now), from: events))
    }

    func historySections(now: Date) -> [WeekSection] {
        WeekMath.groupByWeekThenDay(events, calendar: calendar)
    }

    func presets(for kind: AdjustmentKind) -> [Preset] {
        kind == .penalty ? settings.penalties : settings.benefits
    }

    // MARK: - Event mutations

    /// 버튼 한 번 = 기록 한 건. 이름과 분은 지금 값으로 박제해서 나중에 프리셋을 고쳐도 과거가 변하지 않는다.
    func apply(_ preset: Preset, kind: AdjustmentKind, at date: Date = Date()) {
        let event = AdjustmentEvent(
            kind: kind,
            name: preset.name,
            minutes: max(preset.minutes, 0),
            date: date
        )
        events.append(event)
        persistNow()
    }

    func deleteEvent(id: UUID) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        events.remove(at: index)
        persistNow()
    }

    // MARK: - Settings mutations

    func setWeeklyBaseMinutes(_ minutes: Int) {
        let clamped = min(max(minutes, 0), AppSettings.maxWeeklyBaseMinutes)
        guard clamped != settings.weeklyBaseMinutes else { return }
        settings.weeklyBaseMinutes = clamped
        persistSoon()
    }

    func setWeekStart(_ weekStart: WeekStart) {
        guard weekStart != settings.weekStart else { return }
        settings.weekStart = weekStart
        persistNow()
    }

    func addPreset(_ preset: Preset, kind: AdjustmentKind) {
        guard let clean = preset.sanitized() else { return }
        updatePresets(kind) { $0.append(clean) }
    }

    func updatePreset(_ preset: Preset, kind: AdjustmentKind) {
        guard let clean = preset.sanitized() else { return }
        updatePresets(kind) { list in
            guard let index = list.firstIndex(where: { $0.id == clean.id }) else { return }
            list[index] = clean
        }
    }

    func deletePresets(at offsets: IndexSet, kind: AdjustmentKind) {
        updatePresets(kind) { list in
            for index in offsets.sorted(by: >) where list.indices.contains(index) {
                list.remove(at: index)
            }
        }
    }

    /// SwiftUI `onMove`와 같은 규칙: `destination`은 원소를 빼기 *전* 기준의 삽입 위치다.
    ///
    /// (`remove(atOffsets:)`/`move(fromOffsets:toOffset:)`는 SwiftUI가 붙여 주는 확장이라
    /// Foundation만 쓰는 이 파일에서는 직접 구현한다.)
    func movePresets(from source: IndexSet, to destination: Int, kind: AdjustmentKind) {
        updatePresets(kind) { list in
            let indices = source.sorted().filter { list.indices.contains($0) }
            guard !indices.isEmpty else { return }
            let moving = indices.map { list[$0] }
            let insertAt = destination - indices.filter { $0 < destination }.count
            for index in indices.reversed() {
                list.remove(at: index)
            }
            list.insert(contentsOf: moving, at: min(max(insertAt, 0), list.count))
        }
    }

    private func updatePresets(_ kind: AdjustmentKind, _ mutate: (inout [Preset]) -> Void) {
        switch kind {
        case .penalty: mutate(&settings.penalties)
        case .benefit: mutate(&settings.benefits)
        }
        persistNow()
    }

    // MARK: - Persistence

    /// 앱이 배경으로 갈 때 호출. 대기 중인 저장을 즉시 확정한다.
    func flushSaves() {
        persistNow()
    }

    /// 기록 추가/삭제처럼 잃으면 안 되는 변경은 곧바로 디스크에 쓴다.
    private func persistNow() {
        saveTask?.cancel()
        saveTask = nil
        do {
            try persistence.save(PersistedState(settings: settings, events: events))
            saveCount += 1
            saveFailed = false
        } catch {
            // 저장 공간 부족이 현실적인 원인이다. 여기서 조용히 넘어가면 사용자는 기록이
            // 남은 줄 알고 계속 쓰다가, 다음 실행에서 통째로 잃는다.
            saveFailed = true
            print("GameTimer: 저장 실패 - \(error)")
        }
    }

    /// 텍스트 필드처럼 한 글자마다 값이 바뀌는 변경은 잠깐 모았다가 쓴다.
    private func persistSoon() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.persistNow()
        }
    }
}
