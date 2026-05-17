import AVFAudio
import AVFoundation
import Foundation
import MediaPlayer
@preconcurrency import MusicKit
import Network
import UniformTypeIdentifiers
import ZIPFoundation

enum AppError: LocalizedError {
    case missingPreview
    case featureDisabled
    case invalidImport
    case invalidSearchTerm
    case musicSearchUnavailable
    case musicAuthorizationRequired
    case musicSubscriptionRequired
    case appleMusicSongUnavailable
    case invalidCSV
    case noAudioTrack
    case microphonePermissionDenied
    case recordingUnavailable
    case customIntroSaveFailed(String)
    case invalidAnnouncerText
    case invalidAnnouncerAudio
    case announcerGenerationTimedOut
    case missingBuiltInClip
    case appleMusicFullSongCatalogUnavailable

    var errorDescription: String? {
        switch self {
        case .missingPreview:
            return "This Apple Music selection does not expose preview media for the experimental local-copy path."
        case .featureDisabled:
            return "Experimental local copies are disabled in Settings."
        case .invalidImport:
            return "That file could not be imported."
        case .invalidSearchTerm:
            return "Enter a song title, artist, or both before searching."
        case .musicSearchUnavailable:
            return "Song search is temporarily unavailable."
        case .musicAuthorizationRequired:
            return "Allow Apple Music access to search and use Apple Music songs."
        case .musicSubscriptionRequired:
            return "No Apple Music playback subscription is active. You can only choose from the available preview clip."
        case .appleMusicSongUnavailable:
            return "That Apple Music song is unavailable for full-song playback right now."
        case .invalidCSV:
            return "That CSV could not be parsed. Use a header row with name and number, or simple two-column rows."
        case .noAudioTrack:
            return "That video does not contain an audio track that Roll Call can import."
        case .microphonePermissionDenied:
            return "Microphone access is required to record an Announcement Cue."
        case .recordingUnavailable:
            return "Custom announcer recording is not available right now."
        case .customIntroSaveFailed(let detail):
            return "Roll Call could not save that Announcement Cue recording. [\(AppMetadata.appVersion) build \(AppMetadata.buildNumber) \(AppMetadata.customIntroStorageMarker)] \(detail)"
        case .invalidAnnouncerText:
            return "Enter announcer text before generating or previewing built-in voice audio."
        case .invalidAnnouncerAudio:
            return "Roll Call could not create a usable built-in announcer clip for this voice on this device."
        case .announcerGenerationTimedOut:
            return "Built-in voice generation took too long and was stopped. Try a shorter phrase or a different installed voice."
        case .missingBuiltInClip:
            return "A built-in General Clip could not be loaded from the app bundle."
        case .appleMusicFullSongCatalogUnavailable:
            return "Roll Call could not load a full-song Apple Music catalog result. Check Apple Music account access and the MusicKit app service, then try again."
        }
    }
}

private func builtInClipRelativePath(for source: BuiltInClipSource) -> String {
    "\(source.id).mp3"
}

struct AudioAssetService: Sendable {
    func assetURL(relativePath: String) throws -> URL {
        try AppPaths.assetURL(relativePath: relativePath)
    }

    func makeWritableAssetURL(fileExtension: String) throws -> URL {
        let normalizedExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = normalizedExtension.isEmpty ? "m4a" : normalizedExtension
        return try AppPaths.assetsDirectory().appendingPathComponent("\(UUID().uuidString).\(ext)")
    }

    func importMedia(from url: URL) async throws -> LocalAudioSource {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let asset = AVURLAsset(url: url)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let hasVideoTrack = !videoTracks.isEmpty
        if hasVideoTrack {
            return try await extractAudio(fromVideoAt: url, displayName: url.deletingPathExtension().lastPathComponent)
        }

        return try storeCopiedAsset(
            from: url,
            suggestedExtension: url.pathExtension,
            displayName: url.deletingPathExtension().lastPathComponent,
            hiddenOriginNote: nil
        )
    }

    func importRemotePreview(from previewURL: URL, displayName: String, hiddenOrigin: HiddenOriginNote) async throws -> LocalAudioSource {
        let (tempURL, response) = try await URLSession.shared.download(from: previewURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AppError.invalidImport }
        let destination = try AppPaths.assetsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")
        try FileManager.default.copyItem(at: tempURL, to: destination)
        let duration = try audioDuration(for: destination)
        return LocalAudioSource(id: UUID(), displayName: displayName, relativePath: destination.lastPathComponent, duration: duration.isFinite ? duration : nil, importedAt: .now, hiddenOriginNote: hiddenOrigin)
    }

    func storeSpeechData(_ data: Data, displayName: String) throws -> LocalAudioSource {
        let destination = try AppPaths.assetsDirectory().appendingPathComponent("\(UUID().uuidString).caf")
        guard !data.isEmpty else { throw AppError.invalidAnnouncerAudio }
        try data.write(to: destination, options: .atomic)
        guard FileManager.default.fileExists(atPath: destination.path),
              let size = try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0 else {
            throw AppError.invalidAnnouncerAudio
        }
        return try localAudioSource(for: destination, displayName: displayName, hiddenOriginNote: nil)
    }

