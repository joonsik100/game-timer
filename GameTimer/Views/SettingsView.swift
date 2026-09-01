import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var editor: PresetEditorContext?
    @FocusState private var baseFieldFocused: Bool

    var body: some View {
        Form {
            weeklyBaseSection
            weekStartSection
            presetSection(for: .penalty)
            presetSection(for: .benefit)
        }
        .navigationTitle(L10n.settings)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.done) { baseFieldFocused = false }
            }
        }
        .sheet(item: $editor) { context in
            NavigationStack {
                PresetEditView(context: context) { saved in
                    if context.isNew {
                        store.addPreset(saved, kind: context.kind)
                    } else {
                        store.updatePreset(saved, kind: context.kind)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var weeklyBaseSection: some View {
        Section {
            HStack {
                TextField(L10n.minuteUnit, value: baseMinutes, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($baseFieldFocused)
                Text(L10n.minuteUnit)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(TimeFormat.hhmm(store.settings.weeklyBaseMinutes))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper("", value: baseMinutes, in: 0...AppSettings.maxWeeklyBaseMinutes, step: 30)
                    .labelsHidden()
            }
        } header: {
            Text(L10n.weeklyBaseSection)
        } footer: {
            Text(L10n.weeklyBaseFooter)
        }
    }

    private var weekStartSection: some View {
        Section {
            Picker(L10n.weekStartSection, selection: weekStart) {
                Text(L10n.monday).tag(WeekStart.monday)
                Text(L10n.sunday).tag(WeekStart.sunday)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } header: {
            Text(L10n.weekStartSection)
        } footer: {
            Text(L10n.weekStartFooter)
        }
    }

    private func presetSection(for kind: AdjustmentKind) -> some View {
        let presets = store.presets(for: kind)
        return Section {
            if presets.isEmpty {
                Text(L10n.emptyPresets)
                    .foregroundStyle(.tertiary)
            }
            ForEach(presets) { preset in
                Button {
                    editor = PresetEditorContext(kind: kind, preset: preset, isNew: false)
                } label: {
                    PresetRow(preset: preset, kind: kind)
                }
                .buttonStyle(.plain)
            }
            .onDelete { store.deletePresets(at: $0, kind: kind) }
            .onMove { store.movePresets(from: $0, to: $1, kind: kind) }

            Button {
                editor = PresetEditorContext(
                    kind: kind,
                    preset: Preset(name: "", minutes: kind == .penalty ? 30 : 15),
                    isNew: true
                )
            } label: {
                Label(kind == .penalty ? L10n.addPenalty : L10n.addBenefit, systemImage: "plus.circle")
            }
        } header: {
            Text(kind == .penalty ? L10n.penaltySection : L10n.benefitSection)
        }
    }

    // MARK: - Bindings
    //
    // 스토어는 모든 변경을 메서드로만 받으므로(저장 시점을 한곳에 모으기 위해) 바인딩을 직접 만든다.

    private var baseMinutes: Binding<Int> {
        Binding(
            get: { store.settings.weeklyBaseMinutes },
            set: { store.setWeeklyBaseMinutes($0) }
        )
    }

    private var weekStart: Binding<WeekStart> {
        Binding(
            get: { store.settings.weekStart },
            set: { store.setWeekStart($0) }
        )
    }
}

// MARK: - Preset row

private struct PresetRow: View {
    let preset: Preset
    let kind: AdjustmentKind

    var body: some View {
        HStack {
            Text(preset.name)
            Spacer()
            Text(TimeFormat.signedMinutes(kind.sign * preset.minutes))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Editor context

/// 시트로 띄울 편집 대상. 새 항목이면 아직 목록에 없는 프리셋을 들고 있는다.
struct PresetEditorContext: Identifiable {
    var id: UUID { preset.id }
    let kind: AdjustmentKind
    let preset: Preset
    let isNew: Bool
}
