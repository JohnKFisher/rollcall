import SwiftUI

enum RollCallCardFamily: CaseIterable {
    case utility
    case status
    case identity
    case live
}

struct RollCallCardModifier: ViewModifier {
    let family: RollCallCardFamily
    let surface: RollCallSurfaceVariant

    func body(content: Content) -> some View {
        content
            .padding(RollCallInsets.card)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private var background: some ShapeStyle {
        switch (family, surface) {
        case (.live, _):
            return Color.rollCall(.neutralSurface, surface: .live)
        case (.status, .standard):
            return Color.rollCall(.neutralSurface)
        case (.identity, .standard):
            return Color(uiColor: .systemBackground)
        case (.utility, .standard):
            return Color(uiColor: .secondarySystemGroupedBackground)
        case (_, .live):
            return Color.rollCall(.neutralSurface, surface: .live)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        switch family {
        case .utility:
            return Color.rollCall(.neutralStructure, surface: surface).opacity(0.65)
        case .status:
            return Color.rollCall(.warning, surface: surface).opacity(0.35)
        case .identity:
            return Color.rollCall(.accent, surface: surface).opacity(0.28)
        case .live:
            return Color.rollCall(.live, surface: .live).opacity(0.44)
        }
    }

    private var borderWidth: CGFloat {
        family == .utility ? 1 : 1.5
    }

    private var cornerRadius: CGFloat {
        family == .live ? 14 : 12
    }

    private var shadowColor: Color {
        surface == .live ? .clear : .black.opacity(0.06)
    }

    private var shadowRadius: CGFloat {
        surface == .live ? 0 : 6
    }

    private var shadowY: CGFloat {
        surface == .live ? 0 : 2
    }
}

extension View {
    func rollCallCard(
        _ family: RollCallCardFamily = .utility,
        surface: RollCallSurfaceVariant = .standard
    ) -> some View {
        modifier(RollCallCardModifier(family: family, surface: surface))
    }
}

struct SectionCard<Content: View>: View {
    let family: RollCallCardFamily
    let surface: RollCallSurfaceVariant
    let content: Content

    init(
        family: RollCallCardFamily = .utility,
        surface: RollCallSurfaceVariant = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.family = family
        self.surface = surface
        self.content = content()
    }

    var body: some View {
        content
            .rollCallCard(family, surface: surface)
    }
}

#Preview("Roll Call Card Families") {
    ScrollView {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
            ForEach(RollCallSurfaceVariant.allCases, id: \.self) { surface in
                VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                    Text(surface == .standard ? "Standard Cards" : "Live Cards")
                        .rollCallText(.sectionTitle, surface: surface)

                    ForEach(RollCallCardFamily.allCases, id: \.self) { family in
                        SectionCard(family: family, surface: surface) {
                            VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                                Text(family.previewName)
                                    .rollCallText(.cardTitle, surface: surface)
                                Text("Sample card content with enough text to check padding, contrast, and wrapping.")
                                    .rollCallText(.helperText, surface: surface)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
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

private extension RollCallCardFamily {
    var previewName: String {
        switch self {
        case .utility: return "Utility Card"
        case .status: return "Status Card"
        case .identity: return "Identity Card"
        case .live: return "Live Card"
        }
    }
}
