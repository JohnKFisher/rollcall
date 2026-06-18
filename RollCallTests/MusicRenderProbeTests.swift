import XCTest
@testable import RollCall

final class MusicRenderProbeTests: XCTestCase {
    func testFailureClassificationMapsPermissionNetworkAndPermanentCases() {
        XCTAssertEqual(
            MusicRenderProbeFailureCategory.classify(AppError.musicAuthorizationRequired),
            .permissionNeeded
        )
        XCTAssertEqual(
            MusicRenderProbeFailureCategory.classify(URLError(.notConnectedToInternet)),
            .networkNeeded
        )
        XCTAssertEqual(
            MusicRenderProbeFailureCategory.classify(AppError.invalidImport),
            .renderFailedPermanent
        )
    }

    func testRedactedSummaryOmitsSongTitlesArtistsAndIDs() throws {
        let sample = MusicRenderProbeSample(
            scenario: .appleMusicCatalogOnly,
            selection: .catalog(
                MusicRenderProbeCatalogCandidate(
                    songID: "secret-song-id-123",
                    title: "Secret Walkup Song",
                    artistName: "Hidden Artist",
                    duration: 12,
                    previewURL: URL(string: "https://example.com/preview.m4a"),
                    isCatalogBacked: true
                )
            ),
            result: MusicRenderProbeResult.make(
                scenario: .appleMusicCatalogOnly,
                startedAt: Date(timeIntervalSince1970: 100),
                fullSourceAttempt: .failure(
                    path: .fullSource,
                    category: .protectedUnreadable,
                    detail: "No readable asset URL."
                ),
                previewProxyAttempt: .success(
                    path: .previewProxy,
                    detail: "Preview/proxy media exported to a temporary probe file."
                ),
                finishedAt: Date(timeIntervalSince1970: 105)
            )
        )

        let summary = MusicRenderProbeRedactedSummary.make(
            samples: [sample],
            authorizationStatus: "Authorized",
            playbackCapability: "Full Song",
            generatedAt: Date(timeIntervalSince1970: 110)
        )

        let data = try JSONEncoder().encode(summary)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(json.contains("Secret Walkup Song"))
        XCTAssertFalse(json.contains("Hidden Artist"))
        XCTAssertFalse(json.contains("secret-song-id-123"))
        XCTAssertTrue(json.contains("appleMusicCatalogOnly"))
        XCTAssertTrue(json.contains("previewOnlyRenderable"))
    }

}
