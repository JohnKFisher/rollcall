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

private struct PlayingSpeakerSymbol: View {
    let systemImage: String
    var color: Color?
    @State private var isPulsing = false

    var body: some View {
        if #available(iOS 26.0, *) {
            ZStack {
                Image(systemName: resolvedSystemImage)
                    .optionalForegroundStyle(color)
                    .opacity(0.68)
                Image(systemName: resolvedSystemImage)
                    .optionalForegroundStyle(color)
                    .symbolEffect(.drawOn.individually, options: .repeat(.periodic(delay: 3.0)))
            }
        } else {
            Image(systemName: resolvedSystemImage)
                .optionalForegroundStyle(color)
                .scaleEffect(isPulsing ? 1.16 : 0.92)
                .opacity(isPulsing ? 1.0 : 0.62)
                .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear {
                    isPulsing = true
                }
        }
    }

    private var resolvedSystemImage: String {
        if UIImage(systemName: systemImage) != nil {
            return systemImage
        }
        if UIImage(systemName: "speaker.wave.3") != nil {
            return "speaker.wave.3"
        }
        return "speaker.wave.2.fill"
    }
}

private extension View {
    @ViewBuilder
    func optionalForegroundStyle(_ color: Color?) -> some View {
        if let color {
            self.foregroundStyle(color)
        } else {
            self
        }
    }
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

    private var liveTabPreferredColorScheme: ColorScheme? {
        appModel.state.settings.alwaysUseDarkLiveMode ? .dark : nil
    }

    private var clipsSurface: RollCallSurfaceVariant {
        .live
    }

    private var clipsTeamBannerVariant: TeamBannerVariant {
        .liveSide
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            gameDayTab
                .tag(RootTab.gameDay)
                .tabItem { Label("Game Day", systemImage: "play.rectangle.fill") }

            generalClipsTab
                .tag(RootTab.generalClips)
                .tabItem { Label("Clips", systemImage: "music.note.list") }

            playersTab
                .tag(RootTab.players)
                .tabItem { Label("Players", systemImage: "person.3.fill") }

            teamsTab
                .tag(RootTab.teams)
                .tabItem { Label("Teams", systemImage: "list.number") }

            readinessTab
                .tag(RootTab.readiness)
                .tabItem { Label("Readiness", systemImage: "checklist") }

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
            Button("Enable") {
                appModel.setShowExperimentalFeatures(true)
                appModel.enableExperimentalCopies()
            }
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
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader()
            }
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