    func removeAsset(relativePath: String?) {
        guard let relativePath else { return }
        guard let url = try? assetURL(relativePath: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func storeCustomAnnouncerRecording(from sourceURL: URL, playerID: UUID, displayName: String) throws -> LocalAudioSource {
        let relativePath = "custom-intro-\(playerID.uuidString.lowercased()).caf"
        let destination = try AppPaths.assetsDirectory().appendingPathComponent(relativePath)
        let recordedData = try Data(contentsOf: sourceURL)
        guard !recordedData.isEmpty else {
            throw AppError.customIntroSaveFailed("recorded temp file was empty before app-storage write")
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try recordedData.write(to: destination, options: .atomic)
        guard FileManager.default.fileExists(atPath: destination.path),
              ((try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 0 else {
            throw AppError.customIntroSaveFailed("flat saved asset was not visible at \(relativePath)")
        }
        return try localAudioSource(for: destination, displayName: displayName, hiddenOriginNote: nil, relativePath: relativePath)
    }

    func storeCopiedAsset(from sourceURL: URL, suggestedExtension: String?, displayName: String, hiddenOriginNote: HiddenOriginNote?) throws -> LocalAudioSource {
        let ext = suggestedExtension?.isEmpty == false ? suggestedExtension! : sourceURL.pathExtension
        let destination = try makeWritableAssetURL(fileExtension: ext)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return try localAudioSource(for: destination, displayName: displayName, hiddenOriginNote: hiddenOriginNote)
    }

    func ensureBuiltInAssets() throws {
        for builtIn in BuiltInClip.defaults {
            guard case .builtInClip(let source) = builtIn.cue.source else { continue }
            let relativePath = builtInClipRelativePath(for: source)
            let url = try assetURL(relativePath: relativePath)
            guard !FileManager.default.fileExists(atPath: url.path) else { continue }
            guard let bundledURL = Bundle.main.url(forResource: source.id, withExtension: "mp3", subdirectory: "BuiltInAudio") else {
                throw AppError.missingBuiltInClip
            }
            try FileManager.default.copyItem(at: bundledURL, to: url)
        }
    }

    func assetExists(relativePath: String) -> Bool {
        guard let url = try? assetURL(relativePath: relativePath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func localAudioSource(for url: URL, displayName: String, hiddenOriginNote: HiddenOriginNote?, relativePath: String? = nil) throws -> LocalAudioSource {
        let duration = try audioDuration(for: url)
        return LocalAudioSource(
            id: UUID(),
            displayName: displayName,
            relativePath: relativePath ?? url.lastPathComponent,
            duration: duration.isFinite ? duration : nil,
            importedAt: .now,
            hiddenOriginNote: hiddenOriginNote
        )
    }

    private func ensureDirectoryExists(at url: URL) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return
            }
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func extractAudio(fromVideoAt url: URL, displayName: String) async throws -> LocalAudioSource {
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AppError.noAudioTrack
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AppError.invalidImport
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: tempURL)
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = false

        try await exportSession.export(to: tempURL, as: .m4a)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        return try storeCopiedAsset(
            from: tempURL,
            suggestedExtension: "m4a",
            displayName: displayName,
            hiddenOriginNote: nil
        )
    }

    private func audioDuration(for url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard format.sampleRate > 0 else { return 0 }
        return Double(file.length) / format.sampleRate
    }
}

struct MusicSearchResult: Identifiable {
    var id: String { songID }
    var songID: String
    var title: String
    var artistName: String
    var duration: TimeInterval?
    var previewURL: URL?
    var isCatalogBacked: Bool = true
}

enum AppleMusicPlaybackCapability: Equatable {
    case unknown
    case previewOnly
    case fullSong
}

enum AppleMusicSearchMode: Equatable {
    case catalogOnly
    case previewFallback
}

struct MusicCatalogService: Sendable {
    func search(term: String, mode: AppleMusicSearchMode) async throws -> [MusicSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.invalidSearchTerm }

        if mode == .catalogOnly {
            do {
                let catalogResults = try await catalogSearch(term: trimmed)
                guard !catalogResults.isEmpty else { throw AppError.musicSearchUnavailable }
                return catalogResults
            } catch let error as AppError {
                throw error
            } catch {
                throw AppError.appleMusicFullSongCatalogUnavailable
            }
        }

        do {
            let musicKitResults = try await catalogSearch(term: trimmed)
            if !musicKitResults.isEmpty {
                return musicKitResults
            }
        } catch {
            // Fall back to preview-only search when catalog access fails, including
            // local development builds that cannot fetch a MusicKit developer token.
        }

        let previewResults = try await searchWithITunesPreview(term: trimmed)
        guard !previewResults.isEmpty else { throw AppError.musicSearchUnavailable }
        return previewResults
    }

    func catalogBackedResult(for result: MusicSearchResult) async throws -> MusicSearchResult {
        let song = try await song(for: result.songID)
        var resolvedDuration = song.duration ?? result.duration
        if resolvedDuration == nil {
            resolvedDuration = try? await durationFromITunesLookup(songID: song.id.rawValue)
        }
        return MusicSearchResult(
            songID: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            duration: resolvedDuration,
            previewURL: song.previewAssets?.first?.url ?? result.previewURL,
            isCatalogBacked: true
        )
    }

    func playbackCapability() async -> AppleMusicPlaybackCapability {
        do {
            let status = try await authorizedStatus()
            guard status == .authorized else { return .previewOnly }
            let subscription = try await MusicSubscription.current
            return subscription.canPlayCatalogContent ? .fullSong : .previewOnly
        } catch {
            return .previewOnly
        }
    }

    func song(for songID: String) async throws -> Song {
        let status = try await authorizedStatus()
        guard status == .authorized else { throw AppError.musicAuthorizationRequired }

        let subscription = try await MusicSubscription.current
        guard subscription.canPlayCatalogContent else { throw AppError.musicSubscriptionRequired }

        var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(songID))
        request.limit = 1
        let response = try await request.response()
        guard let song = response.items.first else { throw AppError.appleMusicSongUnavailable }
        return song
    }

    private func catalogSearch(term: String) async throws -> [MusicSearchResult] {
        let status = try await authorizedStatus()
        guard status == .authorized else { throw AppError.musicAuthorizationRequired }
        return try await searchWithMusicKit(term: term)
    }

    private func searchWithMusicKit(term: String) async throws -> [MusicSearchResult] {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 20
        let response = try await request.response()
        return response.songs.map {
            MusicSearchResult(
                songID: $0.id.rawValue,
                title: $0.title,
                artistName: $0.artistName,
                duration: $0.duration,
                previewURL: $0.previewAssets?.first?.url,
                isCatalogBacked: true
            )
        }
    }

    private func searchWithITunesPreview(term: String) async throws -> [MusicSearchResult] {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "media", value: "music")
        ]
        guard let url = components?.url else { throw AppError.musicSearchUnavailable }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AppError.musicSearchUnavailable
        }

        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return decoded.results.compactMap { item in
            guard let previewURL = item.previewURL else { return nil }
            return MusicSearchResult(
                songID: String(item.trackID),
                title: item.trackName,
                artistName: item.artistName,
                duration: item.trackTimeMillis.map { TimeInterval($0) / 1000 },
                previewURL: previewURL,
                isCatalogBacked: false
            )
        }
    }

