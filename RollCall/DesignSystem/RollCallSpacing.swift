import SwiftUI

enum RollCallSpacingTier: CGFloat, CaseIterable {
    case tight = 8
    case standard = 12
    case large = 20

    var value: CGFloat {
        rawValue
    }
}

enum RollCallInsets {
    static let card = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    static let section = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
}

#Preview("Roll Call Spacing") {
    VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
        Text("Spacing Tiers")
            .rollCallText(.screenTitle)

        ForEach(RollCallSpacingTier.allCases, id: \.self) { tier in
            VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                Text(tier.previewName)
                    .rollCallText(.cardTitle)

                HStack(spacing: tier.value) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.rollCall(.accent))
                            .frame(width: 36, height: 36)
                    }
                }
            }
            .padding(RollCallInsets.card)
            .rollCallCard(.utility)
        }
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}

private extension RollCallSpacingTier {
    var previewName: String {
        switch self {
        case .tight: return "Tight: 8"
        case .standard: return "Standard: 12"
        case .large: return "Large: 20"
        }
    }
}

