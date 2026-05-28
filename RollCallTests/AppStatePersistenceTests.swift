import XCTest
@testable import RollCall

final class AppStatePersistenceTests: XCTestCase {
    func testAppStateRoundTripsTeamRosterAndSelection() throws {
        let team = RollCallTestFixtures.team()
        let state = RollCallTestFixtures.appState(team: team)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(AppState.self, from: try encoder.encode(state))

        XCTAssertEqual(decoded.selectedTeamID, team.id)
        XCTAssertEqual(decoded.teams.first?.players.map(\.displayName), ["Alex Ramirez", "Jordan Lee", "Casey Morgan"])
        XCTAssertEqual(decoded.settings, .default)
    }

    func testPlayerDecodeDefaultsMissingPresenceToPresent() throws {
        let json = """
        {
          "id": "\(RollCallTestFixtures.alexID.uuidString)",
          "displayName": "Alex Ramirez",
          "uniformNumber": "12",
          "pronunciationOverride": ""
        }
        """

        let player = try JSONDecoder().decode(Player.self, from: Data(json.utf8))

        XCTAssertTrue(player.isPresent)
        XCTAssertNil(player.cue)
        XCTAssertNil(player.photoRelativePath)
    }

    func testFutureSavedStateSchemaCanBeDetectedByCallers() throws {
        var state = RollCallTestFixtures.appState(team: RollCallTestFixtures.team())
        state.schemaVersion = AppState.currentSchemaVersion + 1
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let decoded = try decoder.decode(AppState.self, from: try encoder.encode(state))

        XCTAssertGreaterThan(decoded.schemaVersion, AppState.currentSchemaVersion)
    }
}
