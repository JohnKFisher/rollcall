import XCTest
@testable import RollCall

final class ReadinessServiceTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    @MainActor
    func testSnapshotMarksMissingPlayerAudioAsNeedsAudioWithoutBlockingGameDayFallback() {
        let team = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12", cue: nil),
        ])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)

        XCTAssertEqual(
            snapshot.checks.first { $0.id == "player-\(RollCallTestFixtures.alexID)-needs-audio" }?.state,
            .needsAudio
        )
    }

    @MainActor
    func testSnapshotMarksMissingLocalAudioAssetAsIssue() {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "missing.m4a")
        )
        let team = RollCallTestFixtures.team(players: [player])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)

        XCTAssertEqual(
            snapshot.checks.first { $0.id == "player-\(RollCallTestFixtures.alexID)-audio-issue" }?.state,
            .issue
        )
    }

    @MainActor
    func testSnapshotMarksPlayerWithLocalAudioAndAnnouncementAsEnhanced() throws {
        let cueURL = try AppPaths.assetURL(relativePath: "alex.m4a")
        try Data("fake-audio".utf8).write(to: cueURL)
        let announcerURL = try AppPaths.assetURL(relativePath: "alex-announcer.caf")
        try Data("fake-announcer".utf8).write(to: announcerURL)
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "alex.m4a"),
            customAnnouncerRelativePath: "alex-announcer.caf"
        )
        let team = RollCallTestFixtures.team(players: [player])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)

        XCTAssertEqual(
            snapshot.checks.first { $0.id == "player-\(RollCallTestFixtures.alexID)-enhanced" }?.state,
            .enhanced
        )
    }

    @MainActor
    func testSnapshotMarksEmptyLineupAsIssue() {
        let team = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12", isPresent: false),
        ])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)

        XCTAssertEqual(snapshot.checks.first { $0.id == "lineup" }?.state, .issue)
    }

    @MainActor
    func testSnapshotExplainsPreservedAppleMusicAssignmentThatNeedsAccess() {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.needs.access",
                title: "Needs Access",
                artistName: "Test Artist"
            )
        )
        guard case .privateClip(var clip)? = player.songAssignment else {
            return XCTFail("Expected private song clip.")
        }
        clip.readinessInputs.playback = .needsAppleMusic
        clip.readinessInputs.sourceAvailableOnDevice = false
        player.songAssignment = .privateClip(clip)
        let team = RollCallTestFixtures.team(players: [player])

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)
        let check = snapshot.checks.first { $0.id == "player-\(player.id)-audio-issue" }

        XCTAssertEqual(check?.state, .issue)
        XCTAssertTrue(check?.detail.contains("song choice is preserved") == true)
    }

    @MainActor
    func testSnapshotTreatsIncludedGeneratedSharedClipAsPortableReady() throws {
        let generatedPath = "GeneratedClips/shared-ready.m4a"
        try Data("generated".utf8).write(to: AppPaths.assetURL(relativePath: generatedPath))
        var clip = SongClip(
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.shared.ready",
                title: "Shared Ready",
                artistName: "Test Artist"
            )
        )
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: generatedPath,
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.songAssignment = .sharedTeamClip(clip.id)
        var team = RollCallTestFixtures.team(players: [player])
        team.teamClips = [clip]

        let snapshot = ReadinessService(audioAssetService: AudioAssetService()).snapshot(for: team)
        let check = snapshot.checks.first { $0.id == "player-\(player.id)-ready" }

        XCTAssertEqual(check?.state, .ready)
        XCTAssertTrue(check?.detail.contains("portable Roll Call clip") == true)
    }
}
