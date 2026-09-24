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

    func testPackageCustomColorRoundTripsWithoutChangingPresetAccentOrSchema() throws {
        var team = RollCallTestFixtures.team(players: [])
        team.accentPreset = .blue
        team.customColor = TeamCustomColor(
            colorSpace: "sRGB",
            red: 0.123456,
            green: 0.654321,
            blue: 0.777777,
            alpha: 1.0
        )
        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )
        defer { service.cleanupExportedPackage(at: packageURL) }

        let exportedManifest = try manifestObject(in: packageURL)
        let exportedTeam = try XCTUnwrap(exportedManifest["team"] as? [String: Any])
        XCTAssertEqual(exportedManifest["schemaVersion"] as? Int, 9)
        XCTAssertEqual(exportedTeam["accentPreset"] as? String, "blue")
        XCTAssertNotNil(exportedTeam["customColor"] as? [String: Any])

        let preview = try service.preview(packageURL: packageURL)
        let imported = try service.import(
            packageURL: packageURL,
            audioAssetService: AudioAssetService()
        )

        XCTAssertEqual(preview.team.customColor, team.customColor)
        XCTAssertEqual(imported.team.customColor, team.customColor)
        XCTAssertEqual(imported.team.accentPreset, .blue)
        XCTAssertEqual(imported.schemaVersion, 9)
    }

    func testPackageOmitsNilCustomColorInsteadOfEncodingNull() throws {
        var team = RollCallTestFixtures.team(players: [])
        team.accentPreset = .blue
        XCTAssertNil(team.customColor)
        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )
        defer { service.cleanupExportedPackage(at: packageURL) }

        let exportedManifest = try manifestObject(in: packageURL)
        let exportedTeam = try XCTUnwrap(exportedManifest["team"] as? [String: Any])

        XCTAssertFalse(exportedTeam.keys.contains("customColor"))
        XCTAssertEqual(exportedTeam["accentPreset"] as? String, "blue")
    }

    func testSchemaNinePackageWithoutCustomColorAndWithUnknownTeamFieldStillImports() throws {
        var team = RollCallTestFixtures.team(players: [])
        team.accentPreset = .blue
        let packageURL = try writePackageDirectory(
            name: "SchemaNineWithoutCustomColor.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: 9,
                appVersion: "1.2.3",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Older Device",
                team: team
            )
        )
        var manifest = try manifestObject(at: packageURL.appendingPathComponent("manifest.json"))
        var teamObject = try XCTUnwrap(manifest["team"] as? [String: Any])
        teamObject.removeValue(forKey: "customColor")
        teamObject["futureTeamField"] = ["unknown": true]
        manifest["team"] = teamObject
        try JSONSerialization.data(withJSONObject: manifest)
            .write(to: packageURL.appendingPathComponent("manifest.json"))
        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent("Assets", isDirectory: true),
            withIntermediateDirectories: true
        )

        let preview = try service.preview(packageURL: packageURL)
        let imported = try service.import(
            packageURL: packageURL,
            audioAssetService: AudioAssetService()
        )

        XCTAssertNil(preview.team.customColor)
        XCTAssertNil(imported.team.customColor)
        XCTAssertEqual(preview.team.accentPreset, .blue)
        XCTAssertEqual(imported.team.accentPreset, .blue)
        XCTAssertEqual(imported.schemaVersion, 9)
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

    func testLargeLocalWAVRoundTripsThroughCurrentAndShipping12Packages() async throws {
        let sourceWAVURL = temp.fileURL("eight-minute-silent-stereo.wav")
        try writeSilentStereoWAV(to: sourceWAVURL, durationSeconds: 8 * 60)

        let audioSource = try await AudioAssetService().importMedia(from: sourceWAVURL)
        let appSourceURL = try AudioAssetService().assetURL(relativePath: audioSource.relativePath)
        let fileSize = try XCTUnwrap(
            sourceWAVURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        )
        XCTAssertGreaterThan(fileSize, 64 * 1_024 * 1_024)

        var cue = RollCallTestFixtures.localCue(relativePath: audioSource.relativePath)
        cue.source = .localAudio(audioSource)
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: cue
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let state = RollCallTestFixtures.appState(team: team)

        let currentPackageURL = try service.export(team: team, state: state)
        defer { service.cleanupExportedPackage(at: currentPackageURL) }

        let currentArchive = try Archive(url: currentPackageURL, accessMode: .read)
        let currentAssetEntry = try XCTUnwrap(currentArchive["Assets/\(audioSource.relativePath)"])
        XCTAssertGreaterThan(currentAssetEntry.uncompressedSize, 64 * 1_024 * 1_024)
        XCTAssertGreaterThan(currentAssetEntry.compressedSize, 0)

        let currentPreview = try service.preview(packageURL: currentPackageURL)
        let currentImport = try service.import(
            packageURL: currentPackageURL,
            audioAssetService: AudioAssetService()
        )
        try assertImportedAudioMatches(currentPreview.team, sourceURL: appSourceURL, expectedSize: fileSize)
        try assertImportedAudioMatches(currentImport.team, sourceURL: appSourceURL, expectedSize: fileSize)

        // Shipping 1.2.2 used this same schema-9 manifest + Assets ZIP layout,
        // and copied source media without a size or compression-ratio ceiling.
        let legacyDirectoryURL = try writePackageDirectory(
            name: "Legacy12LargeAudio",
            manifest: TeamPackageManifest(
                schemaVersion: 9,
                appVersion: "1.2.2",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Older Device",
                team: team
            )
        )
        let legacyAssetsURL = legacyDirectoryURL.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyAssetsURL, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: appSourceURL,
            to: legacyAssetsURL.appendingPathComponent(audioSource.relativePath)
        )
        let legacyPackageURL = temp.fileURL("Shipping12LargeAudio.rollcall")
        try FileManager.default.zipItem(at: legacyDirectoryURL, to: legacyPackageURL, shouldKeepParent: false)

        let legacyPreview = try service.preview(packageURL: legacyPackageURL)
        let legacyImport = try service.import(
            packageURL: legacyPackageURL,
            audioAssetService: AudioAssetService()
        )
        XCTAssertEqual(legacyPreview.schemaVersion, 9)
        XCTAssertEqual(legacyPreview.appVersion, "1.2.2")
        try assertImportedAudioMatches(legacyImport.team, sourceURL: appSourceURL, expectedSize: fileSize)

        // A ZIP tool may recompress the same valid package. Silent PCM WAV can
        // exceed 1,000:1, so the absolute Assets limits—not the structural
        // compression-ratio guard—bound its expansion.
        let compressedPackageURL = try writeArchive(
            name: "Compressed12LargeAudio.rollcall",
            entries: [
                (path: "manifest.json", sourceURL: legacyDirectoryURL.appendingPathComponent("manifest.json"), compressionMethod: .deflate),
                (path: "Assets/\(audioSource.relativePath)", sourceURL: appSourceURL, compressionMethod: .deflate)
            ]
        )
        let compressedArchive = try Archive(url: compressedPackageURL, accessMode: .read)
        let compressedAssetEntry = try XCTUnwrap(compressedArchive["Assets/\(audioSource.relativePath)"])
        XCTAssertGreaterThan(compressedAssetEntry.uncompressedSize, compressedAssetEntry.compressedSize * 1_000)
        let compressedPreview = try service.preview(packageURL: compressedPackageURL)
        let compressedImport = try service.import(
            packageURL: compressedPackageURL,
            audioAssetService: AudioAssetService()
        )
        XCTAssertEqual(compressedPreview.schemaVersion, 9)
        try assertImportedAudioMatches(compressedImport.team, sourceURL: appSourceURL, expectedSize: fileSize)
    }

    func testExportRejectsSingleAssetAboveBoundedPackageContractBeforeCopying() throws {
        let relativePath = "oversized-export-\(UUID().uuidString).bin"
        let assetURL = try AppPaths.assetURL(relativePath: relativePath)
        try FileManager.default.createDirectory(
            at: assetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: assetURL.path, contents: nil)
        let assetFile = try FileHandle(forWritingTo: assetURL)
        try assetFile.truncate(atOffset: UInt64(256 * 1_024 * 1_024 + 1))
        try assetFile.close()

        let cue = RollCallTestFixtures.localCue(relativePath: relativePath)
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: cue
        )
        var team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        team.name = "Oversized-\(UUID().uuidString)"
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(team.name).rollcall")
        defer { try? FileManager.default.removeItem(at: packageURL) }

        XCTAssertThrowsError(
            try service.export(team: team, state: RollCallTestFixtures.appState(team: team))
        ) { error in
            guard let appError = error as? AppError,
                  case .packageSizeLimitExceeded = appError else {
                return XCTFail("Expected the package size limit error, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: packageURL.path))
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

    func testAssetHeavyMultiPlayerPackageExportsAndRoundTrips() throws {
        let photoData = deterministicBinaryData(byteCount: 384 * 1_024, seed: 0x11)
        let photoSourceData = deterministicBinaryData(byteCount: 768 * 1_024, seed: 0x22)
        var players: [Player] = []

        for index in 0..<8 {
            let photoPath = "player-\(index)-profile.jpg"
            let photoSourcePath = "player-\(index)-source.jpg"
            let audioPath = "player-\(index)-song.caf"
            let announcementPath = "player-\(index)-announcement.caf"
            try photoData.write(to: AppPaths.assetURL(relativePath: photoPath))
            try photoSourceData.write(to: AppPaths.assetURL(relativePath: photoSourcePath))
            try writeDeterministicAudio(
                to: AppPaths.assetURL(relativePath: audioPath),
                duration: 4,
                seed: UInt64(0x3300 + index)
            )
            try writeDeterministicAudio(
                to: AppPaths.assetURL(relativePath: announcementPath),
                duration: 1,
                seed: UInt64(0x4400 + index)
            )

            var player = RollCallTestFixtures.player(
                id: UUID(),
                name: "Player \(index + 1)",
                number: "\(index + 1)",
                cue: RollCallTestFixtures.localCue(relativePath: audioPath),
                photoRelativePath: photoPath,
                customAnnouncerRelativePath: announcementPath
            )
            player.photoSourceRelativePath = photoSourcePath
            players.append(player)
        }

        var team = RollCallTestFixtures.team(
            players: players,
            battingOrder: players.map(\.id)
        )
        team.name = "Asset-Heavy-\(UUID().uuidString)"
        let state = RollCallTestFixtures.appState(team: team)
        let start = ContinuousClock.now
        let packageURL = try service.export(team: team, state: state)
        let elapsed = start.duration(to: .now)
        defer { service.cleanupExportedPackage(at: packageURL) }

        let preview = try service.preview(packageURL: packageURL)
        let imported = try service.import(
            packageURL: packageURL,
            audioAssetService: AudioAssetService()
        )
        let packageBytes = try XCTUnwrap(
            packageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        )

        XCTAssertEqual(preview.team.players.count, players.count)
        XCTAssertEqual(imported.team.players.count, players.count)
        XCTAssertTrue(imported.team.players.allSatisfy { $0.photoRelativePath != nil })
        XCTAssertTrue(imported.team.players.allSatisfy { $0.photoSourceRelativePath != nil })
        XCTAssertTrue(imported.team.players.allSatisfy { $0.customAnnouncerRelativePath != nil })
        XCTAssertGreaterThan(packageBytes, 8 * 1_024 * 1_024)
        print("Asset-heavy package export: \(packageBytes) bytes in \(elapsed)")
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

    func testExportCleanupRemovesOnlyExactTopLevelTemporaryPackage() throws {
        var team = RollCallTestFixtures.team(players: [])
        team.name = "Cleanup-\(UUID().uuidString)"
        let packageURL = try service.export(
            team: team,
            state: RollCallTestFixtures.appState(team: team)
        )
        let unrelatedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Unrelated-\(UUID().uuidString).rollcall")
        let nestedDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Nested-\(UUID().uuidString)", isDirectory: true)
        let nestedPackageURL = nestedDirectory.appendingPathComponent("Nested.rollcall")
        let wrongExtensionURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Wrong-\(UUID().uuidString).zip")
        defer {
            try? FileManager.default.removeItem(at: packageURL)
            try? FileManager.default.removeItem(at: unrelatedURL)
            try? FileManager.default.removeItem(at: nestedDirectory)
            try? FileManager.default.removeItem(at: wrongExtensionURL)
        }
        try Data("unrelated".utf8).write(to: unrelatedURL)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: nestedPackageURL)
        try Data("wrong-extension".utf8).write(to: wrongExtensionURL)

        service.cleanupExportedPackage(at: packageURL)
        service.cleanupExportedPackage(at: packageURL)
        service.cleanupExportedPackage(at: nestedPackageURL)
        service.cleanupExportedPackage(at: wrongExtensionURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: packageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedPackageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: wrongExtensionURL.path))
    }

    @MainActor
    func testPackageShareFinalizationRetainsURLUntilMatchingShareFinishes() async throws {
        var team = RollCallTestFixtures.team(players: [])
        team.name = "Share-Finalization-\(UUID().uuidString)"
        let model = AppModel()
        model.state = RollCallTestFixtures.appState(team: team)
        model.prepareSelectedTeamExport()
        let exportResult = await model.confirmPendingPackageExport()
        let packageURL = try XCTUnwrap(exportResult)
        let unrelatedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Unrelated-\(UUID().uuidString).rollcall")
        defer {
            try? FileManager.default.removeItem(at: packageURL)
            try? FileManager.default.removeItem(at: unrelatedURL)
        }
        try Data("unrelated".utf8).write(to: unrelatedURL)

        XCTAssertEqual(model.exportURL, packageURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageURL.path))

        model.finishPackageShare(for: unrelatedURL)

        XCTAssertEqual(model.exportURL, packageURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedURL.path))

        model.finishPackageShare(for: packageURL)

        XCTAssertNil(model.exportURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: packageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedURL.path))
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
        let sourceURL = temp.fileURL("small-media.wav")
        try Data("wav".utf8).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "OversizedEntry.rollcall",
            entries: [(path: "Assets/oversized.wav", sourceURL: sourceURL, compressionMethod: .none)]
        )
        try overwriteArchiveUncompressedSize(
            256 * 1_024 * 1_024 + 1,
            for: "Assets/oversized.wav",
            in: packageURL
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsExcessiveAggregateMediaContents() throws {
        let sourceURL = temp.fileURL("small-media.wav")
        try Data("wav".utf8).write(to: sourceURL)
        let entryPaths = (0..<5).map { "Assets/media-\($0).wav" }
        let packageURL = try writeArchive(
            name: "ExcessiveAggregateMedia.rollcall",
            entries: entryPaths.map { (path: $0, sourceURL: sourceURL, compressionMethod: .none) }
        )
        let perEntrySize = 220 * 1_024 * 1_024
        for path in entryPaths {
            try overwriteArchiveUncompressedSize(perEntrySize, for: path, in: packageURL)
        }

        let archive = try Archive(url: packageURL, accessMode: .read)
        for path in entryPaths {
            XCTAssertEqual(try XCTUnwrap(archive[path]).uncompressedSize, UInt64(perEntrySize))
        }
        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchiveExtractionBoundsExpansionWhenAssetSizeMetadataIsUnderreported() throws {
        let sourceURL = temp.fileURL("forged-expansion.bin")
        FileManager.default.createFile(atPath: sourceURL.path, contents: nil)
        let sourceFile = try FileHandle(forWritingTo: sourceURL)
        try sourceFile.truncate(atOffset: UInt64(256 * 1_024 * 1_024 + 1))
        try sourceFile.close()

        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "forged-expansion.bin")
        )
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        let manifestURL = temp.fileURL("forged-expansion-manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(
            TeamPackageManifest(
                schemaVersion: 9,
                appVersion: "1.2.2",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Older Device",
                team: team
            )
        ).write(to: manifestURL)

        let packageURL = try writeArchive(
            name: "ForgedExpansion.rollcall",
            entries: [
                (path: "manifest.json", sourceURL: manifestURL, compressionMethod: .none),
                (path: "Assets/forged-expansion.bin", sourceURL: sourceURL, compressionMethod: .deflate)
            ]
        )
        try overwriteArchiveUncompressedSize(
            256 * 1_024 * 1_024,
            for: "Assets/forged-expansion.bin",
            in: packageURL
        )

        let archive = try Archive(url: packageURL, accessMode: .read)
        let entry = try XCTUnwrap(archive["Assets/forged-expansion.bin"])
        XCTAssertEqual(entry.uncompressedSize, 256 * 1_024 * 1_024)
        XCTAssertLessThan(try XCTUnwrap(packageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize), 16 * 1_024 * 1_024)

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsOversizedManifestBeforeDecoding() throws {
        let sourceURL = temp.fileURL("small-manifest.json")
        try Data("{}".utf8).write(to: sourceURL)
        let packageURL = try writeArchive(
            name: "OversizedManifest.rollcall",
            entries: [(path: "manifest.json", sourceURL: sourceURL, compressionMethod: .none)]
        )
        try overwriteArchiveUncompressedSize(
            8 * 1_024 * 1_024 + 1,
            for: "manifest.json",
            in: packageURL
        )

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testArchivePreflightRejectsArchiveAboveBoundedPackageSize() throws {
        let packageURL = temp.fileURL("OversizedArchive.rollcall")
        FileManager.default.createFile(atPath: packageURL.path, contents: nil)
        let file = try FileHandle(forWritingTo: packageURL)
        try file.truncate(atOffset: UInt64(1_040 * 1_024 * 1_024 + 1))
        try file.close()

        XCTAssertThrowsError(try service.preview(packageURL: packageURL)) { error in
            XCTAssertAppError(error, is: .invalidImport)
        }
    }

    func testPackageDirectoryRejectsOversizedManifest() throws {
        let packageURL = try writePackageDirectory(
            name: "OversizedDirectoryManifest.rollcall",
            manifest: TeamPackageManifest(
                schemaVersion: 9,
                appVersion: "1.2.2",
                exportedAt: RollCallTestFixtures.now,
                deviceLabel: "Older Device",
                team: RollCallTestFixtures.team(players: [])
            )
        )
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        let manifest = try FileHandle(forWritingTo: manifestURL)
        try manifest.truncate(atOffset: 8 * 1_024 * 1_024 + 1)
        try manifest.close()

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

    private func deterministicBinaryData(byteCount: Int, seed: UInt64) -> Data {
        var state = seed
        var data = Data(count: byteCount)
        data.withUnsafeMutableBytes { buffer in
            guard let bytes = buffer.bindMemory(to: UInt8.self).baseAddress else { return }
            for index in 0..<byteCount {
                state ^= state << 13
                state ^= state >> 7
                state ^= state << 17
                bytes[index] = UInt8(truncatingIfNeeded: state)
            }
        }
        return data
    }

    private func writeSilentStereoWAV(to url: URL, durationSeconds: Int) throws {
        let channels: UInt16 = 2
        let sampleRate: UInt32 = 44_100
        let bytesPerSample: UInt16 = 2
        let dataByteCount = UInt32(durationSeconds) * sampleRate * UInt32(channels) * UInt32(bytesPerSample)
        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(dataByteCount + 36, to: &header)
        header.append(contentsOf: "WAVEfmt ".utf8)
        appendLittleEndian(UInt32(16), to: &header)
        appendLittleEndian(UInt16(1), to: &header)
        appendLittleEndian(channels, to: &header)
        appendLittleEndian(sampleRate, to: &header)
        appendLittleEndian(sampleRate * UInt32(channels) * UInt32(bytesPerSample), to: &header)
        appendLittleEndian(channels * bytesPerSample, to: &header)
        appendLittleEndian(UInt16(16), to: &header)
        header.append(contentsOf: "data".utf8)
        appendLittleEndian(dataByteCount, to: &header)
        XCTAssertEqual(header.count, 44)

        FileManager.default.createFile(atPath: url.path, contents: nil)
        let file = try FileHandle(forWritingTo: url)
        try file.write(contentsOf: header)
        try file.truncate(atOffset: UInt64(header.count) + UInt64(dataByteCount))
        try file.close()
    }

    private func appendLittleEndian(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    private func appendLittleEndian(_ value: UInt32, to data: inout Data) {
        for byteIndex in 0..<4 {
            data.append(UInt8(truncatingIfNeeded: value >> (byteIndex * 8)))
        }
    }

    private func assertImportedAudioMatches(
        _ team: Team,
        sourceURL: URL,
        expectedSize: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard case .localAudio(let importedSource)? = team.players.first?.cue?.source else {
            XCTFail("Expected an imported local audio source", file: file, line: line)
            return
        }
        let importedURL = try AudioAssetService().assetURL(relativePath: importedSource.relativePath)
        let importedSize = try XCTUnwrap(
            importedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            file: file,
            line: line
        )
        XCTAssertEqual(importedSize, expectedSize, file: file, line: line)
        XCTAssertTrue(try filesHaveSameBytes(sourceURL, importedURL), file: file, line: line)
    }

    private func filesHaveSameBytes(_ lhsURL: URL, _ rhsURL: URL) throws -> Bool {
        let lhs = try FileHandle(forReadingFrom: lhsURL)
        let rhs = try FileHandle(forReadingFrom: rhsURL)
        defer {
            try? lhs.close()
            try? rhs.close()
        }

        while true {
            let lhsChunk = try lhs.read(upToCount: 1_024 * 1_024) ?? Data()
            let rhsChunk = try rhs.read(upToCount: 1_024 * 1_024) ?? Data()
            guard lhsChunk == rhsChunk else { return false }
            if lhsChunk.isEmpty { return true }
        }
    }

    private func overwriteArchiveUncompressedSize(
        _ uncompressedSize: Int,
        for entryPath: String,
        in packageURL: URL
    ) throws {
        var archiveData = try Data(contentsOf: packageURL)
        var offset = 0
        while offset + 46 <= archiveData.count {
            let signature = UInt32(archiveData[offset])
                | (UInt32(archiveData[offset + 1]) << 8)
                | (UInt32(archiveData[offset + 2]) << 16)
                | (UInt32(archiveData[offset + 3]) << 24)
            guard signature == 0x0201_4B50 else {
                offset += 1
                continue
            }

            let nameLength = Int(archiveData[offset + 28]) | (Int(archiveData[offset + 29]) << 8)
            let extraLength = Int(archiveData[offset + 30]) | (Int(archiveData[offset + 31]) << 8)
            let commentLength = Int(archiveData[offset + 32]) | (Int(archiveData[offset + 33]) << 8)
            let nameStart = offset + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= archiveData.count else { throw AppError.invalidImport }
            let path = String(data: archiveData[nameStart..<nameEnd], encoding: .utf8)
            if path == entryPath {
                let encodedSize = UInt32(uncompressedSize)
                for byteIndex in 0..<4 {
                    archiveData[offset + 24 + byteIndex] = UInt8(
                        truncatingIfNeeded: encodedSize >> (byteIndex * 8)
                    )
                }
                let localHeaderOffset = Int(littleEndianUInt32(in: archiveData, at: offset + 42))
                guard localHeaderOffset + 30 <= archiveData.count,
                      littleEndianUInt32(in: archiveData, at: localHeaderOffset) == 0x0403_4B50 else {
                    throw AppError.invalidImport
                }
                for byteIndex in 0..<4 {
                    archiveData[localHeaderOffset + 22 + byteIndex] = UInt8(
                        truncatingIfNeeded: encodedSize >> (byteIndex * 8)
                    )
                }
                try archiveData.write(to: packageURL, options: .atomic)
                return
            }
            offset = nameEnd + extraLength + commentLength
        }
        throw AppError.invalidImport
    }

    private func littleEndianUInt32(in data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private func writeDeterministicAudio(to url: URL, duration: TimeInterval, seed: UInt64) throws {
        let format = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        var state = seed
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for frame in 0..<Int(frameCount) {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            samples[frame] = Float(Int16(truncatingIfNeeded: state)) / Float(Int16.max)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
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

    private func manifestObject(in packageURL: URL) throws -> [String: Any] {
        let archive = try Archive(url: packageURL, accessMode: .read)
        let entry = try XCTUnwrap(archive["manifest.json"])
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func manifestObject(at manifestURL: URL) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any])
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