    private func durationFromITunesLookup(songID: String) async throws -> TimeInterval? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [URLQueryItem(name: "id", value: songID)]
        guard let url = components?.url else { return nil }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return decoded.results.first?.trackTimeMillis.map { TimeInterval($0) / 1000 }
    }

    private func authorizedStatus() async throws -> MusicAuthorization.Status {
        switch MusicAuthorization.currentStatus {
        case .notDetermined:
            return await MusicAuthorization.request()
        default:
            return MusicAuthorization.currentStatus
        }
    }
}

private struct ITunesSearchResponse: Decodable {
    let results: [ITunesTrack]
}

private struct ITunesTrack: Decodable {
    let trackID: Int
    let trackName: String
    let artistName: String
    let previewURL: URL?
    let trackTimeMillis: Int?

    enum CodingKeys: String, CodingKey {
        case trackID = "trackId"
        case trackName
        case artistName
        case previewURL = "previewUrl"
        case trackTimeMillis
    }
}

struct ParsedRosterRow: Equatable {
    let name: String
    let number: String
}

struct PlaybackSupportDiagnostics: Codable, Equatable {
    var activeCueID: UUID?
    var prewarmedCueID: UUID?
    var lastStartedCueID: UUID?
    var debounceWindowSeconds: Double
}

private struct SupportBundlePayload: Codable {
    struct TeamSummary: Codable {
        var id: UUID
        var name: String
        var playerCount: Int
        var presentPlayerCount: Int
        var builtInClipCount: Int
    }

    var generatedAt: Date
    var appVersion: String
    var schemaVersion: Int
    var selectedTeamID: UUID?
    var settings: AppSettings
    var experimental: ExperimentalSettings
    var readiness: ReadinessStatus?
    var playback: PlaybackSupportDiagnostics
    var teams: [TeamSummary]
}

@MainActor
private protocol AppleMusicCatalogPlaybackControlling: AnyObject {
    func preconnect()
    func play(
        songID: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        volumeAutomationEnabled: Bool
    ) async throws
    func setVolume(_ volume: Float)
    func stop()
}

@MainActor
private final class MediaPlayerCatalogPlaybackController: AppleMusicCatalogPlaybackControlling {
    private let player: MPMusicPlayerApplicationController
    private var fadeAnchorVolume: Float = 1
    private var volumeAutomationEnabledForCurrentCue = true
    private var startupRampTask: Task<Void, Never>?

    init(player: MPMusicPlayerApplicationController = MPMusicPlayerController.applicationQueuePlayer) {
        self.player = player
    }

    func preconnect() {
        _ = player
    }

    func play(
        songID: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        volumeAutomationEnabled: Bool
    ) async throws {
        volumeAutomationEnabledForCurrentCue = volumeAutomationEnabled
        if volumeAutomationEnabled {
            fadeAnchorVolume = currentPlayerVolume()
        }
        startupRampTask?.cancel()
        player.stop()
        if volumeAutomationEnabled {
            setPlayerVolume(0)
        }

        let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: [songID])
        descriptor.startItemID = songID
        descriptor.setStartTime(startTime, forItemWithStoreID: songID)
        descriptor.setEndTime(startTime + duration, forItemWithStoreID: songID)
        player.setQueue(with: descriptor)

        // MediaPlayer queue start times can still be sticky on reused selections, so
        // force the playhead to the cue's current trim point before and after playback.
        if startTime > 0 {
            player.currentPlaybackTime = startTime
        }

        player.play()
        if volumeAutomationEnabled {
            setPlayerVolume(0)
        }

        if startTime > 0 {
            await Task.yield()
            player.currentPlaybackTime = startTime
        }

