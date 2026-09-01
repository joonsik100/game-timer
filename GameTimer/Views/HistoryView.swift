import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State private var showAuthFailure = false

    /// 주 제목("이번 주"/"지난 주")을 정하는 기준 시각. 화면을 열 때마다 갱신한다.
    /// 여기서 TimelineView를 쓰면 1분마다 List가 다시 만들어져 스크롤이 튀기 때문에 쓰지 않는다.
    @State private var now = Date()

    var body: some View {
        let calendar = store.calendar
        let sections = store.historySections(now: now)

        Group {
            if sections.isEmpty {
                ContentUnavailableView {
                    Label(L10n.noHistory, systemImage: "clock.arrow.circlepath")
                } description: {
                    Text(L10n.noHistoryHint)
                }
            } else {
                List {
                    ForEach(sections) { week in
                        Section {
                            ForEach(week.days) { day in
                                DayHeaderRow(day: day, calendar: calendar)
                                ForEach(day.events) { event in
                                    HistoryRow(event: event, calendar: calendar)
                                        .swipeActions(edge: .trailing) {
                                            // id로 지우기 때문에 중첩 ForEach의 인덱스 어긋남 문제가 없다.
                                            // 기록을 지우는 것도 결국 시간을 되돌리는 일이라 똑같이 본인 확인을 받는다.
                                            Button(role: .destructive) {
                                                Task {
                                                    switch await BiometricGate.authenticate(reason: L10n.authReasonDelete) {
                                                    case .success: store.deleteEvent(id: event.id)
                                                    case .cancelled: break
                                                    case .failed: showAuthFailure = true
                                                    }
                                                }
                                            } label: {
                                                Label(L10n.delete, systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        } header: {
                            WeekHeader(
                                title: TimeFormat.weekTitle(week.interval, calendar: calendar, now: now),
                                net: week.netMinutes
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(L10n.history)
        .navigationBarTitleDisplayMode(.inline)
        .authFailureAlert(isPresented: $showAuthFailure)
        .onAppear { now = Date() }
        // 배경에 두었다가 주가 바뀐 뒤 돌아오면 지난 주가 "이번 주"로 남는다.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
        // 화면을 계속 켜 둔 채 주가 바뀌는 경우. 다음 주 시작 순간에 한 번만 깨어난다.
        .task(id: now) {
            let boundary = store.currentWeek(now: now).end
            let delay = boundary.timeIntervalSince(Date())
            guard delay > 0 else {
                now = Date()
                return
            }
            try? await Task.sleep(for: .seconds(delay))
            if !Task.isCancelled { now = Date() }
        }
    }
}

// MARK: - Rows

private struct WeekHeader: View {
    let title: String
    let net: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(TimeFormat.netMinutes(net))
                .monospacedDigit()
        }
    }
}

private struct DayHeaderRow: View {
    let day: DaySection
    let calendar: Calendar

    var body: some View {
        HStack {
            Text(TimeFormat.dayTitle(day.day, calendar: calendar))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(TimeFormat.netMinutes(day.netMinutes))
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.top, 4)
    }
}

private struct HistoryRow: View {
    let event: AdjustmentEvent
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 12) {
            KindBadge(kind: event.kind)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.subheadline)
                Text(TimeFormat.time(event.date, calendar: calendar))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Text(TimeFormat.signedMinutes(event.signedMinutes))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