    private func rootTeamBannerHeader(
        variant: TeamBannerVariant = .standard,
        secondaryStatus: TeamBannerSecondaryStatus? = nil
    ) -> some View {
        VStack(spacing: 0) {
            TeamBanner(
                teamName: appModel.selectedTeam?.name,
                secondaryStatus: secondaryStatus ?? selectedTeamBannerStatus,
                variant: variant
            )
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("root-team-banner")
            .padding(.horizontal, 6)

            Rectangle()
                .fill(Color.rollCall(.neutralStructure, surface: variant == .liveSide ? .live : .standard).opacity(0.55))
                .frame(height: 1)
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background {
            rootTeamBannerBackground(for: variant)
        }
    }

    @ViewBuilder
    private func rootTeamBannerBackground(for variant: TeamBannerVariant) -> some View {
        switch variant {
        case .standard:
            Color(uiColor: .systemGroupedBackground)
        case .liveSide:
            LiveSurfaceBackground()
        }
    }

    private var generalClipsTab: some View {
        NavigationStack {
            ZStack {
                LiveSurfaceBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        if appModel.selectedTeamBuiltInClips.isEmpty {
                            ClipsEmptyStateCard(surface: clipsSurface)
                        } else {
                            ClipsHeaderCard(clipCount: appModel.selectedTeamBuiltInClips.count, surface: clipsSurface)

                            LazyVStack(spacing: RollCallSpacingTier.tight.value) {
                                ForEach(appModel.selectedTeamBuiltInClips) { clip in
                                    GeneralClipCard(clip: clip, surface: clipsSurface) {
                                        Task { await appModel.play(builtInClip: clip) }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Clips")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader(variant: clipsTeamBannerVariant)
            }
        }
        .preferredColorScheme(liveTabPreferredColorScheme)
    }

    private struct ClipsHeaderCard: View {
        let clipCount: Int
        let surface: RollCallSurfaceVariant

        var body: some View {
            HStack(spacing: RollCallSpacingTier.standard.value) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.rollCall(.live, surface: surface))
                    .frame(width: 24, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Crowd clips ready")
                        .rollCallText(.cardTitle, surface: surface)
                    Text("\(clipCount) built-in reactions for quick live moments")
                        .rollCallText(.helperText, surface: surface)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.rollCall(.neutralStructure, surface: surface).opacity(0.7))
                    .frame(height: 1)
            }
        }
    }

    private struct ClipsEmptyStateCard: View {
        let surface: RollCallSurfaceVariant

        var body: some View {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                Image(systemName: "speaker.slash.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.rollCall(.warning, surface: surface))

                VStack(alignment: .leading, spacing: 4) {
                    Text("No clips ready")
                        .rollCallText(.cardTitle, surface: surface)
                    Text("Select a team to use the built-in crowd clip library.")
                        .rollCallText(.helperText, surface: surface)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rollCallCard(surface == .live ? .live : .utility, surface: surface)
        }
    }

    private struct GeneralClipCard: View {
        let clip: BuiltInClip
        let surface: RollCallSurfaceVariant
        let play: () -> Void

        var body: some View {
            Button(action: play) {
                HStack(spacing: RollCallSpacingTier.standard.value) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(clip.title)
                            .rollCallText(.cardTitle, surface: surface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        HStack(spacing: RollCallSpacingTier.tight.value) {
                            Label("Tap to play", systemImage: "hand.tap.fill")
                            Text(clipDurationText)
                        }
                        .rollCallText(.helperText, surface: surface)
                        .lineLimit(1)
                    }

                    Spacer(minLength: RollCallSpacingTier.tight.value)

                    Label("Play", systemImage: "play.fill")
                        .labelStyle(.iconOnly)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.rollCall(.accent, surface: .live), in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        }
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 12)
                .padding(.leading, 14)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(cardBorder)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(clip.title)")
            .accessibilityHint("Plays this built-in crowd clip.")
        }

        private var clipDurationText: String {
            let roundedDuration = Int(clip.cue.duration.rounded())
            return "\(roundedDuration) sec"
        }

        private var cardBackground: some ShapeStyle {
            if surface == .live {
                return LinearGradient(
                    colors: [
                        Color.white.opacity(0.13),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [
                    Color(uiColor: .secondarySystemGroupedBackground),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        private var cardBorder: some View {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.rollCall(.neutralStructure, surface: surface).opacity(0.9), lineWidth: 1)
        }
    }

    private var gameDayTab: some View {
        NavigationStack {
            ZStack {
                GameDayBackground()
                    .ignoresSafeArea()
                GameDayBoard(appModel: appModel) {
                    showLineupEditor = true
                }
            }
            .navigationTitle("Game Day")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader(variant: .liveSide, secondaryStatus: gameDayTeamBannerStatus)
            }
            .sheet(isPresented: $showLineupEditor) {
                LineupEditorSheet(appModel: appModel)
            }
        }
        .preferredColorScheme(liveTabPreferredColorScheme)
    }

    private var readinessTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    if let readiness = appModel.state.lastReadiness {
                        ReadinessOverviewCard(
                            readiness: readiness,
                            team: appModel.selectedTeam,
                            onOpenGameDay: { selectedTab = .gameDay }
                        ) {
                            appModel.refreshReadiness()
                        }

                        ReadinessPlayerAudioCard(
                            checks: playerAudioReadinessChecks(from: readiness.checks),
                            playerForCheck: playerForReadinessCheck,
                            onEditPlayer: { selectedPlayer = $0 }
                        )

                        ReadinessEnhancementsCard(
                            checks: announcementReadinessChecks(from: readiness.checks),
                            playerAudioChecks: playerAudioReadinessChecks(from: readiness.checks),
                            playerForCheck: playerForReadinessCheck,
                            onEditPlayer: { selectedPlayer = $0 }
                        )

                        ReadinessOptionalUpgradesCard(
                            checks: optionalUpgradeReadinessChecks(from: readiness.checks),
                            playerForCheck: playerForReadinessCheck,
                            onEditPlayer: { selectedPlayer = $0 }
                        )

                        ReadinessGameDayChecksCard(
                            checks: gameDayReadinessChecks(from: readiness.checks),
                            onRequestAppleMusicAccess: {
                                Task { await appModel.requestAppleMusicAccess() }
                            }
                        )
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
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader()
            }
            .sheet(item: $selectedPlayer) { player in
                PlayerEditorSheet(appModel: appModel, player: player)
            }
        }
    }

    private var teamsTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
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
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader()
            }
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

    private var gameDayTeamBannerStatus: TeamBannerSecondaryStatus? {
        guard let team = appModel.selectedTeam else {
            return TeamBannerSecondaryStatus(text: "Choose or create a team", tone: .warning)
        }
        if hasLiveGameDayWarning(for: team) {
            return TeamBannerSecondaryStatus(text: "Warnings", tone: .warning)
        }
        return TeamBannerSecondaryStatus(
            text: "\(team.players.count) players • \(team.presentPlayersInBattingOrder.count) present"
        )
    }

    private func hasLiveGameDayWarning(for team: Team) -> Bool {
        let presentPlayers = team.presentPlayersInBattingOrder
        if presentPlayers.isEmpty {
            return true
        }

        guard let readiness = appModel.state.lastReadiness else { return false }
        return readiness.checks.contains { check in
            guard check.state == .issue else { return false }
            if check.id.contains("photo-upgrade") || check.id.contains("announcement-upgrade") { return false }
            if check.id.contains("custom-announcer-issue") {
                return team.session.gameDayAnnouncerMode.usesAnnouncer
            }
            if check.id.hasPrefix("player-") {
                return presentPlayers.contains { player in
                    check.id.contains(player.id.uuidString)
                }
            }
            return ["route", "volume", "network", "music-auth", "lineup"].contains(check.id)
        }
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
                            get: { appModel.state.settings.alwaysUseDarkLiveMode },
                            set: { appModel.setAlwaysUseDarkLiveMode($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Always Use Dark Live Screens",
                                detail: "Keep Game Day and Clips dark for field visibility.",
                                systemImage: "sun.max.fill"
                            )
                        }

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
                                detail: "Allow Roll Call to override playback volume to max, then lower it to simulate a fade-out.",
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
                                StatusChip(
                                    text: BuildEnvironment.current.rawValue,
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

                            NavigationLink {
                                AttributionsView()
                            } label: {
                                SettingsNavigationLabel(
                                    title: "Attributions & Licenses",
                                    detail: "Credits for bundled clips and third-party software.",
                                    systemImage: "doc.text.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if appModel.featureFlags.showDeveloperSettings {
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
                }
                .padding(.horizontal, 16)
                .padding(.top, RollCallSpacingTier.tight.value)
                .padding(.bottom, RollCallSpacingTier.large.value)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader()
            }
            .sheet(isPresented: $packageSharePresented) {
                if let exportURL = appModel.exportURL {
                    ActivityShareSheet(items: [exportURL])
                }
            }
        }
        .tint(Color(uiColor: .label))
    }

    private func playerAudioReadinessChecks(from checks: [ReadinessCheck]) -> [ReadinessCheck] {
        checks.filter { check in
            check.id.hasPrefix("player-")
                && !check.id.contains("announcement-upgrade")
                && !check.id.contains("photo-upgrade")
        }
    }

    private func announcementReadinessChecks(from checks: [ReadinessCheck]) -> [ReadinessCheck] {
        checks.filter { check in
            check.id.contains("announcement-upgrade")
        }
    }

    private func optionalUpgradeReadinessChecks(from checks: [ReadinessCheck]) -> [ReadinessCheck] {
        checks.filter { $0.id.contains("photo-upgrade") }
    }

    private func gameDayReadinessChecks(from checks: [ReadinessCheck]) -> [ReadinessCheck] {
        checks.filter { ["route", "volume", "network", "music-auth", "lineup"].contains($0.id) }
    }

    private func playerForReadinessCheck(_ check: ReadinessCheck) -> Player? {
        appModel.selectedTeam?.players.first { check.id.contains($0.id.uuidString) }
    }
}

private struct ReadinessOverviewCard: View {
    let readiness: ReadinessStatus
    let team: Team?
    let onOpenGameDay: () -> Void
    let onRefresh: () -> Void

    private var presentCount: Int {
        team?.presentPlayersInBattingOrder.count ?? 0
    }

    private var playerChecks: [ReadinessCheck] {
        readiness.checks.filter { check in
            check.id.hasPrefix("player-")
                && !check.id.contains("announcement-upgrade")
                && !check.id.contains("photo-upgrade")
        }
    }

    private var readyCount: Int {
        playerChecks.filter { $0.state == .ready || $0.state == .enhanced }.count
    }

    private var enhancedCount: Int {
        playerChecks.filter { $0.state == .enhanced }.count
    }

    private var needsAudioCount: Int {
        playerChecks.filter { $0.state == .needsAudio }.count
    }

    private var issueCount: Int {
        playerChecks.filter { $0.state == .issue }.count
    }

    private var isReadyForGameDay: Bool {
        presentCount > 0 && needsAudioCount == 0 && issueCount == 0
    }

    var body: some View {
        SectionCard(family: isReadyForGameDay ? .identity : .status) {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
                    VStack(alignment: .leading, spacing: 4) {
                        StatusChip(
                            text: summaryChipText,
                            role: summaryRole,
                            systemImage: summaryIcon,
                            emphasis: .subdued
                        )
                        Text(summaryTitle)
                            .rollCallText(.sectionTitle)
                        Text("Updated \(readiness.generatedAt.formatted(date: .omitted, time: .shortened))")
                            .rollCallText(.helperText)
                    }

                    Spacer(minLength: RollCallSpacingTier.standard.value)

                    ReadinessRefreshButton(action: onRefresh)
                }

                Text(summaryDetail)
                    .rollCallText(.helperText)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 118), spacing: RollCallSpacingTier.tight.value)],
                    alignment: .leading,
                    spacing: RollCallSpacingTier.tight.value
                ) {
                    StatusChip(text: "\(readyCount) ready", role: .ready, systemImage: "checkmark.circle", emphasis: .subdued)
                    if needsAudioCount > 0 {
                        StatusChip(text: "\(needsAudioCount) need audio", role: .warning, systemImage: "music.note", emphasis: .subdued)
                    }
                    if enhancedCount > 0 {
                        StatusChip(text: "\(enhancedCount) enhanced", role: .live, systemImage: "mic.fill", emphasis: .subdued)
                    }
                    if issueCount > 0 {
                        StatusChip(text: "\(issueCount) need repair", role: .destructive, systemImage: "wrench.and.screwdriver", emphasis: .subdued)
                    }
                }

                Button(action: onOpenGameDay) {
                    Label("Open Game Day", systemImage: "play.rectangle.fill")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.primary)
            }
        }
    }

    private var summaryTitle: String {
        if presentCount == 0 {
            return "Choose Today’s Lineup"
        }
        if issueCount > 0 {
            return "Some Audio Needs Repair"
        }
        if needsAudioCount > 0 {
            return "Some Players Need Audio"
        }
        return "Ready for Game Day"
    }

    private var summaryDetail: String {
        if presentCount == 0 {
            return "Mark players present before game day so Roll Call can focus on the lineup you will actually use."
        }
        if issueCount > 0 {
            return "A few assigned audio files need attention before they can be trusted live."
        }
        if needsAudioCount > 0 {
            return "Game Day can still use Small Cheer fallback, but these players need their own audio to feel ready."
        }
        return "Every present player has player-specific audio. Optional upgrades can add more delight, but they are not required."
    }

    private var summaryChipText: String {
        isReadyForGameDay ? "Ready" : "Help Available"
    }

    private var summaryRole: StatusChipRole {
        if issueCount > 0 {
            return .destructive
        }
        if needsAudioCount > 0 || presentCount == 0 {
            return .warning
        }
        return .ready
    }

    private var summaryIcon: String {
        if issueCount > 0 {
            return "wrench.and.screwdriver"
        }
        if needsAudioCount > 0 || presentCount == 0 {
            return "music.note"
        }
        return "checkmark.circle"
    }
}