        if volumeAutomationEnabled {
            beginStartupRamp()
        }
    }

    func setVolume(_ volume: Float) {
        let clamped = min(max(0, volume), 1)
        if clamped >= 0.999 {
            fadeAnchorVolume = currentPlayerVolume()
        }
        setPlayerVolume(fadeAnchorVolume * clamped)
    }

    func stop() {
        startupRampTask?.cancel()
        startupRampTask = nil
        player.stop()
        if volumeAutomationEnabledForCurrentCue {
            setPlayerVolume(fadeAnchorVolume)
        }
    }

    private func setPlayerVolume(_ volume: Float) {
        // `MPMusicPlayerController.volume` is marked unavailable on modern iOS SDKs,
        // but the application queue player still exposes the underlying Objective-C
        // setter. Keep this isolated as a provisional on-device experiment.
        player.setValue(volume, forKey: "volume")
    }

    private func currentPlayerVolume() -> Float {
        guard let number = player.value(forKey: "volume") as? NSNumber else { return 1 }
        return min(max(number.floatValue, 0), 1)
    }

    private func beginStartupRamp() {
        startupRampTask?.cancel()
        let targetVolume = fadeAnchorVolume
        startupRampTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let steps = 4
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let progress = Float(step) / Float(steps)
                self.setPlayerVolume(targetVolume * progress)
                try? await Task.sleep(for: .milliseconds(30))
            }
            self.startupRampTask = nil
        }
    }
}

@MainActor
final class CuePlaybackEngine: NSObject, ObservableObject {
    @Published private(set) var activeCueID: UUID?

    private let audioAssetService: AudioAssetService
    private let musicCatalogService: MusicCatalogService
    private let catalogPlaybackController: any AppleMusicCatalogPlaybackControlling
    private let debounceWindow: TimeInterval = 0.45
    private let appleMusicClipDurationLimit: TimeInterval = 20
    private var audioPlayer: AVAudioPlayer?
    private var announcerPlayer: AVAudioPlayer?
    private var remotePlayer: AVPlayer?
    private var stopTask: Task<Void, Never>?
    private var prewarmedCueID: UUID?
    private var prewarmedLocalPlayer: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var lastStartDate: Date?
    private var lastStartedCueID: UUID?

    init(
        audioAssetService: AudioAssetService,
        musicCatalogService: MusicCatalogService
    ) {
        self.audioAssetService = audioAssetService
        self.musicCatalogService = musicCatalogService
        self.catalogPlaybackController = MediaPlayerCatalogPlaybackController()
    }

