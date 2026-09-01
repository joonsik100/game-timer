import SwiftUI

struct MainView: View {
    @Environment(AppStore.self) private var store
    @State private var showSettings = false
    @State private var showAuthFailure = false
    /// 인증 시트가 떠 있는 동안 다른 버튼이 또 인증을 걸지 못하게 막는다.
    /// 차감 열과 추가 열이 함께 봐야 하므로 여기서 소유한다.
    @State private var isAuthenticating = false

    // 전용 기기(사용법 유도로 고정한 아이패드)를 오래 켜 둘 때 화면을 아끼기 위한 상태.
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastInteraction = Date()
    @State private var dimmer = ScreenDimmer()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                TimelineView(.everyMinute) { context in
                    screenCared(layout(in: geometry.size, now: context.date), now: context.date)
                }
            }
            .background(activityObserver)
            .navigationTitle(L10n.appTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .authFailureAlert(isPresented: $showAuthFailure)
            .onChange(of: scenePhase) { _, phase in
                // 배경으로 나갈 때 밝기를 반드시 되돌린다. 기기를 어두운 채로 두면 안 된다.
                if phase != .active {
                    dimmer.restore()
                } else {
                    registerActivity()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label(L10n.history, systemImage: "list.bullet.rectangle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // 설정에서 기본 시간과 항목을 바꾸면 잔여 시간이 달라지므로 여기도 잠근다.
                    Button {
                        guard !isAuthenticating else { return }
                        isAuthenticating = true
                        Task {
                            switch await BiometricGate.authenticate(reason: L10n.authReasonSettings) {
                            case .success: showSettings = true
                            case .cancelled: break
                            case .failed: showAuthFailure = true
                            }
                            isAuthenticating = false
                        }
                    } label: {
                        Label(L10n.settings, systemImage: "gearshape")
                    }
                }
            }
        }
    }

    /// 가로로 넓으면(아이패드 가로) 왼쪽에 시간, 오른쪽에 버튼. 세로로 길면(아이폰) 위에 시간, 아래에 버튼.
    ///
    /// 기기 종류가 아니라 실제 화면 비율로 판단하기 때문에 아이패드 멀티태스킹으로 창이 좁아져도 자연스럽게 세로 배치로 바뀐다.
    @ViewBuilder
    private func layout(in size: CGSize, now: Date) -> some View {
        let isWide = size.width > size.height
        let clockPane = clockPaneSize(in: size, isWide: isWide)

        // `now`는 1분마다 갱신된다. 주가 바뀌는 순간 자정 눈금에서 잔액이 저절로 초기화된다.
        let clock = RemainingTimeView(
            minutes: store.remainingMinutes(now: now),
            baseMinutes: store.settings.weeklyBaseMinutes,
            fontSize: timeFontSize(clockPane: clockPane, isWide: isWide),
            saveFailed: store.saveFailed
        )

        if isWide {
            HStack(spacing: 0) {
                clock.frame(width: clockPane.width)
                Divider()
                // 아이패드는 세로 여유가 많아 버튼이 위로 몰린다. 남는 높이를 알려 주고 가운데 정렬한다.
                AdjustmentColumns(fillHeight: size.height, prominent: true, isAuthenticating: $isAuthenticating)
            }
        } else {
            VStack(spacing: 0) {
                clock.frame(height: clockPane.height)
                Divider()
                AdjustmentColumns(fillHeight: nil, prominent: false, isAuthenticating: $isAuthenticating)
            }
        }
    }

    // MARK: - 화면 보호 (전용 기기용)

    /// 같은 화면을 오래 띄워 두는 경우를 대비해 내용을 조금씩 움직이고, 손을 대지 않으면 밝기를 낮춘다.
    @ViewBuilder
    private func screenCared(_ content: some View, now: Date) -> some View {
        let shift = ScreenCare.pixelShift(at: now)
        let dimmed = ScreenCare.appliesToThisDevice
            && ScreenCare.isIdle(now: now, lastInteraction: lastInteraction)

        content
            .offset(x: shift.x, y: shift.y)
            .overlay {
                if dimmed {
                    // 어두워진 상태의 첫 터치는 깨우는 데만 쓰고 버튼으로 넘기지 않는다.
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { registerActivity() }
                }
            }
            .onChange(of: dimmed) { _, isDimmed in
                if isDimmed {
                    dimmer.dim(to: ScreenCare.dimmedBrightness)
                } else {
                    dimmer.restore()
                }
            }
    }

    @ViewBuilder
    private var activityObserver: some View {
        #if canImport(UIKit)
        ActivityObserver { registerActivity() }
        #else
        Color.clear
        #endif
    }

    private func registerActivity() {
        lastInteraction = Date()
        dimmer.restore()
    }

    private func clockPaneSize(in size: CGSize, isWide: Bool) -> CGSize {
        isWide
            ? CGSize(width: max(size.width * 0.42, 240), height: size.height)
            : CGSize(width: size.width, height: max(size.height * 0.42, 180))
    }

    /// 남은 시간 글자 크기. 아이폰 세로에서는 기존 크기(약 84pt)가 그대로 나오고,
    /// 가로 배치에서는 세로 여유가 많으므로 폭 대비 비율을 조금 더 키운다.
    private func timeFontSize(clockPane: CGSize, isWide: Bool) -> CGFloat {
        let widthFactor: CGFloat = isWide ? 0.24 : 0.21
        return min(max(min(clockPane.width * widthFactor, clockPane.height * 0.34), 44), 220)
    }
}

