import AVFoundation
import XCTest
@testable import RollCall

final class SongClipGenerationTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    func testGenerationKeyIsStableAndChangesWithCreativeSelection() {
        var clip = SongClip(cue: RollCallTestFixtures.localCue())
        let originalKey = clip.generationKey

        XCTAssertEqual(originalKey, clip.generationKey)

        clip.requestedSelection.startTime += 1
        XCTAssertNotEqual(originalKey, clip.generationKey)
    }

    func testPreparationRequestRejectsStaleCreativeSelection() {
        var clip = SongClip(cue: RollCallTestFixtures.localCue())
        let currentRequest = SongClipPreparationRequest(
            id: UUID(),
            teamID: RollCallTestFixtures.teamID,
            target: .player(RollCallTestFixtures.alexID),
            clipID: clip.id,
            generationKey: clip.generationKey,
            trigger: .assignmentSaved,
            isExplicit: false
        )

        XCTAssertTrue(currentRequest.matches(clip))
        clip.requestedSelection.duration += 1
        XCTAssertFalse(currentRequest.matches(clip))
    }

    func testPublicAPICannotRequestAppleMusicOfflineDownload() {
        XCTAssertFalse(SongClipGenerationService.canRequestAppleMusicOfflineDownload)
        XCTAssertFalse(SongClipPolicy.current.autoDownloadEligibleSongsEnabled)
    }

    func testAppleMusicSearchRecognizesCancellationErrors() {
        XCTAssertTrue(MusicCatalogService.isCancellation(CancellationError()))
        XCTAssertTrue(
            MusicCatalogService.isCancellation(
                URLError(.cancelled)
            )
        )
        XCTAssertFalse(
            MusicCatalogService.isCancellation(
                URLError(.notConnectedToInternet)
            )
        )
    }

    func testPlayerEditorDraftStateIgnoresBackgroundSongPreparationChanges() {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7",
            cue: RollCallTestFixtures.localCue()
        )
        var refreshedPlayer = player
        guard case .privateClip(var clip) = refreshedPlayer.songAssignment else {
            return XCTFail("Expected a private song clip.")
        }
        clip.readinessInputs.playback = .localClipReady
        clip.generatedAsset.status = .pending
        clip.retryMetadata.attemptCount = 1
        refreshedPlayer.songAssignment = .privateClip(clip)

        XCTAssertNotEqual(player, refreshedPlayer)
        XCTAssertEqual(
            PlayerEditorDraftState(player: player),
            PlayerEditorDraftState(player: refreshedPlayer)
        )
    }

    func testPlayerEditorDraftStateDetectsDeferredIdentityPhotoAndTimingChanges() {
        let player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7",
            cue: RollCallTestFixtures.localCue()
        )

        var renamed = player
        renamed.displayName = "Alex M."
        XCTAssertNotEqual(PlayerEditorDraftState(player: player), PlayerEditorDraftState(player: renamed))

        var renumbered = player
        renumbered.uniformNumber = "17"
        XCTAssertNotEqual(PlayerEditorDraftState(player: player), PlayerEditorDraftState(player: renumbered))

        var rephotographed = player
        rephotographed.photoRelativePath = "new-photo.jpg"
        XCTAssertNotEqual(PlayerEditorDraftState(player: player), PlayerEditorDraftState(player: rephotographed))

        var retrimmed = player
        retrimmed.cue?.startTime += 0.25
        XCTAssertNotEqual(PlayerEditorDraftState(player: player), PlayerEditorDraftState(player: retrimmed))
    }

    func testTeamResolvesSharedAssignmentToPlaybackCue() {
        let clip = SongClip(cue: RollCallTestFixtures.localCue())
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        player.songAssignment = .sharedTeamClip(clip.id)
        var team = RollCallTestFixtures.team(players: [player])
        team.teamClips = [clip]

        XCTAssertEqual(team.songClip(for: player), clip)
        XCTAssertEqual(team.cue(for: player), clip.playbackCue)
        XCTAssertEqual(team.playerAssignmentCount(forTeamClipID: clip.id), 1)
    }

    @MainActor
    func testSavingExactTeamClipDuplicateReusesExistingClip() throws {
        try writeState(RollCallTestFixtures.appState(team: RollCallTestFixtures.team()))
        let model = AppModel()
        let cue = RollCallTestFixtures.localCue()

        let first = try XCTUnwrap(model.saveTeamClip(cue: cue, named: "Warmup"))
        let second = try XCTUnwrap(model.saveTeamClip(cue: cue, named: "Different Name"))

        guard case .saved(let savedID) = first else {
            return XCTFail("Expected the first clip to be saved.")
        }
        XCTAssertEqual(second, .exactDuplicate(savedID))
        XCTAssertEqual(model.selectedTeam?.teamClips.count, 1)
    }

    @MainActor
    func testSavingReadableTeamClipSchedulesPortableGeneration() async throws {
        let sourcePath = "team-source.caf"
        try writeSilentAudio(to: AppPaths.assetURL(relativePath: sourcePath), duration: 2)
        var cue = RollCallTestFixtures.localCue(relativePath: sourcePath)
        cue.duration = 1
        let team = RollCallTestFixtures.team(players: [])
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()

        guard case .saved(let clipID) = model.saveTeamClip(cue: cue, named: "Team Intro") else {
            return XCTFail("Expected Team Clip to save.")
        }

        let generated = try await waitForTeamClip(in: model, id: clipID) {
            $0.generatedAsset.status == .ready
        }
        XCTAssertEqual(generated.readinessInputs.playback, .localClipReady)
        XCTAssertEqual(generated.portabilityInputs.portability, .portableLocalClip)
        let generatedPath = try XCTUnwrap(generated.generatedAsset.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try AppPaths.assetURL(relativePath: generatedPath).path))
    }

    @MainActor
    func testPromotionReusesDuplicatesAndProtectedDeleteKeepsPlayerCopies() throws {
        let alex = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7",
            cue: RollCallTestFixtures.localCue()
        )
        let jordan = RollCallTestFixtures.player(
            id: RollCallTestFixtures.jordanID,
            name: "Jordan Lee",
            number: "4",
            cue: RollCallTestFixtures.localCue()
        )
        let team = RollCallTestFixtures.team(players: [alex, jordan])
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()

        let result = model.savePlayerSongsToTeamClips()

        XCTAssertEqual(result.addedCount, 1)
        XCTAssertEqual(result.reusedCount, 1)
        XCTAssertEqual(result.assignedPlayerCount, 2)
        let sharedClip = try XCTUnwrap(model.selectedTeam?.teamClips.first)
        XCTAssertEqual(model.selectedTeam?.playerAssignmentCount(forTeamClipID: sharedClip.id), 2)

        model.deleteTeamClip(sharedClip.id, keepPlayerCopies: true)

        let updatedTeam = try XCTUnwrap(model.selectedTeam)
        XCTAssertTrue(updatedTeam.teamClips.isEmpty)
        XCTAssertTrue(updatedTeam.players.allSatisfy {
            guard case .privateClip? = $0.songAssignment else { return false }
            return updatedTeam.cue(for: $0) != nil
        })
    }

    @MainActor
    func testProtectedTeamClipDeletePreservesRecentlyDeletedPlayerAssignment() throws {
        let sharedClip = SongClip(cue: RollCallTestFixtures.localCue())
        var deletedPlayer = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Morgan",
            number: "7"
        )
        deletedPlayer.songAssignment = .sharedTeamClip(sharedClip.id)
        var team = RollCallTestFixtures.team(players: [])
        team.teamClips = [sharedClip]
        var state = RollCallTestFixtures.appState(team: team)
        state.recentlyDeleted = [
            RecentlyDeletedItem(
                id: UUID(),
                deletedAt: .now,
                payload: .player(
                    DeletedPlayerRecord(
                        player: deletedPlayer,
                        originalTeamID: team.id,
                        originalTeamName: team.name,
                        previousBattingOrder: [deletedPlayer.id]
                    )
                )
            )
        ]
        try writeState(state)
        let model = AppModel()

        model.deleteTeamClip(sharedClip.id, keepPlayerCopies: true)

        guard case .player(let updated)? = model.state.recentlyDeleted.first?.payload,
              case .privateClip(let privateClip)? = updated.player.songAssignment else {
            return XCTFail("Expected a preserved private clip for the recoverable player.")
        }
        XCTAssertEqual(privateClip.sourceLineageClipID, sharedClip.id)
        XCTAssertEqual(privateClip.playbackCue.source, sharedClip.playbackCue.source)
    }

    func testRuntimeVolumeAutomationAppliesOnlyToSourceBackedAppleMusic() {
        let localSource = RollCallTestFixtures.localCue().source
        let builtInSource = CueSource.builtInClip(
            BuiltInClipSource(id: "test", displayName: "Test")
        )
        let appleMusicSource = RollCallTestFixtures.appleMusicCue(
            songID: "123",
            title: "Song",
            artistName: "Artist"
        ).source

        XCTAssertFalse(localSource.runtimeVolumeAutomationEnabled(whenSettingEnabled: true))
        XCTAssertFalse(builtInSource.runtimeVolumeAutomationEnabled(whenSettingEnabled: true))
        XCTAssertTrue(appleMusicSource.runtimeVolumeAutomationEnabled(whenSettingEnabled: true))
        XCTAssertFalse(appleMusicSource.runtimeVolumeAutomationEnabled(whenSettingEnabled: false))
    }

    func testMissingLocalSourceFailsPermanentlyWithoutCreatingAsset() async {
        let service = SongClipGenerationService()
        let clip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: "missing.caf"))

        let outcome = await service.prepare(clip)

        XCTAssertEqual(outcome, .failed(code: .sourceMissing, retryable: false))
    }

    func testUnreadablePresentSourceReturnsRetryableRenderFailure() async throws {
        let relativePath = "unreadable.m4a"
        try Data("not-audio".utf8).write(to: AppPaths.assetURL(relativePath: relativePath))
        let clip = SongClip(cue: RollCallTestFixtures.localCue(relativePath: relativePath))

        let outcome = await SongClipGenerationService().prepare(clip)

        XCTAssertEqual(outcome, .failed(code: .renderFailed, retryable: true))
    }

    func testReadableLocalSourceGeneratesPortableM4A() async throws {
        let relativePath = "source.caf"
        let sourceURL = try AppPaths.assetURL(relativePath: relativePath)
        try writeSilentAudio(to: sourceURL, duration: 1)
        var cue = RollCallTestFixtures.localCue(relativePath: relativePath)
        cue.startTime = 0.1
        cue.duration = 0.5
        cue.fadeOutDuration = 0.1
        let clip = SongClip(cue: cue)

        let outcome = await SongClipGenerationService().prepare(clip)

        guard case .generated(let asset) = outcome else {
            return XCTFail("Expected a generated local clip, got \(outcome).")
        }
        XCTAssertEqual(asset.status, .ready)
        XCTAssertEqual(asset.generationKey, clip.generationKey)
        let renderedSelection = try XCTUnwrap(asset.renderedSelection)
        XCTAssertEqual(renderedSelection.startTime, 0.1, accuracy: 0.01)
        XCTAssertEqual(renderedSelection.duration, 0.5, accuracy: 0.02)
        XCTAssertTrue(asset.relativePath?.hasPrefix("GeneratedClips/") == true)
        let generatedRelativePath = try XCTUnwrap(asset.relativePath)
        let generatedURL = try AppPaths.assetURL(relativePath: generatedRelativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: generatedURL.path))
    }

    func testWaveformSamplerReflectsReadableAudioAmplitude() async throws {
        let sourceURL = try AppPaths.assetURL(relativePath: "waveform-source.caf")
        try writeSteppedAudio(to: sourceURL, duration: 1)

        let samples = try await SongWaveformService().samples(from: sourceURL, sampleCount: 20)

        XCTAssertEqual(samples.count, 20)
        XCTAssertLessThan(samples.prefix(8).max() ?? 1, 0.2)
        XCTAssertGreaterThan(samples.suffix(8).min() ?? 0, 0.9)
    }

    func testWaveformSamplerRejectsUnreadableAudio() async throws {
        let sourceURL = try AppPaths.assetURL(relativePath: "waveform-unreadable.m4a")
        try Data("not-audio".utf8).write(to: sourceURL)

        do {
            _ = try await SongWaveformService().samples(from: sourceURL, sampleCount: 20)
            XCTFail("Expected unreadable audio to fail waveform sampling.")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testChangingClipLengthKeepsWaveformStartPositionFixed() {
        let shortClip = SongShapeRailGeometry(
            width: 320,
            startTime: 60,
            duration: 8,
            timelineDuration: 180
        )
        let longClip = SongShapeRailGeometry(
            width: 320,
            startTime: 60,
            duration: 20,
            timelineDuration: 180
        )

        XCTAssertEqual(shortClip.offset, longClip.offset, accuracy: 0.001)
        XCTAssertEqual(shortClip.offset, 320 * 60 / 180, accuracy: 0.001)
        XCTAssertLessThan(shortClip.selectedWidth, longClip.selectedWidth)
    }

    func testWaveformDragMapsVisualPositionToTimelineStart() {
        let geometry = SongShapeRailGeometry(
            width: 320,
            startTime: 0,
            duration: 10,
            timelineDuration: 160
        )

        XCTAssertEqual(
            geometry.startTime(centeredAt: 170),
            80,
            accuracy: 0.001
        )
    }

    func testPrecisionStartAdjustmentClampsToAvailableTimeline() {
        let earlier = SongClipTimingAdjustment.adjustingStart(
            startTime: 0.1,
            duration: 10,
            fadeOutDuration: 2,
            delta: -0.25,
            timelineDuration: 180
        )
        let later = SongClipTimingAdjustment.adjustingStart(
            startTime: 169.75,
            duration: 10,
            fadeOutDuration: 2,
            delta: 1,
            timelineDuration: 180
        )

        XCTAssertEqual(earlier.startTime, 0)
        XCTAssertEqual(later.startTime, 170)
    }

    func testPrecisionLengthAdjustmentKeepsStartUnlessEndRequiresClamp() {
        let normal = SongClipTimingAdjustment.adjustingDuration(
            startTime: 60,
            duration: 8,
            fadeOutDuration: 2,
            delta: 0.25,
            timelineDuration: 180
        )
        let clamped = SongClipTimingAdjustment.adjustingDuration(
            startTime: 171,
            duration: 8,
            fadeOutDuration: 2,
            delta: 2,
            timelineDuration: 180
        )

        XCTAssertEqual(normal.startTime, 60)
        XCTAssertEqual(normal.duration, 8.25)
        XCTAssertEqual(clamped.startTime, 170)
        XCTAssertEqual(clamped.duration, 10)
    }

    func testPrecisionLengthAndFadeRespectBounds() {
        let minimumLength = SongClipTimingAdjustment.adjustingDuration(
            startTime: 0,
            duration: 1,
            fadeOutDuration: 1,
            delta: -1,
            timelineDuration: 180
        )
        let maximumLength = SongClipTimingAdjustment.adjustingDuration(
            startTime: 0,
            duration: 20,
            fadeOutDuration: 2,
            delta: 1,
            timelineDuration: 180
        )
        let maximumFade = SongClipTimingAdjustment.adjustingFade(
            startTime: 0,
            duration: 3,
            fadeOutDuration: 2.75,
            delta: 1,
            timelineDuration: 180
        )

        XCTAssertEqual(minimumLength.duration, 1)
        XCTAssertEqual(maximumLength.duration, 20)
        XCTAssertEqual(maximumFade.fadeOutDuration, 3)
    }

    func testQueueDeduplicatesPlayerRequestsAndHonorsPause() async {
        let queue = SongClipGenerationQueue()
        let first = request(key: "first")
        let replacement = request(key: "replacement")

        await queue.enqueue(first)
        await queue.enqueue(replacement)
        await queue.setPaused(true, reason: .liveUse)

        let pausedNext = await queue.next()
        let pausedCount = await queue.pendingCount()
        XCTAssertNil(pausedNext)
        XCTAssertEqual(pausedCount, 1)

        await queue.setPaused(false, reason: .liveUse)
        let next = await queue.next()
        XCTAssertEqual(next, replacement)
        await queue.complete(replacement)
        let completedCount = await queue.pendingCount()
        XCTAssertEqual(completedCount, 0)
    }

    func testQueueKeepsPlayerAndTeamClipTargetsIndependent() async {
        let queue = SongClipGenerationQueue()
        let playerRequest = request(key: "player")
        var teamClipRequest = request(key: "team")
        teamClipRequest.target = .teamClip(teamClipRequest.clipID)

        await queue.enqueue(playerRequest)
        await queue.enqueue(teamClipRequest)

        let first = await queue.next()
        XCTAssertEqual(first, playerRequest)
        await queue.complete(playerRequest)
        let second = await queue.next()
        XCTAssertEqual(second, teamClipRequest)
    }

    func testExplicitRequestBypassesLowPowerPauseButNotLiveUsePause() async {
        let queue = SongClipGenerationQueue()
        var explicit = request(key: "explicit")
        explicit.isExplicit = true
        await queue.enqueue(explicit)
        await queue.setPaused(true, reason: .lowPowerMode)

        let lowPowerNext = await queue.next()
        XCTAssertEqual(lowPowerNext, explicit)
        await queue.complete(explicit)

        await queue.enqueue(explicit)
        await queue.setPaused(true, reason: .liveUse)
        let liveUseNext = await queue.next()
        XCTAssertNil(liveUseNext)
    }

    @MainActor
    func testFailedRegenerationPreservesExistingReadyGeneratedAsset() async throws {
        let generatedRelativePath = "GeneratedClips/existing.m4a"
        let generatedURL = try AppPaths.assetURL(relativePath: generatedRelativePath)
        try Data("existing-generated-audio".utf8).write(to: generatedURL)
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "missing-original.caf")
        )
        guard case .privateClip(var clip)? = player.songAssignment else {
            return XCTFail("Expected a private song assignment.")
        }
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: generatedRelativePath,
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        clip.readinessInputs.playback = .localClipReady
        clip.portabilityInputs = SongClipPortabilityInputs(
            portability: .portableLocalClip,
            generatedAssetCanBeExported: true
        )
        player.songAssignment = .privateClip(clip)
        let team = RollCallTestFixtures.team(players: [player], battingOrder: [player.id])
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()

        model.tryPreparingSongNow(for: player.id)
        let updatedClip = try await waitForClip(in: model) {
            $0.retryMetadata.attemptCount == 1
        }

        XCTAssertEqual(updatedClip.generatedAsset.status, .ready)
        XCTAssertEqual(updatedClip.generatedAsset.relativePath, generatedRelativePath)
        XCTAssertEqual(updatedClip.readinessInputs.playback, .localClipReady)
        XCTAssertTrue(FileManager.default.fileExists(atPath: generatedURL.path))
    }

    private func request(key: String) -> SongClipPreparationRequest {
        SongClipPreparationRequest(
            id: UUID(),
            teamID: RollCallTestFixtures.teamID,
            target: .player(RollCallTestFixtures.alexID),
            clipID: RollCallTestFixtures.localCueID,
            generationKey: key,
            trigger: .assignmentSaved,
            isExplicit: false
        )
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

    private func writeSteppedAudio(to url: URL, duration: TimeInterval) throws {
        let format = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for frame in 0..<Int(frameCount) {
            samples[frame] = frame < Int(frameCount) / 2 ? 0.05 : 0.8
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func writeState(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)
    }

    @MainActor
    private func waitForTeamClip(
        in model: AppModel,
        id: UUID,
        matching predicate: (SongClip) -> Bool
    ) async throws -> SongClip {
        for _ in 0..<100 {
            if let clip = model.selectedTeam?.teamClips.first(where: { $0.id == id }),
               predicate(clip) {
                return clip
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw NSError(
            domain: "SongClipGenerationTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for Team Clip preparation."]
        )
    }

    @MainActor
    private func waitForClip(
        in model: AppModel,
        matching predicate: (SongClip) -> Bool
    ) async throws -> SongClip {
        for _ in 0..<100 {
            if let clip = model.selectedTeam?.players.first?.songAssignment?.privateClip,
               predicate(clip) {
                return clip
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw NSError(
            domain: "SongClipGenerationTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for song clip preparation."]
        )
    }
}
