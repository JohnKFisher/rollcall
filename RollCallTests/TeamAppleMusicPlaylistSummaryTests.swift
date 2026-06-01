import XCTest
@testable import RollCall

final class TeamAppleMusicPlaylistSummaryTests: XCTestCase {
    func testSummaryIncludesAllTeamPlayersNotJustPresentLineup() {
        let alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(songID: "song.alex", title: "Thunder", artistName: "The Bats")
        )
        let jordan = RollCallTestFixtures.player(
            id: RollCallTestFixtures.jordanID,
            name: "Jordan Lee",
            number: "4",
            isPresent: false,
            cue: RollCallTestFixtures.appleMusicCue(songID: "song.jordan", title: "Lightning", artistName: "The Gloves")
        )
        let team = RollCallTestFixtures.team(players: [alex, jordan], battingOrder: [alex.id])

        let summary = TeamAppleMusicPlaylistSummary(team: team)

        XCTAssertEqual(summary.playlistName, "Roll Call - Thunder")
        XCTAssertEqual(summary.songIDs, ["song.alex", "song.jordan"])
        XCTAssertTrue(summary.skippedCues.isEmpty)
    }

    func testSummaryDeduplicatesSongsAndTracksDuplicatePlayers() {
        let sharedCue = RollCallTestFixtures.appleMusicCue(
            songID: "song.shared",
            title: "Same Song",
            artistName: "Same Artist"
        )
        let alex = RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12", cue: sharedCue)
        let jordan = RollCallTestFixtures.player(id: RollCallTestFixtures.jordanID, name: "Jordan Lee", number: "4", cue: sharedCue)
        let team = RollCallTestFixtures.team(players: [alex, jordan])

        let summary = TeamAppleMusicPlaylistSummary(team: team)

        XCTAssertEqual(summary.includedSongs.map(\.playerName), ["Alex Ramirez"])
        XCTAssertEqual(summary.duplicateSongs.map(\.playerName), ["Jordan Lee"])
        XCTAssertTrue(summary.skippedCues.isEmpty)
    }

    func testSummaryExplainsSkippedCueReasons() {
        let alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue()
        )
        let jordan = RollCallTestFixtures.player(
            id: RollCallTestFixtures.jordanID,
            name: "Jordan Lee",
            number: "4",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "preview.only",
                title: "Preview Song",
                artistName: "Preview Artist",
                isCatalogBacked: false
            )
        )
        let casey = RollCallTestFixtures.player(
            id: RollCallTestFixtures.caseyID,
            name: "Casey Morgan",
            number: "9",
            cue: nil
        )
        let team = RollCallTestFixtures.team(players: [alex, jordan, casey])

        let summary = TeamAppleMusicPlaylistSummary(team: team)

        XCTAssertFalse(summary.canUpdatePlaylist)
        XCTAssertEqual(summary.skippedCues.map(\.reason), [.localAudio, .previewOnlyAppleMusic, .missingCue])
        XCTAssertEqual(summary.skippedCues.map(\.playerName), ["Alex Ramirez", "Jordan Lee", "Casey Morgan"])
    }
}
