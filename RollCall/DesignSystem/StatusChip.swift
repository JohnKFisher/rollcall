import SwiftUI

enum StatusChipRole: CaseIterable {
    case live
    case ready
    case warning
    case destructive
    case disabled
    case neutral
}

enum StatusChipEmphasis: CaseIterable {
    case subdued
    case standard
    case strong
}

struct StatusChip: View {
    let text: String
    let role: StatusChipRole
    let systemImage: String?
    let emphasis: StatusChipEmphasis

    init(
        text: String,
        role: StatusChipRole,
        systemImage: String? = nil,
        emphasis: StatusChipEmphasis = .standard
    ) {
        self.text = text
        self.role = role
        self.systemImage = systemImage
        self.emphasis = emphasis
    }

    var body: some View {
        Label {
            Text(text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
        .rollCallText(.chipLabel)
        .foregroundStyle(foreground)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .background(background)
        .overlay(border)
        .clipShape(Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        switch emphasis {
        case .subdued:
            return role.baseColor
        case .standard:
            return role == .warning ? Color(uiColor: .label) : role.baseColor
        case .strong:
            return role == .warning ? Color(uiColor: .label) : .white
        }
    }

    private var background: Color {
        switch emphasis {
        case .subdued:
            return role.baseColor.opacity(0.12)
        case .standard:
            return role.baseColor.opacity(role == .warning ? 0.28 : 0.18)
        case .strong:
            return role == .warning ? role.baseColor.opacity(0.92) : role.baseColor
        }
    }

    private var border: some View {
        Capsule(style: .continuous)
            .strokeBorder(role.baseColor.opacity(emphasis == .strong ? 0 : 0.35), lineWidth: 1)
    }

    private var verticalPadding: CGFloat {
        emphasis == .strong ? 7 : 5
    }

    private var horizontalPadding: CGFloat {
        emphasis == .strong ? 11 : 9
    }
}

private extension StatusChipRole {
    var baseColor: Color {
        switch self {
        case .live:
            return Color.rollCall(.live)
        case .ready:
            return Color.rollCall(.ready)
        case .warning:
            return Color.rollCall(.warning)
        case .destructive:
            return Color.rollCall(.destructive)
        case .disabled:
            return Color.rollCall(.disabled)
        case .neutral:
            return Color(uiColor: .secondaryLabel)
        }
    }
}

#Preview("Roll Call Status Chips") {
    ScrollView {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
            ForEach(StatusChipEmphasis.allCases, id: \.self) { emphasis in
                VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                    Text(emphasis.previewName)
                        .rollCallText(.sectionTitle)

                    FlowLayout(spacing: RollCallSpacingTier.tight.value) {
                        StatusChip(text: "Playing", role: .live, systemImage: "waveform", emphasis: emphasis)
                        StatusChip(text: "Ready", role: .ready, systemImage: "checkmark.circle", emphasis: emphasis)
                        StatusChip(text: "Apple Music access needed", role: .warning, systemImage: "exclamationmark.triangle", emphasis: emphasis)
                        StatusChip(text: "Missing file", role: .destructive, systemImage: "xmark.octagon", emphasis: emphasis)
                        StatusChip(text: "Not active today", role: .disabled, systemImage: "pause.circle", emphasis: emphasis)
                        StatusChip(text: "No team selected", role: .neutral, systemImage: "person.3", emphasis: emphasis)
                    }
                }
                .padding(RollCallInsets.section)
                .rollCallCard(.utility)
            }
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

private extension StatusChipEmphasis {
    var previewName: String {
        switch self {
        case .subdued: return "Subdued"
        case .standard: return "Standard"
        case .strong: return "Strong"
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: spacing, alignment: .leading)],
            alignment: .leading,
            spacing: spacing
        ) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

