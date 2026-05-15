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
        HStack(spacing: RollCallSpacingTier.standard.value) {
            accentBar

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .rollCallText(.cardTitle, surface: surface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(displayStatus)
                    .rollCallText(.helperText, surface: surface)
                    .lineLimit(1)
            }

            Spacer(minLength: RollCallSpacingTier.tight.value)

            if let secondaryStatus {
                StatusChip(
                    text: secondaryStatus.text,
                    role: secondaryStatus.chipRole,
                    systemImage: secondaryStatus.systemImage,
                    emphasis: .subdued
                )
            }
        }
        .frame(minHeight: 54)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(background)
        .overlay(border)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var accentBar: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(resolvedAccent)
            .frame(width: 5)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
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
        return variant == .liveSide ? "Live team context" : "Current team"
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
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.rollCall(.neutralStructure, surface: surface), lineWidth: 1)
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

