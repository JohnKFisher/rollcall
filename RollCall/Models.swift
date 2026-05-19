import Foundation

private enum CueDefaults {
    static let fadeOutDuration: TimeInterval = 2.0
}

enum AppMetadata {
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    static let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    static let customIntroStorageMarker = "flat-custom-intro-v2"
}

enum CueSource: Codable, Equatable {
    case appleMusic(AppleMusicSource)
    case localAudio(LocalAudioSource)
    case builtInClip(BuiltInClipSource)

    enum CodingKeys: String, CodingKey {
        case type, appleMusic, localAudio, builtInClip
    }

    enum Kind: String, Codable {
        case appleMusic, localAudio, builtInClip
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .appleMusic:
            self = .appleMusic(try container.decode(AppleMusicSource.self, forKey: .appleMusic))
        case .localAudio:
            self = .localAudio(try container.decode(LocalAudioSource.self, forKey: .localAudio))
        case .builtInClip:
            self = .builtInClip(try container.decode(BuiltInClipSource.self, forKey: .builtInClip))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .appleMusic(let value):
            try container.encode(Kind.appleMusic, forKey: .type)
            try container.encode(value, forKey: .appleMusic)
        case .localAudio(let value):
            try container.encode(Kind.localAudio, forKey: .type)
            try container.encode(value, forKey: .localAudio)
        case .builtInClip(let value):
            try container.encode(Kind.builtInClip, forKey: .type)
            try container.encode(value, forKey: .builtInClip)
        }
    }
}

struct AppleMusicSource: Codable, Equatable, Identifiable {
    var id: String { songID }
    var songID: String
    var title: String
    var artistName: String
    var duration: TimeInterval?
    var previewURL: URL?
    var isCatalogBacked: Bool? = nil
}

struct RecentAppleMusicSelection: Codable, Equatable, Identifiable {
    var id: String { songID }
    var songID: String
    var title: String
    var artistName: String
    var duration: TimeInterval?
    var previewURL: URL?
    var isCatalogBacked: Bool? = nil
    var selectedAt: Date
}

struct HiddenOriginNote: Codable, Equatable {
    var importedAt: Date
    var originSummary: String
}

struct LocalAudioSource: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var relativePath: String
    var duration: TimeInterval?
    var importedAt: Date
    var hiddenOriginNote: HiddenOriginNote?
}

struct BuiltInClipSource: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
}

