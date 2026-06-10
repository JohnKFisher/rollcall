import XCTest
@testable import RollCall

final class AppStatePersistenceTests: XCTestCase {
    func testAppStateRoundTripsTeamRosterAndSelection() throws {
        let team = RollCallTestFixtures.team()
        var state = RollCallTestFixtures.appState(team: team)
        state.recentlyDeleted = [
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .player(
                    DeletedPlayerRecord(
                        player: RollCallTestFixtures.player(id: UUID(), name: "Deleted Player", number: "7"),
                        originalTeamID: team.id,
                        originalTeamName: team.name,
                        previousBattingOrder: []
                    )
                )
            )
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(AppState.self, from: try encoder.encode(state))

        XCTAssertEqual(decoded.selectedTeamID, team.id)
        XCTAssertEqual(decoded.teams.first?.players.map(\.displayName), ["Alex Ramirez", "Jordan Lee", "Casey Morgan"])
        XCTAssertEqual(decoded.recentlyDeleted.count, 1)
        if case .player(let deletedPlayer)? = decoded.recentlyDeleted.first?.payload {
            XCTAssertEqual(deletedPlayer.player.displayName, "Deleted Player")
            XCTAssertEqual(deletedPlayer.originalTeamID, team.id)
            XCTAssertEqual(deletedPlayer.originalTeamName, team.name)
        } else {
            XCTFail("Expected a deleted player payload.")
        }
        XCTAssertEqual(decoded.settings, .default)
        XCTAssertEqual(decoded.ratingRequest, .default)
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

    func testLegacyPlayerCueDecodesAsPrivateSongAssignment() throws {
        let cueData = try JSONEncoder().encode(RollCallTestFixtures.localCue())
        let cueObject = try XCTUnwrap(JSONSerialization.jsonObject(with: cueData) as? [String: Any])
        let playerObject: [String: Any] = [
            "id": RollCallTestFixtures.alexID.uuidString,
            "displayName": "Alex Ramirez",
            "uniformNumber": "12",
            "pronunciationOverride": "",
            "cue": cueObject
        ]
        let playerData = try JSONSerialization.data(withJSONObject: playerObject)

        let player = try JSONDecoder().decode(Player.self, from: playerData)

        guard case .privateClip(let clip)? = player.songAssignment else {
            return XCTFail("Expected the legacy cue to migrate to a private song assignment.")
        }
        XCTAssertEqual(clip.playbackCue, RollCallTestFixtures.localCue())
    }

    func testPlayerEncodingWritesSongAssignmentWithoutLegacyCue() throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.cue = RollCallTestFixtures.localCue()

        let data = try JSONEncoder().encode(player)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNotNil(object["songAssignment"])
        XCTAssertNil(object["cue"])
    }

    func testMigratedAppleMusicClipIsSourceBackedAndNotPortable() {
        let clip = SongClip(
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "song.alex",
                title: "Thunder",
                artistName: "The Bats"
            )
        )

