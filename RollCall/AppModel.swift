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

    func duplicateCount(comparedTo existingPlayers: [Player]) -> Int {
        let existingKeys = Set(existingPlayers.map(Self.duplicateKey).filter { !$0.isEmpty })
        var importedKeys = Set<String>()
        var duplicateCount = 0

        for player in rows {
            let key = Self.duplicateKey(for: player)
            guard !key.isEmpty else { continue }
            if existingKeys.contains(key) || !importedKeys.insert(key).inserted {
                duplicateCount += 1
            }
        }

        return duplicateCount
    }

    static func duplicateMessage(count: Int) -> String {
        let noun = count == 1 ? "player" : "players"
        return "\(count) possible duplicate \(noun) found by matching name and number."
    }

    private static func duplicateKey(for player: Player) -> String {
        let name = player.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let number = player.uniformNumber.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty else { return "" }
        return "\(name)#\(number)"
    }
}

struct SupportBundleExport: Identifiable {
    let id = UUID()
    let url: URL
}

struct AppBannerMessage: Identifiable, Equatable {
    enum Style: Equatable {
        case success
        case warning
    }

    let id = UUID()
    let text: String
    let style: Style
}

struct PartialRestorePrompt: Identifiable, Equatable {
    enum ItemType: Equatable {
        case team
        case player
    }

    let id = UUID()
    let itemID: UUID
    let itemType: ItemType
    let title: String
    let message: String
}

enum RestorePreparation: Equatable {
    case ready
    case blocked(String)
    case partialPrompt(PartialRestorePrompt)
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

struct TeamAppleMusicPlaylistSongRow: Equatable, Identifiable {
    var id: String { songID }
    var playerID: UUID
    var playerName: String
    var songID: String
    var title: String
    var artistName: String
}

enum TeamAppleMusicPlaylistSkipReason: String, Equatable {
    case missingCue
    case localAudio
    case builtInClip
    case previewOnlyAppleMusic

    var explanation: String {
        switch self {
        case .missingCue:
            return "No song cue selected"
        case .localAudio:
            return "Local audio cannot be added to Apple Music"
        case .builtInClip:
            return "Built-in clips cannot be added to Apple Music"
        case .previewOnlyAppleMusic:
            return "Preview-only Apple Music selections cannot be added"
        }
    }
}

struct TeamAppleMusicPlaylistSkippedCue: Equatable, Identifiable {
    var id: UUID { playerID }
    var playerID: UUID
    var playerName: String
    var title: String?
    var artistName: String?
    var reason: TeamAppleMusicPlaylistSkipReason
}

struct TeamAppleMusicPlaylistSummary: Equatable, Identifiable {
    var id: UUID { teamID }
    var teamID: UUID
    var teamName: String
    var playlistName: String
    var includedSongs: [TeamAppleMusicPlaylistSongRow]
    var skippedCues: [TeamAppleMusicPlaylistSkippedCue]
    var duplicateSongs: [TeamAppleMusicPlaylistSongRow]

    var songIDs: [String] {
        includedSongs.map(\.songID)
    }

    var canUpdatePlaylist: Bool {
        !includedSongs.isEmpty
    }

    init(team: Team) {
        teamID = team.id
        teamName = team.name
        playlistName = "Roll Call - \(team.name)"

        var seenSongIDs = Set<String>()
        var included: [TeamAppleMusicPlaylistSongRow] = []
        var skipped: [TeamAppleMusicPlaylistSkippedCue] = []
        var duplicates: [TeamAppleMusicPlaylistSongRow] = []

        for player in team.players {
            guard let cue = player.cue else {
                skipped.append(TeamAppleMusicPlaylistSkippedCue(
                    playerID: player.id,
                    playerName: player.displayName,
                    title: nil,
                    artistName: nil,
                    reason: .missingCue
                ))
                continue
            }

            switch cue.source {
            case .appleMusic(let source):
                let row = TeamAppleMusicPlaylistSongRow(
                    playerID: player.id,
                    playerName: player.displayName,
                    songID: source.songID,
                    title: source.title,
                    artistName: source.artistName
                )
                if source.isCatalogBacked == false {
                    skipped.append(TeamAppleMusicPlaylistSkippedCue(
                        playerID: player.id,
                        playerName: player.displayName,
                        title: source.title,
                        artistName: source.artistName,
                        reason: .previewOnlyAppleMusic
                    ))
                } else if seenSongIDs.insert(source.songID).inserted {
                    included.append(row)
                } else {
                    duplicates.append(row)
                }
            case .localAudio(let source):
                skipped.append(TeamAppleMusicPlaylistSkippedCue(
                    playerID: player.id,
                    playerName: player.displayName,
                    title: source.displayName,
                    artistName: nil,
                    reason: .localAudio
                ))
            case .builtInClip(let source):
                skipped.append(TeamAppleMusicPlaylistSkippedCue(
                    playerID: player.id,
                    playerName: player.displayName,
                    title: source.displayName,
                    artistName: nil,
                    reason: .builtInClip
                ))
            }
        }

        includedSongs = included
        skippedCues = skipped
        duplicateSongs = duplicates
    }
}

struct AppleMusicPlaylistRecovery: Equatable, Identifiable {
    var id = UUID()
    var summary: TeamAppleMusicPlaylistSummary
    var unresolvedSongs: [TeamAppleMusicPlaylistSongRow]
    var availableSongIDs: [String]
}

enum GameDayLineupProgressHintSource: Equatable {
    case nextButton
    case onDeckCard
}

struct GameDayLineupProgressHintEvent: Equatable {
    let id = UUID()
    let teamID: UUID
    let source: GameDayLineupProgressHintSource
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
    private enum RatingRequestPolicy {
        static let sessionThreshold = 10
        static let retrySessionIncrement = 10
        static let maxAutomaticPromptAttempts = 2
        static let cooldown: TimeInterval = 4 * 60 * 60
    }

    // Central default so a future settings UI can replace this with user selection.
    private let defaultNoSongFallbackBuiltInClipSourceID = "small-cheer"

    @Published var state: AppState
    @Published var isBusy = false
    @Published var lastError: String?
    @Published var bannerMessage: AppBannerMessage?
    @Published var exportURL: URL?
    @Published var pendingRosterImport: PendingRosterImport?
    @Published var pendingPackageImport: PendingPackageImport?
    @Published var completedPackageImportTeamID: UUID?
    @Published var supportBundle: SupportBundleExport?
    @Published private(set) var musicRenderProbeSamples = MusicRenderProbeScenario.allCases.map { MusicRenderProbeSample(scenario: $0) }
    @Published private(set) var musicRenderProbeLibraryCandidates: [MusicRenderProbeLibraryCandidate] = []
    @Published private(set) var musicRenderProbeCatalogCandidates: [MusicRenderProbeCatalogCandidate] = []
    @Published private(set) var isMusicRenderProbeLoadingLibrary = false
    @Published private(set) var isMusicRenderProbeSearchingCatalog = false
    @Published var musicRenderProbeSummaryURL: URL?
    @Published var announcerRegenerationStatus: AnnouncerRegenerationStatus?
    @Published private(set) var isAppleMusicPlaylistSyncing = false
    @Published private(set) var appleMusicPlaylistSyncStatus: String?
    @Published private(set) var appleMusicPlaylistRecovery: AppleMusicPlaylistRecovery?
    @Published private(set) var appleMusicPlaybackCapability: AppleMusicPlaybackCapability = .unknown
    @Published private(set) var customAnnouncerRecordingPhase: CustomAnnouncerRecordingPhase = .idle
    @Published var pendingRecoveryNavigationToken: UUID?
    @Published private(set) var gameDayLineupProgressHintEvent: GameDayLineupProgressHintEvent?
    @Published private(set) var pendingSongClipPreparationCount = 0
    private var hasFinishedLaunching = false
    private let persistenceWriter = StatePersistenceWriter()
    private var persistSequence = 0
    private var readinessRefreshTask: Task<Void, Never>?
    private var audioRouteChangeTask: Task<Void, Never>?
    private var outputVolumeObservation: NSKeyValueObservation?
    private var prewarmTask: Task<Void, Never>?
    private var startupWarmupTask: Task<Void, Never>?
    private var announcerRegenerationTask: Task<Void, Never>?
    private var pendingIncomingPackageURLs: [URL] = []
    private var isPreparingIncomingPackagePreview = false
    private var initialStateLoadWarning: String?
    private var bannerDismissTask: Task<Void, Never>?
    private var songClipPreparationTask: Task<Void, Never>?
    private var lowPowerModeTask: Task<Void, Never>?

