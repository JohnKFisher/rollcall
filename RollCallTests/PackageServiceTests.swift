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

    func testPreviewMigratesLegacyPlayerCuePackage() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue()
        )
        let manifest = TeamPackageManifest(
            schemaVersion: 7,
            appVersion: "1.1.0",
            exportedAt: RollCallTestFixtures.now,
            deviceLabel: "Legacy Device",
            team: RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var manifestObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(manifest)) as? [String: Any]
        )
        var teamObject = try XCTUnwrap(manifestObject["team"] as? [String: Any])
        var players = try XCTUnwrap(teamObject["players"] as? [[String: Any]])
        var legacyPlayer = try XCTUnwrap(players.first)
        legacyPlayer.removeValue(forKey: "songAssignment")
        legacyPlayer["cue"] = try JSONSerialization.jsonObject(
            with: encoder.encode(RollCallTestFixtures.localCue())
        )
        players[0] = legacyPlayer
        teamObject["players"] = players
        teamObject.removeValue(forKey: "teamClips")
        manifestObject["team"] = teamObject

        let packageURL = temp.fileURL("Legacy.rollcall")
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: manifestObject)
            .write(to: packageURL.appendingPathComponent("manifest.json"))

        let preview = try service.preview(packageURL: packageURL)

        XCTAssertEqual(preview.team.players.first?.cue, RollCallTestFixtures.localCue())
        XCTAssertTrue(preview.team.teamClips.isEmpty)
    }

    func testSchemaNineImportPreservesOrdinaryTeamAndProfilePhotoWithoutPlayerCardWarning() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "alex.jpg"
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try writePackageDirectory(
            name: "OrdinarySchemaNine.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion,
                appVersion: "1.2.2",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: team
            )
        )
        let packageAssetsURL = packageURL.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: packageAssetsURL, withIntermediateDirectories: true)
        try Data("profile-photo".utf8).write(to: packageAssetsURL.appendingPathComponent("alex.jpg"))

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        XCTAssertEqual(result.manifest.schemaVersion, 9)
        XCTAssertEqual(result.manifest.team.name, "Thunder")
        XCTAssertEqual(result.manifest.team.session.battingOrder, [player.id])
        XCTAssertEqual(result.manifest.team.players.first?.displayName, "Alex Ramirez")
        XCTAssertNotNil(result.manifest.team.players.first?.photoRelativePath)
        XCTAssertFalse(result.audit.containsUnsupportedPlayerCardInformation)
    }

    func testImportWithPlayerCardDesignMetadataSucceedsAndDoesNotPersistThatField() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try writePackageDirectoryWithPlayerFields(
            name: "PlayerCardDesign.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion,
                appVersion: "1.3.0",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Newer Device",
                team: team
            ),
            fields: ["playerCardDesignID": "Spotlight"]
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        XCTAssertEqual(result.manifest.team.players.first?.displayName, "Alex Ramirez")
        XCTAssertTrue(result.audit.containsUnsupportedPlayerCardInformation)

        let roundTripObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result.manifest)) as? [String: Any]
        )
        let roundTripTeam = try XCTUnwrap(roundTripObject["team"] as? [String: Any])
        let roundTripPlayers = try XCTUnwrap(roundTripTeam["players"] as? [[String: Any]])
        XCTAssertNil(roundTripPlayers.first?["playerCardDesignID"])
    }

    func testImportWithNewerPhotoSourceAndCropFieldsSucceedsAndWarnsOnce() throws {
        let team = RollCallTestFixtures.team(
            players: [
                RollCallTestFixtures.player(
                    id: RollCallTestFixtures.alexID,
                    name: "Alex Ramirez",
                    number: "12"
                ),
                RollCallTestFixtures.player(
                    id: RollCallTestFixtures.jordanID,
                    name: "Jordan Lee",
                    number: "4"
                )
            ],
            battingOrder: [RollCallTestFixtures.alexID, RollCallTestFixtures.jordanID]
        )
        let packageURL = try writePackageDirectoryWithPlayerFields(
            name: "PlayerCardPhotoFields.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion,
                appVersion: "1.3.0",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Newer Device",
                team: team
            ),
            fields: [
                "photoSourceRelativePath": "PlayerPhotos/alex-master.jpg",
                "profilePhotoCrop": ["x": 0.1, "y": 0.2, "scale": 1.0],
                "playerCardPhotoCrop": "malformed-but-non-null"
            ]
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        XCTAssertEqual(result.manifest.team.players.map(\.displayName), ["Alex Ramirez", "Jordan Lee"])
        XCTAssertEqual(result.manifest.team.session.battingOrder, [RollCallTestFixtures.alexID, RollCallTestFixtures.jordanID])
        XCTAssertTrue(result.audit.containsUnsupportedPlayerCardInformation)
        XCTAssertFalse(result.manifest.team.players.contains { $0.photoRelativePath == "PlayerPhotos/alex-master.jpg" })
    }

    func testImportWithNullRecognizedFieldsDoesNotWarn() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        let packageURL = try writePackageDirectoryWithPlayerFields(
            name: "NullPlayerCardFields.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion,
                appVersion: "1.2.2",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
            ),
            fields: [
                "photoSourceRelativePath": NSNull(),
                "profilePhotoCrop": NSNull(),
                "playerCardPhotoCrop": NSNull(),
                "playerCardDesignID": NSNull()
            ]
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        XCTAssertFalse(result.audit.containsUnsupportedPlayerCardInformation)
    }

    func testImportWithUnrelatedUnknownPlayerFieldDoesNotWarn() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        let packageURL = try writePackageDirectoryWithPlayerFields(
            name: "UnrelatedFutureField.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion,
                appVersion: "1.3.0",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Newer Device",
                team: RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
            ),
            fields: ["futureUnrelatedPlayerField": ["value": true]]
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        XCTAssertEqual(result.manifest.team.players.first?.displayName, "Alex Ramirez")
        XCTAssertFalse(result.audit.containsUnsupportedPlayerCardInformation)
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

    func testPreviewRejectsDuplicatePlayerOrLineupIDs() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        var team = RollCallTestFixtures.team(players: [player, player], battingOrder: [player.id, player.id])
        team.session.battingOrderIsCustomized = true
        let packageURL = try writePackageDirectory(
            name: "DuplicateIDs.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: AppState.currentSchemaVersion,
                appVersion: "1.0.1",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: team
            )
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testImportPreservesMissingLocalAudioAsRepairableAssignment() throws {
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

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        guard let clip = result.manifest.team.players.first?.songAssignment?.privateClip else {
            return XCTFail("Expected the missing local assignment to be preserved.")
        }
        XCTAssertEqual(clip.readinessInputs.playback, .needsRepair)
        XCTAssertEqual(clip.portabilityInputs.portability, .metadataOnly)
        XCTAssertEqual(result.audit.items.first?.state, .needsRepair)
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

    func testGeneratedCustomClipRoundTripsAsPortablePackageAsset() throws {
        let generatedPath = "GeneratedClips/team-warmup.m4a"
        try Data("portable-generated-audio".utf8)
            .write(to: AppPaths.assetURL(relativePath: generatedPath))
        var clip = SongClip(
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.team.warmup",
                title: "Team Warmup",
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
        clip.readinessInputs = SongClipReadinessInputs(
            playback: .localClipReady,
            sourceAvailableOnDevice: true,
            downloadedOnDevice: true
        )
        clip.portabilityInputs = SongClipPortabilityInputs(
            portability: .portableLocalClip,
            generatedAssetCanBeExported: true
        )
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        var team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        team.teamClips = [clip]

        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )
        let preview = try service.previewDetails(packageURL: packageURL)
        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        XCTAssertEqual(preview.summary.localClipIncludedCount, 1)
        let importedClip = try XCTUnwrap(result.manifest.team.teamClips.first)
        let importedPath = try XCTUnwrap(importedClip.generatedAsset.relativePath)
        XCTAssertTrue(importedPath.hasPrefix("GeneratedClips/"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try AppPaths.assetURL(relativePath: importedPath).path))
        XCTAssertEqual(result.audit.items.first?.state, .localClipIncluded)
        guard case .localAudio = importedClip.playbackCue.source else {
            return XCTFail("Expected the imported Custom Clip to use its included generated asset.")
        }
    }

    func testAppleMusicAssignmentSurvivesImportAndReportsAccessNeed() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.keep.me",
                title: "Keep Me",
                artistName: "Test Artist"
            )
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )

        guard case .appleMusic(let source)? = result.manifest.team.players.first?
            .songAssignment?.privateClip?.originalSource else {
            return XCTFail("Expected Apple Music metadata to survive import.")
        }
        XCTAssertEqual(source.songID, "catalog.keep.me")
        XCTAssertEqual(result.audit.items.first?.state, .needsAppleMusic)
    }

    func testAppleMusicAssignmentReportsCheckNeededBeforeMusicAuthorization() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.check.me",
                title: "Check Me",
                artistName: "Test Artist"
            )
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .notDetermined,
            appleMusicPlaybackCapability: .unknown
        )

        XCTAssertEqual(result.audit.items.first?.state, .needsAppleMusicCheck)
        XCTAssertEqual(result.audit.summary.needsAppleMusicCount, 1)
    }

    func testAppleMusicAssignmentReportsReadyWhenPlaybackCapabilityIsConfirmed() throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.ready.here",
                title: "Ready Here",
                artistName: "Test Artist"
            )
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .authorized,
            appleMusicPlaybackCapability: .fullSong
        )

        XCTAssertEqual(result.audit.items.first?.state, .sourceReferenceOnly)
        XCTAssertEqual(result.audit.summary.sourceReferenceOnlyCount, 1)
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

    private func writePackageDirectoryWithPlayerFields(
        name: String,
        manifest: TeamPackageManifest,
        fields: [String: Any]
    ) throws -> URL {
        let packageURL = try writePackageDirectory(name: name, manifest: manifest)
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        var manifestObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]
        )
        var teamObject = try XCTUnwrap(manifestObject["team"] as? [String: Any])
        var players = try XCTUnwrap(teamObject["players"] as? [[String: Any]])
        var player = try XCTUnwrap(players.first)
        fields.forEach { key, value in
            player[key] = value
        }
        players[0] = player
        teamObject["players"] = players
        manifestObject["team"] = teamObject
        try JSONSerialization.data(withJSONObject: manifestObject, options: [.sortedKeys])
            .write(to: manifestURL, options: .atomic)
        return packageURL
    }
}
