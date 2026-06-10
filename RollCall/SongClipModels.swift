import Foundation

enum SongSource: Codable, Equatable {
    case appleMusic(AppleMusicSource)
    case localAudio(LocalAudioSource)
    case builtInClip(BuiltInClipSource)

    private enum CodingKeys: String, CodingKey {
        case type
        case appleMusic
        case localAudio
        case builtInClip
    }

    private enum Kind: String, Codable {
        case appleMusic
        case localAudio
        case builtInClip
    }

    init(cueSource: CueSource) {
        switch cueSource {
        case .appleMusic(let source):
            self = .appleMusic(source)
        case .localAudio(let source):
            self = .localAudio(source)
        case .builtInClip(let source):
            self = .builtInClip(source)
        }
    }

    var cueSource: CueSource {
        switch self {
        case .appleMusic(let source):
            return .appleMusic(source)
        case .localAudio(let source):
            return .localAudio(source)
        case .builtInClip(let source):
            return .builtInClip(source)
        }
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
        case .appleMusic(let source):
            try container.encode(Kind.appleMusic, forKey: .type)
            try container.encode(source, forKey: .appleMusic)
        case .localAudio(let source):
            try container.encode(Kind.localAudio, forKey: .type)
            try container.encode(source, forKey: .localAudio)
        case .builtInClip(let source):
            try container.encode(Kind.builtInClip, forKey: .type)
            try container.encode(source, forKey: .builtInClip)
        }
    }
}

struct SongClipSelection: Codable, Equatable {
    var startTime: TimeInterval
    var duration: TimeInterval
    var fadeOutDuration: TimeInterval
}

enum GeneratedClipAssetStatus: String, Codable, Equatable {
    case none
    case pending
    case ready
    case failedRetryable
    case failedPermanent
}

struct GeneratedClipAsset: Codable, Equatable {
    var relativePath: String?
    var status: GeneratedClipAssetStatus
    var renderedSelection: SongClipSelection?
    var generationKey: String?
    var generatedAt: Date?
}

enum SongClipPlaybackReadiness: String, Codable, Equatable {
    case localClipReady
    case sourceBackedReady
    case sourceBackedDownloaded
    case needsAppleMusic
    case needsRepair
}

enum SongClipPortability: String, Codable, Equatable {
    case portableLocalClip
    case sourceReferenceOnly
    case metadataOnly
}

struct SongClipReadinessInputs: Codable, Equatable {
    var playback: SongClipPlaybackReadiness
    var sourceAvailableOnDevice: Bool
    var downloadedOnDevice: Bool
}

struct SongClipPortabilityInputs: Codable, Equatable {
    var portability: SongClipPortability
    var generatedAssetCanBeExported: Bool
}

struct SongClipRetryMetadata: Codable, Equatable {
    var attemptCount: Int
    var lastAttemptAt: Date?
    var nextRetryAt: Date?
    var lastFailureCode: String?

    static let none = SongClipRetryMetadata(
        attemptCount: 0,
        lastAttemptAt: nil,
        nextRetryAt: nil,
        lastFailureCode: nil
    )
}

enum AppleMusicHandlingPolicy: String, Codable, Equatable {
    case readableLocalOnly
}

struct SongClipPolicy: Codable, Equatable {
    var localClipGenerationEnabled: Bool
    var appleMusicHandlingPolicy: AppleMusicHandlingPolicy
    var autoDownloadEligibleSongsEnabled: Bool
    var generationPolicyVersion: Int

    static let current = SongClipPolicy(
        localClipGenerationEnabled: true,
        appleMusicHandlingPolicy: .readableLocalOnly,
        autoDownloadEligibleSongsEnabled: true,
        generationPolicyVersion: 1
    )
}

