import XCTest
import UIKit
@testable import RollCall

final class PlayerCardLabTests: XCTestCase {
    func testCleanV2DefaultsMatchApprovedTuning() {
        let tuning = PlayerCardLabTuning.default

        XCTAssertEqual(tuning.cleanGradientStart, 0.35, accuracy: 0.0001)
        XCTAssertEqual(tuning.cleanGradientStrength, 1.00, accuracy: 0.0001)
        XCTAssertEqual(tuning.cleanNameY, 785, accuracy: 0.0001)
        XCTAssertEqual(tuning.cleanEdgeLight, 0.55, accuracy: 0.0001)
    }

    func testCleanV2MusicGroupStartsBelowPhotoBoundary() {
        let boundary = CleanV2Layout.photoRect.maxY

        XCTAssertGreaterThanOrEqual(CleanV2Layout.musicIconRect.minY, boundary)
        XCTAssertGreaterThanOrEqual(CleanV2Layout.musicLabelRect.minY, boundary)
        XCTAssertGreaterThanOrEqual(CleanV2Layout.songRect.minY, boundary)
        XCTAssertGreaterThanOrEqual(CleanV2Layout.artistRect.minY, boundary)
        XCTAssertGreaterThan(CleanV2Layout.songRect.minY, CleanV2Layout.musicLabelRect.maxY)
        XCTAssertGreaterThanOrEqual(CleanV2Layout.artistRect.minY, CleanV2Layout.songRect.maxY)
        XCTAssertGreaterThan(CleanV2Layout.waveformRect.minY, CleanV2Layout.artistRect.maxY)
        XCTAssertLessThan(CleanV2Layout.waveformRect.maxY, CleanV2Layout.footerY - 18)
    }

    func testCleanV2DefaultNameFitsInsidePhotoSection() {
        let nameBottom = PlayerCardLabTuning.default.cleanNameY + 42 + 110

        XCTAssertLessThanOrEqual(nameBottom, CleanV2Layout.photoRect.maxY)
    }

    func testAllLabTemplatesShareTheAutomaticCardCrop() {
        let crop = NormalizedPhotoCrop(x: 0.12, y: 0.08, width: 0.76, height: 0.74)
        let crops = PlayerCardTemplate.allCases.map {
            CardFixtureLibrary.fixture(id: "normal", template: $0, crop: crop).model.crop
        }

        XCTAssertEqual(crops, Array(repeating: crop, count: PlayerCardTemplate.allCases.count))
    }

    func testEmbeddedLabPhotoFixtureCatalogContainsFiveDebugPhotos() {
        XCTAssertEqual(LabPhotoFixture.allCases.count, 5)
        XCTAssertEqual(
            LabPhotoFixture.allCases.map(\.rawValue),
            [
                "lab-field-full-body",
                "lab-field-action-wide",
                "lab-batting-portrait",
                "lab-batting-side",
                "lab-throwing-wide"
            ]
        )
    }

    func testEveryLabTemplateUsesCanonicalCanvasAndPNG() throws {
        for template in PlayerCardTemplate.allCases {
            let model = CardFixtureLibrary.fixture(id: "normal", template: template).model
            let image = PlayerCardArtworkRenderer.render(model)

            XCTAssertEqual(image.size, CGSize(width: 1_080, height: 1_350))
            let pixels = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(pixels.width, 1_080)
            XCTAssertEqual(pixels.height, 1_350)
            XCTAssertEqual(pixels.colorSpace?.name, CGColorSpace.sRGB)
            XCTAssertEqual(image.size.width / image.size.height, 4.0 / 5.0, accuracy: 0.0001)
            XCTAssertNotNil(image.pngData())
        }
    }

    func testLabRenderingIsDeterministicAcrossTemplates() throws {
        for template in PlayerCardTemplate.allCases {
            let model = CardFixtureLibrary.fixture(id: "long-name", template: template).model
            XCTAssertEqual(
                try XCTUnwrap(PlayerCardArtworkRenderer.render(model).pngData()),
                try XCTUnwrap(PlayerCardArtworkRenderer.render(model).pngData()),
                "Expected deterministic PNG output for \(template.title)."
            )
        }
    }

