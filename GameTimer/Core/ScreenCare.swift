import Foundation

/// 같은 화면을 계속 띄워 두는 전용 기기(사용법 유도로 고정한 아이패드)를 위한 계산.
///
/// UI에 의존하지 않는 순수 함수만 두어 CLI 테스트로 검증한다. 실제 밝기 조절은 `ScreenDimmer`가 한다.
enum ScreenCare {

    // MARK: - 픽셀 시프트

    /// 내용을 옮기는 폭(pt). 눈에 띄지 않으면서도 같은 픽셀이 계속 켜져 있지 않을 만큼만.
    static let shiftAmplitude: Double = 3

    /// 위치를 바꾸는 주기(초).
    static let shiftInterval: TimeInterval = 120

    /// 시각에 따라 내용을 옮길 거리. 네 모서리를 2분마다 순환한다.
    ///
    /// LCD에서는 번인이 사실상 없지만 비용이 없고, 나중에 OLED 기기로 바꿔도 그대로 대비된다.
    static func pixelShift(at date: Date) -> (x: Double, y: Double) {
        let step = Int((date.timeIntervalSince1970 / shiftInterval).rounded(.down)) % 4
        // 음수 나머지를 0...3으로 정규화한다(1970년 이전 날짜에도 안전하게).
        let index = (step + 4) % 4
        let a = shiftAmplitude
        switch index {
        case 0: return (-a, -a)
        case 1: return (a, -a)
        case 2: return (a, a)
        default: return (-a, a)
        }
    }

    // MARK: - 유휴 감지

    /// 손을 대지 않고 이 시간이 지나면 화면을 어둡게 한다.
    static let idleThreshold: TimeInterval = 120

    /// 유휴 상태에서 낮출 화면 밝기(0...1). 글자는 읽히되 백라이트 부담은 크게 준다.
    static let dimmedBrightness: Double = 0.12

    static func isIdle(now: Date, lastInteraction: Date, threshold: TimeInterval = idleThreshold) -> Bool {
        now.timeIntervalSince(lastInteraction) >= threshold
    }
}
