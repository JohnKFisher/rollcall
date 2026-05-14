import AVFoundation
@preconcurrency import AVFAudio
import Combine
import Foundation
import UIKit

struct PendingRosterImport: Identifiable {
    let id = UUID()
    let sourceName: String
    let rows: [Player]
}

struct SupportBundleExport: Identifiable {
    let id = UUID()
    let url: URL
}

struct AnnouncerVoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let languageCode: String
    let qualityRank: Int
}

struct AnnouncerRegenerationStatus: Equatable {
    var teamID: UUID
    var phase: String
    var completed: Int
    var total: Int

    var progressText: String {
        total == 0 ? phase : "\(phase) (\(completed)/\(total))"
    }
}

fileprivate struct RenderedAnnouncerAudio {
    var data: Data
    var resolvedVoiceIdentifier: String?
    var voiceLanguageCode: String?
}

@MainActor
final class CustomAnnouncerRecorder {
    private var recorder: AVAudioRecorder?
    private var tempURL: URL?
    private(set) var recordingPlayerID: UUID?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func requestPermissionIfNeeded() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission(completionHandler: { granted in
                    continuation.resume(returning: granted)
                })
            }
        @unknown default:
            return false
        }
    }

    func startRecording(for playerID: UUID) async throws {
        guard await requestPermissionIfNeeded() else { throw AppError.microphonePermissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else { throw AppError.recordingUnavailable }

        self.recorder = recorder
        self.tempURL = url
        self.recordingPlayerID = playerID
    }

    func stopRecording() throws -> URL {
        guard let recorder, let tempURL else { throw AppError.recordingUnavailable }
        recorder.stop()
        self.recorder = nil
        self.tempURL = nil
        self.recordingPlayerID = nil
        return tempURL
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        tempURL = nil
        recordingPlayerID = nil
    }
}

@MainActor
final class GameDayHaptics {
    func success(isEnabled: Bool) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning(isEnabled: Bool) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var state: AppState
    @Published var isBusy = false
    @Published var lastError: String?
    @Published var exportURL: URL?
    @Published var pendingRosterImport: PendingRosterImport?
    @Published var supportBundle: SupportBundleExport?
    @Published var announcerRegenerationStatus: AnnouncerRegenerationStatus?
    @Published private(set) var appleMusicPlaybackCapability: AppleMusicPlaybackCapability = .unknown
    private var hasFinishedLaunching = false
    private var persistTask: Task<Void, Never>?
    private var readinessRefreshTask: Task<Void, Never>?
    private var prewarmTask: Task<Void, Never>?
    private var announcerRegenerationTask: Task<Void, Never>?

    let audioAssetService = AudioAssetService()
    let musicCatalogService = MusicCatalogService()
    let packageService = PackageService()
    let announcerRenderer = AnnouncerSpeechRenderer()
    let haptics = GameDayHaptics()
    let readinessService: ReadinessService
    let playbackEngine: CuePlaybackEngine
    let customAnnouncerRecorder = CustomAnnouncerRecorder()

    init() {
        self.playbackEngine = CuePlaybackEngine(audioAssetService: audioAssetService, musicCatalogService: musicCatalogService)
        self.readinessService = ReadinessService(audioAssetService: audioAssetService)
        self.state = (try? Self.load()) ?? {
            var state = AppState.empty
            state.deviceIdentity = DeviceIdentity(label: UIDevice.current.name)
            let team = Team.sample()
            state.teams = [team]
            state.selectedTeamID = team.id
            return state
        }()
        self.state.appVersion = AppMetadata.appVersion
        self.state.schemaVersion = max(self.state.schemaVersion, AppState.empty.schemaVersion)
        normalizeSelectedTeamIfNeeded()
        normalizeAllTeamsForToday()
        persist()
    }

