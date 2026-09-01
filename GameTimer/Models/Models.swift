import Foundation

// MARK: - Adjustment kind

/// 시간을 깎는 항목(차감)인지 더하는 항목(추가)인지.
enum AdjustmentKind: String, Codable, Hashable, CaseIterable {
    case penalty
    case benefit

    /// 잔여 시간에 적용할 부호.
    var sign: Int { self == .benefit ? 1 : -1 }
}

// MARK: - Preset

/// 설정 화면에서 관리하는 버튼 항목. `minutes`는 항상 양수로 저장하고 부호는 `kind`가 결정한다.
struct Preset: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var minutes: Int

    init(id: UUID = UUID(), name: String, minutes: Int) {
        self.id = id
        self.name = name
        self.minutes = minutes
    }
}

// MARK: - Adjustment event

/// 실제로 눌린 기록 한 건. `name`/`minutes`는 누른 시점의 스냅샷이라 이후 프리셋을 고쳐도 과거 기록은 변하지 않는다.
struct AdjustmentEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: AdjustmentKind
    var name: String
    var minutes: Int
    var date: Date

    init(id: UUID = UUID(), kind: AdjustmentKind, name: String, minutes: Int, date: Date) {
        self.id = id
        self.kind = kind
        self.name = name
        self.minutes = minutes
        self.date = date
    }

    var signedMinutes: Int { kind.sign * minutes }
}

// MARK: - Week start

enum WeekStart: String, Codable, Hashable, CaseIterable {
    case monday
    case sunday

    /// `Calendar.firstWeekday` 규약: 1 = 일요일, 2 = 월요일.
    var firstWeekday: Int { self == .sunday ? 1 : 2 }
}

// MARK: - Settings

struct AppSettings: Codable, Hashable {
    var weeklyBaseMinutes: Int
    var weekStart: WeekStart
    var penalties: [Preset]
    var benefits: [Preset]

    init(weeklyBaseMinutes: Int, weekStart: WeekStart, penalties: [Preset], benefits: [Preset]) {
        self.weeklyBaseMinutes = weeklyBaseMinutes
        self.weekStart = weekStart
        self.penalties = penalties
        self.benefits = benefits
    }

    /// 필드가 없거나 깨져 있어도 기본값으로 살아남는 관대한 디코딩. 나중에 필드를 추가해도 옛 파일이 계속 열린다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.default
        weeklyBaseMinutes = c.lenient(Int.self, forKey: .weeklyBaseMinutes, default: fallback.weeklyBaseMinutes)
        weekStart = c.lenient(WeekStart.self, forKey: .weekStart, default: fallback.weekStart)
        penalties = c.lenientArray(Preset.self, forKey: .penalties, default: fallback.penalties)
        benefits = c.lenientArray(Preset.self, forKey: .benefits, default: fallback.benefits)
    }

    /// 사용자가 입력한 값을 안전한 범위로 정리한다. 저장 직전에 호출.
    func sanitized() -> AppSettings {
        AppSettings(
            weeklyBaseMinutes: min(max(weeklyBaseMinutes, 0), AppSettings.maxWeeklyBaseMinutes),
            weekStart: weekStart,
            penalties: penalties.compactMap { $0.sanitized() },
            benefits: benefits.compactMap { $0.sanitized() }
        )
    }

    /// 주 100시간이면 현실적인 상한을 크게 넘어선다. 오버플로와 표시 깨짐을 함께 막는다.
    static let maxWeeklyBaseMinutes = 6000
}

extension Preset {
    /// 이름이 비면 버리고, 분은 1...1440으로 자른다.
    func sanitized() -> Preset? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Preset(id: id, name: trimmed, minutes: min(max(minutes, 1), 1440))
    }
}

// MARK: - Persisted state

struct PersistedState: Codable {
    static let currentVersion = 1

    var version: Int
    var settings: AppSettings
    var events: [AdjustmentEvent]

    init(version: Int = PersistedState.currentVersion, settings: AppSettings, events: [AdjustmentEvent]) {
        self.version = version
        self.settings = settings
        self.events = events
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.lenient(Int.self, forKey: .version, default: PersistedState.currentVersion)
        settings = c.lenient(AppSettings.self, forKey: .settings, default: .default)
        // 기록 한 건이 깨졌다고 원장 전체를 버리지 않는다.
        events = c.lenientArray(AdjustmentEvent.self, forKey: .events, default: [])
    }
}

// MARK: - Lenient decoding helpers

/// 원소 하나가 깨져도 배열 전체를 잃지 않도록, 실패를 nil로 흡수하는 래퍼.
private struct LossyElement<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

extension KeyedDecodingContainer {
    /// 키가 없거나 값이 깨졌으면 기본값을 쓴다.
    /// (`try?`가 옵셔널을 평탄화하므로 "키 없음"과 "디코딩 실패"가 똑같이 nil로 떨어진다 — 둘 다 기본값이면 된다.)
    func lenient<T: Decodable>(_ type: T.Type, forKey key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(type, forKey: key)) ?? fallback
    }

    /// 키가 없으면 기본값, 있으면 디코딩 가능한 원소만 살린다. 빈 배열은 빈 배열 그대로 둔다.
    func lenientArray<T: Decodable>(_ type: T.Type, forKey key: Key, default fallback: [T]) -> [T] {
        guard let wrapped = try? decodeIfPresent([LossyElement<T>].self, forKey: key) else { return fallback }
        return wrapped.compactMap(\.value)
    }
}
