import XCTest
import UIKit
@testable import RollCall

final class PlayerPhotoTests: XCTestCase {
    private struct LegacyPlayerPhotoView: Decodable {
        var id: UUID
        var displayName: String
        var photoRelativePath: String?
    }

    func testLegacyPlayerDecodesWithoutNewPhotoFields() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "displayName": "Legacy Player",
          "uniformNumber": "7",
          "pronunciationOverride": "",
          "photoRelativePath": "legacy.jpg",
          "isPresent": true
        }
        """

        let player = try JSONDecoder().decode(Player.self, from: Data(json.utf8))

        XCTAssertEqual(player.photoRelativePath, "legacy.jpg")
        XCTAssertNil(player.photoSourceRelativePath)
        XCTAssertNil(player.profilePhotoCrop)
        XCTAssertNil(player.playerCardPhotoCrop)
    }

    func testNewPhotoFieldsRoundTrip() throws {
        var player = RollCallTestFixtures.player(id: UUID(), name: "Player", number: "1", photoRelativePath: "profile.jpg")
        player.photoSourceRelativePath = "master.jpg"
        player.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.8)
        player.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.8, height: 0.9)

        let decoded = try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(player))

        XCTAssertEqual(decoded, player)
    }

    func testStaleProfileFramingCannotApplyOrPersistAfterPhotoReplacement() throws {
        let cropA = NormalizedPhotoCrop(x: 0.12, y: 0.18, width: 0.5, height: 0.5)
        let cropB = NormalizedPhotoCrop(x: 0.3, y: 0.2, width: 0.4, height: 0.4)
        let cardCropB = NormalizedPhotoCrop(x: 0.08, y: 0.12, width: 0.82, height: 0.7)
        var player = RollCallTestFixtures.player(
            id: UUID(),
            name: "Player",
            number: "1",
            photoRelativePath: "profile-a.jpg"
        )
        player.photoSourceRelativePath = "master-a.jpg"
        player.profilePhotoCrop = cropA
        let requestA = PlayerPhotoFramingRequest(source: .workingMaster(relativePath: "master-a.jpg"))
        var activeRequestID: UUID? = requestA.id

        XCTAssertEqual(requestA.validatedSourcePath(activeRequestID: activeRequestID, player: player), "master-a.jpg")

        // Replacement begins while A's framing work is outstanding.
        activeRequestID = nil
        player.photoRelativePath = "profile-b.jpg"
        player.photoSourceRelativePath = "master-b.jpg"
        player.profilePhotoCrop = cropB
        player.playerCardPhotoCrop = cardCropB
        let replacementDraft = player

        XCTAssertNil(requestA.validatedSourcePath(activeRequestID: activeRequestID, player: player))
        XCTAssertNil(requestA.validatedSourcePath(activeRequestID: requestA.id, player: player))
        XCTAssertFalse(requestA.applyProfileFraming(
            cropA,
            profileRelativePath: "stale-profile-from-a.jpg",
            activeRequestID: activeRequestID,
            to: &player
        ))
        XCTAssertEqual(player, replacementDraft)

        let savedPlayer = try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(player))
        XCTAssertEqual(savedPlayer.photoRelativePath, "profile-b.jpg")
        XCTAssertEqual(savedPlayer.photoSourceRelativePath, "master-b.jpg")
        XCTAssertEqual(savedPlayer.profilePhotoCrop, cropB)
        XCTAssertEqual(savedPlayer.playerCardPhotoCrop, cardCropB)
    }

    func testCurrentProfileFramingUpdatesProfileAndKeepsWorkingMasterAndCardCrop() throws {
        let initialCardCrop = NormalizedPhotoCrop(x: 0.1, y: 0.08, width: 0.8, height: 0.75)
        let adjustedProfileCrop = NormalizedPhotoCrop(x: 0.2, y: 0.16, width: 0.56, height: 0.56)
        var player = RollCallTestFixtures.player(
            id: UUID(),
            name: "Player",
            number: "1",
            photoRelativePath: "profile-a.jpg"
        )
        player.photoSourceRelativePath = "master-a.jpg"
        player.playerCardPhotoCrop = initialCardCrop
        let request = PlayerPhotoFramingRequest(source: .workingMaster(relativePath: "master-a.jpg"))

        XCTAssertTrue(request.applyProfileFraming(
            adjustedProfileCrop,
            profileRelativePath: "profile-adjusted.jpg",
            activeRequestID: request.id,
            to: &player
        ))

        XCTAssertEqual(player.photoRelativePath, "profile-adjusted.jpg")
        XCTAssertEqual(player.photoSourceRelativePath, "master-a.jpg")
        XCTAssertEqual(player.profilePhotoCrop, adjustedProfileCrop)
        XCTAssertEqual(player.playerCardPhotoCrop, initialCardCrop)
    }

    func testLegacyProfileFramingRequiresTheSameUnbackedProfilePath() {
        var player = RollCallTestFixtures.player(
            id: UUID(),
            name: "Legacy Player",
            number: "1",
            photoRelativePath: "legacy-profile.jpg"
        )
        let request = PlayerPhotoFramingRequest(source: .legacyProfile(relativePath: "legacy-profile.jpg"))

        XCTAssertEqual(request.validatedSourcePath(activeRequestID: request.id, player: player), "legacy-profile.jpg")

        player.photoSourceRelativePath = "new-working-master.jpg"

        XCTAssertNil(request.validatedSourcePath(activeRequestID: request.id, player: player))
    }

    func testLegacyDecoderKeepsProfilePhotoAndIgnoresAdditivePhotoFields() throws {
        var player = RollCallTestFixtures.player(id: UUID(), name: "Player", number: "1", photoRelativePath: "profile.jpg")
        player.photoSourceRelativePath = "master.jpg"
        player.profilePhotoCrop = NormalizedPhotoCrop(x: 0.2, y: 0.1, width: 0.5, height: 0.5)
        player.playerCardPhotoCrop = NormalizedPhotoCrop(x: 0.1, y: 0.05, width: 0.8, height: 0.9)

        let legacyView = try JSONDecoder().decode(LegacyPlayerPhotoView.self, from: JSONEncoder().encode(player))

        XCTAssertEqual(legacyView.id, player.id)
        XCTAssertEqual(legacyView.displayName, player.displayName)
        XCTAssertEqual(legacyView.photoRelativePath, "profile.jpg")
    }

    func testFaceAndPersonProduceIndependentAspectCorrectFramings() {
        let imageSize = CGSize(width: 1_600, height: 900)
        let analysis = PlayerPhotoFramingGeometry.analyze(
            faces: [CGRect(x: 0.46, y: 0.16, width: 0.12, height: 0.18)],
            people: [CGRect(x: 0.31, y: 0.1, width: 0.42, height: 0.83)],
            imageSize: imageSize
        )

        XCTAssertEqual(analysis.result, .faceAndPerson)
        assertPhysicalAspect(analysis.profileCrop, imageSize: imageSize, expected: 1)
        assertPhysicalAspect(analysis.cardCrop, imageSize: imageSize, expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio)
        XCTAssertLessThan(analysis.profileCrop.height, analysis.cardCrop.height)
    }

    func testAutomaticProfileFaceCropIsTighterWhileCardCropRemainsSeparate() throws {
        let imageSize = CGSize(width: 1_000, height: 1_000)
        let face = CGRect(x: 0.44, y: 0.14, width: 0.12, height: 0.14)
        let options = PlayerPhotoFramingGeometry.framingOptions(
            faces: [face],
            people: [],
            imageSize: imageSize
        )

        let profile = try XCTUnwrap(options.profile[.automatic]).cgRect
        let card = try XCTUnwrap(options.card[.automatic]).cgRect

        // The original 0.8x / 1.15x padding produced a 0.462 crop; the prior
        // 0.7x / 1.0x adjustment produced 0.42. This revision tightens it to 0.378.
        XCTAssertEqual(profile.width, 0.378, accuracy: 0.001)
        XCTAssertEqual(profile.height, 0.378, accuracy: 0.001)
        XCTAssertEqual(profile.midX, face.midX, accuracy: 0.001)
        XCTAssertTrue(profile.contains(face))

        XCTAssertEqual(card.width, 0.883, accuracy: 0.002)
        XCTAssertEqual(card.height, 0.728, accuracy: 0.002)
        assertPhysicalAspect(
            NormalizedPhotoCrop(card),
            imageSize: imageSize,
            expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio
        )
    }

    func testAutomaticProfileFaceCropStaysBoundedAndKeepsAnEdgeFace() throws {
        let face = CGRect(x: 0.02, y: 0.14, width: 0.12, height: 0.14)
        let crop = try XCTUnwrap(
            PlayerPhotoFramingGeometry.framingOptions(
                faces: [face],
                people: [],
                imageSize: CGSize(width: 1_000, height: 1_000)
            ).profile[.automatic]
        )
        let rect = crop.cgRect

        XCTAssertEqual(rect.minX, 0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(rect.minY, 0)
        XCTAssertLessThanOrEqual(rect.maxX, 1)
        XCTAssertLessThanOrEqual(rect.maxY, 1)
        XCTAssertTrue(rect.contains(face))
        XCTAssertEqual(crop.clamped().cgRect, rect)
    }

    func testAutomaticCardFramingPrefersUpperBodyWhenFullBodyIsAvailable() {
        let imageSize = CGSize(width: 1_600, height: 1_200)
        let face = CGRect(x: 0.46, y: 0.1, width: 0.08, height: 0.1)
        let options = PlayerPhotoFramingGeometry.framingOptions(
            faces: [face],
            people: [CGRect(x: 0.3, y: 0.08, width: 0.4, height: 0.86)],
            upperBodies: [CGRect(x: 0.32, y: 0.08, width: 0.36, height: 0.48)],
            imageSize: imageSize
        )
        let faceOnly = PlayerPhotoFramingGeometry.framingOptions(
            faces: [face],
            people: [],
            imageSize: imageSize
        )

        let automatic = try! XCTUnwrap(options.card[.automatic])
        let faceOnlyAutomatic = try! XCTUnwrap(faceOnly.card[.automatic])
        let fullBody = try! XCTUnwrap(options.card[.fullBody])

        assertPhysicalAspect(automatic, imageSize: imageSize, expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio)
        XCTAssertLessThan(automatic.cgRect.height, fullBody.cgRect.height)
        XCTAssertGreaterThan(automatic.cgRect.midY, 0.25)
        XCTAssertNotEqual(automatic.cgRect, faceOnlyAutomatic.cgRect)
    }

    func testAutomaticCardFramingUsesFaceOnlyWhenAvailableBodiesBelongElsewhere() throws {
        let imageSize = CGSize(width: 1_600, height: 1_200)
        let faceA = CGRect(x: 0.12, y: 0.16, width: 0.1, height: 0.12)
        let bodyB = CGRect(x: 0.68, y: 0.08, width: 0.24, height: 0.78)

        XCTAssertNil(PlayerPhotoFramingGeometry.bestAssociatedBody(in: [bodyB], matching: faceA))
        XCTAssertNil(PlayerPhotoFramingGeometry.bestAssociatedBody(in: [], matching: faceA))

        let withUnrelatedBodies = PlayerPhotoFramingGeometry.framingOptions(
            faces: [faceA],
            people: [bodyB],
            upperBodies: [bodyB],
            imageSize: imageSize
        )
        let faceOnly = PlayerPhotoFramingGeometry.framingOptions(
            faces: [faceA],
            people: [],
            imageSize: imageSize
        )

        let automatic = try XCTUnwrap(withUnrelatedBodies.card[.automatic]).cgRect
        let faceOnlyAutomatic = try XCTUnwrap(faceOnly.card[.automatic]).cgRect
        XCTAssertEqual(automatic, faceOnlyAutomatic)

        // The explicit Full Body preset retains its existing independent person selection.
        let fullBody = try XCTUnwrap(withUnrelatedBodies.card[.fullBody]).cgRect
        XCTAssertGreaterThan(fullBody.midX, faceOnlyAutomatic.midX)
    }

    func testAutomaticCardFramingChoosesStrongestFaceAssociatedBodyIndependentOfOrder() throws {
        let imageSize = CGSize(width: 1_600, height: 1_200)
        let faceA = CGRect(x: 0.38, y: 0.14, width: 0.1, height: 0.12)
        let bodyA = CGRect(x: 0.30, y: 0.08, width: 0.26, height: 0.55)
        // This broader rectangle also contains the face, but its upper-center association is weaker.
        let bodyB = CGRect(x: 0.1, y: 0.01, width: 0.8, height: 0.9)

        XCTAssertEqual(
            PlayerPhotoFramingGeometry.bestAssociatedBody(in: [bodyB, bodyA], matching: faceA),
            bodyA
        )
        XCTAssertEqual(
            PlayerPhotoFramingGeometry.bestAssociatedBody(in: [bodyA, bodyB], matching: faceA),
            bodyA
        )

        let options = PlayerPhotoFramingGeometry.framingOptions(
            faces: [faceA],
            people: [bodyB],
            upperBodies: [bodyB, bodyA],
            imageSize: imageSize
        )
        let reversedOptions = PlayerPhotoFramingGeometry.framingOptions(
            faces: [faceA],
            people: [bodyB],
            upperBodies: [bodyA, bodyB],
            imageSize: imageSize
        )
        let bodyAOnly = PlayerPhotoFramingGeometry.framingOptions(
            faces: [faceA],
            people: [],
            upperBodies: [bodyA],
            imageSize: imageSize
        )

        let automatic = try XCTUnwrap(options.card[.automatic]).cgRect
        let reversedAutomatic = try XCTUnwrap(reversedOptions.card[.automatic]).cgRect
        let bodyAOnlyAutomatic = try XCTUnwrap(bodyAOnly.card[.automatic]).cgRect
        XCTAssertEqual(automatic, bodyAOnlyAutomatic)
        XCTAssertEqual(reversedAutomatic, bodyAOnlyAutomatic)
    }

    func testFramingOptionsExposeAllTestingModesForBothTargets() {
        let options = PlayerPhotoFramingGeometry.framingOptions(
            faces: [CGRect(x: 0.4, y: 0.12, width: 0.2, height: 0.16)],
            people: [CGRect(x: 0.25, y: 0.08, width: 0.5, height: 0.84)],
            upperBodies: [CGRect(x: 0.28, y: 0.08, width: 0.44, height: 0.5)],
            imageSize: CGSize(width: 1_200, height: 1_600)
        )

        XCTAssertEqual(Set(options.profile.keys), Set(PlayerPhotoFramingMode.allCases))
        XCTAssertEqual(Set(options.card.keys), Set(PlayerPhotoFramingMode.allCases))
    }

    func testMultiplePeopleFavorLargeCentralSubject() {
        let imageSize = CGSize(width: 1_000, height: 1_500)
        let analysis = PlayerPhotoFramingGeometry.analyze(
            faces: [
                CGRect(x: 0.05, y: 0.2, width: 0.08, height: 0.08),
                CGRect(x: 0.45, y: 0.12, width: 0.16, height: 0.14)
            ],
            people: [
                CGRect(x: 0.02, y: 0.12, width: 0.18, height: 0.55),
                CGRect(x: 0.31, y: 0.05, width: 0.48, height: 0.9)
            ],
            imageSize: imageSize
        )

        XCTAssertEqual(analysis.result, .multiplePeople)
        XCTAssertGreaterThan(analysis.cardCrop.cgRect.midX, 0.35)
        XCTAssertLessThan(analysis.cardCrop.cgRect.midX, 0.7)
    }

    func testSuppliedCatcherPhotoSelectsCentralFaceIndependentOfObservationOrder() {
        let catcher = CGRect(x: 0.380072, y: 0.210776, width: 0.151447, height: 0.181736)
        let edgePerson = CGRect(x: -0.001754, y: 0.077555, width: 0.057913, height: 0.069496)

        XCTAssertGreaterThan(
            PlayerPhotoFramingGeometry.primaryFaceScore(for: catcher),
            PlayerPhotoFramingGeometry.primaryFaceScore(for: edgePerson)
        )
        XCTAssertEqual(PlayerPhotoFramingGeometry.selectPrimaryFace(from: [catcher, edgePerson]), catcher)
        XCTAssertEqual(PlayerPhotoFramingGeometry.selectPrimaryFace(from: [edgePerson, catcher]), catcher)

        let analysis = PlayerPhotoFramingGeometry.analyze(
            faces: [catcher, edgePerson],
            people: [CGRect(x: 0.001626, y: 0.011998, width: 0.203880, height: 0.920759)],
            upperBodies: [
                CGRect(x: 0.249419, y: 0.092913, width: 0.340846, height: 0.676897),
                CGRect(x: 0.001162, y: 0.012695, width: 0.150674, height: 0.484096)
            ],
            imageSize: CGSize(width: 1_374, height: 1_145)
        )
        let reversedObservations = PlayerPhotoFramingGeometry.analyze(
            faces: [edgePerson, catcher],
            people: [CGRect(x: 0.001626, y: 0.011998, width: 0.203880, height: 0.920759)],
            upperBodies: [
                CGRect(x: 0.001162, y: 0.012695, width: 0.150674, height: 0.484096),
                CGRect(x: 0.249419, y: 0.092913, width: 0.340846, height: 0.676897)
            ],
            imageSize: CGSize(width: 1_374, height: 1_145)
        )
        let profileCrop = analysis.profileCrop.cgRect
        let cardCrop = analysis.cardCrop.cgRect
        XCTAssertTrue(profileCrop.contains(CGPoint(x: catcher.midX, y: catcher.midY)))
        XCTAssertFalse(profileCrop.contains(CGPoint(x: edgePerson.midX, y: edgePerson.midY)))
        // This image's aspect ratio is nearly the card viewport ratio, so the card crop stays broad.
        XCTAssertTrue(cardCrop.contains(CGPoint(x: catcher.midX, y: catcher.midY)))
        XCTAssertEqual(cardCrop.midX, catcher.midX, accuracy: 0.03)
        XCTAssertEqual(reversedObservations.cardCrop.cgRect, cardCrop)
    }

    func testPrimaryFaceSelectionKeepsOnlyAvailableOffCenterFace() {
        let offCenterFace = CGRect(x: 0.12, y: 0.23, width: 0.2, height: 0.2)

        XCTAssertEqual(PlayerPhotoFramingGeometry.selectPrimaryFace(from: [offCenterFace]), offCenterFace)
    }

    func testPrimaryFaceSelectionCanPreferProminentOffCenterFaceToSmallIncidentalFace() {
        let primary = CGRect(x: 0.12, y: 0.2, width: 0.22, height: 0.24)
        let incidental = CGRect(x: 0.47, y: 0.46, width: 0.06, height: 0.06)

        XCTAssertEqual(PlayerPhotoFramingGeometry.selectPrimaryFace(from: [incidental, primary]), primary)
    }

    func testPrimaryFaceSelectionBreaksExactTiesWithoutUsingObservationOrder() {
        let left = CGRect(x: 0.1, y: 0.4, width: 0.1, height: 0.1)
        let right = CGRect(x: 0.8, y: 0.4, width: 0.1, height: 0.1)

        XCTAssertEqual(PlayerPhotoFramingGeometry.primaryFaceScore(for: left), PlayerPhotoFramingGeometry.primaryFaceScore(for: right), accuracy: 0.000_001)
        XCTAssertEqual(PlayerPhotoFramingGeometry.selectPrimaryFace(from: [left, right]), left)
        XCTAssertEqual(PlayerPhotoFramingGeometry.selectPrimaryFace(from: [right, left]), left)
    }

    func testTwoPeopleWithoutFacesStillReportMultiplePeople() {
        let analysis = PlayerPhotoFramingGeometry.analyze(
            faces: [],
            people: [
                CGRect(x: 0.05, y: 0.18, width: 0.28, height: 0.7),
                CGRect(x: 0.4, y: 0.08, width: 0.5, height: 0.88)
            ],
            imageSize: CGSize(width: 1_200, height: 1_600)
        )

        XCTAssertEqual(analysis.result, .multiplePeople)
        XCTAssertGreaterThan(analysis.cardCrop.cgRect.midX, 0.4)
    }

    func testFaceOnlyPersonOnlyAndNoDetectionFallbacks() {
        let size = CGSize(width: 800, height: 1_200)
        XCTAssertEqual(
            PlayerPhotoFramingGeometry.analyze(
                faces: [CGRect(x: 0.4, y: 0.15, width: 0.2, height: 0.18)],
                people: [],
                imageSize: size
            ).result,
            .faceOnly
        )
        XCTAssertEqual(
            PlayerPhotoFramingGeometry.analyze(
                faces: [],
                people: [CGRect(x: 0.25, y: 0.08, width: 0.5, height: 0.86)],
                imageSize: size
            ).result,
            .personOnly
        )
        let fallback = PlayerPhotoFramingGeometry.analyze(faces: [], people: [], imageSize: size)
        XCTAssertEqual(fallback.result, .noUsableDetection)
        assertPhysicalAspect(fallback.cardCrop, imageSize: size, expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio)
    }

    func testCenteredCropHandlesExtremeAspectRatios() {
        let panorama = CGSize(width: 4_000, height: 500)
        let tall = CGSize(width: 400, height: 3_000)
        let panoramaCrop = PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: panorama)
        let tallCrop = PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: tall)

        assertPhysicalAspect(panoramaCrop, imageSize: panorama, expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio)
        assertPhysicalAspect(tallCrop, imageSize: tall, expected: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio)
        XCTAssertEqual(panoramaCrop.cgRect.midX, 0.5, accuracy: 0.001)
        XCTAssertEqual(tallCrop.cgRect.midY, 0.5, accuracy: 0.001)
    }

    /// Regression guard for the degenerate-anchor bug: `centeredCrop` returned a
    /// zero-area rect for *every* image, so any player without a stored crop —
    /// i.e. every photo added before 1.3 — framed a 1% sliver of their photo.
    /// Extreme aspect ratios are covered above; this covers the ordinary shapes
    /// real player photos actually have, for both the card and profile aspects.
    func testCenteredCropCoversMostOfAnOrdinaryPhoto() {
        let sizes = [
            CGSize(width: 1_000, height: 1_500),
            CGSize(width: 1_200, height: 1_600),
            CGSize(width: 3_024, height: 4_032),
            CGSize(width: 500, height: 500)
        ]
        let aspects = [PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, 1.0]

        for size in sizes {
            for aspect in aspects {
                let crop = PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: aspect, imageSize: size)
                let rect = crop.cgRect

                assertPhysicalAspect(crop, imageSize: size, expected: aspect)
                XCTAssertEqual(rect.midX, 0.5, accuracy: 0.001, "\(size) @ \(aspect)")
                XCTAssertEqual(rect.midY, 0.5, accuracy: 0.001, "\(size) @ \(aspect)")
                // A correct centred crop always spans one axis completely.
                XCTAssertEqual(max(rect.width, rect.height), 1, accuracy: 0.001, "\(size) @ \(aspect)")
                XCTAssertGreaterThan(rect.width * rect.height, 0.4, "\(size) @ \(aspect) framed a degenerate sliver")
                // `clamped()` must not have to rescue the value.
                XCTAssertEqual(crop.clamped().cgRect, rect)
            }
        }
    }

    func testPreparationNormalizesOrientationAndBoundsMaster() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4_000, height: 2_000))
        let base = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4_000, height: 2_000))
        }
        guard let cgImage = base.cgImage,
              let encoded = UIImage(cgImage: cgImage, scale: 1, orientation: .left).jpegData(compressionQuality: 0.9) else {
            return XCTFail("Could not create oriented fixture")
        }

        let prepared = try await PlayerPhotoPreparationService().prepare(data: encoded)
        let decodedMaster = try XCTUnwrap(UIImage(data: prepared.masterJPEG))
        let decodedProfile = try XCTUnwrap(UIImage(data: prepared.profileJPEG))

        XCTAssertLessThanOrEqual(max(decodedMaster.size.width, decodedMaster.size.height), 3_000)
        XCTAssertEqual(decodedProfile.size, PlayerPhotoPreparationService.profilePixelSize)
        XCTAssertEqual(decodedMaster.imageOrientation, .up)
    }

    private func assertPhysicalAspect(
        _ crop: NormalizedPhotoCrop,
        imageSize: CGSize,
        expected: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = crop.cgRect.width * imageSize.width / (crop.cgRect.height * imageSize.height)
        XCTAssertEqual(actual, expected, accuracy: 0.002, file: file, line: line)
    }
}
