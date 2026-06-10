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
            playerID: RollCallTestFixtures.alexID,
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
            playerID: RollCallTestFixtures.alexID,
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

    private func writeState(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)
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