        XCTAssertEqual(clip.readinessInputs.playback, .sourceBackedReady)
        XCTAssertFalse(clip.readinessInputs.downloadedOnDevice)
        XCTAssertEqual(clip.portabilityInputs.portability, .sourceReferenceOnly)
        XCTAssertFalse(clip.portabilityInputs.generatedAssetCanBeExported)
        XCTAssertEqual(clip.policy.appleMusicHandlingPolicy, .readableLocalOnly)
    }

    func testSongAssignmentRoundTripsPrivateAndSharedCases() throws {
        let privateAssignment = SongAssignment.privateClip(
            SongClip(cue: RollCallTestFixtures.localCue())
        )
        let sharedID = UUID()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        XCTAssertEqual(
            try decoder.decode(SongAssignment.self, from: encoder.encode(privateAssignment)),
            privateAssignment
        )
        XCTAssertEqual(
            try decoder.decode(SongAssignment.self, from: encoder.encode(SongAssignment.sharedTeamClip(sharedID))),
            .sharedTeamClip(sharedID)
        )
    }

    func testTeamDecodeDefaultsMissingTeamClipsToEmpty() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let teamData = try encoder.encode(RollCallTestFixtures.team())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: teamData) as? [String: Any])
        object.removeValue(forKey: "teamClips")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let team = try decoder.decode(Team.self, from: legacyData)

        XCTAssertTrue(team.teamClips.isEmpty)
    }

    func testFutureSavedStateSchemaCanBeDetectedByCallers() throws {
        var state = RollCallTestFixtures.appState(team: RollCallTestFixtures.team())
        state.schemaVersion = AppState.currentSchemaVersion + 1
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let decoded = try decoder.decode(AppState.self, from: try encoder.encode(state))

        XCTAssertGreaterThan(decoded.schemaVersion, AppState.currentSchemaVersion)
    }

    func testAppStateDecodeDefaultsMissingRatingRequestState() throws {
        let json = """
        {
          "schemaVersion": 6,
          "appVersion": "1.1.0",
          "deviceIdentity": { "label": "This iPhone" },
          "teams": [],
          "recentlyDeleted": [],
          "snapshots": [],
          "experimental": {
            "showExperimentalFeatures": false,
            "unlockPremiumForTesting": false,
            "appleMusicLocalCopyEnabled": false,
            "appleMusicTeamPlaylistSyncEnabled": false,
            "appleMusicTransitionCrossfadeEnabled": false
          },
          "settings": {
            "hapticsEnabled": true,
            "fadeOutVolumeAutomationEnabled": false,
            "alwaysUseDarkLiveMode": true,
            "keepScreenAwakeDuringLiveUse": false
          },
          "recentAppleMusicSelections": [],
          "trimDefaults": { "preferredLength": 8 }
        }
        """

        let decoded = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.ratingRequest, .default)
        XCTAssertFalse(decoded.settings.showLineupProgressHints)
    }

    func testAppStateDecodeMigratesLegacySingleAttemptRatingState() throws {
        let json = """
        {
          "schemaVersion": 7,
          "appVersion": "1.1.0",
          "deviceIdentity": { "label": "This iPhone" },
          "teams": [],
          "recentlyDeleted": [],
          "snapshots": [],
          "experimental": {
            "showExperimentalFeatures": false,
            "unlockPremiumForTesting": false,
            "appleMusicLocalCopyEnabled": false,
            "appleMusicTeamPlaylistSyncEnabled": false,
            "appleMusicTransitionCrossfadeEnabled": false
          },
          "settings": {
            "hapticsEnabled": true,
            "fadeOutVolumeAutomationEnabled": false,
            "alwaysUseDarkLiveMode": true,
            "keepScreenAwakeDuringLiveUse": false
          },
          "recentAppleMusicSelections": [],
          "trimDefaults": { "preferredLength": 8 },
          "ratingRequest": {
            "successfulGameDaySessionCount": 5,
            "hasPlayedQualifyingCueInCurrentGameDayVisit": false,
            "hasCountedCurrentGameDayVisit": true,
            "hasAttemptedAutomaticPrompt": true
          }
        }
        """

        let decoded = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.ratingRequest.automaticPromptAttemptCount, 1)
        XCTAssertEqual(decoded.ratingRequest.nextAutomaticPromptSessionThreshold, 10)
        XCTAssertFalse(decoded.settings.showLineupProgressHints)
    }

    func testAppStateDecodeDefaultsMissingLineupProgressHintsSettingToDisabled() throws {
        let json = """
        {
          "schemaVersion": 8,
          "appVersion": "1.1.0",
          "deviceIdentity": { "label": "This iPhone" },
          "teams": [],
          "recentlyDeleted": [],
          "snapshots": [],
          "experimental": {
            "showExperimentalFeatures": false,
            "unlockPremiumForTesting": false,
            "appleMusicLocalCopyEnabled": false,
            "appleMusicTeamPlaylistSyncEnabled": false,
            "appleMusicTransitionCrossfadeEnabled": false
          },
          "settings": {
            "hapticsEnabled": true,
            "fadeOutVolumeAutomationEnabled": false,
            "alwaysUseDarkLiveMode": true,
            "keepScreenAwakeDuringLiveUse": false
          },
          "recentAppleMusicSelections": [],
          "trimDefaults": { "preferredLength": 8 },
          "ratingRequest": {
            "successfulGameDaySessionCount": 0,
            "hasPlayedQualifyingCueInCurrentGameDayVisit": false,
            "hasCountedCurrentGameDayVisit": false,
            "automaticPromptAttemptCount": 0,
            "nextAutomaticPromptSessionThreshold": 10
          }
        }
        """

        let decoded = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))

        XCTAssertFalse(decoded.settings.showLineupProgressHints)
    }
}