func normalizedPlayerNameParts(_ name: String) -> (first: String, remainder: String) {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let splitIndex = trimmedName.firstIndex(where: \.isWhitespace) else {
        return (trimmedName, "")
    }

    let firstName = String(trimmedName[..<splitIndex])
    let remainder = trimmedName[splitIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
    return (firstName, remainder)
}

func alphabeticalPlayerIDs(for players: [Player]) -> [UUID] {
    players.sorted { lhs, rhs in
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
    .map(\.id)
}

enum GameDayAnnouncerMode: String, Codable, CaseIterable, Identifiable {
    case announcerOnly
    case announcerAndSong
    case songOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .announcerOnly:
            return "Announcer Only"
        case .announcerAndSong:
            return "Announcer+Song"
        case .songOnly:
            return "Song Only"
        }
    }

    var usesAnnouncer: Bool {
        switch self {
        case .announcerOnly, .announcerAndSong:
            return true
        case .songOnly:
            return false
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "announcerOnly":
            self = .announcerOnly
        case "announcerAndSong":
            self = .announcerAndSong
        case "songOnly":
            self = .songOnly
        case "announcer":
            self = .announcerAndSong
        case "noAnnouncer":
            self = .songOnly
        default:
            self = .songOnly
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum AnnouncerTemplate: String, Codable, CaseIterable, Identifiable {
    case nameOnly
    case numberAndName
    case nowBatting

    var id: String { rawValue }
}

struct TeamAnnouncerProfile: Codable, Equatable {
    var phraseTemplate: String
    var requestedVoiceIdentifier: String?
    var resolvedVoiceIdentifier: String?
    var voiceLanguageCode: String?
    var rate: Float
    var pitchMultiplier: Float
    var volume: Float

    static let `default` = TeamAnnouncerProfile(
        phraseTemplate: "Now batting, number <number>, <name>",
        requestedVoiceIdentifier: nil,
        resolvedVoiceIdentifier: nil,
        voiceLanguageCode: "en-US",
        rate: 0.46,
        pitchMultiplier: 1.0,
        volume: 1.0
    )
}

struct AnnouncerConfig: Codable, Equatable {
    var isEnabled: Bool
    var template: AnnouncerTemplate
    var customPrefix: String
    var generatedAssetRelativePath: String?
}

struct Cue: Codable, Equatable, Identifiable {
    var id: UUID
    var label: String
    var source: CueSource
    var startTime: TimeInterval
    var duration: TimeInterval
    var fadeOutDuration: TimeInterval
    var pauseAfterAnnouncer: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case source
        case startTime
        case duration
        case fadeOutDuration
        case pauseAfterAnnouncer
        case announcer
    }

    init(
        id: UUID,
        label: String,
        source: CueSource,
        startTime: TimeInterval,
        duration: TimeInterval,
        fadeOutDuration: TimeInterval,
        pauseAfterAnnouncer: TimeInterval
    ) {
        self.id = id
        self.label = label
        self.source = source
        self.startTime = startTime
        self.duration = duration
        self.fadeOutDuration = fadeOutDuration
        self.pauseAfterAnnouncer = pauseAfterAnnouncer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        source = try container.decode(CueSource.self, forKey: .source)
        startTime = try container.decodeIfPresent(TimeInterval.self, forKey: .startTime) ?? 0
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 12
        fadeOutDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .fadeOutDuration) ?? CueDefaults.fadeOutDuration
        pauseAfterAnnouncer = try container.decodeIfPresent(TimeInterval.self, forKey: .pauseAfterAnnouncer) ?? 0.2
        _ = try container.decodeIfPresent(AnnouncerConfig.self, forKey: .announcer)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(source, forKey: .source)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(fadeOutDuration, forKey: .fadeOutDuration)
        try container.encode(pauseAfterAnnouncer, forKey: .pauseAfterAnnouncer)
    }
}

struct Player: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var uniformNumber: String
    var pronunciationOverride: String
    var photoRelativePath: String?
    var cue: Cue?
    var isPresent: Bool
    var customAnnouncerRelativePath: String?
    var generatedBuiltInAnnouncerRelativePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case uniformNumber
        case pronunciationOverride
        case photoRelativePath
        case cue
        case isPresent
        case customAnnouncerRelativePath
        case generatedBuiltInAnnouncerRelativePath
    }

    init(
        id: UUID,
        displayName: String,
        uniformNumber: String,
        pronunciationOverride: String,
        photoRelativePath: String?,
        cue: Cue?,
        isPresent: Bool,
        customAnnouncerRelativePath: String? = nil,
        generatedBuiltInAnnouncerRelativePath: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.uniformNumber = uniformNumber
        self.pronunciationOverride = pronunciationOverride
        self.photoRelativePath = photoRelativePath
        self.cue = cue
        self.isPresent = isPresent
        self.customAnnouncerRelativePath = customAnnouncerRelativePath
        self.generatedBuiltInAnnouncerRelativePath = generatedBuiltInAnnouncerRelativePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        uniformNumber = try container.decodeIfPresent(String.self, forKey: .uniformNumber) ?? ""
        pronunciationOverride = try container.decodeIfPresent(String.self, forKey: .pronunciationOverride) ?? ""
        photoRelativePath = try container.decodeIfPresent(String.self, forKey: .photoRelativePath)
        cue = try container.decodeIfPresent(Cue.self, forKey: .cue)
        isPresent = try container.decodeIfPresent(Bool.self, forKey: .isPresent) ?? true
        customAnnouncerRelativePath = try container.decodeIfPresent(String.self, forKey: .customAnnouncerRelativePath)
        generatedBuiltInAnnouncerRelativePath = try container.decodeIfPresent(String.self, forKey: .generatedBuiltInAnnouncerRelativePath)

        if generatedBuiltInAnnouncerRelativePath == nil,
           let legacyPayload = try? LegacyPlayerDecoder.LegacyPlayerPayload(from: decoder),
           let legacyGenerated = legacyPayload.cue?.announcer?.generatedAssetRelativePath {
            generatedBuiltInAnnouncerRelativePath = legacyGenerated
        }
    }
}

