import Foundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum RootTab: Hashable {
    case players
    case generalClips
    case gameDay
    case readiness
    case teams
    case settings
}

struct RootView: View {
    @ObservedObject var appModel: AppModel
    @State private var newTeamName = ""
    @State private var selectedPlayer: Player?
    @State private var showExperimentalWarning = false
    @State private var packageImportPresented = false
    @State private var csvImportPresented = false
    @State private var selectedTab: RootTab = .players
    @State private var showLineupEditor = false
    @State private var showRenameTeamAlert = false
    @State private var showRemoveTeamConfirmation = false
    @State private var renameTeamName = ""
    @State private var packageSharePresented = false

    private var errorBinding: Binding<Bool> {
        Binding(get: { appModel.lastError != nil }, set: { newValue in if !newValue { appModel.lastError = nil } })
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            playersTab
                .tag(RootTab.players)
                .tabItem { Label("Players", systemImage: "person.3.fill") }

            generalClipsTab
                .tag(RootTab.generalClips)
                .tabItem { Label("Clips", systemImage: "music.note.list") }

            gameDayTab
                .tag(RootTab.gameDay)
                .tabItem { Label("Game Day", systemImage: "play.rectangle.fill") }

            readinessTab
                .tag(RootTab.readiness)
                .tabItem { Label("Readiness", systemImage: "checklist") }

            teamsTab
                .tag(RootTab.teams)
                .tabItem { Label("Teams", systemImage: "list.number") }

            settingsTab
                .tag(RootTab.settings)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.orange)
        .task {
            await appModel.finishLaunchingIfNeeded()
        }
        .onOpenURL { url in
            appModel.handleIncomingPackage(url)
        }
        .overlay(alignment: .top) {
            if appModel.isBusy {
                ProgressView("Working…")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
        .alert("Experimental Apple Music Local Copies", isPresented: $showExperimentalWarning) {
            Button("Enable") { appModel.enableExperimentalCopies() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This feature is off by default. It attempts to turn Apple Music preview media into a regular local file. It may fail, and it is intentionally separate from the normal Apple Music path.")
        }
        .alert("Roll Call", isPresented: errorBinding) {
            Button("OK") { appModel.lastError = nil }
        } message: {
            Text(appModel.lastError ?? "")
        }
        .alert("Rename Team", isPresented: $showRenameTeamAlert) {
            TextField("Team name", text: $renameTeamName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                appModel.renameSelectedTeam(to: renameTeamName)
            }
            .disabled(renameTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Update the selected team name.")
        }
        .alert("Remove Team?", isPresented: $showRemoveTeamConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                appModel.removeSelectedTeam()
            }
        } message: {
            if let team = appModel.selectedTeam {
                Text("Remove \(team.name) from this device? This deletes that team's \(team.players.count) players, lineup state, clips, and custom intros from the app. Existing exports and backups stay untouched.")
            } else {
                Text("Remove the selected team from this device. Existing exports and backups stay untouched.")
            }
        }
        .sheet(item: Binding(get: { appModel.pendingRosterImport }, set: { appModel.pendingRosterImport = $0 })) { pending in
            NavigationStack {
                List {
                    Section("Importing \(pending.rows.count) players from \(pending.sourceName)") {
                        ForEach(pending.rows) { player in
                            HStack {
                                Text(player.displayName)
                                Spacer()
                                if !player.uniformNumber.isEmpty {
                                    Text("#\(player.uniformNumber)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Roster Preview")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { appModel.discardPendingRosterImport() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Import") { appModel.applyPendingRosterImport() }
                    }
                }
            }
        }
        .sheet(isPresented: $packageImportPresented) {
            RollCallPackageImportSheet(
                onPick: { url in
                    packageImportPresented = false
                    Task { await appModel.importPackage(from: url) }
                },
                onCancel: {
                    packageImportPresented = false
                }
            )
        }
        .fileImporter(isPresented: $csvImportPresented, allowedContentTypes: [.commaSeparatedText, .text], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await appModel.prepareRosterImport(from: url) }
            }
        }
    }

    private var playersTab: some View {
        NavigationStack {
            List {
                Section {
                    TeamBanner(
                        teamName: appModel.selectedTeam?.name,
                        secondaryStatus: selectedTeamBannerStatus
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                if let team = appModel.selectedTeam {
                    Section {
                        PlayerQuickAddView(appModel: appModel)
                    } header: {
                        PlayersSectionHeader(
                            title: "Add Player",
                            helperText: "Fast roster entry stays here; detailed cue and photo setup opens from each player row."
                        )
                    }

                    Section {
                        ForEach(playersTabRoster(for: team)) { player in
                            let cue = player.cue
                            let hasCustomIntro = appModel.hasStoredCustomAnnouncer(for: player)
                            let isCustomIntroMissing = player.customAnnouncerRelativePath != nil && !hasCustomIntro
                            let isPresent = player.isPresent
                            Button {
                                selectedPlayer = player
                            } label: {
                                PlayerRosterRow(
                                    player: player,
                                    cue: cue,
                                    isPresent: isPresent,
                                    hasCustomIntro: hasCustomIntro,
                                    isCustomIntroMissing: isCustomIntroMissing
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(isPresent ? "Mark Out" : "Mark In") { appModel.togglePresent(player) }
                                    .tint(isPresent ? .red : .green)
                            }
                        }
                    } header: {
                        PlayersSectionHeader(
                            title: "Roster",
                            helperText: "\(team.players.count) players sorted by name. Players marked out are hidden from Game Day."
                        )
                    }
                } else {
                    ContentUnavailableView("No Team Selected", systemImage: "person.3.sequence.fill", description: Text("Create or select a team on the Teams tab."))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Players")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
            .sheet(item: $selectedPlayer) { player in
                PlayerEditorSheet(appModel: appModel, player: player)
            }
        }
    }

    private var playersTabTitle: String {
        if let teamName = appModel.selectedTeam?.name, !teamName.isEmpty {
            return "Players - \(teamName)"
        }
        return "Players"
    }

    private func playersTabRoster(for team: Team) -> [Player] {
        team.players.sorted { lhs, rhs in
            let lhsName = playerSortNameParts(lhs)
            let rhsName = playerSortNameParts(rhs)
            if lhsName.first != rhsName.first {
                return lhsName.first.localizedCaseInsensitiveCompare(rhsName.first) == .orderedAscending
            }
            if lhsName.remainder != rhsName.remainder {
                return lhsName.remainder.localizedCaseInsensitiveCompare(rhsName.remainder) == .orderedAscending
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func playerSortNameParts(_ player: Player) -> (first: String, remainder: String) {
        let trimmedName = player.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let splitIndex = trimmedName.firstIndex(where: \.isWhitespace) else {
            return (trimmedName, "")
        }

        let firstName = String(trimmedName[..<splitIndex])
        let remainder = trimmedName[splitIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (firstName, remainder)
    }

    private var generalClipsTab: some View {
        NavigationStack {
            List {
                Section {
                    TeamBanner(
                        teamName: appModel.selectedTeam?.name,
                        secondaryStatus: selectedTeamBannerStatus
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                if appModel.selectedTeamBuiltInClips.isEmpty {
                    ContentUnavailableView("No Clips Ready", systemImage: "speaker.wave.2", description: Text("Select a team to use the built-in crowd clip library."))
                } else {
                    Section("Built-In Crowd Clips") {
                        ForEach(appModel.selectedTeamBuiltInClips) { clip in
                            Button {
                                Task { await appModel.play(builtInClip: clip) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(clip.title)
                                            .font(.headline)
                                        Text("Built-in hype audio for quick game-day reactions.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("General Clips")
        }
    }

    private var gameDayTab: some View {
        NavigationStack {
            ZStack {
                GameDayBackground()
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    if let team = appModel.selectedTeam {
                        GameDayHeader(appModel: appModel, teamName: team.name)

                        Label("Before first pitch, enable an iPhone Focus to reduce calls, texts, and notification interruptions.", systemImage: "moon.zzz.fill")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Picker("Intro Mode", selection: Binding(
                            get: { team.session.gameDayAnnouncerMode },
                            set: { appModel.setGameDayAnnouncerMode($0) }
                        )) {
                            Text("Cue Only").tag(GameDayAnnouncerMode.noAnnouncer)
                            Text("Announcement Cues").tag(GameDayAnnouncerMode.announcer)
                        }
                        .pickerStyle(.segmented)

                        GameDayPlayerGrid(appModel: appModel)

                        HStack {
                            Button("Advance Next Batter") { appModel.advanceNextBatter() }
                                .buttonStyle(.bordered)
                            Spacer()
                            if let nextBatter = team.nextBatter {
                                Text("Next: \(nextBatter.displayName)")
                            } else {
                                Text("No present players in the lineup")
                            }
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView("No Team Ready", systemImage: "music.note")
                    }
                }
                .padding()
            }
            .navigationTitle("Game Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if appModel.selectedTeam != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Lineup") { showLineupEditor = true }
                    }
                }
            }
            .sheet(isPresented: $showLineupEditor) {
                LineupEditorSheet(appModel: appModel)
            }
        }
    }

    private var readinessTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    TeamBanner(
                        teamName: appModel.selectedTeam?.name,
                        secondaryStatus: selectedTeamBannerStatus
                    )

                    if let readiness = appModel.state.lastReadiness {
                        ReadinessOverviewCard(readiness: readiness) {
                            appModel.refreshReadiness()
                        }

                        ForEach(readinessIssueFamilies(for: readiness.checks)) { family in
                            ReadinessIssueFamilyCard(family: family)
                        }
                    } else {
                        ReadinessEmptyCard {
                            appModel.refreshReadiness()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, RollCallSpacingTier.tight.value)
                .padding(.bottom, RollCallSpacingTier.large.value)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Readiness")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var teamsTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    TeamBanner(
                        teamName: appModel.selectedTeam?.name,
                        secondaryStatus: selectedTeamBannerStatus
                    )

                    if let team = appModel.selectedTeam {
                        TeamsSectionGroup(
                            title: "Selected Team",
                            helperText: "Lifecycle tools stay here so they do not interrupt normal team selection."
                        ) {
                            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                                SelectedTeamSummary(team: team)

                                Menu {
                                    Button("Rename Selected Team") {
                                        renameTeamName = appModel.selectedTeam?.name ?? ""
                                        showRenameTeamAlert = true
                                    }
                                    Button("Duplicate Selected Team") { appModel.duplicateTeam() }
                                    Button("Import Roster CSV") { csvImportPresented = true }
                                    Button("Remove Selected Team", role: .destructive) {
                                        showRemoveTeamConfirmation = true
                                    }
                                } label: {
                                    Label("Team Actions", systemImage: "ellipsis.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RollCallButtonStyle(family: .secondary, surface: .standard))
                            }
                        }
                    }

                    TeamsSectionGroup(
                        title: "Create Team",
                        helperText: "Add a roster container, then choose it below."
                    ) {
                        VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                            TextField("Team name", text: $newTeamName)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                appModel.addTeam(named: newTeamName)
                                newTeamName = ""
                            } label: {
                                Label("Create Team", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .rollCallButtonStyle(.primary)
                            .disabled(newTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    TeamsSectionGroup(
                        title: "Teams",
                        helperText: "Choose the roster Roll Call should use for setup and game day."
                    ) {
                        if appModel.state.teams.isEmpty {
                            TeamsEmptyState()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(appModel.state.teams.enumerated()), id: \.element.id) { index, team in
                                    if index > 0 {
                                        Divider()
                                            .padding(.leading, 46)
                                    }

                                    Button {
                                        appModel.selectTeam(team)
                                    } label: {
                                        TeamSelectionRow(
                                            team: team,
                                            isSelected: appModel.state.selectedTeamID == team.id
                                        )
                                        .padding(.vertical, RollCallSpacingTier.tight.value)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, RollCallSpacingTier.tight.value)
                .padding(.bottom, RollCallSpacingTier.large.value)
                .padding(.bottom, 72)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Teams")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
        }
    }

    private var selectedTeamBannerStatus: TeamBannerSecondaryStatus? {
        guard let team = appModel.selectedTeam else {
            return TeamBannerSecondaryStatus(text: "Choose or create a team")
        }
        return TeamBannerSecondaryStatus(
            text: "\(team.players.count) players • \(team.presentPlayersInBattingOrder.count) present"
        )
    }

    private var settingsTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    SettingsSectionGroup(
                        title: "Team Package",
                        helperText: "Share the selected team or bring in a .rollcall package from another device."
                    ) {
                        VStack(spacing: RollCallSpacingTier.standard.value) {
                            Button {
                                Task { await appModel.exportSelectedTeam() }
                            } label: {
                                SettingsRowLabel(
                                    title: "Export Selected Team",
                                    detail: "Create the latest portable team package.",
                                    systemImage: "shippingbox.fill"
                                )
                            }
                            .rollCallButtonStyle(.primary)
                            .disabled(appModel.selectedTeam == nil)

                            if appModel.exportURL != nil {
                                Button {
                                    packageSharePresented = true
                                } label: {
                                    SettingsRowLabel(
                                        title: "Share Latest .rollcall Package",
                                        detail: "Open the system share sheet for the most recent export.",
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                                .rollCallButtonStyle(.secondary)
                            }

                            Button {
                                packageImportPresented = true
                            } label: {
                                SettingsRowLabel(
                                    title: "Import .rollcall Package",
                                    detail: "Import a shared team package.",
                                    systemImage: "tray.and.arrow.down.fill"
                                )
                            }
                            .rollCallButtonStyle(.secondary)
                        }
                    }

                    SettingsSectionGroup(
                        title: "Game Day",
                        helperText: "Keep live-use preferences simple and predictable."
                    ) {
                        Toggle(isOn: Binding(
                            get: { appModel.state.settings.hapticsEnabled },
                            set: { appModel.setHapticsEnabled($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Game Day Haptics",
                                detail: "Use subtle feedback for live controls.",
                                systemImage: "iphone.radiowaves.left.and.right"
                            )
                        }

                        Toggle(isOn: Binding(
                            get: { appModel.state.settings.fadeOutVolumeAutomationEnabled },
                            set: { appModel.setFadeOutVolumeAutomationEnabled($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Fade-Out Volume Automation",
                                detail: "Lower cue volume during fade-out instead of hard-stopping at the end.",
                                systemImage: "speaker.wave.2.fill"
                            )
                        }
                    }

                    SettingsSectionGroup(
                        title: "Recovery",
                        helperText: "Backup and restore tools stay separate from everyday setup."
                    ) {
                        NavigationLink {
                            RecoveryCenterView(appModel: appModel)
                        } label: {
                            SettingsNavigationLabel(
                                title: "Recovery & Backups",
                                detail: "Create or restore local recovery points.",
                                systemImage: "arrow.counterclockwise.circle.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSectionGroup(title: "About") {
                        VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                            HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
                                SettingsIcon(systemImage: "baseball.fill", role: .accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Roll Call")
                                        .rollCallText(.cardTitle)
                                    Text("Game day cues for local teams.")
                                        .rollCallText(.helperText)
                                }
                                Spacer()
                                StatusChip(
                                    text: "v\(AppMetadata.appVersion) (\(AppMetadata.buildNumber))",
                                    role: .neutral,
                                    emphasis: .subdued
                                )
                            }

                            Divider()

                            Text("Copyright John Kenneth Fisher")
                                .rollCallText(.helperText)

                            Link(destination: URL(string: "https://github.com/JohnKFisher/roll-call")!) {
                                SettingsRowLabel(
                                    title: "GitHub: JohnKFisher/roll-call",
                                    detail: "Open the public project page.",
                                    systemImage: "link"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SettingsSectionGroup(
                        title: "Advanced / Developer Tools",
                        helperText: "Experimental and diagnostic features stay out of normal user flows."
                    ) {
                        NavigationLink {
                            DeveloperToolsView(appModel: appModel, showExperimentalWarning: $showExperimentalWarning)
                        } label: {
                            SettingsNavigationLabel(
                                title: "Developer Tools",
                                detail: "Open experimental settings and support utilities.",
                                systemImage: "wrench.and.screwdriver.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, RollCallSpacingTier.tight.value)
                .padding(.bottom, RollCallSpacingTier.large.value)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $packageSharePresented) {
                if let exportURL = appModel.exportURL {
                    ActivityShareSheet(items: [exportURL])
                }
            }
        }
    }

    private func iconName(for state: ReadinessState) -> String {
        switch state {
        case .ready: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private func color(for state: ReadinessState) -> Color {
        switch state {
        case .ready: return .green
        case .warning: return .orange
        case .failed: return .red
        case .unknown: return .secondary
        }
    }

    private func readinessIssueFamilies(for checks: [ReadinessCheck]) -> [ReadinessIssueFamily] {
        let order = [
            "audio",
            "apple-music",
            "team",
            "player-cues",
            "announcement-cues",
            "photos",
            "other"
        ]
        let grouped = Dictionary(grouping: checks, by: readinessFamilyID(for:))

        return order.compactMap { id in
            guard let checks = grouped[id], !checks.isEmpty else { return nil }
            return ReadinessIssueFamily(
                id: id,
                title: readinessFamilyTitle(for: id),
                helperText: readinessFamilyHelperText(for: id),
                checks: checks
            )
        }
    }

    private func readinessFamilyID(for check: ReadinessCheck) -> String {
        if check.id == "route" || check.id == "volume" {
            return "audio"
        }
        if check.id == "network" || check.id == "music-auth" {
            return "apple-music"
        }
        if check.id == "lineup" {
            return "team"
        }
        if check.id.contains("custom-announcer") {
            return "announcement-cues"
        }
        if check.id.contains("photo") {
            return "photos"
        }
        if check.id.hasPrefix("player-") {
            return "player-cues"
        }
        return "other"
    }

    private func readinessFamilyTitle(for id: String) -> String {
        switch id {
        case "audio": return "Audio Output"
        case "apple-music": return "Apple Music Access"
        case "team": return "Team & Present Players"
        case "player-cues": return "Player Cues"
        case "announcement-cues": return "Announcement Cues"
        case "photos": return "Player Photos"
        default: return "Other Checks"
        }
    }

    private func readinessFamilyHelperText(for id: String) -> String {
        switch id {
        case "audio":
            return "Route and volume checks for game-day playback."
        case "apple-music":
            return "Network and authorization checks for Apple Music cues."
        case "team":
            return "Selected team and present-player coverage."
        case "player-cues":
            return "Cue coverage for players marked present."
        case "announcement-cues":
            return "Custom announcement files used before player cues."
        case "photos":
            return "Player photo files referenced by the roster."
        default:
            return "Additional readiness checks."
        }
    }
}

private struct ReadinessIssueFamily: Identifiable {
    let id: String
    let title: String
    let helperText: String
    let checks: [ReadinessCheck]

    var status: ReadinessState {
        if checks.contains(where: { $0.state == .failed }) {
            return .failed
        }
        if checks.contains(where: { $0.state == .warning }) {
            return .warning
        }
        if checks.contains(where: { $0.state == .unknown }) {
            return .unknown
        }
        return .ready
    }
}

private struct ReadinessOverviewCard: View {
    let readiness: ReadinessStatus
    let onRefresh: () -> Void

    private var readyCount: Int {
        readiness.checks.filter { $0.state == .ready }.count
    }

    private var warningCount: Int {
        readiness.checks.filter { $0.state == .warning }.count
    }

    private var failedCount: Int {
        readiness.checks.filter { $0.state == .failed }.count
    }

    private var unknownCount: Int {
        readiness.checks.filter { $0.state == .unknown }.count
    }

    var body: some View {
        SectionCard(family: .status) {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pre-Game Checklist")
                            .rollCallText(.sectionTitle)
                        Text("Updated \(readiness.generatedAt.formatted(date: .omitted, time: .shortened))")
                            .rollCallText(.helperText)
                    }

                    Spacer(minLength: RollCallSpacingTier.standard.value)

                    ReadinessRefreshButton(action: onRefresh)

                    StatusChip(
                        text: summaryText,
                        role: summaryRole,
                        systemImage: summaryIcon,
                        emphasis: .standard
                    )
                }

                Text("Readiness reports what Roll Call can currently verify. It does not guarantee playback on every route or network condition.")
                    .rollCallText(.helperText)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 118), spacing: RollCallSpacingTier.tight.value)],
                    alignment: .leading,
                    spacing: RollCallSpacingTier.tight.value
                ) {
                    StatusChip(text: "\(readyCount) ready", role: .ready, systemImage: "checkmark.circle", emphasis: .subdued)
                    StatusChip(text: "\(warningCount) warnings", role: .warning, systemImage: "exclamationmark.triangle", emphasis: .subdued)
                    StatusChip(text: "\(failedCount) failed", role: .destructive, systemImage: "xmark.octagon", emphasis: .subdued)
                    if unknownCount > 0 {
                        StatusChip(text: "\(unknownCount) unknown", role: .neutral, systemImage: "questionmark.circle", emphasis: .subdued)
                    }
                }
            }
        }
    }

    private var summaryText: String {
        if failedCount > 0 {
            return "Needs Attention"
        }
        if warningCount > 0 {
            return "Warnings"
        }
        if unknownCount > 0 {
            return "Some Unknown"
        }
        return "Ready"
    }

    private var summaryRole: StatusChipRole {
        if failedCount > 0 {
            return .destructive
        }
        if warningCount > 0 {
            return .warning
        }
        if unknownCount > 0 {
            return .neutral
        }
        return .ready
    }

    private var summaryIcon: String {
        if failedCount > 0 {
            return "xmark.octagon"
        }
        if warningCount > 0 {
            return "exclamationmark.triangle"
        }
        if unknownCount > 0 {
            return "questionmark.circle"
        }
        return "checkmark.circle"
    }
}

private struct ReadinessIssueFamilyCard: View {
    let family: ReadinessIssueFamily

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: RollCallSpacingTier.standard.value) {
                    Text(family.title)
                        .rollCallText(.sectionTitle)
                    Spacer(minLength: RollCallSpacingTier.standard.value)
                    StatusChip(
                        text: family.status.readinessLabel,
                        role: family.status.statusChipRole,
                        systemImage: family.status.statusChipIcon,
                        emphasis: .subdued
                    )
                }

                Text(family.helperText)
                    .rollCallText(.helperText)
            }
            .padding(.horizontal, 2)

            SectionCard(family: family.status.cardFamily) {
                VStack(spacing: 0) {
                    ForEach(Array(family.checks.enumerated()), id: \.element.id) { index, check in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 42)
                        }
                        ReadinessCheckRow(check: check)
                            .padding(.vertical, RollCallSpacingTier.tight.value)
                    }
                }
            }
        }
    }
}

private struct ReadinessCheckRow: View {
    let check: ReadinessCheck

    var body: some View {
        HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
            Image(systemName: check.state.statusChipIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(check.state.semanticColor)
                .frame(width: 30, height: 30)
                .background(check.state.semanticColor.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: RollCallSpacingTier.tight.value) {
                    Text(check.title)
                        .rollCallText(.cardTitle)
                    Spacer(minLength: RollCallSpacingTier.tight.value)
                    StatusChip(
                        text: check.state.readinessLabel,
                        role: check.state.statusChipRole,
                        emphasis: .subdued
                    )
                }
                Text(check.detail)
                    .rollCallText(.helperText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReadinessEmptyCard: View {
    let onRefresh: () -> Void

    var body: some View {
        SectionCard(family: .status) {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                        StatusChip(text: "Not Checked Yet", role: .neutral, systemImage: "checklist", emphasis: .subdued)
                        Text("Pre-Game Checklist")
                            .rollCallText(.sectionTitle)
                    }

                    Spacer(minLength: RollCallSpacingTier.standard.value)

                    ReadinessRefreshButton(action: onRefresh)
                }

                Text("Tap Refresh to generate the current readiness report.")
                    .rollCallText(.helperText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ReadinessRefreshButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint("Updates the readiness checklist.")
    }
}

private struct TeamsSectionGroup<Content: View>: View {
    let title: String
    let helperText: String
    let content: Content

    init(
        title: String,
        helperText: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helperText = helperText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .rollCallText(.sectionTitle)
                Text(helperText)
                    .rollCallText(.helperText)
            }
            .padding(.horizontal, 2)

            SectionCard {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct TeamSelectionRow: View {
    let team: Team
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
            TeamRowIcon(isSelected: isSelected)

            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .rollCallText(.cardTitle)
                    .lineLimit(2)
                Text("\(team.players.count) players • \(team.presentPlayersInBattingOrder.count) present")
                    .rollCallText(.helperText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                StatusChip(
                    text: "Current",
                    role: .ready,
                    systemImage: "checkmark.circle",
                    emphasis: .subdued
                )
            }
        }
        .contentShape(Rectangle())
    }
}

private struct SelectedTeamSummary: View {
    let team: Team

    var body: some View {
        HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
            TeamRowIcon(isSelected: true)

            VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                Text(team.name)
                    .rollCallText(.primaryIdentity)
                    .lineLimit(2)

                HStack(spacing: RollCallSpacingTier.tight.value) {
                    StatusChip(
                        text: "\(team.players.count) players",
                        role: .neutral,
                        systemImage: "person.3",
                        emphasis: .subdued
                    )
                    StatusChip(
                        text: "\(team.presentPlayersInBattingOrder.count) present",
                        role: .ready,
                        systemImage: "checkmark.circle",
                        emphasis: .subdued
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TeamRowIcon: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "person.3.fill" : "person.3")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isSelected ? Color.rollCall(.ready) : Color.rollCall(.accent))
            .frame(width: 34, height: 34)
            .background((isSelected ? Color.rollCall(.ready) : Color.rollCall(.accent)).opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct TeamsEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            StatusChip(text: "No teams yet", role: .neutral, systemImage: "person.3", emphasis: .subdued)
            Text("Create a team to start building a roster.")
                .rollCallText(.helperText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension ReadinessState {
    var readinessLabel: String {
        switch self {
        case .ready: return "Ready"
        case .warning: return "Warning"
        case .failed: return "Failed"
        case .unknown: return "Unknown"
        }
    }

    var statusChipRole: StatusChipRole {
        switch self {
        case .ready: return .ready
        case .warning: return .warning
        case .failed: return .destructive
        case .unknown: return .neutral
        }
    }

    var statusChipIcon: String {
        switch self {
        case .ready: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .failed: return "xmark.octagon"
        case .unknown: return "questionmark.circle"
        }
    }

    var semanticColor: Color {
        switch self {
        case .ready: return Color.rollCall(.ready)
        case .warning: return Color.rollCall(.warning)
        case .failed: return Color.rollCall(.destructive)
        case .unknown: return Color(uiColor: .secondaryLabel)
        }
    }

    var cardFamily: RollCallCardFamily {
        switch self {
        case .ready, .unknown:
            return .utility
        case .warning, .failed:
            return .status
        }
    }
}

private struct SettingsSectionGroup<Content: View>: View {
    let title: String
    let helperText: String?
    let content: Content

    init(
        title: String,
        helperText: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helperText = helperText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .rollCallText(.sectionTitle)
                if let helperText {
                    Text(helperText)
                        .rollCallText(.helperText)
                }
            }
            .padding(.horizontal, 2)

            SectionCard {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct SettingsNavigationLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: RollCallSpacingTier.standard.value) {
            SettingsRowLabel(title: title, detail: detail, systemImage: systemImage)
            Spacer(minLength: RollCallSpacingTier.standard.value)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
            SettingsIcon(systemImage: systemImage, role: .accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .rollCallText(.cardTitle)
                    .lineLimit(2)
                Text(detail)
                    .rollCallText(.helperText)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsIcon: View {
    let systemImage: String
    let role: RollCallColorRole

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.rollCall(role))
            .frame(width: 34, height: 34)
            .background(Color.rollCall(role).opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct RollCallPackageImportSheet: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.rollCallPackage, .data, .folder],
            asCopy: false
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }
    }
}

private struct GameDayBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(colors: [Color.orange.opacity(0.18), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            LinearGradient(colors: [Color.white, Color.orange.opacity(0.20), Color.yellow.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct GameDayPlayerGrid: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var playbackEngine: CuePlaybackEngine

    init(appModel: AppModel) {
        self.appModel = appModel
        _playbackEngine = ObservedObject(initialValue: appModel.playbackEngine)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(appModel.selectedTeamPresentPlayers) { player in
                    let isActive = if let cueID = player.cue?.id {
                        playbackEngine.activeCueID == cueID
                    } else {
                        playbackEngine.activeCueID == player.id
                    }
                    let hasCustomIntro = appModel.hasStoredCustomAnnouncer(for: player)
                    let isCustomIntroMissing = player.customAnnouncerRelativePath != nil && !hasCustomIntro
                    let cueLabel = player.cue?.label ?? "No Cue Yet"
                    Button {
                        Task { await appModel.play(player: player) }
                    } label: {
                        VStack(spacing: 10) {
                            PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 64, cornerRadius: 18)
                            Text(player.uniformNumber.isEmpty ? "--" : "#\(player.uniformNumber)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(player.displayName)
                                .font(.title3.weight(.bold))
                                .multilineTextAlignment(.center)
                            Text(cueLabel)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(customIntroStatusText(hasCustomIntro: hasCustomIntro, isMissing: isCustomIntroMissing, readyLabel: "Announcement Cue Ready"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(customIntroStatusForeground(hasCustomIntro: hasCustomIntro, isMissing: isCustomIntroMissing))
                            if isActive {
                                Label("Now Playing", systemImage: "speaker.wave.2.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 152)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(isActive ? Color.green.opacity(0.22) : Color.orange.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(isActive ? Color.green.opacity(0.9) : Color.white.opacity(0.08), lineWidth: isActive ? 3 : 1)
                        )
                        .shadow(color: isActive ? Color.green.opacity(0.18) : .clear, radius: 16, y: 8)
                        .scaleEffect(isActive ? 1.01 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.18), value: isActive)
                }
            }
        }
    }
}

private struct GameDayHeader: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var playbackEngine: CuePlaybackEngine
    let teamName: String

    init(appModel: AppModel, teamName: String) {
        self.appModel = appModel
        self.teamName = teamName
        _playbackEngine = ObservedObject(initialValue: appModel.playbackEngine)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(teamName)
                    .font(.title.bold())
                Text("Portrait-first game board")
            }
            Spacer()
            if playbackEngine.activeCueID != nil {
                Button("Stop Audio") {
                    appModel.stopPlayback()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct LineupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                if let team = appModel.selectedTeam {
                    Section("Lineup") {
                        HStack(spacing: 12) {
                            Button("Sort A-Z") {
                                appModel.sortBattingOrderAlphabetically()
                            }
                            .buttonStyle(.bordered)

                            Button("Sort by Number") {
                                appModel.sortBattingOrderByNumber()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)

                        ForEach(team.battingOrderPlayers) { player in
                            HStack {
                                PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 40, cornerRadius: 12)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.displayName)
                                    if !player.uniformNumber.isEmpty {
                                        Text("#\(player.uniformNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { player.isPresent },
                                    set: { appModel.setPresent(player, isPresent: $0) }
                                ))
                                .labelsHidden()
                            }
                        }
                        .onMove(perform: appModel.moveBattingOrder)
                    }

                    Section("Status") {
                        Text("Manual order is preserved across launches until you sort or move the lineup again.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Today’s Lineup")
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct RecoveryCenterView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        List {
            Section("Backups") {
                Text("Create a manual backup before risky edits. Automatic backups are also created before package imports, and only the newest 10 are kept.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Create Backup") {
                    appModel.createBackup(reason: "Manual backup")
                }
            }

            Section("Available Backups") {
                if appModel.state.snapshots.isEmpty {
                    Text("No backups yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.state.snapshots) { snapshot in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(snapshot.reason)
                                .font(.headline)
                            Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Restore Backup") {
                                Task { await appModel.restoreBackup(snapshot) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Recovery & Backups")
    }
}

private struct DeveloperToolsView: View {
    @ObservedObject var appModel: AppModel
    @Binding var showExperimentalWarning: Bool

    var body: some View {
        List {
            Section("Experimental Features") {
                if appModel.state.experimental.appleMusicLocalCopyEnabled {
                    Label("Apple Music local copies enabled", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("This remains a developer-facing experiment and is not the primary product path.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Enable Experimental Apple Music Local Copies") {
                        showExperimentalWarning = true
                    }
                    Text("Developer only: attempts to turn preview media into normal local files. This may fail and may not be App Store appropriate.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Diagnostics") {
                Button("Generate Support Bundle") {
                    Task { await appModel.exportSupportBundle() }
                }
                if let supportBundle = appModel.supportBundle {
                    ShareLink(item: supportBundle.url) {
                        Label("Share Latest Support Bundle", systemImage: "square.and.arrow.up")
                    }
                }
                Text("Support bundles include app version, schema version, feature flags, readiness results, and playback diagnostics. Imported media and other user content are excluded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Developer Tools")
    }
}

private struct PlayerQuickAddView: View {
    private enum Field: Hashable {
        case name
        case number
    }

    @ObservedObject var appModel: AppModel
    @State private var name = ""
    @State private var number = ""
    @FocusState private var focusedField: Field?
    
    private var canAddPlayer: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        TextField("Player name", text: $name)
            .focused($focusedField, equals: .name)
            .submitLabel(.next)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(true)
            .onSubmit {
                focusedField = .number
            }
        TextField("Number", text: $number)
            .focused($focusedField, equals: .number)
            .keyboardType(.numberPad)
            .submitLabel(.done)
        HStack {
            Button("Dismiss Keyboard") {
                focusedField = nil
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Add Player") {
                addPlayerAndReset()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAddPlayer)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Done") {
                    focusedField = nil
                }
                Spacer()
                Button("Add") {
                    addPlayerAndReset()
                }
                .disabled(!canAddPlayer)
            }
        }
    }

    private func addPlayerAndReset() {
        appModel.addPlayer(name: name, number: number)
        name = ""
        number = ""
        focusedField = .name
    }
}

private struct PlayersSectionHeader: View {
    let title: String
    let helperText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .rollCallText(.sectionTitle)
            Text(helperText)
                .rollCallText(.helperText)
                .textCase(nil)
        }
        .padding(.top, 2)
        .textCase(nil)
    }
}

private struct PlayerRosterRow: View {
    let player: Player
    let cue: Cue?
    let isPresent: Bool
    let hasCustomIntro: Bool
    let isCustomIntroMissing: Bool

    var body: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
            PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 44, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: RollCallSpacingTier.tight.value) {
                    Text(player.displayName)
                        .rollCallText(.cardTitle)
                        .lineLimit(2)
                    if !player.uniformNumber.isEmpty {
                        Text("#\(player.uniformNumber)")
                            .rollCallText(.helperText)
                            .lineLimit(1)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    cueSummary

                    operationalSummary
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens player details.")
    }

    @ViewBuilder
    private var cueSummary: some View {
        if let cue {
            Label(cue.rosterDisplayTitle, systemImage: "music.note")
                .rollCallText(.helperText)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(1)
        } else {
            Label("No cue", systemImage: "music.note")
                .rollCallText(.helperText)
                .foregroundStyle(Color.rollCall(.warning))
                .lineLimit(1)
        }
    }

    private var operationalSummary: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.tight.value) {
            if !isPresent {
                Label("Hidden from Game Day", systemImage: "eye.slash")
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }

            if isCustomIntroMissing {
                Label("Announcer missing", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.rollCall(.destructive))
            } else if !hasCustomIntro {
                Label("No announcer cue", systemImage: "mic.slash")
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
        }
        .rollCallText(.chipLabel)
        .lineLimit(1)
    }
}

private struct PlayerEditorSheet: View {
    private struct PendingPhotoCrop: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private enum Field: Hashable {
        case displayName
        case uniformNumber
        case pronunciation
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    @State var player: Player
    @State private var importPresented = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingPhotoCrop: PendingPhotoCrop?
    @State private var photoCropFallbackTask: Task<Void, Never>?
    @State private var didCropperRender = false
    @State private var showAppleMusicPicker = false
    @State private var trimMode: TrimSuggestionMode = .suggestedHook
    @State private var showAdvancedTrim = false
    @State private var liveScrubTask: Task<Void, Never>?
    @State private var pendingClearAction: PendingClearAction?
    @State private var isStartTrimEditingEnabled = false
    @FocusState private var focusedField: Field?

    private let lengthOptions: [Double] = [6, 8, 10, 12, 15]

    var body: some View {
        let hasStoredCustomIntro = appModel.hasStoredCustomAnnouncer(for: player)
        let isCustomIntroMissing = player.customAnnouncerRelativePath != nil && !hasStoredCustomIntro

        NavigationStack {
            Form {
                Section("Player") {
                    let photoRelativePath = player.photoRelativePath
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 10) {
                            PlayerPhotoThumbnail(relativePath: photoRelativePath, size: 110, cornerRadius: 28)
                            Text(photoRelativePath == nil ? "Tap to Choose Photo" : "Tap to Replace Photo")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.clear)
                    TextField("Display Name", text: $player.displayName)
                        .focused($focusedField, equals: .displayName)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .uniformNumber
                        }
                    TextField("Uniform Number", text: $player.uniformNumber)
                        .focused($focusedField, equals: .uniformNumber)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .pronunciation
                        }
                    TextField("Pronunciation Override", text: $player.pronunciationOverride)
                        .focused($focusedField, equals: .pronunciation)
                    Toggle("Present Today", isOn: $player.isPresent)
                }

                Section("Cue Source") {
                    if case .appleMusic(let source)? = player.cue?.source {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Selected Song")
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(source.title)
                                Text(source.artistName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Change Song") { showAppleMusicPicker = true }
                                .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            showAppleMusicPicker = true
                        } label: {
                            Label("Choose Song", systemImage: "music.note")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                Section("Announcement Cue") {
                    Text("Optional. When Game Day is set to Announcement Cues, Roll Call will play this recording before the player’s cue.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if isCustomIntroMissing {
                        Label("Roll Call still has an Announcement Cue reference for this player, but the audio file is missing from app storage.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if appModel.isRecordingCustomAnnouncer(for: player) {
                        Button("Stop Recording") {
                            let currentPlayer = player
                            Task {
                                await appModel.stopRecordingCustomAnnouncer(for: currentPlayer)
                                await MainActor.run { refreshPlayerFromModel() }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button(appModel.customAnnouncerButtonTitle(for: player)) {
                            let currentPlayer = player
                            Task {
                                await appModel.startRecordingCustomAnnouncer(for: currentPlayer)
                            }
                        }
                        .disabled(appModel.isCustomAnnouncerTransitioning(for: player))
                    }

                    if hasStoredCustomIntro {
                        Button("Preview Announcement Cue") {
                            appModel.previewCustomAnnouncer(for: player)
                        }
                    }
                }

                Section("More Audio Options") {
                    DisclosureGroup("Import from Device") {
                        Button("Import Audio or Video") { importPresented = true }
                            .padding(.top, 6)
                        Text("Fallback path for device-owned audio when Apple Music is not the right source for this cue.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }

                if let cue = player.cue {
                    Section("Clip Trim") {
                        cueTrimSection(for: cue)
                    }

                    if appModel.state.experimental.appleMusicLocalCopyEnabled, case .appleMusic = cue.source {
                        Section("Experimental") {
                            Button("Make Local Copy") {
                                appModel.updatePlayer(player)
                                let currentPlayer = player
                                Task {
                                    await appModel.makeLocalCopy(for: currentPlayer)
                                    await MainActor.run { refreshPlayerFromModel() }
                                }
                            }
                        }
                    }
                }

                Section("Clear Audio") {
                    Button("Clear Song") {
                        pendingClearAction = .song
                    }
                    .disabled(player.cue == nil)

                    Button("Clear Custom Announcer") {
                        pendingClearAction = .customAnnouncer
                    }
                    .disabled(player.customAnnouncerRelativePath == nil)
                }
            }
            .navigationTitle(player.displayName.isEmpty ? "Player" : player.displayName)
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        appModel.updatePlayer(player)
                        dismiss()
                    }
                }
            }
            .onChange(of: photoItem) { _, _ in
                Task { await importPhoto() }
            }
            .onAppear {
                normalizeTrimModeForCurrentCue()
            }
            .task {
                await appModel.refreshAppleMusicPlaybackCapability()
                if await appModel.refreshAppleMusicCueMetadata(for: player.id) {
                    await MainActor.run { refreshPlayerFromModel() }
                }
            }
            .onDisappear {
                if appModel.isRecordingCustomAnnouncer(for: player) {
                    appModel.cancelRecordingCustomAnnouncer()
                }
            }
            .alert("Are you sure?", isPresented: Binding(
                get: { pendingClearAction != nil },
                set: { if !$0 { pendingClearAction = nil } }
            ), presenting: pendingClearAction) { action in
                Button("Cancel", role: .cancel) {
                    pendingClearAction = nil
                }
                Button(action.confirmButtonTitle, role: .destructive) {
                    performClearAction(action)
                }
            } message: { action in
                Text(action.confirmationMessage)
            }
            .fileImporter(isPresented: $importPresented, allowedContentTypes: [.audio, .movie], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let currentPlayer = player
                    Task {
                        await appModel.importMedia(from: url, for: currentPlayer)
                        await MainActor.run { refreshPlayerFromModel() }
                    }
                }
            }
            .sheet(isPresented: $showAppleMusicPicker) {
                AppleMusicPickerSheet(appModel: appModel) { result in
                    let currentPlayer = player
                    Task {
                        let didAssign = await appModel.assignAppleMusic(result, to: currentPlayer)
                        guard didAssign else { return }
                        await MainActor.run {
                            refreshPlayerFromModel()
                            trimMode = .suggestedHook
                            applyTrimSuggestion(mode: .suggestedHook)
                            showAppleMusicPicker = false
                        }
                    }
                }
            }
            .sheet(isPresented: $showAdvancedTrim) {
                if player.cue != nil {
                    AdvancedTrimSheet(
                        cue: Binding(
                            get: { player.cue! },
                            set: { player.cue = $0 }
                        ),
                        cueTimeLimit: cueTimeLimit,
                        cueDurationLimit: cueDurationLimit
                    )
                    .presentationDetents([.medium])
                }
            }
            .fullScreenCover(item: $pendingPhotoCrop) { pending in
                BasicPhotoCropperSheet(
                    image: pending.image,
                    onReady: {
                        didCropperRender = true
                        photoCropFallbackTask?.cancel()
                        photoCropFallbackTask = nil
                    },
                    onCancel: {
                        photoCropFallbackTask?.cancel()
                        photoCropFallbackTask = nil
                        pendingPhotoCrop = nil
                    },
                    onApply: { croppedImage in
                        photoCropFallbackTask?.cancel()
                        photoCropFallbackTask = nil
                        savePlayerPhoto(croppedImage)
                        pendingPhotoCrop = nil
                    }
                )
            }
        }
    }

    private var cueTimeLimit: Double {
        guard let cue = player.cue else { return 30 }
        return appModel.cueTimelineLength(for: cue)
    }

    private var cueDurationLimit: Double {
        guard let cue = player.cue else { return 30 }
        return appModel.cueDurationLimit(for: cue)
    }

    private func importPhoto() async {
        guard let photoItem,
              let data = try? await photoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }

        await MainActor.run {
            photoCropFallbackTask?.cancel()
            didCropperRender = false
            pendingPhotoCrop = PendingPhotoCrop(image: image)
            photoCropFallbackTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !didCropperRender, let pending = pendingPhotoCrop else { return }
                    savePlayerPhoto(pending.image)
                    appModel.lastError = "Photo crop screen did not load in time. Roll Call saved the original photo instead."
                    pendingPhotoCrop = nil
                }
            }
        }
    }

    private func savePlayerPhoto(_ image: UIImage) {
        guard let jpeg = image.jpegData(compressionQuality: 0.8),
              let assetsDir = try? AppPaths.assetsDirectory() else { return }
        let fileName = "\(UUID().uuidString).jpg"
        do {
            try jpeg.write(to: assetsDir.appendingPathComponent(fileName), options: .atomic)
            player.photoRelativePath = fileName
        } catch {
            appModel.lastError = error.localizedDescription
        }
    }

    private func refreshPlayerFromModel() {
        player = appModel.selectedTeam?.players.first(where: { $0.id == player.id }) ?? player
        isStartTrimEditingEnabled = false
        normalizeTrimModeForCurrentCue()
    }

    private func performClearAction(_ action: PendingClearAction) {
        switch action {
        case .song:
            appModel.clearSong(for: player)
        case .customAnnouncer:
            appModel.clearCustomAnnouncer(for: player)
        }
        pendingClearAction = nil
        refreshPlayerFromModel()
    }

    private func secondsText(_ value: Double) -> String {
        formattedCueTime(value)
    }

    @ViewBuilder
    private func cueTrimSection(for cue: Cue) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let trimHelpText = appModel.appleMusicTrimHelpText(for: cue) {
                Text(trimHelpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(TrimSuggestionMode.allCases) { mode in
                        Button(mode.title) {
                            trimMode = mode
                            applyTrimSuggestion(mode: mode)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(trimMode == mode ? .orange : .gray.opacity(0.4))
                    }
                }
            }

            Button {
                guard let cue = player.cue else { return }
                Task { await appModel.previewCue(cue) }
            } label: {
                Label("Preview Clip", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start")
                        .font(.headline)
                    Spacer()
                    Button(isStartTrimEditingEnabled ? "Done" : "Enable") {
                        isStartTrimEditingEnabled.toggle()
                    }
                    .buttonStyle(.bordered)
                    Text(secondsText(cue.startTime))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                StartScrubControl(
                    progress: cueTimeLimit <= 0 ? 0 : cue.startTime / cueTimeLimit,
                    displayRange: cueTimeLimit,
                    currentValueText: secondsText(cue.startTime),
                    onSeek: { progress in
                        updateCueStart(progress: progress)
                    },
                    onLiveScrub: { progress in
                        updateCueStart(progress: progress)
                        scheduleLiveScrubPreview()
                    }
                )
                .allowsHitTesting(isStartTrimEditingEnabled)
                .opacity(isStartTrimEditingEnabled ? 1 : 0.45)
                .overlay(alignment: .center) {
                    if !isStartTrimEditingEnabled {
                        Text("Tap Enable to adjust start")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Length")
                        .font(.headline)
                    Spacer()
                    Text(secondsText(cue.duration))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                FlowChipRow(options: lengthOptions, selected: cue.duration) { option in
                    updateCueDuration(option)
                    appModel.rememberPreferredLength(option)
                }
            }

            Button("Advanced") {
                showAdvancedTrim = true
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private func normalizeTrimModeForCurrentCue() {
        guard let cue = player.cue, case .appleMusic = cue.source else { return }
        let beginningCue = appModel.chooseStartAtBeginning(for: cue)
        trimMode = abs(beginningCue.startTime - cue.startTime) < 0.01 ? .startAtBeginning : .suggestedHook
    }

    private func applyTrimSuggestion(mode: TrimSuggestionMode) {
        guard let cue = player.cue, case .appleMusic = cue.source else { return }
        switch mode {
        case .suggestedHook:
            player.cue = appModel.chooseSuggestedHook(for: cue)
        case .startAtBeginning:
            player.cue = appModel.chooseStartAtBeginning(for: cue)
        }
    }

    private func updateCueStart(progress: Double) {
        guard var cue = player.cue else { return }
        let maxStart = max(0, cueTimeLimit - cue.duration)
        cue.startTime = min(max(0, progress * cueTimeLimit), maxStart)
        player.cue = cue
    }

    private func updateCueDuration(_ duration: Double) {
        guard var cue = player.cue else { return }
        cue.duration = min(duration, cueDurationLimit)
        cue.duration = min(cue.duration, cueTimeLimit - cue.startTime)
        cue.duration = max(0.5, cue.duration)
        player.cue = cue
    }

    private func scheduleLiveScrubPreview() {
        liveScrubTask?.cancel()
        guard let cue = player.cue else { return }
        liveScrubTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await appModel.previewCue(cue)
        }
    }
}

private func formattedCueTime(_ value: Double) -> String {
    let clamped = max(0, value)
    if clamped >= 60 {
        let minutes = Int(clamped) / 60
        let seconds = clamped.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    return String(format: "%.2fs", clamped)
}

private struct BasicPhotoCropperSheet: View {
    let image: UIImage
    let onReady: () -> Void
    let onCancel: () -> Void
    let onApply: (UIImage) -> Void

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 280

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Pinch to zoom, drag to position.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.92))

                    GeometryReader { geometry in
                        let side = min(cropSize, min(geometry.size.width, geometry.size.height))
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: side, height: side)
                                .scaleEffect(zoom)
                                .offset(offset)
                                .clipped()
                                .gesture(dragGesture(maxSide: side))
                                .simultaneousGesture(magnifyGesture(maxSide: side))

                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.88), lineWidth: 2)
                                .frame(width: side, height: side)
                                .allowsHitTesting(false)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: cropSize)
                }
                .frame(height: cropSize + 24)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button("Reset") {
                        zoom = 1
                        lastZoom = 1
                        offset = .zero
                        lastOffset = .zero
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .navigationTitle("Adjust Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use Photo") {
                        onApply(croppedImage() ?? image)
                    }
                }
            }
            .onAppear {
                onReady()
            }
        }
    }

    private func magnifyGesture(maxSide: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(max(lastZoom * value, 1), 4)
                clampOffset(maxSide: maxSide)
            }
            .onEnded { _ in
                lastZoom = zoom
                clampOffset(maxSide: maxSide)
                lastOffset = offset
            }
    }

    private func dragGesture(maxSide: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                clampOffset(maxSide: maxSide)
            }
            .onEnded { _ in
                clampOffset(maxSide: maxSide)
                lastOffset = offset
            }
    }

    private func clampOffset(maxSide: CGFloat) {
        let normalized = image.normalizedUpImage()
        let baseScale = max(maxSide / normalized.size.width, maxSide / normalized.size.height)
        let scaledWidth = normalized.size.width * baseScale * zoom
        let scaledHeight = normalized.size.height * baseScale * zoom
        let maxX = max((scaledWidth - maxSide) / 2, 0)
        let maxY = max((scaledHeight - maxSide) / 2, 0)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
    }

    private func croppedImage() -> UIImage? {
        let normalized = image.normalizedUpImage()
        guard let cgImage = normalized.cgImage else { return nil }

        let side = cropSize
        let baseScale = max(side / normalized.size.width, side / normalized.size.height)
        let effectiveScale = baseScale * zoom
        let displayedWidth = normalized.size.width * effectiveScale
        let displayedHeight = normalized.size.height * effectiveScale

        let originX = (side - displayedWidth) / 2 + offset.width
        let originY = (side - displayedHeight) / 2 + offset.height

        var cropRect = CGRect(
            x: (0 - originX) / effectiveScale,
            y: (0 - originY) / effectiveScale,
            width: side / effectiveScale,
            height: side / effectiveScale
        ).integral

        cropRect.origin.x = max(0, min(cropRect.origin.x, normalized.size.width - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, normalized.size.height - cropRect.height))
        cropRect.size.width = min(cropRect.width, normalized.size.width - cropRect.origin.x)
        cropRect.size.height = min(cropRect.height, normalized.size.height - cropRect.origin.y)

        guard let cropped = cgImage.cropping(to: cropRect), cropped.width > 0, cropped.height > 0 else {
            return nil
        }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
    }
}

private extension UIImage {
    func normalizedUpImage() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension PlayerEditorSheet {
    enum PendingClearAction: Identifiable {
        case song
        case customAnnouncer

        var id: String {
            switch self {
            case .song:
                return "song"
            case .customAnnouncer:
                return "customAnnouncer"
            }
        }

        var confirmButtonTitle: String {
            switch self {
            case .song:
                return "Clear Song"
            case .customAnnouncer:
                return "Clear Custom Announcer"
            }
        }

        var confirmationMessage: String {
            switch self {
            case .song:
                return "This will remove the current cue for this player."
            case .customAnnouncer:
                return "This will remove only the Announcement Cue recording for this player."
            }
        }
    }
}

private func cueStatusText(cueLabel: String?) -> String {
    cueLabel ?? "Add Cue"
}

private func cueStatusBackground(cueLabel: String?) -> Color {
    cueLabel == nil ? Color.gray.opacity(0.14) : Color.orange.opacity(0.15)
}

private func cueStatusForeground(cueLabel: String?) -> Color {
    cueLabel == nil ? .secondary : .orange
}

private func customIntroStatusText(hasCustomIntro: Bool, isMissing: Bool, readyLabel: String = "Announcement Cue") -> String {
    if hasCustomIntro {
        return readyLabel
    }
    if isMissing {
        return "Announcement Cue Missing"
    }
    return "No Announcement Cue"
}

private func customIntroStatusForeground(hasCustomIntro: Bool, isMissing: Bool) -> Color {
    if hasCustomIntro {
        return .green
    }
    if isMissing {
        return .red
    }
    return .secondary
}

private func customIntroStatusBackground(hasCustomIntro: Bool, isMissing: Bool) -> Color {
    if hasCustomIntro {
        return Color.green.opacity(0.15)
    }
    if isMissing {
        return Color.red.opacity(0.14)
    }
    return Color.secondary.opacity(0.14)
}

private extension Cue {
    var rosterDisplayTitle: String {
        switch source {
        case .appleMusic(let source):
            return source.title
        case .localAudio(let source):
            return source.displayName.songTitleWithoutArtistPrefix
        case .builtInClip(let source):
            return source.displayName
        }
    }
}

private extension String {
    var songTitleWithoutArtistPrefix: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = [" - ", " — ", " – "]
        for separator in separators {
            guard let range = trimmed.range(of: separator) else { continue }
            let candidate = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                return candidate
            }
        }
        return trimmed
    }
}

private enum TrimSuggestionMode: String, CaseIterable, Identifiable {
    case suggestedHook
    case startAtBeginning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .suggestedHook:
            return "Suggested Hook"
        case .startAtBeginning:
            return "Start at Beginning"
        }
    }
}

private struct AppleMusicPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let onSelect: (MusicSearchResult) -> Void

    @State private var searchTerm = ""
    @State private var results: [MusicSearchResult] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchError: String?

    private var showsRecents: Bool {
        searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                capabilityBanner
                if showsRecents {
                    Section("Recent Songs") {
                        if appModel.recentAppleMusicSelections.isEmpty {
                            Text("Your recent songs will show up here.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appModel.recentAppleMusicSelections) { recent in
                                AppleMusicRow(
                                    title: recent.title,
                                    artistName: recent.artistName,
                                    badge: recent.isCatalogBacked == false ? "Preview" : "Full Song",
                                    onSelect: {
                                        onSelect(recent.asSearchResult)
                                    },
                                    onPreview: {
                                        Task { await appModel.previewAppleMusicSearchResult(recent.asSearchResult) }
                                    }
                                )
                            }
                        }
                    }
                } else {
                    Section("Search Results") {
                        if isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Searching Apple Music…")
                                    .foregroundStyle(.secondary)
                            }
                        } else if results.isEmpty, hasSearched {
                            Text(searchError ?? "No songs found. Try a different search.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(results) { result in
                                AppleMusicRow(
                                    title: result.title,
                                    artistName: result.artistName,
                                    badge: result.isCatalogBacked ? "Full Song" : "Preview",
                                    onSelect: {
                                        onSelect(result)
                                    },
                                    onPreview: {
                                        Task { await appModel.previewAppleMusicSearchResult(result) }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Song")
            .searchable(text: $searchTerm, prompt: "Search Apple Music")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await appModel.refreshAppleMusicPlaybackCapability()
            }
            .onChange(of: searchTerm) { _, newValue in
                queueSearch(for: newValue)
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    @ViewBuilder
    private var capabilityBanner: some View {
        Section {
            switch appModel.appleMusicPlaybackCapability {
            case .fullSong:
                Text("Apple Music subscription detected. You can choose up to 20 seconds from anywhere in the full song.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .previewOnly, .unknown:
                Text("No Apple Music playback subscription detected. You can still choose a song, but trimming is limited to the available preview clip.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func queueSearch(for rawValue: String) {
        searchTask?.cancel()
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isLoading = false
            hasSearched = false
            searchError = nil
            return
        }

        isLoading = true
        hasSearched = false
        searchError = nil
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let fetched = try await appModel.searchAppleMusic(term: trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = fetched
                    isLoading = false
                    hasSearched = true
                    searchError = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = []
                    isLoading = false
                    hasSearched = true
                    searchError = error.localizedDescription
                    appModel.lastError = error.localizedDescription
                }
            }
        }
    }
}

private struct AppleMusicRow: View {
    let title: String
    let artistName: String
    let badge: String
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(badge == "Full Song" ? .green : .orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onPreview) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct StartScrubControl: View {
    let progress: Double
    let displayRange: Double
    let currentValueText: String
    let onSeek: (Double) -> Void
    let onLiveScrub: (Double) -> Void

    @GestureState private var isPressing = false
    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let thumbOffset = max(0, min(width - 28, width * progress - 14))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 18)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.8))
                    .frame(width: max(14, width * progress), height: 18)
                if isDragging {
                    Text(currentValueText)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .offset(x: max(0, min(width - 72, width * progress - 36)), y: -30)
                }
                Circle()
                    .fill(Color.orange)
                    .frame(width: 28, height: 28)
                    .offset(x: thumbOffset)
                    .shadow(radius: 2)
            }
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        let newProgress = min(max(0, value.location.x / width), 1)
                        onSeek(newProgress)
                        if isPressing {
                            onLiveScrub(newProgress)
                        }
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .updating($isPressing) { current, state, _ in
                        state = current
                    }
            )
        }
        .frame(height: 40)
        .accessibilityValue(Text("\(Int(progress * displayRange)) seconds"))
    }
}

private struct FlowChipRow: View {
    let options: [Double]
    let selected: Double
    let onSelect: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button("\(Int(option))s") {
                    onSelect(option)
                }
                .buttonStyle(.borderedProminent)
                .tint(abs(selected - option) < 0.01 ? .orange : .gray.opacity(0.35))
            }
        }
    }
}

private struct AdvancedTrimSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cue: Cue
    let cueTimeLimit: Double
    let cueDurationLimit: Double

    var body: some View {
        NavigationStack {
            Form {
                Section("Fine Tune") {
                    nudgeRow(title: "Start", value: cue.startTime) { delta in
                        let maxStart = max(0, cueTimeLimit - cue.duration)
                        cue.startTime = min(max(0, cue.startTime + delta), maxStart)
                    }
                    nudgeRow(title: "Length", value: cue.duration) { delta in
                        cue.duration = min(max(0.5, cue.duration + delta), cueDurationLimit)
                        cue.duration = min(cue.duration, cueTimeLimit - cue.startTime)
                    }
                }

                Section("Fade Out") {
                    nudgeRow(title: "Fade", value: cue.fadeOutDuration) { delta in
                        cue.fadeOutDuration = min(max(0.1, cue.fadeOutDuration + delta), 3.0)
                    }
                }
            }
            .navigationTitle("Advanced Trim")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func nudgeRow(title: String, value: Double, apply: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button("-0.25") { apply(-0.25) }
                .buttonStyle(.bordered)
            Text(formattedCueTime(value))
                .monospacedDigit()
                .frame(minWidth: 68)
            Button("+0.25") { apply(0.25) }
                .buttonStyle(.bordered)
        }
    }
}

private extension RecentAppleMusicSelection {
    var asSearchResult: MusicSearchResult {
        MusicSearchResult(songID: songID, title: title, artistName: artistName, duration: duration, previewURL: previewURL, isCatalogBacked: isCatalogBacked ?? true)
    }
}

private struct PlayerPhotoThumbnail: View {
    let relativePath: String?
    var size: CGFloat
    var cornerRadius: CGFloat = 16

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.orange.opacity(0.14))
                    Image(systemName: "person.crop.square.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.orange.opacity(0.8))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func loadImage() -> UIImage? {
        guard let relativePath else { return nil }
        return PlayerPhotoCache.shared.image(for: relativePath)
    }
}

private extension View {
    func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissTapOverlay())
    }
}

private struct KeyboardDismissTapOverlay: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func handleTap() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

@MainActor
private final class PlayerPhotoCache {
    static let shared = PlayerPhotoCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(for relativePath: String) -> UIImage? {
        let key = relativePath as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = try? AppPaths.assetURL(relativePath: relativePath),
              let image = UIImage(contentsOfFile: url.path)
        else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}
