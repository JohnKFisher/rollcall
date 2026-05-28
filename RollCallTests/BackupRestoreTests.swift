import XCTest
@testable import RollCall

final class BackupRestoreTests: XCTestCase {
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
    func testPackageImportCreatesAutomaticBackupBeforeChangingTeams() async throws {
        let originalTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12"),
        ])
        let incomingTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Casey Morgan", number: "9"),
        ])
        let initialState = RollCallTestFixtures.appState(team: originalTeam)
        try writeState(initialState)
        let packageURL = try writePackageDirectory(
            name: "Incoming.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion,
                appVersion: "1.0.1",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: incomingTeam
            )
        )
        let model = AppModel()

        await model.importPackage(from: packageURL)

        XCTAssertNil(model.lastError)
        XCTAssertEqual(model.state.teams.count, 2)
        XCTAssertEqual(model.state.snapshots.first?.reason, "Automatic backup before package import")
        let backupState = try readStateSnapshot(model.state.snapshots[0])
        XCTAssertEqual(backupState.teams.map(\.name), initialState.teams.map(\.name))
    }

    @MainActor
    func testFailedPackageImportLeavesStateUnchangedAndRecordsError() async throws {
        let originalTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12"),
        ])
        let initialState = RollCallTestFixtures.appState(team: originalTeam)
        try writeState(initialState)
        let brokenPackageURL = temp.fileURL("Broken.rollcall")
        try FileManager.default.createDirectory(at: brokenPackageURL, withIntermediateDirectories: true)
        let model = AppModel()

        await model.importPackage(from: brokenPackageURL)

        XCTAssertNotNil(model.lastError)
        XCTAssertEqual(model.state.teams, initialState.teams)
    }

    @MainActor
    func testRestoreBackupCreatesAutomaticPreRestoreBackupAndRestoresRoster() async throws {
        let currentTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.alexID, name: "Alex Ramirez", number: "12"),
        ])
        let restoredTeam = RollCallTestFixtures.team(players: [
            RollCallTestFixtures.player(id: RollCallTestFixtures.caseyID, name: "Casey Morgan", number: "9"),
        ])
        let restoredSnapshot = SnapshotRecord(
            id: UUID(),
            createdAt: RollCallTestFixtures.now,
            reason: "Manual backup",
            relativeManifestPath: "restore.json"
        )
        let currentState = RollCallTestFixtures.appState(team: currentTeam, snapshots: [restoredSnapshot])
        try writeState(currentState)
        try writeSnapshotState(RollCallTestFixtures.appState(team: restoredTeam), fileName: restoredSnapshot.relativeManifestPath)
        let model = AppModel()

        await model.restoreBackup(restoredSnapshot)

        XCTAssertNil(model.lastError)
        XCTAssertEqual(model.state.teams.first?.players.map(\.displayName), ["Casey Morgan"])
        XCTAssertEqual(model.state.snapshots.first?.reason, "Automatic backup before restore")
    }

    private func writePackageDirectory(name: String, manifest: TeamPackageManifest) throws -> URL {
        let packageURL = temp.fileURL(name)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: packageURL.appendingPathComponent("manifest.json"))
        return packageURL
    }

    private func writeState(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)
    }

    private func writeSnapshotState(_ state: AppState, fileName: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let snapshotURL = try AppPaths.snapshotsDirectory().appendingPathComponent(fileName)
        try encoder.encode(state).write(to: snapshotURL, options: .atomic)
    }

    private func readStateSnapshot(_ snapshot: SnapshotRecord) throws -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let url = try AppPaths.snapshotsDirectory().appendingPathComponent(snapshot.relativeManifestPath)
        return try decoder.decode(AppState.self, from: Data(contentsOf: url))
    }
}
