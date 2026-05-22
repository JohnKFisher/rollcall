import AVFoundation
@preconcurrency import AVFAudio
import Combine
import Foundation
import MusicKit
import UIKit
import UniformTypeIdentifiers

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

enum CustomAnnouncerRecordingPhase: Equatable {
    case idle
    case starting(UUID)
    case recording(UUID)
    case stopping(UUID)
}

fileprivate struct RenderedAnnouncerAudio {
    var data: Data
    var resolvedVoiceIdentifier: String?
    var voiceLanguageCode: String?
}

private func customAnnouncerTemporaryURL(fileExtension: String) -> URL {
    let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "caf" : fileExtension
    return FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
}

private func customIntroFileSummary(for url: URL?) -> String {
    guard let url else { return "no file url" }
    let exists = FileManager.default.fileExists(atPath: url.path)
    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    let ext = url.pathExtension.isEmpty ? "none" : url.pathExtension
    return "ext=\(ext), exists=\(exists), bytes=\(size)"
}

private func customIntroErrorSummary(_ error: Error?) -> String {
    guard let error else { return "no underlying error" }
    let nsError = error as NSError
    return "\(nsError.domain) code \(nsError.code): \(nsError.localizedDescription)"
}

private final class AnnouncerRenderCompletionState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func claimCompletion() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        return true
    }

    func hasFinished() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }
}

private final class CustomAnnouncerStopState: @unchecked Sendable {
    private let lock = NSLock()
    private var pendingStopURL: URL?
    private var stopContinuation: CheckedContinuation<URL, Error>?

    func beginStop(url: URL, continuation: CheckedContinuation<URL, Error>) {
        lock.lock()
        pendingStopURL = url
        stopContinuation = continuation
        lock.unlock()
    }

    func takePendingStop() -> (URL?, CheckedContinuation<URL, Error>?) {
        lock.lock()
        defer { lock.unlock() }
        let result = (pendingStopURL, stopContinuation)
        pendingStopURL = nil
        stopContinuation = nil
        return result
    }

    func hasPendingStop() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingStopURL != nil || stopContinuation != nil
    }
}

final class CustomAnnouncerRecorder: NSObject, AVAudioRecorderDelegate, @unchecked Sendable {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private(set) var recordingPlayerID: UUID?
    private let stopState = CustomAnnouncerStopState()

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

