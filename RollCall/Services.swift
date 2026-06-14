import AVFAudio
import AVFoundation
import Foundation
import MediaPlayer
import OSLog
@preconcurrency import MusicKit
import Network
import UniformTypeIdentifiers
import ZIPFoundation

enum AppError: LocalizedError {
    case missingPreview
    case featureDisabled
    case invalidImport
    case unsupportedImportVersion
    case unsupportedSavedStateVersion
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
    case noSelectedTeam
    case noAppleMusicTeamCues
    case appleMusicPlaylistSyncFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPreview:
            return "This Apple Music selection does not expose preview media for the experimental local-copy path."
        case .featureDisabled:
            return "Experimental local copies are disabled in Settings."
        case .invalidImport:
            return "That file could not be imported."
        case .unsupportedImportVersion:
            return "That package was created by a newer Roll Call version. Update Roll Call, then try importing it again."
        case .unsupportedSavedStateVersion:
            return "Saved Roll Call data was created by a newer app version. Update Roll Call to recover that data."
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
        case .noSelectedTeam:
            return "Select a team before updating an Apple Music team playlist."
        case .noAppleMusicTeamCues:
            return "No Apple Music song cues found for this team."
        case .appleMusicPlaylistSyncFailed(let message):
            return "Apple Music could not update this team playlist. \(message)"
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

