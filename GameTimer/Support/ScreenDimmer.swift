import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 화면 밝기를 직접 낮췄다 되돌린다.
///
/// LCD에서는 화면 위에 반투명 막을 씌워도 백라이트가 그대로라 전력·발열·수명에 아무 도움이 안 된다.
/// 실제로 줄이려면 시스템 밝기를 건드려야 한다. 보통 앱이 할 일은 아니지만,
/// 이 앱은 안내 접근으로 고정해 24시간 켜 두는 전용 기기를 상정하므로 예외로 둔다.
@MainActor
final class ScreenDimmer {

    /// 어둡게 만들기 전 밝기. 되돌릴 때 쓴다.
    private var restoreLevel: Double?

    func dim(to level: Double) {
        #if canImport(UIKit)
        guard let screen = Self.currentScreen else { return }
        if restoreLevel == nil {
            restoreLevel = Double(screen.brightness)
        }
        // 이미 사용자가 더 어둡게 해 뒀다면 굳이 올리지 않는다.
        guard Double(screen.brightness) > level else { return }
        screen.brightness = CGFloat(level)
        #endif
    }

    /// 원래 밝기로. 앱이 배경으로 갈 때도 반드시 불러서 기기를 어두운 채 두지 않는다.
    func restore() {
        #if canImport(UIKit)
        guard let level = restoreLevel, let screen = Self.currentScreen else { return }
        screen.brightness = CGFloat(level)
        #endif
        restoreLevel = nil
    }

    #if canImport(UIKit)
    /// `UIScreen.main`은 더 이상 권장되지 않아 활성 씬의 화면을 쓴다.
    private static var currentScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen
    }
    #endif
}

extension ScreenCare {
    /// 전용 기기로 세워 두는 아이패드에서만 켠다.
    /// 아이폰은 자동 잠금이 알아서 화면을 끄고, 손에 들고 쓰는 기기에서 밝기가 멋대로 바뀌면 성가시다.
    @MainActor
    static var appliesToThisDevice: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
}

#if canImport(UIKit)
/// 창 전체에서 터치를 **관찰만** 한다. 어느 화면에서 무엇을 눌러도 "사용 중"으로 잡히게 하려는 것.
///
/// `cancelsTouchesInView = false` 이고 다른 제스처와 동시 인식을 허용하므로
/// 버튼 누름이나 스크롤 같은 기존 동작을 전혀 가로채지 않는다.
struct ActivityObserver: UIViewRepresentable {
    let onActivity: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onActivity: onActivity) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        // 이 시점에는 아직 창에 붙기 전이라 다음 런루프에 붙인다.
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onActivity = onActivity
        context.coordinator.attach(to: uiView.window)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onActivity: () -> Void
        private weak var attached: UIGestureRecognizer?

        init(onActivity: @escaping () -> Void) {
            self.onActivity = onActivity
        }

        func attach(to window: UIWindow?) {
            guard let window, attached == nil else { return }
            // 최소 누름 시간 0 = 손가락이 닿는 순간 발동. 탭뿐 아니라 스크롤·드래그도 잡힌다.
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(touched))
            recognizer.minimumPressDuration = 0
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            attached = recognizer
        }

        @objc private func touched() { onActivity() }

        nonisolated func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
#endif
