import SwiftUI

enum RollCallColorRole: CaseIterable {
    case accent
    case live
    case ready
    case warning
    case destructive
    case disabled
    case neutralSurface
    case neutralStructure
}

extension Color {
    static func rollCall(
        _ role: RollCallColorRole,
        surface: RollCallSurfaceVariant = .standard
    ) -> Color {
        switch (role, surface) {
        case (.accent, .standard):
            return Color(uiColor: .systemOrange)
        case (.accent, .live):
            return Color(uiColor: .systemYellow)
        case (.live, .standard):
            return Color(uiColor: .systemBlue)
        case (.live, .live):
            return Color(uiColor: .systemCyan)
        case (.ready, .standard):
            return Color(uiColor: .systemGreen)
        case (.ready, .live):
            return Color(uiColor: .systemMint)
        case (.warning, .standard), (.warning, .live):
            return Color(uiColor: .systemYellow)
        case (.destructive, .standard), (.destructive, .live):
            return Color(uiColor: .systemRed)
        case (.disabled, .standard):
            return Color(uiColor: .secondaryLabel)
        case (.disabled, .live):
            return Color(uiColor: .tertiaryLabel)
        case (.neutralSurface, .standard):
            return Color(uiColor: .secondarySystemGroupedBackground)
        case (.neutralSurface, .live):
            return Color(uiColor: .secondaryLabel).opacity(0.22)
        case (.neutralStructure, .standard):
            return Color(uiColor: .separator)
        case (.neutralStructure, .live):
            return Color.white.opacity(0.18)
        }
    }
}

#Preview("Roll Call Color Roles") {
    ScrollView {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
            ForEach(RollCallSurfaceVariant.allCases, id: \.self) { surface in
                VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                    Text(surface == .standard ? "Standard Surface" : "Live Surface")
                        .rollCallText(.sectionTitle, surface: surface)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 132), spacing: RollCallSpacingTier.standard.value)],
                        spacing: RollCallSpacingTier.standard.value
                    ) {
                        ForEach(RollCallColorRole.allCases, id: \.self) { role in
                            VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.rollCall(role, surface: surface))
                                    .frame(height: 48)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.rollCall(.neutralStructure, surface: surface), lineWidth: 1)
                                    )

                                Text(role.previewName)
                                    .rollCallText(.chipLabel, surface: surface)
                            }
                            .padding(RollCallSpacingTier.tight.value)
                            .background(Color.rollCall(.neutralSurface, surface: surface))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

private extension RollCallColorRole {
    var previewName: String {
        switch self {
        case .accent: return "Accent"
        case .live: return "Live"
        case .ready: return "Ready"
        case .warning: return "Warning"
        case .destructive: return "Destructive"
        case .disabled: return "Disabled"
        case .neutralSurface: return "Neutral Surface"
        case .neutralStructure: return "Neutral Structure"
        }
    }
}

extension RollCallSurfaceVariant {
    var previewBackground: Color {
        switch self {
        case .standard:
            return Color(uiColor: .systemGroupedBackground)
        case .live:
            return Color(red: 0.05, green: 0.07, blue: 0.10)
        }
    }
}