    func startRecording(for playerID: UUID, destinationURL: URL) async throws {
        guard await requestPermissionIfNeeded() else { throw AppError.microphonePermissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        let recorder = try AVAudioRecorder(url: destinationURL, settings: settings)
        recorder.delegate = self
        recorder.prepareToRecord()
        guard recorder.record() else { throw AppError.recordingUnavailable }

        self.recorder = recorder
        self.recordingURL = destinationURL
        self.recordingPlayerID = playerID
    }

    func stopRecording() async throws -> URL {
        guard let recorder, let recordingURL else { throw AppError.recordingUnavailable }
        return try await withCheckedThrowingContinuation { continuation in
            stopState.beginStop(url: recordingURL, continuation: continuation)
            recorder.stop()
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let (finishedURL, continuation) = stopState.takePendingStop()
        guard let continuation else { return }
        clearRecordingState()

        guard let finishedURL else {
            continuation.resume(throwing: AppError.customIntroSaveFailed("recorder finished with no destination url"))
            return
        }

        let fileSize = (try? finishedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard fileSize > 0 else {
            continuation.resume(throwing: AppError.customIntroSaveFailed("finish flag=\(flag), \(customIntroFileSummary(for: finishedURL))"))
            return
        }

        continuation.resume(returning: finishedURL)
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let (_, continuation) = stopState.takePendingStop()
        guard let continuation else { return }
        clearRecordingState()
        continuation.resume(throwing: AppError.customIntroSaveFailed("encode callback: \(customIntroErrorSummary(error))"))
    }

    private func finishPendingStopAsCancelled() {
        let (_, continuation) = stopState.takePendingStop()
        guard let continuation else { return }
        continuation.resume(throwing: AppError.recordingUnavailable)
    }

    private func clearRecordingState() {
        self.recorder = nil
        self.recordingURL = nil
        self.recordingPlayerID = nil
    }

    func cancelRecording() {
        guard !stopState.hasPendingStop() else { return }
        let recordingURL = self.recordingURL
        recorder?.stop()
        clearRecordingState()
        finishPendingStopAsCancelled()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
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
    // Central default so a future settings UI can replace this with user selection.
    private let defaultNoSongFallbackBuiltInClipSourceID = "small-cheer"

    @Published var state: AppState
    @Published var isBusy = false
    @Published var lastError: String?
    @Published var exportURL: URL?
    @Published var pendingRosterImport: PendingRosterImport?
    @Published var supportBundle: SupportBundleExport?
    @Published var announcerRegenerationStatus: AnnouncerRegenerationStatus?
    @Published private(set) var isAppleMusicPlaylistSyncing = false
    @Published private(set) var appleMusicPlaylistSyncStatus: String?
    @Published private(set) var appleMusicPlaybackCapability: AppleMusicPlaybackCapability = .unknown
    @Published private(set) var customAnnouncerRecordingPhase: CustomAnnouncerRecordingPhase = .idle
    private var hasFinishedLaunching = false
    private var persistTask: Task<Void, Never>?
    private var readinessRefreshTask: Task<Void, Never>?
    private var prewarmTask: Task<Void, Never>?
    private var startupWarmupTask: Task<Void, Never>?
    private var announcerRegenerationTask: Task<Void, Never>?
    private var pendingIncomingPackageURLs: [URL] = []

    let audioAssetService = AudioAssetService()
    let musicCatalogService = MusicCatalogService()
    let packageService = PackageService()
    let announcerRenderer = AnnouncerSpeechRenderer()
    let haptics = GameDayHaptics()
    let readinessService: ReadinessService
    let playbackEngine: CuePlaybackEngine
    let customAnnouncerRecorder = CustomAnnouncerRecorder()

    var featureFlags: FeatureFlags {
        FeatureFlags(environment: .current, experimental: state.experimental)
    }

    init() {
        FeatureFlags.assertReleaseSafety()
        self.playbackEngine = CuePlaybackEngine(audioAssetService: audioAssetService, musicCatalogService: musicCatalogService)
        self.readinessService = ReadinessService(audioAssetService: audioAssetService)
        self.state = (try? Self.load()) ?? {
            var state = AppState.empty
            state.deviceIdentity = DeviceIdentity(label: UIDevice.current.name)
            return state
        }()
        self.state.appVersion = AppMetadata.appVersion
        self.state.schemaVersion = max(self.state.schemaVersion, AppState.empty.schemaVersion)
        FeatureFlags.assertReleaseSafety(featureFlags)
        normalizeSelectedTeamIfNeeded()
        normalizeAllTeams()
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
            scheduleStartupGameDayWarmup()
            persist()
            await importPendingIncomingPackagesIfNeeded()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func handleIncomingPackage(_ url: URL) {
        guard isSupportedIncomingPackageURL(url) else {
            lastError = "Roll Call can only open .rollcall packages from Share or AirDrop."
            return
        }
        pendingIncomingPackageURLs.append(url)
        Task { await self.importPendingIncomingPackagesIfNeeded() }
    }

    var selectedTeam: Team? {
        state.teams.first(where: { $0.id == state.selectedTeamID })
    }

    var shouldShowOnboarding: Bool {
        state.teams.isEmpty || state.onboarding.activeFlow != nil || !state.onboarding.isComplete
    }

    var onboardingTeam: Team? {
        if let activeTeamID = state.onboarding.activeTeamID {
            return state.teams.first(where: { $0.id == activeTeamID }) ?? selectedTeam
        }
        if state.onboarding.activeFlow == .manualCreate {
            return nil
        }
        return selectedTeam
    }

    func beginSetupGuide() {
        state.onboarding = .manualChooser(completedAt: state.onboarding.completedAt)
        persist()
    }

    func dismissManualSetupGuide() {
        if state.teams.isEmpty {
            state.onboarding = .notStarted
        } else {
            state.onboarding = .completed(at: state.onboarding.completedAt ?? .now)
        }
        persist()
    }

    func startOnboardingCreateNewTeam() {
        state.onboarding.activeFlow = state.teams.isEmpty ? .automatic : .manualCreate
        state.onboarding.activeTeamID = nil
        state.onboarding.didChooseCheerFallback = false
        state.onboarding.didSeeLineup = false
        state.onboarding.importHandoffTeamID = nil
        persist()
    }

    func startOnboardingReviewCurrentTeam() {
        state.onboarding.activeFlow = .manualReview
        state.onboarding.activeTeamID = state.selectedTeamID
        state.onboarding.didChooseCheerFallback = selectedTeam?.players.contains { $0.cue != nil } ?? false
        state.onboarding.didSeeLineup = false
        state.onboarding.importHandoffTeamID = nil
        persist()
    }

    func completeOnboarding() {
        state.onboarding = .completed()
        persist()
    }

    func markOnboardingCheerFallbackChosen() {
        state.onboarding.didChooseCheerFallback = true
        persist()
    }

    func markOnboardingLineupSeen() {
        state.onboarding.didSeeLineup = true
        persist()
    }

    func selectTeam(_ team: Team) {
        state.selectedTeamID = team.id
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
    }

    @discardableResult
    func addTeam(named name: String, accentPreset: TeamAccentPreset = .rollCallOrange, forOnboarding: Bool = false) -> Team? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let team = Team(
            id: UUID(),
            name: trimmed,
            createdAt: .now,
            modifiedAt: .now,
            players: [],
            builtInClips: BuiltInClip.defaults,
            session: TeamSessionState(activeSessionDate: nil, battingOrder: [], nextBatterIndex: 0, gameDayAnnouncerMode: .songOnly, battingOrderIsCustomized: false),
            announcerProfile: .default,
            accentPreset: accentPreset
        )
        state.teams.append(team)
        state.selectedTeamID = team.id
        if forOnboarding {
            state.onboarding.activeFlow = state.teams.count == 1 ? .automatic : .manualCreate
            state.onboarding.activeTeamID = team.id
            state.onboarding.didChooseCheerFallback = false
            state.onboarding.didSeeLineup = false
            state.onboarding.importHandoffTeamID = nil
        }
        persist()
        return team
    }

    func duplicateTeam() {
        guard var team = selectedTeam else { return }
        let originalPlayers = team.players
        let originalBattingOrder = team.session.battingOrder
        let originalNextBatter = team.nextBatter?.id
        team.id = UUID()
        team.name += " Copy"
        var playerIDMap: [UUID: UUID] = [:]
        team.players = originalPlayers.map { player in
            var player = player
            let oldID = player.id
            player.id = UUID()
            playerIDMap[oldID] = player.id
            if var cue = player.cue {
                cue.id = UUID()
                player.cue = cue
            }
            return player
        }
        let duplicatedOrder = originalBattingOrder.compactMap { playerIDMap[$0] }
        let nextBatterID = originalNextBatter.flatMap { playerIDMap[$0] }
        let duplicatedPresentPlayers = team.orderedPlayers(by: duplicatedOrder).filter(\.isPresent)
        let duplicatedNextBatterIndex = nextBatterID.flatMap { nextID in
            duplicatedPresentPlayers.firstIndex(where: { $0.id == nextID })
        } ?? 0
        team.session = TeamSessionState(
            activeSessionDate: nil,
            battingOrder: duplicatedOrder,
            nextBatterIndex: duplicatedNextBatterIndex,
            gameDayAnnouncerMode: team.session.gameDayAnnouncerMode,
            battingOrderIsCustomized: team.session.battingOrderIsCustomized
        )
        state.teams.append(team)
        state.selectedTeamID = team.id
        normalizeLineup(for: state.teams.count - 1)
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

    func setAccentPreset(_ accentPreset: TeamAccentPreset, for teamID: UUID) {
        guard let index = state.teams.firstIndex(where: { $0.id == teamID }) else { return }
        state.teams[index].accentPreset = accentPreset
        state.teams[index].modifiedAt = .now
        persist()
    }

    func removeSelectedTeam() {
        guard let teamIndex else { return }
        state.teams.remove(at: teamIndex)
        normalizeSelectedTeamIfNeeded()
        stopPlayback()
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
    }

    @discardableResult
    func addPlayer(name: String, number: String) -> Player? {
        guard let teamIndex = teamIndex else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let player = Player(id: UUID(), displayName: trimmedName, uniformNumber: number.trimmingCharacters(in: .whitespacesAndNewlines), pronunciationOverride: "", photoRelativePath: nil, cue: nil, isPresent: true)
        state.teams[teamIndex].players.append(player)
        state.teams[teamIndex].session.battingOrder.append(player.id)
        state.teams[teamIndex].modifiedAt = .now
        normalizeLineup(for: teamIndex)
        persist()
        return player
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
        state.teams[teamIndex].session.battingOrder = state.teams[teamIndex].players.map(\.id)
        state.teams[teamIndex].session.battingOrderIsCustomized = true
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
    }

    func moveBattingOrder(from offsets: IndexSet, to offset: Int) {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.battingOrder.move(fromOffsets: offsets, toOffset: offset)
        state.teams[teamIndex].session.battingOrderIsCustomized = true
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
    }

    func sortBattingOrderAlphabetically() {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.battingOrder = alphabeticalBattingOrder(for: state.teams[teamIndex].players)
        state.teams[teamIndex].session.battingOrderIsCustomized = true
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
    }

    func sortBattingOrderByNumber() {
        guard let teamIndex else { return }
        state.teams[teamIndex].session.battingOrder = uniformNumberBattingOrder(for: state.teams[teamIndex].players)
        state.teams[teamIndex].session.battingOrderIsCustomized = true
        normalizeLineup(for: teamIndex)
        prewarmNextBatterCue()
        persist()
    }

    @discardableResult
    func assignAppleMusic(_ result: MusicSearchResult, to player: Player) async -> Bool {
        do {
            await refreshAppleMusicPlaybackCapability()
            let resolvedResult = try await enrichedAppleMusicSelection(result)
            var updated = player
            updated.cue = makeDefaultAppleMusicCue(for: resolvedResult)
            rememberAppleMusicSelection(resolvedResult)
            updatePlayer(updated)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
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
        customAnnouncerRecordingPhase = .starting(player.id)
        do {
            let destinationURL = customAnnouncerTemporaryURL(fileExtension: "caf")
            try await customAnnouncerRecorder.startRecording(for: player.id, destinationURL: destinationURL)
            customAnnouncerRecordingPhase = .recording(player.id)
        } catch {
            customAnnouncerRecordingPhase = .idle
            lastError = error.localizedDescription
        }
    }

    func stopRecordingCustomAnnouncer(for player: Player) async {
        customAnnouncerRecordingPhase = .stopping(player.id)
        do {
            let recordedURL = try await customAnnouncerRecorder.stopRecording()
            let asset: LocalAudioSource
            do {
                asset = try audioAssetService.storeCustomAnnouncerRecording(
                    from: recordedURL,
                    playerID: player.id,
                    displayName: "\(player.displayName)-custom-announcer",
                )
            } catch {
                throw AppError.customIntroSaveFailed("recorded file could not be reopened. \(customIntroFileSummary(for: recordedURL)); reader error: \(customIntroErrorSummary(error))")
            }
            guard audioAssetService.assetExists(relativePath: asset.relativePath) else {
                throw AppError.customIntroSaveFailed("saved flat asset was not visible at \(asset.relativePath)")
            }
            try? FileManager.default.removeItem(at: recordedURL)
            var updated = player
            if player.customAnnouncerRelativePath != asset.relativePath {
                audioAssetService.removeAsset(relativePath: player.customAnnouncerRelativePath)
            }
            updated.customAnnouncerRelativePath = asset.relativePath
            updatePlayer(updated)
            try configurePlaybackAudioSession()
            customAnnouncerRecordingPhase = .idle
        } catch {
            customAnnouncerRecordingPhase = .idle
            lastError = error.localizedDescription
        }
    }

    func cancelRecordingCustomAnnouncer() {
        customAnnouncerRecorder.cancelRecording()
        customAnnouncerRecordingPhase = .idle
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
        audioAssetService.removeAsset(relativePath: player.customAnnouncerRelativePath)
        updated.customAnnouncerRelativePath = nil
        updatePlayer(updated)
    }

    func makeLocalCopy(for player: Player) async {
        await busy {
            guard self.featureFlags.appleMusicLocalCopyEnabled else { throw AppError.featureDisabled }
            guard let cue = player.cue, case .appleMusic(let source) = cue.source, let previewURL = source.previewURL else { throw AppError.missingPreview }
            let local = try await self.audioAssetService.importRemotePreview(from: previewURL, displayName: "\(source.artistName) - \(source.title)", hiddenOrigin: HiddenOriginNote(importedAt: .now, originSummary: "appleMusicPreview:\(source.songID)"))
            var updated = player
            updated.cue = .localDefault(source: local)
            self.updatePlayer(updated)
        }
    }

    func play(player: Player) async {
        do {
            guard let plan = playbackPlan(for: player) else { return }
            switch plan {
            case .cue(let cue, let announcerRelativePath):
                try await playbackEngine.play(
                    cue: cue,
                    announcerRelativePath: announcerRelativePath,
                    fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled
                )
            case .assetOnly(let relativePath, let activeCueID):
                try await playbackEngine.playAsset(
                    relativePath: relativePath,
                    activeCueID: activeCueID,
                    fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled
                )
            }
            haptics.success(isEnabled: state.settings.hapticsEnabled)
        } catch {
            lastError = error.localizedDescription
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
        }
    }

    func play(builtInClip: BuiltInClip) async {
        do {
            try await playbackEngine.play(
                cue: builtInClip.cue,
                fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled
            )
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
            try await playbackEngine.play(
                cue: cue,
                fadeOutVolumeAutomationEnabled: state.settings.fadeOutVolumeAutomationEnabled
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func previewAppleMusicSearchResult(_ result: MusicSearchResult) async {
        do {
            await refreshAppleMusicPlaybackCapability()
            let cue = makeDefaultAppleMusicCue(for: try await enrichedAppleMusicSelection(result))
            await previewCue(cue)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshAppleMusicPlaybackCapability() async {
        let capability = await musicCatalogService.playbackCapability()
        appleMusicPlaybackCapability = capability
    }

    func searchAppleMusic(term: String) async throws -> [MusicSearchResult] {
        await refreshAppleMusicPlaybackCapability()
        let mode: AppleMusicSearchMode = appleMusicPlaybackCapability == .fullSong ? .catalogOnly : .previewFallback
        return try await musicCatalogService.search(term: term, mode: mode)
    }

    @discardableResult
    func refreshAppleMusicCueMetadata(for playerID: UUID) async -> Bool {
        await refreshAppleMusicPlaybackCapability()
        guard appleMusicPlaybackCapability == .fullSong,
              let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }),
              var cue = state.teams[teamIndex].players[playerIndex].cue,
              case .appleMusic(var source) = cue.source,
              source.isCatalogBacked != false,
              source.duration == nil else {
            return false
        }

        do {
            let resolved = try await musicCatalogService.catalogBackedResult(for: MusicSearchResult(
                songID: source.songID,
                title: source.title,
                artistName: source.artistName,
                duration: source.duration,
                previewURL: source.previewURL,
                isCatalogBacked: true
            ))
            source.songID = resolved.songID
            source.title = resolved.title
            source.artistName = resolved.artistName
            source.duration = resolved.duration
            source.previewURL = resolved.previewURL
            source.isCatalogBacked = true
            cue.source = .appleMusic(source)
            state.teams[teamIndex].players[playerIndex].cue = cue
            persist()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func previewBuiltInAnnouncer(profile: TeamAnnouncerProfile? = nil) async {
        lastError = "Built-in Voice has been removed from Roll Call. Use Announcement Cue recordings instead."
    }

    func advanceNextBatter() {
        guard let teamIndex else { return }
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

    func goToPreviousBatter() {
        guard let teamIndex else { return }
        let present = state.teams[teamIndex].presentPlayersInBattingOrder
        guard !present.isEmpty else {
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
            return
        }
        let count = present.count
        state.teams[teamIndex].session.nextBatterIndex = (state.teams[teamIndex].session.nextBatterIndex - 1 + count) % count
        state.teams[teamIndex].modifiedAt = .now
        haptics.success(isEnabled: state.settings.hapticsEnabled)
        prewarmNextBatterCue()
        persist()
    }

    func setHapticsEnabled(_ isEnabled: Bool) {
        state.settings.hapticsEnabled = isEnabled
        persist()
    }

    func setFadeOutVolumeAutomationEnabled(_ isEnabled: Bool) {
        state.settings.fadeOutVolumeAutomationEnabled = isEnabled
        persist()
    }

    func setAlwaysUseDarkLiveMode(_ isEnabled: Bool) {
        state.settings.alwaysUseDarkLiveMode = isEnabled
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
        lastError = "Built-in Voice has been removed from Roll Call. Use Announcement Cue recordings instead."
    }

    func enableExperimentalCopies() {
        state.experimental.appleMusicLocalCopyEnabled = true
        state.experimental.acknowledgedAt = .now
        persist()
    }

    func setShowExperimentalFeatures(_ isEnabled: Bool) {
        state.experimental.showExperimentalFeatures = isEnabled
        persist()
    }

    func setUnlockPremiumForTesting(_ isEnabled: Bool) {
        state.experimental.unlockPremiumForTesting = isEnabled
        persist()
    }

    func setAppleMusicLocalCopyEnabled(_ isEnabled: Bool) {
        state.experimental.appleMusicLocalCopyEnabled = isEnabled
        if isEnabled, state.experimental.acknowledgedAt == nil {
            state.experimental.acknowledgedAt = .now
        }
        persist()
    }

    func setAppleMusicTeamPlaylistSyncEnabled(_ isEnabled: Bool) {
        state.experimental.appleMusicTeamPlaylistSyncEnabled = isEnabled
        persist()
    }

    func acknowledgeExperimentalTeamPlaylistSync() {
        state.experimental.appleMusicTeamPlaylistAcknowledgedAt = .now
        persist()
    }

    func syncSelectedTeamAppleMusicPlaylist() async {
        guard !isAppleMusicPlaylistSyncing else { return }
        guard featureFlags.appleMusicTeamPlaylistSyncEnabled else {
            appleMusicPlaylistSyncStatus = AppError.featureDisabled.localizedDescription
            return
        }
        guard let team = selectedTeam else {
            appleMusicPlaylistSyncStatus = AppError.noSelectedTeam.localizedDescription
            return
        }

        let summary = appleMusicPlaylistSummary(for: team)
        guard !summary.songIDs.isEmpty else {
            appleMusicPlaylistSyncStatus = AppError.noAppleMusicTeamCues.localizedDescription
            return
        }

        isAppleMusicPlaylistSyncing = true
        appleMusicPlaylistSyncStatus = "Updating \"\(summary.playlistName)\"..."
        defer { isAppleMusicPlaylistSyncing = false }

        do {
            try await musicCatalogService.syncTeamPlaylist(name: summary.playlistName, songIDs: summary.songIDs)
            var message = "Updated \"\(summary.playlistName)\" with \(summary.songIDs.count) \(summary.songIDs.count == 1 ? "song" : "songs")."
            if summary.skippedCueCount > 0 {
                message += " Skipped \(summary.skippedCueCount) non-Apple-Music \(summary.skippedCueCount == 1 ? "cue" : "cues")."
            }
            appleMusicPlaylistSyncStatus = message
            haptics.success(isEnabled: state.settings.hapticsEnabled)
        } catch {
            appleMusicPlaylistSyncStatus = error.localizedDescription
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
        }
    }

    func exportSelectedTeam() async {
        await busy {
            guard let team = self.selectedTeam else { return }
            self.exportURL = try self.packageService.export(team: team, state: self.state)
        }
    }

    func importPackage(from url: URL) async {
        await performPackageImport(from: url, opensOnboardingHandoff: false)
    }

    func importPackageFromOnboarding(from url: URL) async {
        await performPackageImport(from: url, opensOnboardingHandoff: true)
    }

    private func performPackageImport(from url: URL, opensOnboardingHandoff: Bool) async {
        await busy {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            self.createBackup(reason: "Automatic backup before package import")
            let manifest = try self.packageService.import(packageURL: url, audioAssetService: self.audioAssetService)
            var imported = manifest.team
            imported.id = UUID()
            imported.name += " Imported"
            self.state.teams.append(imported)
            self.state.selectedTeamID = imported.id
            self.normalizeLineup(for: self.state.teams.count - 1)
            if opensOnboardingHandoff {
                self.state.onboarding.completedAt = .now
                self.state.onboarding.activeFlow = .importHandoff
                self.state.onboarding.activeTeamID = imported.id
                self.state.onboarding.importHandoffTeamID = imported.id
                self.state.onboarding.didChooseCheerFallback = false
                self.state.onboarding.didSeeLineup = true
            }
            self.persist()
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
        state.lastReadiness = readinessService.snapshot(for: selectedTeam)
    }

    func requestAppleMusicAccess() async {
        _ = await MusicAuthorization.request()
        refreshReadiness()
    }

    func createBackup(reason: String) {
        let snapshotState = state
        Task(priority: .utility) { [weak self] in
            let result = await self?.writeBackupRecord(for: snapshotState, reason: reason) ?? .failure(AppError.invalidImport)

            guard let self else { return }
            switch result {
            case .success(let snapshotRecord):
                self.insertBackupRecord(snapshotRecord)
                self.persist()
            case .failure(let error):
                self.lastError = error.localizedDescription
            }
        }
    }

    private func writeBackupRecord(for snapshotState: AppState, reason: String) async -> Result<SnapshotRecord, Error> {
        await Task.detached(priority: .utility) { () -> Result<SnapshotRecord, Error> in
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
    }

    private func insertBackupRecord(_ snapshotRecord: SnapshotRecord) {
        state.snapshots.insert(snapshotRecord, at: 0)
        let overflow = Array(state.snapshots.dropFirst(10))
        state.snapshots = Array(state.snapshots.prefix(10))
        pruneBackupFiles(for: overflow)
    }

    private func pruneBackupFiles(for snapshots: [SnapshotRecord]) {
        guard !snapshots.isEmpty else { return }
        Task.detached(priority: .utility) {
            guard let snapshotsDirectory = try? AppPaths.snapshotsDirectory() else { return }
            for snapshot in snapshots {
                let url = snapshotsDirectory.appendingPathComponent(snapshot.relativeManifestPath)
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func restoreBackup(_ snapshot: SnapshotRecord) async {
        await busy {
            guard let snapshotsDirectory = try? AppPaths.snapshotsDirectory() else {
                throw AppError.invalidImport
            }
            let preRestoreBackup = try await self.writeBackupRecord(
                for: self.state,
                reason: "Automatic backup before restore"
            ).get()
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
            self.insertBackupRecord(preRestoreBackup)
            self.normalizeSelectedTeamIfNeeded()
            self.normalizeAllTeams()
            self.scheduleReadinessRefresh()
            self.persist()
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

    private func cueForPlayerPlayback(_ player: Player) -> Cue? {
        if let cue = player.cue {
            return cue
        }
        return fallbackCue(for: player)
    }

    private func fallbackCue(for player: Player, cueID: UUID? = nil) -> Cue? {
        let teamBuiltIns = selectedTeam?.builtInClips ?? []
        if let fallbackClip = BuiltInClip.firstMatchingSourceID(defaultNoSongFallbackBuiltInClipSourceID, in: teamBuiltIns) {
            var cue = fallbackClip.cue
            cue.id = cueID ?? player.id
            return cue
        }
        if let fallbackClip = BuiltInClip.firstMatchingSourceID(defaultNoSongFallbackBuiltInClipSourceID, in: BuiltInClip.defaults) {
            var cue = fallbackClip.cue
            cue.id = cueID ?? player.id
            return cue
        }
        return nil
    }

    private func playbackPlan(for player: Player) -> PlayerPlaybackPlan? {
        let mode = selectedTeam?.session.gameDayAnnouncerMode ?? .songOnly
        let announcerRelativePath = storedCustomAnnouncerRelativePath(for: player)
        switch mode {
        case .announcerOnly:
            if let announcerRelativePath {
                return .assetOnly(relativePath: announcerRelativePath, activeCueID: playbackID(for: player))
            }
            guard let fallbackCue = fallbackCue(for: player, cueID: playbackID(for: player)) else { return nil }
            return .cue(cue: fallbackCue, announcerRelativePath: nil)
        case .announcerAndSong:
            guard let cue = cueForPlayerPlayback(player) else { return nil }
            return .cue(cue: cue, announcerRelativePath: announcerRelativePath)
        case .songOnly:
            guard let cue = cueForPlayerPlayback(player) else { return nil }
            return .cue(cue: cue, announcerRelativePath: nil)
        }
    }

    private func playbackID(for player: Player) -> UUID {
        player.cue?.id ?? player.id
    }

    private struct AppleMusicPlaylistSummary {
        var playlistName: String
        var songIDs: [String]
        var skippedCueCount: Int
    }

    private func appleMusicPlaylistSummary(for team: Team) -> AppleMusicPlaylistSummary {
        var seenSongIDs = Set<String>()
        var songIDs: [String] = []
        var skippedCueCount = 0

        for player in team.players {
            guard let cue = player.cue else { continue }
            guard case .appleMusic(let source) = cue.source, source.isCatalogBacked != false else {
                skippedCueCount += 1
                continue
            }
            guard seenSongIDs.insert(source.songID).inserted else { continue }
            songIDs.append(source.songID)
        }

        return AppleMusicPlaylistSummary(
            playlistName: "Roll Call - \(team.name)",
            songIDs: songIDs,
            skippedCueCount: skippedCueCount
        )
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

    private func normalizeAllTeams() {
        for index in state.teams.indices {
            normalizeLineup(for: index)
        }
    }

    private func normalizeLineup(for teamIndex: Int) {
        let players = state.teams[teamIndex].players
        let ids = Set(players.map(\.id))
        let existingOrder = state.teams[teamIndex].session.battingOrder.filter { ids.contains($0) }
        if state.teams[teamIndex].session.battingOrderIsCustomized {
            let missingOrder = players.map(\.id).filter { !existingOrder.contains($0) }
            state.teams[teamIndex].session.battingOrder = existingOrder + missingOrder
        } else {
            state.teams[teamIndex].session.battingOrder = alphabeticalBattingOrder(for: players)
        }
        let presentCount = state.teams[teamIndex].presentPlayersInBattingOrder.count
        state.teams[teamIndex].session.nextBatterIndex = presentCount == 0 ? 0 : min(max(state.teams[teamIndex].session.nextBatterIndex, 0), presentCount - 1)
    }

    private func alphabeticalBattingOrder(for players: [Player]) -> [UUID] {
        alphabeticalPlayerIDs(for: players)
    }

    private func uniformNumberBattingOrder(for players: [Player]) -> [UUID] {
        players.sorted { lhs, rhs in
            let lhsNumber = Int(lhs.uniformNumber.trimmingCharacters(in: .whitespacesAndNewlines))
            let rhsNumber = Int(rhs.uniformNumber.trimmingCharacters(in: .whitespacesAndNewlines))
            switch (lhsNumber, rhsNumber) {
            case let (lhs?, rhs?) where lhs != rhs:
                return lhs < rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                let lhsName = normalizedPlayerNameParts(lhs.displayName)
                let rhsName = normalizedPlayerNameParts(rhs.displayName)
                if lhsName.first != rhsName.first {
                    return lhsName.first.localizedCaseInsensitiveCompare(rhsName.first) == .orderedAscending
                }
                if lhsName.remainder != rhsName.remainder {
                    return lhsName.remainder.localizedCaseInsensitiveCompare(rhsName.remainder) == .orderedAscending
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }
        .map(\.id)
    }

    private func prewarmNextBatterCue() {
        prewarmTask?.cancel()
        guard let nextCue = selectedTeam?.nextBatter?.cue else { return }
        prewarmTask = Task(priority: .utility) { [playbackEngine] in
            guard !Task.isCancelled else { return }
            try? await playbackEngine.prewarm(cue: nextCue)
        }
    }

    private func scheduleStartupGameDayWarmup() {
        startupWarmupTask?.cancel()
        let nextCue = selectedTeam?.nextBatter?.cue
        startupWarmupTask = Task(priority: .utility) { [playbackEngine] in
            guard !Task.isCancelled else { return }
            guard let nextCue, !Task.isCancelled else { return }
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

    private func importPendingIncomingPackagesIfNeeded() async {
        guard hasFinishedLaunching, !isBusy else { return }
        while !pendingIncomingPackageURLs.isEmpty {
            let nextURL = pendingIncomingPackageURLs.removeFirst()
            await performPackageImport(from: nextURL, opensOnboardingHandoff: false)
        }
    }

    private func isSupportedIncomingPackageURL(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        if url.pathExtension.localizedCaseInsensitiveCompare("rollcall") == .orderedSame {
            return true
        }
        if let type = UTType(filenameExtension: url.pathExtension),
           type.conforms(to: .rollCallPackage) {
            return true
        }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path)
    }

    func announcerPreviewText(for team: Team, profile: TeamAnnouncerProfile? = nil) -> String {
        let previewPlayer = announcerPreviewPlayer(for: team)
        return announcerText(for: previewPlayer, teamName: team.name, profile: profile ?? team.announcerProfile)
    }

    func announcerVoiceOptions(includeAllLanguages: Bool) -> [AnnouncerVoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { includeAllLanguages || $0.language.hasPrefix("en") }
            .filter { !isNoveltyVoice($0) }
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
        switch customAnnouncerRecordingPhase {
        case .recording(let playerID):
            return playerID == player.id
        default:
            return false
        }
    }

    func isCustomAnnouncerTransitioning(for player: Player) -> Bool {
        switch customAnnouncerRecordingPhase {
        case .starting(let playerID), .stopping(let playerID):
            return playerID == player.id
        default:
            return false
        }
    }

    func customAnnouncerButtonTitle(for player: Player) -> String {
        switch customAnnouncerRecordingPhase {
        case .starting(let playerID) where playerID == player.id:
            return "Starting Recording..."
        case .stopping(let playerID) where playerID == player.id:
            return "Saving Recording..."
        case .recording(let playerID) where playerID == player.id:
            return "Stop Recording"
        default:
            return player.customAnnouncerRelativePath == nil ? "Record Announcement Cue" : "Re-record Announcement Cue"
        }
    }

    func hasStoredCustomAnnouncer(for player: Player) -> Bool {
        guard let relativePath = player.customAnnouncerRelativePath else { return false }
        return audioAssetService.assetExists(relativePath: relativePath)
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
        var cue = Cue.appleDefault(source: AppleMusicSource(songID: result.songID, title: result.title, artistName: result.artistName, duration: result.duration, previewURL: result.previewURL, isCatalogBacked: result.isCatalogBacked))
        cue.duration = min(max(state.trimDefaults.preferredLength, 6), cueDurationLimit(for: cue))
        return cue
    }

    private func enrichedAppleMusicSelection(_ result: MusicSearchResult) async throws -> MusicSearchResult {
        guard appleMusicPlaybackCapability == .fullSong else { return result }
        return try await musicCatalogService.catalogBackedResult(for: result)
    }

    private func rememberAppleMusicSelection(_ result: MusicSearchResult) {
        let selection = RecentAppleMusicSelection(
            songID: result.songID,
            title: result.title,
            artistName: result.artistName,
            duration: result.duration,
            previewURL: result.previewURL,
            isCatalogBacked: result.isCatalogBacked,
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
            if source.isCatalogBacked == false {
                return 20
            }
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
            return "Choose up to 20 seconds from anywhere in the full song. Fade-out timing currently applies reliably to preview and local audio playback; full-song Apple Music still ends hard through MusicKit."
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

    private func storedCustomAnnouncerRelativePath(for player: Player) -> String? {
        if let custom = player.customAnnouncerRelativePath,
           audioAssetService.assetExists(relativePath: custom) {
            return custom
        }
        return nil
    }

    private enum PlayerPlaybackPlan {
        case cue(cue: Cue, announcerRelativePath: String?)
        case assetOnly(relativePath: String, activeCueID: UUID)
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
        var firstFailure: String?

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
                guard let liveTeamIndex = state.teams.firstIndex(where: { $0.id == teamID }),
                      let playerIndex = state.teams[liveTeamIndex].players.firstIndex(where: { $0.id == player.id }) else {
                    continue
                }
                state.teams[liveTeamIndex].players[playerIndex].generatedBuiltInAnnouncerRelativePath = nil
                if firstFailure == nil {
                    firstFailure = "\(player.displayName): \(error.localizedDescription)"
                }
                announcerRegenerationStatus = AnnouncerRegenerationStatus(teamID: teamID, phase: phase, completed: index + 1, total: players.count)
            }
        }
        scheduleReadinessRefresh()
        announcerRegenerationStatus = nil
        if let firstFailure {
            lastError = "Built-in voice clips could not be pre-generated on this device. Roll Call will speak built-in announcers live during playback. First failure: \(firstFailure)"
        }
        persist()
    }

    private func renderBuiltInAnnouncer(for player: Player, teamName: String, profile: TeamAnnouncerProfile) async throws -> RenderedAnnouncerAudio {
        let phrase = announcerText(for: player, teamName: teamName, profile: profile)
        guard !phrase.isEmpty else { throw AppError.invalidAnnouncerText }
        return try await announcerRenderer.renderSpeechAudio(for: phrase, profile: profile)
    }

    private func generateBuiltInAnnouncerAsset(for player: Player, teamName: String, profile: TeamAnnouncerProfile) async throws -> GeneratedAnnouncerAsset {
        let rendered = try await renderBuiltInAnnouncer(for: player, teamName: teamName, profile: profile)
        let asset = try audioAssetService.storeSpeechData(rendered.data, displayName: "\(player.displayName)-built-in-announcer")
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

    private func isNoveltyVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        let noveltyNames: Set<String> = [
            "bad news",
            "bahh",
            "bells",
            "boing",
            "bubbles",
            "cellos",
            "good news",
            "jester",
            "organ",
            "superstar",
            "trinoids",
            "whisper",
            "wobble",
            "zarvox"
        ]
        return noveltyNames.contains(voice.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
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

@MainActor
final class AnnouncerSpeechRenderer {
    private let renderTimeout: Duration = .seconds(12)

    fileprivate func renderSpeechAudio(for text: String, profile: TeamAnnouncerProfile) async throws -> RenderedAnnouncerAudio {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.invalidAnnouncerText }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.usesApplicationAudioSession = true
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = profile.rate
        utterance.pitchMultiplier = profile.pitchMultiplier
        utterance.volume = profile.volume
        let resolvedVoice = resolvedVoice(for: profile)
        utterance.voice = resolvedVoice

        return try await withCheckedThrowingContinuation { continuation in
            var file: AVAudioFile?
            var wroteAudioData = false
            let completionState = AnnouncerRenderCompletionState()
            var timeoutTask: Task<Void, Never>?

            func finish(with result: Result<RenderedAnnouncerAudio, Error>) {
                guard completionState.claimCompletion() else { return }
                timeoutTask?.cancel()
                continuation.resume(with: result)
            }

            func loadRenderedAudio() -> Result<RenderedAnnouncerAudio, Error> {
                do {
                    guard wroteAudioData, FileManager.default.fileExists(atPath: tempURL.path) else {
                        return .failure(AppError.invalidAnnouncerAudio)
                    }
                    file = nil
                    let data = try Data(contentsOf: tempURL)
                    guard !data.isEmpty else {
                        try? FileManager.default.removeItem(at: tempURL)
                        return .failure(AppError.invalidAnnouncerAudio)
                    }
                    try? FileManager.default.removeItem(at: tempURL)
                    return .success(
                        RenderedAnnouncerAudio(
                            data: data,
                            resolvedVoiceIdentifier: resolvedVoice?.identifier,
                            voiceLanguageCode: resolvedVoice?.language
                        )
                    )
                } catch {
                    return .failure(error)
                }
            }

            timeoutTask = Task {
                try? await Task.sleep(for: renderTimeout)
                guard completionState.claimCompletion() else { return }
                synthesizer.stopSpeaking(at: .immediate)
                try? FileManager.default.removeItem(at: tempURL)
                continuation.resume(throwing: AppError.announcerGenerationTimedOut)
            }

            synthesizer.write(utterance) { buffer in
                guard !completionState.hasFinished() else { return }

                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    finish(with: loadRenderedAudio())
                    return
                }

                if pcmBuffer.frameLength == 0 {
                    finish(with: loadRenderedAudio())
                    return
                }

                guard self.pcmBufferHasAudioData(pcmBuffer) else { return }

                do {
                    if file == nil {
                        let fileSettings = self.audioFileSettings(for: resolvedVoice) ?? pcmBuffer.format.settings
                        file = try AVAudioFile(forWriting: tempURL, settings: fileSettings)
                    }
                    try file?.write(from: pcmBuffer)
                    wroteAudioData = true
                } catch {
                    try? FileManager.default.removeItem(at: tempURL)
                    finish(with: .failure(error))
                }
            }
        }
    }

    private func pcmBufferHasAudioData(_ buffer: AVAudioPCMBuffer) -> Bool {
        UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList).contains { audioBuffer in
            audioBuffer.mDataByteSize > 0
        }
    }

    private func audioFileSettings(for voice: AVSpeechSynthesisVoice?) -> [String: Any]? {
        guard let voice else { return nil }
        let settings = voice.audioFileSettings
        return settings.isEmpty ? nil : settings
    }

    private func resolvedVoice(for profile: TeamAnnouncerProfile) -> AVSpeechSynthesisVoice? {
        if let requested = profile.requestedVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: requested) {
            return voice
        }

        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let languageCode = profile.voiceLanguageCode {
            if let languageMatch = exportPreferredVoices(from: voices)
                .filter({ $0.language == languageCode })
                .sorted(by: { qualityRank(for: $0.quality) > qualityRank(for: $1.quality) })
                .first {
                return languageMatch
            }
        }

        if let usEnglish = exportPreferredVoices(from: voices)
            .filter({ $0.language.hasPrefix("en-US") || $0.language == "en-US" })
            .sorted(by: { qualityRank(for: $0.quality) > qualityRank(for: $1.quality) })
            .first {
            return usEnglish
        }

        return exportPreferredVoices(from: voices)
            .sorted(by: { qualityRank(for: $0.quality) > qualityRank(for: $1.quality) })
            .first
    }

    private func exportPreferredVoices(from voices: [AVSpeechSynthesisVoice]) -> [AVSpeechSynthesisVoice] {
        let exportable = voices.filter { !(self.audioFileSettings(for: $0)?.isEmpty ?? true) }
        return exportable.isEmpty ? voices : exportable
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
