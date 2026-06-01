import Foundation
@testable import RollCall

enum RollCallTestFixtures {
    static let teamID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let alexID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let jordanID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let caseyID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let localCueID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let localSourceID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    static let now = Date(timeIntervalSince1970: 1_700_000_000)

    static func player(
        id: UUID,
        name: String,
        number: String,
        isPresent: Bool = true,
        cue: Cue? = nil,
        photoRelativePath: String? = nil,
        customAnnouncerRelativePath: String? = nil
    ) -> Player {
        Player(
            id: id,
            displayName: name,
            uniformNumber: number,
            pronunciationOverride: "",
            photoRelativePath: photoRelativePath,
            cue: cue,
            isPresent: isPresent,
            customAnnouncerRelativePath: customAnnouncerRelativePath
        )
    }

    static func localCue(relativePath: String = "alex.m4a") -> Cue {
        Cue(
            id: localCueID,
            label: "Alex Walkup",
            source: .localAudio(
                LocalAudioSource(
                    id: localSourceID,
                    displayName: "Alex Walkup",
                    relativePath: relativePath,
                    duration: 8,
                    importedAt: now,
                    hiddenOriginNote: HiddenOriginNote(importedAt: now, originSummary: "original-file")
                )
            ),
            startTime: 0,
            duration: 8,
            fadeOutDuration: 1,
            pauseAfterAnnouncer: 0.2
        )
    }

    static func appleMusicCue(
        id: UUID = UUID(),
        songID: String,
        title: String,
        artistName: String,
        isCatalogBacked: Bool? = true
    ) -> Cue {
        Cue(
            id: id,
            label: title,
            source: .appleMusic(
                AppleMusicSource(
                    songID: songID,
                    title: title,
                    artistName: artistName,
                    duration: 180,
                    previewURL: nil,
                    isCatalogBacked: isCatalogBacked
                )
            ),
            startTime: 0,
            duration: 8,
            fadeOutDuration: 1,
            pauseAfterAnnouncer: 0.2
        )
    }

    static func team(
        players: [Player]? = nil,
        battingOrder: [UUID]? = nil,
        nextBatterIndex: Int = 0,
        battingOrderIsCustomized: Bool = true
    ) -> Team {
        let roster = players ?? [
            player(id: alexID, name: "Alex Ramirez", number: "12"),
            player(id: jordanID, name: "Jordan Lee", number: "4"),
            player(id: caseyID, name: "Casey Morgan", number: "9"),
        ]
        return Team(
            id: teamID,
            name: "Thunder",
            createdAt: now,
            modifiedAt: now,
            players: roster,
            builtInClips: BuiltInClip.defaults,
            session: TeamSessionState(
                activeSessionDate: nil,
                battingOrder: battingOrder ?? roster.map(\.id),
                nextBatterIndex: nextBatterIndex,
                gameDayAnnouncerMode: .announcerAndSong,
                battingOrderIsCustomized: battingOrderIsCustomized
            ),
            announcerProfile: .default
        )
    }

    static func appState(team: Team? = nil, snapshots: [SnapshotRecord] = []) -> AppState {
        let teams = team.map { [$0] } ?? []
        return AppState(
            schemaVersion: AppState.currentSchemaVersion,
            appVersion: "1.0.1",
            deviceIdentity: DeviceIdentity(label: "Test iPhone"),
            selectedTeamID: team?.id,
            teams: teams,
            snapshots: snapshots,
            experimental: .default,
            settings: .default,
            lastReadiness: nil,
            lastSeenWhatsNewReleaseID: nil,
            recentAppleMusicSelections: [],
            trimDefaults: .default,
            onboarding: teams.isEmpty ? .notStarted : .completed(at: now)
        )
    }
}

final class RollCallTemporaryDirectory {
    let url: URL

    init(name: String = UUID().uuidString) throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RollCallTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.removeItemIfPresent(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func fileURL(_ name: String) -> URL {
        url.appendingPathComponent(name)
    }

    func write(_ contents: String, to name: String) throws -> URL {
        let file = fileURL(name)
        try contents.data(using: .utf8)!.write(to: file)
        return file
    }
}

extension FileManager {
    func removeItemIfPresent(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}