struct BuiltInClip: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var cue: Cue
}

struct TeamSessionState: Codable, Equatable {
    var activeSessionDate: Date?
    var battingOrder: [UUID]
    var nextBatterIndex: Int
    var gameDayAnnouncerMode: GameDayAnnouncerMode
    var battingOrderIsCustomized: Bool

    init(
        activeSessionDate: Date?,
        battingOrder: [UUID],
        nextBatterIndex: Int,
        gameDayAnnouncerMode: GameDayAnnouncerMode,
        battingOrderIsCustomized: Bool
    ) {
        self.activeSessionDate = activeSessionDate
        self.battingOrder = battingOrder
        self.nextBatterIndex = nextBatterIndex
        self.gameDayAnnouncerMode = gameDayAnnouncerMode
        self.battingOrderIsCustomized = battingOrderIsCustomized
    }

    enum CodingKeys: String, CodingKey {
        case activeSessionDate
        case battingOrder
        case nextBatterIndex
        case gameDayAnnouncerMode
        case battingOrderIsCustomized
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeSessionDate = try container.decodeIfPresent(Date.self, forKey: .activeSessionDate)
        battingOrder = try container.decodeIfPresent([UUID].self, forKey: .battingOrder) ?? []
        nextBatterIndex = try container.decodeIfPresent(Int.self, forKey: .nextBatterIndex) ?? 0
        gameDayAnnouncerMode = try container.decodeIfPresent(GameDayAnnouncerMode.self, forKey: .gameDayAnnouncerMode) ?? .songOnly
        battingOrderIsCustomized = try container.decodeIfPresent(Bool.self, forKey: .battingOrderIsCustomized) ?? false
    }
}

struct AppSettings: Codable, Equatable {
    var hapticsEnabled: Bool
    var fadeOutVolumeAutomationEnabled: Bool

    static let `default` = AppSettings(
        hapticsEnabled: true,
        fadeOutVolumeAutomationEnabled: true
    )

    enum CodingKeys: String, CodingKey {
        case hapticsEnabled
        case fadeOutVolumeAutomationEnabled
    }

    init(
        hapticsEnabled: Bool,
        fadeOutVolumeAutomationEnabled: Bool
    ) {
        self.hapticsEnabled = hapticsEnabled
        self.fadeOutVolumeAutomationEnabled = fadeOutVolumeAutomationEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        fadeOutVolumeAutomationEnabled = try container.decodeIfPresent(Bool.self, forKey: .fadeOutVolumeAutomationEnabled) ?? true
    }
}

