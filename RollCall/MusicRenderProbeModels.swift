import Foundation

enum MusicRenderProbeScenarioSourceFamily {
    case library
    case catalog
    case appLocal
}

enum MusicRenderProbeScenario: String, CaseIterable, Identifiable, Codable {
    case readableLibrarySong
    case purchasedLibrarySong
    case importedLibrarySong
    case appleMusicLibrarySong
    case downloadedAppleMusicSong
    case appleMusicNotInLibrary
    case appleMusicCatalogOnly
    case appLocalImportedSong

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readableLibrarySong:
            return "Readable Library Song"
        case .purchasedLibrarySong:
            return "Purchased Library Song"
        case .importedLibrarySong:
            return "Imported Library Song"
        case .appleMusicLibrarySong:
            return "Apple Music In Library"
        case .downloadedAppleMusicSong:
            return "Downloaded Apple Music"
        case .appleMusicNotInLibrary:
            return "Apple Music Not In Library"
        case .appleMusicCatalogOnly:
            return "Catalog-Only Apple Music"
        case .appLocalImportedSong:
            return "App-Owned Local Import"
        }
    }

    var detail: String {
        switch self {
        case .readableLibrarySong:
            return "Pick a normal device-library song that you expect to expose a readable local asset."
        case .purchasedLibrarySong:
            return "Pick a purchased song from the device Music Library."
        case .importedLibrarySong:
            return "Pick a user-imported device-library song rather than an Apple Music item."
        case .appleMusicLibrarySong:
            return "Pick an Apple Music song that is already saved in the device Music Library."
        case .downloadedAppleMusicSong:
            return "Pick an Apple Music song that is downloaded for offline playback."
        case .appleMusicNotInLibrary:
            return "Search Apple Music and pick a song that is playable for this account but not saved in the library."
        case .appleMusicCatalogOnly:
            return "Search Apple Music and pick a pure catalog case that depends on Apple Music rather than a local library item."
        case .appLocalImportedSong:
            return "Pick an audio file Roll Call already imported into its own app storage as a local control case."
        }
    }

    var sourceFamily: MusicRenderProbeScenarioSourceFamily {
        switch self {
        case .readableLibrarySong,
             .purchasedLibrarySong,
             .importedLibrarySong,
             .appleMusicLibrarySong,
             .downloadedAppleMusicSong:
            return .library
        case .appleMusicNotInLibrary, .appleMusicCatalogOnly:
            return .catalog
        case .appLocalImportedSong:
            return .appLocal
        }
    }
}

struct MusicRenderProbeLibraryCandidate: Identifiable, Equatable {
    var id: UInt64 { persistentID }
    let persistentID: UInt64
    let title: String
    let artistName: String
    let duration: TimeInterval?
    let hasLocalAssetURL: Bool
    let isCloudItem: Bool
    let playbackStoreID: String?
    let albumTitle: String?
}

struct MusicRenderProbeCatalogCandidate: Identifiable, Equatable {
    var id: String { songID }
    let songID: String
    let title: String
    let artistName: String
    let duration: TimeInterval?
    let previewURL: URL?
    let isCatalogBacked: Bool
}

struct MusicRenderProbeLocalCandidate: Identifiable, Equatable {
    let id: UUID
    let source: LocalAudioSource
    let teamName: String
    let playerName: String
}

enum MusicRenderProbeSelection: Equatable {
    case library(MusicRenderProbeLibraryCandidate)
    case catalog(MusicRenderProbeCatalogCandidate)
    case local(MusicRenderProbeLocalCandidate)

    var displayTitle: String {
        switch self {
        case .library(let candidate):
            return candidate.title
        case .catalog(let candidate):
            return candidate.title
        case .local(let candidate):
            return candidate.source.displayName
        }
    }

    var displaySubtitle: String {
        switch self {
        case .library(let candidate):
            return candidate.artistName
        case .catalog(let candidate):
            return candidate.artistName
        case .local(let candidate):
            return "\(candidate.teamName) • \(candidate.playerName)"
        }
    }
}

enum MusicRenderProbeFailureCategory: String, Codable, CaseIterable {
    case permissionNeeded
    case networkNeeded
    case sourceUnavailable
    case protectedUnreadable
    case renderFailedTransient
    case renderFailedPermanent
    case policyDisabled

    var title: String {
        switch self {
        case .permissionNeeded:
            return "Permission Needed"
        case .networkNeeded:
            return "Network Needed"
        case .sourceUnavailable:
            return "Source Unavailable"
        case .protectedUnreadable:
            return "Protected / Unreadable"
        case .renderFailedTransient:
            return "Render Failed (Transient)"
        case .renderFailedPermanent:
            return "Render Failed (Permanent)"
        case .policyDisabled:
            return "Policy Disabled"
        }
    }

    static func classify(_ error: Error) -> MusicRenderProbeFailureCategory {
        if let appError = error as? AppError {
            switch appError {
            case .musicAuthorizationRequired:
                return .permissionNeeded
            case .musicSubscriptionRequired, .appleMusicSongUnavailable:
                return .sourceUnavailable
            case .missingPreview:
                return .sourceUnavailable
            case .invalidImport, .noAudioTrack:
                return .renderFailedPermanent
            default:
                return .renderFailedTransient
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .timedOut, .dataNotAllowed:
                return .networkNeeded
            default:
                return .renderFailedTransient
            }
        }

        return .renderFailedTransient
    }
}