    func finishLaunchingIfNeeded() async {
        guard !hasFinishedLaunching else { return }
        hasFinishedLaunching = true

        let audioAssetService = self.audioAssetService
        let assetError = await Task.detached(priority: .utility) { () -> String? in
            do {
                try audioAssetService.ensureBuiltInAssets()
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value

        if let assetError {
            lastError = assetError
            return
        }

        do {
            try configurePlaybackAudioSession()
            await refreshAppleMusicPlaybackCapability()
            refreshReadiness()
            persist()
        } catch {
            lastError = error.localizedDescription
        }
    }

    var selectedTeam: Team? {
        state.teams.first(where: { $0.id == state.selectedTeamID })
    }

    func selectTeam(_ team: Team) {
        state.selectedTeamID = team.id
        prepareSessionForToday()
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
    }

    func addTeam(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let team = Team(
            id: UUID(),
            name: trimmed,
            createdAt: .now,
            modifiedAt: .now,
            players: [],
            builtInClips: BuiltInClip.defaults,
            session: TeamSessionState(activeSessionDate: nil, battingOrder: [], nextBatterIndex: 0, gameDayAnnouncerMode: .noAnnouncer),
            announcerProfile: .default
        )
        state.teams.append(team)
        state.selectedTeamID = team.id
        prepareSessionForToday()
        persist()
    }

    func duplicateTeam() {
        guard var team = selectedTeam else { return }
        team.id = UUID()
        team.name += " Copy"
        team.players = team.players.map { player in
            var player = player
            player.id = UUID()
            if var cue = player.cue {
                cue.id = UUID()
                player.cue = cue
            }
            return player
        }
        team.session = TeamSessionState(activeSessionDate: nil, battingOrder: team.players.map(\.id), nextBatterIndex: 0, gameDayAnnouncerMode: team.session.gameDayAnnouncerMode)
        state.teams.append(team)
        state.selectedTeamID = team.id
        prepareSessionForToday()
        snapshot(reason: "Duplicate team")
        persist()
    }

    func renameSelectedTeam(to name: String) {
        guard let teamIndex else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.teams[teamIndex].name = trimmed
        state.teams[teamIndex].modifiedAt = .now
        persist()
    }

    func addPlayer(name: String, number: String) {
        guard let teamIndex = teamIndex else { return }
        let player = Player(id: UUID(), displayName: name, uniformNumber: number, pronunciationOverride: "", photoRelativePath: nil, cue: nil, isPresent: true)
        state.teams[teamIndex].players.append(player)
        state.teams[teamIndex].session.battingOrder.append(player.id)
        state.teams[teamIndex].modifiedAt = .now
        normalizeLineup(for: teamIndex)
        persist()
    }

    func updatePlayer(_ player: Player) {
        guard let teamIndex, let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == player.id }) else { return }
        state.teams[teamIndex].players[playerIndex] = player
        state.teams[teamIndex].modifiedAt = .now
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
    }

    func togglePresent(_ player: Player) {
        var updated = player
        updated.isPresent.toggle()
        updatePlayer(updated)
    }

    func setPresent(_ player: Player, isPresent: Bool) {
        guard player.isPresent != isPresent else { return }
        var updated = player
        updated.isPresent = isPresent
        updatePlayer(updated)
    }

    func movePlayers(from offsets: IndexSet, to offset: Int) {
        guard let teamIndex else { return }
        state.teams[teamIndex].players.move(fromOffsets: offsets, toOffset: offset)
        if !state.teams[teamIndex].session.battingOrder.elementsEqual(state.teams[teamIndex].players.map(\.id)) {
            state.teams[teamIndex].session.battingOrder = state.teams[teamIndex].players.map(\.id)
        }
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
    }

    func moveBattingOrder(from offsets: IndexSet, to offset: Int) {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.battingOrder.move(fromOffsets: offsets, toOffset: offset)
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
    }

    func moveBattingOrderPlayer(_ playerID: UUID, onto targetPlayerID: UUID) {
        guard let teamIndex else { return }

        var battingOrder = state.teams[teamIndex].session.battingOrder
        guard
            let sourceIndex = battingOrder.firstIndex(of: playerID),
            let targetIndex = battingOrder.firstIndex(of: targetPlayerID),
            sourceIndex != targetIndex
        else {
            return
        }

        let movedPlayerID = battingOrder.remove(at: sourceIndex)
        guard let updatedTargetIndex = battingOrder.firstIndex(of: targetPlayerID) else { return }
        let destinationIndex = sourceIndex < targetIndex ? updatedTargetIndex + 1 : updatedTargetIndex
        battingOrder.insert(movedPlayerID, at: destinationIndex)

        state.teams[teamIndex].session.battingOrder = battingOrder
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
    }

    func assignAppleMusic(_ result: MusicSearchResult, to player: Player) {
        var updated = player
        updated.cue = makeDefaultAppleMusicCue(for: result)
        rememberAppleMusicSelection(result)
        updatePlayer(updated)
    }

    func importMedia(from url: URL, for player: Player) async {
        await busy {
            let source = try await self.audioAssetService.importMedia(from: url)
            var updated = player
            updated.cue = .localDefault(source: source)
            self.updatePlayer(updated)
        }
    }