private struct ReadinessPlayerAudioCard: View {
    let checks: [ReadinessCheck]
    let playerForCheck: (ReadinessCheck) -> Player?
    let onEditPlayer: (Player) -> Void

    var body: some View {
        ReadinessSectionCard(
            title: "Player Audio",
            helperText: "Ready means the player has their own playable audio. Fallback keeps Game Day safe, but it does not count as ready.",
            checks: checks,
            emptyText: "No present players to check yet.",
            playerForCheck: playerForCheck,
            onEditPlayer: onEditPlayer
        )
    }
}

private struct ReadinessEnhancementsCard: View {
    let checks: [ReadinessCheck]
    let playerAudioChecks: [ReadinessCheck]
    let playerForCheck: (ReadinessCheck) -> Player?
    let onEditPlayer: (Player) -> Void

    var body: some View {
        ReadinessSectionCard(
            title: "Announcements",
            helperText: "This list shows players who have songs selected but do not have announcements recorded yet.",
            checks: checks,
            emptyText: emptyText,
            playerForCheck: playerForCheck,
            onEditPlayer: onEditPlayer
        )
    }

    private var emptyText: String {
        let playersWithAudio = playerAudioChecks.filter { check in
            check.state == .ready || check.state == .enhanced
        }
        guard !playersWithAudio.isEmpty else {
            return "Add player audio first, then Roll Call can suggest announcement upgrades."
        }
        return "Every player with audio already has an Announcement Cue."
    }
}

private struct ReadinessOptionalUpgradesCard: View {
    let checks: [ReadinessCheck]
    let playerForCheck: (ReadinessCheck) -> Player?
    let onEditPlayer: (Player) -> Void

    var body: some View {
        ReadinessSectionCard(
            title: "Optional Polish",
            helperText: "Photos and presentation details can make the board cooler. They never make a player incomplete.",
            checks: checks,
            emptyText: "Optional polish looks good for today’s lineup.",
            playerForCheck: playerForCheck,
            onEditPlayer: onEditPlayer
        )
    }
}

private struct ReadinessGameDayChecksCard: View {
    let checks: [ReadinessCheck]
    let onRequestAppleMusicAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Before You Start")
                    .rollCallText(.sectionTitle)
                Text("Phone and setup checks are separate from player readiness.")
                    .rollCallText(.helperText)
            }
            .padding(.horizontal, 2)

            SectionCard(family: checks.contains(where: { $0.state == .issue }) ? .status : .utility) {
                VStack(spacing: 0) {
                    ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 42)
                        }
                        ReadinessGameDayCheckRow(
                            check: check,
                            onRequestAppleMusicAccess: onRequestAppleMusicAccess
                        )
                    }
                }
            }
        }
    }
}

private struct ReadinessGameDayCheckRow: View {
    let check: ReadinessCheck
    let onRequestAppleMusicAccess: () -> Void

