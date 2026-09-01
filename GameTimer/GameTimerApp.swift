import SwiftUI

@main
struct GameTimerApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(store)
                // 강조색까지 회색조로 맞춘다. 라이트/다크는 시스템 설정을 그대로 따른다.
                .tint(.primary)
                .onChange(of: scenePhase) { _, phase in
                    // 홈으로 나가거나 앱 전환기에 들어갈 때 대기 중인 저장을 확정한다.
                    if phase != .active { store.flushSaves() }
                }
        }
    }
}
