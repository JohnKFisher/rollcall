import XCTest
@testable import RollCall

final class PackageServiceTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!
    private let service = PackageService()

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    func testExportedRollCallPackageCanBePreviewedAndStripsHiddenLocalAudioOrigin() throws {
        let assetURL = try AppPaths.assetURL(relativePath: "alex.m4a")
        try Data("fake-audio".utf8).write(to: assetURL)
        let alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "alex.m4a")
        )
        let team = RollCallTestFixtures.team(players: [alex], battingOrder: [alex.id])
        let state = RollCallTestFixtures.appState(team: team)

        let packageURL = try service.export(team: team, state: state)
        let manifest = try service.preview(packageURL: packageURL)

        XCTAssertEqual(packageURL.pathExtension, "rollcall")
        XCTAssertEqual(manifest.team.name, "Thunder")
        XCTAssertEqual(manifest.team.players.count, 1)
        guard case .localAudio(let source)? = manifest.team.players.first?.cue?.source else {
            return XCTFail("Expected exported player to keep a local audio cue")
        }
        XCTAssertNil(source.hiddenOriginNote)
    }

    func testPreviewRejectsPackageDirectoryWithoutManifest() throws {
        let packageURL = temp.fileURL("Broken.rollcall")
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testPreviewRejectsFutureSchemaPackages() throws {
        let packageURL = try writePackageDirectory(
            name: "Future.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion + 1,
                appVersion: "99.0",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Future Device",
                team: RollCallTestFixtures.team()
            )
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .unsupportedImportVersion)
        }
    }

    func testImportRejectsMissingRequiredLocalAudioAsset() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "missing.m4a")
        )
        let packageURL = try writePackageDirectory(
            name: "MissingAsset.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion,
                appVersion: "1.0.1",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
            )
        )
        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent("Assets", isDirectory: true),
            withIntermediateDirectories: true
        )

        XCTAssertThrowsError(try service.import(packageURL: packageURL, audioAssetService: AudioAssetService())) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testImportRejectsUnsafePackageAssetPath() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "../escape.m4a")
        )
        let packageURL = try writePackageDirectory(
            name: "UnsafeAsset.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion,
                appVersion: "1.0.1",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
            )
        )
        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent("Assets", isDirectory: true),
            withIntermediateDirectories: true
        )

        XCTAssertThrowsError(try service.import(packageURL: packageURL, audioAssetService: AudioAssetService())) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
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
}
