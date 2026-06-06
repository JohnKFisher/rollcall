import XCTest
@testable import RollCall

final class RatingRequestTests: XCTestCase {
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
    func testSuccessfulGameDaySessionsRespectCooldown() {
        let model = AppModel()
        let firstSession = RollCallTestFixtures.now

        model.state.ratingRequest.hasPlayedQualifyingCueInCurrentGameDayVisit = true
        model.finalizeGameDayVisitForRatingIfNeeded(at: firstSession)

        XCTAssertEqual(model.state.ratingRequest.successfulGameDaySessionCount, 1)
        XCTAssertTrue(model.state.ratingRequest.hasCountedCurrentGameDayVisit)

        model.beginGameDayVisitForRatingIfNeeded()
        model.state.ratingRequest.hasPlayedQualifyingCueInCurrentGameDayVisit = true
        model.finalizeGameDayVisitForRatingIfNeeded(at: firstSession.addingTimeInterval(2 * 60 * 60))

        XCTAssertEqual(model.state.ratingRequest.successfulGameDaySessionCount, 1)

        model.beginGameDayVisitForRatingIfNeeded()
        model.state.ratingRequest.hasPlayedQualifyingCueInCurrentGameDayVisit = true
        model.finalizeGameDayVisitForRatingIfNeeded(at: firstSession.addingTimeInterval(5 * 60 * 60))

        XCTAssertEqual(model.state.ratingRequest.successfulGameDaySessionCount, 2)
    }

    @MainActor
    func testThresholdTestingToggleResetsAutomaticAttemptState() {
        let model = AppModel()
        model.markAutomaticRatingPromptAttempted()

        model.setRatingThresholdMetForTesting(true)

        XCTAssertTrue(model.hasEarnedRatingRequest)
        XCTAssertTrue(model.canPresentAutomaticRatingRequest)
        XCTAssertEqual(model.state.ratingRequest.successfulGameDaySessionCount, 5)
        XCTAssertEqual(model.state.ratingRequest.automaticPromptAttemptCount, 0)
        XCTAssertEqual(model.state.ratingRequest.nextAutomaticPromptSessionThreshold, 5)

        model.markAutomaticRatingPromptAttempted()
        model.setRatingThresholdMetForTesting(false)

        XCTAssertFalse(model.hasEarnedRatingRequest)
        XCTAssertFalse(model.canPresentAutomaticRatingRequest)
        XCTAssertEqual(model.state.ratingRequest.successfulGameDaySessionCount, 0)
        XCTAssertEqual(model.state.ratingRequest.automaticPromptAttemptCount, 0)
        XCTAssertEqual(model.state.ratingRequest.nextAutomaticPromptSessionThreshold, 5)
    }

    @MainActor
    func testAutomaticPromptAllowsOneLaterRetryAfterMoreSuccessfulSessions() {
        let model = AppModel()

        model.setRatingThresholdMetForTesting(true)
        XCTAssertTrue(model.canPresentAutomaticRatingRequest)

        model.markAutomaticRatingPromptAttempted()
        XCTAssertFalse(model.canPresentAutomaticRatingRequest)
        XCTAssertEqual(model.state.ratingRequest.automaticPromptAttemptCount, 1)
        XCTAssertEqual(model.state.ratingRequest.nextAutomaticPromptSessionThreshold, 10)

        model.state.ratingRequest.successfulGameDaySessionCount = 9
        XCTAssertFalse(model.canPresentAutomaticRatingRequest)

        model.state.ratingRequest.successfulGameDaySessionCount = 10
        XCTAssertTrue(model.canPresentAutomaticRatingRequest)

        model.markAutomaticRatingPromptAttempted()
        XCTAssertEqual(model.state.ratingRequest.automaticPromptAttemptCount, 2)
        XCTAssertFalse(model.canPresentAutomaticRatingRequest)
    }
}