    func play(
        cue: Cue,
        announcerRelativePath: String? = nil,
        fadeOutVolumeAutomationEnabled: Bool = true
    ) async throws {
        if activeCueID == cue.id {
            stop()
            return
        }
        if let lastStartDate,
           let lastStartedCueID,
           lastStartedCueID == cue.id,
           Date().timeIntervalSince(lastStartDate) < debounceWindow {
            return
        }
        stop()
        activeCueID = cue.id
        lastStartDate = Date()
        lastStartedCueID = cue.id
        try await playCueSequence(
            cue,
            announcerRelativePath: announcerRelativePath,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
    }

    func playAsset(relativePath: String, activeCueID: UUID) async throws {
        if self.activeCueID == activeCueID {
            stop()
            return
        }
        if let lastStartDate,
           let lastStartedCueID,
           lastStartedCueID == activeCueID,
           Date().timeIntervalSince(lastStartDate) < debounceWindow {
            return
        }
        stop()
        self.activeCueID = activeCueID
        lastStartDate = Date()
        lastStartedCueID = activeCueID

        let url = try audioAssetService.assetURL(relativePath: relativePath)
        let player = try AVAudioPlayer(contentsOf: url)
        announcerPlayer = player
        player.prepareToPlay()
        guard player.play() else {
            announcerPlayer = nil
            self.activeCueID = nil
            return
        }

        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(player.duration))
            guard let self, !Task.isCancelled else { return }
            self.stop()
        }
    }

    func prewarm(cue: Cue) async throws {
        switch cue.source {
        case .appleMusic:
            prewarmedCueID = cue.id
            prewarmedLocalPlayer = nil
            catalogPlaybackController.preconnect()
        case .localAudio(let source):
            let url = try audioAssetService.assetURL(relativePath: source.relativePath)
            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = cue.startTime
            player.prepareToPlay()
            prewarmedCueID = cue.id
            prewarmedLocalPlayer = player
        case .builtInClip(let source):
            let url = try audioAssetService.assetURL(relativePath: builtInClipRelativePath(for: source))
            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = cue.startTime
            player.prepareToPlay()
            prewarmedCueID = cue.id
            prewarmedLocalPlayer = player
        }
    }

    func preconnectForUpcomingPlayback() {
        catalogPlaybackController.preconnect()
    }

    func supportDiagnostics() -> PlaybackSupportDiagnostics {
        PlaybackSupportDiagnostics(
            activeCueID: activeCueID,
            prewarmedCueID: prewarmedCueID,
            lastStartedCueID: lastStartedCueID,
            debounceWindowSeconds: debounceWindow
        )
    }

    func previewAudio(data: Data) throws {
        stop()
        let player = try AVAudioPlayer(data: data)
        previewPlayer = player
        player.prepareToPlay()
        player.play()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(player.duration))
            self?.previewPlayer?.stop()
            self?.previewPlayer = nil
            self?.stopTask = nil
        }
    }

    func previewAsset(relativePath: String) throws {
        stop()
        let url = try audioAssetService.assetURL(relativePath: relativePath)
        let player = try AVAudioPlayer(contentsOf: url)
        previewPlayer = player
        player.prepareToPlay()
        player.play()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(player.duration))
            self?.previewPlayer?.stop()
            self?.previewPlayer = nil
            self?.stopTask = nil
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        announcerPlayer?.stop()
        announcerPlayer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        remotePlayer?.pause()
        remotePlayer = nil
        catalogPlaybackController.stop()
        previewPlayer?.stop()
        previewPlayer = nil
        activeCueID = nil
    }

    private func playCueSequence(
        _ cue: Cue,
        announcerRelativePath: String?,
        fadeOutVolumeAutomationEnabled: Bool
    ) async throws {
        if let relativePath = announcerRelativePath {
            try? await prewarm(cue: cue)

            let announcerURL = try audioAssetService.assetURL(relativePath: relativePath)
            guard FileManager.default.fileExists(atPath: announcerURL.path) else {
                try await startPrimaryCue(cue, fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled)
                return
            }

            let player: AVAudioPlayer
            do {
                player = try AVAudioPlayer(contentsOf: announcerURL)
            } catch {
                try await startPrimaryCue(cue, fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled)
                return
            }
            announcerPlayer = player
            player.prepareToPlay()
            guard player.play() else {
                announcerPlayer = nil
                try await startPrimaryCue(cue, fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled)
                return
            }

            let delay = player.duration + cue.pauseAfterAnnouncer
            guard delay.isFinite, delay >= 0 else {
                try await startPrimaryCue(cue, fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled)
                return
            }

            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self, !Task.isCancelled else { return }
                do {
                    try await self.startPrimaryCue(
                        cue,
                        cancelPendingStopTask: false,
                        fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
                    )
                } catch {
                    self.stop()
                }
            }
            return
        }

        try await startPrimaryCue(cue, fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled)
    }

    private func startPrimaryCue(
        _ cue: Cue,
        cancelPendingStopTask: Bool = true,
        fadeOutVolumeAutomationEnabled: Bool
    ) async throws {
        if cancelPendingStopTask {
            stopTask?.cancel()
            stopTask = nil
        } else {
            stopTask = nil
        }
        announcerPlayer?.stop()
        announcerPlayer = nil

        let duration = cue.source.maximumPlaybackDuration.map { min(cue.duration, $0) } ?? cue.duration

        switch cue.source {
        case .appleMusic(let source):
            let clipDuration = min(duration, appleMusicClipDurationLimit)
            if source.isCatalogBacked != false, await musicCatalogService.playbackCapability() == .fullSong {
                do {
                    try await playCatalogSong(
                        source: source,
                        startTime: cue.startTime,
                        duration: clipDuration,
                        fadeOut: cue.fadeOutDuration,
                        fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
                    )
                    return
                } catch {
                    throw AppError.appleMusicFullSongCatalogUnavailable
                }
            }

            guard let previewURL = source.previewURL else { throw AppError.missingPreview }
            let player = AVPlayer(url: previewURL)
            remotePlayer = player
            let maxPreviewStart = max(0, appleMusicClipDurationLimit - clipDuration)
            let previewStart = min(max(0, cue.startTime), maxPreviewStart)
            player.seek(to: CMTime(seconds: previewStart, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
                if fadeOutVolumeAutomationEnabled {
                    player?.volume = 1
                }
                player?.play()
            }
            scheduleRemoteStop(
                duration: clipDuration,
                fadeOut: cue.fadeOutDuration,
                fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
            )
        case .localAudio(let source):
            let url = try audioAssetService.assetURL(relativePath: source.relativePath)
            try playLocal(
                url: url,
                start: cue.startTime,
                duration: duration,
                fadeOut: cue.fadeOutDuration,
                fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                reusePrewarm: prewarmedCueID == cue.id
            )
        case .builtInClip(let source):
            let url = try audioAssetService.assetURL(relativePath: builtInClipRelativePath(for: source))
            try playLocal(
                url: url,
                start: cue.startTime,
                duration: duration,
                fadeOut: cue.fadeOutDuration,
                fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                reusePrewarm: prewarmedCueID == cue.id
            )
        }
    }

    private func playCatalogSong(
        source: AppleMusicSource,
        startTime: TimeInterval,
        duration: TimeInterval,
        fadeOut: TimeInterval,
        fadeOutVolumeAutomationEnabled: Bool
    ) async throws {
        try await catalogPlaybackController.play(
            songID: source.songID,
            startTime: startTime,
            duration: duration,
            volumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        scheduleCatalogStop(
            duration: duration,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
    }

    private func playLocal(
        url: URL,
        start: TimeInterval,
        duration: TimeInterval,
        fadeOut: TimeInterval,
        fadeOutVolumeAutomationEnabled: Bool,
        reusePrewarm: Bool
    ) throws {
        let player = if reusePrewarm, let prewarmedLocalPlayer {
            prewarmedLocalPlayer
        } else {
            try AVAudioPlayer(contentsOf: url)
        }
        audioPlayer = player
        if fadeOutVolumeAutomationEnabled {
            player.volume = 1
        }
        player.currentTime = start
        player.play()
        scheduleLocalStop(
            duration: duration,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
    }

    private func scheduleLocalStop(duration: TimeInterval, fadeOut: TimeInterval, fadeOutVolumeAutomationEnabled: Bool) {
        let fadeDuration = effectiveFadeDuration(
            playbackDuration: duration,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        let sustainDuration = max(0, duration - fadeDuration)
        stopTask = Task { [weak self] in
            if sustainDuration > 0 {
                try? await Task.sleep(for: .seconds(sustainDuration))
            }
            guard let self, !Task.isCancelled else { return }
            if fadeDuration > 0 {
                await self.fadeLocal(duration: fadeDuration)
            } else {
                self.stop()
            }
        }
    }

    private func scheduleRemoteStop(duration: TimeInterval, fadeOut: TimeInterval, fadeOutVolumeAutomationEnabled: Bool) {
        let fadeDuration = effectiveFadeDuration(
            playbackDuration: duration,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        let sustainDuration = max(0, duration - fadeDuration)
        stopTask = Task { [weak self] in
            if sustainDuration > 0 {
                try? await Task.sleep(for: .seconds(sustainDuration))
            }
            guard let self, !Task.isCancelled else { return }
            if fadeDuration > 0 {
                await self.fadeRemote(duration: fadeDuration)
            } else {
                self.stop()
            }
        }
    }

    private func scheduleCatalogStop(duration: TimeInterval, fadeOut: TimeInterval, fadeOutVolumeAutomationEnabled: Bool) {
        let fadeDuration = effectiveFadeDuration(
            playbackDuration: duration,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        let sustainDuration = max(0, duration - fadeDuration)
        stopTask = Task { [weak self] in
            if sustainDuration > 0 {
                try? await Task.sleep(for: .seconds(sustainDuration))
            }
            guard let self, !Task.isCancelled else { return }
            if fadeDuration > 0 {
                await self.fadeCatalog(duration: fadeDuration)
            } else {
                self.stop()
            }
        }
    }

    private func effectiveFadeDuration(
        playbackDuration: TimeInterval,
        fadeOut: TimeInterval,
        fadeOutVolumeAutomationEnabled: Bool
    ) -> TimeInterval {
        guard fadeOutVolumeAutomationEnabled else { return 0 }
        let boundedPlayback = max(0, playbackDuration)
        let boundedFade = max(0, fadeOut)
        return min(boundedPlayback, boundedFade)
    }

    private func fadeLocal(duration: TimeInterval) async {
        guard let player = audioPlayer else { return }
        for step in stride(from: 8, through: 1, by: -1) {
            player.volume = Float(step) / 8
            try? await Task.sleep(for: .seconds(duration / 8))
        }
        stop()
    }

    private func fadeRemote(duration: TimeInterval) async {
        guard let player = remotePlayer else { return }
        for step in stride(from: 8, through: 1, by: -1) {
            player.volume = Float(step) / 8
            try? await Task.sleep(for: .seconds(duration / 8))
        }
        stop()
    }

    private func fadeCatalog(duration: TimeInterval) async {
        for step in stride(from: 8, through: 1, by: -1) {
            catalogPlaybackController.setVolume(Float(step) / 8)
            try? await Task.sleep(for: .seconds(duration / 8))
        }
        stop()
    }
}

private extension CueSource {
    var maximumPlaybackDuration: TimeInterval? {
        switch self {
        case .appleMusic:
            return 20
        case .localAudio, .builtInClip:
            return nil
        }
    }
}

@MainActor
final class ReadinessService {
    private let audioAssetService: AudioAssetService
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "RollCall.Readiness")
    private var pathStatus: NWPath.Status = .requiresConnection

    init(audioAssetService: AudioAssetService) {
        self.audioAssetService = audioAssetService
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.pathStatus = path.status
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    func snapshot(for team: Team?) -> ReadinessStatus {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute.outputs.first?.portName ?? "Unknown"
        let volume = session.outputVolume
        let appleMusicCount = team?.players.compactMap(\.cue).filter { cue in
            if case .appleMusic = cue.source { return true }
            return false
        }.count ?? 0
        let musicAuthStatus = MusicAuthorization.currentStatus
        let playerChecks = (team?.battingOrderPlayers ?? []).compactMap { readinessCheck(for: $0, team: team) }
        let customChecks = customAnnouncerChecks(for: team)
        return ReadinessStatus(
            generatedAt: .now,
            checks: [
                ReadinessCheck(id: "route", title: "Audio Route", detail: route, state: route == "Unknown" ? .warning : .ready),
                ReadinessCheck(id: "volume", title: "Volume", detail: "\(Int(volume * 100))%", state: volume < 0.25 ? .warning : .ready),
                ReadinessCheck(id: "network", title: "Apple Music Network", detail: appleMusicCount == 0 ? "No Apple Music cues assigned." : (pathStatus == .satisfied ? "Connection available." : "Connection unavailable. Apple Music cues may fail."), state: appleMusicCount == 0 ? .unknown : (pathStatus == .satisfied ? .ready : .warning)),
                ReadinessCheck(id: "music-auth", title: "Apple Music Access", detail: appleMusicCount == 0 ? "No Apple Music cues assigned." : appleMusicAuthorizationDetail(for: musicAuthStatus), state: readinessStateForMusic(status: musicAuthStatus, appleMusicCount: appleMusicCount)),
                ReadinessCheck(id: "lineup", title: "Present Players", detail: "\(team?.presentPlayersInBattingOrder.count ?? 0) players marked present", state: team == nil ? .warning : ((team?.presentPlayersInBattingOrder.isEmpty ?? true) ? .warning : .ready)),
            ] + customChecks + playerChecks
        )
    }

    private func readinessCheck(for player: Player, team: Team?) -> ReadinessCheck? {
        guard player.isPresent else { return nil }
        guard let cue = player.cue else {
            return ReadinessCheck(id: "player-\(player.id)", title: player.displayName, detail: "Present player has no cue assigned.", state: .warning)
        }

        switch cue.source {
        case .appleMusic:
            break
        case .localAudio(let source):
            if !audioAssetService.assetExists(relativePath: source.relativePath) {
                return ReadinessCheck(id: "player-\(player.id)", title: player.displayName, detail: "Local cue file is missing from app storage.", state: .failed)
            }
        case .builtInClip(let source):
            if !audioAssetService.assetExists(relativePath: builtInClipRelativePath(for: source)) {
                return ReadinessCheck(id: "player-\(player.id)", title: player.displayName, detail: "Built-in clip asset is missing.", state: .failed)
            }
        }

        if team?.session.gameDayAnnouncerMode.usesAnnouncer == true {
            if let customAnnouncerRelativePath = player.customAnnouncerRelativePath {
                if !audioAssetService.assetExists(relativePath: customAnnouncerRelativePath) {
                    return ReadinessCheck(id: "player-\(player.id)-custom-announcer", title: player.displayName, detail: "Announcement Cue file is missing from app storage.", state: .failed)
                }
            }
        }

        if let photoRelativePath = player.photoRelativePath,
           !audioAssetService.assetExists(relativePath: photoRelativePath) {
            return ReadinessCheck(id: "player-\(player.id)-photo", title: player.displayName, detail: "Player photo is missing from app storage.", state: .warning)
        }

        return ReadinessCheck(id: "player-\(player.id)-ready", title: player.displayName, detail: "Cue is ready.", state: .ready)
    }

    private func customAnnouncerChecks(for team: Team?) -> [ReadinessCheck] {
        guard let team else { return [] }
        guard team.session.gameDayAnnouncerMode == .announcerOnly else { return [] }
        let presentPlayers = team.presentPlayersInBattingOrder
        guard !presentPlayers.isEmpty else { return [] }

        let playersWithCustom = presentPlayers.filter {
            guard let relativePath = $0.customAnnouncerRelativePath else { return false }
            return audioAssetService.assetExists(relativePath: relativePath)
        }
        if playersWithCustom.isEmpty {
            return [
                ReadinessCheck(
                    id: "custom-announcers-none",
                    title: "Announcement Cues",
                    detail: "No present players have an Announcement Cue recorded. Game Day will fall back to Small Cheer.",
                    state: .warning
                )
            ]
        }

        return presentPlayers.compactMap { player in
            guard player.customAnnouncerRelativePath == nil else { return nil }
            return ReadinessCheck(
                id: "player-\(player.id)-custom-coverage",
                title: player.displayName,
                detail: "This present player does not have an Announcement Cue recorded. Game Day will fall back to Small Cheer.",
                state: .warning
            )
        }
    }

    private func readinessStateForMusic(status: MusicAuthorization.Status, appleMusicCount: Int) -> ReadinessState {
        guard appleMusicCount > 0 else { return .unknown }
        return status == .authorized ? .ready : .warning
    }

    private func appleMusicAuthorizationDetail(for status: MusicAuthorization.Status) -> String {
        switch status {
        case .authorized:
            return "Music authorization is available."
        case .denied:
            return "Music authorization is denied."
        case .restricted:
            return "Music authorization is restricted."
        case .notDetermined:
            return "Music authorization has not been requested yet."
        @unknown default:
            return "Music authorization state is unknown."
        }
    }
}

struct PackageService: Sendable {
    func export(team: Team, state: AppState) throws -> URL {
        let packageName = safePackageName(for: team.name)
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(packageName).rollcall", isDirectory: false)
        let stagingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("\(packageName)-\(UUID().uuidString)", isDirectory: true)
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }
        if FileManager.default.fileExists(atPath: stagingDirectory.path) {
            try FileManager.default.removeItem(at: stagingDirectory)
        }
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }

        let manifest = TeamPackageManifest(schemaVersion: state.schemaVersion, appVersion: state.appVersion, exportedAt: .now, deviceLabel: state.deviceIdentity.label, team: sanitized(team))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: stagingDirectory.appendingPathComponent("manifest.json"), options: .atomic)

        let packageAssetsURL = stagingDirectory.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: packageAssetsURL, withIntermediateDirectories: true)
        try copyAssets(for: manifest.team, into: packageAssetsURL)
        try FileManager.default.zipItem(at: stagingDirectory, to: exportURL, shouldKeepParent: false)

        return exportURL
    }

    func `import`(packageURL: URL, audioAssetService: AudioAssetService) throws -> TeamPackageManifest {
        let extractedDirectory = try extractedDirectoryIfNeeded(for: packageURL)
        defer {
            if let extractedDirectory {
                try? FileManager.default.removeItem(at: extractedDirectory)
            }
        }

        let packageRootURL = extractedDirectory ?? packageURL
        let manifestURL = try manifestURL(for: packageRootURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var manifest = try decoder.decode(TeamPackageManifest.self, from: Data(contentsOf: manifestURL))

        if try isDirectory(packageRootURL) {
            let packageAssetsURL = packageRootURL.appendingPathComponent("Assets", isDirectory: true)
            manifest.team = try importAssets(for: manifest.team, from: packageAssetsURL, audioAssetService: audioAssetService)
        }
        return manifest
    }

    func parseRosterCSV(from url: URL) async throws -> [ParsedRosterRow] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw AppError.invalidCSV
        }

        let rawLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !rawLines.isEmpty else { throw AppError.invalidCSV }

        let parsedLines = rawLines.map(parseCSVColumns)
        let firstRow = parsedLines[0].map { $0.lowercased() }
        let hasHeader = firstRow.contains("name")
        let rows = (hasHeader ? Array(parsedLines.dropFirst()) : parsedLines).compactMap { columns -> ParsedRosterRow? in
            guard !columns.isEmpty else { return nil }
            if hasHeader {
                guard let nameIndex = firstRow.firstIndex(of: "name") else { return nil }
                let numberIndex = firstRow.firstIndex(of: "number")
                let name = columns[safe: nameIndex]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let number = numberIndex.flatMap { columns[safe: $0] }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else { return nil }
                return ParsedRosterRow(name: name, number: number)
            }

            let name = columns.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let number = columns.count > 1 ? columns[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            guard !name.isEmpty else { return nil }
            return ParsedRosterRow(name: name, number: number)
        }

        guard !rows.isEmpty else { throw AppError.invalidCSV }
        return rows
    }

    func exportSupportBundle(
        state: AppState,
        selectedTeam: Team?,
        diagnostics: PlaybackSupportDiagnostics
    ) throws -> URL {
        let teamSummaries = state.teams.map { team in
            SupportBundlePayload.TeamSummary(
                id: team.id,
                name: team.name,
                playerCount: team.players.count,
                presentPlayerCount: team.presentPlayersInBattingOrder.count,
                builtInClipCount: team.builtInClips.count
            )
        }
        let payload = SupportBundlePayload(
            generatedAt: .now,
            appVersion: state.appVersion,
            schemaVersion: state.schemaVersion,
            selectedTeamID: selectedTeam?.id,
            settings: state.settings,
            experimental: state.experimental,
            readiness: state.lastReadiness,
            playback: diagnostics,
            teams: teamSummaries
        )

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RollCall-Support-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(payload).write(to: url, options: .atomic)
        return url
    }

    private func sanitized(_ team: Team) -> Team {
        var team = team
        team.players = team.players.map { player in
            var player = player
            if case .localAudio(var local)? = player.cue?.source {
                local.hiddenOriginNote = nil
                player.cue?.source = .localAudio(local)
            }
            return player
        }
        return team
    }

    private func safePackageName(for teamName: String) -> String {
        let sanitized = teamName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "RollCall-Team" : sanitized.replacingOccurrences(of: " ", with: "-")
    }

    private func extractedDirectoryIfNeeded(for packageURL: URL) throws -> URL? {
        if try isDirectory(packageURL) {
            return nil
        }
        let extractedURL = FileManager.default.temporaryDirectory.appendingPathComponent("RollCall-Import-\(UUID().uuidString)", isDirectory: true)
        if FileManager.default.fileExists(atPath: extractedURL.path) {
            try FileManager.default.removeItem(at: extractedURL)
        }
        try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)
        do {
            try FileManager.default.unzipItem(at: packageURL, to: extractedURL)
            return extractedURL
        } catch {
            try? FileManager.default.removeItem(at: extractedURL)
            throw error
        }
    }

    private func manifestURL(for packageURL: URL) throws -> URL {
        if try isDirectory(packageURL) {
            let manifestURL = packageURL.appendingPathComponent("manifest.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else { throw AppError.invalidImport }
            return manifestURL
        }
        return packageURL
    }

    private func copyAssets(for team: Team, into assetsDirectory: URL) throws {
        try copyPlayerAssets(for: team.players, into: assetsDirectory)
    }

    private func copyPlayerAssets(for players: [Player], into assetsDirectory: URL) throws {
        for player in players {
            if let photoRelativePath = player.photoRelativePath {
                try copyAssetIfPresent(relativePath: photoRelativePath, into: assetsDirectory)
            }
            if let cue = player.cue,
               case .localAudio(let source) = cue.source {
                try copyAssetIfPresent(relativePath: source.relativePath, into: assetsDirectory)
            }
            try copyAssetIfPresent(relativePath: player.customAnnouncerRelativePath, into: assetsDirectory)
        }
    }

    private func copyAssetIfPresent(relativePath: String?, into packageAssetsDirectory: URL) throws {
        guard let relativePath else { return }
        let sourceURL = try AppPaths.assetURL(relativePath: relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        let destinationURL = packageAssetsDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func importAssets(for team: Team, from packageAssetsDirectory: URL, audioAssetService: AudioAssetService) throws -> Team {
        var importedTeam = team
        importedTeam.players = try importedTeam.players.map { player in
            var player = player
            if let photoRelativePath = player.photoRelativePath {
                player.photoRelativePath = try importPhotoIfPresent(relativePath: photoRelativePath, from: packageAssetsDirectory)
            }
            if case .localAudio(let source)? = player.cue?.source {
                let importedSource = try importLocalAudio(source, from: packageAssetsDirectory, audioAssetService: audioAssetService)
                player.cue?.source = .localAudio(importedSource)
            }
            player.customAnnouncerRelativePath = try importGeneratedAudioIfPresent(relativePath: player.customAnnouncerRelativePath, from: packageAssetsDirectory, audioAssetService: audioAssetService)
            return player
        }
        return importedTeam
    }

    private func importLocalAudio(_ source: LocalAudioSource, from packageAssetsDirectory: URL, audioAssetService: AudioAssetService) throws -> LocalAudioSource {
        let sourceURL = packageAssetsDirectory.appendingPathComponent(source.relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return source }
        var imported = try audioAssetService.storeCopiedAsset(
            from: sourceURL,
            suggestedExtension: sourceURL.pathExtension,
            displayName: source.displayName,
            hiddenOriginNote: source.hiddenOriginNote
        )
        imported.importedAt = source.importedAt
        imported.hiddenOriginNote = source.hiddenOriginNote
        return imported
    }

    private func importGeneratedAudioIfPresent(relativePath: String?, from packageAssetsDirectory: URL, audioAssetService: AudioAssetService) throws -> String? {
        guard let relativePath else { return nil }
        let sourceURL = packageAssetsDirectory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }
        let imported = try audioAssetService.storeCopiedAsset(
            from: sourceURL,
            suggestedExtension: sourceURL.pathExtension,
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            hiddenOriginNote: nil
        )
        return imported.relativePath
    }

    private func importPhotoIfPresent(relativePath: String, from packageAssetsDirectory: URL) throws -> String? {
        let sourceURL = packageAssetsDirectory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = try AppPaths.assetURL(relativePath: "\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.lastPathComponent
    }

    private func isDirectory(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        return values.isDirectory == true
    }

    private func parseCSVColumns(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        for character in line {
            switch character {
            case "\"":
                inQuotes.toggle()
            case "," where !inQuotes:
                values.append(current)
                current = ""
            default:
                current.append(character)
            }
        }
        values.append(current)
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