    func testOptionalContentStatesRender() {
        for id in ["no-number", "no-music"] {
            let model = CardFixtureLibrary.fixture(id: id, template: .broadcast(version: 1)).model
            let image = PlayerCardArtworkRenderer.render(model)

            XCTAssertEqual(image.size, CGSize(width: 1_080, height: 1_350))
            XCTAssertNotNil(image.pngData())
        }
    }

    func testBroadcastLongNameAndMusicStayWithinTheirLayoutContracts() throws {
        let model = CardFixtureLibrary.fixture(id: "long-name", template: .broadcast(version: 1)).model
        let nameFit = PlayerCardArtworkRenderer.fittedBroadcastNameFont(
            model.lastName.uppercased(),
            maxSize: 102.5,
            minimumSize: 40,
            width: 940,
            weight: .black
        )
        let measuredName = NSAttributedString(
            string: model.lastName.uppercased(),
            attributes: [.font: nameFit.font, .kern: nameFit.tracking]
        ).size().width
        XCTAssertLessThanOrEqual(measuredName, 940.0)

        let song = try XCTUnwrap(model.songTitle)
        let songFont = PlayerCardArtworkRenderer.fittedWrappedFont(
            song,
            maxSize: 42,
            minimumSize: 28,
            width: 700,
            maxLines: 2,
            weight: .bold
        )
        XCTAssertLessThanOrEqual(
            PlayerCardArtworkRenderer.wrappedLineCount(song, font: songFont, width: 700, maxLines: 2),
            2
        )
        XCTAssertNotNil(PlayerCardArtworkRenderer.render(model).pngData())
    }

    func testBroadcastGiantNumberYControlChangesOnlyBroadcastArtwork() throws {
        var adjusted = PlayerCardLabTuning.default
        adjusted.broadcastGiantNumberY = 560

        let baseline = CardFixtureLibrary.fixture(id: "normal", template: .broadcast(version: 1)).model
        let shifted = CardFixtureLibrary.fixture(id: "normal", template: .broadcast(version: 1), tuning: adjusted).model

        XCTAssertEqual(PlayerCardLabTuning.default.broadcastGiantNumberY, 650.00)
        XCTAssertNotEqual(
            try XCTUnwrap(PlayerCardArtworkRenderer.render(baseline).pngData()),
            try XCTUnwrap(PlayerCardArtworkRenderer.render(shifted).pngData())
        )
    }

    func testBroadcastGeometryDefaultsMatchApprovedTuning() {
        let tuning = PlayerCardLabTuning.default

        XCTAssertEqual(tuning.broadcastAngle, 10.0)
        XCTAssertEqual(tuning.broadcastLowerThirdY, 865.00)
        XCTAssertEqual(tuning.broadcastPlaneOpacity, 0.40)
        XCTAssertEqual(tuning.broadcastNumberOpacity, 0.60)
        XCTAssertEqual(tuning.broadcastGiantNumberY, 650.00)
        XCTAssertEqual(tuning.broadcastPhotoHeight, 1_020)
        XCTAssertEqual(tuning.broadcastNameY, 850)
        XCTAssertEqual(tuning.broadcastMusicY, 1_080)
    }

    func testResolversRemainFiniteAcrossArbitraryColors() {
        let colors = [
            CardRGBColor(red: 0.01, green: 0.01, blue: 0.01),
            CardRGBColor(red: 0.99, green: 0.99, blue: 0.99),
            CardRGBColor(red: 0.95, green: 0.02, blue: 0.03),
            CardRGBColor(red: 0.02, green: 0.90, blue: 0.04),
            CardRGBColor(red: 0.03, green: 0.10, blue: 0.95),
            CardRGBColor(red: 0.72, green: 0.46, blue: 0.16),
            CardRGBColor(red: 0.42, green: 0.42, blue: 0.42)
        ]

        for color in colors {
            let resolved = [
                CleanCardColorResolver.resolve(color).displayAccent,
                BroadcastCardColorResolver.resolve(color).strongGraphicAccent,
                SpotlightCardColorResolver.resolve(color).rimLightAccent
            ]
            for value in resolved {
                XCTAssertTrue(value.red.isFinite && value.green.isFinite && value.blue.isFinite)
                XCTAssertGreaterThanOrEqual(value.red, 0)
                XCTAssertLessThanOrEqual(value.red, 1)
            }
        }
    }