    func storeCustomAnnouncerRecording(from sourceURL: URL, playerID: UUID, displayName: String, relativePath preferredRelativePath: String? = nil) throws -> LocalAudioSource {
        let relativePath = preferredRelativePath ?? "custom-intro-\(playerID.uuidString.lowercased()).caf"
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

    func freshCustomAnnouncerRelativePath() -> String {
        "\(UUID().uuidString).caf"
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

    func builtInClipExists(source: BuiltInClipSource) -> Bool {
        assetExists(relativePath: builtInClipRelativePath(for: source))
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

struct MusicSearchResult: Identifiable, Hashable {
    var id: String { songID }
    var songID: String
    var title: String
    var artistName: String
    var duration: TimeInterval?
    var previewURL: URL?
    var artworkURL: URL? = nil
    var isCatalogBacked: Bool = true
}

struct ResolvedTeamPlaylistSongs {
    var songs: [Song]
    var resolvedSongIDs: [String]
    var unresolvedSongIDs: [String]
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
            artworkURL: song.artwork?.url(width: 120, height: 120) ?? result.artworkURL,
            isCatalogBacked: true
        )
    }

    func playbackCapability() async -> AppleMusicPlaybackCapability {
        do {
            let status = currentAuthorizationStatus()
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

    func syncTeamPlaylist(name: String, songIDs: [String]) async throws {
        let status = try await authorizedStatus()
        guard status == .authorized else { throw AppError.musicAuthorizationRequired }

        let resolved = try await catalogSongs(for: songIDs)
        guard !resolved.songs.isEmpty else { throw AppError.noAppleMusicTeamCues }
        try await replaceTeamPlaylist(name: name, songs: resolved.songs)
    }

    func resolveTeamPlaylistSongs(songIDs: [String]) async throws -> ResolvedTeamPlaylistSongs {
        let status = try await authorizedStatus()
        guard status == .authorized else { throw AppError.musicAuthorizationRequired }

        return try await catalogSongs(for: songIDs)
    }

    func replaceTeamPlaylist(name: String, songs: [Song]) async throws {
        guard !songs.isEmpty else { throw AppError.noAppleMusicTeamCues }
        let playlist = try await existingLibraryPlaylist(named: name)
        do {
            if let playlist {
                try await MusicLibrary.shared.edit(
                    playlist,
                    name: name,
                    description: teamPlaylistDescription,
                    authorDisplayName: "Roll Call",
                    items: songs
                )
            } else {
                try await MusicLibrary.shared.createPlaylist(
                    name: name,
                    description: teamPlaylistDescription,
                    authorDisplayName: "Roll Call",
                    items: songs
                )
            }
        } catch {
            throw AppError.appleMusicPlaylistSyncFailed(error.localizedDescription)
        }
    }

    private func catalogSearch(term: String) async throws -> [MusicSearchResult] {
        let status = try await authorizedStatus()
        guard status == .authorized else { throw AppError.musicAuthorizationRequired }
        return try await searchWithMusicKit(term: term)
    }

    private var teamPlaylistDescription: String {
        "Generated by Roll Call from the selected team's Apple Music song cues."
    }

    private func existingLibraryPlaylist(named name: String) async throws -> Playlist? {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 25
        request.filter(matching: \.name, equalTo: name)
        let response = try await request.response()
        return response.items.first
    }

    private func catalogSongs(for songIDs: [String]) async throws -> ResolvedTeamPlaylistSongs {
        var songs: [Song] = []
        var resolvedSongIDs: [String] = []
        var unresolvedSongIDs: [String] = []
        for songID in songIDs {
            var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(songID))
            request.limit = 1
            let response = try await request.response()
            if let song = response.items.first {
                songs.append(song)
                resolvedSongIDs.append(songID)
            } else {
                unresolvedSongIDs.append(songID)
            }
        }
        return ResolvedTeamPlaylistSongs(
            songs: songs,
            resolvedSongIDs: resolvedSongIDs,
            unresolvedSongIDs: unresolvedSongIDs
        )
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
                artworkURL: $0.artwork?.url(width: 120, height: 120),
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
                artworkURL: item.artworkURL,
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

    private func currentAuthorizationStatus() -> MusicAuthorization.Status {
        MusicAuthorization.currentStatus
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
    let artworkURL: URL?

    enum CodingKeys: String, CodingKey {
        case trackID = "trackId"
        case trackName
        case artistName
        case previewURL = "previewUrl"
        case trackTimeMillis
        case artworkURL = "artworkUrl100"
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
        var name: String
        var playerCount: Int
        var presentPlayerCount: Int
        var builtInClipCount: Int
    }

    var generatedAt: Date
    var appVersion: String
    var schemaVersion: Int
    var selectedTeamIndex: Int?
    var settings: AppSettings
    var experimental: ExperimentalSettings
    var readiness: ReadinessStatus?
    var playback: PlaybackSupportDiagnostics
    var teams: [TeamSummary]
}

@MainActor
private protocol AppleMusicCatalogPlaybackControlling: AnyObject {
    var usesSystemTransitionCrossfade: Bool { get }
    func preconnect()
    func play(
        songID: String,
        song: Song?,
        startTime: TimeInterval,
        duration: TimeInterval,
        volumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        fadeOutDuration: TimeInterval,
        transitionCrossfadeEnabled: Bool
    ) async throws
    func setVolume(_ volume: Float)
    func restoreVolume()
    func discardPendingRestore()
    func stop(restoresVolume: Bool)
}

@MainActor
private final class MediaPlayerCatalogPlaybackController: AppleMusicCatalogPlaybackControlling {
    private let player: MPMusicPlayerApplicationController
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "RollCall",
        category: "AppleMusicVolumeAutomation"
    )

    private var capturedSystemVolumeBaseline: Float = 1
    private var volumeAutomationEnabledForCurrentCue = true
    private var hasPendingVolumeRestore = false

    var usesSystemTransitionCrossfade: Bool { false }

    init(player: MPMusicPlayerApplicationController = MPMusicPlayerController.applicationQueuePlayer) {
        self.player = player
    }

    func preconnect() {
        _ = player
    }

    func play(
        songID: String,
        song: Song?,
        startTime: TimeInterval,
        duration: TimeInterval,
        volumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        fadeOutDuration: TimeInterval,
        transitionCrossfadeEnabled: Bool
    ) async throws {
        volumeAutomationEnabledForCurrentCue = volumeAutomationEnabled
        if volumeAutomationEnabled {
            // Volume Automation must not touch Apple Music volume before playback starts.
            // Capture the pre-cue baseline here, only apply volume changes once fade-out
            // begins, then restore this exact baseline after playback has fully stopped.
            captureSystemVolumeBaseline()
            hasPendingVolumeRestore = true
        } else {
            hasPendingVolumeRestore = false
        }
        player.stop()

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

        if startTime > 0 {
            await Task.yield()
            player.currentPlaybackTime = startTime
        }
    }

    func setVolume(_ volume: Float) {
        let clamped = min(max(0, volume), 1)
        setPlayerVolume(capturedSystemVolumeBaseline * clamped)
    }

    func restoreVolume() {
        guard hasPendingVolumeRestore else { return }
        setPlayerVolume(capturedSystemVolumeBaseline)
        Self.logger.debug(
            "Restored Apple Music player volume to captured baseline \(self.formattedVolume(self.capturedSystemVolumeBaseline), privacy: .public) after playback stopped"
        )
        hasPendingVolumeRestore = false
    }

    func discardPendingRestore() {
        guard hasPendingVolumeRestore else { return }
        hasPendingVolumeRestore = false
        Self.logger.debug(
            "Discarded pending Apple Music restore during cue handoff; next cue will recapture system volume baseline from \(self.formattedVolume(self.capturedSystemVolumeBaseline), privacy: .public)"
        )
    }

    func stop(restoresVolume: Bool = true) {
        player.stop()
        if restoresVolume {
            restoreVolume()
        }
        volumeAutomationEnabledForCurrentCue = false
    }

    private func captureSystemVolumeBaseline() {
        capturedSystemVolumeBaseline = AVAudioSession.sharedInstance().outputVolume
        Self.logger.debug(
            "Captured system volume baseline \(self.formattedVolume(self.capturedSystemVolumeBaseline), privacy: .public) before Apple Music automation"
        )
    }

    private func formattedVolume(_ volume: Float) -> String {
        String(format: "%.3f", volume)
    }

    private func setPlayerVolume(_ volume: Float) {
        // `MPMusicPlayerController.volume` is marked unavailable on modern iOS SDKs,
        // but the application queue player still exposes the underlying Objective-C
        // setter. Keep this isolated as a provisional on-device experiment.
        player.setValue(volume, forKey: "volume")
    }

}

@available(iOS 18.0, *)
@MainActor
private final class MusicKitTransitionCatalogPlaybackController: AppleMusicCatalogPlaybackControlling {
    private let player: ApplicationMusicPlayer

    var usesSystemTransitionCrossfade: Bool { true }

    init(player: ApplicationMusicPlayer = .shared) {
        self.player = player
    }

    func preconnect() {
        _ = player
    }

    func play(
        songID: String,
        song: Song?,
        startTime: TimeInterval,
        duration: TimeInterval,
        volumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        fadeOutDuration: TimeInterval,
        transitionCrossfadeEnabled: Bool
    ) async throws {
        guard let song else { throw AppError.appleMusicSongUnavailable }

        let boundedStartTime = max(0, startTime)
        let boundedDuration = max(0, duration)
        let boundedFade = min(boundedDuration, max(0, fadeOutDuration))

        player.stop()
        player.transition = transitionCrossfadeEnabled && boundedFade > 0
            ? .crossfade(duration: boundedFade)
            : .none
        let entry = MusicPlayer.Queue.Entry(
            song,
            startTime: boundedStartTime,
            endTime: boundedStartTime + boundedDuration
        )
        player.queue = ApplicationMusicPlayer.Queue([entry])
        try await player.prepareToPlay()
        try await player.play()
    }

    func setVolume(_ volume: Float) {
    }

    func restoreVolume() {
    }

    func discardPendingRestore() {
    }

    func stop(restoresVolume: Bool = true) {
        player.stop()
        player.transition = .none
    }
}

@MainActor
final class CuePlaybackEngine: NSObject, ObservableObject {
    @Published private(set) var activeCueID: UUID?

    private let audioAssetService: AudioAssetService
    private let musicCatalogService: MusicCatalogService
    private var catalogPlaybackController: any AppleMusicCatalogPlaybackControlling
    private let debounceWindow: TimeInterval = 0.45
    private let appleMusicClipDurationLimit: TimeInterval = 20
    private let primaryCueTailGuard: TimeInterval = 0.75
    private let announcerCompletionGrace: TimeInterval = 1.25
    private let announcerCompletionPollInterval: TimeInterval = 0.05
    private var audioPlayer: AVAudioPlayer?
    private var announcerPlayer: AVAudioPlayer?
    private var remotePlayer: AVPlayer?
    private var stopTask: Task<Void, Never>?
    private var prewarmedCueID: UUID?
    private var prewarmedLocalPlayer: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var playbackSessionID = UUID()
    private var lastStartDate: Date?
    private var lastStartedCueID: UUID?
    private var volumeAutomationEnabledForCurrentCue = false
    private var appleMusicTransitionCrossfadeExperimentEnabled = false

    init(
        audioAssetService: AudioAssetService,
        musicCatalogService: MusicCatalogService
    ) {
        self.audioAssetService = audioAssetService
        self.musicCatalogService = musicCatalogService
        self.catalogPlaybackController = MediaPlayerCatalogPlaybackController()
    }

    func setAppleMusicTransitionCrossfadeExperimentEnabled(_ isEnabled: Bool) {
        let wantsExperiment = isEnabled
        let needsControllerSwap = catalogPlaybackController.usesSystemTransitionCrossfade != wantsExperiment
        appleMusicTransitionCrossfadeExperimentEnabled = wantsExperiment
        guard needsControllerSwap else { return }
        stop()
        catalogPlaybackController = Self.makeCatalogPlaybackController(
            appleMusicTransitionCrossfadeExperimentEnabled: wantsExperiment
        )
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
        let sessionID = beginPlayback(
            activeCueID: cue.id,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        lastStartDate = Date()
        lastStartedCueID = cue.id
        do {
            try await playCueSequence(
                cue,
                announcerRelativePath: announcerRelativePath,
                fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                sessionID: sessionID
            )
        } catch {
            stopIfCurrent(sessionID: sessionID)
            throw error
        }
    }

    func playAsset(
        relativePath: String,
        activeCueID: UUID,
        fadeOutVolumeAutomationEnabled: Bool = true
    ) async throws {
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
        let sessionID = beginPlayback(
            activeCueID: activeCueID,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        lastStartDate = Date()
        lastStartedCueID = activeCueID

        do {
            let url = try audioAssetService.assetURL(relativePath: relativePath)
            let player = try AVAudioPlayer(contentsOf: url)
            announcerPlayer = player
            player.prepareToPlay()
            if fadeOutVolumeAutomationEnabled {
                player.volume = 1
            }
            guard player.play() else {
                announcerPlayer = nil
                stopIfCurrent(sessionID: sessionID)
                return
            }

            stopTask = Task { [weak self] in
                await self?.waitForAnnouncerPlaybackToFinish(player)
                guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                self.stop()
            }
        } catch {
            stopIfCurrent(sessionID: sessionID)
            throw error
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
        let sessionID = beginPreview()
        let player = try AVAudioPlayer(data: data)
        previewPlayer = player
        player.prepareToPlay()
        player.play()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(player.duration))
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            self.previewPlayer?.stop()
            self.previewPlayer = nil
            self.stopTask = nil
        }
    }

    func previewAsset(relativePath: String) throws {
        stop()
        let sessionID = beginPreview()
        let url = try audioAssetService.assetURL(relativePath: relativePath)
        let player = try AVAudioPlayer(contentsOf: url)
        previewPlayer = player
        player.prepareToPlay()
        player.play()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(player.duration))
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            self.previewPlayer?.stop()
            self.previewPlayer = nil
            self.stopTask = nil
        }
    }

    func stop() {
        stop(restoresCatalogVolume: true)
    }

    private func stop(restoresCatalogVolume: Bool) {
        playbackSessionID = UUID()
        stopTask?.cancel()
        stopTask = nil
        announcerPlayer?.stop()
        if volumeAutomationEnabledForCurrentCue {
            announcerPlayer?.volume = 1
        }
        announcerPlayer = nil
        audioPlayer?.stop()
        if volumeAutomationEnabledForCurrentCue {
            audioPlayer?.volume = 1
        }
        audioPlayer = nil
        remotePlayer?.pause()
        if volumeAutomationEnabledForCurrentCue {
            remotePlayer?.volume = 1
        }
        remotePlayer = nil
        catalogPlaybackController.stop(restoresVolume: restoresCatalogVolume)
        previewPlayer?.stop()
        previewPlayer = nil
        activeCueID = nil
        volumeAutomationEnabledForCurrentCue = false
    }

    private func beginPlayback(activeCueID: UUID, fadeOutVolumeAutomationEnabled: Bool) -> UUID {
        // When replacing one cue with another, keep the outgoing cue from briefly
        // restoring its old Apple Music volume before the new cue captures its own anchor.
        stop(restoresCatalogVolume: false)
        catalogPlaybackController.discardPendingRestore()
        let sessionID = UUID()
        playbackSessionID = sessionID
        self.activeCueID = activeCueID
        volumeAutomationEnabledForCurrentCue = fadeOutVolumeAutomationEnabled
        return sessionID
    }

    private func beginPreview() -> UUID {
        let sessionID = UUID()
        playbackSessionID = sessionID
        return sessionID
    }

    private func stopIfCurrent(sessionID: UUID) {
        guard playbackSessionID == sessionID else { return }
        stop()
    }

    private func playCueSequence(
        _ cue: Cue,
        announcerRelativePath: String?,
        fadeOutVolumeAutomationEnabled: Bool,
        sessionID: UUID
    ) async throws {
        if let relativePath = announcerRelativePath {
            try? await prewarm(cue: cue)
            guard playbackSessionID == sessionID else { return }

            let announcerURL = try audioAssetService.assetURL(relativePath: relativePath)
            guard FileManager.default.fileExists(atPath: announcerURL.path) else {
                try await startPrimaryCue(
                    cue,
                    fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                    sessionID: sessionID
                )
                return
            }

            let player: AVAudioPlayer
            do {
                player = try AVAudioPlayer(contentsOf: announcerURL)
            } catch {
                try await startPrimaryCue(
                    cue,
                    fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                    sessionID: sessionID
                )
                return
            }
            announcerPlayer = player
            player.prepareToPlay()
            if fadeOutVolumeAutomationEnabled {
                player.volume = 1
            }
            guard player.play() else {
                announcerPlayer = nil
                try await startPrimaryCue(
                    cue,
                    fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                    sessionID: sessionID
                )
                return
            }

            guard player.duration.isFinite, player.duration >= 0 else {
                try await startPrimaryCue(
                    cue,
                    fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                    sessionID: sessionID
                )
                return
            }

            stopTask = Task { [weak self] in
                await self?.waitForAnnouncerPlaybackToFinish(player)
                guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                let pauseAfterAnnouncer = max(0, cue.pauseAfterAnnouncer)
                if pauseAfterAnnouncer > 0 {
                    try? await Task.sleep(for: .seconds(pauseAfterAnnouncer))
                    guard !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                }
                do {
                    try await self.startPrimaryCue(
                        cue,
                        cancelPendingStopTask: false,
                        fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                        setsInitialVolumeToMax: false,
                        sessionID: sessionID
                    )
                } catch {
                    self.stopIfCurrent(sessionID: sessionID)
                }
            }
            return
        }

        try await startPrimaryCue(
            cue,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
            sessionID: sessionID
        )
    }

    private func startPrimaryCue(
        _ cue: Cue,
        cancelPendingStopTask: Bool = true,
        fadeOutVolumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool = true,
        sessionID: UUID
    ) async throws {
        guard playbackSessionID == sessionID else { return }
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
                guard playbackSessionID == sessionID else { return }
                do {
                    try await playCatalogSong(
                        source: source,
                        startTime: cue.startTime,
                        duration: clipDuration,
                        fadeOut: cue.fadeOutDuration,
                        fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                        setsInitialVolumeToMax: setsInitialVolumeToMax,
                        sessionID: sessionID
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
            player.seek(to: CMTime(seconds: previewStart, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] _ in
                Task { @MainActor [weak self, weak player] in
                    guard self?.playbackSessionID == sessionID else { return }
                    if fadeOutVolumeAutomationEnabled, setsInitialVolumeToMax {
                        player?.volume = 1
                    }
                    player?.play()
                }
            }
            scheduleRemoteStop(
                duration: clipDuration,
                fadeOut: cue.fadeOutDuration,
                fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                sessionID: sessionID
            )
        case .localAudio(let source):
            let url = try audioAssetService.assetURL(relativePath: source.relativePath)
            try playLocal(
                url: url,
                start: cue.startTime,
                duration: duration,
                fadeOut: cue.fadeOutDuration,
                fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                setsInitialVolumeToMax: setsInitialVolumeToMax,
                reusePrewarm: prewarmedCueID == cue.id,
                sessionID: sessionID
            )
        case .builtInClip(let source):
            let url = try audioAssetService.assetURL(relativePath: builtInClipRelativePath(for: source))
            try playLocal(
                url: url,
                start: cue.startTime,
                duration: duration,
                fadeOut: cue.fadeOutDuration,
                fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
                setsInitialVolumeToMax: setsInitialVolumeToMax,
                reusePrewarm: prewarmedCueID == cue.id,
                sessionID: sessionID
            )
        }
    }

    private func playCatalogSong(
        source: AppleMusicSource,
        startTime: TimeInterval,
        duration: TimeInterval,
        fadeOut: TimeInterval,
        fadeOutVolumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        sessionID: UUID
    ) async throws {
        let song: Song? = if catalogPlaybackController.usesSystemTransitionCrossfade {
            try await musicCatalogService.song(for: source.songID)
        } else {
            nil
        }
        try await catalogPlaybackController.play(
            songID: source.songID,
            song: song,
            startTime: startTime,
            duration: catalogPlaybackController.usesSystemTransitionCrossfade
                ? duration
                : catalogPlaybackDurationIncludingTailGuard(for: duration),
            volumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
            setsInitialVolumeToMax: setsInitialVolumeToMax,
            fadeOutDuration: fadeOut,
            transitionCrossfadeEnabled: fadeOutVolumeAutomationEnabled && catalogPlaybackController.usesSystemTransitionCrossfade
        )
        guard playbackSessionID == sessionID else { return }
        scheduleCatalogStop(
            duration: duration,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled && !catalogPlaybackController.usesSystemTransitionCrossfade,
            sessionID: sessionID
        )
    }

    private func playLocal(
        url: URL,
        start: TimeInterval,
        duration: TimeInterval,
        fadeOut: TimeInterval,
        fadeOutVolumeAutomationEnabled: Bool,
        setsInitialVolumeToMax: Bool,
        reusePrewarm: Bool,
        sessionID: UUID
    ) throws {
        let player = if reusePrewarm, let prewarmedLocalPlayer {
            prewarmedLocalPlayer
        } else {
            try AVAudioPlayer(contentsOf: url)
        }
        audioPlayer = player
        if fadeOutVolumeAutomationEnabled, setsInitialVolumeToMax {
            player.volume = 1
        }
        player.currentTime = start
        player.play()
        scheduleLocalStop(
            duration: duration,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled,
            sessionID: sessionID
        )
    }

    private func scheduleLocalStop(duration: TimeInterval, fadeOut: TimeInterval, fadeOutVolumeAutomationEnabled: Bool, sessionID: UUID) {
        let stopDelay = playbackStopDelayIncludingTailGuard(for: duration)
        let fadeDuration = effectiveFadeDuration(
            playbackDuration: stopDelay,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        let sustainDuration = max(0, stopDelay - fadeDuration)
        stopTask = Task { [weak self] in
            if sustainDuration > 0 {
                try? await Task.sleep(for: .seconds(sustainDuration))
            }
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            if fadeDuration > 0 {
                await self.fadeLocal(duration: fadeDuration, sessionID: sessionID)
            } else {
                self.stopIfCurrent(sessionID: sessionID)
            }
        }
    }

    private func scheduleRemoteStop(duration: TimeInterval, fadeOut: TimeInterval, fadeOutVolumeAutomationEnabled: Bool, sessionID: UUID) {
        let stopDelay = playbackStopDelayIncludingTailGuard(for: duration)
        let fadeDuration = effectiveFadeDuration(
            playbackDuration: stopDelay,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        let sustainDuration = max(0, stopDelay - fadeDuration)
        stopTask = Task { [weak self] in
            if sustainDuration > 0 {
                try? await Task.sleep(for: .seconds(sustainDuration))
            }
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            if fadeDuration > 0 {
                await self.fadeRemote(duration: fadeDuration, sessionID: sessionID)
            } else {
                self.stopIfCurrent(sessionID: sessionID)
            }
        }
    }

    private func scheduleCatalogStop(duration: TimeInterval, fadeOut: TimeInterval, fadeOutVolumeAutomationEnabled: Bool, sessionID: UUID) {
        let stopDelay = playbackStopDelayIncludingTailGuard(for: duration)
        let fadeDuration = effectiveFadeDuration(
            playbackDuration: stopDelay,
            fadeOut: fadeOut,
            fadeOutVolumeAutomationEnabled: fadeOutVolumeAutomationEnabled
        )
        let sustainDuration = max(0, stopDelay - fadeDuration)
        stopTask = Task { [weak self] in
            if sustainDuration > 0 {
                try? await Task.sleep(for: .seconds(sustainDuration))
            }
            guard let self, !Task.isCancelled, self.playbackSessionID == sessionID else { return }
            if fadeDuration > 0 {
                await self.fadeCatalog(duration: fadeDuration, sessionID: sessionID)
            } else {
                self.stopIfCurrent(sessionID: sessionID)
            }
        }
    }

    private func playbackStopDelayIncludingTailGuard(for duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite else { return 0 }
        return max(0, duration) + primaryCueTailGuard
    }

    private func catalogPlaybackDurationIncludingTailGuard(for duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite else { return 0 }
        return min(appleMusicClipDurationLimit, max(0, duration) + primaryCueTailGuard)
    }

    private func waitForAnnouncerPlaybackToFinish(_ player: AVAudioPlayer) async {
        let maxWait = max(0, player.duration) + announcerCompletionGrace
        let startDate = Date()
        while player.isPlaying, Date().timeIntervalSince(startDate) < maxWait {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(announcerCompletionPollInterval))
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

    private func fadeLocal(duration: TimeInterval, sessionID: UUID) async {
        guard let player = audioPlayer else { return }
        for step in stride(from: 8, through: 1, by: -1) {
            guard playbackSessionID == sessionID, !Task.isCancelled else { return }
            player.volume = Float(step) / 8
            try? await Task.sleep(for: .seconds(duration / 8))
        }
        stopIfCurrent(sessionID: sessionID)
    }

    private func fadeRemote(duration: TimeInterval, sessionID: UUID) async {
        guard let player = remotePlayer else { return }
        for step in stride(from: 8, through: 1, by: -1) {
            guard playbackSessionID == sessionID, !Task.isCancelled else { return }
            player.volume = Float(step) / 8
            try? await Task.sleep(for: .seconds(duration / 8))
        }
        stopIfCurrent(sessionID: sessionID)
    }

    private func fadeCatalog(duration: TimeInterval, sessionID: UUID) async {
        for step in stride(from: 8, through: 1, by: -1) {
            guard playbackSessionID == sessionID, !Task.isCancelled else { return }
            catalogPlaybackController.setVolume(Float(step) / 8)
            try? await Task.sleep(for: .seconds(duration / 8))
        }
        guard playbackSessionID == sessionID, !Task.isCancelled else { return }
        catalogPlaybackController.setVolume(0)
        catalogPlaybackController.stop(restoresVolume: false)
        activeCueID = nil
        volumeAutomationEnabledForCurrentCue = false
        try? await Task.sleep(for: .seconds(0.25))
        guard playbackSessionID == sessionID, !Task.isCancelled else { return }
        catalogPlaybackController.restoreVolume()
        stopTask = nil
    }
}

private extension CuePlaybackEngine {
    static func makeCatalogPlaybackController(
        appleMusicTransitionCrossfadeExperimentEnabled: Bool
    ) -> any AppleMusicCatalogPlaybackControlling {
        if appleMusicTransitionCrossfadeExperimentEnabled, #available(iOS 18.0, *) {
            return MusicKitTransitionCatalogPlaybackController()
        }
        return MediaPlayerCatalogPlaybackController()
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
    var onPathStatusChange: (() -> Void)?

    init(audioAssetService: AudioAssetService) {
        self.audioAssetService = audioAssetService
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let previousStatus = self.pathStatus
                self.pathStatus = path.status
                if previousStatus != path.status {
                    self.onPathStatusChange?()
                }
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
        let presentPlayers = team?.presentPlayersInBattingOrder ?? []
        let appleMusicCount = presentPlayers.compactMap(\.cue).filter { cue in
            if case .appleMusic = cue.source { return true }
            return false
        }.count
        let musicAuthStatus = MusicAuthorization.currentStatus
        let playerChecks = presentPlayers.compactMap { readinessCheck(for: $0) }
        let customChecks = customAnnouncerChecks(for: team)
        let optionalChecks = optionalUpgradeChecks(for: team)
        return ReadinessStatus(
            generatedAt: .now,
            checks: [
                ReadinessCheck(id: "route", title: "Audio Route", detail: route == "Unknown" ? "Choose your speaker before live use." : route, state: route == "Unknown" ? .issue : .gameDayCheck),
                ReadinessCheck(id: "volume", title: "Volume", detail: volume < 0.30 ? "Please check your volume - it appears low." : "\(Int(volume * 100))%", state: volume < 0.30 ? .issue : .gameDayCheck),
                ReadinessCheck(id: "network", title: "Apple Music Network", detail: appleMusicCount == 0 ? "No Apple Music cues in today's lineup." : (pathStatus == .satisfied ? "Connection available." : "Connection unavailable. Apple Music cues may fail."), state: appleMusicCount == 0 ? .gameDayCheck : (pathStatus == .satisfied ? .gameDayCheck : .issue)),
                ReadinessCheck(id: "music-auth", title: "Apple Music Access", detail: appleMusicCount == 0 ? "No Apple Music cues assigned." : appleMusicAuthorizationDetail(for: musicAuthStatus), state: readinessStateForMusic(status: musicAuthStatus, appleMusicCount: appleMusicCount)),
                ReadinessCheck(id: "lineup", title: "Present Players", detail: "\(presentPlayers.count) players marked present", state: team == nil || presentPlayers.isEmpty ? .issue : .gameDayCheck),
            ] + playerChecks + customChecks + optionalChecks
        )
    }

    private func readinessCheck(for player: Player) -> ReadinessCheck? {
        guard let cue = player.cue else {
            return ReadinessCheck(id: "player-\(player.id)-needs-audio", title: player.displayName, detail: "Add a song or local audio. Game Day can still use Small Cheer fallback.", state: .needsAudio)
        }

        switch cue.source {
        case .appleMusic:
            break
        case .localAudio(let source):
            if !audioAssetService.assetExists(relativePath: source.relativePath) {
                return ReadinessCheck(id: "player-\(player.id)-audio-issue", title: player.displayName, detail: "The selected local cue file is missing from app storage.", state: .issue)
            }
        case .builtInClip(let source):
            if !audioAssetService.assetExists(relativePath: builtInClipRelativePath(for: source)) {
                return ReadinessCheck(id: "player-\(player.id)-audio-issue", title: player.displayName, detail: "The selected built-in clip asset is missing.", state: .issue)
            }
        }

        if let customAnnouncerRelativePath = player.customAnnouncerRelativePath,
           !audioAssetService.assetExists(relativePath: customAnnouncerRelativePath) {
            return ReadinessCheck(id: "player-\(player.id)-custom-announcer-issue", title: player.displayName, detail: "The Announcement Cue file is missing from app storage.", state: .issue)
        }

        if hasStoredCustomAnnouncer(for: player) {
            return ReadinessCheck(id: "player-\(player.id)-enhanced", title: player.displayName, detail: "Playable audio plus an Announcement Cue.", state: .enhanced)
        }

        return ReadinessCheck(id: "player-\(player.id)-ready", title: player.displayName, detail: "Playable audio is ready for Game Day.", state: .ready)
    }

    private func customAnnouncerChecks(for team: Team?) -> [ReadinessCheck] {
        guard let team else { return [] }
        let presentPlayers = team.presentPlayersInBattingOrder
        guard !presentPlayers.isEmpty else { return [] }
        let readyPlayers = presentPlayers.filter { player in
            guard player.cue != nil else { return false }
            return readinessCheck(for: player)?.state != .issue
        }
        guard !readyPlayers.isEmpty else { return [] }

        return readyPlayers.compactMap { player in
            guard !hasStoredCustomAnnouncer(for: player) else { return nil }
            return ReadinessCheck(
                id: "player-\(player.id)-announcement-upgrade",
                title: player.displayName,
                detail: "Add an Announcement Cue to make this walkup feel more stadium-like.",
                state: .optional
            )
        }
    }

    private func readinessStateForMusic(status: MusicAuthorization.Status, appleMusicCount: Int) -> ReadinessState {
        guard appleMusicCount > 0 else { return .gameDayCheck }
        return status == .authorized ? .gameDayCheck : .issue
    }

    private func optionalUpgradeChecks(for team: Team?) -> [ReadinessCheck] {
        guard let team else { return [] }
        return team.presentPlayersInBattingOrder.compactMap { player in
            if player.photoRelativePath == nil {
                return ReadinessCheck(
                    id: "player-\(player.id)-photo-upgrade",
                    title: player.displayName,
                    detail: "A photo can make the live board easier to recognize, but this player can still be ready without one.",
                    state: .optional
                )
            }
            if let photoRelativePath = player.photoRelativePath,
               !audioAssetService.assetExists(relativePath: photoRelativePath) {
                return ReadinessCheck(
                    id: "player-\(player.id)-photo-upgrade",
                    title: player.displayName,
                    detail: "The saved photo is missing. This only affects presentation, not Game Day audio.",
                    state: .optional
                )
            }
            return nil
        }
    }

    private func hasStoredCustomAnnouncer(for player: Player) -> Bool {
        guard let relativePath = player.customAnnouncerRelativePath else { return false }
        return audioAssetService.assetExists(relativePath: relativePath)
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
        guard manifest.schemaVersion <= AppState.currentSchemaVersion else { throw AppError.unsupportedImportVersion }

        if try isDirectory(packageRootURL) {
            let packageAssetsURL = packageRootURL.appendingPathComponent("Assets", isDirectory: true)
            manifest.team = try importAssets(for: manifest.team, from: packageAssetsURL, audioAssetService: audioAssetService)
        }
        return manifest
    }

    func preview(packageURL: URL) throws -> TeamPackageManifest {
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
        let manifest = try decoder.decode(TeamPackageManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.schemaVersion <= AppState.currentSchemaVersion else { throw AppError.unsupportedImportVersion }
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
        let teamSummaries = state.teams.enumerated().map { index, team in
            SupportBundlePayload.TeamSummary(
                name: "Team \(index + 1)",
                playerCount: team.players.count,
                presentPlayerCount: team.presentPlayersInBattingOrder.count,
                builtInClipCount: team.builtInClips.count
            )
        }
        let selectedTeamIndex = selectedTeam.flatMap { selectedTeam in
            state.teams.firstIndex(where: { $0.id == selectedTeam.id })
        }
        let payload = SupportBundlePayload(
            generatedAt: .now,
            appVersion: state.appVersion,
            schemaVersion: state.schemaVersion,
            selectedTeamIndex: selectedTeamIndex,
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
        guard let sourceURL = try packageAssetURLIfPresent(relativePath: source.relativePath, from: packageAssetsDirectory) else { throw AppError.invalidImport }
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
        guard let sourceURL = try packageAssetURLIfPresent(relativePath: relativePath, from: packageAssetsDirectory) else { return nil }
        let imported = try audioAssetService.storeCopiedAsset(
            from: sourceURL,
            suggestedExtension: sourceURL.pathExtension,
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            hiddenOriginNote: nil
        )
        return imported.relativePath
    }

    private func importPhotoIfPresent(relativePath: String, from packageAssetsDirectory: URL) throws -> String? {
        guard let sourceURL = try packageAssetURLIfPresent(relativePath: relativePath, from: packageAssetsDirectory) else { return nil }
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = try AppPaths.assetURL(relativePath: "\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.lastPathComponent
    }

    private func packageAssetURLIfPresent(relativePath: String, from packageAssetsDirectory: URL) throws -> URL? {
        let fileName = try validatedPackageAssetFileName(relativePath)
        let assetURL = packageAssetsDirectory.appendingPathComponent(fileName, isDirectory: false)
        let packageAssetsPath = packageAssetsDirectory.standardizedFileURL.path
        let assetPath = assetURL.standardizedFileURL.path
        guard assetPath.hasPrefix(packageAssetsPath + "/") else { throw AppError.invalidImport }
        guard FileManager.default.fileExists(atPath: assetURL.path) else { return nil }
        let values = try assetURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw AppError.invalidImport }
        return assetURL
    }

    private func validatedPackageAssetFileName(_ relativePath: String) throws -> String {
        let fileName = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileName.isEmpty,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              !fileName.hasPrefix("."),
              fileName != ".",
              fileName != "..",
              !fileName.contains("/"),
              !fileName.contains("\\") else {
            throw AppError.invalidImport
        }
        return fileName
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