enum MusicRenderProbeAttemptPath: String, Codable {
    case fullSource
    case previewProxy
}

enum MusicRenderProbeAttemptStatus: String, Codable {
    case succeeded
    case failed
    case notAttempted
}

struct MusicRenderProbeAttempt: Equatable, Codable {
    let path: MusicRenderProbeAttemptPath
    let status: MusicRenderProbeAttemptStatus
    let failureCategory: MusicRenderProbeFailureCategory?
    let detail: String?

    var succeeded: Bool { status == .succeeded }

    static func success(path: MusicRenderProbeAttemptPath, detail: String) -> MusicRenderProbeAttempt {
        MusicRenderProbeAttempt(path: path, status: .succeeded, failureCategory: nil, detail: detail)
    }

    static func failure(
        path: MusicRenderProbeAttemptPath,
        category: MusicRenderProbeFailureCategory,
        detail: String
    ) -> MusicRenderProbeAttempt {
        MusicRenderProbeAttempt(path: path, status: .failed, failureCategory: category, detail: detail)
    }

    static func notAttempted(path: MusicRenderProbeAttemptPath, detail: String) -> MusicRenderProbeAttempt {
        MusicRenderProbeAttempt(path: path, status: .notAttempted, failureCategory: nil, detail: detail)
    }
}

enum MusicRenderProbeVerdict: String, Codable {
    case fullSourceRenderable
    case previewOnlyRenderable
    case failed
}

struct MusicRenderProbeResult: Equatable {
    let scenario: MusicRenderProbeScenario
    let startedAt: Date
    let finishedAt: Date
    let fullSourceAttempt: MusicRenderProbeAttempt
    let previewProxyAttempt: MusicRenderProbeAttempt
    let verdict: MusicRenderProbeVerdict

    var headline: String {
        switch verdict {
        case .fullSourceRenderable:
            return "Full-source local rendering succeeded."
        case .previewOnlyRenderable:
            return "Only preview/proxy rendering succeeded."
        case .failed:
            return "No renderable path succeeded."
        }
    }

    static func make(
        scenario: MusicRenderProbeScenario,
        startedAt: Date,
        fullSourceAttempt: MusicRenderProbeAttempt,
        previewProxyAttempt: MusicRenderProbeAttempt,
        finishedAt: Date = .now
    ) -> MusicRenderProbeResult {
        let verdict: MusicRenderProbeVerdict
        if fullSourceAttempt.succeeded {
            verdict = .fullSourceRenderable
        } else if previewProxyAttempt.succeeded {
            verdict = .previewOnlyRenderable
        } else {
            verdict = .failed
        }

        return MusicRenderProbeResult(
            scenario: scenario,
            startedAt: startedAt,
            finishedAt: finishedAt,
            fullSourceAttempt: fullSourceAttempt,
            previewProxyAttempt: previewProxyAttempt,
            verdict: verdict
        )
    }
}

struct MusicRenderProbeSample: Identifiable, Equatable {
    let scenario: MusicRenderProbeScenario
    var selection: MusicRenderProbeSelection?
    var result: MusicRenderProbeResult?

    var id: String { scenario.rawValue }

    init(scenario: MusicRenderProbeScenario, selection: MusicRenderProbeSelection? = nil, result: MusicRenderProbeResult? = nil) {
        self.scenario = scenario
        self.selection = selection
        self.result = result
    }
}

struct MusicRenderProbeRedactedScenarioSummary: Codable, Equatable, Identifiable {
    let scenario: MusicRenderProbeScenario
    let sampleAssigned: Bool
    let verdict: MusicRenderProbeVerdict?
    let fullSourceStatus: MusicRenderProbeAttemptStatus?
    let fullSourceFailureCategory: MusicRenderProbeFailureCategory?
    let previewProxyStatus: MusicRenderProbeAttemptStatus?
    let previewProxyFailureCategory: MusicRenderProbeFailureCategory?

    var id: String { scenario.rawValue }
}

struct MusicRenderProbeRedactedSummary: Codable, Equatable {
    let generatedAt: Date
    let authorizationStatus: String
    let playbackCapability: String
    let sampleCount: Int
    let completedProbeCount: Int
    let scenarioSummaries: [MusicRenderProbeRedactedScenarioSummary]

    static func make(
        samples: [MusicRenderProbeSample],
        authorizationStatus: String,
        playbackCapability: String,
        generatedAt: Date = .now
    ) -> MusicRenderProbeRedactedSummary {
        let summaries = samples.map { sample in
            MusicRenderProbeRedactedScenarioSummary(
                scenario: sample.scenario,
                sampleAssigned: sample.selection != nil,
                verdict: sample.result?.verdict,
                fullSourceStatus: sample.result?.fullSourceAttempt.status,
                fullSourceFailureCategory: sample.result?.fullSourceAttempt.failureCategory,
                previewProxyStatus: sample.result?.previewProxyAttempt.status,
                previewProxyFailureCategory: sample.result?.previewProxyAttempt.failureCategory
            )
        }

        return MusicRenderProbeRedactedSummary(
            generatedAt: generatedAt,
            authorizationStatus: authorizationStatus,
            playbackCapability: playbackCapability,
            sampleCount: samples.filter { $0.selection != nil }.count,
            completedProbeCount: samples.filter { $0.result != nil }.count,
            scenarioSummaries: summaries
        )
    }
}
