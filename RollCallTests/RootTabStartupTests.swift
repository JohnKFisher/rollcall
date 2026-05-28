import XCTest
@testable import RollCall

final class RootTabStartupTests: XCTestCase {
    func testSensibleInitialTabUsesPlayersWhenThereIsNoTeam() {
        XCTAssertEqual(RootTab.sensibleInitialTab(for: nil), .players)
    }

    func testSensibleInitialTabUsesPlayersWhenSelectedTeamHasNoPlayers() {
        let team = RollCallTestFixtures.team(players: [])

        XCTAssertEqual(RootTab.sensibleInitialTab(for: team), .players)
    }

    func testSensibleInitialTabUsesGameDayWhenSelectedTeamHasPlayers() {
        let team = RollCallTestFixtures.team()

        XCTAssertEqual(RootTab.sensibleInitialTab(for: team), .gameDay)
    }
}