    var body: some View {
        Group {
            if canRequestAppleMusicAccess {
                Button(action: onRequestAppleMusicAccess) {
                    content(showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Requests Apple Music access.")
            } else {
                content(showsChevron: false)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func content(showsChevron: Bool) -> some View {
        HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
            Image(systemName: status.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(status.color)
                .frame(width: 30, height: 30)
                .background(status.color.opacity(0.13))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: RollCallSpacingTier.tight.value) {
                    Text(check.title)
                        .rollCallText(.cardTitle)
                    Spacer(minLength: RollCallSpacingTier.tight.value)
                    StatusChip(
                        text: canRequestAppleMusicAccess ? status.actionLabel : status.label,
                        role: status.chipRole,
                        emphasis: .subdued
                    )
                }

                Text(detail)
                    .rollCallText(.helperText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, RollCallSpacingTier.tight.value)
    }

    private var status: GameDayCheckStatus {
        if check.state == .issue {
            return .needsAttention
        }

        switch check.id {
        case "route":
            return .checkManually
        case "network", "music-auth":
            return check.detail.hasPrefix("No Apple Music") ? .notNeeded : .looksGood
        default:
            return .looksGood
        }
    }

    private var detail: String {
        if check.state == .issue {
            switch check.id {
            case "route":
                return "Roll Call cannot identify the current output. Connect your speaker and play a quick test before starting."
            case "volume":
                return "Device volume is \(check.detail). Turn it up and test it on the speaker you will use."
            case "music-auth" where canRequestAppleMusicAccess:
                return "Apple Music cues need approval. Tap Grant Access to let Roll Call use Apple Music."
            case "music-auth":
                return "\(check.detail) Check iOS Settings if you need Apple Music cues today."
            default:
                return check.detail
            }
        }

        switch check.id {
        case "route":
            return "Detected: \(check.detail). This may be right or wrong; confirm the sound is coming from the speaker you want."
        case "volume":
            return "Device volume is \(check.detail). This looks usable, but confirm it is loud enough on the field."
        case "network" where check.detail.hasPrefix("No Apple Music"):
            return "No Apple Music cues are in today's lineup, so network access is not needed for those cues."
        case "music-auth" where check.detail.hasPrefix("No Apple Music"):
            return "No Apple Music cues are assigned, so Apple Music access is not needed right now."
        case "lineup":
            return "\(check.detail). This is the lineup Roll Call will use in Game Day."
        default:
            return check.detail
        }
    }

    private var canRequestAppleMusicAccess: Bool {
        check.id == "music-auth" && check.detail == "Music authorization has not been requested yet."
    }
}

private enum GameDayCheckStatus {
    case looksGood
    case checkManually
    case notNeeded
    case needsAttention

    var label: String {
        switch self {
        case .looksGood: return "Looks Good"
        case .checkManually: return "Check This"
        case .notNeeded: return "Not Needed"
        case .needsAttention: return "Needs Attention"
        }
    }

    var actionLabel: String {
        switch self {
        case .needsAttention: return "Grant Access"
        case .checkManually: return "Check This"
        case .notNeeded: return "Not Needed"
        case .looksGood: return "Looks Good"
        }
    }

    var chipRole: StatusChipRole {
        switch self {
        case .looksGood, .notNeeded: return .ready
        case .checkManually: return .warning
        case .needsAttention: return .destructive
        }
    }

    var systemImage: String {
        switch self {
        case .looksGood: return "checkmark.circle.fill"
        case .checkManually: return "questionmark.circle.fill"
        case .notNeeded: return "minus.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .looksGood, .notNeeded: return Color.rollCall(.ready)
        case .checkManually: return Color.rollCall(.warning)
        case .needsAttention: return Color.rollCall(.destructive)
        }
    }
}

private struct ReadinessSectionCard: View {
    let title: String
    let helperText: String
    let checks: [ReadinessCheck]
    let emptyText: String
    let playerForCheck: (ReadinessCheck) -> Player?
    let onEditPlayer: (Player) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .rollCallText(.sectionTitle)
                Text(helperText)
                    .rollCallText(.helperText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 2)

            SectionCard(family: cardFamily) {
                VStack(spacing: 0) {
                    if checks.isEmpty {
                        Text(emptyText)
                            .rollCallText(.helperText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 42)
                        }
                        if let player = playerForCheck(check) {
                            Button {
                                onEditPlayer(player)
                            } label: {
                                ReadinessCheckDisplayRow(check: check, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens this player’s setup.")
                        } else {
                            ReadinessCheckDisplayRow(check: check)
                        }
                    }
                }
            }
        }
    }

    private var cardFamily: RollCallCardFamily {
        if checks.contains(where: { $0.state == .issue || $0.state == .needsAudio }) {
            return .status
        }
        return .utility
    }
}

private struct ReadinessCheckDisplayRow: View {
    let check: ReadinessCheck
    var showsChevron = false

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

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, RollCallSpacingTier.tight.value)
        .contentShape(Rectangle())
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
                        Text("Ready for Game Day?")
                            .rollCallText(.sectionTitle)
                    }

                    Spacer(minLength: RollCallSpacingTier.standard.value)

                    ReadinessRefreshButton(action: onRefresh)
                }

                Text("Tap Refresh to check today’s lineup, player audio, optional upgrades, and before-start phone checks.")
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
        .accessibilityHint("Updates the readiness report.")
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
        case .enhanced: return "Enhanced"
        case .needsAudio: return "Needs Audio"
        case .optional: return "Optional"
        case .gameDayCheck: return "Check"
        case .issue: return "Issue"
        }
    }

    var statusChipRole: StatusChipRole {
        switch self {
        case .ready: return .ready
        case .enhanced: return .live
        case .needsAudio: return .warning
        case .optional, .gameDayCheck: return .neutral
        case .issue: return .destructive
        }
    }

    var statusChipIcon: String {
        switch self {
        case .ready: return "checkmark.circle"
        case .enhanced: return "star.circle"
        case .needsAudio: return "music.note"
        case .optional: return "circle"
        case .gameDayCheck: return "checklist"
        case .issue: return "exclamationmark.triangle"
        }
    }

    var semanticColor: Color {
        switch self {
        case .ready: return Color.rollCall(.ready)
        case .enhanced: return Color.rollCall(.live)
        case .needsAudio: return Color.rollCall(.warning)
        case .optional, .gameDayCheck: return Color(uiColor: .secondaryLabel)
        case .issue: return Color.rollCall(.destructive)
        }
    }

    var cardFamily: RollCallCardFamily {
        switch self {
        case .ready, .enhanced, .optional, .gameDayCheck:
            return .utility
        case .needsAudio, .issue:
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

private struct AttributionsView: View {
    private let generalClips = [
        "Small Cheer",
        "Victory Roar",
        "Stadium Burst",
        "Rhythmic Clap",
        "Whistle Pop",
        "Crowd Laugh"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                SettingsSectionGroup(title: "Roll Call") {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        Text("Copyright 2026 John Kenneth Fisher")
                            .rollCallText(.body)

                        Link(destination: URL(string: "https://github.com/JohnKFisher/roll-call")!) {
                            SettingsRowLabel(
                                title: "Public GitHub Project",
                                detail: "github.com/JohnKFisher/roll-call",
                                systemImage: "link"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSectionGroup(
                    title: "Bundled General Clips",
                    helperText: "Roll Call includes crowd and applause sound effects from Mixkit."
                ) {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        SettingsRowLabel(
                            title: "Mixkit Sound Effects",
                            detail: "Licensed under the Mixkit Sound Effects Free License. The reviewed Mixkit pages say attribution is not required, but Roll Call credits Mixkit here.",
                            systemImage: "waveform"
                        )

                        Text(generalClips.joined(separator: ", "))
                            .rollCallText(.helperText)

                        Link(destination: URL(string: "https://mixkit.co/free-sound-effects/")!) {
                            SettingsRowLabel(
                                title: "Mixkit Sound Effects Catalog",
                                detail: "Source catalog for the bundled clip set.",
                                systemImage: "link"
                            )
                        }
                        .buttonStyle(.plain)

                        Link(destination: URL(string: "https://mixkit.co/license/")!) {
                            SettingsRowLabel(
                                title: "Mixkit License",
                                detail: "License terms for Mixkit sound effects.",
                                systemImage: "doc.text.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSectionGroup(
                    title: "Third-Party Software",
                    helperText: "Roll Call uses ZIPFoundation to read and write .rollcall packages."
                ) {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        SettingsRowLabel(
                            title: "ZIPFoundation 0.9.20",
                            detail: "MIT License. Copyright Thomas Zoechling and contributors.",
                            systemImage: "shippingbox.fill"
                        )

                        Link(destination: URL(string: "https://github.com/weichsel/ZIPFoundation")!) {
                            SettingsRowLabel(
                                title: "ZIPFoundation Project",
                                detail: "github.com/weichsel/ZIPFoundation",
                                systemImage: "link"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSectionGroup(title: "Special Thanks") {
                    SettingsRowLabel(
                        title: "Piscataway Thunder Softball Team",
                        detail: "Special thanks to the girls of the Piscataway Thunder Softball Team.",
                        systemImage: "heart.fill"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, RollCallSpacingTier.tight.value)
            .padding(.bottom, RollCallSpacingTier.large.value)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Attributions")
        .navigationBarTitleDisplayMode(.inline)
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
    var body: some View {
        LiveSurfaceBackground()
    }
}

private enum LiveSurfaceStyle {
    static let backgroundAccentTint = Color.rollCall(.accent, surface: .live)
}

private struct LiveSurfaceBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var accentTint: Color = LiveSurfaceStyle.backgroundAccentTint

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.08),
                    Color(red: 0.08, green: 0.10, blue: 0.12),
                    accentTint.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.12),
                    Color(red: 0.12, green: 0.13, blue: 0.14),
                    accentTint.opacity(0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct GameDayBoard: View {
    @ObservedObject var appModel: AppModel
    let onLineup: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let team = appModel.selectedTeam {
                    GameDayTeamStack(appModel: appModel, team: team, onLineup: onLineup)
                } else {
                    GameDayNoTeamStack()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
    }
}

private struct GameDayTeamStack: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var playbackEngine: CuePlaybackEngine
    let team: Team
    let onLineup: () -> Void

    init(appModel: AppModel, team: Team, onLineup: @escaping () -> Void) {
        self.appModel = appModel
        self.team = team
        self.onLineup = onLineup
        _playbackEngine = ObservedObject(initialValue: appModel.playbackEngine)
    }

    private var presentPlayers: [Player] {
        team.presentPlayersInBattingOrder
    }

    private var activePlayer: Player? {
        presentPlayers.first(where: isActive)
    }

    private var nowPlayer: Player? {
        activePlayer ?? team.nextBatter
    }

    private var onDeckPlayer: Player? {
        nextPlayer(after: nowPlayer)
    }

    private var liveWarning: GameDayLiveWarning? {
        if presentPlayers.isEmpty {
            return GameDayLiveWarning(text: "No present players in the lineup", role: .warning)
        }

        guard let readiness = appModel.state.lastReadiness else { return nil }
        let issues = readiness.checks.filter(isLiveReadinessIssue)
        guard let firstIssue = issues.first else { return nil }
        if issues.count == 1 {
            return GameDayLiveWarning(text: firstIssue.detail, role: role(for: firstIssue.state))
        }
        return GameDayLiveWarning(text: "\(issues.count) live warnings - \(firstIssue.title)", role: role(for: firstIssue.state))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameDayAnnouncerModePicker(
                selectedMode: team.session.gameDayAnnouncerMode,
                onSelect: appModel.setGameDayAnnouncerMode
            )

            if let liveWarning {
                GameDayWarningStrip(warning: liveWarning)
            }

            if let nowPlayer {
                GameDayNowBattingHero(
                    appModel: appModel,
                    player: nowPlayer,
                    isActive: isActive(nowPlayer),
                    announcerMode: team.session.gameDayAnnouncerMode
                )
            } else {
                GameDayEmptyHero(
                    title: "No Present Players",
                    detail: "Open the lineup and mark players present before game day."
                )
            }

            GameDayOnDeckCard(
                appModel: appModel,
                player: onDeckPlayer,
                announcerMode: team.session.gameDayAnnouncerMode
            )

            GameDayControlRow(
                appModel: appModel,
                onLineup: onLineup
            )

            GameDayGridDivider()

            GameDayPlayerGrid(
                appModel: appModel,
                players: presentPlayers,
                nowPlayerID: nowPlayer?.id,
                onDeckPlayerID: onDeckPlayer?.id,
                announcerMode: team.session.gameDayAnnouncerMode
            )
        }
    }

    private func isActive(_ player: Player) -> Bool {
        if let cueID = player.cue?.id {
            return playbackEngine.activeCueID == cueID
        }
        return playbackEngine.activeCueID == player.id
    }

    private func nextPlayer(after player: Player?) -> Player? {
        guard presentPlayers.count > 1 else { return nil }
        guard let player, let index = presentPlayers.firstIndex(where: { $0.id == player.id }) else {
            return presentPlayers.dropFirst().first
        }
        return presentPlayers[(index + 1) % presentPlayers.count]
    }

    private func isLiveReadinessIssue(_ check: ReadinessCheck) -> Bool {
        guard check.state == .issue else { return false }
        if check.id.contains("photo-upgrade") || check.id.contains("announcement-upgrade") { return false }
        if check.id.contains("custom-announcer-issue") {
            return team.session.gameDayAnnouncerMode.usesAnnouncer
        }
        if check.id.hasPrefix("player-") {
            return presentPlayers.contains { player in
                check.id.contains(player.id.uuidString)
            }
        }
        return ["route", "volume", "network", "music-auth", "lineup"].contains(check.id)
    }

    private func willUseFallback(for player: Player) -> Bool {
        switch team.session.gameDayAnnouncerMode {
        case .announcerOnly:
            return !appModel.hasStoredCustomAnnouncer(for: player)
        case .announcerAndSong, .songOnly:
            return player.cue == nil
        }
    }

    private func role(for state: ReadinessState) -> StatusChipRole {
        state == .issue ? .destructive : .warning
    }
}

private struct GameDayNoTeamStack: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameDayWarningStrip(warning: GameDayLiveWarning(text: "No team selected", role: .warning))
            GameDayEmptyHero(
                title: "No Team Selected",
                detail: "Choose or create a team before using live player cues."
            )
        }
    }
}

private struct GameDayLiveWarning {
    let text: String
    let role: StatusChipRole
}

private struct GameDayWarningStrip: View {
    let warning: GameDayLiveWarning

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: warning.role == .destructive ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
            Text(warning.text)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(warning.role == .destructive ? Color.rollCall(.destructive, surface: .live) : Color.rollCall(.warning, surface: .live))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.rollCall(.neutralStructure, surface: .live), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct GameDayNowBattingHero: View {
    @ObservedObject var appModel: AppModel
    let player: Player
    let isActive: Bool
    let announcerMode: GameDayAnnouncerMode

    private var cueTitle: String {
        switch announcerMode {
        case .announcerOnly:
            return hasCustomAnnouncer ? "Announcer Only" : "Fallback: Small Cheer"
        case .announcerAndSong, .songOnly:
            if let cue = player.cue {
                return cue.label
            }
            return "Fallback: Small Cheer"
        }
    }

    private var cueTitleShowsMusicIcon: Bool {
        announcerMode != .announcerOnly && player.cue != nil
    }

    private var hasCustomAnnouncer: Bool {
        appModel.hasStoredCustomAnnouncer(for: player)
    }

    private var willUseFallback: Bool {
        switch announcerMode {
        case .announcerOnly:
            return !hasCustomAnnouncer
        case .announcerAndSong, .songOnly:
            return player.cue == nil
        }
    }

    private var statusText: String {
        if isActive { return "Playing" }
        if willUseFallback { return "Fallback available" }
        return "Ready"
    }

    private var actionTitle: String {
        if isActive { return "Tap Again to Stop" }
        if willUseFallback { return "Play Fallback" }
        switch announcerMode {
        case .announcerOnly:
            return "Play Announcer"
        case .announcerAndSong:
            return hasCustomAnnouncer ? "Play Announcer + Song" : "Play Song"
        case .songOnly:
            return "Play Song"
        }
    }

    private var announcerSummary: String {
        switch announcerMode {
        case .announcerOnly:
            return hasCustomAnnouncer ? "Announcer Only" : "Announcement not recorded, Small Cheer fallback"
        case .announcerAndSong:
            if player.cue == nil {
                return hasCustomAnnouncer ? "Announcer + Small Cheer" : "Small Cheer fallback"
            }
            return hasCustomAnnouncer ? "Announcer + Song" : "Song only"
        case .songOnly:
            return player.cue == nil ? "Song not selected, Small Cheer fallback" : "Song only"
        }
    }

    var body: some View {
        Button {
            if isCurrentlyActive {
                appModel.stopPlayback()
            } else {
                Task { await appModel.play(player: player) }
            }
        } label: {
            heroContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 72, cornerRadius: 18)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Now Batting")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.70))

                    Text(player.displayName)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .allowsTightening(true)

                    HStack(spacing: 8) {
                        if !player.uniformNumber.isEmpty {
                            Text("#\(player.uniformNumber)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.rollCall(.accent, surface: .live))
                        }
                        GameDayStatePill(
                            text: statusText,
                            systemImage: isActive ? "speaker.wave.3.fill" : (willUseFallback ? "music.note.list" : "checkmark.circle.fill"),
                            role: isActive ? .live : (willUseFallback ? .warning : .ready),
                            strong: isActive,
                            animatesSymbol: isActive
                        )
                    }
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    if cueTitleShowsMusicIcon {
                        Image(systemName: "music.note")
                    }
                    Text(cueTitle)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                Text(announcerSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                Image(systemName: isActive ? "stop.fill" : "play.fill")
                Text(actionTitle)
                    .font(.headline.weight(.bold))
                Spacer(minLength: 0)
                if isActive {
                    Text("Playing")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isActive ? Color.rollCall(.live, surface: .live) : Color.white.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? Color.white.opacity(0.50) : Color.rollCall(.neutralStructure, surface: .live), lineWidth: 1)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isActive ? Color.rollCall(.live, surface: .live).opacity(0.24) : Color.white.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isActive ? Color.rollCall(.live, surface: .live).opacity(0.95) : Color.rollCall(.neutralStructure, surface: .live), lineWidth: isActive ? 2 : 1)
        )
        .shadow(color: isActive ? Color.rollCall(.live, surface: .live).opacity(0.20) : .clear, radius: 14, y: 8)
        .accessibilityElement(children: .combine)
    }

    private var accessibilityLabel: String {
        "Now Batting, \(player.displayName), \(statusText), \(cueTitle), \(isActive ? "tap again to stop" : actionTitle)"
    }

    private var isCurrentlyActive: Bool {
        if let cueID = player.cue?.id {
            return appModel.playbackEngine.activeCueID == cueID
        }
        return appModel.playbackEngine.activeCueID == player.id
    }
}

private struct GameDayOnDeckCard: View {
    @ObservedObject var appModel: AppModel
    let player: Player?
    let announcerMode: GameDayAnnouncerMode

    var body: some View {
        Group {
            if player != nil {
                Button {
                    appModel.advanceNextBatter()
                } label: {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityHint("Moves this player to Now Batting.")
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            if let player {
                playerContent(for: player)
            } else {
                emptyContent
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.rollCall(.neutralStructure, surface: .live), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func playerContent(for player: Player) -> some View {
        Group {
            PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 42, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 4) {
                Text("On Deck")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.62))
                Text(player.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(onDeckStatus(for: player))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.70))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !player.uniformNumber.isEmpty {
                Text("#\(player.uniformNumber)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.rollCall(.accent, surface: .live))
            }
        }
    }

    private var emptyContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text("On Deck")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.62))
                Text("No on deck player")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("Mark another player present to show who is next.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.70))
            }
            Spacer(minLength: 0)
        }
    }

    private func onDeckStatus(for player: Player) -> String {
        let hasCustomAnnouncer = appModel.hasStoredCustomAnnouncer(for: player)
        switch announcerMode {
        case .announcerOnly:
            return hasCustomAnnouncer ? "Announcer Only" : "Small Cheer fallback"
        case .announcerAndSong:
            if player.cue == nil {
                return hasCustomAnnouncer ? "Announcer + Small Cheer" : "Small Cheer fallback"
            }
            return hasCustomAnnouncer ? "Announcer + Song" : "Song ready"
        case .songOnly:
            return player.cue == nil ? "Small Cheer fallback" : "Song ready"
        }
    }
}

private struct GameDayAnnouncerModePicker: View {
    let selectedMode: GameDayAnnouncerMode
    let onSelect: (GameDayAnnouncerMode) -> Void

    var body: some View {
        Picker("Announcer Mode", selection: Binding(
            get: { selectedMode },
            set: { mode in onSelect(mode) }
        )) {
            ForEach(GameDayAnnouncerMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .environment(\.colorScheme, .dark)
    }
}

private struct GameDayControlRow: View {
    @ObservedObject var appModel: AppModel
    let onLineup: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                appModel.goToPreviousBatter()
            } label: {
                Label("Prev", systemImage: "chevron.left")
            }
            .rollCallButtonStyle(.secondary, surface: .live)

            Button {
                onLineup()
            } label: {
                Label("Edit Lineup", systemImage: "list.number")
            }
            .rollCallButtonStyle(.secondary, surface: .live)

            Button {
                appModel.advanceNextBatter()
            } label: {
                HStack(spacing: 5) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
            }
            .rollCallButtonStyle(.secondary, surface: .live)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct GameDayGridDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

private struct GameDayEmptyHero: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Now Batting")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.64))
            Text(title)
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(detail)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.rollCall(.neutralStructure, surface: .live), lineWidth: 1)
        )
    }
}

private struct GameDayStatePill: View {
    let text: String
    let systemImage: String
    let role: StatusChipRole
    let strong: Bool
    var animatesSymbol: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if animatesSymbol {
                PlayingSpeakerSymbol(systemImage: systemImage)
            } else {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.bold))
        .lineLimit(1)
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(background, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(color.opacity(strong ? 0 : 0.45), lineWidth: 1)
        )
    }

    private var foreground: Color {
        strong ? .white : color
    }

    private var background: Color {
        strong ? color : color.opacity(0.16)
    }

    private var color: Color {
        switch role {
        case .live:
            return Color.rollCall(.live, surface: .live)
        case .ready:
            return Color.rollCall(.ready, surface: .live)
        case .warning:
            return Color.rollCall(.warning, surface: .live)
        case .destructive:
            return Color.rollCall(.destructive, surface: .live)
        case .disabled:
            return Color.rollCall(.disabled, surface: .live)
        case .neutral:
            return Color.white.opacity(0.62)
        }
    }
}

private struct GameDayPlayerGrid: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var playbackEngine: CuePlaybackEngine
    let players: [Player]
    let nowPlayerID: UUID?
    let onDeckPlayerID: UUID?
    let announcerMode: GameDayAnnouncerMode

    init(
        appModel: AppModel,
        players: [Player],
        nowPlayerID: UUID?,
        onDeckPlayerID: UUID?,
        announcerMode: GameDayAnnouncerMode
    ) {
        self.appModel = appModel
        self.players = players
        self.nowPlayerID = nowPlayerID
        self.onDeckPlayerID = onDeckPlayerID
        self.announcerMode = announcerMode
        _playbackEngine = ObservedObject(initialValue: appModel.playbackEngine)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(players) { player in
                let isActive = isActive(player)
                let tileState = tileState(for: player, isActive: isActive)
                Button {
                    if isCurrentlyActive(player) {
                        appModel.stopPlayback()
                    } else {
                        Task { await appModel.play(player: player) }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .center, spacing: 4) {
                            Text(player.uniformNumber.isEmpty ? "--" : "#\(player.uniformNumber)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.white.opacity(0.62))
                            Spacer(minLength: 0)
                            if let tileState {
                                if tileState.animatesSymbol {
                                    PlayingSpeakerSymbol(systemImage: tileState.systemImage, color: tileState.color)
                                        .font(.caption.weight(.bold))
                                } else {
                                    Image(systemName: tileState.systemImage)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(tileState.color)
                                }
                            }
                        }

                        Text(tileName(for: player))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.74)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let tileState {
                            Text(tileState.text)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(tileState.color)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                        } else if let footerText = tileFooterText(for: player) {
                            Text(footerText)
                                .font(.caption2.weight(.semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(Color.white.opacity(0.50))
                                .lineLimit(2)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(tileBackground(isActive: isActive))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(tileBorder(isActive: isActive), lineWidth: isActive ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.16), value: isActive)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tileAccessibilityLabel(for: player, tileState: tileState))
                .accessibilityValue(tileAccessibilityValue(for: player, isActive: isActive))
                .accessibilityHint(tileAccessibilityHint(for: player, isActive: isActive))
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    private func isActive(_ player: Player) -> Bool {
        if let cueID = player.cue?.id {
            return playbackEngine.activeCueID == cueID
        }
        return playbackEngine.activeCueID == player.id
    }

    private func isCurrentlyActive(_ player: Player) -> Bool {
        if let cueID = player.cue?.id {
            return appModel.playbackEngine.activeCueID == cueID
        }
        return appModel.playbackEngine.activeCueID == player.id
    }

    private func tileName(for player: Player) -> String {
        let parts = normalizedPlayerNameParts(player.displayName)
        let first = parts.first.isEmpty ? player.displayName : parts.first
        let duplicateFirstNames = players.filter {
            normalizedPlayerNameParts($0.displayName).first.localizedCaseInsensitiveCompare(first) == .orderedSame
        }.count > 1

        if duplicateFirstNames, !parts.remainder.isEmpty {
            return player.displayName
        }
        return first
    }

    private func tileState(for player: Player, isActive: Bool) -> GameDayTileState? {
        if isActive {
            return GameDayTileState(text: "Playing", systemImage: "speaker.wave.3.fill", color: Color.rollCall(.live, surface: .live), animatesSymbol: true)
        }
        if player.id == onDeckPlayerID {
            return GameDayTileState(text: "On Deck", systemImage: "person.crop.circle.badge.clock", color: Color.rollCall(.accent, surface: .live))
        }
        if player.id == nowPlayerID {
            return GameDayTileState(text: "Now Batting", systemImage: "figure.baseball", color: Color.rollCall(.ready, surface: .live))
        }
        return nil
    }

    private func tileFooterText(for player: Player) -> String? {
        switch announcerMode {
        case .announcerOnly:
            return appModel.hasStoredCustomAnnouncer(for: player) ? "Announcer" : nil
        case .announcerAndSong:
            if player.cue == nil { return nil }
            return appModel.hasStoredCustomAnnouncer(for: player) ? "Announcer + Song" : "Song"
        case .songOnly:
            return player.cue == nil ? nil : "Song"
        }
    }

    private func willUseFallback(for player: Player) -> Bool {
        switch announcerMode {
        case .announcerOnly:
            return !appModel.hasStoredCustomAnnouncer(for: player)
        case .announcerAndSong, .songOnly:
            return player.cue == nil
        }
    }

    private func tileAccessibilityLabel(for player: Player, tileState: GameDayTileState?) -> String {
        var parts: [String] = []
        if !player.uniformNumber.isEmpty {
            parts.append("Number \(player.uniformNumber)")
        }
        parts.append(player.displayName)
        if let tileState {
            parts.append(tileState.text)
        }
        return parts.joined(separator: ", ")
    }

    private func tileAccessibilityValue(for player: Player, isActive: Bool) -> String {
        if isActive {
            return "Currently playing"
        }
        if willUseFallback(for: player) {
            return "Will play fallback clip"
        }

        switch announcerMode {
        case .announcerOnly:
            return "Will play announcement cue"
        case .announcerAndSong:
            return appModel.hasStoredCustomAnnouncer(for: player) ? "Will play announcement cue and song" : "Will play song"
        case .songOnly:
            return "Will play song"
        }
    }

    private func tileAccessibilityHint(for player: Player, isActive: Bool) -> String {
        if isActive {
            return "Stops the active cue."
        }
        if willUseFallback(for: player) {
            return "Plays the default fallback crowd clip."
        }
        return "Plays this player's cue."
    }

    private func tileBackground(isActive: Bool) -> Color {
        isActive ? Color.rollCall(.live, surface: .live).opacity(0.22) : Color.white.opacity(0.07)
    }

    private func tileBorder(isActive: Bool) -> Color {
        isActive ? Color.rollCall(.live, surface: .live).opacity(0.95) : Color.rollCall(.neutralStructure, surface: .live)
    }
}

private struct GameDayTileState {
    let text: String
    let systemImage: String
    let color: Color
    var animatesSymbol: Bool = false
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
                Text("Create a manual backup before risky edits. Automatic backups are also created before package imports and backup restores, and only the newest 10 are kept.")
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
    @State private var showTeamPlaylistWarning = false

    private var flags: FeatureFlags {
        appModel.featureFlags
    }

    var body: some View {
        Group {
            if flags.isReleaseBuild {
                ContentUnavailableView(
                    "Developer Tools Unavailable",
                    systemImage: "lock.fill",
                    description: Text("Release builds do not expose developer settings or experimental features.")
                )
            } else {
                List {
                    Section("Build Environment") {
                        LabeledContent("Environment", value: flags.environment.rawValue)
                        LabeledContent("App Version", value: "\(AppMetadata.appVersion) (\(AppMetadata.buildNumber))")
                    }

                    Section("Environment Gates") {
                        FlagStatusRow(
                            title: "Developer Settings",
                            detail: "Shows this internal settings surface outside production releases.",
                            isEnabled: flags.showDeveloperSettings
                        )
                        FlagStatusRow(
                            title: "Experimental Features",
                            detail: "Allows unfinished or provisional tools to appear for trusted testing.",
                            isEnabled: flags.showExperimentalFeatures
                        )
                        FlagStatusRow(
                            title: "Premium Testing Unlock",
                            detail: "Reserved for purchase-related testing. Roll Call does not currently sell premium features.",
                            isEnabled: flags.unlockPremiumForTesting
                        )
                    }

                    Section("Runtime Testing Flags") {
                        Toggle(isOn: Binding(
                            get: { appModel.state.experimental.showExperimentalFeatures },
                            set: { appModel.setShowExperimentalFeatures($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Show Experimental Features",
                                detail: flags.isDebugBuild ? "Debug builds force experimental visibility on; this stored value mainly affects Internal builds." : "Internal builds only show experiments when this is enabled.",
                                systemImage: "testtube.2"
                            )
                        }
                        .disabled(flags.isDebugBuild)

                        Toggle(isOn: Binding(
                            get: { appModel.state.experimental.unlockPremiumForTesting },
                            set: { appModel.setUnlockPremiumForTesting($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Unlock Premium for Testing",
                                detail: flags.isDebugBuild ? "Debug builds force this on for future purchase testing." : "Allows trusted internal testers to exercise future premium-only paths.",
                                systemImage: "key.fill"
                            )
                        }
                        .disabled(flags.isDebugBuild)

                        Toggle(isOn: Binding(
                            get: { appModel.state.experimental.appleMusicLocalCopyEnabled },
                            set: { isEnabled in
                                if isEnabled {
                                    showExperimentalWarning = true
                                } else {
                                    appModel.setAppleMusicLocalCopyEnabled(false)
                                }
                            }
                        )) {
                            SettingsRowLabel(
                                title: "Apple Music Local Copies",
                                detail: "Shows the Make Local Copy action for Apple Music cues. This remains experimental and outside the primary product path.",
                                systemImage: "doc.on.doc"
                            )
                        }
                        .disabled(!flags.showExperimentalFeatures)

                        Toggle(isOn: Binding(
                            get: { appModel.state.experimental.appleMusicTeamPlaylistSyncEnabled },
                            set: { appModel.setAppleMusicTeamPlaylistSyncEnabled($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Apple Music Team Playlist Sync",
                                detail: "Allows a selected team to update the exact-name Apple Music playlist Roll Call - <Team Name>.",
                                systemImage: "music.note.list"
                            )
                        }
                        .disabled(!flags.showExperimentalFeatures)
                    }

                    if flags.appleMusicTeamPlaylistSyncEnabled {
                        Section("Experimental Actions") {
                            Button {
                                if appModel.state.experimental.appleMusicTeamPlaylistAcknowledgedAt == nil {
                                    showTeamPlaylistWarning = true
                                } else {
                                    Task { await appModel.syncSelectedTeamAppleMusicPlaylist() }
                                }
                            } label: {
                                if appModel.isAppleMusicPlaylistSyncing {
                                    Label("Updating Apple Music Team Playlist", systemImage: "music.note.list")
                                } else {
                                    Label("Update Apple Music Team Playlist", systemImage: "music.note.list")
                                }
                            }
                            .disabled(appModel.isAppleMusicPlaylistSyncing || appModel.selectedTeam == nil)

                            Text("Creates or replaces \"Roll Call - <Team Name>\" in Apple Music using this team's Apple Music song cues only.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if appModel.isAppleMusicPlaylistSyncing {
                                HStack {
                                    ProgressView()
                                    Text("Updating Apple Music playlist...")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.footnote)
                            } else if let status = appModel.appleMusicPlaylistSyncStatus {
                                Text(status)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
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
            }
        }
        .navigationTitle("Developer Tools")
        .alert("Experimental Apple Music Playlist Sync", isPresented: $showTeamPlaylistWarning) {
            Button("Update Playlist") {
                appModel.acknowledgeExperimentalTeamPlaylistSync()
                Task { await appModel.syncSelectedTeamAppleMusicPlaylist() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Roll Call will create or update the exact-name Apple Music playlist for the selected team and replace that playlist's songs with the team's current Apple Music cues.")
        }
    }
}

private struct FlagStatusRow: View {
    let title: String
    let detail: String
    let isEnabled: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isEnabled ? .green : .secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
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
                .lineLimit(1)
                .foregroundStyle(Color.rollCall(.ready))
        } else {
            Label("Song not selected", systemImage: "music.note")
                .rollCallText(.helperText)
                .lineLimit(1)
                .foregroundStyle(Color.rollCall(.warning))
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
            } else if hasCustomIntro {
                Label("Announcement recorded", systemImage: "mic.fill")
                    .foregroundStyle(Color.rollCall(.ready))
            } else if !hasCustomIntro {
                Label("Announcement not recorded", systemImage: "mic.slash")
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
                Section {
                    setupSummaryView
                        .rollCallCard(.status)
                }
                .playerEditorListRow()

                Section {
                    let photoRelativePath = player.photoRelativePath
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Display Name", text: $player.displayName)
                                .rollCallText(.body)
                                .focused($focusedField, equals: .displayName)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .uniformNumber
                                }

                            Divider()

                            TextField("Uniform Number", text: $player.uniformNumber)
                                .rollCallText(.body)
                                .focused($focusedField, equals: .uniformNumber)
                                .submitLabel(.done)
                        }

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            VStack(spacing: 6) {
                                PlayerPhotoThumbnail(relativePath: photoRelativePath, size: 64, cornerRadius: 18)
                                Text(photoRelativePath == nil ? "Add Photo" : "Change")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.rollCall(.accent))
                            }
                            .frame(width: 78)
                        }
                    }
                    .rollCallCard(.identity)
                } header: {
                    PlayerEditorSectionHeader("Identity")
                }
                .playerEditorListRow()

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if let cue = player.cue {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 10) {
                                    PlayerEditorSectionIcon(systemImage: "music.note", role: .accent)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Selected Cue")
                                            .rollCallText(.cardTitle)
                                        selectedCueSummary(for: cue)
                                    }
                                }

                                Button {
                                    showAppleMusicPicker = true
                                } label: {
                                    Label("Change Song", systemImage: "music.note.list")
                                }
                                .rollCallButtonStyle(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 10) {
                                    PlayerEditorSectionIcon(systemImage: "music.note", role: .accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("No Song Cue")
                                            .rollCallText(.cardTitle)
                                        Text("Choose the song this player uses in Game Day.")
                                            .rollCallText(.helperText)
                                    }
                                }

                                Button {
                                    showAppleMusicPicker = true
                                } label: {
                                    Label("Choose Song", systemImage: "music.note")
                                        .frame(maxWidth: .infinity)
                                }
                                .rollCallButtonStyle(.primary)
                            }
                        }

                        DisclosureGroup("Other Audio Options") {
                            Button {
                                importPresented = true
                            } label: {
                                Label("Import Audio or Video", systemImage: "square.and.arrow.down")
                            }
                            .rollCallButtonStyle(.secondary)
                            .padding(.top, 6)

                            Text("Use a device-owned audio or video file when Apple Music is not the right source.")
                                .rollCallText(.helperText)
                                .padding(.top, 2)
                        }
                        .font(.subheadline.weight(.semibold))

                        if player.cue != nil {
                            Button {
                                pendingClearAction = .song
                            } label: {
                                Label("Clear Song", systemImage: "xmark.circle")
                            }
                            .rollCallButtonStyle(.quiet)
                            .foregroundStyle(Color.rollCall(.destructive))
                        }
                    }
                    .rollCallCard(.utility)
                } header: {
                    PlayerEditorSectionHeader("Song Cue")
                }
                .playerEditorListRow()

                if let cue = player.cue {
                    Section {
                        cueTrimSection(for: cue)
                            .rollCallCard(.utility)
                    } header: {
                        PlayerEditorSectionHeader("Fine Tune Clip")
                    }
                    .playerEditorListRow()
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 10) {
                            PlayerEditorSectionIcon(systemImage: "mic.fill", role: .live)
                            Text("Optional. In Game Day, this recording can play by itself in Announcer Only or before the player’s song in Announcer+Song.")
                                .rollCallText(.helperText)
                        }

                        if isCustomIntroMissing {
                            Label("Roll Call still has an Announcement Cue reference for this player, but the audio file is missing from app storage.", systemImage: "exclamationmark.triangle.fill")
                                .rollCallText(.helperText)
                                .foregroundStyle(Color.rollCall(.destructive))
                        }

                        if appModel.isRecordingCustomAnnouncer(for: player) {
                            Button {
                                let currentPlayer = player
                                Task {
                                    await appModel.stopRecordingCustomAnnouncer(for: currentPlayer)
                                    await MainActor.run { refreshPlayerFromModel() }
                                }
                            } label: {
                                Label("Stop Recording", systemImage: "stop.circle.fill")
                            }
                            .rollCallButtonStyle(.destructive)
                        } else {
                            Button {
                                let currentPlayer = player
                                Task {
                                    await appModel.startRecordingCustomAnnouncer(for: currentPlayer)
                                }
                            } label: {
                                Label(appModel.customAnnouncerButtonTitle(for: player), systemImage: "mic.fill")
                            }
                            .rollCallButtonStyle(.secondary)
                            .disabled(appModel.isCustomAnnouncerTransitioning(for: player))
                        }

                        if hasStoredCustomIntro {
                            Button {
                                appModel.previewCustomAnnouncer(for: player)
                            } label: {
                                Label("Preview Announcement Cue", systemImage: "play.fill")
                            }
                            .rollCallButtonStyle(.secondary)
                        }

                        if player.customAnnouncerRelativePath != nil {
                            Button {
                                pendingClearAction = .customAnnouncer
                            } label: {
                                Label("Clear Announcement Cue", systemImage: "xmark.circle")
                            }
                            .rollCallButtonStyle(.quiet)
                            .foregroundStyle(Color.rollCall(.destructive))
                        }
                    }
                    .rollCallCard(.utility)
                } header: {
                    PlayerEditorSectionHeader("Announcement Cue")
                }
                .playerEditorListRow()

                if let cue = player.cue,
                   appModel.featureFlags.appleMusicLocalCopyEnabled,
                   case .appleMusic = cue.source {
                    Section {
                        Button {
                            appModel.updatePlayer(player)
                            let currentPlayer = player
                            Task {
                                await appModel.makeLocalCopy(for: currentPlayer)
                                await MainActor.run { refreshPlayerFromModel() }
                            }
                        } label: {
                            Label("Make Local Copy", systemImage: "doc.on.doc")
                        }
                        .rollCallButtonStyle(.secondary)
                        .rollCallCard(.utility)
                    } header: {
                        PlayerEditorSectionHeader("Experimental")
                    }
                    .playerEditorListRow()
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
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
                    let previousCueID = currentPlayer.cue?.id
                    Task {
                        await appModel.importMedia(from: url, for: currentPlayer)
                        await MainActor.run { refreshPlayerFromModel(enableStartTrimForCueReplacing: previousCueID) }
                    }
                }
            }
            .sheet(isPresented: $showAppleMusicPicker) {
                AppleMusicPickerSheet(appModel: appModel) { result in
                    let currentPlayer = player
                    let previousCueID = currentPlayer.cue?.id
                    Task {
                        let didAssign = await appModel.assignAppleMusic(result, to: currentPlayer)
                        guard didAssign else { return }
                        await MainActor.run {
                            refreshPlayerFromModel(enableStartTrimForCueReplacing: previousCueID)
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

    private var setupSummary: (status: String, nextStep: String?, role: StatusChipRole, systemImage: String) {
        if player.cue == nil {
            return ("Song cue needed", "Next need: song cue", .warning, "music.note")
        }

        if player.customAnnouncerRelativePath != nil && !appModel.hasStoredCustomAnnouncer(for: player) {
            return ("Song cue set", "Next need: valid Announcement Cue", .warning, "exclamationmark.triangle")
        }

        if appModel.hasStoredCustomAnnouncer(for: player) {
            return ("Song and Announcement Cue set", nil, .ready, "checkmark.circle")
        }

        return ("Song cue set", nil, .ready, "checkmark.circle")
    }

    @ViewBuilder
    private var setupSummaryView: some View {
        let summary = setupSummary

        if summary.nextStep == nil {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.rollCall(.ready))
                    .accessibilityHidden(true)

                Text("Ready")
                    .rollCallText(.cardTitle)

                StatusChip(
                    text: summary.status,
                    role: summary.role,
                    systemImage: summary.systemImage,
                    emphasis: .subdued
                )

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .top, spacing: 10) {
                PlayerEditorSectionIcon(systemImage: "checklist", role: .ready)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Setup Summary")
                        .rollCallText(.cardTitle)
                    StatusChip(
                        text: summary.status,
                        role: summary.role,
                        systemImage: summary.systemImage,
                        emphasis: .subdued
                    )
                    if let nextStep = summary.nextStep {
                        Text(nextStep)
                            .rollCallText(.helperText)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func selectedCueSummary(for cue: Cue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch cue.source {
            case .appleMusic(let source):
                Text(source.title)
                    .rollCallText(.body)
                Text(source.artistName)
                    .rollCallText(.helperText)
            case .localAudio(let source):
                Text(source.displayName.songTitleWithoutArtistPrefix)
                    .rollCallText(.body)
            case .builtInClip(let source):
                Text(source.displayName)
                    .rollCallText(.body)
            }
            cueSourceChip(for: cue)
        }
    }

    private func cueSourceChip(for cue: Cue) -> StatusChip {
        switch cue.source {
        case .appleMusic:
            return StatusChip(text: "Apple Music", role: .neutral, systemImage: "music.note", emphasis: .subdued)
        case .localAudio:
            return StatusChip(text: "Imported audio", role: .neutral, systemImage: "folder", emphasis: .subdued)
        case .builtInClip:
            return StatusChip(text: "Built-in clip", role: .neutral, systemImage: "speaker.wave.2", emphasis: .subdued)
        }
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

    private func refreshPlayerFromModel(enableStartTrimForCueReplacing previousCueID: UUID?) {
        player = appModel.selectedTeam?.players.first(where: { $0.id == player.id }) ?? player
        isStartTrimEditingEnabled = player.cue?.id != nil && player.cue?.id != previousCueID
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
        VStack(alignment: .leading, spacing: 12) {
            if let trimHelpText = appModel.appleMusicTrimHelpText(for: cue) {
                Text(trimHelpText)
                    .rollCallText(.helperText)
                HStack(spacing: 8) {
                    ForEach(TrimSuggestionMode.allCases) { mode in
                        Button(mode.title) {
                            trimMode = mode
                            applyTrimSuggestion(mode: mode)
                        }
                        .buttonStyle(PlayerEditorChipButtonStyle(isSelected: trimMode == mode))
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
            }
            .rollCallButtonStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start")
                        .rollCallText(.cardTitle)
                    Spacer()
                    Button(isStartTrimEditingEnabled ? "Done" : "Enable") {
                        isStartTrimEditingEnabled.toggle()
                    }
                    .rollCallButtonStyle(.quiet)
                    Text(secondsText(cue.startTime))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
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
                        .rollCallText(.cardTitle)
                    Spacer()
                    Text(secondsText(cue.duration))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                FlowChipRow(options: lengthOptions, selected: cue.duration) { option in
                    updateCueDuration(option)
                    appModel.rememberPreferredLength(option)
                }
            }

            Button {
                showAdvancedTrim = true
            } label: {
                Label("Advanced", systemImage: "slider.horizontal.3")
            }
            .rollCallButtonStyle(.secondary)
        }
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

private struct PlayerEditorSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .rollCallText(.chipLabel)
            .textCase(.uppercase)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}

private struct PlayerEditorSectionIcon: View {
    let systemImage: String
    let role: RollCallColorRole

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.rollCall(role))
            .frame(width: 30, height: 30)
            .background(Color.rollCall(role).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct PlayerEditorChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : Color(uiColor: .label))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(background(isPressed: configuration.isPressed))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.rollCall(.accent).opacity(isSelected ? 0 : 0.35), lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private func background(isPressed: Bool) -> Color {
        let base = isSelected ? Color.rollCall(.accent) : Color.rollCall(.neutralSurface)
        return isPressed ? base.opacity(0.78) : base
    }
}

private extension View {
    func playerEditorListRow() -> some View {
        listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 7, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
                return "Clear Announcement Cue"
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
            .accessibilityLabel("Preview \(title)")
            .accessibilityHint("Plays a short preview without selecting this song.")
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
                    .fill(Color.rollCall(.accent).opacity(0.82))
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
                    .fill(Color.rollCall(.accent))
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
                .buttonStyle(PlayerEditorChipButtonStyle(isSelected: abs(selected - option) < 0.01))
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
