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

enum TeamAccentThemeTone {
    case primary
    case fill
    case subtle
    case onFill
}

struct TeamAccentTheme: Equatable {
    let preset: TeamAccentPreset

    static let rollCallDefault = TeamAccentTheme(preset: .rollCallOrange)

    func uiColor(
        _ tone: TeamAccentThemeTone = .primary,
        surface: RollCallSurfaceVariant = .standard
    ) -> UIColor {
        if tone == .onFill {
            return UIColor { traits in
                let fillColor = self.uiColor(.fill, surface: surface).resolvedColor(with: traits)
                return UIColor.rollCallReadableForeground(over: fillColor)
            }
        }

        let resolvedColor: UIColor

        switch (preset, tone) {
        case (.rollCallOrange, .primary), (.rollCallOrange, .fill), (.rollCallOrange, .subtle):
            resolvedColor = .systemOrange

        case (.red, .primary), (.red, .fill), (.red, .subtle):
            resolvedColor = .systemRed

        case (.gold, .primary):
            resolvedColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? .systemYellow
                    : UIColor(red: 0.58, green: 0.38, blue: 0.00, alpha: 1.00)
            }
        case (.gold, .fill), (.gold, .subtle):
            resolvedColor = .systemYellow

        case (.green, .primary), (.green, .fill), (.green, .subtle):
            resolvedColor = .systemGreen

        case (.blue, .primary), (.blue, .fill), (.blue, .subtle):
            resolvedColor = .systemBlue

        case (.purple, .primary), (.purple, .fill), (.purple, .subtle):
            resolvedColor = .systemPurple

        case (.gray, .primary), (.gray, .subtle):
            resolvedColor = UIColor { traits in
                traits.userInterfaceStyle == .dark ? .systemGray2 : .systemGray
            }
        case (.gray, .fill):
            resolvedColor = UIColor { traits in
                traits.userInterfaceStyle == .dark ? .systemGray3 : .systemGray
            }

        case (.black, .primary), (.black, .fill):
            resolvedColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? .systemGray2
                    : UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.00)
            }
        case (.black, .subtle):
            resolvedColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? .systemGray3
                    : UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.00)
            }
        case (_, .onFill):
            preconditionFailure("onFill is resolved before accent fill colors are switched.")
        }

        return resolvedColor
    }

    func color(
        _ tone: TeamAccentThemeTone = .primary,
        surface: RollCallSurfaceVariant = .standard
    ) -> Color {
        let color = Color(uiColor: uiColor(tone, surface: surface))
        return color
    }
}

private extension UIColor {
    static func rollCallReadableForeground(over background: UIColor) -> UIColor {
        contrastRatio(between: .black, and: background) >= contrastRatio(between: .white, and: background)
            ? .black
            : .white
    }

    static func contrastRatio(between foreground: UIColor, and background: UIColor) -> CGFloat {
        let foregroundLuminance = foreground.rollCallRelativeLuminance
        let backgroundLuminance = background.rollCallRelativeLuminance
        return (max(foregroundLuminance, backgroundLuminance) + 0.05) / (min(foregroundLuminance, backgroundLuminance) + 0.05)
    }

    var rollCallRelativeLuminance: CGFloat {
        let components = rollCallSRGBComponents
        return 0.2126 * UIColor.rollCallLinearComponent(components.red)
            + 0.7152 * UIColor.rollCallLinearComponent(components.green)
            + 0.0722 * UIColor.rollCallLinearComponent(components.blue)
    }

    var rollCallSRGBComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (0, 0, 0)
        }

        return (red, green, blue)
    }

    static func rollCallLinearComponent(_ value: CGFloat) -> CGFloat {
        value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}

private struct TeamAccentThemeKey: EnvironmentKey {
    static let defaultValue = TeamAccentTheme.rollCallDefault
}

extension EnvironmentValues {
    var rollCallTeamAccentTheme: TeamAccentTheme {
        get { self[TeamAccentThemeKey.self] }
        set { self[TeamAccentThemeKey.self] = newValue }
    }
}

extension View {
    func rollCallTeamAccentTheme(_ theme: TeamAccentTheme) -> some View {
        environment(\.rollCallTeamAccentTheme, theme)
    }
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
            return Color(uiColor: .systemOrange)
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
            return Color(uiColor: .secondarySystemGroupedBackground)
        case (.neutralStructure, .standard):
            return Color(uiColor: .separator)
        case (.neutralStructure, .live):
            return Color(uiColor: .separator)
        }
    }
}

extension TeamAccentPreset {
    var title: String {
        switch self {
        case .rollCallOrange: return "Orange"
        case .red: return "Red"
        case .gold: return "Gold"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .gray: return "Gray"
        case .black: return "Black"
        }
    }

    var theme: TeamAccentTheme {
        TeamAccentTheme(preset: self)
    }

    func color(
        _ tone: TeamAccentThemeTone = .primary,
        surface: RollCallSurfaceVariant = .standard
    ) -> Color {
        theme.color(tone, surface: surface)
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
            return Color(uiColor: .systemGroupedBackground)
        }
    }
}