// MARK: - Remaining time

private struct RemainingTimeView: View {
    let minutes: Int
    let baseMinutes: Int
    let fontSize: CGFloat
    let saveFailed: Bool

    var body: some View {
        VStack(spacing: fontSize * 0.1) {
            Text(L10n.remainingTime)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text(TimeFormat.hhmm(minutes))
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            Text(subtitle)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            // 저장에 실패했는데 아무 표시가 없으면, 기록이 남은 줄 알고 계속 쓰다가 다음 실행에서 잃는다.
            if saveFailed {
                Label(L10n.saveFailed, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .animation(.snappy, value: minutes)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.remainingTime) \(accessibleDuration)")
    }

    private var subtitle: String {
        minutes < 0 ? L10n.overdrawn : "기본 \(TimeFormat.hhmm(baseMinutes))"
    }

    /// "01:48"을 그대로 읽으면 날짜처럼 들려서, 음성용으로는 풀어서 준다.
    private var accessibleDuration: String {
        let total = minutes.magnitude
        let prefix = minutes < 0 ? "마이너스 " : ""
        return "\(prefix)\(total / 60)시간 \(total % 60)분"
    }
}

// MARK: - Adjustment buttons

private struct AdjustmentColumns: View {
    @Environment(AppStore.self) private var store
    /// 값이 있으면 그 높이만큼 채우고 가운데 정렬한다. nil이면 위에서부터 쌓는다.
    let fillHeight: CGFloat?
    let prominent: Bool
    @Binding var isAuthenticating: Bool

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: prominent ? 16 : 12) {
                AdjustmentColumn(kind: .penalty, prominent: prominent, isAuthenticating: $isAuthenticating)
                AdjustmentColumn(kind: .benefit, prominent: prominent, isAuthenticating: $isAuthenticating)
            }
            .padding(.horizontal, prominent ? 24 : 16)
            .padding(.vertical, prominent ? 24 : 16)
            // 내용이 짧으면 가운데로, 길면 그대로 스크롤된다.
            .frame(minHeight: fillHeight, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        .sensoryFeedback(.impact(weight: .medium), trigger: store.events.count)
    }
}

private struct AdjustmentColumn: View {
    @Environment(AppStore.self) private var store
    let kind: AdjustmentKind
    let prominent: Bool
    @Binding var isAuthenticating: Bool

    @State private var showAuthFailure = false

    private var presets: [Preset] { store.presets(for: kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: prominent ? 14 : 10) {
            Text(kind == .penalty ? L10n.penaltyColumn : L10n.benefitColumn)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            if presets.isEmpty {
                Text(L10n.noPresets)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            } else {
                ForEach(presets) { preset in
                    Button {
                        // 아이가 몰래 시간을 바꾸지 못하도록 누를 때마다 본인 확인을 받는다.
                        //
                        // 인증이 진행 중이면 무시한다. 이 가드가 없으면 두 번째 탭이 첫 번째 인증을
                        // 취소시켜, 먼저 누른 조정이 아무 안내 없이 사라진다.
                        guard !isAuthenticating else { return }
                        isAuthenticating = true
                        Task {
                            switch await BiometricGate.authenticate(reason: L10n.authReasonAdjust) {
                            case .success: store.apply(preset, kind: kind)
                            case .cancelled: break
                            case .failed: showAuthFailure = true
                            }
                            isAuthenticating = false
                        }
                    } label: {
                        AdjustmentButtonLabel(preset: preset, kind: kind, prominent: prominent)
                    }
                    .buttonStyle(AdjustmentButtonStyle(kind: kind, prominent: prominent))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .authFailureAlert(isPresented: $showAuthFailure)
    }
}

#Preview {
    MainView()
        .environment(AppStore(persistence: Persistence(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-store.json")
        )))
        .tint(.primary)
}
