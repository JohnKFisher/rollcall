import AVFAudio
import AVFoundation
import Foundation
import MusicKit
import Network
import UniformTypeIdentifiers

enum AppError: LocalizedError {
    case missingPreview
    case featureDisabled
    case invalidImport
    case invalidSearchTerm
    case musicSearchUnavailable
    case invalidCSV
    case noAudioTrack
    case protectedModeExitRequired
    case microphonePermissionDenied
    case recordingUnavailable
    case invalidAnnouncerText

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
        case .invalidCSV:
            return "That CSV could not be parsed. Use a header row with name and number, or simple two-column rows."
        case .noAudioTrack:
            return "That video does not contain an audio track that Roll Call can import."
        case .protectedModeExitRequired:
            return "Turn off protected mode before leaving Game Day."
        case .microphonePermissionDenied:
            return "Microphone access is required to record a custom announcer intro."
        case .recordingUnavailable:
            return "Custom announcer recording is not available right now."
        case .invalidAnnouncerText:
            return "Enter announcer text before generating or previewing built-in voice audio."
        }
    }
}

struct AudioAssetService: Sendable {
    func assetURL(relativePath: String) throws -> URL {
        try AppPaths.assetsDirectory().appendingPathComponent(relativePath)
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
        try data.write(to: destination, options: .atomic)
        return try localAudioSource(for: destination, displayName: displayName, hiddenOriginNote: nil)
    }

