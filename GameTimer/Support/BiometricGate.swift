import LocalAuthentication
import SwiftUI

/// 시간을 바꾸는 동작과 설정 진입 앞에 기기 잠금(Face ID / Touch ID / 기기 암호)을 세운다.
///
/// 아이가 몰래 시간을 늘리거나 이미 받은 차감 기록을 지우지 못하게 하는 것이 목적이라,
/// 시간에 영향을 주는 길목은 전부 막는다: 차감/추가 버튼, 기록 삭제, 설정 화면.
enum BiometricGate {

    enum Outcome {
        case success
        /// 사용자가 직접 취소했다. 이미 의도한 행동이라 따로 알리지 않는다.
        case cancelled
        /// 확인에 실패했다. 사용자에게 알려 준다.
        case failed
    }

    static func authenticate(reason: String) async -> Outcome {
        let context = LAContext()
        context.localizedCancelTitle = L10n.cancel

        // 생체 인식만 요구하면 얼굴을 몇 번 못 알아봤을 때 잠겨 버려 부모가 앱을 못 쓰게 된다.
        // 기기 암호까지 허용하는 정책을 쓰면 그런 막다른 길이 없다.
        let policy = LAPolicy.deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: nil) else {
            // 기기에 암호 자체가 없으면 확인할 수단이 없다. 여기서 막으면 앱을 아예 못 쓰게 되는데,
            // 애초에 기기에 잠금이 없으므로 지킬 경계도 없다. 그대로 통과시킨다.
            return .success
        }

        do {
            let approved = try await context.evaluatePolicy(policy, localizedReason: reason)
            return approved ? .success : .failed
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                return .cancelled
            default:
                return .failed
            }
        } catch {
            return .failed
        }
    }
}

extension View {
    /// 본인 확인에 실패했을 때 띄우는 알림. 문구가 한 가지뿐이라 화면마다 따로 만들지 않는다.
    func authFailureAlert(isPresented: Binding<Bool>) -> some View {
        alert(L10n.authFailedTitle, isPresented: isPresented) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.authFailedMessage)
        }
    }
}
