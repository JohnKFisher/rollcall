import XCTest
@testable import RollCall

final class QuickGameDayTests: XCTestCase {
    private var temporaryDirectory: RollCallTemporaryDirectory!

    override func setUpWithError() throws {
        temporaryDirectory = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temporaryDirectory.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temporaryDirectory = nil
    }

    @MainActor
    func testControlDestinationIntentQueuesSystemControlRequest() async throws {
        let center = OpenGameDayRequestCenter.shared
        if let pendingRequest = center.pendingRequest {
            center.consume(id: pendingRequest.id)
        }

        defer {
            if let pendingRequest = center.pendingRequest {
                center.consume(id: pendingRequest.id)
            }
        }

        _ = try await OpenGameDayFromControlIntent().perform()

        XCTAssertNil(center.pendingRequest?.explicitTeamID)
        XCTAssertEqual(center.pendingRequest?.source, .systemControl)
    }

    func testTelemetrySourceUsesOnlyReliablyKnownSystemPath() {
        XCTAssertEqual(QuickGameDayInvocationSource.appIntent.telemetryValue, "appIntent")
        XCTAssertEqual(QuickGameDayInvocationSource.systemControl.telemetryValue, "systemControl")
        XCTAssertEqual(QuickGameDayInvocationSource.unknownSystem.telemetryValue, "unknownSystem")
    }