struct Team: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var players: [Player]
    var builtInClips: [BuiltInClip]
    var session: TeamSessionState
    var announcerProfile: TeamAnnouncerProfile

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case modifiedAt
        case players
        case builtInClips
        case session
        case announcerProfile
    }

    init(
        id: UUID,
        name: String,
        createdAt: Date,
        modifiedAt: Date,
        players: [Player],
        builtInClips: [BuiltInClip],
        session: TeamSessionState,
        announcerProfile: TeamAnnouncerProfile
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.players = players
        self.builtInClips = builtInClips
        self.session = session
        self.announcerProfile = announcerProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
        players = try container.decodeIfPresent([Player].self, forKey: .players) ?? []
        builtInClips = try container.decodeIfPresent([BuiltInClip].self, forKey: .builtInClips) ?? BuiltInClip.defaults
        session = try container.decodeIfPresent(TeamSessionState.self, forKey: .session) ?? TeamSessionState(activeSessionDate: nil, battingOrder: alphabeticalPlayerIDs(for: players), nextBatterIndex: 0, gameDayAnnouncerMode: .songOnly, battingOrderIsCustomized: false)
        let legacyPlayers = (try? container.decodeIfPresent([LegacyPlayerDecoder.LegacyPlayerPayload].self, forKey: .players)) ?? []

        if let decodedProfile = try container.decodeIfPresent(TeamAnnouncerProfile.self, forKey: .announcerProfile) {
            announcerProfile = decodedProfile
        } else {
            announcerProfile = LegacyPlayerDecoder.teamAnnouncerProfile(from: legacyPlayers) ?? .default
        }

        if try container.decodeIfPresent(TeamAnnouncerProfile.self, forKey: .announcerProfile) == nil,
           LegacyPlayerDecoder.legacyAnnouncerEnabled(in: legacyPlayers) {
            session.gameDayAnnouncerMode = .announcerAndSong
        }

        let alphabeticalIDs = alphabeticalPlayerIDs(for: players)
        if !session.battingOrderIsCustomized, !session.battingOrder.isEmpty, session.battingOrder != alphabeticalIDs {
            session.battingOrderIsCustomized = true
        }

        let builtInSourceIDs = Set(
            builtInClips.compactMap { clip in
                if case .builtInClip(let source) = clip.cue.source {
                    return source.id
                }
                return nil
            }
        )
        if builtInSourceIDs == ["charge-up", "crowd-lift"] {
            builtInClips = BuiltInClip.defaults
        }
    }
}

enum ReadinessState: String, Codable {
    case ready
    case warning
    case failed
    case unknown
}

struct ReadinessCheck: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var state: ReadinessState
}

struct ReadinessStatus: Codable, Equatable {
    var generatedAt: Date
    var checks: [ReadinessCheck]
}

struct SnapshotRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var createdAt: Date
    var reason: String
    var relativeManifestPath: String
}

struct ExperimentalSettings: Codable, Equatable {
    var showExperimentalFeatures: Bool
    var unlockPremiumForTesting: Bool
    var appleMusicLocalCopyEnabled: Bool
    var appleMusicTeamPlaylistSyncEnabled: Bool
    var acknowledgedAt: Date?
    var appleMusicTeamPlaylistAcknowledgedAt: Date?

    static let `default` = ExperimentalSettings(
        showExperimentalFeatures: false,
        unlockPremiumForTesting: false,
        appleMusicLocalCopyEnabled: false,
        appleMusicTeamPlaylistSyncEnabled: false,
        acknowledgedAt: nil,
        appleMusicTeamPlaylistAcknowledgedAt: nil
    )

    enum CodingKeys: String, CodingKey {
        case showExperimentalFeatures
        case unlockPremiumForTesting
        case appleMusicLocalCopyEnabled
        case appleMusicTeamPlaylistSyncEnabled
        case acknowledgedAt
        case appleMusicTeamPlaylistAcknowledgedAt
    }