    func testSpotlightFallbackAndInjectedMaskRender() throws {
        let fallback = CardFixtureLibrary.fixture(id: "normal", template: .spotlight(version: 1)).model
        XCTAssertNotNil(PlayerCardArtworkRenderer.render(fallback).pngData())

        let mask = try XCTUnwrap(makeMask().cgImage)
        let analysis = SpotlightAnalysisResult(
            mask: mask,
            processedMask: mask,
            rimLightMask: mask,
            quality: .excellent,
            maskBounds: CGRect(x: 0.26, y: 0.10, width: 0.48, height: 0.78),
            faceBounds: CGRect(x: 0.39, y: 0.13, width: 0.22, height: 0.16),
            personBounds: CGRect(x: 0.26, y: 0.10, width: 0.48, height: 0.78),
            cacheKey: "test-mask",
            wasCacheHit: false
        )
        let segmented = CardFixtureLibrary.fixture(
            id: "normal",
            template: .spotlight(version: 1),
            segmentationMode: .forceExcellent,
            analysis: analysis
        ).model

        XCTAssertNotEqual(
            try XCTUnwrap(PlayerCardArtworkRenderer.render(fallback).pngData()),
            try XCTUnwrap(PlayerCardArtworkRenderer.render(segmented).pngData())
        )
    }

    func testSpotlightMaskedPhotoKeepsAsymmetricMaskRegisteredWithSource() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let source = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { rendererContext in
            UIColor.systemRed.setFill()
            rendererContext.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
            UIColor.systemBlue.setFill()
            rendererContext.fill(CGRect(x: 0, y: 32, width: 64, height: 32))
        }
        let mask = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { rendererContext in
            UIColor.white.setFill()
            rendererContext.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
        }
        let maskCGImage = try XCTUnwrap(mask.cgImage)
        let outputFormat = UIGraphicsImageRendererFormat()
        outputFormat.scale = 1
        outputFormat.opaque = true

