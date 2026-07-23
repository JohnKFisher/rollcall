import XCTest
@testable import RollCall

final class RecentlyDeletedTests: XCTestCase {
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
    func testRemovePlayerAddsRecentlyDeletedEntryAndKeepsAssets() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "alex-walkup.m4a"),
            photoRelativePath: "alex.jpg",
            customAnnouncerRelativePath: "alex-announcer.caf"
        )
        let team = RollCallTestFixtures.team(players: [player])
        try writeState(RollCallTestFixtures.appState(team: team))
        try writeAsset("alex-walkup.m4a")
        try writeAsset("alex.jpg")
        try writeAsset("alex-announcer.caf")
        let model = AppModel()

        model.removePlayer(player)

        XCTAssertEqual(model.state.teams.first?.players.count, 0)
        XCTAssertEqual(model.state.recentlyDeleted.count, 1)
        XCTAssertTrue(assetExists("alex-walkup.m4a"))
        XCTAssertTrue(assetExists("alex.jpg"))
        XCTAssertTrue(assetExists("alex-announcer.caf"))
    }

    @MainActor
    func testRestoreDeletedPlayerPreservesOriginalPresence() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            isPresent: false
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        var state = RollCallTestFixtures.appState(team: team)
        let deletedItem = RecentlyDeletedItem(
            id: UUID(),
            deletedAt: .now,
            payload: .player(
                DeletedPlayerRecord(
                    player: player,
                    originalTeamID: team.id,
                    originalTeamName: team.name,
                    previousBattingOrder: [player.id]
                )
            )
        )
        state.teams[0].players = []
        state.teams[0].session.battingOrder = []
        state.recentlyDeleted = [deletedItem]
        try writeState(state)
        let model = AppModel()

        model.restoreRecentlyDeletedItem(deletedItem, allowPartial: true)

        XCTAssertEqual(model.state.recentlyDeleted.count, 0)
        XCTAssertEqual(model.state.selectedTeamID, team.id)
        XCTAssertEqual(model.state.teams.first?.players.first?.displayName, "Alex Ramirez")
        XCTAssertEqual(model.state.teams.first?.players.first?.isPresent, false)
        XCTAssertEqual(model.state.teams.first?.session.battingOrder, [player.id])
    }

    func testRestorePreparationBlocksDeletedPlayerWhenOriginalTeamIsNotActive() throws {
        let player = RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12")
        var state = RollCallTestFixtures.appState()
        let deletedItem = RecentlyDeletedItem(
            id: UUID(),
            deletedAt: .now,
            payload: .player(
                DeletedPlayerRecord(
                    player: player,
                    originalTeamID: RollCallTestFixtures.teamID,
                    originalTeamName: "Thunder",
                    previousBattingOrder: [player.id]
                )
            )
        )
        state.recentlyDeleted = [deletedItem]
        try writeState(state)
        let model = AppModel()

        XCTAssertEqual(model.restorePreparation(for: deletedItem), .blocked("Restore the team first to bring this player back."))
    }

    @MainActor
    func testRestoreDeletedTeamRenamesWhenActiveTeamNameAlreadyExists() throws {
        let activeTeam = RollCallTestFixtures.team()
        let deletedTeam = Team(
            id: UUID(),
            name: activeTeam.name,
            createdAt: RollCallTestFixtures.now,
            modifiedAt: RollCallTestFixtures.now,
            players: [],
            builtInClips: BuiltInClip.defaults,
            session: TeamSessionState(activeSessionDate: nil, battingOrder: [], nextBatterIndex: 0, gameDayAnnouncerMode: .announcerAndSong, battingOrderIsCustomized: false),
            announcerProfile: .default
        )
        var state = RollCallTestFixtures.appState(team: activeTeam)
        let deletedItem = RecentlyDeletedItem(
            id: UUID(),
            deletedAt: .now,
            payload: .team(DeletedTeamRecord(team: deletedTeam))
        )
        state.recentlyDeleted = [deletedItem]
        try writeState(state)
        let model = AppModel()

        model.restoreRecentlyDeletedItem(deletedItem, allowPartial: true)

        XCTAssertEqual(model.state.teams.map(\.name), ["Thunder", "Thunder (Restored)"])
    }

    @MainActor
    func testDeletedCustomClipRestoresToOriginalPositionWithoutChangingPlayerCopy() throws {
        let first = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "first.m4a"))
        var second = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "second.m4a"))
        second.id = UUID()
        second.displayName = "Second"
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.songAssignment = .privateClip(second.playerSongCopy())
        var team = RollCallTestFixtures.team(players: [player])
        team.teamClips = [first, second]
        try writeState(RollCallTestFixtures.appState(team: team))
        try writeAsset("first.m4a")
        try writeAsset("second.m4a")
        let model = AppModel()

        model.deleteCustomClip(first.id)

        XCTAssertEqual(model.selectedTeam?.teamClips.map(\.id), [second.id])
        guard let deletedItem = model.state.recentlyDeleted.first else {
            return XCTFail("Expected a recoverable Custom Clip.")
        }
        model.restoreRecentlyDeletedItem(deletedItem)

        XCTAssertEqual(model.selectedTeam?.teamClips.map(\.id), [first.id, second.id])
        guard case .privateClip(let playerClip)? = model.selectedTeam?.players.first?.songAssignment else {
            return XCTFail("Expected the player copy to remain private.")
        }
        XCTAssertNotEqual(playerClip.id, second.id)
    }

    @MainActor
    func testRefreshRecoveryStatePurgesExpiredItemsAndDeletesUnreferencedAssets() throws {
        let deletedPlayer = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "expired-song.m4a")
        )
        var state = RollCallTestFixtures.appState()
        state.recentlyDeleted = [
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: Calendar.current.date(byAdding: .day, value: -(RecentlyDeletedItem.retentionDays + 1), to: RollCallTestFixtures.now) ?? RollCallTestFixtures.now,
                payload: .player(
                    DeletedPlayerRecord(
                        player: deletedPlayer,
                        originalTeamID: RollCallTestFixtures.teamID,
                        originalTeamName: "Thunder",
                        previousBattingOrder: [deletedPlayer.id]
                    )
                )
            )
        ]
        try writeState(state)
        try writeAsset("expired-song.m4a")
        let model = AppModel()

        model.refreshRecoveryState()

        XCTAssertTrue(model.state.recentlyDeleted.isEmpty)
        XCTAssertFalse(assetExists("expired-song.m4a"))
    }

    private func writeState(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)
    }

    private func writeAsset(_ relativePath: String) throws {
        let url = try AppPaths.assetURL(relativePath: relativePath)
        try Data("test".utf8).write(to: url, options: .atomic)
    }

    private func assetExists(_ relativePath: String) -> Bool {
        guard let url = try? AppPaths.assetURL(relativePath: relativePath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}
