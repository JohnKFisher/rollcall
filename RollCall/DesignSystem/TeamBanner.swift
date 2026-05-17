import SwiftUI

enum TeamBannerVariant: CaseIterable {
    case standard
    case liveSide
}

struct TeamBannerSecondaryStatus: Equatable {
    let text: String
    let tone: RollCallSecondaryStatusTone

    init(
        text: String,
        tone: RollCallSecondaryStatusTone = .neutral
    ) {
        self.text = text
        self.tone = tone
    }
}

struct TeamBanner: View {
    let teamName: String?
    let secondaryStatus: TeamBannerSecondaryStatus?
    let accentColor: Color?
    let variant: TeamBannerVariant

    init(
        teamName: String?,
        secondaryStatus: TeamBannerSecondaryStatus? = nil,
        accentColor: Color? = nil,
        variant: TeamBannerVariant = .standard
    ) {
        self.teamName = teamName
        self.secondaryStatus = secondaryStatus
        self.accentColor = accentColor
        self.variant = variant
    }

    var body: some View {
        HStack(spacing: RollCallSpacingTier.tight.value) {
            Text(displayName)
                .rollCallText(.cardTitle, surface: surface)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: RollCallSpacingTier.tight.value)
        }
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .background(background)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(resolvedAccent)
                .frame(width: 4)
                .accessibilityHidden(true)
        }
        .overlay(border)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Team")
        .accessibilityValue(accessibilityStatus)
    }

    private var displayName: String {
        guard let teamName, !teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "No Team Selected"
        }
        return teamName
    }

    private var displayStatus: String {
        if teamName == nil {
            return "Choose or create a team"
        }
        return secondaryStatus?.text ?? (variant == .liveSide ? "Live team context" : "Current team")
    }

    private var accessibilityStatus: String {
        "\(displayName), \(displayStatus)"
    }

    private var surface: RollCallSurfaceVariant {
        variant == .liveSide ? .live : .standard
    }

    private var resolvedAccent: Color {
        accentColor ?? Color.rollCall(.accent, surface: surface)
    }

    private var background: Color {
        switch variant {
        case .standard:
            return Color(uiColor: .secondarySystemGroupedBackground)
        case .liveSide:
            return Color.white.opacity(0.08)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(Color.rollCall(.neutralStructure, surface: surface).opacity(0.55), lineWidth: 1)
    }
}

private extension TeamBannerSecondaryStatus {
    var chipRole: StatusChipRole {
        switch tone {
        case .neutral:
            return .neutral
        case .warning:
            return .warning
        }
    }

    var systemImage: String {
        switch tone {
        case .neutral:
            return "person.3"
        case .warning:
            return "exclamationmark.triangle"
        }
    }
}

#Preview("Roll Call Team Banner") {
    ScrollView {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                Text("Standard")
                    .rollCallText(.sectionTitle)
                TeamBanner(teamName: nil)
                TeamBanner(
                    teamName: "Tigers",
                    secondaryStatus: TeamBannerSecondaryStatus(text: "12 players")
                )
                TeamBanner(
                    teamName: "North Valley Thunderbolts With A Very Long Name",
                    secondaryStatus: TeamBannerSecondaryStatus(text: "Warnings", tone: .warning),
                    accentColor: Color(uiColor: .systemYellow)
                )
            }
            .padding(RollCallInsets.section)
            .background(RollCallSurfaceVariant.standard.previewBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                Text("Live Side")
                    .rollCallText(.sectionTitle, surface: .live)
                TeamBanner(
                    teamName: "Tigers",
                    secondaryStatus: TeamBannerSecondaryStatus(text: "Ready"),
                    accentColor: Color(uiColor: .systemYellow),
                    variant: .liveSide
                )
                TeamBanner(
                    teamName: nil,
                    secondaryStatus: TeamBannerSecondaryStatus(text: "No team selected", tone: .warning),
                    variant: .liveSide
                )
            }
            .padding(RollCallInsets.section)
            .background(RollCallSurfaceVariant.live.previewBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding()
    }
}