        let output = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: outputFormat).image { rendererContext in
            UIColor.black.setFill()
            rendererContext.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            PlayerCardArtworkRenderer.drawMaskedPhoto(
                source,
                mask: maskCGImage,
                crop: .full,
                in: CGRect(x: 0, y: 0, width: 64, height: 64),
                context: rendererContext.cgContext,
                envelope: CGRect(x: 0, y: 0, width: 64, height: 64)
            )
        }

        let pixels = rgbaPixels(output)
        let top = pixel(pixels, width: 64, x: 32, y: 16)
        let bottom = pixel(pixels, width: 64, x: 32, y: 48)
        XCTAssertGreaterThan(top.red, top.blue, "The white top-half mask should retain the red top-half source.")
        XCTAssertLessThan(bottom.red, 24, "The masked-out bottom half should remain background.")
        XCTAssertLessThan(bottom.blue, 24, "The masked-out bottom half should remain background.")
    }

    func testSpotlightPhotoTransformCentersAspectFillCropOverflow() {
        let transform = SpotlightPhotoTransform(
            sourceSize: CGSize(width: 1_400, height: 1_800),
            crop: NormalizedPhotoCrop(x: 0, y: 0.1, width: 1, height: 0.8),
            destinationFrame: CGRect(x: 220, y: 155, width: 640, height: 820)
        )

        XCTAssertEqual(transform.fullImageDestination.midX, 540, accuracy: 0.001)
        XCTAssertEqual(transform.fullImageDestination.midY, 565, accuracy: 0.001)
        XCTAssertEqual(transform.fullImageDestination.minX, 141.25, accuracy: 1.0)
        XCTAssertEqual(transform.fullImageDestination.maxX, 938.75, accuracy: 1.0)
        XCTAssertEqual(
            transform.projectedSourceRect(CGRect(x: 0, y: 0, width: 1, height: 1)).midX,
            transform.fullImageDestination.midX,
            accuracy: 0.001
        )
    }

    func testSpotlightMaskBackendIsPartOfAnalysisCacheIdentity() {
        let crop = NormalizedPhotoCrop(x: 0.08, y: 0.12, width: 0.84, height: 0.72)
        let personKey = SpotlightAnalysisService.cacheKey(for: "photo", crop: crop, backend: .personInstance)
        let foregroundKey = SpotlightAnalysisService.cacheKey(for: "photo", crop: crop, backend: .foregroundInstance)

        XCTAssertNotEqual(personKey, foregroundKey)
        XCTAssertTrue(personKey.contains(SpotlightSegmentationBackend.personInstance.rawValue))
        XCTAssertTrue(foregroundKey.contains(SpotlightSegmentationBackend.foregroundInstance.rawValue))
        XCTAssertTrue(personKey.contains(SpotlightAnalysisService.analysisVersion))
    }

    func testSpotlightDiagnosticStateDistinguishesAnalysisLifecycleAndQuality() throws {
        XCTAssertEqual(
            SpotlightDiagnosticState.resolve(mode: .auto, analysis: nil, isAnalyzing: true, hasPhoto: true),
            .fallbackAnalyzing
        )
        XCTAssertEqual(
            SpotlightDiagnosticState.resolve(mode: .auto, analysis: nil, isAnalyzing: false, hasPhoto: true),
            .notAnalyzed
        )
        XCTAssertEqual(
            SpotlightDiagnosticState.resolve(mode: .auto, analysis: makeAnalysis(quality: .fallback), isAnalyzing: false, hasPhoto: true),
            .fallbackNoUsableMask
        )
        XCTAssertEqual(
            SpotlightDiagnosticState.resolve(mode: .auto, analysis: makeAnalysis(quality: .usable), isAnalyzing: false, hasPhoto: true, breakoutMetrics: meaningfulBreakoutMetrics),
            .enhancedUsable
        )
        XCTAssertEqual(
            SpotlightDiagnosticState.resolve(mode: .auto, analysis: makeAnalysis(quality: .excellent), isAnalyzing: false, hasPhoto: true, breakoutMetrics: meaningfulBreakoutMetrics),
            .enhancedExcellent
        )
        XCTAssertEqual(
            SpotlightDiagnosticState.resolve(mode: .forceExcellent, analysis: makeAnalysis(quality: .fallback), isAnalyzing: false, hasPhoto: true),
            .forcedExcellent
        )
        XCTAssertEqual(
            SpotlightDiagnosticState.resolve(mode: .auto, analysis: nil, isAnalyzing: false, hasPhoto: false),
            .noPhoto
        )
    }

    func testSpotlightDiagnosticStateDoesNotCallAContainedMaskAVisibleBreakout() {
        let contained = SpotlightBreakoutGeometry.Metrics(
            sampledForegroundFraction: 0.30,
            outsidePhotoFraction: 0,
            outsideEnvelopeFraction: 0,
            protectedZoneFraction: 0
        )
        XCTAssertEqual(
            SpotlightDiagnosticState.resolve(
                mode: .auto,
                analysis: makeAnalysis(quality: .excellent),
                isAnalyzing: false,
                hasPhoto: true,
                breakoutMetrics: contained
            ),
            .enhancedMaskOnly
        )
    }

    func testSpotlightDiagnosticStatePreservesFailureStageAndErrorCode() {
        let visionFailure = SpotlightAnalysisDiagnostic.visionRequestFailed(
            domain: "com.apple.Vision",
            code: 9,
            message: "Could not create inference context"
        )
        XCTAssertEqual(visionFailure.markerLabel, "Fallback · Vision error 9")
        XCTAssertTrue(visionFailure.detail.contains("com.apple.Vision 9"))
        XCTAssertEqual(
            SpotlightDiagnosticState.resolve(
                mode: .auto,
                analysis: nil,
                isAnalyzing: false,
                hasPhoto: true,
                diagnostic: visionFailure
            ),
            .fallbackDiagnostic(visionFailure)
        )
        XCTAssertEqual(
            SpotlightAnalysisDiagnostic.ambiguousSubject.markerLabel,
            "Fallback · Ambiguous subject"
        )
        let detailedAmbiguity = SpotlightAnalysisDiagnostic.ambiguousSubjectDetails(
            candidateCount: 2,
            summary: "id 1 area 0.220 center 0.810 score 0.420 face 0.000"
        )
        XCTAssertTrue(detailedAmbiguity.detail.contains("2 candidates"))
        XCTAssertEqual(detailedAmbiguity.markerLabel, "Fallback · Ambiguous subject")

        let unusableSubject = SpotlightAnalysisDiagnostic.noUsableSubjectDetails(
            candidateCount: 2,
            summary: "id 1 area 0.001 center 0.118 score 0.042 face 0.000"
        )
        XCTAssertTrue(unusableSubject.detail.contains("minimum subject area"))
        XCTAssertEqual(unusableSubject.markerLabel, "Fallback · No usable subject")
    }

    func testSpotlightBreakoutEnvelopeProtectsNameRegionAndScalesUsableMode() {
        let photoRect = CGRect(x: 220, y: 155, width: 640, height: 820)
        let excellent = SpotlightBreakoutGeometry.envelope(photoRect: photoRect, breakout: 0.12, quality: .excellent)
        let usable = SpotlightBreakoutGeometry.envelope(photoRect: photoRect, breakout: 0.12, quality: .usable)

        XCTAssertLessThanOrEqual(excellent.maxY, SpotlightBreakoutGeometry.protectedNameTop)
        XCTAssertLessThanOrEqual(usable.maxY, SpotlightBreakoutGeometry.protectedNameTop)
        XCTAssertLessThan(usable.width, excellent.width)
        XCTAssertLessThan(usable.height, excellent.height)
    }

    func testSpotlightBreakoutMeasurementDetectsPixelsThatEscapePhotoFrame() throws {
        let mask = makeSyntheticMask(size: CGSize(width: 100, height: 100)) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 35, y: 0, width: 30, height: 28))
        }
        let photoRect = CGRect(x: 25, y: 25, width: 50, height: 50)
        let metrics = try XCTUnwrap(
            SpotlightBreakoutGeometry.measure(
                mask: try XCTUnwrap(mask.cgImage),
                crop: NormalizedPhotoCrop(x: 0, y: 0.2, width: 1, height: 0.6),
                photoRect: photoRect,
                envelope: photoRect.insetBy(dx: -25, dy: -25)
            )
        )

        XCTAssertGreaterThan(metrics.outsidePhotoFraction, 0.02)
        XCTAssertLessThanOrEqual(metrics.outsideEnvelopeFraction, 0.02)
        XCTAssertTrue(metrics.hasMeaningfulEscape)
    }

    private func makeAnalysis(quality: SpotlightSegmentationQuality) -> SpotlightAnalysisResult {
        let mask = makeMask().cgImage!
        return SpotlightAnalysisResult(
            mask: mask,
            processedMask: mask,
            rimLightMask: mask,
            quality: quality,
            maskBounds: CGRect(x: 0.26, y: 0.10, width: 0.48, height: 0.78),
            faceBounds: CGRect(x: 0.39, y: 0.13, width: 0.22, height: 0.16),
            personBounds: CGRect(x: 0.26, y: 0.10, width: 0.48, height: 0.78),
            cacheKey: "diagnostic-state-\(quality.rawValue)",
            wasCacheHit: false
        )
    }

    private var meaningfulBreakoutMetrics: SpotlightBreakoutGeometry.Metrics {
        SpotlightBreakoutGeometry.Metrics(
            sampledForegroundFraction: 0.30,
            outsidePhotoFraction: 0.08,
            outsideEnvelopeFraction: 0,
            protectedZoneFraction: 0
        )
    }

    func testSpotlightSourceIdentityChangesWhenSourceChanges() {
        let first = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let second = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }

        XCTAssertNotEqual(SpotlightAnalysisService.sourceIdentity(for: first), SpotlightAnalysisService.sourceIdentity(for: second))
    }

    func testSpotlightSubjectSelectorPrefersClearlyLargerCenteredCandidate() {
        let selection = SpotlightSubjectSelector.select([
            SpotlightSubjectCandidate(identifier: 1, bounds: CGRect(x: 0.04, y: 0.22, width: 0.20, height: 0.60), faceOverlap: 0.05),
            SpotlightSubjectCandidate(identifier: 2, bounds: CGRect(x: 0.24, y: 0.08, width: 0.54, height: 0.84), faceOverlap: 0.70)
        ])

        XCTAssertEqual(selection?.identifier, 2)
        XCTAssertEqual(selection?.reason, "largest centered candidate")
    }

    func testSpotlightSubjectSelectorFallsBackForGenuineTie() {
        let selection = SpotlightSubjectSelector.select([
            SpotlightSubjectCandidate(identifier: 1, bounds: CGRect(x: 0.18, y: 0.12, width: 0.40, height: 0.76), faceOverlap: 0.20),
            SpotlightSubjectCandidate(identifier: 2, bounds: CGRect(x: 0.42, y: 0.12, width: 0.40, height: 0.76), faceOverlap: 0.20)
        ])

        XCTAssertNil(selection)
    }

    func testSpotlightMaskProcessorKeepsFaceAnchoredSubjectAndDropsDistantIsland() throws {
        let image = makeSyntheticMask(size: CGSize(width: 160, height: 160)) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 48, y: 20, width: 58, height: 112))
            context.fill(CGRect(x: 117, y: 116, width: 30, height: 30))
        }

        let processed = try XCTUnwrap(
            SpotlightMaskProcessor.process(image.cgImage!, faceBounds: CGRect(x: 0.48, y: 0.18, width: 0.16, height: 0.14))
        )

        XCTAssertEqual(processed.mask.width, 160)
        XCTAssertEqual(processed.mask.height, 160)
        XCTAssertLessThan(processed.bounds.maxX, 0.75)
        XCTAssertEqual(processed.metrics.retainedComponentCount, 1)
        XCTAssertGreaterThan(processed.metrics.dominantComponentShare, 0.70)
    }

    func testSpotlightMaskProcessorFillsSmallHoleWithoutOpaqueHardEdge() throws {
        let image = makeSyntheticMask(size: CGSize(width: 120, height: 120)) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 30, y: 18, width: 60, height: 84))
            UIColor(white: 0.10, alpha: 1).setFill()
            context.fill(CGRect(x: 54, y: 54, width: 10, height: 10))
        }

        let processed = try XCTUnwrap(SpotlightMaskProcessor.process(image.cgImage!))
        let pixels = grayscalePixels(processed.mask)
        let center = pixels[60 * 120 + 59]
        let edge = pixels[60 * 120 + 30]

        XCTAssertGreaterThan(center, 0, "A small enclosed hole should be filled.")
        XCTAssertGreaterThan(edge, 0, "The retained subject should still reach its source boundary.")
        XCTAssertLessThan(edge, 255, "The processed edge should retain a subtle feather instead of a hard binary edge.")
    }

    func testSpotlightMaskProcessorRejectsLowConfidenceBackgroundAndSevereFragmentation() throws {
        let lowConfidence = makeSyntheticMask(size: CGSize(width: 100, height: 100)) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 28, y: 12, width: 44, height: 76))
            UIColor(white: 0.10, alpha: 1).setFill()
            context.fill(CGRect(x: 4, y: 4, width: 18, height: 18))
        }
        let cleaned = try XCTUnwrap(SpotlightMaskProcessor.process(lowConfidence.cgImage!))
        XCTAssertEqual(grayscalePixels(cleaned.mask)[10 * 100 + 10], 0)

        let fragmented = makeSyntheticMask(size: CGSize(width: 200, height: 200)) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 72, y: 24, width: 56, height: 150))
            for row in 0..<5 {
                for column in 0..<5 {
                    context.fill(CGRect(x: 4 + column * 36, y: 4 + row * 36, width: 12, height: 12))
                }
            }
        }
        let fragmentedResult = try XCTUnwrap(SpotlightMaskProcessor.process(fragmented.cgImage!))
        XCTAssertEqual(fragmentedResult.quality, .fallback)
        XCTAssertGreaterThan(fragmentedResult.metrics.rawComponentCount, 12)
    }

    func testSpotlightMaskProcessorRejectsDenseRectangularArtifact() throws {
        let image = makeSyntheticMask(size: CGSize(width: 160, height: 160)) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 38, y: 18, width: 84, height: 118))
        }

        let processed = try XCTUnwrap(SpotlightMaskProcessor.process(image.cgImage!))

        XCTAssertGreaterThan(processed.metrics.rectangularity, 0.90)
        XCTAssertEqual(processed.quality, .fallback)
    }

    func testSpotlightMaskProcessorIsDeterministicAndPreservesSoftSourceAlpha() throws {
        let image = makeSyntheticMask(size: CGSize(width: 96, height: 96)) { context in
            UIColor(white: 0.95, alpha: 1).setFill()
            context.fill(CGRect(x: 24, y: 12, width: 44, height: 72))
            UIColor(white: 0.30, alpha: 1).setFill()
            context.fill(CGRect(x: 34, y: 12, width: 24, height: 3))
        }

        let first = try XCTUnwrap(SpotlightMaskProcessor.process(image.cgImage!))
        let second = try XCTUnwrap(SpotlightMaskProcessor.process(image.cgImage!))

        XCTAssertEqual(grayscalePixels(first.mask), grayscalePixels(second.mask))
        XCTAssertEqual(first.metrics, second.metrics)
        XCTAssertGreaterThan(grayscalePixels(first.mask)[13 * 96 + 40], 0)
        XCTAssertLessThan(grayscalePixels(first.mask)[13 * 96 + 40], 255)
    }

    func testContactSheetAndLabExportProducePNG() throws {
        let fixtures = CardFixtureLibrary.comparisonFixtures(template: .clean(version: 2))
        let sheet = CardExportService.contactSheet(fixtures: fixtures)
        XCTAssertEqual(sheet.size, CGSize(width: 900, height: 840))
        XCTAssertNotNil(sheet.pngData())

        let url = try CardExportService.writePNG(sheet, named: "player-card-lab-test")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNotNil(UIImage(contentsOfFile: url.path))
    }

    func testBroadcastPreviewAndExportUseTheSameCanonicalPNG() throws {
        let rendered = PlayerCardArtworkRenderer.render(
            CardFixtureLibrary.fixture(id: "normal", template: .broadcast(version: 1)).model
        )
        XCTAssertEqual(rendered.size, CGSize(width: 1_080, height: 1_350))

        let url = try CardExportService.writePNG(rendered, named: "broadcast-typography-test")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(try Data(contentsOf: url), try XCTUnwrap(rendered.pngData()))
        XCTAssertNotNil(UIImage(contentsOfFile: url.path)?.cgImage)
    }

    private func makeMask() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1_400, height: 1_800)).image { rendererContext in
            UIColor.black.setFill()
            rendererContext.fill(CGRect(x: 0, y: 0, width: 1_400, height: 1_800))
            UIColor.white.setFill()
            rendererContext.fill(CGRect(x: 360, y: 180, width: 680, height: 1_400))
        }
    }

    private func makeSyntheticMask(size: CGSize, draw: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            UIColor.black.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
            draw(rendererContext)
        }
    }

    private func grayscalePixels(_ image: CGImage) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height)
        let context = CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }

    private struct RGBAPixel {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    private func rgbaPixels(_ image: UIImage) -> [UInt8] {
        let cgImage = image.cgImage!
        var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        let context = CGContext(
            data: &pixels,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return pixels
    }

    private func pixel(_ pixels: [UInt8], width: Int, x: Int, y: Int) -> RGBAPixel {
        let index = (y * width + x) * 4
        return RGBAPixel(red: pixels[index], green: pixels[index + 1], blue: pixels[index + 2], alpha: pixels[index + 3])
    }
}