    init(
        showExperimentalFeatures: Bool,
        unlockPremiumForTesting: Bool,
        appleMusicLocalCopyEnabled: Bool,
        appleMusicTeamPlaylistSyncEnabled: Bool,
        acknowledgedAt: Date?,
        appleMusicTeamPlaylistAcknowledgedAt: Date?
    ) {
        self.showExperimentalFeatures = showExperimentalFeatures
        self.unlockPremiumForTesting = unlockPremiumForTesting
        self.appleMusicLocalCopyEnabled = appleMusicLocalCopyEnabled
        self.appleMusicTeamPlaylistSyncEnabled = appleMusicTeamPlaylistSyncEnabled
        self.acknowledgedAt = acknowledgedAt
        self.appleMusicTeamPlaylistAcknowledgedAt = appleMusicTeamPlaylistAcknowledgedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showExperimentalFeatures = try container.decodeIfPresent(Bool.self, forKey: .showExperimentalFeatures) ?? false
        unlockPremiumForTesting = try container.decodeIfPresent(Bool.self, forKey: .unlockPremiumForTesting) ?? false
        appleMusicLocalCopyEnabled = try container.decodeIfPresent(Bool.self, forKey: .appleMusicLocalCopyEnabled) ?? false
        appleMusicTeamPlaylistSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .appleMusicTeamPlaylistSyncEnabled) ?? false
        acknowledgedAt = try container.decodeIfPresent(Date.self, forKey: .acknowledgedAt)
        appleMusicTeamPlaylistAcknowledgedAt = try container.decodeIfPresent(Date.self, forKey: .appleMusicTeamPlaylistAcknowledgedAt)
    }
}

struct TrimDefaults: Codable, Equatable {
    var preferredLength: TimeInterval

    static let `default` = TrimDefaults(preferredLength: 8)
}

struct DeviceIdentity: Codable, Equatable {
    var label: String
}

struct AppState: Codable, Equatable {
    var schemaVersion: Int
    var appVersion: String
    var deviceIdentity: DeviceIdentity
    var selectedTeamID: UUID?
    var teams: [Team]
    var snapshots: [SnapshotRecord]
    var experimental: ExperimentalSettings
    var settings: AppSettings
    var lastReadiness: ReadinessStatus?
    var recentAppleMusicSelections: [RecentAppleMusicSelection]
    var trimDefaults: TrimDefaults

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appVersion
        case deviceIdentity
        case selectedTeamID
        case teams
        case snapshots
        case experimental
        case settings
        case lastReadiness
        case recentAppleMusicSelections
        case trimDefaults
    }

    init(
        schemaVersion: Int,
        appVersion: String,
        deviceIdentity: DeviceIdentity,
        selectedTeamID: UUID?,
        teams: [Team],
        snapshots: [SnapshotRecord],
        experimental: ExperimentalSettings,
        settings: AppSettings,
        lastReadiness: ReadinessStatus?,
        recentAppleMusicSelections: [RecentAppleMusicSelection],
        trimDefaults: TrimDefaults
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.deviceIdentity = deviceIdentity
        self.selectedTeamID = selectedTeamID
        self.teams = teams
        self.snapshots = snapshots
        self.experimental = experimental
        self.settings = settings
        self.lastReadiness = lastReadiness
        self.recentAppleMusicSelections = recentAppleMusicSelections
        self.trimDefaults = trimDefaults
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? AppMetadata.appVersion
        deviceIdentity = try container.decodeIfPresent(DeviceIdentity.self, forKey: .deviceIdentity) ?? DeviceIdentity(label: "This iPhone")
        selectedTeamID = try container.decodeIfPresent(UUID.self, forKey: .selectedTeamID)
        teams = try container.decodeIfPresent([Team].self, forKey: .teams) ?? []
        snapshots = try container.decodeIfPresent([SnapshotRecord].self, forKey: .snapshots) ?? []
        experimental = try container.decodeIfPresent(ExperimentalSettings.self, forKey: .experimental) ?? .default
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? .default
        lastReadiness = try container.decodeIfPresent(ReadinessStatus.self, forKey: .lastReadiness)
        recentAppleMusicSelections = try container.decodeIfPresent([RecentAppleMusicSelection].self, forKey: .recentAppleMusicSelections) ?? []
        trimDefaults = try container.decodeIfPresent(TrimDefaults.self, forKey: .trimDefaults) ?? .default
    }

    static let empty = AppState(
        schemaVersion: 5,
        appVersion: AppMetadata.appVersion,
        deviceIdentity: DeviceIdentity(label: "This iPhone"),
        selectedTeamID: nil,
        teams: [],
        snapshots: [],
        experimental: .default,
        settings: .default,
        lastReadiness: nil,
        recentAppleMusicSelections: [],
        trimDefaults: .default
    )
}

