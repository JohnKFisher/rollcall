import XCTest
@testable import RollCall

@MainActor
private final class DeferredAppleMusicCatalogResolver {
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private var resultContinuation: CheckedContinuation<MusicSearchResult, Error>?

    func resolve(_ result: MusicSearchResult) async throws -> MusicSearchResult {
        requestContinuation?.resume()
        requestContinuation = nil
        return try await withCheckedThrowingContinuation { continuation in
            resultContinuation = continuation
        }
    }

    func waitForRequest() async {
        guard resultContinuation == nil else { return }
        await withCheckedContinuation { continuation in
            requestContinuation = continuation
        }
    }

    func complete(with result: MusicSearchResult) {
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
}

@MainActor
private final class ControlledAppleMusicResultResolver {
    private var continuations: [String: CheckedContinuation<MusicSearchResult, Error>] = [:]
    private var requestCountContinuation: CheckedContinuation<Void, Never>?
    private var requestedSongIDs: [String] = []

    func resolve(_ result: MusicSearchResult) async throws -> MusicSearchResult {
        requestedSongIDs.append(result.songID)
        if requestedSongIDs.count >= 2 {
            requestCountContinuation?.resume()
            requestCountContinuation = nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            continuations[result.songID] = continuation
        }
    }

    func waitForTwoRequests() async {
        guard requestedSongIDs.count < 2 else { return }
        await withCheckedContinuation { continuation in
            requestCountContinuation = continuation
        }
    }

    func complete(songID: String, with result: MusicSearchResult) {
        continuations.removeValue(forKey: songID)?.resume(returning: result)
    }
}

@MainActor
private final class RecordedPreviewPlayback {
    private(set) var playedSongIDs: [String] = []

    func play(_ cue: Cue) async {
        guard case .appleMusic(let source) = cue.source else { return }
        playedSongIDs.append(source.songID)
    }
}

private actor ControlledPersistenceInterleaving {
    private enum Event: Hashable {
        case writePaused
        case coalesced
        case unconfirmed
        case applicationPaused
        case applied
    }

    private var bufferedEvents: [Event: [Int]] = [:]
    private var eventWaiters: [Event: [CheckedContinuation<Int, Never>]] = [:]
    private var shouldPauseNextWrite = false
    private var pausedWriteContinuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private var shouldObserveNextCoalescedRequest = false
    private var shouldObserveNextUnconfirmedResult = false
    private var pausedApplicationSequences: Set<Int> = []
    private var pausedApplicationContinuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private var observedAppliedSequences: Set<Int> = []

    func pauseNextWrite() {
        shouldPauseNextWrite = true
    }

    func beforeWrite(sequence: Int) async {
        guard shouldPauseNextWrite else { return }
        shouldPauseNextWrite = false
        send(sequence, as: .writePaused)
        await withCheckedContinuation { continuation in
            pausedWriteContinuations[sequence] = continuation
        }
    }

    func observeNextCoalescedRequest() {
        shouldObserveNextCoalescedRequest = true
    }

    func didCoalesce(sequence: Int) {
        guard shouldObserveNextCoalescedRequest else { return }
        shouldObserveNextCoalescedRequest = false
        send(sequence, as: .coalesced)
    }

    func observeNextUnconfirmedResult() {
        shouldObserveNextUnconfirmedResult = true
    }

    func didReturnUnconfirmed(sequence: Int) {
        guard shouldObserveNextUnconfirmedResult else { return }
        shouldObserveNextUnconfirmedResult = false
        send(sequence, as: .unconfirmed)
    }

    func pauseWrittenApplication(sequence: Int) {
        pausedApplicationSequences.insert(sequence)
    }

    func beforeApplyWrittenResult(sequence: Int) async {
        guard pausedApplicationSequences.remove(sequence) != nil else { return }
        send(sequence, as: .applicationPaused)
        await withCheckedContinuation { continuation in
            pausedApplicationContinuations[sequence] = continuation
        }
    }

    func observeAppliedResult(sequence: Int) {
        observedAppliedSequences.insert(sequence)
    }

    func didApplyWrittenResult(sequence: Int) {
        guard observedAppliedSequences.remove(sequence) != nil else { return }
        send(sequence, as: .applied)
    }

    func waitForWritePause() async -> Int {
        await waitFor(.writePaused)
    }

    func waitForCoalescedRequest() async -> Int {
        await waitFor(.coalesced)
    }

    func waitForUnconfirmedResult() async -> Int {
        await waitFor(.unconfirmed)
    }

    func waitForApplicationPause() async -> Int {
        await waitFor(.applicationPaused)
    }

    func waitForAppliedResult() async -> Int {
        await waitFor(.applied)
    }

    func releaseWrite(sequence: Int) {
        pausedWriteContinuations.removeValue(forKey: sequence)?.resume()
    }

    func releaseApplication(sequence: Int) {
        pausedApplicationContinuations.removeValue(forKey: sequence)?.resume()
    }

    private func waitFor(_ event: Event) async -> Int {
        if var buffered = bufferedEvents[event], !buffered.isEmpty {
            let sequence = buffered.removeFirst()
            bufferedEvents[event] = buffered
            return sequence
        }

        return await withCheckedContinuation { continuation in
            eventWaiters[event, default: []].append(continuation)
        }
    }

    private func send(_ sequence: Int, as event: Event) {
        if var waiters = eventWaiters[event], !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            eventWaiters[event] = waiters
            waiter.resume(returning: sequence)
        } else {
            bufferedEvents[event, default: []].append(sequence)
        }
    }
}

final class AppStatePersistenceTests: XCTestCase {
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
    private func makeRecoveryTelemetry(
        enabled: Bool = true
    ) -> (coordinator: RollCallTelemetryCoordinator, provider: RecordingTelemetryProvider) {
        let provider = RecordingTelemetryProvider()
        let store = TelemetryStore(
            url: temp.fileURL("recovery-telemetry-state.json"),
            now: RollCallTestFixtures.now
        )
        let suiteName = "RollCallRecoveryTelemetryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preference = AnonymousUsageAnalyticsPreference(defaults: defaults)
        preference.persist(enabled)
        let coordinator = RollCallTelemetryCoordinator(
            provider: provider,
            store: store,
            preference: preference,
            buildContext: TelemetryBuildContext(
                isAppStoreBuild: false,
                isTestFlightBuild: false,
                isDeveloperBuild: true,
                isSwiftUIPreview: false
            )
        )
        return (coordinator, provider)
    }

    private func recoveryReasons(from provider: RecordingTelemetryProvider) -> [String] {
        provider.signals
            .filter { $0.event == .stateRecoveryTriggered }
            .compactMap { $0.properties[RollCallTelemetryProperty.reason.rawValue] }
    }

    func testRecoveryListFormatterFormatsEveryCountAndPreservesOrder() {
        let cases: [([String], String)] = [
            ([], ""),
            (["photo"], "photo"),
            (["photo", "song"], "photo and song"),
            (["photo", "full photo source", "song"], "photo, full photo source, and song"),
            (["photo", "full photo source", "Announcement Cue", "song"], "photo, full photo source, Announcement Cue, and song")
        ]
        let locale = Locale(identifier: "en_US")

        for (items, expected) in cases {
            XCTAssertEqual(
                RecoveryListFormatter.localizedList(items, locale: locale),
                expected,
                "Unexpected list formatting for \(items)."
            )
        }
    }

    func testPersistenceFailureTelemetryOnlyReflectsLatestRequestedSnapshot() {
        XCTAssertFalse(StatePersistenceFailureSemantics.shouldReportFailure(
            failedSequence: 4,
            latestRequestedSequence: 5
        ))
        XCTAssertTrue(StatePersistenceFailureSemantics.shouldReportFailure(
            failedSequence: 5,
            latestRequestedSequence: 5
        ))
    }

