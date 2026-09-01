import SwiftUI

/// 항목 하나를 만들거나 고치는 시트.
struct PresetEditView: View {
    let context: PresetEditorContext
    let onSave: (Preset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Preset
    @FocusState private var nameFocused: Bool

    init(context: PresetEditorContext, onSave: @escaping (Preset) -> Void) {
        self.context = context
        self.onSave = onSave
        _draft = State(initialValue: context.preset)
    }

    var body: some View {
        Form {
            Section(L10n.presetNameLabel) {
                TextField(L10n.presetNamePlaceholder, text: $draft.name)
                    .focused($nameFocused)
                    .submitLabel(.done)
            }

            Section {
                Stepper(value: $draft.minutes, in: 1...600, step: 5) {
                    HStack {
                        Text(TimeFormat.signedMinutes(context.kind.sign * draft.minutes))
                            .font(.title3.weight(.medium))
                            .monospacedDigit()
                        Spacer()
                        Text(TimeFormat.hhmm(draft.minutes))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                // 자주 쓰는 값은 한 번에 고를 수 있게.
                HStack(spacing: 8) {
                    ForEach([10, 15, 30, 60], id: \.self) { minutes in
                        Button("\(minutes)분") { draft.minutes = minutes }
                            .buttonStyle(.bordered)
                            .tint(.primary)
                            .font(.footnote)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 2)
            } header: {
                Text(L10n.presetMinutesLabel)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.save) {
                    onSave(draft)
                    dismiss()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
        .onAppear { nameFocused = context.isNew }
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        switch (context.isNew, context.kind) {
        case (true, .penalty): return L10n.newPenalty
        case (true, .benefit): return L10n.newBenefit
        case (false, .penalty): return L10n.editPenalty
        case (false, .benefit): return L10n.editBenefit
        }
    }
}
