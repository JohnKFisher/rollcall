import SwiftUI

enum RollCallTextRole: CaseIterable {
    case screenTitle
    case sectionTitle
    case cardTitle
    case primaryIdentity
    case body
    case helperText
    case chipLabel
}

struct RollCallTextStyle: ViewModifier {
    let role: RollCallTextRole
    let surface: RollCallSurfaceVariant

    func body(content: Content) -> some View {
        content
            .font(font)
            .fontWeight(weight)
            .foregroundStyle(foregroundStyle)
    }

    private var font: Font {
        switch role {
        case .screenTitle:
            return .largeTitle
        case .sectionTitle:
            return .title3
        case .cardTitle:
            return .headline
        case .primaryIdentity:
            return .title
        case .body:
            return .body
        case .helperText:
            return .footnote
        case .chipLabel:
            return .caption
        }
    }

    private var weight: Font.Weight {
        switch role {
        case .screenTitle, .primaryIdentity:
            return .bold
        case .sectionTitle, .cardTitle, .chipLabel:
            return .semibold
        case .body:
            return .regular
        case .helperText:
            return .medium
        }
    }

    private var foregroundStyle: Color {
        switch (role, surface) {
        case (.helperText, .standard):
            return Color(uiColor: .secondaryLabel)
        case (.helperText, .live):
            return Color(uiColor: .secondaryLabel)
        case (_, .standard):
            return Color(uiColor: .label)
        case (_, .live):
            return Color(uiColor: .label)
        }
    }
}

extension View {
    func rollCallText(
        _ role: RollCallTextRole,
        surface: RollCallSurfaceVariant = .standard
    ) -> some View {
        modifier(RollCallTextStyle(role: role, surface: surface))
    }
}

#Preview("Roll Call Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
            ForEach(RollCallSurfaceVariant.allCases, id: \.self) { surface in
                VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                    ForEach(RollCallTextRole.allCases, id: \.self) { role in
                        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                            Text(role.previewName)
                                .rollCallText(role, surface: surface)
                            Text("Longer sample text to check wrapping, hierarchy, and Dynamic Type behavior.")
                                .rollCallText(.helperText, surface: surface)
                        }
                    }
                }
                .padding(RollCallInsets.section)
                .background(surface.previewBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding()
    }
}

private extension RollCallTextRole {
    var previewName: String {
        switch self {
        case .screenTitle: return "Screen Title"
        case .sectionTitle: return "Section Title"
        case .cardTitle: return "Card Title"
        case .primaryIdentity: return "Primary Identity"
        case .body: return "Body"
        case .helperText: return "Helper Text"
        case .chipLabel: return "Chip Label"
        }
    }
}