    func startRecordingCustomAnnouncer(for player: Player) async {
        do {
            try await customAnnouncerRecorder.startRecording(for: player.id)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopRecordingCustomAnnouncer(for player: Player) async {
        do {
            let tempURL = try customAnnouncerRecorder.stopRecording()
            let asset = try audioAssetService.storeCopiedAsset(
                from: tempURL,
                suggestedExtension: tempURL.pathExtension,
                displayName: "\(player.displayName)-custom-announcer",
                hiddenOriginNote: nil
            )
            try? FileManager.default.removeItem(at: tempURL)
            var updated = player
            updated.customAnnouncerRelativePath = asset.relativePath
            updatePlayer(updated)
            try configurePlaybackAudioSession()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cancelRecordingCustomAnnouncer() {
        customAnnouncerRecorder.cancelRecording()
        try? configurePlaybackAudioSession()
    }

    func previewCustomAnnouncer(for player: Player) {
        guard let relativePath = player.customAnnouncerRelativePath else { return }
        do {
            try playbackEngine.previewAsset(relativePath: relativePath)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearSong(for player: Player) {
        var updated = player
        updated.cue = nil
        updatePlayer(updated)
    }

    func clearCustomAnnouncer(for player: Player) {
        var updated = player
        updated.customAnnouncerRelativePath = nil
        updatePlayer(updated)
    }

    func makeLocalCopy(for player: Player) async {
        await busy {
            guard self.state.experimental.appleMusicLocalCopyEnabled else { throw AppError.featureDisabled }
            guard let cue = player.cue, case .appleMusic(let source) = cue.source, let previewURL = source.previewURL else { throw AppError.missingPreview }
            let local = try await self.audioAssetService.importRemotePreview(from: previewURL, displayName: "\(source.artistName) - \(source.title)", hiddenOrigin: HiddenOriginNote(importedAt: .now, originSummary: "appleMusicPreview:\(source.songID)"))
            var updated = player
            updated.cue = .localDefault(source: local)
            self.updatePlayer(updated)
        }
    }

    func play(player: Player) async {
        guard let cue = player.cue else { return }
        do {
            let announcerRelativePath = await resolveAnnouncerAssetRelativePath(for: player)
            try await playbackEngine.play(cue: cue, announcerRelativePath: announcerRelativePath)
            haptics.success(isEnabled: state.settings.hapticsEnabled)
        } catch {
            lastError = error.localizedDescription
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
        }
    }

    func play(builtInClip: BuiltInClip) async {
        do {
            try await playbackEngine.play(cue: builtInClip.cue)
            haptics.success(isEnabled: state.settings.hapticsEnabled)
        } catch {
            lastError = error.localizedDescription
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
        }
    }

    func stopPlayback() {
        playbackEngine.stop()
    }

    func previewCue(_ cue: Cue) async {
        do {
            try await playbackEngine.play(cue: cue)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func previewAppleMusicSearchResult(_ result: MusicSearchResult) async {
        let cue = makeDefaultAppleMusicCue(for: result)
        await previewCue(cue)
    }

    func refreshAppleMusicPlaybackCapability() async {
        let capability = await musicCatalogService.playbackCapability()
        appleMusicPlaybackCapability = capability
    }

    func previewBuiltInAnnouncer(profile: TeamAnnouncerProfile? = nil) async {
        do {
            guard let team = selectedTeam else { return }
            let previewPlayer = announcerPreviewPlayer(for: team)
            let audio = try await renderBuiltInAnnouncer(for: previewPlayer, teamName: team.name, profile: profile ?? team.announcerProfile)
            try playbackEngine.previewAudio(data: audio.data)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func advanceNextBatter() {
        guard let teamIndex else { return }
        prepareSessionForToday()
        let present = state.teams[teamIndex].presentPlayersInBattingOrder
        guard !present.isEmpty else {
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
            return
        }
        state.teams[teamIndex].session.nextBatterIndex = (state.teams[teamIndex].session.nextBatterIndex + 1) % present.count
        state.teams[teamIndex].modifiedAt = .now
        haptics.success(isEnabled: state.settings.hapticsEnabled)
        prewarmNextBatterCue()
        persist()
    }

    func resetLineupForToday() {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.activeSessionDate = .now
        state.teams[teamIndex].session.battingOrder = state.teams[teamIndex].players.map(\.id)
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
    }

    func startFreshSession() {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.activeSessionDate = .now
        state.teams[teamIndex].session.nextBatterIndex = 0
        if !state.settings.reusePreviousLineupOnNewDay {
            state.teams[teamIndex].players = state.teams[teamIndex].players.map { player in
                var player = player
                player.isPresent = true
                return player
            }
            state.teams[teamIndex].session.battingOrder = state.teams[teamIndex].players.map(\.id)
        }
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
    }

    func toggleProtectedMode() {
        state.settings.protectedModeEnabled.toggle()
        persist()
    }

    func setHapticsEnabled(_ isEnabled: Bool) {
        state.settings.hapticsEnabled = isEnabled
        persist()
    }

    func setReusePreviousLineupOnNewDay(_ isEnabled: Bool) {
        state.settings.reusePreviousLineupOnNewDay = isEnabled
        persist()
    }

    func setGameDayAnnouncerMode(_ mode: GameDayAnnouncerMode) {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.gameDayAnnouncerMode = mode
        state.teams[teamIndex].modifiedAt = .now
        scheduleReadinessRefresh()
        persist()
    }

    func saveSelectedTeamAnnouncerProfile(_ profile: TeamAnnouncerProfile) {
        guard let teamIndex else { return }
        state.teams[teamIndex].announcerProfile = profile
        state.teams[teamIndex].modifiedAt = .now
        persist()
        triggerAnnouncerRegeneration(for: state.teams[teamIndex].id, phase: "Generating built-in announcers")
    }

    func enableExperimentalCopies() {
        state.experimental.appleMusicLocalCopyEnabled = true
        state.experimental.acknowledgedAt = .now
        persist()
    }

    func exportSelectedTeam() async {
        await busy {
            guard let team = self.selectedTeam else { return }
            self.exportURL = try self.packageService.export(team: team, state: self.state)
        }
    }

    func importPackage(from url: URL) async {
        await busy {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            self.snapshot(reason: "Before package import")
            let manifest = try self.packageService.import(packageURL: url, audioAssetService: self.audioAssetService)
            var imported = manifest.team
            imported.id = UUID()
            imported.name += " Imported"
            self.state.teams.append(imported)
            self.state.selectedTeamID = imported.id
            self.persist()
            self.triggerAnnouncerRegeneration(for: imported.id, phase: "Regenerating imported built-in announcers")
        }
    }

    func prepareRosterImport(from url: URL) async {
        await busy {
            let rows = try await self.packageService.parseRosterCSV(from: url)
            self.pendingRosterImport = PendingRosterImport(
                sourceName: url.lastPathComponent,
                rows: rows.map {
                    Player(
                        id: UUID(),
                        displayName: $0.name,
                        uniformNumber: $0.number,
                        pronunciationOverride: "",
                        photoRelativePath: nil,
                        cue: nil,
                        isPresent: true
                    )
                }
            )
        }
    }

    func applyPendingRosterImport() {
        guard let teamIndex, let pendingRosterImport else { return }
        state.teams[teamIndex].players.append(contentsOf: pendingRosterImport.rows)
        state.teams[teamIndex].session.battingOrder.append(contentsOf: pendingRosterImport.rows.map(\.id))
        state.teams[teamIndex].modifiedAt = .now
        normalizeLineup(for: teamIndex)
        self.pendingRosterImport = nil
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
    }

    func discardPendingRosterImport() {
        pendingRosterImport = nil
    }

    func refreshReadiness() {
        prepareSessionForToday()
        state.lastReadiness = readinessService.snapshot(for: selectedTeam)
    }

    func snapshot(reason: String) {
        let snapshotState = state
        Task(priority: .utility) { [weak self] in
            let result = await Task.detached(priority: .utility) { () -> Result<SnapshotRecord, Error> in
                guard let snapshotsDirectory = try? AppPaths.snapshotsDirectory() else {
                    return .failure(AppError.invalidImport)
                }
                let name = "\(UUID().uuidString).json"
                let destination = snapshotsDirectory.appendingPathComponent(name)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                do {
                    try encoder.encode(snapshotState).write(to: destination, options: .atomic)
                    return .success(
                        SnapshotRecord(
                            id: UUID(),
                            createdAt: .now,
                            reason: reason,
                            relativeManifestPath: name
                        )
                    )
                } catch {
                    return .failure(error)
                }
            }.value

            guard let self else { return }
            switch result {
            case .success(let snapshotRecord):
                self.state.snapshots.insert(snapshotRecord, at: 0)
                self.persist()
            case .failure(let error):
                self.lastError = error.localizedDescription
            }
        }
    }

    func restoreSnapshot(_ snapshot: SnapshotRecord) async {
        await busy {
            guard let snapshotsDirectory = try? AppPaths.snapshotsDirectory() else {
                throw AppError.invalidImport
            }
            let sourceURL = snapshotsDirectory.appendingPathComponent(snapshot.relativeManifestPath)
            let currentVersion = self.state.appVersion
            let currentDeviceIdentity = self.state.deviceIdentity
            let currentSettings = self.state.settings
            let currentSchemaVersion = self.state.schemaVersion

            let restoredState = try await Task.detached(priority: .utility) { () -> AppState in
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                var restoredState = try decoder.decode(AppState.self, from: Data(contentsOf: sourceURL))
                restoredState.appVersion = currentVersion
                restoredState.deviceIdentity = currentDeviceIdentity
                restoredState.settings = currentSettings
                restoredState.schemaVersion = max(restoredState.schemaVersion, currentSchemaVersion)
                return restoredState
            }.value

            self.state = restoredState
            self.normalizeSelectedTeamIfNeeded()
            self.normalizeAllTeamsForToday()
            self.scheduleReadinessRefresh()
        }
    }

    func exportSupportBundle() async {
        await busy {
            let url = try self.packageService.exportSupportBundle(
                state: self.state,
                selectedTeam: self.selectedTeam,
                diagnostics: self.playbackEngine.supportDiagnostics()
            )
            self.supportBundle = SupportBundleExport(url: url)
        }
    }

    var selectedTeamPresentPlayers: [Player] {
        selectedTeam?.presentPlayersInBattingOrder ?? []
    }

    var selectedTeamBuiltInClips: [BuiltInClip] {
        selectedTeam?.builtInClips ?? []
    }

    private var teamIndex: Int? {
        state.teams.firstIndex(where: { $0.id == state.selectedTeamID })
    }

    private func normalizeSelectedTeamIfNeeded() {
        if let selectedTeamID = state.selectedTeamID,
           state.teams.contains(where: { $0.id == selectedTeamID }) {
            return
        }
        state.selectedTeamID = state.teams.first?.id
    }

    private func normalizeAllTeamsForToday() {
        for index in state.teams.indices {
            normalizeLineup(for: index)
            if state.teams[index].session.activeSessionDate == nil {
                state.teams[index].session.activeSessionDate = .now
            }
        }
    }

    private func prepareSessionForToday() {
        guard let teamIndex else { return }
        normalizeLineup(for: teamIndex)
        guard !Calendar.current.isDateInToday(state.teams[teamIndex].session.activeSessionDate ?? .distantPast) else {
            return
        }
        state.teams[teamIndex].session.activeSessionDate = .now
        state.teams[teamIndex].session.nextBatterIndex = 0
        if !state.settings.reusePreviousLineupOnNewDay {
            state.teams[teamIndex].session.battingOrder = state.teams[teamIndex].players.map(\.id)
            state.teams[teamIndex].players = state.teams[teamIndex].players.map { player in
                var player = player
                player.isPresent = true
                return player
            }
        }
        normalizeLineup(for: teamIndex)
    }

    private func normalizeLineup(for teamIndex: Int) {
        let players = state.teams[teamIndex].players
        let ids = Set(players.map(\.id))
        let existingOrder = state.teams[teamIndex].session.battingOrder.filter { ids.contains($0) }
        let missingOrder = players.map(\.id).filter { !existingOrder.contains($0) }
        state.teams[teamIndex].session.battingOrder = existingOrder + missingOrder
        let presentCount = state.teams[teamIndex].presentPlayersInBattingOrder.count
        state.teams[teamIndex].session.nextBatterIndex = presentCount == 0 ? 0 : min(max(state.teams[teamIndex].session.nextBatterIndex, 0), presentCount - 1)
    }

    private func prewarmNextBatterCue() {
        prewarmTask?.cancel()
        guard let nextCue = selectedTeam?.nextBatter?.cue else { return }
        prewarmTask = Task(priority: .utility) { [playbackEngine] in
            guard !Task.isCancelled else { return }
            try? await playbackEngine.prewarm(cue: nextCue)
        }
    }

    private func scheduleReadinessRefresh() {
        readinessRefreshTask?.cancel()
        readinessRefreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.refreshReadiness()
        }
    }

    private func persist() {
        let snapshot = state
        persistTask?.cancel()
        persistTask = Task(priority: .utility) {
            let errorDescription = await Task.detached(priority: .utility) { () -> String? in
                do {
                    try Self.write(snapshot)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value

            if let errorDescription {
                self.lastError = errorDescription
            }
        }
    }

    private static func load() throws -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppState.self, from: Data(contentsOf: AppPaths.stateURL()))
    }

    nonisolated private static func write(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)
    }

    private func busy(_ operation: @escaping () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await operation()
            refreshReadiness()
            persist()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func announcerPreviewText(for team: Team, profile: TeamAnnouncerProfile? = nil) -> String {
        let previewPlayer = announcerPreviewPlayer(for: team)
        return announcerText(for: previewPlayer, teamName: team.name, profile: profile ?? team.announcerProfile)
    }

    func announcerVoiceOptions(includeAllLanguages: Bool) -> [AnnouncerVoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { includeAllLanguages || $0.language.hasPrefix("en") }
            .map { voice in
                AnnouncerVoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    languageCode: voice.language,
                    qualityRank: qualityRank(for: voice.quality)
                )
            }
            .sorted {
                if $0.qualityRank != $1.qualityRank {
                    return $0.qualityRank > $1.qualityRank
                }
                if $0.languageCode != $1.languageCode {
                    return $0.languageCode.localizedCaseInsensitiveCompare($1.languageCode) == .orderedAscending
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    func isRecordingCustomAnnouncer(for player: Player) -> Bool {
        customAnnouncerRecorder.recordingPlayerID == player.id && customAnnouncerRecorder.isRecording
    }

    func chooseSuggestedHook(for cue: Cue) -> Cue {
        var updated = cue
        let clipLength = min(max(state.trimDefaults.preferredLength, 6), cueDurationLimit(for: cue))
        updated.duration = max(0.5, clipLength)
        let maxStart = max(0, cueTimelineLength(for: updated) - updated.duration)
        let candidateStart = min(max(4, maxStart * 0.45), maxStart)
        updated.startTime = roundedQuarterSecond(candidateStart)
        return updated
    }

    func chooseStartAtBeginning(for cue: Cue) -> Cue {
        var updated = cue
        updated.startTime = 0
        updated.duration = min(max(state.trimDefaults.preferredLength, 6), cueDurationLimit(for: updated))
        return updated
    }

    func rememberPreferredLength(_ duration: TimeInterval) {
        state.trimDefaults.preferredLength = roundedQuarterSecond(duration)
        persist()
    }

    var recentAppleMusicSelections: [RecentAppleMusicSelection] {
        Array(state.recentAppleMusicSelections.prefix(8))
    }

    private func configurePlaybackAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func makeDefaultAppleMusicCue(for result: MusicSearchResult) -> Cue {
        var cue = Cue.appleDefault(source: AppleMusicSource(songID: result.songID, title: result.title, artistName: result.artistName, duration: result.duration, previewURL: result.previewURL))
        cue.duration = min(max(state.trimDefaults.preferredLength, 6), cueDurationLimit(for: cue))
        return cue
    }

    private func rememberAppleMusicSelection(_ result: MusicSearchResult) {
        let selection = RecentAppleMusicSelection(
            songID: result.songID,
            title: result.title,
            artistName: result.artistName,
            duration: result.duration,
            previewURL: result.previewURL,
            selectedAt: .now
        )
        state.recentAppleMusicSelections.removeAll { $0.songID == selection.songID }
        state.recentAppleMusicSelections.insert(selection, at: 0)
        if state.recentAppleMusicSelections.count > 20 {
            state.recentAppleMusicSelections.removeLast(state.recentAppleMusicSelections.count - 20)
        }
        persist()
    }

    func cueTimelineLength(for cue: Cue) -> Double {
        switch cue.source {
        case .appleMusic(let source):
            switch appleMusicPlaybackCapability {
            case .fullSong:
                return max(source.duration ?? 30, cue.startTime + cue.duration)
            case .previewOnly, .unknown:
                return 20
            }
        case .builtInClip:
            return max(12, cue.startTime + cue.duration)
        case .localAudio(let source):
            return max(source.duration ?? 30, cue.startTime + cue.duration)
        }
    }

    func cueDurationLimit(for cue: Cue) -> Double {
        switch cue.source {
        case .appleMusic:
            return min(20, cueTimelineLength(for: cue))
        case .builtInClip, .localAudio:
            return cueTimelineLength(for: cue)
        }
    }

    func appleMusicTrimHelpText(for cue: Cue) -> String? {
        guard case .appleMusic = cue.source else { return nil }
        switch appleMusicPlaybackCapability {
        case .fullSong:
            return "Choose up to 20 seconds from anywhere in the full song."
        case .previewOnly, .unknown:
            return "No Apple Music playback subscription is active. You can choose up to 20 seconds from the available preview clip."
        }
    }

    private func roundedQuarterSecond(_ value: TimeInterval) -> TimeInterval {
        (value / 0.25).rounded() * 0.25
    }

    private func announcerText(for player: Player, teamName: String, profile: TeamAnnouncerProfile) -> String {
        let name = player.pronunciationOverride.isEmpty ? player.displayName : player.pronunciationOverride
        let values: [(String, String)] = [
            ("<number>", player.uniformNumber),
            ("<name>", name),
            ("<team>", teamName)
        ]

        var rendered = profile.phraseTemplate
        for (token, value) in values {
            rendered = rendered.replacingOccurrences(of: token, with: value)
        }
        return rendered
            .replacingOccurrences(of: " ,", with: ",")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func announcerPreviewPlayer(for team: Team) -> Player {
        team.nextBatter
        ?? team.players.first
        ?? Player(
            id: UUID(),
            displayName: "Alex Ramirez",
            uniformNumber: "12",
            pronunciationOverride: "",
            photoRelativePath: nil,
            cue: Cue.localDefault(source: LocalAudioSource(id: UUID(), displayName: "Sample Cue", relativePath: "", duration: nil, importedAt: .now, hiddenOriginNote: nil)),
            isPresent: true
        )
    }

    private func announcerAssetRelativePath(for player: Player) -> String? {
        guard selectedTeam?.session.gameDayAnnouncerMode == .announcer else { return nil }
        if let custom = player.customAnnouncerRelativePath,
           audioAssetService.assetExists(relativePath: custom) {
            return custom
        }
        if let generated = player.generatedBuiltInAnnouncerRelativePath,
           audioAssetService.assetExists(relativePath: generated) {
            return generated
        }
        return nil
    }

    private func resolveAnnouncerAssetRelativePath(for player: Player) async -> String? {
        if let existing = announcerAssetRelativePath(for: player) {
            return existing
        }

        guard selectedTeam?.session.gameDayAnnouncerMode == .announcer,
              let team = selectedTeam else {
            return nil
        }

        do {
            let asset = try await generateBuiltInAnnouncerAsset(for: player, teamName: team.name, profile: team.announcerProfile)
            guard let liveTeamIndex = state.teams.firstIndex(where: { $0.id == team.id }),
                  let playerIndex = state.teams[liveTeamIndex].players.firstIndex(where: { $0.id == player.id }) else {
                return nil
            }
            state.teams[liveTeamIndex].players[playerIndex].generatedBuiltInAnnouncerRelativePath = asset.relativePath
            state.teams[liveTeamIndex].announcerProfile.applyResolvedVoice(from: asset)
            state.teams[liveTeamIndex].modifiedAt = .now
            scheduleReadinessRefresh()
            persist()
            return asset.relativePath
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func triggerAnnouncerRegeneration(for teamID: UUID, phase: String) {
        announcerRegenerationTask?.cancel()
        announcerRegenerationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.regenerateBuiltInAnnouncers(for: teamID, phase: phase)
        }
    }

    private func regenerateBuiltInAnnouncers(for teamID: UUID, phase: String) async {
        guard let teamIndex = state.teams.firstIndex(where: { $0.id == teamID }) else { return }
        let teamName = state.teams[teamIndex].name
        let profile = state.teams[teamIndex].announcerProfile
        let players = state.teams[teamIndex].players

        announcerRegenerationStatus = AnnouncerRegenerationStatus(teamID: teamID, phase: phase, completed: 0, total: players.count)
        for (index, player) in players.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                let asset = try await generateBuiltInAnnouncerAsset(for: player, teamName: teamName, profile: profile)
                guard let liveTeamIndex = state.teams.firstIndex(where: { $0.id == teamID }),
                      let playerIndex = state.teams[liveTeamIndex].players.firstIndex(where: { $0.id == player.id }) else {
                    continue
                }
                state.teams[liveTeamIndex].players[playerIndex].generatedBuiltInAnnouncerRelativePath = asset.relativePath
                state.teams[liveTeamIndex].announcerProfile.applyResolvedVoice(from: asset)
                state.teams[liveTeamIndex].modifiedAt = .now
                announcerRegenerationStatus = AnnouncerRegenerationStatus(teamID: teamID, phase: phase, completed: index + 1, total: players.count)
                persist()
            } catch {
                lastError = error.localizedDescription
                break
            }
        }
        scheduleReadinessRefresh()
        announcerRegenerationStatus = nil
    }

    private func renderBuiltInAnnouncer(for player: Player, teamName: String, profile: TeamAnnouncerProfile) async throws -> RenderedAnnouncerAudio {
        let phrase = announcerText(for: player, teamName: teamName, profile: profile)
        guard !phrase.isEmpty else { throw AppError.invalidAnnouncerText }
        return try await announcerRenderer.renderSpeechAudio(for: phrase, profile: profile)
    }

    private func generateBuiltInAnnouncerAsset(for player: Player, teamName: String, profile: TeamAnnouncerProfile) async throws -> GeneratedAnnouncerAsset {
        let rendered = try await renderBuiltInAnnouncer(for: player, teamName: teamName, profile: profile)
        let asset = try audioAssetService.storeSpeechData(rendered.data, displayName: "\(player.displayName)-built-in-announcer")
        guard audioAssetService.assetExists(relativePath: asset.relativePath) else {
            throw AppError.invalidImport
        }
        return GeneratedAnnouncerAsset(
            relativePath: asset.relativePath,
            resolvedVoiceIdentifier: rendered.resolvedVoiceIdentifier,
            voiceLanguageCode: rendered.voiceLanguageCode
        )
    }

    private func qualityRank(for quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium:
            return 3
        case .enhanced:
            return 2
        default:
            return 1
        }
    }
}

private struct GeneratedAnnouncerAsset {
    var relativePath: String
    var resolvedVoiceIdentifier: String?
    var voiceLanguageCode: String?
}

private extension TeamAnnouncerProfile {
    mutating func applyResolvedVoice(from asset: GeneratedAnnouncerAsset) {
        resolvedVoiceIdentifier = asset.resolvedVoiceIdentifier
        voiceLanguageCode = asset.voiceLanguageCode
    }
}

actor AnnouncerSpeechRenderer {
    private let synthesizer = AVSpeechSynthesizer()

    fileprivate func renderSpeechAudio(for text: String, profile: TeamAnnouncerProfile) async throws -> RenderedAnnouncerAudio {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.invalidAnnouncerText }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = profile.rate
        utterance.pitchMultiplier = profile.pitchMultiplier
        utterance.volume = profile.volume
        let resolvedVoice = resolvedVoice(for: profile)
        utterance.voice = resolvedVoice

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            var file: AVAudioFile?

            synthesizer.write(utterance) { buffer in
                guard !finished else { return }
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    finished = true
                    do {
                        file = nil
                        let data = try Data(contentsOf: tempURL)
                        try? FileManager.default.removeItem(at: tempURL)
                        continuation.resume(returning: RenderedAnnouncerAudio(
                            data: data,
                            resolvedVoiceIdentifier: resolvedVoice?.identifier,
                            voiceLanguageCode: resolvedVoice?.language
                        ))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                if pcmBuffer.frameLength == 0 {
                    finished = true
                    do {
                        file = nil
                        let data = try Data(contentsOf: tempURL)
                        try? FileManager.default.removeItem(at: tempURL)
                        continuation.resume(returning: RenderedAnnouncerAudio(
                            data: data,
                            resolvedVoiceIdentifier: resolvedVoice?.identifier,
                            voiceLanguageCode: resolvedVoice?.language
                        ))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                do {
                    if file == nil {
                        file = try AVAudioFile(forWriting: tempURL, settings: pcmBuffer.format.settings)
                    }
                    try file?.write(from: pcmBuffer)
                } catch {
                    finished = true
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func resolvedVoice(for profile: TeamAnnouncerProfile) -> AVSpeechSynthesisVoice? {
        if let requested = profile.requestedVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: requested) {
            return voice
        }

        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let languageCode = profile.voiceLanguageCode {
            if let languageMatch = voices
                .filter({ $0.language == languageCode })
                .sorted(by: { qualityRank(for: $0.quality) > qualityRank(for: $1.quality) })
                .first {
                return languageMatch
            }
        }

        if let usEnglish = voices
            .filter({ $0.language.hasPrefix("en-US") || $0.language == "en-US" })
            .sorted(by: { qualityRank(for: $0.quality) > qualityRank(for: $1.quality) })
            .first {
            return usEnglish
        }

        return voices.sorted(by: { qualityRank(for: $0.quality) > qualityRank(for: $1.quality) }).first
    }

    private func qualityRank(for quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium:
            return 3
        case .enhanced:
            return 2
        default:
            return 1
        }
    }
}
