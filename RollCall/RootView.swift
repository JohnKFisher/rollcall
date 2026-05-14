import Foundation
import PhotosUI
import SwiftUI
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
    @State private var requestedTabAfterConfirmation: RootTab?
    @State private var showProtectedModeExitAlert = false
    @State private var showLineupEditor = false
    @State private var showRenameTeamAlert = false
    @State private var renameTeamName = ""

    private var tabSelection: Binding<RootTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                guard appModel.state.settings.protectedModeEnabled,
                      selectedTab == .gameDay,
                      newValue != .gameDay else {
                    selectedTab = newValue
                    return
                }
                requestedTabAfterConfirmation = newValue
                showProtectedModeExitAlert = true
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { appModel.lastError != nil }, set: { newValue in if !newValue { appModel.lastError = nil } })
    }

    var body: some View {
        TabView(selection: tabSelection) {
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
        .alert("Leave Protected Game Day?", isPresented: $showProtectedModeExitAlert) {
            Button("Stay", role: .cancel) {
                requestedTabAfterConfirmation = nil
            }
            Button("Leave") {
                if let requestedTabAfterConfirmation {
                    selectedTab = requestedTabAfterConfirmation
                }
                self.requestedTabAfterConfirmation = nil
            }
        } message: {
            Text("Protected mode is active. Confirm before leaving Game Day.")
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
        .fileImporter(isPresented: $packageImportPresented, allowedContentTypes: [UTType(filenameExtension: "rollcall") ?? .data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await appModel.importPackage(from: url) }
            }
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
                    Section("Quick Add") {
                        PlayerQuickAddView(appModel: appModel)
                    }

                    Section("Roster") {
                        ForEach(playersTabRoster(for: team)) { player in
                            Button {
                                selectedPlayer = player
                            } label: {
                                HStack {
                                    PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 52)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(player.displayName)
                                            .font(.headline)
                                        Text(player.uniformNumber.isEmpty ? "No number" : "#\(player.uniformNumber)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let cue = player.cue {
                                        Text(cue.label)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.orange.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.orange)
                                    } else {
                                        Text("Add Cue")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(player.isPresent ? "Mark Out" : "Mark In") { appModel.togglePresent(player) }
                                    .tint(player.isPresent ? .red : .green)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("No Team Selected", systemImage: "person.3.sequence.fill", description: Text("Create or select a team on the Teams tab."))
                }
            }
            .navigationTitle(playersTabTitle)
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
                if appModel.selectedTeamBuiltInClips.isEmpty {
                    ContentUnavailableView("No Clips Ready", systemImage: "speaker.wave.2", description: Text("Select a team to use built-in safety sounds."))
                } else {
                    Section("Built-In Safety Sounds") {
                        ForEach(appModel.selectedTeamBuiltInClips) { clip in
                            Button {
                                Task { await appModel.play(builtInClip: clip) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(clip.title)
                                            .font(.headline)
                                        Text("Uses the same cue engine as player walk-up audio.")
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
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(team.name)
                                    .font(.title.bold())
                                Text(appModel.state.settings.protectedModeEnabled ? "Protected Game Day is on" : "Portrait-first game board")
                            }
                            Spacer()
                            Button(appModel.state.settings.protectedModeEnabled ? "Unlock" : "Protect") {
                                appModel.toggleProtectedMode()
                            }
                            .buttonStyle(.bordered)
                            Button("Panic Stop") { appModel.stopPlayback() }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                        }
                        .foregroundStyle(.primary)

                        if appModel.state.settings.protectedModeEnabled {
                            Label("Protected mode reduces accidental exits and edits during game play.", systemImage: "lock.shield.fill")
                                .font(.footnote)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        Picker("Announcer Mode", selection: Binding(
                            get: { team.session.gameDayAnnouncerMode },
                            set: { appModel.setGameDayAnnouncerMode($0) }
                        )) {
                            Text("No Announcer").tag(GameDayAnnouncerMode.noAnnouncer)
                            Text("Announcer").tag(GameDayAnnouncerMode.announcer)
                        }
                        .pickerStyle(.segmented)

                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                ForEach(appModel.selectedTeamPresentPlayers) { player in
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
                                            Text(player.cue?.label ?? "No Cue Yet")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 140)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .fill(appModel.playbackEngine.activeCueID == player.cue?.id ? Color.green.opacity(0.25) : Color.orange.opacity(0.10))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

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
                if !appModel.state.settings.protectedModeEnabled {
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
            List {
                if let readiness = appModel.state.lastReadiness {
                    Section("Updated \(readiness.generatedAt.formatted(date: .omitted, time: .shortened))") {
                        ForEach(readiness.checks) { check in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: iconName(for: check.state))
                                    .foregroundStyle(color(for: check.state))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(check.title).font(.headline)
                                    Text(check.detail).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Readiness")
            .toolbar {
                Button("Refresh") { appModel.refreshReadiness() }
            }
        }
    }

    private var teamsTab: some View {
        NavigationStack {
            List {
                Section("Create Team") {
                    TextField("Team name", text: $newTeamName)
                    Button("Create Team") {
                        appModel.addTeam(named: newTeamName)
                        newTeamName = ""
                    }
                    .disabled(newTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Teams") {
                    ForEach(appModel.state.teams) { team in
                        Button {
                            appModel.selectTeam(team)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(team.name).font(.headline)
                                    Text("\(team.players.count) players").foregroundStyle(.secondary)
                                }
                                Spacer()
                                if appModel.state.selectedTeamID == team.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
                if appModel.selectedTeam != nil {
                    Section("Selected Team") {
                        if let team = appModel.selectedTeam {
                            LabeledContent("Current") {
                                Text(team.name)
                            }
                        }
                        Menu("More") {
                            Button("Rename Selected Team") {
                                renameTeamName = appModel.selectedTeam?.name ?? ""
                                showRenameTeamAlert = true
                            }
                            Button("Duplicate Selected Team") { appModel.duplicateTeam() }
                            Button("Create Safety Snapshot") { appModel.snapshot(reason: "Manual snapshot") }
                            Button("Import Roster CSV") { csvImportPresented = true }
                        }
                    }
                }
            }
            .navigationTitle("Teams")
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            List {
                Section("Packages") {
                    Button("Export Selected Team") {
                        Task { await appModel.exportSelectedTeam() }
                    }
                    .disabled(appModel.selectedTeam == nil)
                    if let exportURL = appModel.exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share Latest .rollcall Package", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("Import .rollcall Package") { packageImportPresented = true }
                }

                Section("Game Day") {
                    Toggle("Protected Game Day Mode", isOn: Binding(
                        get: { appModel.state.settings.protectedModeEnabled },
                        set: { _ in appModel.toggleProtectedMode() }
                    ))
                    Toggle("Game Day Haptics", isOn: Binding(
                        get: { appModel.state.settings.hapticsEnabled },
                        set: { appModel.setHapticsEnabled($0) }
                    ))
                    Toggle("Reuse Prior Lineup on New Day", isOn: Binding(
                        get: { appModel.state.settings.reusePreviousLineupOnNewDay },
                        set: { appModel.setReusePreviousLineupOnNewDay($0) }
                    ))
                }

                if let team = appModel.selectedTeam {
                    TeamAnnouncerSettingsSection(appModel: appModel, team: team)
                }

                Section("Recovery") {
                    NavigationLink("Recovery Center") {
                        RecoveryCenterView(appModel: appModel)
                    }
                }

                Section("Developer") {
                    NavigationLink("Developer Tools") {
                        DeveloperToolsView(appModel: appModel, showExperimentalWarning: $showExperimentalWarning)
                    }
                }

                Section("About") {
                    Text("Roll Call \(AppMetadata.appVersion)")
                    Text("Copyright John Kenneth Fisher")
                    Link("GitHub: JohnKFisher/roll-call", destination: URL(string: "https://github.com/JohnKFisher/roll-call")!)
                }
            }
            .navigationTitle("Settings")
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

private struct LineupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    @State private var draggedPlayerID: UUID?

    var body: some View {
        NavigationStack {
            List {
                if let team = appModel.selectedTeam {
                    Section("Present Players") {
                        ForEach(team.battingOrderPlayers) { player in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 4)
                                    .onDrag {
                                        draggedPlayerID = player.id
                                        return NSItemProvider(object: player.id.uuidString as NSString)
                                    }
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
                            .opacity(draggedPlayerID == player.id ? 0.65 : 1)
                            .onDrop(
                                of: [UTType.text],
                                delegate: BattingOrderDropDelegate(
                                    targetPlayerID: player.id,
                                    draggedPlayerID: $draggedPlayerID,
                                    appModel: appModel
                                )
                            )
                        }
                    }

                    Section("Session") {
                        Button("Reset Today’s Lineup") { appModel.resetLineupForToday() }
                        Button("Start Fresh Session") { appModel.startFreshSession() }
                    }
                }
            }
            .navigationTitle("Today’s Lineup")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct BattingOrderDropDelegate: DropDelegate {
    let targetPlayerID: UUID
    @Binding var draggedPlayerID: UUID?
    let appModel: AppModel

    func dropEntered(info: DropInfo) {
        guard let draggedPlayerID, draggedPlayerID != targetPlayerID else { return }
        withAnimation {
            appModel.moveBattingOrderPlayer(draggedPlayerID, onto: targetPlayerID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPlayerID = nil
        return true
    }

    func dropExited(info: DropInfo) {}
}

private struct RecoveryCenterView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        List {
            Section("Recovery Actions") {
                Button("Create Safety Snapshot") {
                    appModel.snapshot(reason: "Manual snapshot from Recovery Center")
                }
            }

            Section("Snapshots") {
                if appModel.state.snapshots.isEmpty {
                    Text("No snapshots yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.state.snapshots) { snapshot in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(snapshot.reason)
                                .font(.headline)
                            Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Restore Snapshot") {
                                Task { await appModel.restoreSnapshot(snapshot) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Recovery Center")
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

private struct TeamAnnouncerSettingsSection: View {
    @ObservedObject var appModel: AppModel
    let team: Team
    @State private var draftProfile: TeamAnnouncerProfile
    @State private var includeAllVoices = false

    init(appModel: AppModel, team: Team) {
        self.appModel = appModel
        self.team = team
        _draftProfile = State(initialValue: team.announcerProfile)
    }

    var body: some View {
        Section("Built-in Voice") {
            Text("Applies to the selected team. Tokens: `<number>`, `<name>`, `<team>`.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Phrase Template", text: $draftProfile.phraseTemplate, axis: .vertical)
                .lineLimit(2...4)

            Toggle("Show All Languages", isOn: $includeAllVoices)

            Picker("Voice", selection: Binding(
                get: { draftProfile.requestedVoiceIdentifier ?? "automatic" },
                set: { newValue in
                    if newValue == "automatic" {
                        draftProfile.requestedVoiceIdentifier = nil
                    } else {
                        draftProfile.requestedVoiceIdentifier = newValue
                        if let option = appModel.announcerVoiceOptions(includeAllLanguages: true).first(where: { $0.id == newValue }) {
                            draftProfile.voiceLanguageCode = option.languageCode
                        }
                    }
                }
            )) {
                Text("Automatic Best Match").tag("automatic")
                ForEach(appModel.announcerVoiceOptions(includeAllLanguages: includeAllVoices)) { voice in
                    Text("\(voice.name) (\(voice.languageCode))").tag(voice.id)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Rate \(String(format: "%.2f", draftProfile.rate))")
                Slider(value: Binding(
                    get: { Double(draftProfile.rate) },
                    set: { draftProfile.rate = Float($0) }
                ), in: 0.35...0.6)

                Text("Pitch \(String(format: "%.2f", draftProfile.pitchMultiplier))")
                Slider(value: Binding(
                    get: { Double(draftProfile.pitchMultiplier) },
                    set: { draftProfile.pitchMultiplier = Float($0) }
                ), in: 0.8...1.2)

                Text("Volume \(String(format: "%.2f", draftProfile.volume))")
                Slider(value: Binding(
                    get: { Double(draftProfile.volume) },
                    set: { draftProfile.volume = Float($0) }
                ), in: 0.4...1.0)
            }

            Text(appModel.announcerPreviewText(for: team, profile: draftProfile))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Preview Built-in Voice") {
                Task { await appModel.previewBuiltInAnnouncer(profile: draftProfile) }
            }

            Button("Save Built-in Voice") {
                appModel.saveSelectedTeamAnnouncerProfile(draftProfile)
            }
            .buttonStyle(.borderedProminent)

            if let requested = draftProfile.requestedVoiceIdentifier,
               let resolved = team.announcerProfile.resolvedVoiceIdentifier,
               requested != resolved {
                Text("Current device fallback: the requested voice is unavailable, so Roll Call is using a different installed voice.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let regeneration = appModel.announcerRegenerationStatus,
               regeneration.teamID == team.id {
                Text(regeneration.progressText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: team.announcerProfile) { _, newValue in
            draftProfile = newValue
        }
    }
}

private struct PlayerQuickAddView: View {
    @ObservedObject var appModel: AppModel
    @State private var name = ""
    @State private var number = ""

    var body: some View {
        TextField("Player name", text: $name)
        TextField("Number", text: $number)
            .keyboardType(.numberPad)
        Button("Add Player") {
            appModel.addPlayer(name: name, number: number)
            name = ""
            number = ""
        }
        .buttonStyle(.borderedProminent)
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

private struct PlayerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    @State var player: Player
    @State private var importPresented = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showAppleMusicPicker = false
    @State private var trimMode: TrimSuggestionMode = .suggestedHook
    @State private var showAdvancedTrim = false
    @State private var liveScrubTask: Task<Void, Never>?
    @State private var pendingClearAction: PendingClearAction?

    private let lengthOptions: [Double] = [6, 8, 10, 12, 15]

    var body: some View {
        NavigationStack {
            Form {
                Section("Player") {
                    HStack {
                        Spacer()
                        PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 110, cornerRadius: 28)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    TextField("Display Name", text: $player.displayName)
                    TextField("Uniform Number", text: $player.uniformNumber)
                    TextField("Pronunciation Override", text: $player.pronunciationOverride)
                    Toggle("Present Today", isOn: $player.isPresent)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(player.photoRelativePath == nil ? "Choose Photo" : "Replace Photo", systemImage: "photo")
                    }
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

                    Button("Import Audio or Video") { importPresented = true }
                }

                Section("Custom Announcer") {
                    Text("Optional. Game Day announcer mode will use this recording first, then Built-in Voice if no custom intro is present.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if appModel.isRecordingCustomAnnouncer(for: player) {
                        Button("Stop Recording") {
                            appModel.updatePlayer(player)
                            let currentPlayer = player
                            Task {
                                await appModel.stopRecordingCustomAnnouncer(for: currentPlayer)
                                await MainActor.run { refreshPlayerFromModel() }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button(player.customAnnouncerRelativePath == nil ? "Record Custom Intro" : "Re-record Custom Intro") {
                            appModel.updatePlayer(player)
                            let currentPlayer = player
                            Task {
                                await appModel.startRecordingCustomAnnouncer(for: currentPlayer)
                            }
                        }
                    }

                    if player.customAnnouncerRelativePath != nil {
                        Button("Preview Custom Intro") {
                            appModel.previewCustomAnnouncer(for: player)
                        }
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
            .onDisappear {
                if appModel.isRecordingCustomAnnouncer(for: player) {
                    appModel.cancelRecordingCustomAnnouncer()
                }
            }
            .onChange(of: player.displayName) { _, _ in
                invalidateAnnouncerAsset()
            }
            .onChange(of: player.uniformNumber) { _, _ in
                invalidateAnnouncerAsset()
            }
            .onChange(of: player.pronunciationOverride) { _, _ in
                invalidateAnnouncerAsset()
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
                    appModel.assignAppleMusic(result, to: player)
                    refreshPlayerFromModel()
                    trimMode = .suggestedHook
                    applyTrimSuggestion(mode: .suggestedHook)
                    showAppleMusicPicker = false
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
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.8),
              let assetsDir = try? AppPaths.assetsDirectory()
        else { return }

        let fileName = "\(UUID().uuidString).jpg"
        do {
            try jpeg.write(to: assetsDir.appendingPathComponent(fileName), options: .atomic)
            player.photoRelativePath = fileName
        } catch {
            appModel.lastError = error.localizedDescription
        }
    }

    private func invalidateAnnouncerAsset() {
        player.generatedBuiltInAnnouncerRelativePath = nil
    }

    private func refreshPlayerFromModel() {
        player = appModel.selectedTeam?.players.first(where: { $0.id == player.id }) ?? player
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
        String(format: "%.2fs", value)
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
                    Text(secondsText(cue.startTime))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                StartScrubControl(
                    progress: cueTimeLimit <= 0 ? 0 : cue.startTime / cueTimeLimit,
                    displayRange: cueTimeLimit,
                    onSeek: { progress in
                        updateCueStart(progress: progress)
                    },
                    onLiveScrub: { progress in
                        updateCueStart(progress: progress)
                        scheduleLiveScrubPreview()
                    }
                )
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
                return "This will remove only the custom announcer recording for this player. Built-in Voice can still be used."
            }
        }
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
                            Text("No songs found. Try a different search.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(results) { result in
                                AppleMusicRow(
                                    title: result.title,
                                    artistName: result.artistName,
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
            return
        }

        isLoading = true
        hasSearched = false
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let fetched = try await appModel.musicCatalogService.search(term: trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = fetched
                    isLoading = false
                    hasSearched = true
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = []
                    isLoading = false
                    hasSearched = true
                    appModel.lastError = error.localizedDescription
                }
            }
        }
    }
}

private struct AppleMusicRow: View {
    let title: String
    let artistName: String
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
    let onSeek: (Double) -> Void
    let onLiveScrub: (Double) -> Void

    @GestureState private var isPressing = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 18)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.8))
                    .frame(width: max(14, width * progress), height: 18)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 28, height: 28)
                    .offset(x: max(0, min(width - 28, width * progress - 14)))
                    .shadow(radius: 2)
            }
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
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
                        cue.fadeOutDuration = min(max(0.1, cue.fadeOutDuration + delta), 2.0)
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
            Text(String(format: "%.2fs", value))
                .monospacedDigit()
                .frame(minWidth: 68)
            Button("+0.25") { apply(0.25) }
                .buttonStyle(.bordered)
        }
    }
}

private extension RecentAppleMusicSelection {
    var asSearchResult: MusicSearchResult {
        MusicSearchResult(songID: songID, title: title, artistName: artistName, duration: duration, previewURL: previewURL)
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

@MainActor
private final class PlayerPhotoCache {
    static let shared = PlayerPhotoCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(for relativePath: String) -> UIImage? {
        let key = relativePath as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = try? AppPaths.assetsDirectory().appendingPathComponent(relativePath),
              let image = UIImage(contentsOfFile: url.path)
        else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}
