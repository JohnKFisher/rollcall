import SwiftUI

enum RollCallButtonFamily: CaseIterable {
    case primary
    case secondary
    case quiet
    case destructive
    case liveControl
}

struct RollCallButtonStyle: ButtonStyle {
    let family: RollCallButtonFamily
    let surface: RollCallSurfaceVariant
    let teamAccentTheme: TeamAccentTheme

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    init(
        family: RollCallButtonFamily,
        surface: RollCallSurfaceVariant,
        teamAccentTheme: TeamAccentTheme = .rollCallDefault
    ) {
        self.family = family
        self.surface = surface
        self.teamAccentTheme = teamAccentTheme
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rollCallText(.body, surface: surface)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: minHeight)
            .frame(maxWidth: family == .liveControl ? .infinity : nil)
            .background(background(isPressed: configuration.isPressed))
            .foregroundStyle(foreground)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var verticalPadding: CGFloat {
        family == .quiet ? 6 : 10
    }

    private var horizontalPadding: CGFloat {
        family == .liveControl ? 16 : 14
    }

    private var minHeight: CGFloat {
        family == .liveControl ? 52 : 40
    }

    private var cornerRadius: CGFloat {
        family == .liveControl ? 12 : 10
    }

    private func background(isPressed: Bool) -> Color {
        let base: Color
        switch family {
        case .primary:
            base = teamAccentTheme.color(.fill, surface: surface)
        case .secondary:
            base = Color.rollCall(.neutralSurface, surface: surface)
        case .quiet:
            base = .clear
        case .destructive:
            base = Color.rollCall(.destructive, surface: surface)
        case .liveControl:
            base = Color.rollCall(.live, surface: .live)
        }
        return isPressed ? base.opacity(0.78) : base
    }

    private var foreground: Color {
        switch family {
        case .destructive, .liveControl:
            return .white
        case .primary:
            return teamAccentTheme.color(.onFill, surface: surface)
        case .secondary, .quiet:
            return Color(uiColor: .label)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        switch family {
        case .primary, .destructive, .liveControl:
            return .clear
        case .secondary:
            if surface == .live {
                return teamAccentTheme
                    .color(colorScheme == .dark ? .subtle : .primary, surface: surface)
                    .opacity(colorScheme == .dark ? 0.38 : 1)
            }
            return Color.rollCall(.neutralStructure, surface: surface)
        case .quiet:
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        family == .secondary ? 1 : 0
    }
}

private struct RollCallButtonStyleModifier: ViewModifier {
    let family: RollCallButtonFamily
    let surface: RollCallSurfaceVariant

    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    func body(content: Content) -> some View {
        content.buttonStyle(RollCallButtonStyle(
            family: family,
            surface: surface,
            teamAccentTheme: teamAccentTheme
        ))
    }
}

extension Button {
    func rollCallButtonStyle(
        _ family: RollCallButtonFamily,
        surface: RollCallSurfaceVariant = .standard
    ) -> some View {
        modifier(RollCallButtonStyleModifier(family: family, surface: surface))
    }
}

#Preview("Roll Call Button Families") {
    ScrollView {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
            ForEach(RollCallSurfaceVariant.allCases, id: \.self) { surface in
                VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                    Text(surface == .standard ? "Standard Buttons" : "Live Buttons")
                        .rollCallText(.sectionTitle, surface: surface)

                    ForEach(RollCallButtonFamily.allCases, id: \.self) { family in
                        HStack {
                            Button {
                            } label: {
                                Label(family.previewName, systemImage: family.previewImage)
                            }
                            .rollCallButtonStyle(family, surface: surface)

                            Button {
                            } label: {
                                Label("Disabled", systemImage: family.previewImage)
                            }
                            .rollCallButtonStyle(family, surface: surface)
                            .disabled(true)
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

private extension RollCallButtonFamily {
    var previewName: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .quiet: return "Quiet"
        case .destructive: return "Destructive"
        case .liveControl: return "Live Control"
        }
    }

    var previewImage: String {
        switch self {
        case .primary: return "plus"
        case .secondary: return "slider.horizontal.3"
        case .quiet: return "ellipsis"
        case .destructive: return "trash"
        case .liveControl: return "play.fill"
        }
    }
}