    let audioAssetService = AudioAssetService()
    let musicCatalogService = MusicCatalogService()
    let musicRenderProbeService: MusicRenderProbeService
    let packageService = PackageService()
    let announcerRenderer = AnnouncerSpeechRenderer()
    let haptics = GameDayHaptics()
    let readinessService: ReadinessService
    let playbackEngine: CuePlaybackEngine
    let customAnnouncerRecorder = CustomAnnouncerRecorder()
    let songClipGenerationService = SongClipGenerationService()
    private let songClipGenerationQueue = SongClipGenerationQueue()

    var featureFlags: FeatureFlags {
        FeatureFlags(environment: .current, experimental: state.experimental)
    }

    var hasUnseenWhatsNew: Bool {
        state.lastSeenWhatsNewReleaseID != AppMetadata.whatsNewReleaseID
    }

    var hasEarnedRatingRequest: Bool {
        state.ratingRequest.successfulGameDaySessionCount >= RatingRequestPolicy.sessionThreshold
    }

    var canPresentAutomaticRatingRequest: Bool {
        state.ratingRequest.successfulGameDaySessionCount >= state.ratingRequest.nextAutomaticPromptSessionThreshold
            && state.ratingRequest.automaticPromptAttemptCount < RatingRequestPolicy.maxAutomaticPromptAttempts
    }

    var ratingRequestDebugSummary: String {
        let count = state.ratingRequest.successfulGameDaySessionCount
        let nextThreshold = state.ratingRequest.nextAutomaticPromptSessionThreshold
        let attempts = state.ratingRequest.automaticPromptAttemptCount
        return "\(count) sessions, attempt \(attempts)/\(RatingRequestPolicy.maxAutomaticPromptAttempts), next auto at \(nextThreshold)"
    }

    init() {
        FeatureFlags.assertReleaseSafety()
        self.musicRenderProbeService = MusicRenderProbeService(audioAssetService: audioAssetService, musicCatalogService: musicCatalogService)
        self.playbackEngine = CuePlaybackEngine(audioAssetService: audioAssetService, musicCatalogService: musicCatalogService)
        self.readinessService = ReadinessService(audioAssetService: audioAssetService)
        let loadResult = Self.loadInitialState()
        self.state = loadResult.state
        self.initialStateLoadWarning = loadResult.warning
        self.state.appVersion = AppMetadata.appVersion
        self.state.schemaVersion = max(self.state.schemaVersion, AppState.empty.schemaVersion)
        normalizeRatingRequestPolicyState()
        self.playbackEngine.setAppleMusicTransitionCrossfadeExperimentEnabled(
            FeatureFlags(environment: .current, experimental: self.state.experimental).appleMusicTransitionCrossfadeEnabled
        )
        self.readinessService.onPathStatusChange = { [weak self] in
            self?.scheduleReadinessRefresh()
        }
        observeReadinessInputs()
        observeLowPowerMode()
        FeatureFlags.assertReleaseSafety(featureFlags)
        normalizeSelectedTeamIfNeeded()
        normalizeAllTeams()
        purgeExpiredRecentlyDeletedItems()
        reconcileOnboardingForExistingTeamIfNeeded()
        if let initialStateLoadWarning {
            lastError = initialStateLoadWarning
        }
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
            scheduleAllSongClipPreparation(trigger: .appLaunch)
            persist()
            await preparePendingIncomingPackageIfNeeded()
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
        Task { await self.preparePendingIncomingPackageIfNeeded() }
    }

    var selectedTeam: Team? {
        state.teams.first(where: { $0.id == state.selectedTeamID })
    }

    var shouldShowOnboarding: Bool {
        state.teams.isEmpty || state.onboarding.activeFlow != nil || !state.onboarding.isComplete
    }

    private func reconcileOnboardingForExistingTeamIfNeeded() {
        guard !state.onboarding.isComplete,
              state.onboarding.activeFlow == .automatic,
              state.teams.contains(where: { !$0.players.isEmpty }) else {
            return
        }

        state.onboarding = .completed()
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
            session: TeamSessionState(activeSessionDate: nil, battingOrder: [], nextBatterIndex: 0, gameDayAnnouncerMode: .announcerAndSong, battingOrderIsCustomized: false),
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
        guard let teamIndex, let team = selectedTeam else { return }
        addRecentlyDeletedItem(
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .team(DeletedTeamRecord(team: team))
            )
        )
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
        let previousPlayer = state.teams[teamIndex].players[playerIndex]
        state.teams[teamIndex].players[playerIndex] = player
        state.teams[teamIndex].modifiedAt = .now
        normalizeLineup(for: teamIndex)
        removeAssetsNoLongerReferenced(from: previousPlayer, to: player)
        prewarmNextBatterCue()
        scheduleReadinessRefresh()
        persist()
        if previousPlayer.songAssignment != player.songAssignment {
            if player.songAssignment == nil {
                Task {
                    await songClipGenerationQueue.cancel(teamID: state.teams[teamIndex].id, playerID: player.id)
                    await refreshPendingSongClipPreparationCount()
                }
            } else {
                scheduleSongClipPreparation(
                    teamID: state.teams[teamIndex].id,
                    playerID: player.id,
                    trigger: .assignmentSaved
                )
            }
        }
    }

