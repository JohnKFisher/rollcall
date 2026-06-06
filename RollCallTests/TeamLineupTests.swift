import XCTest
@testable import RollCall

final class TeamLineupTests: XCTestCase {
    func testPresentPlayersInBattingOrderSkipsAbsentPlayersAndPreservesOrder() {
        let alex = RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12")
        let jordan = RollCallTestFixtures.player(id: RollCallTestFixtures.jordanID, name: "Jordan Lee", number: "4", isPresent: false)
        let casey = RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Casey Morgan", number: "9")
        let team = RollCallTestFixtures.team(
            players: [alex, jordan, casey],
            battingOrder: [casey.id, jordan.id, alex.id]
        )

        XCTAssertEqual(team.presentPlayersInBattingOrder.map(\.id), [casey.id, alex.id])
    }

    func testNextBatterClampsOutOfRangeIndexToLastPresentPlayer() {
        let alex = RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12")
        let jordan = RollCallTestFixtures.player(id: RollCallTestFixtures.jordanID, name: "Jordan Lee", number: "4", isPresent: false)
        let casey = RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Casey Morgan", number: "9")
        let team = RollCallTestFixtures.team(
            players: [alex, jordan, casey],
            battingOrder: [alex.id, jordan.id, casey.id],
            nextBatterIndex: 99
        )

        XCTAssertEqual(team.nextBatter?.id, casey.id)
    }

    func testOrderedPlayersAppendsPlayersMissingFromSavedBattingOrder() {
        let team = RollCallTestFixtures.team(
            battingOrder: [RollCallTestFixtures.caseyID]
        )

        XCTAssertEqual(
            team.battingOrderPlayers.map(\.id),
            [
                RollCallTestFixtures.caseyID,
                RollCallTestFixtures.alexID,
                RollCallTestFixtures.jordanID,
            ]
        )
    }

    func testGameDayGridPlayersStartsAfterOnDeckAndWrapsThroughLineup() {
        let team = RollCallTestFixtures.team(
            battingOrder: [
                RollCallTestFixtures.alexID,
                RollCallTestFixtures.jordanID,
                RollCallTestFixtures.caseyID,
            ]
        )

        XCTAssertEqual(
            team.gameDayGridPlayers(startingAfter: RollCallTestFixtures.jordanID).map(\.id),
            [
                RollCallTestFixtures.caseyID,
                RollCallTestFixtures.alexID,
                RollCallTestFixtures.jordanID,
            ]
        )
    }

    func testGameDayGridPlayersReturnsPresentOrderWhenStartPlayerMissing() {
        let jordan = RollCallTestFixtures.player(
            id: RollCallTestFixtures.jordanID,
            name: "Jordan Lee",
            number: "4",
            isPresent: false
        )
        let team = RollCallTestFixtures.team(
            players: [
                RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12"),
                jordan,
                RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Casey Morgan", number: "9"),
            ],
            battingOrder: [
                RollCallTestFixtures.alexID,
                RollCallTestFixtures.jordanID,
                RollCallTestFixtures.caseyID,
            ]
        )

        XCTAssertEqual(
            team.gameDayGridPlayers(startingAfter: RollCallTestFixtures.jordanID).map(\.id),
            [
                RollCallTestFixtures.alexID,
                RollCallTestFixtures.caseyID,
            ]
        )
    }

    func testAlphabeticalPlayerIDsSortsByFirstNameThenRemainder() {
        let players = [
            RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Alex Zed", number: "8"),
            RollCallTestFixtures.player(id: RollCallTestFixtures.jordanID, name: "Jordan Lee", number: "4"),
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Baker", number: "12"),
        ]

        XCTAssertEqual(
            alphabeticalPlayerIDs(for: players),
            [
                RollCallTestFixtures.alexID,
                RollCallTestFixtures.caseyID,
                RollCallTestFixtures.jordanID,
            ]
        )
    }
}