    @MainActor
    func testCoalescedAssetCleanupWaitsForLatestDurableState() async throws {
        let playerID = UUID()
        let announcementPath = "custom-intro-\(playerID.uuidString.lowercased()).caf"
        let photoPath = "\(UUID().uuidString).jpg"
        var player = RollCallTestFixtures.player(
            id: playerID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.customAnnouncerRelativePath = announcementPath
        player.photoRelativePath = photoPath
        try writeAsset(announcementPath)
        try writeAsset(photoPath)

        var team = RollCallTestFixtures.team(players: [player])
        team.id = UUID()
        try writeState(RollCallTestFixtures.appState(
            teams: [team],
            selectedTeamID: team.id
        ))

        let interleaving = ControlledPersistenceInterleaving()
        let hooks = StatePersistenceTestHooks(
            beforeWrite: { sequence in await interleaving.beforeWrite(sequence: sequence) },
            didCoalesce: { sequence in await interleaving.didCoalesce(sequence: sequence) },
            didReturnUnconfirmed: { sequence in await interleaving.didReturnUnconfirmed(sequence: sequence) },
            beforeApplyWrittenResult: { sequence in await interleaving.beforeApplyWrittenResult(sequence: sequence) },
            didApplyWrittenResult: { sequence in await interleaving.didApplyWrittenResult(sequence: sequence) }
        )
        let model = AppModel(persistenceTestHooks: hooks)
        let initialFlushSucceeded = await model.flushLatestState()
        XCTAssertTrue(initialFlushSucceeded)

        await interleaving.pauseNextWrite()
        await interleaving.observeNextCoalescedRequest()
        var afterA = try XCTUnwrap(model.state.teams.first?.players.first)
        afterA.customAnnouncerRelativePath = nil
        model.updatePlayer(afterA)
        let sequenceA = await interleaving.waitForWritePause()

        await interleaving.observeNextUnconfirmedResult()
        var afterB = try XCTUnwrap(model.state.teams.first?.players.first)
        afterB.customAnnouncerRelativePath = announcementPath
        afterB.photoRelativePath = nil
        model.updatePlayer(afterB)
        let sequenceB = await interleaving.waitForCoalescedRequest()
        let unconfirmedSequenceB = await interleaving.waitForUnconfirmedResult()
        XCTAssertEqual(unconfirmedSequenceB, sequenceB)
        XCTAssertGreaterThan(sequenceB, sequenceA)

        await interleaving.pauseWrittenApplication(sequence: sequenceB)
        await interleaving.releaseWrite(sequence: sequenceA)
        let pausedApplicationSequenceB = await interleaving.waitForApplicationPause()
        XCTAssertEqual(pausedApplicationSequenceB, sequenceB)

        let durableStateB = try AppStatePersistenceCodec.decode(Data(contentsOf: AppPaths.stateURL()))
        let durablePlayerB = try XCTUnwrap(durableStateB.teams.first?.players.first)
        XCTAssertEqual(durablePlayerB.customAnnouncerRelativePath, announcementPath)
        XCTAssertNil(durablePlayerB.photoRelativePath)
        XCTAssertTrue(assetExists(announcementPath), "B durably references this path; A must not delete it.")
        XCTAssertTrue(assetExists(photoPath), "B's coalesced cleanup path waits for a confirmed state.")

        await interleaving.pauseNextWrite()
        var afterC = try XCTUnwrap(model.state.teams.first?.players.first)
        afterC.customAnnouncerRelativePath = nil
        model.updatePlayer(afterC)
        let sequenceC = await interleaving.waitForWritePause()
        XCTAssertGreaterThan(sequenceC, sequenceB)

        await interleaving.observeAppliedResult(sequence: sequenceB)
        await interleaving.releaseApplication(sequence: sequenceB)
        let appliedSequenceB = await interleaving.waitForAppliedResult()
        XCTAssertEqual(appliedSequenceB, sequenceB)

        let stillDurableStateB = try AppStatePersistenceCodec.decode(Data(contentsOf: AppPaths.stateURL()))
        let stillDurablePlayerB = try XCTUnwrap(stillDurableStateB.teams.first?.players.first)
        XCTAssertEqual(stillDurablePlayerB.customAnnouncerRelativePath, announcementPath)
        XCTAssertTrue(assetExists(announcementPath), "A stale B completion must not delete an asset referenced by durable B while C is pending.")
        XCTAssertTrue(assetExists(photoPath))

        await interleaving.observeAppliedResult(sequence: sequenceC)
        await interleaving.releaseWrite(sequence: sequenceC)
        let appliedSequenceC = await interleaving.waitForAppliedResult()
        XCTAssertEqual(appliedSequenceC, sequenceC)

        let durableStateC = try AppStatePersistenceCodec.decode(Data(contentsOf: AppPaths.stateURL()))
        let durablePlayerC = try XCTUnwrap(durableStateC.teams.first?.players.first)
        XCTAssertNil(durablePlayerC.customAnnouncerRelativePath)
        XCTAssertNil(durablePlayerC.photoRelativePath)
        XCTAssertFalse(assetExists(announcementPath))
        XCTAssertFalse(assetExists(photoPath), "B's path must not remain stranded after C confirms the cleanup set.")
    }

    @MainActor
    func testLatestCoalescedWriteDrainsItsCleanupPaths() async throws {
        let playerID = UUID()
        let announcementPath = "custom-intro-\(playerID.uuidString.lowercased()).caf"
        let photoPath = "\(UUID().uuidString).jpg"
        var player = RollCallTestFixtures.player(
            id: playerID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.customAnnouncerRelativePath = announcementPath
        player.photoRelativePath = photoPath
        try writeAsset(announcementPath)
        try writeAsset(photoPath)

        var team = RollCallTestFixtures.team(players: [player])
        team.id = UUID()
        try writeState(RollCallTestFixtures.appState(
            teams: [team],
            selectedTeamID: team.id
        ))

        let interleaving = ControlledPersistenceInterleaving()
        let hooks = StatePersistenceTestHooks(
            beforeWrite: { sequence in await interleaving.beforeWrite(sequence: sequence) },
            didCoalesce: { sequence in await interleaving.didCoalesce(sequence: sequence) },
            didApplyWrittenResult: { sequence in await interleaving.didApplyWrittenResult(sequence: sequence) }
        )
        let model = AppModel(persistenceTestHooks: hooks)
        let initialFlushSucceeded = await model.flushLatestState()
        XCTAssertTrue(initialFlushSucceeded)

        await interleaving.pauseNextWrite()
        await interleaving.observeNextCoalescedRequest()
        var afterA = try XCTUnwrap(model.state.teams.first?.players.first)
        afterA.customAnnouncerRelativePath = nil
        model.updatePlayer(afterA)
        let sequenceA = await interleaving.waitForWritePause()

        var afterB = try XCTUnwrap(model.state.teams.first?.players.first)
        afterB.customAnnouncerRelativePath = announcementPath
        afterB.photoRelativePath = nil
        model.updatePlayer(afterB)
        let sequenceB = await interleaving.waitForCoalescedRequest()
        XCTAssertGreaterThan(sequenceB, sequenceA)
        await interleaving.observeAppliedResult(sequence: sequenceB)

        await interleaving.releaseWrite(sequence: sequenceA)
        let appliedSequenceB = await interleaving.waitForAppliedResult()
        XCTAssertEqual(appliedSequenceB, sequenceB)

        let durableStateB = try AppStatePersistenceCodec.decode(Data(contentsOf: AppPaths.stateURL()))
        let durablePlayerB = try XCTUnwrap(durableStateB.teams.first?.players.first)
        XCTAssertEqual(durablePlayerB.customAnnouncerRelativePath, announcementPath)
        XCTAssertNil(durablePlayerB.photoRelativePath)
        XCTAssertTrue(assetExists(announcementPath), "B's live reference must keep the reintroduced path.")
        XCTAssertFalse(assetExists(photoPath), "B's coalesced cleanup path must be drained by B's durable write.")
    }

    func testCurrentStateRoundTripPreservesPortableIntentAndDeviceQualification() throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.appleMusicCue(
                songID: "catalog.alex",
                title: "Thunder",
                artistName: "The Bats"
            )
        )
        player.songAssignment = .privateClip(
            SongClip(cue: player.cue!)
        )
        guard case .privateClip(var clip)? = player.songAssignment,
              case .appleMusic(var source) = clip.originalSource else {
            return XCTFail("Expected an Apple Music clip.")
        }
        source.libraryPersistentID = 42
        clip.originalSource = .appleMusic(source)
        player.songAssignment = .privateClip(clip)

        var state = RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [player]))
        state.deviceIdentity = DeviceIdentity(label: "Source iPhone", qualificationToken: "source-device")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoded = try AppStatePersistenceCodec.decode(try encoder.encode(state))

        XCTAssertEqual(decoded.schemaVersion, AppState.currentSchemaVersion)
        XCTAssertEqual(decoded.deviceIdentity.qualificationToken, "source-device")
        guard case .privateClip(let decodedClip)? = decoded.teams[0].players[0].songAssignment,
              case .appleMusic(let decodedSource) = decodedClip.originalSource else {
            return XCTFail("Expected the Apple Music selection to survive the round trip.")
        }
        XCTAssertEqual(decodedSource.songID, "catalog.alex")
        XCTAssertEqual(decodedSource.libraryPersistentID, 42)
    }

    func testSchemaTenMigratesSequentiallyToCurrentSchema() throws {
        var legacyState = RollCallTestFixtures.appState(team: RollCallTestFixtures.team())
        legacyState.schemaVersion = 10
        legacyState.lastGameDayTeamID = legacyState.selectedTeamID
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let migrated = try AppStatePersistenceCodec.decode(try encoder.encode(legacyState))

        XCTAssertEqual(migrated.schemaVersion, 11)
        XCTAssertEqual(migrated.lastGameDayTeamID, legacyState.lastGameDayTeamID)
        XCTAssertEqual(migrated.teams.first?.players.count, legacyState.teams.first?.players.count)
    }

    func testSchemaVersionOneIsAcceptedWhileBooleanAndOverflowAreRejected() throws {
        let numericOne = Data(#"{"schemaVersion":1}"#.utf8)
        let boolean = Data(#"{"schemaVersion":true}"#.utf8)
        let overflow = Data(#"{"schemaVersion":9223372036854775808}"#.utf8)

        XCTAssertEqual(try AppStatePersistenceCodec.schemaVersion(in: numericOne), 1)
        for invalidData in [boolean, overflow] {
            XCTAssertThrowsError(try AppStatePersistenceCodec.schemaVersion(in: invalidData)) { error in
                XCTAssertEqual(error as? AppStateMigrationError, .invalidSchemaVersion)
            }
        }
    }

    @MainActor
    func testMigrationFailurePreservesOriginalStateBytes() throws {
        let originalBytes = Data(#"{"schemaVersion":10,"deviceIdentity":"not-an-object","teams":[]}"#.utf8)
        try originalBytes.write(to: AppPaths.stateURL(), options: .atomic)

        let model = AppModel(deviceIdentityProvider: {
            DeviceIdentity(label: "Test Device", qualificationToken: "test-device")
        })

        XCTAssertEqual(model.stateRecovery?.reason, .loadFailure)
        XCTAssertEqual(try Data(contentsOf: AppPaths.stateURL()), originalBytes)
        XCTAssertNotNil(model.stateRecovery?.preservedStateURL)
    }

    @MainActor
    func testMalformedSchemaVersionPreservesOriginalStateBytes() throws {
        let originalBytes = Data(#"{"schemaVersion":true,"teams":[]}"#.utf8)
        try originalBytes.write(to: AppPaths.stateURL(), options: .atomic)

        let model = AppModel(deviceIdentityProvider: {
            DeviceIdentity(label: "Test Device", qualificationToken: "test-device")
        })

        XCTAssertEqual(model.stateRecovery?.reason, .loadFailure)
        XCTAssertEqual(try Data(contentsOf: AppPaths.stateURL()), originalBytes)
        XCTAssertNotNil(model.stateRecovery?.preservedStateURL)
    }

    @MainActor
    func testMissingStateWithoutResidualDataStartsFresh() {
        let model = AppModel(deviceIdentityProvider: {
            DeviceIdentity(label: "Fresh Device", qualificationToken: "fresh-device")
        })

        XCTAssertNil(model.stateRecovery)
        XCTAssertTrue(model.state.teams.isEmpty)
        XCTAssertEqual(model.state.deviceIdentity.qualificationToken, "fresh-device")
    }

    @MainActor
    func testMissingStateWithResidualAssetEntersRecoveryWithoutDeletingAsset() async throws {
        try writeAsset("orphan-photo.jpg")
        let telemetry = makeRecoveryTelemetry(enabled: false)

        let model = AppModel(telemetry: telemetry.coordinator, deviceIdentityProvider: {
            DeviceIdentity(label: "Restored Device", qualificationToken: "restored-device")
        })

        XCTAssertEqual(model.stateRecovery?.reason, .missingPrimaryWithResidualData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try AppPaths.stateURL().path))
        XCTAssertTrue(assetExists("orphan-photo.jpg"))
        XCTAssertTrue(recoveryReasons(from: telemetry.provider).isEmpty)

        await model.startFreshAfterStateRecovery()
        XCTAssertNil(model.stateRecovery)
        XCTAssertTrue(assetExists("orphan-photo.jpg"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try AppPaths.stateURL().path))
        XCTAssertTrue(recoveryReasons(from: telemetry.provider).isEmpty)
    }

    @MainActor
    func testMissingStateWithSnapshotOffersAndRestoresSnapshotRecovery() async throws {
        let snapshotState = RollCallTestFixtures.appState(team: RollCallTestFixtures.team())
        _ = try writeRecoverySnapshot(snapshotState, fileName: "orphan-snapshot.json")
        let telemetry = makeRecoveryTelemetry()

        let model = AppModel(telemetry: telemetry.coordinator, deviceIdentityProvider: {
            DeviceIdentity(label: "Restored Device", qualificationToken: "restored-device")
        })

        XCTAssertEqual(model.stateRecovery?.reason, .missingPrimaryWithResidualData)
        let snapshot = try XCTUnwrap(model.stateRecovery?.snapshots.first)
        XCTAssertEqual(model.stateRecovery?.snapshots.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try AppPaths.stateURL().path))
        XCTAssertTrue(recoveryReasons(from: telemetry.provider).isEmpty)

        await model.restoreStateRecoverySnapshot(snapshot)

        XCTAssertNil(model.stateRecovery)
        XCTAssertEqual(model.state.teams.first?.name, "Thunder")
        XCTAssertEqual(model.state.deviceIdentity.qualificationToken, "restored-device")
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshot.url.path))
        XCTAssertEqual(recoveryReasons(from: telemetry.provider), ["missingPrimaryWithResidualData"])

        await model.startFreshAfterStateRecovery()
        XCTAssertEqual(recoveryReasons(from: telemetry.provider), ["missingPrimaryWithResidualData"])
    }

    @MainActor
    func testConcurrentRecoveryChoiceIsRejectedUntilAdmittedRecoveryCompletes() async throws {
        let snapshotState = RollCallTestFixtures.appState(team: RollCallTestFixtures.team())
        _ = try writeRecoverySnapshot(snapshotState, fileName: "orphan-snapshot.json")
        let telemetry = makeRecoveryTelemetry()
        let interleaving = ControlledPersistenceInterleaving()
        let hooks = StatePersistenceTestHooks(
            beforeWrite: { sequence in await interleaving.beforeWrite(sequence: sequence) }
        )
        let model = AppModel(
            telemetry: telemetry.coordinator,
            persistenceTestHooks: hooks,
            deviceIdentityProvider: {
                DeviceIdentity(label: "Restored Device", qualificationToken: "restored-device")
            }
        )
        let snapshot = try XCTUnwrap(model.stateRecovery?.snapshots.first)

        await interleaving.pauseNextWrite()
        let admittedRecovery = Task { @MainActor in
            await model.restoreStateRecoverySnapshot(snapshot)
        }
        let pausedSequence = await interleaving.waitForWritePause()
        XCTAssertTrue(model.isStateRecoveryInProgress)
        XCTAssertTrue(recoveryReasons(from: telemetry.provider).isEmpty)

        var competingActionStarted = false
        var competingActionReturnedBeforeWrite = false
        let competingRecovery = Task { @MainActor in
            competingActionStarted = true
            await model.startFreshAfterStateRecovery()
            competingActionReturnedBeforeWrite = true
        }
        for _ in 0..<100 where !competingActionStarted {
            await Task.yield()
        }
        for _ in 0..<100 where !competingActionReturnedBeforeWrite {
            await Task.yield()
        }
        let competingActionWasRejected = competingActionStarted && competingActionReturnedBeforeWrite
        XCTAssertTrue(recoveryReasons(from: telemetry.provider).isEmpty)

        await interleaving.releaseWrite(sequence: pausedSequence)
        await admittedRecovery.value
        await competingRecovery.value

        XCTAssertTrue(competingActionWasRejected, "A second recovery choice must return without joining or replacing the active write.")
        XCTAssertFalse(model.isStateRecoveryInProgress)
        XCTAssertNil(model.stateRecovery)
        XCTAssertEqual(model.state.teams.map(\.name), ["Thunder"])
        let savedState = try AppStatePersistenceCodec.decode(Data(contentsOf: AppPaths.stateURL()))
        XCTAssertEqual(savedState.teams.map(\.name), ["Thunder"])
        XCTAssertEqual(recoveryReasons(from: telemetry.provider), ["missingPrimaryWithResidualData"])
    }

    func testConsistencyReportDistinguishesMissingAuthoritativeAndDerivedAssets() throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: RollCallTestFixtures.localCue(relativePath: "missing-song.m4a"),
            photoRelativePath: "missing-photo.jpg"
        )
        var clip = SongClip(cue: player.cue!)
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/missing-generated.m4a",
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: RollCallTestFixtures.now
        )
        player.songAssignment = .privateClip(clip)
        let report = AppStateConsistencyValidator.report(
            for: RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [player]))
        )

        XCTAssertEqual(report.missingPhotoPaths, ["missing-photo.jpg"])
        XCTAssertEqual(report.missingLocalAudioPaths, ["missing-song.m4a"])
        XCTAssertEqual(report.missingGeneratedClipPaths, ["GeneratedClips/missing-generated.m4a"])
        XCTAssertTrue(report.hasIssues)
    }

    func testInvalidAppleMusicLibraryHintDoesNotMatchDifferentCatalogSong() {
        let source = AppleMusicSource(
            songID: "catalog.correct",
            title: "Correct Song",
            artistName: "The Bats",
            duration: 180,
            previewURL: nil,
            isCatalogBacked: true,
            libraryPersistentID: 123
        )

        XCTAssertFalse(AppleMusicLibraryResolution.matches(source: source, playbackStoreID: "catalog.other"))
        XCTAssertTrue(AppleMusicLibraryResolution.matches(source: source, playbackStoreID: "catalog.correct"))
    }

    @MainActor
    func testDeviceIdentityIsRequalifiedAfterRestoration() throws {
        let cue = RollCallTestFixtures.appleMusicCue(
            songID: "catalog.alex",
            title: "Alex Walkup",
            artistName: "The Bats"
        )
        guard case .appleMusic(var source) = cue.source else {
            return XCTFail("Expected Apple Music fixture.")
        }
        source.libraryPersistentID = 42
        var appleMusicCue = cue
        appleMusicCue.source = .appleMusic(source)
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: appleMusicCue
        )
        var clip = SongClip(cue: appleMusicCue)
        clip.readinessInputs = SongClipReadinessInputs(
            playback: .sourceBackedDownloaded,
            sourceAvailableOnDevice: true,
            downloadedOnDevice: true
        )
        player.songAssignment = .privateClip(clip)
        var state = RollCallTestFixtures.appState(team: RollCallTestFixtures.team(players: [player]))
        state.deviceIdentity = DeviceIdentity(label: "Old iPhone", qualificationToken: "old-device")
        try writeState(state)

        let model = AppModel(deviceIdentityProvider: {
            DeviceIdentity(label: "New iPhone", qualificationToken: "new-device")
        })

        XCTAssertEqual(model.state.deviceIdentity.label, "New iPhone")
        XCTAssertEqual(model.state.deviceIdentity.qualificationToken, "new-device")
        XCTAssertEqual(model.selectedTeam?.name, "Thunder")
        guard case .privateClip(let restoredClip)? = model.selectedTeam?.players.first?.songAssignment else {
            return XCTFail("Expected the Apple Music clip to remain assigned.")
        }
        XCTAssertEqual(restoredClip.readinessInputs.playback, .needsAppleMusic)
        XCTAssertFalse(restoredClip.readinessInputs.sourceAvailableOnDevice)
        XCTAssertFalse(restoredClip.readinessInputs.downloadedOnDevice)
    }

    @MainActor
    func testLaunchDoesNotTrustPersistedReadinessAndFlushesLatestRapidMutation() async throws {
        var state = RollCallTestFixtures.appState(team: RollCallTestFixtures.team())
        state.lastReadiness = ReadinessStatus(
            generatedAt: RollCallTestFixtures.now,
            checks: [],
            teamID: state.selectedTeamID
        )
        try writeState(state)
        let model = AppModel()
        XCTAssertNil(model.state.lastReadiness)

        for index in 0..<8 {
            model.renameSelectedTeam(to: "Thunder \(index)")
        }
        let flushed = await model.flushLatestState()
        XCTAssertTrue(flushed)
        let saved = try AppStatePersistenceCodec.decode(Data(contentsOf: AppPaths.stateURL()))
        XCTAssertEqual(saved.teams.first?.name, "Thunder 7")
    }

    @MainActor
    func testUnreadableStateRemainsUntouchedUntilRecoveryChoice() async throws {
        let originalBytes = Data("not-json".utf8)
        try originalBytes.write(to: AppPaths.stateURL(), options: .atomic)
        let telemetry = makeRecoveryTelemetry()

        let model = AppModel(telemetry: telemetry.coordinator)

        let recovery = try XCTUnwrap(model.stateRecovery)
        XCTAssertTrue(model.requiresStateRecoveryDecision)
        XCTAssertEqual(try Data(contentsOf: AppPaths.stateURL()), originalBytes)
        let preservedStateURL = try XCTUnwrap(recovery.preservedStateURL)
        XCTAssertEqual(try Data(contentsOf: preservedStateURL), originalBytes)
        XCTAssertTrue(recoveryReasons(from: telemetry.provider).isEmpty)

        await model.flushLatestState()
        XCTAssertEqual(try Data(contentsOf: AppPaths.stateURL()), originalBytes)

        await model.startFreshAfterStateRecovery()
        await model.flushLatestState()

        XCTAssertFalse(model.requiresStateRecoveryDecision)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertTrue(try decoder.decode(AppState.self, from: Data(contentsOf: AppPaths.stateURL())).teams.isEmpty)
        XCTAssertEqual(try Data(contentsOf: preservedStateURL), originalBytes)
        XCTAssertEqual(recoveryReasons(from: telemetry.provider), ["loadFailure"])
    }

    @MainActor
    func testFutureSchemaStateRemainsUntouchedAndOffersRecovery() async throws {
        var futureState = RollCallTestFixtures.appState(team: RollCallTestFixtures.team())
        futureState.schemaVersion = AppState.currentSchemaVersion + 1
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let originalBytes = try encoder.encode(futureState)
        try originalBytes.write(to: AppPaths.stateURL(), options: .atomic)
        let telemetry = makeRecoveryTelemetry()

        let model = AppModel(telemetry: telemetry.coordinator)

        let recovery = try XCTUnwrap(model.stateRecovery)
        XCTAssertEqual(recovery.reason, .unsupportedSchema)
        XCTAssertEqual(try Data(contentsOf: AppPaths.stateURL()), originalBytes)
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(recovery.preservedStateURL)), originalBytes)
        XCTAssertTrue(model.state.teams.isEmpty)
        XCTAssertTrue(recoveryReasons(from: telemetry.provider).isEmpty)

        await model.startFreshAfterStateRecovery()
        XCTAssertNil(model.stateRecovery)
        XCTAssertEqual(recoveryReasons(from: telemetry.provider), ["unsupportedSchema"])
    }

    @MainActor
    func testValidLegacyStateStillLoadsAndCanBePersisted() async throws {
        // This fixture follows the state shape written by the first shipping
        // release, v1.0-build53 (AppState schema 5). In particular, it uses
        // Player.cue rather than the later SongAssignment representation.
        let legacyStateData = Data(
            #"""
            {
              "schemaVersion": 5,
              "appVersion": "1.0.0",
              "deviceIdentity": { "label": "Test iPhone" },
              "selectedTeamID": "11111111-1111-1111-1111-111111111111",
              "teams": [
                {
                  "id": "11111111-1111-1111-1111-111111111111",
                  "name": "Thunder",
                  "createdAt": "2023-11-14T22:13:20Z",
                  "modifiedAt": "2023-11-14T22:13:20Z",
                  "players": [
                    {
                      "id": "22222222-2222-2222-2222-222222222222",
                      "displayName": "Alex Ramirez",
                      "uniformNumber": "12",
                      "pronunciationOverride": "ah-leks",
                      "photoRelativePath": "alex-profile.jpg",
                      "cue": {
                        "id": "55555555-5555-5555-5555-555555555555",
                        "label": "Alex Walk-up",
                        "source": {
                          "type": "localAudio",
                          "localAudio": {
                            "id": "66666666-6666-6666-6666-666666666666",
                            "displayName": "Alex Walk-up",
                            "relativePath": "alex-walkup.m4a",
                            "duration": 8,
                            "importedAt": "2023-11-14T22:13:20Z",
                            "hiddenOriginNote": {
                              "importedAt": "2023-11-14T22:13:20Z",
                              "originSummary": "original-file"
                            }
                          }
                        },
                        "startTime": 0,
                        "duration": 8,
                        "fadeOutDuration": 1,
                        "pauseAfterAnnouncer": 0.2
                      },
                      "isPresent": true,
                      "customAnnouncerRelativePath": "alex-announcement.caf"
                    },
                    {
                      "id": "33333333-3333-3333-3333-333333333333",
                      "displayName": "Jordan Lee",
                      "uniformNumber": "4",
                      "pronunciationOverride": "",
                      "cue": {
                        "id": "77777777-7777-7777-7777-777777777777",
                        "label": "Jordan Walk-up",
                        "source": {
                          "type": "appleMusic",
                          "appleMusic": {
                            "songID": "catalog.jordan-legacy",
                            "title": "Jump Around",
                            "artistName": "House of Pain",
                            "duration": 180
                          }
                        },
                        "startTime": 0,
                        "duration": 8,
                        "fadeOutDuration": 1,
                        "pauseAfterAnnouncer": 0.2
                      },
                      "isPresent": true
                    }
                  ],
                  "builtInClips": [],
                  "session": {
                    "activeSessionDate": "2023-11-14T22:13:20Z",
                    "battingOrder": [
                      "33333333-3333-3333-3333-333333333333",
                      "22222222-2222-2222-2222-222222222222"
                    ],
                    "nextBatterIndex": 1,
                    "gameDayAnnouncerMode": "songOnly",
                    "battingOrderIsCustomized": true
                  },
                  "announcerProfile": {
                    "phraseTemplate": "Now batting, number <number>, <name>",
                    "voiceLanguageCode": "en-US",
                    "rate": 0.46,
                    "pitchMultiplier": 1,
                    "volume": 1
                  },
                  "accentPreset": "blue"
                }
              ],
              "snapshots": [],
              "experimental": {
                "showExperimentalFeatures": true,
                "unlockPremiumForTesting": false,
                "appleMusicLocalCopyEnabled": false,
                "appleMusicTeamPlaylistSyncEnabled": true
              },
              "settings": {
                "hapticsEnabled": false,
                "fadeOutVolumeAutomationEnabled": true,
                "alwaysUseDarkLiveMode": false
              },
              "recentAppleMusicSelections": [],
              "trimDefaults": { "preferredLength": 8 },
              "onboarding": {
                "completedAt": "2023-11-14T22:13:20Z",
                "didChooseCheerFallback": true,
                "didSeeLineup": true
              }
            }
            """#.utf8
        )
        try writeAsset("alex-profile.jpg")
        try writeAsset("alex-walkup.m4a")
        try writeAsset("alex-announcement.caf")
        try legacyStateData.write(to: AppPaths.stateURL(), options: .atomic)

        let model = AppModel()

        XCTAssertNil(model.stateRecovery)
        try assertShippingSchemaFiveMeaningfulFields(in: model.state)

        let flushSucceeded = await model.flushLatestState()
        XCTAssertTrue(flushSucceeded)
        let savedState = try AppStatePersistenceCodec.decode(Data(contentsOf: AppPaths.stateURL()))
        try assertShippingSchemaFiveMeaningfulFields(in: savedState)
        XCTAssertEqual(savedState.teams, model.state.teams)
    }

    private func assertShippingSchemaFiveMeaningfulFields(
        in state: AppState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let legacyDate = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(state.schemaVersion, AppState.currentSchemaVersion, file: file, line: line)
        XCTAssertEqual(state.selectedTeamID, RollCallTestFixtures.teamID, file: file, line: line)
        XCTAssertNil(state.lastGameDayTeamID, file: file, line: line)
        XCTAssertTrue(state.recentlyDeleted.isEmpty, file: file, line: line)
        XCTAssertEqual(state.ratingRequest, .default, file: file, line: line)
        XCTAssertTrue(state.onboarding.isComplete, file: file, line: line)
        XCTAssertTrue(state.onboarding.didChooseCheerFallback, file: file, line: line)
        XCTAssertTrue(state.onboarding.didSeeLineup, file: file, line: line)
        XCTAssertTrue(state.experimental.showExperimentalFeatures, file: file, line: line)
        XCTAssertTrue(state.experimental.appleMusicTeamPlaylistSyncEnabled, file: file, line: line)
        XCTAssertFalse(state.settings.hapticsEnabled, file: file, line: line)
        XCTAssertTrue(state.settings.fadeOutVolumeAutomationEnabled, file: file, line: line)
        XCTAssertFalse(state.settings.alwaysUseDarkLiveMode, file: file, line: line)
        XCTAssertEqual(state.trimDefaults.preferredLength, 12, file: file, line: line)
        XCTAssertTrue(state.trimDefaults.hasAppliedTwelveSecondDefaultReset, file: file, line: line)

        let team = try XCTUnwrap(state.teams.first, file: file, line: line)
        XCTAssertEqual(team.id, RollCallTestFixtures.teamID, file: file, line: line)
        XCTAssertEqual(team.name, "Thunder", file: file, line: line)
        XCTAssertEqual(team.accentPreset, .blue, file: file, line: line)
        XCTAssertNil(team.customColor, file: file, line: line)
        XCTAssertTrue(team.teamClips.isEmpty, file: file, line: line)
        XCTAssertEqual(team.session.activeSessionDate, legacyDate, file: file, line: line)
        XCTAssertEqual(team.session.battingOrder, [RollCallTestFixtures.jordanID, RollCallTestFixtures.alexID], file: file, line: line)
        XCTAssertEqual(team.session.nextBatterIndex, 1, file: file, line: line)
        XCTAssertEqual(team.session.gameDayAnnouncerMode, .songOnly, file: file, line: line)
        XCTAssertTrue(team.session.battingOrderIsCustomized, file: file, line: line)
        XCTAssertEqual(team.players.map(\.id), [RollCallTestFixtures.alexID, RollCallTestFixtures.jordanID], file: file, line: line)

        let alex = try XCTUnwrap(team.players.first, file: file, line: line)
        XCTAssertEqual(alex.displayName, "Alex Ramirez", file: file, line: line)
        XCTAssertEqual(alex.uniformNumber, "12", file: file, line: line)
        XCTAssertEqual(alex.pronunciationOverride, "ah-leks", file: file, line: line)
        XCTAssertTrue(alex.isPresent, file: file, line: line)
        XCTAssertEqual(alex.photoRelativePath, "alex-profile.jpg", file: file, line: line)
        XCTAssertNil(alex.photoSourceRelativePath, file: file, line: line)
        XCTAssertNil(alex.profilePhotoCrop, file: file, line: line)
        XCTAssertNil(alex.playerCardPhotoCrop, file: file, line: line)
        XCTAssertNil(alex.playerCardDesignID, file: file, line: line)
        XCTAssertEqual(alex.customAnnouncerRelativePath, "alex-announcement.caf", file: file, line: line)
        guard case .privateClip(let localClip)? = alex.songAssignment,
              case .localAudio(let localSource) = localClip.originalSource else {
            XCTFail("The legacy local audio cue should migrate to a private clip.", file: file, line: line)
            return
        }
        XCTAssertEqual(localClip.id, RollCallTestFixtures.localCueID, file: file, line: line)
        XCTAssertEqual(localClip.displayName, "Alex Walk-up", file: file, line: line)
        XCTAssertEqual(localClip.requestedSelection, SongClipSelection(startTime: 0, duration: 8, fadeOutDuration: 1), file: file, line: line)
        XCTAssertEqual(localClip.pauseAfterAnnouncer, 0.2, file: file, line: line)
        XCTAssertEqual(localSource.id, RollCallTestFixtures.localSourceID, file: file, line: line)
        XCTAssertEqual(localSource.displayName, "Alex Walk-up", file: file, line: line)
        XCTAssertEqual(localSource.relativePath, "alex-walkup.m4a", file: file, line: line)
        XCTAssertEqual(localSource.duration, 8, file: file, line: line)
        XCTAssertEqual(localSource.importedAt, legacyDate, file: file, line: line)
        XCTAssertEqual(localSource.hiddenOriginNote?.importedAt, legacyDate, file: file, line: line)
        XCTAssertEqual(localSource.hiddenOriginNote?.originSummary, "original-file", file: file, line: line)

        let jordan = try XCTUnwrap(team.players.last, file: file, line: line)
        XCTAssertEqual(jordan.displayName, "Jordan Lee", file: file, line: line)
        XCTAssertEqual(jordan.uniformNumber, "4", file: file, line: line)
        XCTAssertTrue(jordan.isPresent, file: file, line: line)
        XCTAssertNil(jordan.photoRelativePath, file: file, line: line)
        guard case .privateClip(let musicClip)? = jordan.songAssignment,
              case .appleMusic(let musicSource) = musicClip.originalSource else {
            XCTFail("The legacy Apple Music cue should migrate to a private clip.", file: file, line: line)
            return
        }
        XCTAssertEqual(musicClip.id, UUID(uuidString: "77777777-7777-7777-7777-777777777777"), file: file, line: line)
        XCTAssertEqual(musicClip.displayName, "Jordan Walk-up", file: file, line: line)
        XCTAssertEqual(musicClip.requestedSelection, SongClipSelection(startTime: 0, duration: 8, fadeOutDuration: 1), file: file, line: line)
        XCTAssertEqual(musicClip.pauseAfterAnnouncer, 0.2, file: file, line: line)
        XCTAssertEqual(musicSource.songID, "catalog.jordan-legacy", file: file, line: line)
        XCTAssertEqual(musicSource.title, "Jump Around", file: file, line: line)
        XCTAssertEqual(musicSource.artistName, "House of Pain", file: file, line: line)
        XCTAssertEqual(musicSource.duration, 180, file: file, line: line)

        XCTAssertFalse(AppStateConsistencyValidator.report(for: state).hasIssues, file: file, line: line)
    }

    @MainActor
    func testUnreadableStateCanDiscoverAndRestoreIndependentSnapshot() async throws {
        let originalBytes = Data("not-json".utf8)
        try originalBytes.write(to: AppPaths.stateURL(), options: .atomic)
        let snapshotState = RollCallTestFixtures.appState(team: RollCallTestFixtures.team())
        let snapshotURL = try writeRecoverySnapshot(snapshotState, fileName: "orphan-snapshot.json")

        let model = AppModel()

        let recovery = try XCTUnwrap(model.stateRecovery)
        let snapshot = try XCTUnwrap(recovery.snapshots.first(where: { $0.url == snapshotURL }))
        await model.restoreStateRecoverySnapshot(snapshot)
        await model.flushLatestState()

        XCTAssertFalse(model.requiresStateRecoveryDecision)
        XCTAssertEqual(model.state.teams.first?.name, snapshotState.teams.first?.name)
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(recovery.preservedStateURL)), originalBytes)
    }

    func testWhatsNewReleaseIdentityStaysWithinMajorMinorFamily() {
        XCTAssertEqual(AppMetadata.releaseFamily(for: "1.2.1"), "1.2")
        XCTAssertTrue(AppMetadata.hasSeenWhatsNewRelease("1.2 (76)", for: "1.2.1"))
        XCTAssertTrue(AppMetadata.hasSeenWhatsNewRelease("1.2.1 (77)", for: "1.2.2"))
        XCTAssertFalse(AppMetadata.hasSeenWhatsNewRelease("1.1 (73)", for: "1.2.1"))
        XCTAssertFalse(AppMetadata.hasSeenWhatsNewRelease(nil, for: "1.2.1"))
    }

    func testDefaultTrimLengthIsTwelveSeconds() throws {
        XCTAssertEqual(AppState.empty.trimDefaults.preferredLength, 12)

        let json = """
        {
          "schemaVersion": 8,
          "appVersion": "1.2",
          "deviceIdentity": { "label": "This iPhone" },
          "selectedTeamID": null,
          "teams": [],
          "recentlyDeleted": [],
          "snapshots": [],
          "experimental": {},
          "settings": {},
          "recentAppleMusicSelections": []
        }
        """

        let decoded = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.trimDefaults.preferredLength, 12)
        XCTAssertTrue(decoded.trimDefaults.hasAppliedTwelveSecondDefaultReset)
        XCTAssertTrue(decoded.settings.explicitAppleMusicSearchFilteringEnabled)
    }

    func testSavedTrimLengthResetsToTwelveSecondsOnce() throws {
        let legacyJSON = #"{"preferredLength":8}"#
        let legacyDefaults = try JSONDecoder().decode(TrimDefaults.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(legacyDefaults.preferredLength, 12)
        XCTAssertTrue(legacyDefaults.hasAppliedTwelveSecondDefaultReset)

        let currentJSON = #"{"preferredLength":15,"hasAppliedTwelveSecondDefaultReset":true}"#
        let currentDefaults = try JSONDecoder().decode(TrimDefaults.self, from: Data(currentJSON.utf8))
        XCTAssertEqual(currentDefaults.preferredLength, 15)
        XCTAssertTrue(currentDefaults.hasAppliedTwelveSecondDefaultReset)
    }

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

    @MainActor
    func testViewingTeamDoesNotReplaceLastIntentionalGameDayTeam() throws {
        var viewedTeam = RollCallTestFixtures.team()
        viewedTeam.id = UUID()
        viewedTeam.name = "Viewed Team"
        var gameDayTeam = RollCallTestFixtures.team()
        gameDayTeam.id = UUID()
        gameDayTeam.name = "Game Day Team"
        var state = RollCallTestFixtures.appState(teams: [viewedTeam, gameDayTeam], selectedTeamID: gameDayTeam.id)
        state.lastGameDayTeamID = gameDayTeam.id
        try writeState(state)

        let model = AppModel()
        model.selectTeam(viewedTeam)

        XCTAssertEqual(model.state.selectedTeamID, viewedTeam.id)
        XCTAssertEqual(model.state.lastGameDayTeamID, gameDayTeam.id)
        model.recordIntentionalGameDayEntry()
        XCTAssertEqual(model.state.lastGameDayTeamID, viewedTeam.id)
    }

    @MainActor
    func testDeletingRememberedGameDayTeamClearsStaleTarget() throws {
        let team = RollCallTestFixtures.team()
        var state = RollCallTestFixtures.appState(team: team)
        state.lastGameDayTeamID = team.id
        try writeState(state)

        let model = AppModel()
        model.removeSelectedTeam()

        XCTAssertNil(model.state.lastGameDayTeamID)
    }

    @MainActor
    func testQuickGameDayExplicitTargetSelectsAndRemembersTeam() throws {
        var selected = RollCallTestFixtures.team()
        selected.id = UUID()
        var explicit = RollCallTestFixtures.team()
        explicit.id = UUID()
        let state = RollCallTestFixtures.appState(teams: [selected, explicit], selectedTeamID: selected.id)
        try writeState(state)
        let model = AppModel()

        let resolution = model.resolveOpenGameDay(
            OpenGameDayRequest(explicitTeamID: explicit.id, source: .appIntent)
        )

        XCTAssertEqual(resolution, .gameDay(teamID: explicit.id, targetKind: .explicitTeam))
        XCTAssertEqual(model.state.selectedTeamID, explicit.id)
        XCTAssertEqual(model.state.lastGameDayTeamID, explicit.id)
    }

    @MainActor
    func testQuickGameDayClearsMissingRememberedTarget() throws {
        let team = RollCallTestFixtures.team()
        var state = RollCallTestFixtures.appState(team: team)
        state.lastGameDayTeamID = UUID()
        try writeState(state)
        let model = AppModel()

        XCTAssertEqual(
            model.resolveOpenGameDay(OpenGameDayRequest(source: .systemControl)),
            .fallback(.rememberedTeamMissing)
        )
        XCTAssertNil(model.state.lastGameDayTeamID)
        XCTAssertEqual(model.state.selectedTeamID, team.id)
    }

    @MainActor
    func testPlayerEditorCommitPersistsBothPhotoFramings() throws {
        let team = RollCallTestFixtures.team()
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()
        var draft = try XCTUnwrap(model.selectedTeam?.players.first)
        draft.photoRelativePath = "profile.jpg"
        draft.photoSourceRelativePath = "master.jpg"
        draft.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.5)
        draft.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.75, height: 0.84)
        draft.playerCardDesign = .broadcast

        model.commitPlayerEditorDraft(draft)

        let saved = try XCTUnwrap(model.selectedTeam?.players.first)
        XCTAssertEqual(saved.photoRelativePath, "profile.jpg")
        XCTAssertEqual(saved.photoSourceRelativePath, "master.jpg")
        XCTAssertEqual(saved.profilePhotoCrop, draft.profilePhotoCrop)
        XCTAssertEqual(saved.playerCardPhotoCrop, draft.playerCardPhotoCrop)
        XCTAssertEqual(saved.playerCardDesign, .broadcast)
    }

    @MainActor
    func testRepeatedPhotoReplacementThenTeamDeletionPersistsLatestState() async throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            photoRelativePath: "profile-a.jpg"
        )
        player.photoSourceRelativePath = "master-a.jpg"
        var selectedTeam = RollCallTestFixtures.team(players: [player])
        selectedTeam.id = UUID()
        var remainingTeam = RollCallTestFixtures.team(players: [])
        remainingTeam.id = UUID()
        remainingTeam.name = "Lightning"
        try writeState(RollCallTestFixtures.appState(
            teams: [selectedTeam, remainingTeam],
            selectedTeamID: selectedTeam.id
        ))
        let model = AppModel()

        var draft = try XCTUnwrap(model.selectedTeam?.players.first)
        draft.photoRelativePath = "profile-b.jpg"
        draft.photoSourceRelativePath = "master-b.jpg"
        model.commitPlayerEditorDraft(draft)

        draft = try XCTUnwrap(model.selectedTeam?.players.first)
        draft.photoRelativePath = "profile-c.jpg"
        draft.photoSourceRelativePath = "master-c.jpg"
        model.commitPlayerEditorDraft(draft)

        model.state.selectedTeamID = remainingTeam.id
        model.removeTeam(id: selectedTeam.id)
        let deletionFlushSucceeded = await model.flushLatestState()
        XCTAssertTrue(deletionFlushSucceeded)

        XCTAssertFalse(model.state.teams.contains(where: { $0.id == selectedTeam.id }))
        XCTAssertEqual(model.state.selectedTeamID, remainingTeam.id)
        let liveDeletedTeam = try XCTUnwrap(model.state.recentlyDeleted.compactMap { item -> Team? in
            guard case .team(let record) = item.payload, record.team.id == selectedTeam.id else { return nil }
            return record.team
        }.first)
        XCTAssertEqual(liveDeletedTeam.players.first?.photoRelativePath, "profile-c.jpg")
        XCTAssertEqual(liveDeletedTeam.players.first?.photoSourceRelativePath, "master-c.jpg")

        let saved = try AppStatePersistenceCodec.decode(Data(contentsOf: AppPaths.stateURL()))
        XCTAssertFalse(saved.teams.contains(where: { $0.id == selectedTeam.id }))
        XCTAssertEqual(saved.selectedTeamID, remainingTeam.id)
        let savedDeletedTeam = try XCTUnwrap(saved.recentlyDeleted.compactMap { item -> Team? in
            guard case .team(let record) = item.payload, record.team.id == selectedTeam.id else { return nil }
            return record.team
        }.first)
        XCTAssertEqual(savedDeletedTeam.players.first?.photoRelativePath, "profile-c.jpg")
        XCTAssertEqual(savedDeletedTeam.players.first?.photoSourceRelativePath, "master-c.jpg")
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

    @MainActor
    func testAppleMusicMetadataRefreshDoesNotOverwriteNewerSavedCue() async throws {
        var originalCue = RollCallTestFixtures.appleMusicCue(
            songID: "catalog.old",
            title: "Old Song",
            artistName: "Old Artist"
        )
        guard case .appleMusic(var originalSource) = originalCue.source else {
            return XCTFail("Expected an Apple Music source.")
        }
        originalSource.duration = nil
        originalCue.source = .appleMusic(originalSource)

        let originalPlayer = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: originalCue
        )
        try writeState(RollCallTestFixtures.appState(
            team: RollCallTestFixtures.team(players: [originalPlayer])
        ))

        let resolver = DeferredAppleMusicCatalogResolver()
        let model = AppModel(
            appleMusicPlaybackCapabilityResolver: { .fullSong },
            catalogBackedResultResolver: { result in
                try await resolver.resolve(result)
            }
        )
        let refreshTask = Task { @MainActor in
            await model.refreshAppleMusicCueMetadata(for: originalPlayer.id)
        }
        await resolver.waitForRequest()

        let replacementCue = RollCallTestFixtures.appleMusicCue(
            songID: "catalog.new",
            title: "New Song",
            artistName: "New Artist"
        )
        model.saveSongCue(replacementCue, to: originalPlayer.id)

        resolver.complete(with: MusicSearchResult(
            songID: "catalog.old",
            title: "Old Song Resolved",
            artistName: "Old Artist Resolved",
            duration: 210,
            previewURL: nil,
            isCatalogBacked: true
        ))

        let didRefresh = await refreshTask.value
        XCTAssertFalse(didRefresh)
        guard case .appleMusic(let currentSource)? = model.selectedTeam?.players.first?.cue?.source else {
            return XCTFail("Expected the replacement Apple Music cue to remain saved.")
        }
        XCTAssertEqual(currentSource.songID, "catalog.new")
        XCTAssertEqual(currentSource.title, "New Song")
        XCTAssertEqual(currentSource.artistName, "New Artist")
    }

    @MainActor
    func testAppleMusicMetadataRefreshPreservesPreparedClipState() async throws {
        let (originalPlayer, originalClip) = preparedAppleMusicPlayer()
        try writeState(RollCallTestFixtures.appState(
            team: RollCallTestFixtures.team(players: [originalPlayer])
        ))

        let resolver = DeferredAppleMusicCatalogResolver()
        let model = AppModel(
            appleMusicPlaybackCapabilityResolver: { .fullSong },
            catalogBackedResultResolver: { result in
                try await resolver.resolve(result)
            }
        )
        let refreshTask = Task { @MainActor in
            await model.refreshAppleMusicCueMetadata(for: originalPlayer.id)
        }
        await resolver.waitForRequest()

        resolver.complete(with: MusicSearchResult(
            songID: "catalog.prepared",
            title: "Resolved Song",
            artistName: "Resolved Artist",
            duration: 210,
            previewURL: nil,
            isCatalogBacked: true
        ))

        let didRefresh = await refreshTask.value
        XCTAssertTrue(didRefresh)
        let refreshedPlayer = try XCTUnwrap(
            model.selectedTeam?.players.first(where: { $0.id == originalPlayer.id })
        )
        let refreshedClip = try XCTUnwrap(refreshedPlayer.songAssignment?.privateClip)
        XCTAssertEqual(refreshedClip.id, originalClip.id)
        XCTAssertEqual(refreshedClip.displayName, originalClip.displayName)
        XCTAssertEqual(refreshedClip.requestedSelection, originalClip.requestedSelection)
        XCTAssertEqual(refreshedClip.pauseAfterAnnouncer, originalClip.pauseAfterAnnouncer)
        XCTAssertEqual(refreshedClip.generatedAsset, originalClip.generatedAsset)
        XCTAssertEqual(refreshedClip.readinessInputs, originalClip.readinessInputs)
        XCTAssertEqual(refreshedClip.portabilityInputs, originalClip.portabilityInputs)
        XCTAssertEqual(refreshedClip.retryMetadata, originalClip.retryMetadata)
        XCTAssertEqual(refreshedClip.policy, originalClip.policy)
        XCTAssertEqual(refreshedClip.sourceLineageClipID, originalClip.sourceLineageClipID)
        XCTAssertEqual(refreshedClip.generationKey, originalClip.generationKey)
        XCTAssertTrue(refreshedClip.hasCurrentGeneratedAsset)
        guard case .appleMusic(let source) = refreshedClip.originalSource else {
            return XCTFail("Expected the refreshed clip to remain Apple Music-backed.")
        }
        XCTAssertEqual(source.title, "Resolved Song")
        XCTAssertEqual(source.artistName, "Resolved Artist")
        XCTAssertEqual(source.duration, 210)
    }

    @MainActor
    func testAppleMusicMetadataRefreshRejectsGenerationKeyChangeWithoutMutatingClip() async throws {
        let (originalPlayer, originalClip) = preparedAppleMusicPlayer()
        try writeState(RollCallTestFixtures.appState(
            team: RollCallTestFixtures.team(players: [originalPlayer])
        ))

        let resolver = DeferredAppleMusicCatalogResolver()
        let model = AppModel(
            appleMusicPlaybackCapabilityResolver: { .fullSong },
            catalogBackedResultResolver: { result in
                try await resolver.resolve(result)
            }
        )
        let refreshTask = Task { @MainActor in
            await model.refreshAppleMusicCueMetadata(for: originalPlayer.id)
        }
        await resolver.waitForRequest()

        resolver.complete(with: MusicSearchResult(
            songID: "catalog.different",
            title: "Different Song",
            artistName: "Different Artist",
            duration: 210,
            previewURL: nil,
            isCatalogBacked: true
        ))

        let didRefresh = await refreshTask.value
        XCTAssertFalse(didRefresh)
        XCTAssertEqual(model.selectedTeam?.songClip(for: originalPlayer), originalClip)
    }

    @MainActor
    func testAppleMusicMetadataRefreshRejectsCompletionForReplacementWithSameSource() async throws {
        let (originalPlayer, originalClip) = preparedAppleMusicPlayer()
        try writeState(RollCallTestFixtures.appState(
            team: RollCallTestFixtures.team(players: [originalPlayer])
        ))

        let resolver = DeferredAppleMusicCatalogResolver()
        let model = AppModel(
            appleMusicPlaybackCapabilityResolver: { .fullSong },
            catalogBackedResultResolver: { result in
                try await resolver.resolve(result)
            }
        )
        let refreshTask = Task { @MainActor in
            await model.refreshAppleMusicCueMetadata(for: originalPlayer.id)
        }
        await resolver.waitForRequest()

        var replacementCue = originalClip.editingCue
        replacementCue.id = UUID()
        model.saveSongCue(replacementCue, to: originalPlayer.id)
        let replacementPlayer = try XCTUnwrap(
            model.selectedTeam?.players.first(where: { $0.id == originalPlayer.id })
        )
        let replacementClip = try XCTUnwrap(replacementPlayer.songAssignment?.privateClip)
        XCTAssertNotEqual(replacementClip.id, originalClip.id)

        resolver.complete(with: MusicSearchResult(
            songID: "catalog.prepared",
            title: "Resolved Song",
            artistName: "Resolved Artist",
            duration: 210,
            previewURL: nil,
            isCatalogBacked: true
        ))

        let didRefresh = await refreshTask.value
        XCTAssertFalse(didRefresh)
        let currentPlayer = try XCTUnwrap(
            model.selectedTeam?.players.first(where: { $0.id == originalPlayer.id })
        )
        XCTAssertEqual(currentPlayer.songAssignment?.privateClip, replacementClip)
    }

    @MainActor
    func testExplicitAppleMusicReplacementStillCreatesFreshClip() throws {
        let (originalPlayer, originalClip) = preparedAppleMusicPlayer()
        try writeState(RollCallTestFixtures.appState(
            team: RollCallTestFixtures.team(players: [originalPlayer])
        ))
        let model = AppModel()

        var replacementCue = RollCallTestFixtures.appleMusicCue(
            id: UUID(),
            songID: "catalog.replacement",
            title: "Replacement Song",
            artistName: "Replacement Artist"
        )
        guard case .appleMusic(var source) = replacementCue.source else {
            return XCTFail("Expected an Apple Music replacement source.")
        }
        source.duration = nil
        replacementCue.source = .appleMusic(source)
        model.saveSongCue(replacementCue, to: originalPlayer.id)

        let replacementPlayer = try XCTUnwrap(
            model.selectedTeam?.players.first(where: { $0.id == originalPlayer.id })
        )
        let replacementClip = try XCTUnwrap(replacementPlayer.songAssignment?.privateClip)
        XCTAssertNotEqual(replacementClip.id, originalClip.id)
        XCTAssertNil(replacementClip.generatedAsset.relativePath)
        XCTAssertEqual(replacementClip.generatedAsset.status, .none)
        XCTAssertEqual(replacementClip.readinessInputs.playback, .sourceBackedReady)
        XCTAssertEqual(replacementClip.portabilityInputs.portability, .sourceReferenceOnly)
        XCTAssertEqual(replacementClip.retryMetadata, .none)
        XCTAssertNil(replacementClip.sourceLineageClipID)
    }

    @MainActor
    func testAppleMusicPreviewIgnoresOlderResultWhenNewerPreviewFinishesFirst() async throws {
        try writeState(RollCallTestFixtures.appState())

        let resolver = ControlledAppleMusicResultResolver()
        let playback = RecordedPreviewPlayback()
        let model = AppModel(
            appleMusicPlaybackCapabilityResolver: { .fullSong },
            catalogBackedResultResolver: { result in
                try await resolver.resolve(result)
            },
            previewPlaybackResolver: { cue in
                await playback.play(cue)
            }
        )
        let first = MusicSearchResult(
            songID: "catalog.first",
            title: "First Song",
            artistName: "First Artist",
            duration: nil,
            previewURL: nil,
            isCatalogBacked: true
        )
        let second = MusicSearchResult(
            songID: "catalog.second",
            title: "Second Song",
            artistName: "Second Artist",
            duration: nil,
            previewURL: nil,
            isCatalogBacked: true
        )

        let firstTask = Task { @MainActor in
            await model.previewAppleMusicSearchResult(first)
        }
        let secondTask = Task { @MainActor in
            await model.previewAppleMusicSearchResult(second)
        }
        await resolver.waitForTwoRequests()

        resolver.complete(songID: second.songID, with: second)
        await secondTask.value
        XCTAssertEqual(playback.playedSongIDs, [second.songID])

        resolver.complete(songID: first.songID, with: first)
        await firstTask.value
        XCTAssertEqual(playback.playedSongIDs, [second.songID])
    }

    @MainActor
    /// `flushLatestState()` must have actually written by the time it returns. This
    /// was intermittently failing (~1 in 4 full-suite runs) because the flush raced
    /// the write against a one-second timeout and cancelled the write when the main
    /// actor was busy — dropping the save entirely rather than merely delaying it.
    /// The assertion is deliberately immediate, with no polling or retry: a flush
    /// that has returned must already be durable.
    func testFlushLatestStateWritesTheMostRecentSnapshot() async throws {
        let team = RollCallTestFixtures.team()
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()
        model.state.teams[0].name = "Updated Thunder"

        await model.flushLatestState()

        let data = try Data(contentsOf: AppPaths.stateURL())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedState = try decoder.decode(AppState.self, from: data)
        XCTAssertEqual(savedState.teams.first?.name, "Updated Thunder")
    }

    private func writeState(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)
    }

    private func writeRecoverySnapshot(_ state: AppState, fileName: String) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let url = try AppPaths.snapshotsDirectory().appendingPathComponent(fileName)
        try encoder.encode(state).write(to: url, options: .atomic)
        return url
    }

    private func writeAsset(_ relativePath: String) throws {
        try Data("test".utf8).write(to: AppPaths.assetURL(relativePath: relativePath), options: .atomic)
    }

    private func assetExists(_ relativePath: String) -> Bool {
        AppPaths.isUsableAssetFile(relativePath: relativePath)
    }

    private func preparedAppleMusicPlayer() -> (player: Player, clip: SongClip) {
        var cue = RollCallTestFixtures.appleMusicCue(
            id: UUID(),
            songID: "catalog.prepared",
            title: "Prepared Song",
            artistName: "Prepared Artist"
        )
        guard case .appleMusic(var source) = cue.source else {
            preconditionFailure("Expected an Apple Music source.")
        }
        source.duration = nil
        cue.source = .appleMusic(source)

        var clip = SongClip(cue: cue)
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: "GeneratedClips/prepared-song.m4a",
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
        clip.retryMetadata = SongClipRetryMetadata(
            attemptCount: 2,
            lastAttemptAt: RollCallTestFixtures.now,
            nextRetryAt: RollCallTestFixtures.now.addingTimeInterval(60),
            lastFailureCode: SongClipPreparationFailureCode.transientSystemFailure.rawValue
        )

        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12",
            cue: cue
        )
        player.songAssignment = .privateClip(clip)
        return (player, clip)
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

    func testPlayerDecodesExplicitlyNullSongAssignment() throws {
        var player = RollCallTestFixtures.player(
            id: RollCallTestFixtures.alexID,
            name: "Alex Ramirez",
            number: "12"
        )
        player.songAssignment = nil

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(player)) as? [String: Any]
        )
        object["songAssignment"] = NSNull()

        let decoded = try JSONDecoder().decode(
            Player.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.songAssignment)
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

    func testSongAssignmentRoundTripsPrivateClipAndPreservesUnresolvedLegacySharedPayload() throws {
        let privateAssignment = SongAssignment.privateClip(
            SongClip(cue: RollCallTestFixtures.localCue())
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        XCTAssertEqual(
            try decoder.decode(SongAssignment.self, from: encoder.encode(privateAssignment)),
            privateAssignment
        )

        let legacyPayload = """
        {"type":"sharedTeamClip","sharedTeamClipID":"\(UUID().uuidString)"}
        """
        let unresolved = try decoder.decode(
            SongAssignment.self,
            from: Data(legacyPayload.utf8)
        )
        guard case .unresolvedLegacySharedTeamClip(let sharedID) = unresolved else {
            return XCTFail("Expected unresolved legacy shared assignment.")
        }
        let encoded = try encoder.encode(unresolved)
        let encodedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertEqual(encodedObject["type"] as? String, "sharedTeamClip")
        XCTAssertEqual(encodedObject["sharedTeamClipID"] as? String, sharedID.uuidString)
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

    func testTeamCustomColorIsOptionalAndRoundTripsWithoutInterpretation() throws {
        var team = RollCallTestFixtures.team()
        team.accentPreset = .blue

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let nilColorData = try encoder.encode(team)
        var nilColorObject = try XCTUnwrap(JSONSerialization.jsonObject(with: nilColorData) as? [String: Any])
        XCTAssertNil(nilColorObject["customColor"])
        nilColorObject["futureTeamField"] = ["preserve": true]
        let oldTeamData = try JSONSerialization.data(withJSONObject: nilColorObject)
        let oldTeam = try decoder.decode(Team.self, from: oldTeamData)
        XCTAssertNil(oldTeam.customColor)
        XCTAssertEqual(oldTeam.accentPreset, .blue)

        team.customColor = TeamCustomColor(
            colorSpace: "sRGB",
            red: 0.123456,
            green: 0.654321,
            blue: 0.777777,
            alpha: 1.0
        )
        var decoded = try decoder.decode(Team.self, from: encoder.encode(team))
        XCTAssertEqual(decoded.customColor, team.customColor)
        XCTAssertEqual(decoded.accentPreset, .blue)

        decoded.name = "Renamed without replacing dormant color"
        XCTAssertEqual(decoded.customColor, team.customColor)
    }

    func testAppStatePersistencePreservesUnusualDormantTeamCustomColor() throws {
        var team = RollCallTestFixtures.team()
        team.accentPreset = .blue
        team.customColor = TeamCustomColor(
            colorSpace: "vendor:future-wide-gamut-v2",
            red: -0.25,
            green: 2.5,
            blue: 0.0000000000123456,
            alpha: 1.25
        )
        let state = RollCallTestFixtures.appState(team: team)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoded = try AppStatePersistenceCodec.decode(encoder.encode(state))

        XCTAssertEqual(decoded.schemaVersion, 11)
        XCTAssertEqual(decoded.teams.first?.customColor, team.customColor)
        XCTAssertEqual(decoded.teams.first?.accentPreset, .blue)
    }

    @MainActor
    func testTeamMutationsKeepDormantCustomColorAndUsePresetAccent() throws {
        var team = RollCallTestFixtures.team()
        team.accentPreset = .blue
        let customColor = TeamCustomColor(
            colorSpace: "sRGB",
            red: 0.123456,
            green: 0.654321,
            blue: 0.777777,
            alpha: 1.0
        )
        team.customColor = customColor
        try writeState(RollCallTestFixtures.appState(team: team))
        let model = AppModel()

        model.renameSelectedTeam(to: "Thunder Renamed")
        model.setAccentPreset(.green, for: team.id)

        XCTAssertEqual(model.selectedTeam?.name, "Thunder Renamed")
        XCTAssertEqual(model.selectedTeam?.customColor, customColor)
        XCTAssertEqual(model.selectedTeam?.accentPreset, .green)
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
            "appleMusicTeamPlaylistSyncEnabled": false
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
            "appleMusicTeamPlaylistSyncEnabled": false
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
            "appleMusicTeamPlaylistSyncEnabled": false
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

    func testRemovedBuiltInAnnouncerPayloadIsIgnoredWithoutLosingCue() throws {
        let json = """
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "displayName": "Alex Ramirez",
          "uniformNumber": "12",
          "pronunciationOverride": "",
          "cue": {
            "id": "55555555-5555-5555-5555-555555555555",
            "label": "Small Cheer",
            "source": {
              "type": "builtInClip",
              "builtInClip": { "id": "small-cheer", "displayName": "Small Cheer" }
            },
            "startTime": 0,
            "duration": 12,
            "announcer": {
              "isEnabled": true,
              "template": "nowBatting",
              "customPrefix": "",
              "generatedAssetRelativePath": "legacy-built-in.caf"
            }
          },
          "isPresent": true
        }
        """

        let decoded = try JSONDecoder().decode(Player.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.cue?.label, "Small Cheer")
    }

    func testLegacyPlaylistExperimentFieldsStillDecodeForCompatibility() throws {
        let json = """
        {
          "showExperimentalFeatures": true,
          "appleMusicTeamPlaylistSyncEnabled": true,
          "acknowledgedAt": "2026-01-01T00:00:00Z",
          "appleMusicTeamPlaylistAcknowledgedAt": "2026-01-02T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(ExperimentalSettings.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.showExperimentalFeatures)
        XCTAssertTrue(decoded.appleMusicTeamPlaylistSyncEnabled)
        XCTAssertNotNil(decoded.appleMusicTeamPlaylistAcknowledgedAt)
    }
}