    func removeAsset(relativePath: String?) {
        guard let relativePath else { return }
        guard let url = try? assetURL(relativePath: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func storeCopiedAsset(from sourceURL: URL, suggestedExtension: String?, displayName: String, hiddenOriginNote: HiddenOriginNote?) throws -> LocalAudioSource {
        let ext = suggestedExtension?.isEmpty == false ? suggestedExtension! : sourceURL.pathExtension
        let normalizedExtension = ext.isEmpty ? "m4a" : ext
        let destination = try AppPaths.assetsDirectory().appendingPathComponent("\(UUID().uuidString).\(normalizedExtension)")
        if FileManager.default.fileExists(atPath: destination.path()) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return try localAudioSource(for: destination, displayName: displayName, hiddenOriginNote: hiddenOriginNote)
    }

    func ensureBuiltInAssets() throws {
        for builtIn in BuiltInClip.defaults {
            guard case .builtInClip(let source) = builtIn.cue.source else { continue }
            let url = try AppPaths.assetsDirectory().appendingPathComponent("\(source.id).caf")
            guard !FileManager.default.fileExists(atPath: url.path()) else { continue }
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            let frames = AVAudioFrameCount(44_100 * 4)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
            buffer.frameLength = frames
            let channel = buffer.floatChannelData![0]
            let freq = Float(240 + abs(source.id.hashValue % 160))
            for index in 0..<Int(frames) {
                let t = Float(index) / 44_100
                let env = min(1, t * 4) * max(0.12, 1 - ((t - 3.1) / 0.9))
                channel[index] = (sin(2 * .pi * freq * t) * 0.22 + sin(2 * .pi * freq * 1.6 * t) * 0.12) * env
            }
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
    }

    func assetExists(relativePath: String) -> Bool {
        guard let url = try? assetURL(relativePath: relativePath) else { return false }
        return FileManager.default.fileExists(atPath: url.path())
    }

    private func localAudioSource(for url: URL, displayName: String, hiddenOriginNote: HiddenOriginNote?) throws -> LocalAudioSource {
        let duration = try audioDuration(for: url)
        return LocalAudioSource(
            id: UUID(),
            displayName: displayName,
            relativePath: url.lastPathComponent,
            duration: duration.isFinite ? duration : nil,
            importedAt: .now,
            hiddenOriginNote: hiddenOriginNote
        )
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
    var previewURL: URL?
}

struct MusicCatalogService: Sendable {
    func search(term: String) async throws -> [MusicSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.invalidSearchTerm }

        do {
            let musicKitResults = try await searchWithMusicKit(term: trimmed)
            if !musicKitResults.isEmpty {
                return musicKitResults
            }
        } catch {
            // Fall through to iTunes preview search when MusicKit is unavailable,
            // including developer-token failures on local development builds.
        }

        let previewResults = try await searchWithITunesPreview(term: trimmed)
        guard !previewResults.isEmpty else { throw AppError.musicSearchUnavailable }
        return previewResults
    }

    private func searchWithMusicKit(term: String) async throws -> [MusicSearchResult] {
        let status = switch MusicAuthorization.currentStatus {
        case .notDetermined:
            await MusicAuthorization.request()
        default:
            MusicAuthorization.currentStatus
        }
        guard status == .authorized else { return [] }

        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 20
        let response = try await request.response()
        return response.songs.map {
            MusicSearchResult(songID: $0.id.rawValue, title: $0.title, artistName: $0.artistName, previewURL: $0.previewAssets?.first?.url)
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
                previewURL: previewURL
            )
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

    enum CodingKeys: String, CodingKey {
        case trackID = "trackId"
        case trackName
        case artistName
        case previewURL = "previewUrl"
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
final class CuePlaybackEngine: NSObject, ObservableObject {
    @Published private(set) var activeCueID: UUID?

    private let audioAssetService: AudioAssetService
    private let debounceWindow: TimeInterval = 0.45
    private var audioPlayer: AVAudioPlayer?
    private var announcerPlayer: AVAudioPlayer?
    private var remotePlayer: AVPlayer?
    private var stopTask: Task<Void, Never>?
    private var prewarmedCueID: UUID?
    private var prewarmedLocalPlayer: AVAudioPlayer?
    private var prewarmedRemoteURL: URL?
    private var previewPlayer: AVAudioPlayer?
    private var lastStartDate: Date?
    private var lastStartedCueID: UUID?

    init(audioAssetService: AudioAssetService) {
        self.audioAssetService = audioAssetService
    }

    func play(cue: Cue, announcerRelativePath: String? = nil) async throws {
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
        try await playCueSequence(cue, announcerRelativePath: announcerRelativePath)
    }

    func prewarm(cue: Cue) async throws {
        switch cue.source {
        case .appleMusic(let source):
            prewarmedCueID = cue.id
            prewarmedRemoteURL = source.previewURL
            prewarmedLocalPlayer = nil
        case .localAudio(let source):
            let url = try audioAssetService.assetURL(relativePath: source.relativePath)
            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = cue.startTime
            player.prepareToPlay()
            prewarmedCueID = cue.id
            prewarmedLocalPlayer = player
            prewarmedRemoteURL = nil
        case .builtInClip(let source):
            let url = try audioAssetService.assetURL(relativePath: "\(source.id).caf")
            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = cue.startTime
            player.prepareToPlay()
            prewarmedCueID = cue.id
            prewarmedLocalPlayer = player
            prewarmedRemoteURL = nil
        }
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
        previewPlayer?.stop()
        previewPlayer = nil
        activeCueID = nil
    }

    private func playCueSequence(_ cue: Cue, announcerRelativePath: String?) async throws {
        guard let relativePath = announcerRelativePath else {
            try startPrimaryCue(cue)
            return
        }

        try? await prewarm(cue: cue)

        let announcerURL = try audioAssetService.assetURL(relativePath: relativePath)
        guard FileManager.default.fileExists(atPath: announcerURL.path()) else {
            try startPrimaryCue(cue)
            return
        }

        let player = try AVAudioPlayer(contentsOf: announcerURL)
        announcerPlayer = player
        player.prepareToPlay()
        player.play()

        stopTask = Task { [weak self] in
            let delay = player.duration + cue.pauseAfterAnnouncer
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            do {
                try self.startPrimaryCue(cue)
            } catch {
                self.stop()
            }
        }
    }

    private func startPrimaryCue(_ cue: Cue) throws {
        stopTask?.cancel()
        stopTask = nil
        announcerPlayer?.stop()
        announcerPlayer = nil

        let duration = cue.source.maximumPlaybackDuration.map { min(cue.duration, $0) } ?? cue.duration

        switch cue.source {
        case .appleMusic(let source):
            guard let previewURL = prewarmedCueID == cue.id ? prewarmedRemoteURL ?? source.previewURL : source.previewURL else {
                throw AppError.missingPreview
            }
            let player = AVPlayer(url: previewURL)
            remotePlayer = player
            player.seek(to: CMTime(seconds: cue.startTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
                player?.play()
            }
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                await self?.fadeRemote(duration: cue.fadeOutDuration)
            }
        case .localAudio(let source):
            let url = try audioAssetService.assetURL(relativePath: source.relativePath)
            try playLocal(url: url, start: cue.startTime, duration: duration, fadeOut: cue.fadeOutDuration, reusePrewarm: prewarmedCueID == cue.id)
        case .builtInClip(let source):
            let url = try audioAssetService.assetURL(relativePath: "\(source.id).caf")
            try playLocal(url: url, start: cue.startTime, duration: duration, fadeOut: cue.fadeOutDuration, reusePrewarm: prewarmedCueID == cue.id)
        }
    }

    private func playLocal(url: URL, start: TimeInterval, duration: TimeInterval, fadeOut: TimeInterval, reusePrewarm: Bool) throws {
        let player = if reusePrewarm, let prewarmedLocalPlayer {
            prewarmedLocalPlayer
        } else {
            try AVAudioPlayer(contentsOf: url)
        }
        audioPlayer = player
        player.currentTime = start
        player.play()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            await self?.fadeLocal(duration: fadeOut)
        }
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
        let voiceFallbackChecks = announcerVoiceChecks(for: team)
        return ReadinessStatus(
            generatedAt: .now,
            checks: [
                ReadinessCheck(id: "route", title: "Audio Route", detail: route, state: route == "Unknown" ? .warning : .ready),
                ReadinessCheck(id: "volume", title: "Volume", detail: "\(Int(volume * 100))%", state: volume < 0.25 ? .warning : .ready),
                ReadinessCheck(id: "network", title: "Apple Music Network", detail: appleMusicCount == 0 ? "No Apple Music cues assigned." : (pathStatus == .satisfied ? "Connection available." : "Connection unavailable. Apple Music cues may fail."), state: appleMusicCount == 0 ? .unknown : (pathStatus == .satisfied ? .ready : .warning)),
                ReadinessCheck(id: "music-auth", title: "Apple Music Access", detail: appleMusicCount == 0 ? "No Apple Music cues assigned." : appleMusicAuthorizationDetail(for: musicAuthStatus), state: readinessStateForMusic(status: musicAuthStatus, appleMusicCount: appleMusicCount)),
                ReadinessCheck(id: "lineup", title: "Present Players", detail: "\(team?.presentPlayersInBattingOrder.count ?? 0) players marked present", state: team == nil ? .warning : ((team?.presentPlayersInBattingOrder.isEmpty ?? true) ? .warning : .ready)),
            ] + customChecks + voiceFallbackChecks + playerChecks
        )
    }

    private func readinessCheck(for player: Player, team: Team?) -> ReadinessCheck? {
        guard player.isPresent else { return nil }
        guard let cue = player.cue else {
            return ReadinessCheck(id: "player-\(player.id)", title: player.displayName, detail: "Present player has no cue assigned.", state: .warning)
        }

        switch cue.source {
        case .appleMusic(let source):
            if source.previewURL == nil {
                return ReadinessCheck(id: "player-\(player.id)", title: player.displayName, detail: "Apple Music cue is missing preview media.", state: .warning)
            }
        case .localAudio(let source):
            if !audioAssetService.assetExists(relativePath: source.relativePath) {
                return ReadinessCheck(id: "player-\(player.id)", title: player.displayName, detail: "Local cue file is missing from app storage.", state: .failed)
            }
        case .builtInClip(let source):
            if !audioAssetService.assetExists(relativePath: "\(source.id).caf") {
                return ReadinessCheck(id: "player-\(player.id)", title: player.displayName, detail: "Built-in clip asset is missing.", state: .failed)
            }
        }

        if team?.session.gameDayAnnouncerMode == .announcer {
            if let customAnnouncerRelativePath = player.customAnnouncerRelativePath {
                if !audioAssetService.assetExists(relativePath: customAnnouncerRelativePath) {
                    return ReadinessCheck(id: "player-\(player.id)-custom-announcer", title: player.displayName, detail: "Custom announcer intro file is missing from app storage.", state: .failed)
                }
            } else {
                guard let generatedAssetRelativePath = player.generatedBuiltInAnnouncerRelativePath else {
                    return ReadinessCheck(id: "player-\(player.id)-announcer", title: player.displayName, detail: "Built-in announcer intro has not been generated yet.", state: .warning)
                }
                if !audioAssetService.assetExists(relativePath: generatedAssetRelativePath) {
                    return ReadinessCheck(id: "player-\(player.id)-announcer", title: player.displayName, detail: "Built-in announcer intro asset is missing.", state: .failed)
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
        let presentPlayers = team.presentPlayersInBattingOrder
        guard !presentPlayers.isEmpty else { return [] }

        let playersWithCustom = presentPlayers.filter { $0.customAnnouncerRelativePath != nil }
        if playersWithCustom.isEmpty {
            return [
                ReadinessCheck(
                    id: "custom-announcers-none",
                    title: "Custom Announcers",
                    detail: "No present players have a custom announcer intro. Built-in Voice will be used instead when announcer mode is on.",
                    state: .warning
                )
            ]
        }

        return presentPlayers.compactMap { player in
            guard player.customAnnouncerRelativePath == nil else { return nil }
            return ReadinessCheck(
                id: "player-\(player.id)-custom-coverage",
                title: player.displayName,
                detail: "This present player does not have a custom announcer intro.",
                state: .warning
            )
        }
    }

    private func announcerVoiceChecks(for team: Team?) -> [ReadinessCheck] {
        guard let team else { return [] }
        guard let requested = team.announcerProfile.requestedVoiceIdentifier,
              let resolved = team.announcerProfile.resolvedVoiceIdentifier,
              requested != resolved else {
            return []
        }

        return [
            ReadinessCheck(
                id: "announcer-voice-fallback",
                title: "Built-in Voice Fallback",
                detail: "The requested built-in voice is unavailable on this device. Roll Call regenerated announcers with an available fallback voice.",
                state: .warning
            )
        ]
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
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(safePackageName(for: team.name)).rollcall", isDirectory: true)
        if FileManager.default.fileExists(atPath: exportURL.path()) {
            try FileManager.default.removeItem(at: exportURL)
        }
        try FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)

        let manifest = TeamPackageManifest(schemaVersion: state.schemaVersion, appVersion: state.appVersion, exportedAt: .now, deviceLabel: state.deviceIdentity.label, team: sanitized(team))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: exportURL.appendingPathComponent("manifest.json"), options: .atomic)

        let packageAssetsURL = exportURL.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: packageAssetsURL, withIntermediateDirectories: true)
        try copyAssets(for: manifest.team, into: packageAssetsURL)

        return exportURL
    }

    func `import`(packageURL: URL, audioAssetService: AudioAssetService) throws -> TeamPackageManifest {
        let manifestURL = try manifestURL(for: packageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var manifest = try decoder.decode(TeamPackageManifest.self, from: Data(contentsOf: manifestURL))

        if try isDirectory(packageURL) {
            let packageAssetsURL = packageURL.appendingPathComponent("Assets", isDirectory: true)
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

    private func manifestURL(for packageURL: URL) throws -> URL {
        if try isDirectory(packageURL) {
            let manifestURL = packageURL.appendingPathComponent("manifest.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path()) else { throw AppError.invalidImport }
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
            try copyAssetIfPresent(relativePath: player.generatedBuiltInAnnouncerRelativePath, into: assetsDirectory)
        }
    }

    private func copyAssetIfPresent(relativePath: String?, into packageAssetsDirectory: URL) throws {
        guard let relativePath else { return }
        let sourceURL = try AppPaths.assetsDirectory().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path()) else { return }
        let destinationURL = packageAssetsDirectory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: destinationURL.path()) {
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
            player.generatedBuiltInAnnouncerRelativePath = try importGeneratedAudioIfPresent(relativePath: player.generatedBuiltInAnnouncerRelativePath, from: packageAssetsDirectory, audioAssetService: audioAssetService)
            return player
        }
        return importedTeam
    }

    private func importLocalAudio(_ source: LocalAudioSource, from packageAssetsDirectory: URL, audioAssetService: AudioAssetService) throws -> LocalAudioSource {
        let sourceURL = packageAssetsDirectory.appendingPathComponent(source.relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path()) else { return source }
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
        guard FileManager.default.fileExists(atPath: sourceURL.path()) else { return nil }
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
        guard FileManager.default.fileExists(atPath: sourceURL.path()) else { return nil }
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = try AppPaths.assetsDirectory().appendingPathComponent("\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: destinationURL.path()) {
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