struct SongClip: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String?
    var originalSource: SongSource
    var requestedSelection: SongClipSelection
    var pauseAfterAnnouncer: TimeInterval
    var generatedAsset: GeneratedClipAsset
    var readinessInputs: SongClipReadinessInputs
    var portabilityInputs: SongClipPortabilityInputs
    var retryMetadata: SongClipRetryMetadata
    var policy: SongClipPolicy
    var sourceLineageClipID: UUID?

    init(cue: Cue) {
        id = cue.id
        displayName = cue.label
        originalSource = SongSource(cueSource: cue.source)
        requestedSelection = SongClipSelection(
            startTime: cue.startTime,
            duration: cue.duration,
            fadeOutDuration: cue.fadeOutDuration
        )
        pauseAfterAnnouncer = cue.pauseAfterAnnouncer
        generatedAsset = GeneratedClipAsset(
            relativePath: nil,
            status: .none,
            renderedSelection: nil,
            generationKey: nil,
            generatedAt: nil
        )
        readinessInputs = Self.defaultReadiness(for: cue.source)
        portabilityInputs = Self.defaultPortability(for: cue.source)
        retryMetadata = .none
        policy = .current
        sourceLineageClipID = nil
    }

    var playbackCue: Cue {
        let selection = generatedAsset.renderedSelection ?? requestedSelection
        let source: CueSource

        if generatedAsset.status == .ready, let relativePath = generatedAsset.relativePath {
            source = .localAudio(
                LocalAudioSource(
                    id: id,
                    displayName: displayName ?? "Walk-Up Song",
                    relativePath: relativePath,
                    duration: selection.duration,
                    importedAt: generatedAsset.generatedAt ?? .now,
                    hiddenOriginNote: nil
                )
            )
        } else {
            source = originalSource.cueSource
        }

        return Cue(
            id: id,
            label: displayName ?? "Walk-Up Song",
            source: source,
            startTime: generatedAsset.status == .ready ? 0 : selection.startTime,
            duration: selection.duration,
            fadeOutDuration: generatedAsset.status == .ready ? 0 : selection.fadeOutDuration,
            pauseAfterAnnouncer: pauseAfterAnnouncer
        )
    }

    private static func defaultReadiness(for source: CueSource) -> SongClipReadinessInputs {
        switch source {
        case .localAudio, .builtInClip:
            return SongClipReadinessInputs(
                playback: .sourceBackedReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: true
            )
        case .appleMusic:
            return SongClipReadinessInputs(
                playback: .sourceBackedReady,
                sourceAvailableOnDevice: true,
                downloadedOnDevice: false
            )
        }
    }

    private static func defaultPortability(for source: CueSource) -> SongClipPortabilityInputs {
        switch source {
        case .localAudio, .builtInClip:
            return SongClipPortabilityInputs(
                portability: .portableLocalClip,
                generatedAssetCanBeExported: true
            )
        case .appleMusic:
            return SongClipPortabilityInputs(
                portability: .sourceReferenceOnly,
                generatedAssetCanBeExported: false
            )
        }
    }
}

enum SongAssignment: Codable, Equatable {
    case privateClip(SongClip)
    case sharedTeamClip(UUID)

    private enum CodingKeys: String, CodingKey {
        case type
        case privateClip
        case sharedTeamClipID
    }

    private enum Kind: String, Codable {
        case privateClip
        case sharedTeamClip
    }

    var privateClip: SongClip? {
        guard case .privateClip(let clip) = self else { return nil }
        return clip
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .privateClip:
            self = .privateClip(try container.decode(SongClip.self, forKey: .privateClip))
        case .sharedTeamClip:
            self = .sharedTeamClip(try container.decode(UUID.self, forKey: .sharedTeamClipID))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .privateClip(let clip):
            try container.encode(Kind.privateClip, forKey: .type)
            try container.encode(clip, forKey: .privateClip)
        case .sharedTeamClip(let clipID):
            try container.encode(Kind.sharedTeamClip, forKey: .type)
            try container.encode(clipID, forKey: .sharedTeamClipID)
        }
    }
}