    func testRememberedGameDayTeamWinsOverSelectedTeam() {
        var viewed = RollCallTestFixtures.team()
        viewed.id = UUID()
        viewed.name = "Viewed"
        var played = RollCallTestFixtures.team()
        played.id = UUID()
        played.name = "Played"
        let state = state(teams: [viewed, played], selected: viewed.id, remembered: played.id)

        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(source: .unknownSystem), in: state),
            .gameDay(teamID: played.id, targetKind: .rememberedTeam)
        )
    }

    func testExplicitTeamOverridesRememberedTeam() {
        var remembered = RollCallTestFixtures.team()
        remembered.id = UUID()
        remembered.name = "Remembered"
        var explicit = RollCallTestFixtures.team()
        explicit.id = UUID()
        explicit.name = "Explicit"
        let state = state(teams: [remembered, explicit], selected: remembered.id, remembered: remembered.id)

        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(explicitTeamID: explicit.id, source: .appIntent), in: state),
            .gameDay(teamID: explicit.id, targetKind: .explicitTeam)
        )
    }

    func testMissingRememberedTeamFallsBackWithoutChoosingAnotherTeam() {
        var existing = RollCallTestFixtures.team()
        existing.id = UUID()
        existing.name = "Existing"
        let state = state(teams: [existing], selected: existing.id, remembered: UUID())

        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(source: .unknownSystem), in: state),
            .fallback(.rememberedTeamMissing)
        )
    }

    func testNoRememberedTeamAndNoTeamsHaveDistinctExpectedFallbacks() {
        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(source: .unknownSystem), in: state(teams: [], selected: nil, remembered: nil)),
            .fallback(.noTeams)
        )
        let team = RollCallTestFixtures.team()
        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(source: .unknownSystem), in: state(teams: [team], selected: team.id, remembered: nil)),
            .fallback(.noRememberedTeam)
        )
    }

    func testDeletedExplicitTeamFallsBackEvenWhenRememberedTeamExists() {
        let remembered = RollCallTestFixtures.team()
        let state = state(teams: [remembered], selected: remembered.id, remembered: remembered.id)

        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(explicitTeamID: UUID(), source: .appIntent), in: state),
            .fallback(.explicitTeamMissing)
        )
    }

    @MainActor
    func testRememberedRequestDefersBehindManualSetupGuideThenReachesExactlyOnce() throws {
        var viewedTeam = RollCallTestFixtures.team()
        viewedTeam.id = UUID()
        var gameDayTeam = RollCallTestFixtures.team()
        gameDayTeam.id = UUID()
        var appState = RollCallTestFixtures.appState(
            teams: [viewedTeam, gameDayTeam],
            selectedTeamID: viewedTeam.id
        )
        appState.lastGameDayTeamID = gameDayTeam.id
        appState.onboarding = .manualChooser(completedAt: RollCallTestFixtures.now)
        let (model, provider) = try makeAppModel(with: appState)
        let center = OpenGameDayRequestCenter()
        let request = OpenGameDayRequest(source: .systemControl)
        center.submit(request)
        var navigationCount = 0

        XCTAssertEqual(
            process(center, model: model, onboardingIsPresented: true, onGameDay: {
                navigationCount += 1
                XCTAssertEqual(model.state.selectedTeamID, viewedTeam.id)
                XCTAssertEqual(center.pendingRequest, request)
                XCTAssertFalse(provider.signals.contains { $0.event == .quickGameDayReached })
            }, onFallback: { XCTFail("A valid remembered team should not fall back.") }),
            .deferred
        )
        XCTAssertEqual(center.pendingRequest, request)
        XCTAssertEqual(model.state.selectedTeamID, viewedTeam.id)
        XCTAssertEqual(navigationCount, 0)
        XCTAssertTrue(quickGameDayEvents(in: provider).isEmpty)

        model.dismissManualSetupGuide()
        XCTAssertFalse(model.shouldShowOnboarding)

        XCTAssertEqual(
            process(center, model: model, onboardingIsPresented: false, onGameDay: {
                navigationCount += 1
                XCTAssertEqual(model.state.selectedTeamID, gameDayTeam.id)
                XCTAssertEqual(center.pendingRequest, request)
                XCTAssertFalse(provider.signals.contains { $0.event == .quickGameDayReached })
            }, onFallback: { XCTFail("A valid remembered team should not fall back.") }),
            .gameDay(teamID: gameDayTeam.id)
        )
        XCTAssertEqual(model.state.selectedTeamID, gameDayTeam.id)
        XCTAssertNil(center.pendingRequest)
        XCTAssertEqual(navigationCount, 1)
        XCTAssertEqual(
            quickGameDayEvents(in: provider),
            [.quickGameDayInvoked, .quickGameDayTargetResolved, .quickGameDayReached]
        )

        XCTAssertEqual(
            process(center, model: model, onboardingIsPresented: false, onGameDay: {
                navigationCount += 1
            }, onFallback: { XCTFail("No second request should be processed.") }),
            .noPendingRequest
        )
        XCTAssertEqual(navigationCount, 1)
        XCTAssertEqual(quickGameDayEvents(in: provider).filter { $0 == .quickGameDayReached }.count, 1)
    }

    @MainActor
    func testExplicitRequestDefersBehindManualSetupGuideAndKeepsRequestedTeam() throws {
        var rememberedTeam = RollCallTestFixtures.team()
        rememberedTeam.id = UUID()
        var explicitTeam = RollCallTestFixtures.team()
        explicitTeam.id = UUID()
        var appState = RollCallTestFixtures.appState(
            teams: [rememberedTeam, explicitTeam],
            selectedTeamID: rememberedTeam.id
        )
        appState.lastGameDayTeamID = rememberedTeam.id
        appState.onboarding = .manualChooser(completedAt: RollCallTestFixtures.now)
        let (model, provider) = try makeAppModel(with: appState)
        let center = OpenGameDayRequestCenter()
        let request = OpenGameDayRequest(explicitTeamID: explicitTeam.id, source: .appIntent)
        center.submit(request)

        XCTAssertEqual(
            process(center, model: model, onboardingIsPresented: true, onGameDay: {
                XCTFail("Onboarding still owns the root.")
            }, onFallback: { XCTFail("A valid explicit team should not fall back.") }),
            .deferred
        )
        XCTAssertEqual(center.pendingRequest, request)
        XCTAssertEqual(model.state.selectedTeamID, rememberedTeam.id)
        XCTAssertFalse(provider.signals.contains { $0.event == .quickGameDayReached })

        model.dismissManualSetupGuide()
        XCTAssertEqual(
            process(center, model: model, onboardingIsPresented: false, onGameDay: {}, onFallback: {
                XCTFail("A valid explicit team should not fall back.")
            }),
            .gameDay(teamID: explicitTeam.id)
        )
        XCTAssertEqual(model.state.selectedTeamID, explicitTeam.id)
        XCTAssertNil(center.pendingRequest)
        XCTAssertEqual(quickGameDayEvents(in: provider).filter { $0 == .quickGameDayReached }.count, 1)
    }

    @MainActor
    func testOrdinaryUnblockedRequestRoutesAndConsumesOnce() throws {
        let team = RollCallTestFixtures.team()
        var appState = RollCallTestFixtures.appState(team: team)
        appState.lastGameDayTeamID = team.id
        let (model, provider) = try makeAppModel(with: appState)
        let center = OpenGameDayRequestCenter()
        center.submit(OpenGameDayRequest(source: .appIntent))
        var navigationCount = 0

        XCTAssertEqual(
            process(center, model: model, onboardingIsPresented: false, onGameDay: {
                navigationCount += 1
            }, onFallback: { XCTFail("The remembered team is valid.") }),
            .gameDay(teamID: team.id)
        )
        XCTAssertNil(center.pendingRequest)
        XCTAssertEqual(model.state.selectedTeamID, team.id)
        XCTAssertEqual(navigationCount, 1)
        XCTAssertEqual(quickGameDayEvents(in: provider).filter { $0 == .quickGameDayReached }.count, 1)
    }

    @MainActor
    func testRequiredFirstLaunchOnboardingIsNotBypassedByValidRequest() throws {
        var team = RollCallTestFixtures.team()
        team.players = []
        var appState = RollCallTestFixtures.appState(team: team)
        appState.lastGameDayTeamID = team.id
        appState.onboarding = .notStarted
        let (model, provider) = try makeAppModel(with: appState)
        XCTAssertTrue(model.shouldShowOnboarding)
        XCTAssertEqual(model.state.onboarding.activeFlow, .automatic)

        let center = OpenGameDayRequestCenter()
        let request = OpenGameDayRequest(source: .appIntent)
        center.submit(request)
        XCTAssertEqual(
            process(center, model: model, onboardingIsPresented: true, onGameDay: {
                XCTFail("Required setup must retain the root.")
            }, onFallback: {
                XCTFail("The team resolves, but required onboarding still owns the root.")
            }),
            .deferred
        )
        XCTAssertEqual(center.pendingRequest, request)
        XCTAssertTrue(model.shouldShowOnboarding)
        XCTAssertEqual(model.state.selectedTeamID, team.id)
        XCTAssertFalse(provider.signals.contains { $0.event == .quickGameDayReached })
    }

    @MainActor
    func testNoTeamFallbackKeepsRequiredOnboardingAndDoesNotRecordReached() throws {
        let (model, provider) = try makeAppModel(with: .empty)
        XCTAssertTrue(model.shouldShowOnboarding)

        let center = OpenGameDayRequestCenter()
        center.submit(OpenGameDayRequest(source: .systemControl))
        var fallbackNavigationCount = 0
        XCTAssertEqual(
            process(center, model: model, onboardingIsPresented: true, onGameDay: {
                XCTFail("There is no team to open.")
            }, onFallback: { fallbackNavigationCount += 1 }),
            .fallback(reason: .noTeams)
        )
        XCTAssertNil(center.pendingRequest)
        XCTAssertEqual(fallbackNavigationCount, 1)
        XCTAssertTrue(model.shouldShowOnboarding)
        XCTAssertEqual(quickGameDayEvents(in: provider), [.quickGameDayInvoked, .quickGameDayFallback])
        XCTAssertFalse(provider.signals.contains { $0.event == .quickGameDayReached })
    }

    func testGameDayURLRoundTripsOptionalTeam() throws {
        let teamID = UUID()
        XCTAssertEqual(URL.rollCallOpenGameDay(teamID: teamID).rollCallOpenGameDayTarget, .explicitTeam(teamID))
        XCTAssertEqual(URL.rollCallOpenGameDay().rollCallOpenGameDayTarget, .rememberedTeam)
        XCTAssertNil(URL(string: "https://example.com")!.rollCallOpenGameDayTarget)
        XCTAssertNil(URL(string: "rollcall://game-day?team=not-a-uuid")!.rollCallOpenGameDayTarget)
    }

    private func state(teams: [Team], selected: UUID?, remembered: UUID?) -> AppState {
        var state = AppState.empty
        state.teams = teams
        state.selectedTeamID = selected
        state.lastGameDayTeamID = remembered
        return state
    }

    @MainActor
    private func process(
        _ center: OpenGameDayRequestCenter,
        model: AppModel,
        onboardingIsPresented: Bool,
        onGameDay: () -> Void,
        onFallback: () -> Void
    ) -> OpenGameDayRequestProcessingResult {
        OpenGameDayRequestProcessor.processPendingRequestIfPossible(
            in: center,
            using: model,
            hasResolvedInitialTab: true,
            hasBlockingPresentation: false,
            onboardingIsPresented: onboardingIsPresented,
            onNavigateToGameDay: onGameDay,
            onNavigateToFallback: onFallback
        )
    }

    @MainActor
    private func makeAppModel(with state: AppState) throws -> (AppModel, RecordingTelemetryProvider) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: AppPaths.stateURL(), options: .atomic)

        let provider = RecordingTelemetryProvider()
        let telemetryStore = TelemetryStore(
            url: temporaryDirectory.fileURL("telemetry-state.json"),
            now: RollCallTestFixtures.now
        )
        let defaults = UserDefaults(suiteName: "RollCallQuickGameDayTests.\(UUID().uuidString)")!
        let telemetry = RollCallTelemetryCoordinator(
            provider: provider,
            store: telemetryStore,
            preference: AnonymousUsageAnalyticsPreference(defaults: defaults),
            buildContext: TelemetryBuildContext(
                isAppStoreBuild: false,
                isTestFlightBuild: false,
                isDeveloperBuild: true,
                isSwiftUIPreview: false
            )
        )
        return (AppModel(telemetry: telemetry), provider)
    }

    private func quickGameDayEvents(in provider: RecordingTelemetryProvider) -> [RollCallTelemetryEvent] {
        provider.signals.map(\.event).filter {
            switch $0 {
            case .quickGameDayInvoked, .quickGameDayTargetResolved, .quickGameDayReached, .quickGameDayFallback:
                return true
            default:
                return false
            }
        }
    }
}