struct TeamPackageManifest: Codable {
    var schemaVersion: Int
    var appVersion: String
    var exportedAt: Date
    var deviceLabel: String
    var team: Team
}

enum AppPaths {
    static func baseDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = base.appendingPathComponent("RollCall", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func stateURL() throws -> URL {
        try baseDirectory().appendingPathComponent("state.json")
    }

    static func assetsDirectory() throws -> URL {
        let url = try baseDirectory().appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func assetURL(relativePath: String) throws -> URL {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/") else { throw AppError.invalidImport }

        return try trimmed
            .split(separator: "/")
            .reduce(assetsDirectory()) { partialURL, component in
                let part = String(component)
                guard part != ".", part != ".." else { throw AppError.invalidImport }
                return partialURL.appendingPathComponent(part)
            }
    }

    static func snapshotsDirectory() throws -> URL {
        let url = try baseDirectory().appendingPathComponent("Snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

extension Cue {
    static func localDefault(source: LocalAudioSource) -> Cue {
        Cue(
            id: UUID(),
            label: source.displayName,
            source: .localAudio(source),
            startTime: 0,
            duration: min(12, source.duration ?? 12),
            fadeOutDuration: CueDefaults.fadeOutDuration,
            pauseAfterAnnouncer: 0.2
        )
    }

    static func appleDefault(source: AppleMusicSource) -> Cue {
        Cue(
            id: UUID(),
            label: source.title,
            source: .appleMusic(source),
            startTime: 0,
            duration: 12,
            fadeOutDuration: CueDefaults.fadeOutDuration,
            pauseAfterAnnouncer: 0.2
        )
    }
}

extension BuiltInClip {
    var sourceID: String? {
        guard case .builtInClip(let source) = cue.source else { return nil }
        return source.id
    }

    static func firstMatchingSourceID(_ sourceID: String, in clips: [BuiltInClip]) -> BuiltInClip? {
        clips.first { $0.sourceID == sourceID }
    }

    static let defaults: [BuiltInClip] = [
        BuiltInClip(id: UUID(), title: "Small Cheer", cue: Cue(id: UUID(), label: "Small Cheer", source: .builtInClip(BuiltInClipSource(id: "small-cheer", displayName: "Small Cheer")), startTime: 0, duration: 5.5, fadeOutDuration: 0.35, pauseAfterAnnouncer: 0.2)),
        BuiltInClip(id: UUID(), title: "Victory Roar", cue: Cue(id: UUID(), label: "Victory Roar", source: .builtInClip(BuiltInClipSource(id: "victory-roar", displayName: "Victory Roar")), startTime: 0, duration: 6.0, fadeOutDuration: 0.35, pauseAfterAnnouncer: 0.2)),
        BuiltInClip(id: UUID(), title: "Stadium Burst", cue: Cue(id: UUID(), label: "Stadium Burst", source: .builtInClip(BuiltInClipSource(id: "stadium-burst", displayName: "Stadium Burst")), startTime: 0, duration: 5.0, fadeOutDuration: 0.35, pauseAfterAnnouncer: 0.2)),
        BuiltInClip(id: UUID(), title: "Rhythmic Clap", cue: Cue(id: UUID(), label: "Rhythmic Clap", source: .builtInClip(BuiltInClipSource(id: "rhythmic-clap", displayName: "Rhythmic Clap")), startTime: 0, duration: 6.0, fadeOutDuration: 0.35, pauseAfterAnnouncer: 0.2)),
        BuiltInClip(id: UUID(), title: "Whistle Pop", cue: Cue(id: UUID(), label: "Whistle Pop", source: .builtInClip(BuiltInClipSource(id: "whistle-pop", displayName: "Whistle Pop")), startTime: 0, duration: 4.0, fadeOutDuration: 0.3, pauseAfterAnnouncer: 0.2)),
        BuiltInClip(id: UUID(), title: "Crowd Laugh", cue: Cue(id: UUID(), label: "Crowd Laugh", source: .builtInClip(BuiltInClipSource(id: "crowd-laugh", displayName: "Crowd Laugh")), startTime: 0, duration: 4.5, fadeOutDuration: 0.35, pauseAfterAnnouncer: 0.2)),
    ]
}

extension Team {
    func orderedPlayers(by ids: [UUID]) -> [Player] {
        let lookup = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        let ordered = ids.compactMap { lookup[$0] }
        let unordered = players.filter { player in
            !ids.contains(player.id)
        }
        return ordered + unordered
    }

    var battingOrderPlayers: [Player] {
        orderedPlayers(by: session.battingOrder)
    }

    var presentPlayersInBattingOrder: [Player] {
        battingOrderPlayers.filter(\.isPresent)
    }

    var nextBatter: Player? {
        let present = presentPlayersInBattingOrder
        guard !present.isEmpty else { return nil }
        let normalizedIndex = min(max(session.nextBatterIndex, 0), present.count - 1)
        return present[normalizedIndex]
    }

    static func sample() -> Team {
        let players = [
            Player(id: UUID(), displayName: "Alex Ramirez", uniformNumber: "12", pronunciationOverride: "", photoRelativePath: nil, cue: nil, isPresent: true),
            Player(id: UUID(), displayName: "Jordan Lee", uniformNumber: "4", pronunciationOverride: "", photoRelativePath: nil, cue: nil, isPresent: true),
        ]
        return Team(
            id: UUID(),
            name: "Home Team",
            createdAt: .now,
            modifiedAt: .now,
            players: players,
            builtInClips: BuiltInClip.defaults,
            session: TeamSessionState(activeSessionDate: nil, battingOrder: alphabeticalPlayerIDs(for: players), nextBatterIndex: 0, gameDayAnnouncerMode: .songOnly, battingOrderIsCustomized: false),
            announcerProfile: .default
        )
    }
}

private enum LegacyPlayerDecoder {
    struct LegacyPlayerPayload: Decodable {
        struct LegacyCuePayload: Decodable {
            var announcer: AnnouncerConfig?
        }

        var cue: LegacyCuePayload?
    }

    static func legacyAnnouncerEnabled(in players: [LegacyPlayerPayload]) -> Bool {
        players.contains(where: { $0.cue?.announcer?.isEnabled == true })
    }

    static func teamAnnouncerProfile(from players: [LegacyPlayerPayload]) -> TeamAnnouncerProfile? {
        guard let announcer = players.compactMap({ $0.cue?.announcer }).first else { return nil }
        return TeamAnnouncerProfile(
            phraseTemplate: legacyPhraseTemplate(from: announcer),
            requestedVoiceIdentifier: nil,
            resolvedVoiceIdentifier: nil,
            voiceLanguageCode: "en-US",
            rate: TeamAnnouncerProfile.default.rate,
            pitchMultiplier: TeamAnnouncerProfile.default.pitchMultiplier,
            volume: TeamAnnouncerProfile.default.volume
        )
    }

    private static func legacyPhraseTemplate(from announcer: AnnouncerConfig) -> String {
        switch announcer.template {
        case .nameOnly:
            return "<name>"
        case .numberAndName:
            return announcer.customPrefix.isEmpty ? "Number <number>, <name>" : "\(announcer.customPrefix), number <number>, <name>"
        case .nowBatting:
            let prefix = announcer.customPrefix.isEmpty ? "Now batting" : announcer.customPrefix
            return "\(prefix), number <number>, <name>"
        }
    }
}
