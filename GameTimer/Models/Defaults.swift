import Foundation

extension AppSettings {
    /// 첫 실행 기본값. 주 420분 = 하루 1시간.
    static let `default` = AppSettings(
        weeklyBaseMinutes: 420,
        weekStart: .monday,
        penalties: [
            Preset(name: "숙제 미완료", minutes: 30),
            Preset(name: "약속 시간 어김", minutes: 20),
            Preset(name: "게임 시간 초과", minutes: 30),
            Preset(name: "정리 안 함", minutes: 15),
            Preset(name: "거짓말", minutes: 60),
        ],
        benefits: [
            Preset(name: "책 읽기", minutes: 15),
            Preset(name: "심부름", minutes: 10),
            Preset(name: "운동하기", minutes: 20),
            Preset(name: "숙제 미리 끝냄", minutes: 20),
            Preset(name: "시험 잘 봄", minutes: 60),
        ]
    )
}