    func removePlayer(_ player: Player) {
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == player.id }) else { return }
        let team = state.teams[teamIndex]
        let removed = state.teams[teamIndex].players.remove(at: playerIndex)
        addRecentlyDeletedItem(
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .player(
                    DeletedPlayerRecord(
                        player: removed,
                        originalTeamID: team.id,
                        originalTeamName: team.name,
                        previousBattingOrder: team.session.battingOrder
                    )
                )
            )
        )
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

    func refreshGameDayWarmup() {
        prewarmNextBatterCue()
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

    func makeAppleMusicCueDraft(_ result: MusicSearchResult) -> Cue {
        makeDefaultAppleMusicCue(for: result)
    }

    func makeImportedSongCueDraft(from url: URL) async -> Cue? {
        do {
            let source = try await audioAssetService.importMedia(from: url)
            return .localDefault(source: source)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func discardImportedSongCueDraft(_ cue: Cue) {
        guard case .localAudio(let source) = cue.source else { return }
        audioAssetService.removeAsset(relativePath: source.relativePath)
    }

    func saveSongCue(_ cue: Cue, to playerID: UUID) {
        guard let teamIndex,
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return
        }
        var updated = state.teams[teamIndex].players[playerIndex]
        updated.cue = cue
        if case .appleMusic(let source) = cue.source {
            rememberAppleMusicSelection(
                MusicSearchResult(
                    songID: source.songID,
                    title: source.title,
                    artistName: source.artistName,
                    duration: source.duration,
                    previewURL: source.previewURL,
                    isCatalogBacked: source.isCatalogBacked ?? true
                )
            )
        }
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
                let replacementRelativePath = self.assetIsReferenced(relativePath: player.customAnnouncerRelativePath, byAnyPlayerOtherThan: player.id)
                    ? self.audioAssetService.freshCustomAnnouncerRelativePath()
                    : nil
                asset = try audioAssetService.storeCustomAnnouncerRecording(
                    from: recordedURL,
                    playerID: player.id,
                    displayName: "\(player.displayName)-custom-announcer",
                    relativePath: replacementRelativePath
                )
            } catch {
                throw AppError.customIntroSaveFailed("recorded file could not be reopened. \(customIntroFileSummary(for: recordedURL)); reader error: \(customIntroErrorSummary(error))")
            }
            guard audioAssetService.assetExists(relativePath: asset.relativePath) else {
                throw AppError.customIntroSaveFailed("saved flat asset was not visible at \(asset.relativePath)")
            }
            try? FileManager.default.removeItem(at: recordedURL)
            var updated = player
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
            markGameDayPlayerCuePlayedForRating()
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

    var musicRenderProbeAuthorizationStatusText: String {
        switch MusicAuthorization.currentStatus {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    var musicRenderProbePlaybackCapabilityText: String {
        switch appleMusicPlaybackCapability {
        case .unknown:
            return "Unknown"
        case .previewOnly:
            return "Preview Only"
        case .fullSong:
            return "Full Song"
        }
    }

    var musicRenderProbeLocalCandidates: [MusicRenderProbeLocalCandidate] {
        var seenRelativePaths = Set<String>()
        var candidates: [MusicRenderProbeLocalCandidate] = []

        for team in state.teams {
            for player in team.players {
                guard let cue = player.cue,
                      case .localAudio(let source) = cue.source,
                      seenRelativePaths.insert(source.relativePath).inserted else {
                    continue
                }

                candidates.append(
                    MusicRenderProbeLocalCandidate(
                        id: player.id,
                        source: source,
                        teamName: team.name,
                        playerName: player.displayName
                    )
                )
            }
        }

        return candidates.sorted {
            if $0.source.displayName.localizedCaseInsensitiveCompare($1.source.displayName) == .orderedSame {
                return $0.playerName.localizedCaseInsensitiveCompare($1.playerName) == .orderedAscending
            }
            return $0.source.displayName.localizedCaseInsensitiveCompare($1.source.displayName) == .orderedAscending
        }
    }

    var musicRenderProbeSummary: MusicRenderProbeRedactedSummary? {
        guard musicRenderProbeSamples.contains(where: { $0.selection != nil || $0.result != nil }) else {
            return nil
        }

        return MusicRenderProbeRedactedSummary.make(
            samples: musicRenderProbeSamples,
            authorizationStatus: musicRenderProbeAuthorizationStatusText,
            playbackCapability: musicRenderProbePlaybackCapabilityText
        )
    }

    func searchAppleMusic(term: String) async throws -> [MusicSearchResult] {
        await refreshAppleMusicPlaybackCapability()
        let mode: AppleMusicSearchMode = appleMusicPlaybackCapability == .fullSong ? .catalogOnly : .previewFallback
        return try await musicCatalogService.search(term: term, mode: mode)
    }

    func loadMusicRenderProbeLibraryCandidates() async {
        isMusicRenderProbeLoadingLibrary = true
        defer { isMusicRenderProbeLoadingLibrary = false }

        if MusicAuthorization.currentStatus == .notDetermined {
            _ = await requestAppleMusicAccess()
        } else {
            await refreshAppleMusicPlaybackCapability()
        }

        guard MusicAuthorization.currentStatus == .authorized else {
            lastError = AppError.musicAuthorizationRequired.localizedDescription
            return
        }

        do {
            musicRenderProbeLibraryCandidates = try musicRenderProbeService.loadLibraryCandidates()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func searchMusicRenderProbeCatalog(term: String) async {
        isMusicRenderProbeSearchingCatalog = true
        defer { isMusicRenderProbeSearchingCatalog = false }

        do {
            musicRenderProbeCatalogCandidates = try await searchAppleMusic(term: term).map {
                MusicRenderProbeCatalogCandidate(
                    songID: $0.songID,
                    title: $0.title,
                    artistName: $0.artistName,
                    duration: $0.duration,
                    previewURL: $0.previewURL,
                    isCatalogBacked: $0.isCatalogBacked
                )
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func assignMusicRenderProbeLibraryCandidate(_ candidate: MusicRenderProbeLibraryCandidate, to scenario: MusicRenderProbeScenario) {
        updateMusicRenderProbeSample(for: scenario) { sample in
            sample.selection = .library(candidate)
            sample.result = nil
        }
    }

    func assignMusicRenderProbeCatalogCandidate(_ candidate: MusicRenderProbeCatalogCandidate, to scenario: MusicRenderProbeScenario) {
        updateMusicRenderProbeSample(for: scenario) { sample in
            sample.selection = .catalog(candidate)
            sample.result = nil
        }
    }

    func assignMusicRenderProbeLocalCandidate(_ candidate: MusicRenderProbeLocalCandidate, to scenario: MusicRenderProbeScenario) {
        updateMusicRenderProbeSample(for: scenario) { sample in
            sample.selection = .local(candidate)
            sample.result = nil
        }
    }

    func clearMusicRenderProbeSample(for scenario: MusicRenderProbeScenario) {
        updateMusicRenderProbeSample(for: scenario) { sample in
            sample.selection = nil
            sample.result = nil
        }
    }

    func runMusicRenderProbe(for scenario: MusicRenderProbeScenario) async {
        guard let sample = musicRenderProbeSamples.first(where: { $0.scenario == scenario }) else { return }
        guard sample.selection != nil else {
            lastError = "Choose a sample before running the probe."
            return
        }

        let result = await musicRenderProbeService.runProbe(for: sample)
        updateMusicRenderProbeSample(for: scenario) { $0.result = result }
    }

    func runAllAssignedMusicRenderProbes() async {
        for sample in musicRenderProbeSamples where sample.selection != nil {
            await runMusicRenderProbe(for: sample.scenario)
        }
    }

    func exportMusicRenderProbeSummary() {
        guard let summary = musicRenderProbeSummary else { return }

        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("RollCall-MusicRenderProbe-\(UUID().uuidString).json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(summary).write(to: url, options: .atomic)
            musicRenderProbeSummaryURL = url
        } catch {
            lastError = error.localizedDescription
        }
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
        advanceNextBatter(hintSource: .nextButton)
    }

    func advanceNextBatterFromOnDeck() {
        advanceNextBatter(hintSource: .onDeckCard)
    }

    private func advanceNextBatter(hintSource: GameDayLineupProgressHintSource) {
        guard let teamIndex else { return }
        let present = state.teams[teamIndex].presentPlayersInBattingOrder
        guard !present.isEmpty else {
            haptics.warning(isEnabled: state.settings.hapticsEnabled)
            return
        }
        state.teams[teamIndex].session.nextBatterIndex = (state.teams[teamIndex].session.nextBatterIndex + 1) % present.count
        state.teams[teamIndex].modifiedAt = .now
        gameDayLineupProgressHintEvent = GameDayLineupProgressHintEvent(teamID: state.teams[teamIndex].id, source: hintSource)
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

    func setKeepScreenAwakeDuringLiveUse(_ isEnabled: Bool) {
        state.settings.keepScreenAwakeDuringLiveUse = isEnabled
        persist()
    }

    func setShowLineupProgressHints(_ isEnabled: Bool) {
        state.settings.showLineupProgressHints = isEnabled
        persist()
    }

    func setSongClipPreparationLiveUsePaused(_ paused: Bool) {
        Task {
            await songClipGenerationQueue.setPaused(paused, reason: .liveUse)
            if !paused {
                await runSongClipPreparationQueueIfNeeded()
            }
            await refreshPendingSongClipPreparationCount()
        }
    }

    func prepareSongClipForPlayerEditor(_ playerID: UUID) {
        guard let teamID = selectedTeam?.id else { return }
        scheduleSongClipPreparation(teamID: teamID, playerID: playerID, trigger: .playerEditor)
    }

    func prepareSongsForReadiness() {
        scheduleAllSongClipPreparation(trigger: .readiness)
    }

    func prepareSongsAfterForeground() {
        scheduleAllSongClipPreparation(trigger: .foreground)
    }

    func tryPreparingSongNow(for playerID: UUID) {
        guard let teamID = selectedTeam?.id else { return }
        scheduleSongClipPreparation(
            teamID: teamID,
            playerID: playerID,
            trigger: .explicitTryNow,
            isExplicit: true
        )
    }

    func markCurrentWhatsNewSeen() {
        state.lastSeenWhatsNewReleaseID = AppMetadata.whatsNewReleaseID
        persist()
    }

    func resetWhatsNewSeenForTesting() {
        state.lastSeenWhatsNewReleaseID = nil
        persist()
    }

    func beginGameDayVisitForRatingIfNeeded() {
        guard state.ratingRequest.hasPlayedQualifyingCueInCurrentGameDayVisit
                || state.ratingRequest.hasCountedCurrentGameDayVisit else { return }
        state.ratingRequest.hasPlayedQualifyingCueInCurrentGameDayVisit = false
        state.ratingRequest.hasCountedCurrentGameDayVisit = false
        persist()
    }

    func finalizeGameDayVisitForRatingIfNeeded(at date: Date = .now) {
        guard state.ratingRequest.hasPlayedQualifyingCueInCurrentGameDayVisit,
              !state.ratingRequest.hasCountedCurrentGameDayVisit else { return }

        if shouldCountSuccessfulGameDaySession(at: date) {
            state.ratingRequest.successfulGameDaySessionCount += 1
            state.ratingRequest.lastCountedSuccessfulGameDaySessionAt = date
        }
        state.ratingRequest.hasCountedCurrentGameDayVisit = true
        persist()
    }

    func markAutomaticRatingPromptAttempted() {
        guard state.ratingRequest.automaticPromptAttemptCount < RatingRequestPolicy.maxAutomaticPromptAttempts else { return }
        state.ratingRequest.automaticPromptAttemptCount += 1
        if state.ratingRequest.automaticPromptAttemptCount < RatingRequestPolicy.maxAutomaticPromptAttempts {
            state.ratingRequest.nextAutomaticPromptSessionThreshold += RatingRequestPolicy.retrySessionIncrement
        }
        persist()
    }

    func setRatingThresholdMetForTesting(_ isMet: Bool) {
        state.ratingRequest.successfulGameDaySessionCount = isMet ? RatingRequestPolicy.sessionThreshold : 0
        state.ratingRequest.hasPlayedQualifyingCueInCurrentGameDayVisit = false
        state.ratingRequest.hasCountedCurrentGameDayVisit = false
        state.ratingRequest.lastCountedSuccessfulGameDaySessionAt = nil
        state.ratingRequest.automaticPromptAttemptCount = 0
        state.ratingRequest.nextAutomaticPromptSessionThreshold = RatingRequestPolicy.sessionThreshold
        persist()
    }

    private func normalizeRatingRequestPolicyState() {
        let attemptCount = max(0, min(state.ratingRequest.automaticPromptAttemptCount, RatingRequestPolicy.maxAutomaticPromptAttempts))
        let retrySteps = min(attemptCount, RatingRequestPolicy.maxAutomaticPromptAttempts - 1)
        state.ratingRequest.nextAutomaticPromptSessionThreshold = RatingRequestPolicy.sessionThreshold
            + (retrySteps * RatingRequestPolicy.retrySessionIncrement)
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
        playbackEngine.setAppleMusicTransitionCrossfadeExperimentEnabled(featureFlags.appleMusicTransitionCrossfadeEnabled)
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

    func setAppleMusicTransitionCrossfadeEnabled(_ isEnabled: Bool) {
        state.experimental.appleMusicTransitionCrossfadeEnabled = isEnabled
        playbackEngine.setAppleMusicTransitionCrossfadeExperimentEnabled(featureFlags.appleMusicTransitionCrossfadeEnabled)
        persist()
    }

    private func markGameDayPlayerCuePlayedForRating() {
        guard !state.ratingRequest.hasPlayedQualifyingCueInCurrentGameDayVisit else { return }
        state.ratingRequest.hasPlayedQualifyingCueInCurrentGameDayVisit = true
        persist()
    }

    private func shouldCountSuccessfulGameDaySession(at date: Date) -> Bool {
        guard let lastCountedAt = state.ratingRequest.lastCountedSuccessfulGameDaySessionAt else {
            return true
        }
        return date.timeIntervalSince(lastCountedAt) >= RatingRequestPolicy.cooldown
    }

    func selectedTeamAppleMusicPlaylistSummary() -> TeamAppleMusicPlaylistSummary? {
        guard let team = selectedTeam else { return nil }
        return TeamAppleMusicPlaylistSummary(team: team)
    }

    func clearAppleMusicPlaylistStatus() {
        appleMusicPlaylistSyncStatus = nil
        appleMusicPlaylistRecovery = nil
    }

    func cancelAppleMusicPlaylistRecovery() {
        appleMusicPlaylistRecovery = nil
        appleMusicPlaylistSyncStatus = "Playlist update canceled. Apple Music was not changed."
    }

    func continueAppleMusicPlaylistUpdate(_ recovery: AppleMusicPlaylistRecovery) async {
        appleMusicPlaylistRecovery = nil
        await syncAppleMusicPlaylist(summary: recovery.summary, songIDs: recovery.availableSongIDs, allowsRecovery: false)
    }

    func syncAppleMusicPlaylist(summary: TeamAppleMusicPlaylistSummary) async {
        await syncAppleMusicPlaylist(summary: summary, songIDs: summary.songIDs, allowsRecovery: true)
    }

    private func syncAppleMusicPlaylist(
        summary: TeamAppleMusicPlaylistSummary,
        songIDs: [String],
        allowsRecovery: Bool
    ) async {
        guard !isAppleMusicPlaylistSyncing else { return }
        guard !songIDs.isEmpty else {
            appleMusicPlaylistSyncStatus = AppError.noAppleMusicTeamCues.localizedDescription
            return
        }

        isAppleMusicPlaylistSyncing = true
        appleMusicPlaylistSyncStatus = "Saving \"\(summary.playlistName)\"..."
        defer { isAppleMusicPlaylistSyncing = false }

        do {
            let resolved = try await musicCatalogService.resolveTeamPlaylistSongs(songIDs: songIDs)
            if !resolved.unresolvedSongIDs.isEmpty {
                if allowsRecovery {
                    let unresolvedIDSet = Set(resolved.unresolvedSongIDs)
                    appleMusicPlaylistRecovery = AppleMusicPlaylistRecovery(
                        summary: summary,
                        unresolvedSongs: summary.includedSongs.filter { unresolvedIDSet.contains($0.songID) },
                        availableSongIDs: resolved.resolvedSongIDs
                    )
                    appleMusicPlaylistSyncStatus = "Apple Music could not find \(resolved.unresolvedSongIDs.count) \(resolved.unresolvedSongIDs.count == 1 ? "song" : "songs"). Review before continuing."
                    haptics.warning(isEnabled: state.settings.hapticsEnabled)
                    return
                } else {
                    appleMusicPlaylistSyncStatus = "Apple Music could not find every selected song. Playlist was not changed."
                    haptics.warning(isEnabled: state.settings.hapticsEnabled)
                    return
                }
            }
            guard !resolved.songs.isEmpty else {
                appleMusicPlaylistSyncStatus = AppError.noAppleMusicTeamCues.localizedDescription
                return
            }

            try await musicCatalogService.replaceTeamPlaylist(name: summary.playlistName, songs: resolved.songs)
            var message = "Saved \"\(summary.playlistName)\" with \(resolved.songs.count) \(resolved.songs.count == 1 ? "song" : "songs")."
            let skippedCount = summary.skippedCues.count
            if skippedCount > 0 {
                message += " Skipped \(skippedCount) unsupported \(skippedCount == 1 ? "cue" : "cues")."
            }
            let duplicateCount = summary.duplicateSongs.count
            if duplicateCount > 0 {
                message += " Added \(duplicateCount == 1 ? "1 duplicate song" : "\(duplicateCount) duplicate songs") once."
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

    func preparePackageImportConfirmation(from url: URL, opensOnboardingHandoff: Bool) async {
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            let manifest = try packageService.preview(packageURL: url)
            pendingPackageImport = PendingPackageImport(
                url: url,
                manifest: manifest,
                opensOnboardingHandoff: opensOnboardingHandoff
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func confirmPendingPackageImport() async {
        guard let pendingPackageImport else { return }
        self.pendingPackageImport = nil
        await performPackageImport(
            from: pendingPackageImport.url,
            opensOnboardingHandoff: pendingPackageImport.opensOnboardingHandoff
        )
        await preparePendingIncomingPackageIfNeeded()
    }

    func cancelPendingPackageImport() {
        pendingPackageImport = nil
        Task { await self.preparePendingIncomingPackageIfNeeded() }
    }

    private func performPackageImport(from url: URL, opensOnboardingHandoff: Bool) async {
        await busy {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            _ = try self.packageService.preview(packageURL: url)
            try await self.createBackupBeforeRiskyOperation(reason: "Automatic backup before package import")
            let manifest = try self.packageService.import(packageURL: url, audioAssetService: self.audioAssetService)
            var imported = manifest.team
            imported.id = UUID()
            imported.name += " Imported"
            self.state.teams.append(imported)
            self.state.selectedTeamID = imported.id
            self.normalizeLineup(for: self.state.teams.count - 1)
            if opensOnboardingHandoff {
                self.state.onboarding = .completed()
            }
            self.completedPackageImportTeamID = imported.id
            self.persist()
            for player in imported.players where player.songAssignment?.privateClip != nil {
                self.scheduleSongClipPreparation(
                    teamID: imported.id,
                    playerID: player.id,
                    trigger: .importRepair
                )
            }
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

    func applyPendingRosterImport() async {
        await busy {
            guard let teamIndex = self.teamIndex, let pendingRosterImport = self.pendingRosterImport else { return }
            try await self.createBackupBeforeRiskyOperation(reason: "Automatic backup before roster CSV import")
            self.state.teams[teamIndex].players.append(contentsOf: pendingRosterImport.rows)
            self.state.teams[teamIndex].session.battingOrder.append(contentsOf: pendingRosterImport.rows.map(\.id))
            self.state.teams[teamIndex].modifiedAt = .now
            self.normalizeLineup(for: teamIndex)
            self.pendingRosterImport = nil
            self.prewarmNextBatterCue()
            self.scheduleReadinessRefresh()
        }
    }

    func discardPendingRosterImport() {
        pendingRosterImport = nil
    }

    func refreshReadiness() {
        state.lastReadiness = readinessService.snapshot(for: selectedTeam)
    }

    var needsAppleMusicAccessPrompt: Bool {
        MusicAuthorization.currentStatus == .notDetermined
    }

    @discardableResult
    func requestAppleMusicAccess() async -> MusicAuthorization.Status {
        let status = await MusicAuthorization.request()
        await refreshAppleMusicPlaybackCapability()
        refreshReadiness()
        scheduleAllSongClipPreparation(trigger: .authorizationChanged)
        return status
    }

    func createBackup(reason: String) {
        let snapshotState = backupSnapshotState(from: state)
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

    private func createBackupBeforeRiskyOperation(reason: String) async throws {
        let snapshotState = backupSnapshotState(from: state)
        let snapshotRecord = try await writeBackupRecord(for: snapshotState, reason: reason).get()
        insertBackupRecord(snapshotRecord)
        persist()
    }

    func refreshRecoveryState() {
        if purgeExpiredRecentlyDeletedItems() {
            persist()
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
            let currentLastSeenWhatsNewReleaseID = self.state.lastSeenWhatsNewReleaseID
            let currentSchemaVersion = self.state.schemaVersion
            let currentRecentlyDeleted = self.state.recentlyDeleted

            let restoredState = try await Task.detached(priority: .utility) { () -> AppState in
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                var restoredState = try decoder.decode(AppState.self, from: Data(contentsOf: sourceURL))
                restoredState.appVersion = currentVersion
                restoredState.deviceIdentity = currentDeviceIdentity
                restoredState.settings = currentSettings
                restoredState.lastSeenWhatsNewReleaseID = currentLastSeenWhatsNewReleaseID
                restoredState.schemaVersion = max(restoredState.schemaVersion, currentSchemaVersion)
                restoredState.recentlyDeleted = currentRecentlyDeleted
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

    func restorePreparation(for item: RecentlyDeletedItem) -> RestorePreparation {
        switch item.payload {
        case .team(let deletedTeam):
            let missingSummary = missingMediaSummary(for: deletedTeam.team)
            guard !missingSummary.hasMissingMedia else { return .partialPrompt(teamPartialPrompt(for: item, team: deletedTeam.team, summary: missingSummary)) }
            return .ready
        case .player(let deletedPlayer):
            guard state.teams.contains(where: { $0.id == deletedPlayer.originalTeamID }) else {
                return .blocked("Restore the team first to bring this player back.")
            }
            let missingTypes = missingMediaTypes(for: deletedPlayer.player)
            guard !missingTypes.isEmpty else { return .ready }
            return .partialPrompt(playerPartialPrompt(for: item, player: deletedPlayer.player, missingTypes: missingTypes))
        }
    }

    func restoreRecentlyDeletedItem(_ item: RecentlyDeletedItem, allowPartial: Bool = false) {
        switch item.payload {
        case .team(let deletedTeam):
            let summary = missingMediaSummary(for: deletedTeam.team)
            if summary.hasMissingMedia && !allowPartial {
                lastError = "Roll Call could not fully restore \(deletedTeam.team.name). Choose Restore What We Can to bring back the team without the missing media."
                return
            }
            restoreDeletedTeam(item, deletedTeam: deletedTeam, partialSummary: summary.hasMissingMedia ? summary : nil)
        case .player(let deletedPlayer):
            guard state.teams.contains(where: { $0.id == deletedPlayer.originalTeamID }) else {
                lastError = "Restore the team first to bring this player back."
                return
            }
            let missingTypes = missingMediaTypes(for: deletedPlayer.player)
            if !missingTypes.isEmpty && !allowPartial {
                lastError = "Roll Call could not fully restore \(deletedPlayer.player.displayName). Choose Restore What We Can to bring back the player without the missing media."
                return
            }
            restoreDeletedPlayer(item, deletedPlayer: deletedPlayer, missingTypes: missingTypes)
        }
    }

    func permanentlyDeleteRecentlyDeletedItem(_ item: RecentlyDeletedItem) {
        guard let itemIndex = state.recentlyDeleted.firstIndex(where: { $0.id == item.id }) else { return }
        state.recentlyDeleted.remove(at: itemIndex)
        removeStoredAssetsForDeletedItemIfUnreferenced(item)
        persist()
    }

    func recoveryTeamName(for deletedPlayer: DeletedPlayerRecord) -> String {
        state.teams.first(where: { $0.id == deletedPlayer.originalTeamID })?.name ?? deletedPlayer.originalTeamName
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

    private func playableCueForPlayerPlayback(_ player: Player) -> Cue? {
        if let cue = player.cue, cueIsPlayable(cue) {
            return cue
        }
        return fallbackCue(for: player, cueID: playbackID(for: player))
    }

    private func fallbackCue(for player: Player, cueID: UUID? = nil) -> Cue? {
        let teamBuiltIns = selectedTeam?.builtInClips ?? []
        if let fallbackClip = BuiltInClip.firstMatchingSourceID(defaultNoSongFallbackBuiltInClipSourceID, in: teamBuiltIns) {
            var cue = fallbackClip.cue
            cue.id = cueID ?? player.id
            if cueIsPlayable(cue) {
                return cue
            }
        }
        if let fallbackClip = BuiltInClip.firstMatchingSourceID(defaultNoSongFallbackBuiltInClipSourceID, in: BuiltInClip.defaults) {
            var cue = fallbackClip.cue
            cue.id = cueID ?? player.id
            if cueIsPlayable(cue) {
                return cue
            }
        }
        return nil
    }

    private func cueIsPlayable(_ cue: Cue) -> Bool {
        switch cue.source {
        case .appleMusic:
            return true
        case .localAudio(let source):
            return audioAssetService.assetExists(relativePath: source.relativePath)
        case .builtInClip(let source):
            return audioAssetService.builtInClipExists(source: source)
        }
    }

    private func playbackPlan(for player: Player) -> PlayerPlaybackPlan? {
        let mode = selectedTeam?.session.gameDayAnnouncerMode ?? .announcerAndSong
        let announcerRelativePath = storedCustomAnnouncerRelativePath(for: player)
        switch mode {
        case .announcerOnly:
            if let announcerRelativePath {
                return .assetOnly(relativePath: announcerRelativePath, activeCueID: playbackID(for: player))
            }
            guard let fallbackCue = fallbackCue(for: player, cueID: playbackID(for: player)) else { return nil }
            return .cue(cue: fallbackCue, announcerRelativePath: nil)
        case .announcerAndSong:
            guard let cue = playableCueForPlayerPlayback(player) else { return nil }
            return .cue(cue: cue, announcerRelativePath: announcerRelativePath)
        case .songOnly:
            guard let cue = playableCueForPlayerPlayback(player) else { return nil }
            return .cue(cue: cue, announcerRelativePath: nil)
        }
    }

    private func playbackID(for player: Player) -> UUID {
        player.cue?.id ?? player.id
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

    private func removeStoredAssetsIfUnreferenced(for player: Player) {
        storedAssetRelativePaths(for: player).forEach(removeAssetIfUnreferenced(relativePath:))
    }

    private func removeAssetsNoLongerReferenced(from previousPlayer: Player, to updatedPlayer: Player) {
        let updatedPaths = Set(storedAssetRelativePaths(for: updatedPlayer))
        storedAssetRelativePaths(for: previousPlayer)
            .filter { !updatedPaths.contains($0) }
            .forEach(removeAssetIfUnreferenced(relativePath:))
    }

    func applyGeneratedBuiltInAnnouncerAsset(
        _ asset: GeneratedAnnouncerAsset?,
        toPlayerID playerID: UUID,
        onTeamID teamID: UUID
    ) {
        guard let teamIndex = state.teams.firstIndex(where: { $0.id == teamID }),
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return
        }

        let previousPlayer = state.teams[teamIndex].players[playerIndex]
        state.teams[teamIndex].players[playerIndex].generatedBuiltInAnnouncerRelativePath = asset?.relativePath
        let updatedPlayer = state.teams[teamIndex].players[playerIndex]

        if let asset {
            state.teams[teamIndex].announcerProfile.applyResolvedVoice(from: asset)
        }

        state.teams[teamIndex].modifiedAt = .now
        removeAssetsNoLongerReferenced(from: previousPlayer, to: updatedPlayer)
    }

    private func removeAssetIfUnreferenced(relativePath: String) {
        guard !assetIsReferenced(relativePath: relativePath) else { return }
        audioAssetService.removeAsset(relativePath: relativePath)
    }

    private func assetIsReferenced(relativePath: String?, byAnyPlayerOtherThan ignoredPlayerID: UUID? = nil) -> Bool {
        guard let relativePath else { return false }
        if state.teams.contains(where: { team in
            team.players.contains { player in
                guard player.id != ignoredPlayerID else { return false }
                return storedAssetRelativePaths(for: player).contains(relativePath)
            }
        }) {
            return true
        }
        return state.recentlyDeleted.contains { item in
            storedAssetRelativePaths(for: item).contains(relativePath)
        }
    }

    private func storedAssetRelativePaths(for player: Player) -> [String] {
        var paths: [String] = []
        if let photoRelativePath = player.photoRelativePath {
            paths.append(photoRelativePath)
        }
        if let customAnnouncerRelativePath = player.customAnnouncerRelativePath {
            paths.append(customAnnouncerRelativePath)
        }
        if let generatedBuiltInAnnouncerRelativePath = player.generatedBuiltInAnnouncerRelativePath {
            paths.append(generatedBuiltInAnnouncerRelativePath)
        }
        if case .localAudio(let source)? = player.cue?.source {
            paths.append(source.relativePath)
        }
        if let generatedRelativePath = player.songAssignment?.privateClip?.generatedAsset.relativePath {
            paths.append(generatedRelativePath)
        }
        return paths
    }

    private func storedAssetRelativePaths(for team: Team) -> [String] {
        team.players.flatMap(storedAssetRelativePaths(for:))
    }

    private func storedAssetRelativePaths(for item: RecentlyDeletedItem) -> [String] {
        switch item.payload {
        case .team(let deletedTeam):
            return storedAssetRelativePaths(for: deletedTeam.team)
        case .player(let deletedPlayer):
            return storedAssetRelativePaths(for: deletedPlayer.player)
        }
    }

    private func addRecentlyDeletedItem(_ item: RecentlyDeletedItem) {
        _ = purgeExpiredRecentlyDeletedItems()
        state.recentlyDeleted.insert(item, at: 0)
    }

    @discardableResult
    private func purgeExpiredRecentlyDeletedItems(now: Date = .now) -> Bool {
        let expiredItems = state.recentlyDeleted.filter { $0.expiresAt <= now }
        guard !expiredItems.isEmpty else { return false }
        state.recentlyDeleted.removeAll { $0.expiresAt <= now }
        expiredItems.forEach(removeStoredAssetsForDeletedItemIfUnreferenced)
        return true
    }

    private func backupSnapshotState(from state: AppState) -> AppState {
        var snapshotState = state
        snapshotState.recentlyDeleted = []
        return snapshotState
    }

    private func removeStoredAssetsForDeletedItemIfUnreferenced(_ item: RecentlyDeletedItem) {
        storedAssetRelativePaths(for: item).forEach(removeAssetIfUnreferenced(relativePath:))
    }

    private enum MissingMediaType: String {
        case song = "song"
        case photo = "photo"
        case announcementCue = "Announcement Cue"
    }

    private struct MissingMediaSummary {
        var songCount = 0
        var photoCount = 0
        var announcementCueCount = 0

        var hasMissingMedia: Bool {
            songCount > 0 || photoCount > 0 || announcementCueCount > 0
        }

        var warningText: String {
            var segments: [String] = []
            if songCount > 0 {
                segments.append("\(songCount) \(songCount == 1 ? "player is" : "players are") missing song audio")
            }
            if photoCount > 0 {
                segments.append("\(photoCount) \(photoCount == 1 ? "player photo could" : "player photos could") not be recovered")
            }
            if announcementCueCount > 0 {
                segments.append("\(announcementCueCount) \(announcementCueCount == 1 ? "Announcement Cue is" : "Announcement Cues are") missing")
            }
            guard let first = segments.first else { return "" }
            if segments.count == 1 {
                return first
            }
            if segments.count == 2 {
                return "\(first), and \(segments[1])"
            }
            return "\(segments[0]), \(segments[1]), and \(segments[2])"
        }
    }

    private func missingMediaTypes(for player: Player) -> [MissingMediaType] {
        var types: [MissingMediaType] = []
        if let photoRelativePath = player.photoRelativePath,
           !audioAssetService.assetExists(relativePath: photoRelativePath) {
            types.append(.photo)
        }
        if let customAnnouncerRelativePath = player.customAnnouncerRelativePath,
           !audioAssetService.assetExists(relativePath: customAnnouncerRelativePath) {
            types.append(.announcementCue)
        }
        if case .localAudio(let source)? = player.cue?.source,
           !audioAssetService.assetExists(relativePath: source.relativePath) {
            types.append(.song)
        }
        return types
    }

    private func missingMediaSummary(for team: Team) -> MissingMediaSummary {
        team.players.reduce(into: MissingMediaSummary()) { summary, player in
            let missingTypes = missingMediaTypes(for: player)
            if missingTypes.contains(.song) {
                summary.songCount += 1
            }
            if missingTypes.contains(.photo) {
                summary.photoCount += 1
            }
            if missingTypes.contains(.announcementCue) {
                summary.announcementCueCount += 1
            }
        }
    }

    private func playerPartialPrompt(for item: RecentlyDeletedItem, player: Player, missingTypes: [MissingMediaType]) -> PartialRestorePrompt {
        PartialRestorePrompt(
            itemID: item.id,
            itemType: .player,
            title: "Restore What We Can?",
            message: "\(player.displayName) could not be fully restored because \(playerMissingSummaryText(missingTypes)) missing. You can still restore the player and re-add the missing media afterward."
        )
    }

    private func teamPartialPrompt(for item: RecentlyDeletedItem, team: Team, summary: MissingMediaSummary) -> PartialRestorePrompt {
        PartialRestorePrompt(
            itemID: item.id,
            itemType: .team,
            title: "Restore What We Can?",
            message: "\(team.name) could not be fully restored because \(summary.warningText). You can still restore the team and re-add the missing media afterward."
        )
    }

    private func playerMissingSummaryText(_ missingTypes: [MissingMediaType]) -> String {
        let names = missingTypes.map(\.rawValue)
        guard let first = names.first else { return "some media is" }
        if names.count == 1 {
            return "the \(first) is"
        }
        if names.count == 2 {
            return "the \(names[0]) and \(names[1]) are"
        }
        return "the \(names[0]), \(names[1]), and \(names[2]) are"
    }

    private func restoreDeletedTeam(_ item: RecentlyDeletedItem, deletedTeam: DeletedTeamRecord, partialSummary: MissingMediaSummary?) {
        var restoredTeam = deletedTeam.team
        restoredTeam.name = restoredTeamName(from: restoredTeam.name)
        restoredTeam.modifiedAt = .now
        state.teams.append(restoredTeam)
        state.selectedTeamID = restoredTeam.id
        normalizeLineup(for: state.teams.count - 1)
        state.recentlyDeleted.removeAll { $0.id == item.id }
        scheduleReadinessRefresh()
        prewarmNextBatterCue()
        pendingRecoveryNavigationToken = UUID()
        if let partialSummary {
            showBanner("\(restoredTeam.name) restored, but \(partialSummary.warningText). Open players to re-add the missing media.", style: .warning)
        } else {
            showBanner("\(restoredTeam.name) restored.", style: .success)
        }
        persist()
    }

    private func restoreDeletedPlayer(_ item: RecentlyDeletedItem, deletedPlayer: DeletedPlayerRecord, missingTypes: [MissingMediaType]) {
        guard let restoreTeamIndex = state.teams.firstIndex(where: { $0.id == deletedPlayer.originalTeamID }) else {
            lastError = "Restore the team first to bring this player back."
            return
        }

        var restoredPlayer = deletedPlayer.player
        restoredPlayer.isPresent = true
        let insertionIndex = restoredPlayerInsertionIndex(
            previousBattingOrder: deletedPlayer.previousBattingOrder,
            playerID: restoredPlayer.id,
            currentBattingOrder: state.teams[restoreTeamIndex].session.battingOrder
        )

        let rosterInsertionIndex = min(insertionIndex, state.teams[restoreTeamIndex].players.count)
        state.teams[restoreTeamIndex].players.insert(restoredPlayer, at: rosterInsertionIndex)
        let battingOrderInsertionIndex = min(insertionIndex, state.teams[restoreTeamIndex].session.battingOrder.count)
        state.teams[restoreTeamIndex].session.battingOrder.insert(restoredPlayer.id, at: battingOrderInsertionIndex)
        state.teams[restoreTeamIndex].modifiedAt = .now
        state.selectedTeamID = state.teams[restoreTeamIndex].id
        normalizeLineup(for: restoreTeamIndex)
        state.recentlyDeleted.removeAll { $0.id == item.id }
        scheduleReadinessRefresh()
        prewarmNextBatterCue()
        pendingRecoveryNavigationToken = UUID()
        if missingTypes.isEmpty {
            showBanner("\(restoredPlayer.displayName) restored.", style: .success)
        } else {
            showBanner("\(restoredPlayer.displayName) restored, but \(playerMissingSummaryText(missingTypes)) missing. Open the player to re-add it.", style: .warning)
        }
        persist()
    }

    private func restoredTeamName(from originalName: String) -> String {
        let activeNames = Set(state.teams.map(\.name))
        guard activeNames.contains(originalName) else { return originalName }

        let restoredBase = "\(originalName) (Restored)"
        guard activeNames.contains(restoredBase) else { return restoredBase }

        var suffix = 2
        while activeNames.contains("\(originalName) (Restored \(suffix))") {
            suffix += 1
        }
        return "\(originalName) (Restored \(suffix))"
    }

    private func restoredPlayerInsertionIndex(previousBattingOrder: [UUID], playerID: UUID, currentBattingOrder: [UUID]) -> Int {
        guard let deletedIndex = previousBattingOrder.firstIndex(of: playerID) else {
            return currentBattingOrder.count
        }

        for candidateID in previousBattingOrder[..<deletedIndex].reversed() {
            if let currentIndex = currentBattingOrder.firstIndex(of: candidateID) {
                return currentIndex + 1
            }
        }

        let successorStart = previousBattingOrder.index(after: deletedIndex)
        if successorStart < previousBattingOrder.endIndex {
            for candidateID in previousBattingOrder[successorStart...] {
                if let currentIndex = currentBattingOrder.firstIndex(of: candidateID) {
                    return currentIndex
                }
            }
        }

        return currentBattingOrder.count
    }

    private func showBanner(_ text: String, style: AppBannerMessage.Style) {
        let banner = AppBannerMessage(text: text, style: style)
        bannerDismissTask?.cancel()
        bannerMessage = banner
        bannerDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, self.bannerMessage?.id == banner.id else { return }
            self.bannerMessage = nil
        }
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

    private func observeReadinessInputs() {
        audioRouteChangeTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification)
            for await _ in notifications {
                await MainActor.run {
                    self?.scheduleReadinessRefresh()
                }
            }
        }

        outputVolumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.scheduleReadinessRefresh()
            }
        }
    }

    private func observeLowPowerMode() {
        let applyCurrentState: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            Task {
                let isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                await self.songClipGenerationQueue.setPaused(isLowPowerModeEnabled, reason: .lowPowerMode)
                if !isLowPowerModeEnabled {
                    await self.runSongClipPreparationQueueIfNeeded()
                }
                await self.refreshPendingSongClipPreparationCount()
            }
        }
        applyCurrentState()
        lowPowerModeTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange
            )
            for await _ in notifications {
                await MainActor.run {
                    guard self != nil else { return }
                    applyCurrentState()
                }
            }
        }
    }

    private func scheduleAllSongClipPreparation(trigger: SongClipPreparationTrigger) {
        for team in state.teams {
            for player in team.players where player.songAssignment?.privateClip != nil {
                scheduleSongClipPreparation(teamID: team.id, playerID: player.id, trigger: trigger)
            }
        }
    }

    private func scheduleSongClipPreparation(
        teamID: UUID,
        playerID: UUID,
        trigger: SongClipPreparationTrigger,
        isExplicit: Bool = false
    ) {
        guard let teamIndex = state.teams.firstIndex(where: { $0.id == teamID }),
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == playerID }),
              case .privateClip(var clip)? = state.teams[teamIndex].players[playerIndex].songAssignment else {
            return
        }

        let generationKey = clip.generationKey
        if !isExplicit,
           clip.generatedAsset.status == .ready,
           clip.generatedAsset.generationKey == generationKey {
            return
        }
        if !isExplicit,
           let nextRetryAt = clip.retryMetadata.nextRetryAt,
           nextRetryAt > .now {
            return
        }

        if clip.generatedAsset.status != .ready {
            clip.generatedAsset.status = .pending
            clip.generatedAsset.generationKey = generationKey
            state.teams[teamIndex].players[playerIndex].songAssignment = .privateClip(clip)
            persist()
        }

        let request = SongClipPreparationRequest(
            id: UUID(),
            teamID: teamID,
            playerID: playerID,
            clipID: clip.id,
            generationKey: generationKey,
            trigger: trigger,
            isExplicit: isExplicit
        )
        Task {
            await songClipGenerationQueue.enqueue(request)
            await refreshPendingSongClipPreparationCount()
            await runSongClipPreparationQueueIfNeeded()
        }
    }

    private func runSongClipPreparationQueueIfNeeded() async {
        guard songClipPreparationTask == nil else { return }
        songClipPreparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.songClipPreparationTask = nil }

            while !Task.isCancelled, let request = await self.songClipGenerationQueue.next() {
                guard let clip = self.privateSongClip(
                    teamID: request.teamID,
                    playerID: request.playerID,
                    matching: request
                ) else {
                    await self.songClipGenerationQueue.complete(request)
                    continue
                }

                let service = self.songClipGenerationService
                let outcome = await Task.detached(priority: .utility) {
                    await service.prepare(clip)
                }.value
                self.applySongClipPreparationOutcome(outcome, request: request)
                await self.songClipGenerationQueue.complete(request)
                await self.refreshPendingSongClipPreparationCount()
            }
        }
        await songClipPreparationTask?.value
    }

    private func privateSongClip(
        teamID: UUID,
        playerID: UUID,
        matching request: SongClipPreparationRequest
    ) -> SongClip? {
        guard let team = state.teams.first(where: { $0.id == teamID }),
              let player = team.players.first(where: { $0.id == playerID }),
              case .privateClip(let clip)? = player.songAssignment,
              request.matches(clip) else {
            return nil
        }
        return clip
    }

    private func applySongClipPreparationOutcome(
        _ outcome: SongClipPreparationOutcome,
        request: SongClipPreparationRequest
    ) {
        guard let teamIndex = state.teams.firstIndex(where: { $0.id == request.teamID }),
              let playerIndex = state.teams[teamIndex].players.firstIndex(where: { $0.id == request.playerID }),
              case .privateClip(var clip)? = state.teams[teamIndex].players[playerIndex].songAssignment,
              request.matches(clip) else {
            if case .generated(let asset) = outcome {
                audioAssetService.removeAsset(relativePath: asset.relativePath)
            }
            return
        }

        let previousGeneratedPath = clip.generatedAsset.status == .ready
            ? clip.generatedAsset.relativePath
            : nil
        clip.retryMetadata.lastAttemptAt = .now

        switch outcome {
        case .generated(let asset):
            clip.generatedAsset = asset
            clip.readinessInputs = SongClipReadinessInputs(
                playback: .localClipReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: true
            )
            clip.portabilityInputs = SongClipPortabilityInputs(
                portability: .portableLocalClip,
                generatedAssetCanBeExported: true
            )
            clip.retryMetadata = .none
        case .sourceBacked(let downloadedOnDevice):
            if clip.generatedAsset.status != .ready {
                clip.generatedAsset = GeneratedClipAsset(
                    relativePath: nil,
                    status: .none,
                    renderedSelection: nil,
                    generationKey: request.generationKey,
                    generatedAt: nil
                )
            }
            clip.readinessInputs = SongClipReadinessInputs(
                playback: downloadedOnDevice ? .sourceBackedDownloaded : .sourceBackedReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: downloadedOnDevice
            )
            clip.portabilityInputs = SongClipPortabilityInputs(
                portability: .sourceReferenceOnly,
                generatedAssetCanBeExported: false
            )
            clip.retryMetadata = .none
        case .needsAppleMusic:
            let hasReadyGeneratedAsset = clip.generatedAsset.status == .ready
            if !hasReadyGeneratedAsset {
                clip.generatedAsset.status = .failedRetryable
                clip.readinessInputs = SongClipReadinessInputs(
                    playback: .needsAppleMusic,
                    sourceAvailableOnDevice: false,
                    downloadedOnDevice: false
                )
            }
            recordPreparationFailure(
                on: &clip,
                code: .musicAuthorizationRequired,
                retryable: true,
                request: request
            )
        case .failed(let code, let retryable):
            let hasReadyGeneratedAsset = clip.generatedAsset.status == .ready
            if !hasReadyGeneratedAsset {
                clip.generatedAsset.status = retryable ? .failedRetryable : .failedPermanent
                if !retryable {
                    clip.readinessInputs.playback = .needsRepair
                    clip.readinessInputs.sourceAvailableOnDevice = false
                }
            }
            recordPreparationFailure(on: &clip, code: code, retryable: retryable, request: request)
        }

        state.teams[teamIndex].players[playerIndex].songAssignment = .privateClip(clip)
        state.teams[teamIndex].modifiedAt = .now
        persist()
        scheduleReadinessRefresh()

        if let previousGeneratedPath,
           previousGeneratedPath != clip.generatedAsset.relativePath {
            removeAssetIfUnreferenced(relativePath: previousGeneratedPath)
        }
    }

    private func recordPreparationFailure(
        on clip: inout SongClip,
        code: SongClipPreparationFailureCode,
        retryable: Bool,
        request: SongClipPreparationRequest
    ) {
        clip.retryMetadata.attemptCount += 1
        clip.retryMetadata.lastFailureCode = code.rawValue
        guard retryable, clip.retryMetadata.attemptCount < 3 else {
            clip.retryMetadata.nextRetryAt = nil
            return
        }

        let delay: TimeInterval = clip.retryMetadata.attemptCount == 1 ? 30 : 120
        let retryAt = Date().addingTimeInterval(delay)
        clip.retryMetadata.nextRetryAt = retryAt
        let teamID = request.teamID
        let playerID = request.playerID
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.scheduleSongClipPreparation(
                teamID: teamID,
                playerID: playerID,
                trigger: .retry
            )
        }
    }

    private func refreshPendingSongClipPreparationCount() async {
        pendingSongClipPreparationCount = await songClipGenerationQueue.pendingCount()
    }

    private func persist() {
        let snapshot = state
        let destinationURL: URL
        do {
            destinationURL = try AppPaths.stateURL()
        } catch {
            lastError = error.localizedDescription
            return
        }
        persistSequence += 1
        let sequence = persistSequence
        Task(priority: .utility) { [persistenceWriter] in
            let errorDescription = await persistenceWriter.enqueue(
                snapshot,
                sequence: sequence,
                destinationURL: destinationURL
            )

            if let errorDescription {
                await MainActor.run {
                    self.lastError = errorDescription
                }
            }
        }
    }

    private static func load() throws -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppState.self, from: Data(contentsOf: AppPaths.stateURL()))
    }

    private static func loadInitialState() -> (state: AppState, warning: String?) {
        do {
            let stateURL = try AppPaths.stateURL()
            guard FileManager.default.fileExists(atPath: stateURL.path) else {
                return (freshEmptyState(), nil)
            }
            let loadedState = try load()
            guard loadedState.schemaVersion <= AppState.currentSchemaVersion else {
                return (
                    freshEmptyState(),
                    preserveUnreadableStateFile(
                        loadError: AppError.unsupportedSavedStateVersion
                    )
                )
            }
            return (loadedState, nil)
        } catch {
            let recoveryMessage = preserveUnreadableStateFile(loadError: error)
            return (freshEmptyState(), recoveryMessage)
        }
    }

    private static func freshEmptyState() -> AppState {
        var state = AppState.empty
        state.deviceIdentity = DeviceIdentity(label: UIDevice.current.name)
        return state
    }

    private static func preserveUnreadableStateFile(loadError: Error) -> String {
        let fallbackMessage = "Roll Call could not load saved app data. Your previous state file could not be decoded, so Roll Call preserved a recovery copy before starting from an empty state. Error: \(loadError.localizedDescription)"

        do {
            let stateURL = try AppPaths.stateURL()
            guard FileManager.default.fileExists(atPath: stateURL.path) else {
                return fallbackMessage
            }
            let recoveryURL = try AppPaths.unreadableStateRecoveryURL()
            try FileManager.default.copyItem(at: stateURL, to: recoveryURL)
            return "Roll Call could not load saved app data. A recovery copy was saved as \(recoveryURL.lastPathComponent) before Roll Call started from an empty state. Error: \(loadError.localizedDescription)"
        } catch {
            return "\(fallbackMessage) Recovery copy failed: \(error.localizedDescription)"
        }
    }

    nonisolated fileprivate static func write(_ state: AppState, to destinationURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: destinationURL, options: .atomic)
    }

    private func busy(_ operation: @escaping () async throws -> Void) async {
        isBusy = true
        defer {
            isBusy = false
            if !pendingIncomingPackageURLs.isEmpty {
                Task { await self.preparePendingIncomingPackageIfNeeded() }
            }
        }
        do {
            try await operation()
            refreshReadiness()
            persist()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func updateMusicRenderProbeSample(
        for scenario: MusicRenderProbeScenario,
        mutate: (inout MusicRenderProbeSample) -> Void
    ) {
        guard let index = musicRenderProbeSamples.firstIndex(where: { $0.scenario == scenario }) else { return }
        var sample = musicRenderProbeSamples[index]
        mutate(&sample)
        musicRenderProbeSamples[index] = sample
        musicRenderProbeSummaryURL = nil
    }

    private func preparePendingIncomingPackageIfNeeded() async {
        guard hasFinishedLaunching,
              !isBusy,
              pendingPackageImport == nil,
              !isPreparingIncomingPackagePreview else {
            return
        }

        isPreparingIncomingPackagePreview = true
        defer { isPreparingIncomingPackagePreview = false }

        while pendingPackageImport == nil, !pendingIncomingPackageURLs.isEmpty {
            let nextURL = pendingIncomingPackageURLs.removeFirst()
            do {
                let scoped = nextURL.startAccessingSecurityScopedResource()
                defer {
                    if scoped { nextURL.stopAccessingSecurityScopedResource() }
                }
                let manifest = try packageService.preview(packageURL: nextURL)
                pendingPackageImport = PendingPackageImport(
                    url: nextURL,
                    manifest: manifest,
                    opensOnboardingHandoff: !state.onboarding.isComplete
                )
            } catch {
                lastError = error.localizedDescription
            }
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
                applyGeneratedBuiltInAnnouncerAsset(asset, toPlayerID: player.id, onTeamID: teamID)
                announcerRegenerationStatus = AnnouncerRegenerationStatus(teamID: teamID, phase: phase, completed: index + 1, total: players.count)
                persist()
            } catch {
                applyGeneratedBuiltInAnnouncerAsset(nil, toPlayerID: player.id, onTeamID: teamID)
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

struct GeneratedAnnouncerAsset {
    var relativePath: String
    var resolvedVoiceIdentifier: String?
    var voiceLanguageCode: String?
}

private actor StatePersistenceWriter {
    private var latestSequence = 0
    private var pending: (state: AppState, sequence: Int, destinationURL: URL)?
    private var isWriting = false

    func enqueue(_ state: AppState, sequence: Int, destinationURL: URL) async -> String? {
        guard sequence >= latestSequence else { return nil }
        latestSequence = sequence
        pending = (state, sequence, destinationURL)

        guard !isWriting else { return nil }
        isWriting = true
        defer { isWriting = false }

        var latestError: String?
        while let next = pending {
            pending = nil
            do {
                try AppModel.write(next.state, to: next.destinationURL)
            } catch {
                latestError = error.localizedDescription
            }
        }
        return latestError
    }
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
