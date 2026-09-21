import XCTest
@preconcurrency import AVFoundation
@testable import RollCall
import ZIPFoundation

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
        let resourceValues = try packageURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])

        XCTAssertEqual(packageURL.pathExtension, "rollcall")
        XCTAssertEqual(resourceValues.isRegularFile, true)
        XCTAssertGreaterThan(resourceValues.fileSize ?? 0, 0)
        XCTAssertEqual(manifest.team.name, "Thunder")
        XCTAssertEqual(manifest.team.players.count, 1)
        guard case .localAudio(let source)? = manifest.team.players.first?.cue?.source else {
            return XCTFail("Expected exported player to keep a local audio cue")
        }
        XCTAssertNil(source.hiddenOriginNote)
    }

    func testMultiPlayerTeamWithoutOptionalClipsExportsAndRoundTripsRepeatedly() throws {
        let alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        let jordan = RollCallTestFixtures.player(
            id: UUID(),
            name: "Jordan Lee",
            number: "7"
        )
        let team = RollCallTestFixtures.team(
            players: [alex, jordan],
            battingOrder: [alex.id, jordan.id]
        )
        let state = RollCallTestFixtures.appState(team: team)

        for _ in 0..<2 {
            let packageURL = try service.export(team: team, state: state)
            let resourceValues = try packageURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            let preview = try service.preview(packageURL: packageURL)
            let imported = try service.import(
                packageURL: packageURL,
                audioAssetService: AudioAssetService()
            )

            XCTAssertEqual(resourceValues.isRegularFile, true)
            XCTAssertGreaterThan(resourceValues.fileSize ?? 0, 0)
            XCTAssertEqual(preview.team.players.map(\.displayName), ["Alex Ramirez", "Jordan Lee"])
            XCTAssertEqual(imported.team.players.map(\.displayName), ["Alex Ramirez", "Jordan Lee"])
            XCTAssertTrue(imported.team.teamClips.isEmpty)
        }
    }

    @MainActor
    func testPackageExportWorkflowDoesNotTreatStaleURLAsSuccessfulRetry() async throws {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let model = AppModel()
        model.state = RollCallTestFixtures.appState(team: team)

        model.prepareSelectedTeamExport()
        let firstResult = await model.confirmPendingPackageExport()
        let firstURL = try XCTUnwrap(firstResult)

        XCTAssertEqual(model.exportURL, firstURL)
        XCTAssertNotNil(model.pendingPackageExport, "The preview owns dismissal until the ready URL is handed off.")
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))

        model.cancelPendingPackageExport()
        model.state.teams[0].players[0].photoRelativePath = "../unsafe.jpg"
        model.prepareSelectedTeamExport()
        let failedURL = await model.confirmPendingPackageExport()

        XCTAssertNil(failedURL)
        XCTAssertNil(model.exportURL, "A failed retry must not reuse the previous package URL.")
        XCTAssertNotNil(model.pendingPackageExport, "A failed export must keep the preview available.")
        XCTAssertNotNil(model.lastError)
    }

    func testNewPhotoMasterAndFramingsRoundTripWithoutRaisingPackageSchema() throws {
        try Data("profile-photo".utf8).write(to: AppPaths.assetURL(relativePath: "profile.jpg"))
        try Data("clean-master-photo".utf8).write(to: AppPaths.assetURL(relativePath: "master.jpg"))
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "profile.jpg"
        )
        player.photoSourceRelativePath = "master.jpg"
        player.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.5)
        player.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.8, height: 0.9)
        player.playerCardDesign = .impact
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])

        let packageURL = try service.export(team: team, state: RollCallTestFixtures.appState(team: team))
        let preview = try service.preview(packageURL: packageURL)
        let imported = try service.import(packageURL: packageURL, audioAssetService: AudioAssetService())
        let importedPlayer = try XCTUnwrap(imported.team.players.first)

        XCTAssertEqual(preview.schemaVersion, TeamPackageManifest.currentSchemaVersion)
        XCTAssertLessThanOrEqual(preview.schemaVersion, 9, "Roll Call 1.2 must continue accepting the additive package.")
        XCTAssertNotEqual(importedPlayer.photoRelativePath, player.photoRelativePath)
        XCTAssertNotEqual(importedPlayer.photoSourceRelativePath, player.photoSourceRelativePath)
        XCTAssertEqual(importedPlayer.profilePhotoCrop, player.profilePhotoCrop)
        XCTAssertEqual(importedPlayer.playerCardPhotoCrop, player.playerCardPhotoCrop)
        XCTAssertEqual(importedPlayer.playerCardDesign, .impact)
        XCTAssertTrue(AudioAssetService().assetExists(relativePath: importedPlayer.photoRelativePath ?? ""))
        XCTAssertTrue(AudioAssetService().assetExists(relativePath: importedPlayer.photoSourceRelativePath ?? ""))
    }

    func testMissingPhotoMasterImportsProfileOnlyAndClearsMasterRelativeCrops() throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "profile.jpg"
        )
        player.photoSourceRelativePath = "missing-master.jpg"
        player.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.5)
        player.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.8, height: 0.9)
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let packageURL = try writePackageDirectory(
            name: "MissingMaster.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: TeamPackageManifest.currentSchemaVersion,
                appVersion: "1.3.0",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Test Device",
                team: team
            )
        )
        let assetsURL = packageURL.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        try Data("profile-photo".utf8).write(to: assetsURL.appendingPathComponent("profile.jpg"))

        let result = try service.importWithAudit(
            packageURL: packageURL,
            audioAssetService: AudioAssetService(),
            musicAuthorizationStatus: .denied,
            appleMusicPlaybackCapability: .unknown
        )
        let imported = try XCTUnwrap(result.manifest.team.players.first)

        XCTAssertNotNil(imported.photoRelativePath)
        XCTAssertNil(imported.photoSourceRelativePath)
        XCTAssertNil(imported.profilePhotoCrop)
        XCTAssertNil(imported.playerCardPhotoCrop)
        XCTAssertTrue(result.audit.items.contains { $0.state == .photoSourceMissing })
        XCTAssertEqual(result.audit.summary.needsRepairCount, 0)
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

    func testPreviewRejectsFutureSchemaPackages() throws {
        let packageURL = try writePackageDirectory(
            name: "Future.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: TeamPackageManifest.currentSchemaVersion + 1,
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
                schemaVersion: TeamPackageManifest.currentSchemaVersion,
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
                schemaVersion: TeamPackageManifest.currentSchemaVersion,
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
                schemaVersion: TeamPackageManifest.currentSchemaVersion,
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

    func testArchivePreflightRejectsTraversalEntryPath() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "TraversalEntry.rollcall",
            entries: [(path: "../manifest.json", sourceURL: sourceURL, compressionMethod: .none)]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsAbsoluteEntryPath() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "AbsoluteEntry.rollcall",
            entries: [(path: "/manifest.json", sourceURL: sourceURL, compressionMethod: .none)]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsDuplicateEntryPaths() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "DuplicateEntries.rollcall",
            entries: [
                (path: "manifest.json", sourceURL: sourceURL, compressionMethod: .none),
                (path: "manifest.json", sourceURL: sourceURL, compressionMethod: .none)
            ]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsSymlinkEntries() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let symlinkURL = temp.fileURL("link.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: sourceURL)
        let packageURL = try writeArchive(
            name: "SymlinkEntry.rollcall",
            entries: [
                (path: "manifest.json", sourceURL: sourceURL, compressionMethod: .none),
                (path: "Assets/link.txt", sourceURL: symlinkURL, compressionMethod: .none)
            ]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsHighCompressionRatio() throws {
        let sourceURL = temp.fileURL("high-ratio.bin")
        try Data(repeating: 0, count: 2 * 1024 * 1024).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "HighRatio.rollcall",
            entries: [(path: "payload.bin", sourceURL: sourceURL, compressionMethod: .deflate)]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsExcessiveEntryCount() throws {
        let sourceURL = temp.fileURL("entry.txt")
        try Data("entry".utf8).write(to: sourceURL)
        let entries = (0...1_024).map {
            (path: "entry-\($0).txt", sourceURL: sourceURL, compressionMethod: CompressionMethod.none)
        }
        let packageURL = try writeArchive(name: "TooManyEntries.rollcall", entries: entries)

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsOversizedEntry() throws {
        let sourceURL = temp.fileURL("oversized.bin")
        FileManager.default.createFile(atPath: sourceURL.path, contents: nil)
        let file = try FileHandle(forWritingTo: sourceURL)
        try file.truncate(atOffset: 64 * 1024 * 1024 + 1)
        try file.close()
        let packageURL = try writeArchive(
            name: "OversizedEntry.rollcall",
            entries: [(path: "payload.bin", sourceURL: sourceURL, compressionMethod: .none)]
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
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

    private func writeArchive(
        name: String,
        entries: [(path: String, sourceURL: URL, compressionMethod: CompressionMethod)]
    ) throws -> URL {
        let packageURL = temp.fileURL(name)
        let archive = try Archive(url: packageURL, accessMode: .create)
        for entry in entries {
            try archive.addEntry(
                with: entry.path,
                fileURL: entry.sourceURL,
                compressionMethod: entry.compressionMethod
            )
        }
        return packageURL
    }
}

final class VideoAudioImportExportTests: XCTestCase {
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
    func testVideoImportExtractsM4AAndCleansTemporaryExport() async throws {
        let sourceVideoURL = temp.fileURL("video-with-audio.mov")
        try await writeVideoWithAudio(to: sourceVideoURL)
        let temporaryFilesBefore = try anonymousTemporaryM4AFiles()

        let source = try await AudioAssetService().importMedia(from: sourceVideoURL)

        XCTAssertEqual(URL(fileURLWithPath: source.relativePath).pathExtension, "m4a")
        let storedURL = try AppPaths.assetURL(relativePath: source.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storedURL.path))
        let storedAsset = AVURLAsset(url: storedURL)
        let audioTracks = try await storedAsset.loadTracks(withMediaType: .audio)
        let videoTracks = try await storedAsset.loadTracks(withMediaType: .video)
        let duration = CMTimeGetSeconds(try await storedAsset.load(.duration))
        XCTAssertFalse(audioTracks.isEmpty)
        XCTAssertTrue(videoTracks.isEmpty)
        XCTAssertGreaterThan(duration, 0.5)
        XCTAssertLessThan(duration, 1.5)
        XCTAssertEqual(try anonymousTemporaryM4AFiles(), temporaryFilesBefore)
    }

    @MainActor
    private func writeVideoWithAudio(to outputURL: URL) async throws {
        let videoOnlyURL = temp.fileURL("video-only.mov")
        let audioOnlyURL = temp.fileURL("audio-only.caf")
        try await writeSilentVideo(to: videoOnlyURL)
        try writeSilentAudio(to: audioOnlyURL, duration: 1)

        let videoAsset = AVURLAsset(url: videoOnlyURL)
        let audioAsset = AVURLAsset(url: audioOnlyURL)
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        let sourceVideoTrack = try XCTUnwrap(videoTracks.first)
        let sourceAudioTrack = try XCTUnwrap(audioTracks.first)
        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)
        let duration = CMTimeMinimum(videoDuration, audioDuration)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0)

        let composition = AVMutableComposition()
        let compositionVideoTrack = try XCTUnwrap(
            composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        )
        let compositionAudioTrack = try XCTUnwrap(
            composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        )
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
        try compositionAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)

        let exportSession = try XCTUnwrap(
            AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            )
        )
        try? FileManager.default.removeItem(at: outputURL)
        try await exportSession.export(to: outputURL, as: .mov)
    }

    @MainActor
    private func writeSilentVideo(to outputURL: URL) async throws {
        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 32,
                AVVideoHeightKey: 32,
            ]
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 32,
                kCVPixelBufferHeightKey as String: 32,
            ]
        )
        guard writer.canAdd(input) else {
            throw mediaTestError("Could not add the synthetic video input.")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? mediaTestError("Could not start the synthetic video writer.")
        }
        writer.startSession(atSourceTime: .zero)
        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw mediaTestError("The synthetic video writer did not create a pixel-buffer pool.")
        }

        let writerReadinessDeadline = ContinuousClock.now + .seconds(10)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData,
                  ContinuousClock.now < writerReadinessDeadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            guard input.isReadyForMoreMediaData else {
                throw mediaTestError("The synthetic video input stopped accepting frames.")
            }
            var optionalPixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(
                nil,
                pixelBufferPool,
                &optionalPixelBuffer
            )
            guard status == kCVReturnSuccess, let pixelBuffer = optionalPixelBuffer else {
                throw mediaTestError("Could not allocate a synthetic video frame.")
            }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                baseAddress.initializeMemory(
                    as: UInt8.self,
                    repeating: 0,
                    count: CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)
                )
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            guard adaptor.append(
                pixelBuffer,
                withPresentationTime: CMTime(value: Int64(frame), timescale: 30)
            ) else {
                throw writer.error ?? mediaTestError("Could not append a synthetic video frame.")
            }
        }

        writer.endSession(atSourceTime: CMTime(value: 30, timescale: 30))
        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }
        guard writer.status == .completed else {
            throw writer.error ?? mediaTestError("The synthetic video writer did not finish.")
        }
    }

    private func writeSilentAudio(to url: URL, duration: TimeInterval) throws {
        let format = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func anonymousTemporaryM4AFiles() throws -> Set<String> {
        Set(
            try FileManager.default.contentsOfDirectory(
                at: FileManager.default.temporaryDirectory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "m4a" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { UUID(uuidString: $0) != nil }
        )
    }

    private func mediaTestError(_ description: String) -> NSError {
        NSError(
            domain: "VideoAudioImportExportTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}
