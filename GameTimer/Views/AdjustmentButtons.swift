import SwiftUI

/// 차감은 꽉 채우고 추가는 테두리만 그린다. 색을 쓰지 않고 형태만으로 둘을 구분하기 위한 규칙이고,
/// 히스토리의 배지도 같은 언어를 따른다.
struct AdjustmentButtonStyle: ButtonStyle {
    let kind: AdjustmentKind
    /// 아이패드처럼 넓은 화면에서는 버튼을 크게 만들어 누르기 쉽게 한다.
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, prominent ? 20 : 14)
            .padding(.vertical, prominent ? 20 : 13)
            .background(background)
            .foregroundStyle(kind == .penalty ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private var cornerRadius: CGFloat { prominent ? 18 : 14 }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch kind {
        case .penalty:
            shape.fill(Color.primary)
        case .benefit:
            shape.strokeBorder(Color.primary.opacity(0.3), lineWidth: 1.5)
        }
    }
}

/// 버튼 안쪽: 항목 이름과 부호 붙은 분.
struct AdjustmentButtonLabel: View {
    let preset: Preset
    let kind: AdjustmentKind
    var prominent = false

    var body: some View {
        VStack(alignment: .leading, spacing: prominent ? 5 : 3) {
            Text(preset.name)
                .font((prominent ? Font.title3 : Font.subheadline).weight(.semibold))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Text(TimeFormat.signedMinutes(kind.sign * preset.minutes))
                .font((prominent ? Font.subheadline : Font.caption).weight(.medium))
                .monospacedDigit()
                .opacity(0.65)
        }
    }
}

/// 히스토리 행 앞에 붙는 작은 배지. 버튼과 같은 채움/테두리 규칙.
struct KindBadge: View {
    let kind: AdjustmentKind

    var body: some View {
        Text(kind == .penalty ? L10n.penaltyColumn : L10n.benefitColumn)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .foregroundStyle(kind == .penalty ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .penalty:
            Capsule().fill(Color.primary)
        case .benefit:
            Capsule().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1.2)
        }
    }
}
