#if DEBUG
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import Vision

// MARK: - Candidate renderer model

/// The versioned, canonical artwork contract used by the development Lab.
/// It is deliberately separate from the 1.3 production PlayerCardRenderer
/// until the owner approves visual integration.
enum PlayerCardTemplate: Hashable, Sendable, CaseIterable {
    case clean(version: Int)
    case broadcast(version: Int)
    case spotlight(version: Int)

    static let allCases: [PlayerCardTemplate] = [.clean(version: 2), .broadcast(version: 1), .spotlight(version: 1)]

    var title: String {
        switch self {
        case .clean: return "Clean"
        case .broadcast: return "Broadcast"
        case .spotlight: return "Spotlight"
        }
    }

    var version: Int {
        switch self {
        case .clean(let version), .broadcast(let version), .spotlight(let version): return version
        }
    }
}

struct CardRGBColor: Equatable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    init(uiColor: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(red: red, green: green, blue: blue)
        } else {
            self = CardRGBColor(red: 0.98, green: 0.35, blue: 0.08)
        }
    }

    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
    var luminance: CGFloat { 0.2126 * red + 0.7152 * green + 0.0722 * blue }
    var swiftUIColor: Color { Color(uiColor: uiColor) }

    static let rollCallOrange = CardRGBColor(red: 1, green: 0.35, blue: 0.08)
    static let white = CardRGBColor(red: 1, green: 1, blue: 1)

    static func from(_ preset: TeamAccentPreset) -> CardRGBColor {
        CardRGBColor(uiColor: preset.theme.uiColor(.fill).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
    }
}

struct CleanDerivedColors: Sendable {
    let displayAccent: CardRGBColor
    let illuminationAccent: CardRGBColor
    let numberAccent: CardRGBColor
}

struct BroadcastDerivedColors: Sendable {
    let displayAccent: CardRGBColor
    let strongGraphicAccent: CardRGBColor
    let mutedGraphicAccent: CardRGBColor
    let illuminationAccent: CardRGBColor
    let contrastAccent: CardRGBColor
}

struct SpotlightDerivedColors: Sendable {
    let displayAccent: CardRGBColor
    let atmosphericAccent: CardRGBColor
    let rimLightAccent: CardRGBColor
    let numberAccent: CardRGBColor
    let planeAccent: CardRGBColor
    let contrastAccent: CardRGBColor
}

private enum CardColorMath {
    static func hsv(_ color: CardRGBColor) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        let maxValue = max(color.red, max(color.green, color.blue))
        let minValue = min(color.red, min(color.green, color.blue))
        let delta = maxValue - minValue
        var hue: CGFloat = 0
        if delta > 0.0001 {
            if maxValue == color.red {
                hue = ((color.green - color.blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == color.green {
                hue = (color.blue - color.red) / delta + 2
            } else {
                hue = (color.red - color.green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maxValue == 0 ? 0 : delta / maxValue, maxValue)
    }

    static func color(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> CardRGBColor {
        CardRGBColor(uiColor: UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1))
    }

    static func clamp(_ value: CGFloat, _ lower: CGFloat = 0, _ upper: CGFloat = 1) -> CGFloat {
        min(max(value, lower), upper)
    }

    static func readableAccent(from raw: CardRGBColor) -> CardRGBColor {
        let hsb = hsv(raw)
        let saturation = hsb.saturation < 0.08 ? 0.18 : clamp(max(hsb.saturation, 0.42), 0.42, 0.92)
        let brightness = raw.luminance > 0.82 ? 0.70 : max(hsb.brightness, 0.62)
        return color(hue: hsb.hue, saturation: saturation, brightness: clamp(brightness, 0.55, 0.88))
    }

    static func light(from raw: CardRGBColor, saturation: CGFloat, brightness: CGFloat) -> CardRGBColor {
        let hsb = hsv(raw)
        return color(hue: hsb.hue, saturation: clamp(saturation), brightness: clamp(brightness))
    }

    static func mix(_ lhs: CardRGBColor, _ rhs: CardRGBColor, amount: CGFloat) -> CardRGBColor {
        let t = clamp(amount)
        return CardRGBColor(
            red: lhs.red + (rhs.red - lhs.red) * t,
            green: lhs.green + (rhs.green - lhs.green) * t,
            blue: lhs.blue + (rhs.blue - lhs.blue) * t
        )
    }
}

enum CleanCardColorResolver {
    static func resolve(_ raw: CardRGBColor) -> CleanDerivedColors {
        let display = CardColorMath.readableAccent(from: raw)
        let illumination = CardColorMath.light(from: raw, saturation: max(CardColorMath.hsv(raw).saturation * 0.72, 0.20), brightness: 0.78)
        return CleanDerivedColors(displayAccent: display, illuminationAccent: illumination, numberAccent: CardColorMath.mix(display, .white, amount: 0.10))
    }
}

enum BroadcastCardColorResolver {
    static func resolve(_ raw: CardRGBColor) -> BroadcastDerivedColors {
        let display = CardColorMath.readableAccent(from: raw)
        let hsb = CardColorMath.hsv(raw)
        let strong = CardColorMath.light(from: raw, saturation: max(hsb.saturation, 0.48), brightness: max(hsb.brightness, 0.64))
        let muted = CardColorMath.light(from: raw, saturation: min(max(hsb.saturation * 0.55, 0.18), 0.60), brightness: min(max(hsb.brightness * 0.52, 0.18), 0.42))
        let illumination = CardColorMath.light(from: raw, saturation: min(max(hsb.saturation * 0.68, 0.18), 0.75), brightness: 0.70)
        let contrast = raw.luminance > 0.58 ? CardRGBColor(red: 0.04, green: 0.05, blue: 0.07) : CardRGBColor(red: 0.96, green: 0.97, blue: 1)
        return BroadcastDerivedColors(displayAccent: display, strongGraphicAccent: strong, mutedGraphicAccent: muted, illuminationAccent: illumination, contrastAccent: contrast)
    }
}

enum SpotlightCardColorResolver {
    static func resolve(_ raw: CardRGBColor) -> SpotlightDerivedColors {
        let hsb = CardColorMath.hsv(raw)
        let display = CardColorMath.readableAccent(from: raw)
        let atmosphere = CardColorMath.light(from: raw, saturation: min(max(hsb.saturation * 0.56, 0.16), 0.62), brightness: min(max(hsb.brightness * 0.55, 0.18), 0.46))
        let rim = CardColorMath.light(from: raw, saturation: min(max(hsb.saturation * 0.80, 0.24), 0.86), brightness: 0.82)
        let number = CardColorMath.mix(display, CardColorMath.light(from: raw, saturation: 0.35, brightness: 0.42), amount: 0.42)
        let plane = CardColorMath.light(from: raw, saturation: min(max(hsb.saturation * 0.48, 0.12), 0.52), brightness: 0.25)
        let contrast = raw.luminance > 0.58 ? CardRGBColor(red: 0.04, green: 0.05, blue: 0.07) : CardRGBColor(red: 0.96, green: 0.97, blue: 1)
        return SpotlightDerivedColors(displayAccent: display, atmosphericAccent: atmosphere, rimLightAccent: rim, numberAccent: number, planeAccent: plane, contrastAccent: contrast)
    }
}

struct SpotlightPhotoTransform: @unchecked Sendable {
    let sourceSize: CGSize
    let crop: NormalizedPhotoCrop
    let destinationFrame: CGRect

    var scale: CGFloat {
        let cropWidth = max(CGFloat(crop.width) * sourceSize.width, 1)
        let cropHeight = max(CGFloat(crop.height) * sourceSize.height, 1)
        return max(destinationFrame.width / cropWidth, destinationFrame.height / cropHeight)
    }

    var fullImageDestination: CGRect {
        let cropCenter = CGPoint(
            x: (CGFloat(crop.x) + CGFloat(crop.width) / 2) * sourceSize.width,
            y: (CGFloat(crop.y) + CGFloat(crop.height) / 2) * sourceSize.height
        )
        return CGRect(
            x: destinationFrame.midX - cropCenter.x * scale,
            y: destinationFrame.midY - cropCenter.y * scale,
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
    }

    func projectedSourceRect(_ normalizedRect: CGRect) -> CGRect {
        let destination = fullImageDestination
        return CGRect(
            x: destination.minX + normalizedRect.minX * destination.width,
            y: destination.minY + normalizedRect.minY * destination.height,
            width: normalizedRect.width * destination.width,
            height: normalizedRect.height * destination.height
        )
    }
}

enum SpotlightSegmentationBackend: String, CaseIterable, Hashable, Sendable {
    case personInstance
    case foregroundInstance

    var title: String {
        switch self {
        case .personInstance: return "Person instances"
        case .foregroundInstance: return "Foreground instances"
        }
    }

    var requestRevision: Int { 1 }
}

struct SpotlightMaskRasterDiagnostics: Equatable, Sendable {
    let width: Int
    let height: Int
    let bitsPerComponent: Int
    let bitsPerPixel: Int
    let bytesPerRow: Int
    let colorSpace: String
    let alphaInfo: UInt32
    let bitmapInfo: UInt32
    let isMask: Bool

    init(image: CGImage) {
        width = image.width
        height = image.height
        bitsPerComponent = image.bitsPerComponent
        bitsPerPixel = image.bitsPerPixel
        bytesPerRow = image.bytesPerRow
        colorSpace = image.colorSpace.map { String(describing: $0.name) } ?? "unknown"
        alphaInfo = image.alphaInfo.rawValue
        bitmapInfo = image.bitmapInfo.rawValue
        isMask = image.isMask
    }

    var summary: String {
        "\(width)×\(height) · \(bitsPerPixel)bpp · row \(bytesPerRow) · \(colorSpace) · alpha \(alphaInfo)"
    }
}

struct SpotlightAnalysisResult: @unchecked Sendable {
    let mask: CGImage
    let processedMask: CGImage
    let rimLightMask: CGImage
    let quality: SpotlightSegmentationQuality
    let maskMetrics: SpotlightMaskMetrics?
    let maskBounds: CGRect
    let faceBounds: CGRect?
    let personBounds: CGRect?
    let cacheKey: String
    let wasCacheHit: Bool
    let candidateCount: Int
    let selectionReason: String?
    let backend: SpotlightSegmentationBackend
    let requestRevision: Int
    let candidateDiagnostics: [SpotlightSubjectCandidate]
    let selectedInstanceIdentifier: Int?
    let maskRasterDiagnostics: SpotlightMaskRasterDiagnostics?

    init(
        mask: CGImage,
        processedMask: CGImage,
        rimLightMask: CGImage,
        quality: SpotlightSegmentationQuality,
        maskBounds: CGRect,
        faceBounds: CGRect?,
        personBounds: CGRect?,
        cacheKey: String,
        wasCacheHit: Bool,
        candidateCount: Int = 0,
        selectionReason: String? = nil,
        maskMetrics: SpotlightMaskMetrics? = nil,
        backend: SpotlightSegmentationBackend = .personInstance,
        requestRevision: Int = 1,
        candidateDiagnostics: [SpotlightSubjectCandidate] = [],
        selectedInstanceIdentifier: Int? = nil,
        maskRasterDiagnostics: SpotlightMaskRasterDiagnostics? = nil
    ) {
        self.mask = mask
        self.processedMask = processedMask
        self.rimLightMask = rimLightMask
        self.quality = quality
        self.maskMetrics = maskMetrics
        self.maskBounds = maskBounds
        self.faceBounds = faceBounds
        self.personBounds = personBounds
        self.cacheKey = cacheKey
        self.wasCacheHit = wasCacheHit
        self.candidateCount = candidateCount
        self.selectionReason = selectionReason
        self.backend = backend
        self.requestRevision = requestRevision
        self.candidateDiagnostics = candidateDiagnostics
        self.selectedInstanceIdentifier = selectedInstanceIdentifier
        self.maskRasterDiagnostics = maskRasterDiagnostics
    }
}

enum SpotlightAnalysisDiagnostic: Equatable, Sendable {
    case notAnalyzed
    case analyzing
    case completed
    case imageUnavailable
    case visionRequestFailed(domain: String, code: Int, message: String)
    case noObservation
    case noInstances
    case maskGenerationFailed(domain: String, code: Int, message: String)
    case maskConversionFailed
    case emptyMask
    case noCandidateMasks
    case noUsableSubjectDetails(candidateCount: Int, summary: String)
    case ambiguousSubject
    case ambiguousSubjectDetails(candidateCount: Int, summary: String)
    case cancelled

    var detail: String {
        switch self {
        case .notAnalyzed: return "Not analyzed"
        case .analyzing: return "Vision analysis in progress"
        case .completed: return "Vision analysis completed"
        case .imageUnavailable: return "Could not create a working CGImage"
        case let .visionRequestFailed(domain, code, message): return "Vision request failed (\(domain) \(code)): \(message)"
        case .noObservation: return "Vision returned no instance-mask observation"
        case .noInstances: return "Vision returned an observation with no foreground instances"
        case let .maskGenerationFailed(domain, code, message): return "Instance mask generation failed (\(domain) \(code)): \(message)"
        case .maskConversionFailed: return "Generated mask could not be converted to CGImage"
        case .emptyMask: return "Generated mask contained no foreground pixels"
        case .noCandidateMasks: return "No instance mask survived mask generation or conversion"
        case let .noUsableSubjectDetails(candidateCount, summary): return "No candidate exceeded the minimum subject area (0.003); received \(candidateCount) raw mask\(candidateCount == 1 ? "" : "s"): \(summary)"
        case .ambiguousSubject: return "Multiple subjects were too close to select safely"
        case let .ambiguousSubjectDetails(candidateCount, summary): return "Subject selection rejected \(candidateCount) candidates: \(summary)"
        case .cancelled: return "Analysis task was cancelled before completion"
        }
    }

    var markerLabel: String {
        switch self {
        case .notAnalyzed: return "Mask: Not analyzed"
        case .analyzing: return "Fallback · Analyzing"
        case .completed: return "Mask: Complete"
        case .imageUnavailable: return "Fallback · Image unavailable"
        case let .visionRequestFailed(_, code, _): return "Fallback · Vision error \(code)"
        case .noObservation: return "Fallback · No observation"
        case .noInstances: return "Fallback · No instances"
        case .maskGenerationFailed: return "Fallback · Mask generation failed"
        case .maskConversionFailed: return "Fallback · Mask conversion failed"
        case .emptyMask: return "Fallback · Empty mask"
        case .noCandidateMasks: return "Fallback · No candidate masks"
        case .noUsableSubjectDetails: return "Fallback · No usable subject"
        case .ambiguousSubject, .ambiguousSubjectDetails: return "Fallback · Ambiguous subject"
        case .cancelled: return "Fallback · Analysis cancelled"
        }
    }
}

struct SpotlightAnalysisReport: @unchecked Sendable {
    let result: SpotlightAnalysisResult?
    let diagnostic: SpotlightAnalysisDiagnostic
}

enum SpotlightSegmentationQuality: String, CaseIterable, Sendable {
    case excellent
    case usable
    case fallback
}

/// The subject-selection policy is intentionally deterministic and testable outside Vision.
/// Area is the strongest signal; proximity to the frame center breaks close calls, with a face
/// overlap used only as a small tie-breaker. A genuinely close tie still falls back conservatively.
struct SpotlightSubjectCandidate: Equatable, Sendable {
    let identifier: Int
    let bounds: CGRect
    let faceOverlap: CGFloat
    let foregroundCoverage: CGFloat

    init(identifier: Int, bounds: CGRect, faceOverlap: CGFloat, foregroundCoverage: CGFloat = 0) {
        self.identifier = identifier
        self.bounds = bounds
        self.faceOverlap = faceOverlap
        self.foregroundCoverage = foregroundCoverage
    }

    var area: CGFloat { max(0, bounds.width * bounds.height) }

    func centerScore(target: CGPoint = CGPoint(x: 0.5, y: 0.46)) -> CGFloat {
        let distance = hypot(bounds.midX - target.x, bounds.midY - target.y)
        return max(0, 1 - distance / 0.72)
    }

    func score(target: CGPoint = CGPoint(x: 0.5, y: 0.46)) -> CGFloat {
        min(max(area * 0.60 + centerScore(target: target) * 0.35 + faceOverlap * 0.05, 0), 1)
    }
}

enum SpotlightSubjectSelector {
    struct Selection: Equatable, Sendable {
        let identifier: Int
        let score: CGFloat
        let reason: String
    }

    static func select(_ candidates: [SpotlightSubjectCandidate]) -> Selection? {
        let ranked = candidates
            .filter { $0.area > minimumCandidateArea }
            .sorted { lhs, rhs in
                if lhs.score() == rhs.score() { return lhs.area > rhs.area }
                return lhs.score() > rhs.score()
            }
        guard let best = ranked.first else { return nil }
        guard let runnerUp = ranked.dropFirst().first else {
            return Selection(identifier: best.identifier, score: best.score(), reason: "only candidate")
        }

        let areaRatio = best.area / max(runnerUp.area, 0.0001)
        let centerAdvantage = best.centerScore() - runnerUp.centerScore()
        let scoreMargin = best.score() - runnerUp.score()
        let isClearlyLarger = areaRatio >= 1.18
        let isClearlyCentered = centerAdvantage >= 0.10
        let hasDecisiveOverallScore = scoreMargin >= 0.055
        guard isClearlyLarger || isClearlyCentered || hasDecisiveOverallScore else {
            return nil
        }

        let reason: String
        if isClearlyLarger && isClearlyCentered {
            reason = "largest centered candidate"
        } else if isClearlyLarger {
            reason = "largest candidate"
        } else if isClearlyCentered {
            reason = "most centered candidate"
        } else {
            reason = "strongest ranked candidate"
        }
        return Selection(identifier: best.identifier, score: best.score(), reason: reason)
    }

    static let minimumCandidateArea: CGFloat = 0.003
}

struct SpotlightMaskMetrics: Equatable, Sendable {
    let foregroundCoverage: CGFloat
    let boundsArea: CGFloat
    let density: CGFloat
    let rawComponentCount: Int
    let retainedComponentCount: Int
    let dominantComponentShare: CGFloat
    let removedForegroundFraction: CGFloat
    let boundaryContactRatio: CGFloat
    let edgeRoughness: CGFloat
    let rectangularity: CGFloat
    let faceOverlap: CGFloat

    var touchesBoundary: Bool {
        boundaryContactRatio > 0 || boundsArea >= 0.98
    }

    var summary: String {
        String(
            format: "coverage %.3f · density %.2f · components %d/%d · removed %.2f · edge %.2f · rect %.2f",
            foregroundCoverage,
            density,
            retainedComponentCount,
            rawComponentCount,
            removedForegroundFraction,
            edgeRoughness,
            rectangularity
        )
    }
}

struct SpotlightMaskProcessingResult: @unchecked Sendable {
    let mask: CGImage
    let bounds: CGRect
    let metrics: SpotlightMaskMetrics
    let quality: SpotlightSegmentationQuality
}

/// Deterministic cleanup for Vision's soft person mattes.
///
/// This intentionally operates on a bounded working raster. It uses the raw alpha values for the
/// final mask, while using a hysteresis support mask only for topology decisions. That prevents
/// low-confidence background pixels from becoming opaque without turning the result into a hard
/// silhouette.
enum SpotlightMaskProcessor {
    static let strongThreshold: UInt8 = 128
    static let supportThreshold: UInt8 = 64
    static let maximumWorkingDimension = 512

    static func process(_ image: CGImage, faceBounds: CGRect? = nil) -> SpotlightMaskProcessingResult? {
        guard let raster = Raster(image: image, maximumDimension: maximumWorkingDimension) else { return nil }

        let originalSupport = raster.pixels.map { $0 >= supportThreshold }
        let strongSupport = raster.pixels.map { $0 >= strongThreshold }
        guard originalSupport.contains(true), strongSupport.contains(true) else { return nil }

        let closedSupport = close(originalSupport, width: raster.width, height: raster.height)
        let minimumComponentArea = max(4, Int(Double(raster.width * raster.height) * 0.00015))
        let allComponents = components(in: closedSupport, strongSupport: strongSupport, width: raster.width, height: raster.height)
        let credibleComponents = allComponents.filter { $0.area >= minimumComponentArea && $0.containsStrongSupport }
        guard let primary = primaryComponent(in: credibleComponents, faceBounds: faceBounds, width: raster.width, height: raster.height) else { return nil }

        let attachmentRadius = max(2, Int(ceil(Double(min(raster.width, raster.height)) * 0.018)))
        let attachmentBounds = primary.bounds.insetBy(dx: -CGFloat(attachmentRadius), dy: -CGFloat(attachmentRadius))
        var retainedComponents = [primary]
        for component in credibleComponents where component.id != primary.id {
            let isSubordinate = Double(component.area) <= max(12, Double(primary.area) * 0.18)
            let isAttached = attachmentBounds.intersects(component.bounds)
            if isSubordinate && isAttached {
                retainedComponents.append(component)
            }
        }

        var cleanedSupport = [Bool](repeating: false, count: raster.width * raster.height)
        for component in retainedComponents {
            for index in component.pixels {
                cleanedSupport[index] = true
            }
        }
        let filledPixels = fillSmallHoles(in: &cleanedSupport, width: raster.width, height: raster.height)
        guard let cleanedBounds = normalizedBounds(of: cleanedSupport, width: raster.width, height: raster.height) else { return nil }

        let retainedSupportCount = cleanedSupport.reduce(into: 0) { count, isForeground in
            if isForeground { count += 1 }
        }
        guard retainedSupportCount > 0 else { return nil }

        let baseAlpha = raster.pixels.enumerated().map { index, value in
            guard cleanedSupport[index] else { return UInt8(0) }
            // Pixels added by small-hole filling have no source alpha. Make them solid enough to
            // close the hole, while retaining the original matte everywhere else.
            return filledPixels[index] ? UInt8(220) : value
        }
        let featheredAlpha = feather(baseAlpha, support: cleanedSupport, width: raster.width, height: raster.height)
        guard let workingImage = makeGrayImage(bytes: featheredAlpha, width: raster.width, height: raster.height),
              let outputImage = raster.resizeToOriginal(workingImage) else { return nil }

        let rawSupportCount = originalSupport.reduce(into: 0) { count, isForeground in
            if isForeground { count += 1 }
        }
        let primaryShare = CGFloat(primary.area) / CGFloat(max(rawSupportCount, 1))
        let removedFraction = CGFloat(max(0, rawSupportCount - retainedSupportCount)) / CGFloat(max(rawSupportCount, 1))
        let boundaryCount = cleanedSupport.enumerated().reduce(into: 0) { count, item in
            guard item.element else { return }
            let x = item.offset % raster.width
            let y = item.offset / raster.width
            if x == 0 || y == 0 || x == raster.width - 1 || y == raster.height - 1 { count += 1 }
        }
        let edgeCount = cleanedSupport.enumerated().reduce(into: 0) { count, item in
            guard item.element else { return }
            let x = item.offset % raster.width
            let y = item.offset / raster.width
            if neighbors(x: x, y: y, width: raster.width, height: raster.height).contains(where: { !cleanedSupport[$0] }) {
                count += 1
            }
        }
        let boundsArea = cleanedBounds.width * cleanedBounds.height
        let coverage = CGFloat(retainedSupportCount) / CGFloat(raster.width * raster.height)
        let rectangularity = edgeOccupancy(of: cleanedSupport, bounds: cleanedBounds, width: raster.width, height: raster.height)
        let metrics = SpotlightMaskMetrics(
            foregroundCoverage: coverage,
            boundsArea: boundsArea,
            density: coverage / max(boundsArea, 0.0001),
            rawComponentCount: allComponents.count,
            retainedComponentCount: retainedComponents.count,
            dominantComponentShare: min(max(primaryShare, 0), 1),
            removedForegroundFraction: min(max(removedFraction, 0), 1),
            boundaryContactRatio: CGFloat(boundaryCount) / CGFloat(max(retainedSupportCount, 1)),
            edgeRoughness: CGFloat(edgeCount) / CGFloat(max(retainedSupportCount, 1)),
            rectangularity: rectangularity,
            faceOverlap: faceBounds.map { overlap($0, cleanedBounds) } ?? 1
        )
        return SpotlightMaskProcessingResult(
            mask: outputImage,
            bounds: cleanedBounds,
            metrics: metrics,
            quality: classify(metrics)
        )
    }

    private struct Raster {
        let width: Int
        let height: Int
        let originalWidth: Int
        let originalHeight: Int
        let pixels: [UInt8]

        init?(image: CGImage, maximumDimension: Int) {
            let originalWidth = image.width
            let originalHeight = image.height
            guard originalWidth > 0, originalHeight > 0 else { return nil }
            let scale = min(1, CGFloat(maximumDimension) / CGFloat(max(originalWidth, originalHeight)))
            let width = max(1, Int((CGFloat(originalWidth) * scale).rounded()))
            let height = max(1, Int((CGFloat(originalHeight) * scale).rounded()))
            var pixels = [UInt8](repeating: 0, count: width * height)
            guard let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            self.width = width
            self.height = height
            self.originalWidth = originalWidth
            self.originalHeight = originalHeight
            self.pixels = pixels
        }

        func resizeToOriginal(_ image: CGImage) -> CGImage? {
            guard width != originalWidth || height != originalHeight else { return image }
            var pixels = [UInt8](repeating: 0, count: originalWidth * originalHeight)
            guard let context = CGContext(
                data: &pixels,
                width: originalWidth,
                height: originalHeight,
                bitsPerComponent: 8,
                bytesPerRow: originalWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight))
            return context.makeImage()
        }
    }

    private struct Component {
        let id: Int
        let pixels: [Int]
        let bounds: CGRect
        let containsStrongSupport: Bool

        var area: Int { pixels.count }
    }

    private static func components(in mask: [Bool], strongSupport: [Bool], width: Int, height: Int) -> [Component] {
        var visited = [Bool](repeating: false, count: mask.count)
        var result: [Component] = []
        var nextID = 0
        for start in mask.indices where mask[start] && !visited[start] {
            var queue = [start]
            var pixels: [Int] = []
            var cursor = 0
            var minX = width
            var minY = height
            var maxX = 0
            var maxY = 0
            var containsStrong = false
            visited[start] = true
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                pixels.append(index)
                let x = index % width
                let y = index / width
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
                containsStrong = containsStrong || strongSupport[index]
                for neighbor in neighbors(x: x, y: y, width: width, height: height) where mask[neighbor] && !visited[neighbor] {
                    visited[neighbor] = true
                    queue.append(neighbor)
                }
            }
            result.append(Component(id: nextID, pixels: pixels, bounds: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1), containsStrongSupport: containsStrong))
            nextID += 1
        }
        return result
    }

    private static func primaryComponent(in components: [Component], faceBounds: CGRect?, width: Int, height: Int) -> Component? {
        guard !components.isEmpty else { return nil }
        if let faceBounds {
            let center = CGPoint(x: faceBounds.midX * CGFloat(width), y: faceBounds.midY * CGFloat(height))
            if let anchored = components.min(by: { distance(from: center, to: $0.bounds) < distance(from: center, to: $1.bounds) }) {
                let maximumFaceDistance = CGFloat(max(width, height)) * 0.16
                if distance(from: center, to: anchored.bounds) <= maximumFaceDistance {
                    return anchored
                }
            }
        }
        return components.max { lhs, rhs in lhs.area < rhs.area }
    }

    private static func close(_ mask: [Bool], width: Int, height: Int) -> [Bool] {
        let dilated = morphological(mask, width: width, height: height, requireAll: false)
        return morphological(dilated, width: width, height: height, requireAll: true)
    }

    private static func morphological(_ mask: [Bool], width: Int, height: Int, requireAll: Bool) -> [Bool] {
        mask.indices.map { index in
            let x = index % width
            let y = index / width
            let samples = [index] + neighbors(x: x, y: y, width: width, height: height)
            return requireAll ? samples.allSatisfy { mask[$0] } : samples.contains { mask[$0] }
        }
    }

    private static func fillSmallHoles(in mask: inout [Bool], width: Int, height: Int) -> [Bool] {
        let maximumHoleArea = max(8, Int(Double(width * height) * 0.008))
        var visited = [Bool](repeating: false, count: mask.count)
        var filled = [Bool](repeating: false, count: mask.count)
        for start in mask.indices where !mask[start] && !visited[start] {
            var queue = [start]
            var cursor = 0
            var touchesBoundary = false
            visited[start] = true
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                let x = index % width
                let y = index / width
                touchesBoundary = touchesBoundary || x == 0 || y == 0 || x == width - 1 || y == height - 1
                for neighbor in orthogonalNeighbors(x: x, y: y, width: width, height: height) where !mask[neighbor] && !visited[neighbor] {
                    visited[neighbor] = true
                    queue.append(neighbor)
                }
            }
            if !touchesBoundary && queue.count <= maximumHoleArea {
                for index in queue {
                    mask[index] = true
                    filled[index] = true
                }
            }
        }
        return filled
    }

    private static func feather(_ alpha: [UInt8], support: [Bool], width: Int, height: Int) -> [UInt8] {
        let weights = [1, 2, 1, 2, 4, 2, 1, 2, 1]
        return alpha.indices.map { index in
            guard support[index] else { return UInt8(0) }
            let x = index % width
            let y = index / width
            var weightedTotal = 0
            var weightTotal = 0
            for (offset, weight) in weights.enumerated() {
                let dx = (offset % 3) - 1
                let dy = (offset / 3) - 1
                let sampleX = x + dx
                let sampleY = y + dy
                guard sampleX >= 0, sampleY >= 0, sampleX < width, sampleY < height else { continue }
                let sample = sampleY * width + sampleX
                weightedTotal += Int(alpha[sample]) * weight
                weightTotal += weight
            }
            return UInt8(min(255, max(0, Int((Double(weightedTotal) / Double(max(weightTotal, 1))).rounded()))))
        }
    }

    private static func makeGrayImage(bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        var bytes = bytes
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        return context.makeImage()
    }

    private static func normalizedBounds(of mask: [Bool], width: Int, height: Int) -> CGRect? {
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var count = 0
        for index in mask.indices where mask[index] {
            let x = index % width
            let y = index / width
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
            count += 1
        }
        guard count > 0 else { return nil }
        return CGRect(x: CGFloat(minX) / CGFloat(width), y: CGFloat(minY) / CGFloat(height), width: CGFloat(maxX - minX + 1) / CGFloat(width), height: CGFloat(maxY - minY + 1) / CGFloat(height))
    }

    private static func edgeOccupancy(of mask: [Bool], bounds: CGRect, width: Int, height: Int) -> CGFloat {
        let minX = min(width - 1, max(0, Int(bounds.minX * CGFloat(width))))
        let minY = min(height - 1, max(0, Int(bounds.minY * CGFloat(height))))
        let maxX = min(width - 1, max(minX, Int(ceil(bounds.maxX * CGFloat(width))) - 1))
        let maxY = min(height - 1, max(minY, Int(ceil(bounds.maxY * CGFloat(height))) - 1))
        var top = 0
        var bottom = 0
        var left = 0
        var right = 0
        for x in minX...maxX {
            if mask[minY * width + x] { top += 1 }
            if mask[maxY * width + x] { bottom += 1 }
        }
        for y in minY...maxY {
            if mask[y * width + minX] { left += 1 }
            if mask[y * width + maxX] { right += 1 }
        }
        let horizontalLength = max(1, maxX - minX + 1)
        let verticalLength = max(1, maxY - minY + 1)
        return (CGFloat(top + bottom) / CGFloat(horizontalLength * 2) + CGFloat(left + right) / CGFloat(verticalLength * 2)) / 2
    }

    private static func classify(_ metrics: SpotlightMaskMetrics) -> SpotlightSegmentationQuality {
        guard metrics.foregroundCoverage >= 0.004,
              metrics.boundsArea >= 0.01,
              metrics.boundsArea < 0.98,
              metrics.density >= 0.10,
              metrics.dominantComponentShare >= 0.45,
              metrics.removedForegroundFraction <= 0.72,
              metrics.edgeRoughness <= 0.42,
              metrics.faceOverlap >= 0.08 else {
            return .fallback
        }
        if metrics.rawComponentCount > 12 {
            return .fallback
        }
        if metrics.density >= 0.75 && metrics.rectangularity >= 0.90 {
            return .fallback
        }
        let coherent = metrics.density >= 0.18 && metrics.dominantComponentShare >= 0.70 && metrics.removedForegroundFraction <= 0.35 && metrics.edgeRoughness <= 0.32 && metrics.retainedComponentCount <= 3
        guard coherent else { return .usable }
        if metrics.boundsArea > 0.10 && metrics.boundsArea < 0.86 && metrics.boundaryContactRatio == 0 && metrics.retainedComponentCount == 1 {
            return .excellent
        }
        return .usable
    }

    private static func overlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return min(max(intersection.width * intersection.height / max(lhs.width * lhs.height, 0.0001), 0), 1)
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(max(rect.minX - point.x, point.x - rect.maxX), 0)
        let dy = max(max(rect.minY - point.y, point.y - rect.maxY), 0)
        return hypot(dx, dy)
    }

    private static func neighbors(x: Int, y: Int, width: Int, height: Int) -> [Int] {
        var result: [Int] = []
        for dy in -1...1 {
            for dx in -1...1 where dx != 0 || dy != 0 {
                let sampleX = x + dx
                let sampleY = y + dy
                if sampleX >= 0, sampleY >= 0, sampleX < width, sampleY < height {
                    result.append(sampleY * width + sampleX)
                }
            }
        }
        return result
    }

    private static func orthogonalNeighbors(x: Int, y: Int, width: Int, height: Int) -> [Int] {
        [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].compactMap { sampleX, sampleY in
            guard sampleX >= 0, sampleY >= 0, sampleX < width, sampleY < height else { return nil }
            return sampleY * width + sampleX
        }
    }
}

enum SpotlightSegmentationMode: String, CaseIterable, Sendable {
    case auto
    case forceExcellent
    case forceUsable
    case forceFallback

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .forceExcellent: return "Force Excellent"
        case .forceUsable: return "Force Usable"
        case .forceFallback: return "Force Fallback"
        }
    }
}

enum SpotlightDiagnosticState: Equatable, Sendable {
    case notAnalyzed
    case fallbackAnalyzing
    case fallbackNoUsableMask
    case enhancedUsable
    case enhancedExcellent
    case enhancedMaskOnly
    case forcedFallback
    case forcedUsable
    case forcedExcellent
    case fallbackDiagnostic(SpotlightAnalysisDiagnostic)
    case noPhoto

    static func resolve(
        mode: SpotlightSegmentationMode,
        analysis: SpotlightAnalysisResult?,
        isAnalyzing: Bool,
        hasPhoto: Bool,
        diagnostic: SpotlightAnalysisDiagnostic? = nil,
        breakoutMetrics: SpotlightBreakoutGeometry.Metrics? = nil
    ) -> SpotlightDiagnosticState {
        guard hasPhoto else { return .noPhoto }
        if isAnalyzing && analysis == nil { return .fallbackAnalyzing }
        guard let analysis else {
            switch diagnostic {
            case .notAnalyzed, .analyzing, .completed, nil: return .notAnalyzed
            default: return .fallbackDiagnostic(diagnostic!)
            }
        }

        switch mode {
        case .auto:
            switch analysis.quality {
            case .excellent: return breakoutMetrics?.hasMeaningfulEscape == true ? .enhancedExcellent : .enhancedMaskOnly
            case .usable: return breakoutMetrics?.hasMeaningfulEscape == true ? .enhancedUsable : .enhancedMaskOnly
            case .fallback: return .fallbackNoUsableMask
            }
        case .forceExcellent: return .forcedExcellent
        case .forceUsable: return .forcedUsable
        case .forceFallback: return .forcedFallback
        }
    }

    var label: String {
        switch self {
        case .notAnalyzed: return "Mask: Not analyzed"
        case .fallbackAnalyzing: return "Fallback · Analyzing"
        case .fallbackNoUsableMask: return "Fallback · No usable mask"
        case .enhancedUsable: return "Enhanced · Usable"
        case .enhancedExcellent: return "Enhanced · Excellent"
        case .enhancedMaskOnly: return "Mask good · no visible escape"
        case .forcedFallback: return "Forced Fallback"
        case .forcedUsable: return "Forced Usable"
        case .forcedExcellent: return "Forced Excellent"
        case .fallbackDiagnostic(let diagnostic): return diagnostic.markerLabel
        case .noPhoto: return "Mask: No photo"
        }
    }

    var role: StatusChipRole {
        switch self {
        case .enhancedExcellent, .forcedExcellent: return .live
        case .enhancedUsable, .forcedUsable, .enhancedMaskOnly: return .ready
        case .noPhoto: return .disabled
        case .notAnalyzed, .fallbackAnalyzing, .fallbackNoUsableMask, .forcedFallback, .fallbackDiagnostic: return .neutral
        }
    }

    var systemImage: String {
        switch self {
        case .notAnalyzed: return "questionmark.circle"
        case .fallbackAnalyzing: return "hourglass"
        case .fallbackNoUsableMask: return "rectangle.on.rectangle"
        case .enhancedUsable: return "checkmark.circle"
        case .enhancedExcellent: return "sparkles"
        case .enhancedMaskOnly: return "viewfinder"
        case .forcedFallback, .forcedUsable, .forcedExcellent: return "wand.and.stars"
        case .fallbackDiagnostic(let diagnostic): return diagnostic == .analyzing ? "hourglass" : "exclamationmark.triangle"
        case .noPhoto: return "photo"
        }
    }
}

struct PlayerCardLabTuning: Equatable, Sendable {
    var cleanGradientStart: CGFloat = 0.35
    var cleanGradientStrength: CGFloat = 1.00
    var cleanNameY: CGFloat = 785
    var cleanEdgeLight: CGFloat = 0.55

    var broadcastAngle: CGFloat = 10.0
    var broadcastLowerThirdY: CGFloat = 865.00
    var broadcastPlaneOpacity: CGFloat = 0.40
    var broadcastNumberOpacity: CGFloat = 0.60
    var broadcastGiantNumberY: CGFloat = 650.00
    var broadcastPhotoHeight: CGFloat = 1_020
    var broadcastNameY: CGFloat = 850
    var broadcastMusicY: CGFloat = 1_080

    var spotlightPhotoWidth: CGFloat = 640
    var spotlightPhotoHeight: CGFloat = 820
    var spotlightPhotoY: CGFloat = 155
    var spotlightAtmosphere: CGFloat = 0.34
    var spotlightGiantNumberOpacity: CGFloat = 0.30
    var spotlightRimLight: CGFloat = 0.34
    var spotlightBreakout: CGFloat = 0.12

    static let `default` = PlayerCardLabTuning()
}

struct PlayerCardModel: @unchecked Sendable {
    static let canvasSize = CGSize(width: 1_080, height: 1_350)
    static let cardSafeInset: CGFloat = 70

    let template: PlayerCardTemplate
    let playerName: String
    let firstName: String?
    let lastName: String
    let playerNumber: String?
    let teamName: String?
    let songTitle: String?
    let artistName: String?
    let teamColor: CardRGBColor
    let photo: UIImage?
    let crop: NormalizedPhotoCrop
    let spotlightAnalysis: SpotlightAnalysisResult?
    let segmentationMode: SpotlightSegmentationMode
    let tuning: PlayerCardLabTuning
    let brandIcon: UIImage?

    init(
        template: PlayerCardTemplate,
        playerName: String,
        playerNumber: String?,
        teamName: String?,
        songTitle: String?,
        artistName: String?,
        teamColor: CardRGBColor,
        photo: UIImage?,
        crop: NormalizedPhotoCrop? = nil,
        spotlightAnalysis: SpotlightAnalysisResult? = nil,
        segmentationMode: SpotlightSegmentationMode = .auto,
        tuning: PlayerCardLabTuning = .default,
        brandIcon: UIImage? = nil
    ) {
        self.template = template
        let normalizedName = playerName.cardTrimmed
        let parts = normalizedName.split(separator: " ").map(String.init)
        self.playerName = normalizedName
        self.firstName = parts.count > 1 ? parts.dropLast().joined(separator: " ").cardNilIfBlank : nil
        self.lastName = (parts.last ?? normalizedName).cardTrimmed
        self.playerNumber = playerNumber?.cardNilIfBlank
        self.teamName = teamName?.cardNilIfBlank
        self.songTitle = songTitle?.cardNilIfBlank
        self.artistName = artistName?.cardNilIfBlank
        self.teamColor = teamColor
        self.photo = photo
        self.crop = crop ?? (photo.map { PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: $0.size) } ?? .full)
        self.spotlightAnalysis = spotlightAnalysis
        self.segmentationMode = segmentationMode
        self.tuning = tuning
        self.brandIcon = brandIcon ?? PlayerCardArtworkRenderer.bundledBrandIcon
    }

    init(
        template: PlayerCardTemplate,
        player: Player,
        team: Team,
        photo: UIImage?,
        teamColorOverride: CardRGBColor? = nil,
        spotlightAnalysis: SpotlightAnalysisResult? = nil,
        segmentationMode: SpotlightSegmentationMode = .auto,
        tuning: PlayerCardLabTuning = .default
    ) {
        let content = PlayerCardContent(player: player, team: team)
        self.init(
            template: template,
            playerName: content.playerName,
            playerNumber: content.playerNumber,
            teamName: content.teamName,
            songTitle: content.songTitle,
            artistName: content.artistName,
            teamColor: teamColorOverride ?? CardRGBColor.from(content.accentPreset),
            photo: photo,
            crop: player.playerCardPhotoCrop,
            spotlightAnalysis: spotlightAnalysis,
            segmentationMode: segmentationMode,
            tuning: tuning
        )
    }
}

// MARK: - Shared canonical drawing primitives

enum PlayerCardArtworkRenderer {
    static let outputSize = PlayerCardModel.canvasSize
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    static func stableSeed(_ value: String) -> Int {
        value.utf8.reduce(17) { ($0 &* 31) &+ Int($1) } & 0x7FFF
    }

    static let bundledBrandIcon: UIImage? = {
        guard let image = UIImage(named: "AppIcon-iOS-Default-1024@1x"), image.size.width > 0, image.size.height > 0 else { return nil }
        return image
    }()

    static func render(_ model: PlayerCardModel) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.setFillColor(UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: 1).cgColor)
            context.fill(CGRect(origin: .zero, size: outputSize))
            switch model.template {
            case .clean:
                CleanPlayerCardRenderer.draw(model, in: context)
            case .broadcast:
                BroadcastPlayerCardRenderer.draw(model, in: context)
            case .spotlight:
                SpotlightPlayerCardRenderer.draw(model, in: context)
            }
        }
    }

    static func drawBackground(in context: CGContext, accent: CardRGBColor, atmosphere: CGFloat = 0.08) {
        let colors = [
            UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: 1).cgColor,
            accent.uiColor.withAlphaComponent(atmosphere).cgColor,
            UIColor(red: 0.015, green: 0.019, blue: 0.03, alpha: 1).cgColor
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: sRGB, colors: colors, locations: [0, 0.52, 1]) else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: 80, y: 40), end: CGPoint(x: 1_000, y: 1_350), options: [])
    }

    static func drawPhoto(_ image: UIImage?, crop: NormalizedPhotoCrop, in rect: CGRect, context: CGContext, cornerRadius: CGFloat, edgeLight: CardRGBColor? = nil, edgeLightStrength: CGFloat = 0) {
        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
        if let image, let cgImage = image.rollCallNormalizedUpImage().cgImage {
            drawFullImage(cgImage, crop: crop, in: rect, context: context)
            if let edgeLight {
                let colors = [edgeLight.uiColor.withAlphaComponent(edgeLightStrength).cgColor, UIColor.clear.cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: sRGB, colors: colors, locations: [0, 1]) {
                    context.drawRadialGradient(gradient, startCenter: CGPoint(x: rect.minX, y: rect.minY), startRadius: 2, endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: max(rect.width, rect.height) * 0.92, options: [])
                }
            }
        } else {
            context.setFillColor(UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1).cgColor)
            context.fill(rect)
            drawText("PHOTO REQUIRED", in: rect.insetBy(dx: 24, dy: 24), font: .systemFont(ofSize: 24, weight: .semibold), color: .white.withAlphaComponent(0.54), alignment: .center, context: context)
        }
        context.restoreGState()
    }

    /// A localized wash at the photo edges. This deliberately avoids a uniform border or full-photo tint.
    static func drawAsymmetricEdgeLight(in rect: CGRect, accent: CardRGBColor, strength: CGFloat, context: CGContext, cornerRadius: CGFloat) {
        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
        let leftColors = [accent.uiColor.withAlphaComponent(strength).cgColor, UIColor.clear.cgColor] as CFArray
        if let left = CGGradient(colorsSpace: sRGB, colors: leftColors, locations: [0, 1]) {
            context.drawLinearGradient(left, start: CGPoint(x: rect.minX, y: rect.midY), end: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.midY), options: [])
        }
        let rightColors = [accent.uiColor.withAlphaComponent(strength * 0.72).cgColor, UIColor.clear.cgColor] as CFArray
        if let right = CGGradient(colorsSpace: sRGB, colors: rightColors, locations: [0, 1]) {
            context.drawLinearGradient(right, start: CGPoint(x: rect.maxX, y: rect.midY), end: CGPoint(x: rect.maxX - rect.width * 0.30, y: rect.midY), options: [])
        }
        let topColors = [accent.uiColor.withAlphaComponent(strength * 0.42).cgColor, UIColor.clear.cgColor] as CFArray
        if let top = CGGradient(colorsSpace: sRGB, colors: topColors, locations: [0, 1]) {
            context.drawLinearGradient(top, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.24), options: [])
        }
        context.restoreGState()
    }

    static func drawFullImage(_ image: CGImage, crop: NormalizedPhotoCrop, in rect: CGRect, context: CGContext) {
        let transform = SpotlightPhotoTransform(sourceSize: CGSize(width: image.width, height: image.height), crop: crop, destinationFrame: rect)
        context.interpolationQuality = .high
        UIImage(cgImage: image, scale: 1, orientation: .up).draw(in: transform.fullImageDestination)
    }

    static func drawMaskedPhoto(_ image: UIImage, mask: CGImage, crop: NormalizedPhotoCrop, in rect: CGRect, context: CGContext, envelope: CGRect) {
        guard let source = image.rollCallNormalizedUpImage().cgImage else { return }
        context.saveGState()
        let transform = SpotlightPhotoTransform(sourceSize: CGSize(width: source.width, height: source.height), crop: crop, destinationFrame: rect)
        context.interpolationQuality = .high
        clipToSpotlightMask(mask, imageDestination: transform.fullImageDestination, envelope: envelope, context: context)
        UIImage(cgImage: source, scale: 1, orientation: .up).draw(in: transform.fullImageDestination)
        context.restoreGState()
    }

    static func drawMaskedColor(mask: CGImage, sourceSize: CGSize, crop: NormalizedPhotoCrop, in rect: CGRect, color: UIColor, alpha: CGFloat, context: CGContext, envelope: CGRect) {
        context.saveGState()
        let transform = SpotlightPhotoTransform(sourceSize: sourceSize, crop: crop, destinationFrame: rect)
        clipToSpotlightMask(mask, imageDestination: transform.fullImageDestination, envelope: envelope, context: context)
        context.setFillColor(color.withAlphaComponent(alpha).cgColor)
        context.fill(transform.fullImageDestination)
        context.restoreGState()
    }

    /// Installs the same envelope-plus-source mask clip for every Spotlight foreground layer.
    /// Keeping this in one primitive prevents the rim and the cutout from drifting into different
    /// coordinate systems as the Lab renderer evolves.
    private static func clipToSpotlightMask(_ mask: CGImage, imageDestination: CGRect, envelope: CGRect, context: CGContext) {
        context.clip(to: envelope)
        // UIGraphicsImageRenderer uses UIKit's top-left coordinate system for the source photo,
        // while CGContext's image-mask installation uses the image's Core Graphics orientation.
        // Reflect only while installing the mask, then restore the drawing transform so the source
        // photo and the mask remain pixel-aligned in the final card.
        let reflection = imageDestination.minY + imageDestination.maxY
        context.translateBy(x: 0, y: reflection)
        context.scaleBy(x: 1, y: -1)
        context.clip(to: imageDestination, mask: mask)
        context.translateBy(x: 0, y: reflection)
        context.scaleBy(x: 1, y: -1)
    }

    static func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment, tracking: CGFloat = 0, lineBreakMode: NSLineBreakMode = .byClipping, context: CGContext) {
        guard !text.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreakMode
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph, .kern: tracking]
        NSAttributedString(string: text, attributes: attributes).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    static func measuredTextWidth(_ text: String, font: UIFont, tracking: CGFloat = 0) -> CGFloat {
        NSAttributedString(string: text, attributes: [.font: font, .kern: tracking]).size().width
    }

    static func fittedFont(_ text: String, maxSize: CGFloat, minimumSize: CGFloat = 20, weight: UIFont.Weight, width: CGFloat) -> UIFont {
        var size = maxSize
        while size > minimumSize {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            if NSString(string: text).size(withAttributes: [.font: font]).width <= width { return font }
            size -= 1
        }
        return .systemFont(ofSize: minimumSize, weight: weight)
    }

    static func fittedFont(_ text: String, maxSize: CGFloat, minimumSize: CGFloat = 20, width: CGFloat, tracking: CGFloat = 0, fontProvider: (CGFloat) -> UIFont) -> UIFont {
        var size = maxSize
        while size > minimumSize {
            let font = fontProvider(size)
            let measured = NSAttributedString(string: text, attributes: [.font: font, .kern: tracking]).size().width
            if measured <= width { return font }
            size -= 1
        }
        return fontProvider(minimumSize)
    }

    static func condensedSystemFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let traits = base.fontDescriptor.symbolicTraits.union(.traitCondensed)
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func fittedBroadcastNameFont(_ text: String, maxSize: CGFloat, minimumSize: CGFloat, width: CGFloat, weight: UIFont.Weight, preferredTracking: CGFloat = 0, fontProvider: ((CGFloat) -> UIFont)? = nil) -> (font: UIFont, tracking: CGFloat) {
        let regularProvider: (CGFloat) -> UIFont = fontProvider ?? { UIFont.systemFont(ofSize: $0, weight: weight) }
        let condensedProvider: (CGFloat) -> UIFont = fontProvider ?? { condensedSystemFont(ofSize: $0, weight: weight) }
        let candidates: [(tracking: CGFloat, provider: (CGFloat) -> UIFont)] = [
            (preferredTracking, regularProvider),
            (preferredTracking - 0.5, regularProvider),
            (0, condensedProvider),
            (-0.5, condensedProvider)
        ]

        for candidate in candidates {
            let font = fittedFont(
                text,
                maxSize: maxSize,
                minimumSize: minimumSize,
                width: width,
                tracking: candidate.tracking,
                fontProvider: candidate.provider
            )
            let measured = NSAttributedString(string: text, attributes: [.font: font, .kern: candidate.tracking]).size().width
            if measured <= width { return (font, candidate.tracking) }
        }

        // Keep the surname single-line and non-ellipsized for pathological names.
        let fallback = condensedSystemFont(ofSize: max(20, minimumSize - 4), weight: weight)
        return (fallback, -0.8)
    }

    static func fittedWrappedFont(_ text: String, maxSize: CGFloat, minimumSize: CGFloat, width: CGFloat, maxLines: Int, weight: UIFont.Weight, fontProvider: ((CGFloat) -> UIFont)? = nil) -> UIFont {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let provider: (CGFloat) -> UIFont = fontProvider ?? { UIFont.systemFont(ofSize: $0, weight: weight) }
        var size = maxSize
        while size >= minimumSize {
            let font = provider(size)
            let bounds = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph]).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            if bounds.width <= width + 1 && bounds.height <= font.lineHeight * CGFloat(maxLines) + 2 {
                return font
            }
            size -= 1
        }
        return provider(minimumSize)
    }

    static func wrappedLineCount(_ text: String, font: UIFont, width: CGFloat, maxLines: Int) -> Int {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let bounds = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph]).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return min(maxLines, max(1, Int(ceil(bounds.height / font.lineHeight))))
    }

    static func drawBroadcastLine(from start: CGPoint, length: CGFloat, angle: CGFloat, color: UIColor, width: CGFloat, context: CGContext) {
        let radians = angle * .pi / 180
        let end = CGPoint(x: start.x + length, y: start.y - tan(radians) * length)
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }

    static func drawBroadcastText(_ text: String, in rect: CGRect, angle: CGFloat, font: UIFont, color: UIColor, alignment: NSTextAlignment, tracking: CGFloat = 0, lineBreakMode: NSLineBreakMode = .byClipping, context: CGContext) {
        guard !text.isEmpty else { return }
        let radians = -angle * .pi / 180
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: radians)
        drawText(
            text,
            in: CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height),
            font: font,
            color: color,
            alignment: alignment,
            tracking: tracking,
            lineBreakMode: lineBreakMode,
            context: context
        )
        context.restoreGState()
    }

    static func drawBroadcastTextFromTopLeft(_ text: String, in rect: CGRect, angle: CGFloat, font: UIFont, color: UIColor, alignment: NSTextAlignment, tracking: CGFloat = 0, lineBreakMode: NSLineBreakMode = .byClipping, context: CGContext) {
        guard !text.isEmpty else { return }
        let radians = -angle * .pi / 180
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.rotate(by: radians)
        drawText(
            text,
            in: CGRect(origin: .zero, size: rect.size),
            font: font,
            color: color,
            alignment: alignment,
            tracking: tracking,
            lineBreakMode: lineBreakMode,
            context: context
        )
        context.restoreGState()
    }

    static func drawName(first: String?, last: String, x: CGFloat, y: CGFloat, width: CGFloat, maxLastSize: CGFloat, context: CGContext, alignment: NSTextAlignment = .left, angle: CGFloat = 0, firstToLastOffset: CGFloat = 42, firstFontProvider: ((CGFloat) -> UIFont)? = nil, lastFontProvider: ((CGFloat) -> UIFont)? = nil) {
        let firstName = first ?? ""
        if !firstName.isEmpty {
            let firstFit = fittedBroadcastNameFont(firstName.uppercased(), maxSize: maxLastSize * 0.45, minimumSize: 25, width: width, weight: .semibold, preferredTracking: 2.0, fontProvider: firstFontProvider)
            let lastFit = fittedBroadcastNameFont(last.uppercased(), maxSize: maxLastSize, minimumSize: 30, width: width, weight: .black, fontProvider: lastFontProvider)
            let firstRect = CGRect(x: x, y: y, width: width, height: 52)
            let lastRect = CGRect(x: x, y: y + firstToLastOffset, width: width, height: 106)
            if angle == 0 {
                drawText(firstName.uppercased(), in: firstRect, font: firstFit.font, color: .white.withAlphaComponent(0.92), alignment: alignment, tracking: firstFit.tracking, context: context)
                drawText(last.uppercased(), in: lastRect, font: lastFit.font, color: .white, alignment: alignment, tracking: lastFit.tracking, lineBreakMode: .byClipping, context: context)
            } else {
                let firstWidth = min(width, measuredTextWidth(firstName.uppercased(), font: firstFit.font, tracking: firstFit.tracking))
                let lastWidth = min(width, measuredTextWidth(last.uppercased(), font: lastFit.font, tracking: lastFit.tracking))
                drawBroadcastText(firstName.uppercased(), in: CGRect(x: firstRect.minX, y: firstRect.minY, width: firstWidth, height: firstRect.height), angle: angle, font: firstFit.font, color: .white.withAlphaComponent(0.92), alignment: alignment, tracking: firstFit.tracking, context: context)
                drawBroadcastText(last.uppercased(), in: CGRect(x: lastRect.minX, y: lastRect.minY, width: lastWidth, height: lastRect.height), angle: angle, font: lastFit.font, color: .white, alignment: alignment, tracking: lastFit.tracking, lineBreakMode: .byClipping, context: context)
            }
        } else {
            let lastFit = fittedBroadcastNameFont(last.uppercased(), maxSize: maxLastSize, minimumSize: 30, width: width, weight: .black, fontProvider: lastFontProvider)
            let lastRect = CGRect(x: x, y: y + 18, width: width, height: 124)
            if angle == 0 {
                drawText(last.uppercased(), in: lastRect, font: lastFit.font, color: .white, alignment: alignment, tracking: lastFit.tracking, lineBreakMode: .byClipping, context: context)
            } else {
                let lastWidth = min(width, measuredTextWidth(last.uppercased(), font: lastFit.font, tracking: lastFit.tracking))
                drawBroadcastText(last.uppercased(), in: CGRect(x: lastRect.minX, y: lastRect.minY, width: lastWidth, height: lastRect.height), angle: angle, font: lastFit.font, color: .white, alignment: alignment, tracking: lastFit.tracking, lineBreakMode: .byClipping, context: context)
            }
        }
    }

    static func drawCleanName(first: String?, last: String, x: CGFloat, y: CGFloat, width: CGFloat, context: CGContext) {
        let firstName = first ?? ""
        if !firstName.isEmpty {
            let firstText = firstName.uppercased()
            let firstTracking: CGFloat = 3.0
            let firstFont = fittedFont(
                firstText,
                maxSize: 42,
                minimumSize: 25,
                width: width,
                tracking: firstTracking,
                fontProvider: { CleanV2Typography.condensed(size: $0, weight: .medium) }
            )
            drawText(firstText, in: CGRect(x: x, y: y, width: width, height: 50), font: firstFont, color: .white.withAlphaComponent(0.92), alignment: .left, tracking: firstTracking, context: context)

            let lastText = last.uppercased()
            let lastTracking: CGFloat = -0.2
            let lastFont = fittedFont(
                lastText,
                maxSize: 94,
                minimumSize: 44,
                width: width,
                tracking: lastTracking,
                fontProvider: { CleanV2Typography.condensed(size: $0, weight: .heavy) }
            )
            drawText(lastText, in: CGRect(x: x, y: y + 42, width: width, height: 110), font: lastFont, color: .white, alignment: .left, tracking: lastTracking, context: context)
        } else {
            let lastText = last.uppercased()
            let lastTracking: CGFloat = -0.2
            let lastFont = fittedFont(
                lastText,
                maxSize: 94,
                minimumSize: 44,
                width: width,
                tracking: lastTracking,
                fontProvider: { CleanV2Typography.condensed(size: $0, weight: .heavy) }
            )
            drawText(lastText, in: CGRect(x: x, y: y + 18, width: width, height: 124), font: lastFont, color: .white, alignment: .left, tracking: lastTracking, context: context)
        }
    }

    static func drawFooter(_ model: PlayerCardModel, y: CGFloat, font: UIFont = .systemFont(ofSize: 22, weight: .semibold), useBroadcastTypography: Bool = false, useCleanSpotlightTypography: Bool = false, context: CGContext) {
        let separator = UIBezierPath()
        separator.move(to: CGPoint(x: 70, y: y - 18))
        separator.addLine(to: CGPoint(x: 1_010, y: y - 18))
        context.addPath(separator.cgPath)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
        context.setLineWidth(2)
        context.strokePath()

        let iconRect = CGRect(x: 70, y: y, width: 42, height: 42)
        if let icon = model.brandIcon {
            UIBezierPath(roundedRect: iconRect, cornerRadius: 9).addClip()
            icon.draw(in: iconRect)
            context.resetClip()
        }
        let inset: CGFloat = model.brandIcon == nil ? 0 : 56
        let textRect = CGRect(x: 70 + inset, y: y + 3, width: 300, height: 36)
        if useBroadcastTypography {
            BroadcastCardTypography.drawFooterText(in: textRect, color: .white.withAlphaComponent(0.62), size: font.pointSize, context: context)
        } else if useCleanSpotlightTypography {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            paragraph.lineBreakMode = .byClipping
            let color = UIColor.white.withAlphaComponent(0.62)
            let attributed = NSMutableAttributedString()
            attributed.append(NSAttributedString(string: "Made with ", attributes: [
                .font: UIFont.systemFont(ofSize: font.pointSize, weight: .regular),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]))
            attributed.append(NSAttributedString(string: "Roll Call", attributes: [
                .font: UIFont.systemFont(ofSize: font.pointSize, weight: .semibold),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]))
            attributed.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        } else {
            drawText("Made with Roll Call", in: textRect, font: font, color: .white.withAlphaComponent(0.62), alignment: .left, context: context)
        }
    }

    static func drawWaveform(in rect: CGRect, color: UIColor, seed: Int, angle: CGFloat = 0, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        if angle != 0 {
            context.rotate(by: -angle * .pi / 180)
        }
        let bars = 24
        let spacing = rect.width / CGFloat(bars)
        for index in 0..<bars {
            let phase = CGFloat((index * 17 + seed * 11) % 31) / 31
            let height = rect.height * (0.28 + phase * 0.64)
            let alpha = min(0.86, 0.22 + min(CGFloat(index), CGFloat(bars - index - 1)) * 0.055)
            context.setFillColor(color.withAlphaComponent(alpha).cgColor)
            context.fill(CGRect(x: -rect.width / 2 + CGFloat(index) * spacing, y: -height / 2, width: max(3, spacing * 0.42), height: height))
        }
        context.restoreGState()
    }

    static func drawGiantNumber(_ number: String?, in rect: CGRect, color: UIColor, opacity: CGFloat, angle: CGFloat = 0, font: UIFont? = nil, context: CGContext) {
        guard let number else { return }
        let resolvedFont = font ?? UIFont.systemFont(ofSize: rect.height * 0.82, weight: .black)
        if angle == 0 {
            drawText(number, in: rect, font: resolvedFont, color: color.withAlphaComponent(opacity), alignment: .center, context: context)
        } else {
            drawBroadcastText(number, in: rect, angle: angle, font: resolvedFont, color: color.withAlphaComponent(opacity), alignment: .center, context: context)
        }
    }
}

private enum CleanV2Typography {
    static func condensed(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let traits = base.fontDescriptor.symbolicTraits.union(.traitCondensed)
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func display(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func text(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
}

enum CleanV2Layout {
    static let photoRect = CGRect(x: 44, y: 44, width: 992, height: 936)
    static let gradientRect = CGRect(x: 44, y: 650, width: 992, height: 330)

    static let musicIconRect = CGRect(x: 70, y: 1_014, width: 22, height: 22)
    static let musicLabelRect = CGRect(x: 100, y: 1_008, width: 470, height: 36)
    static let songRect = CGRect(x: 70, y: 1_053, width: 880, height: 58)
    static let artistRect = CGRect(x: 70, y: 1_111, width: 880, height: 48)
    static let waveformRect = CGRect(x: 70, y: 1_195, width: 560, height: 46)
    static let footerY: CGFloat = 1_274
}

private enum CleanPlayerCardRenderer {
    static func draw(_ model: PlayerCardModel, in context: CGContext) {
        let colors = CleanCardColorResolver.resolve(model.teamColor)
        PlayerCardArtworkRenderer.drawBackground(in: context, accent: colors.illuminationAccent, atmosphere: 0.065)
        let photoRect = CleanV2Layout.photoRect
        PlayerCardArtworkRenderer.drawPhoto(model.photo, crop: model.crop, in: photoRect, context: context, cornerRadius: 22)
        PlayerCardArtworkRenderer.drawAsymmetricEdgeLight(in: photoRect, accent: colors.illuminationAccent, strength: model.tuning.cleanEdgeLight, context: context, cornerRadius: 22)

        if let teamName = model.teamName {
            PlayerCardArtworkRenderer.drawText(teamName.uppercased(), in: CGRect(x: 70, y: 82, width: 690, height: 40), font: CleanV2Typography.condensed(size: 25, weight: .semibold), color: .white.withAlphaComponent(0.92), alignment: .left, tracking: 2.2, context: context)
            context.setStrokeColor(colors.displayAccent.uiColor.cgColor)
            context.setLineWidth(5)
            context.move(to: CGPoint(x: 70, y: 134))
            context.addLine(to: CGPoint(x: 250, y: 134))
            context.strokePath()
        }
        if let number = model.playerNumber {
            let numberFont = PlayerCardArtworkRenderer.fittedFont(number, maxSize: 60, minimumSize: 30, width: 120, fontProvider: { CleanV2Typography.condensed(size: $0, weight: .black) })
            PlayerCardArtworkRenderer.drawText(number, in: CGRect(x: 904, y: 74, width: 120, height: 76), font: numberFont, color: .white, alignment: .right, context: context)
            context.setStrokeColor(colors.displayAccent.uiColor.cgColor)
            context.setLineWidth(4)
            context.move(to: CGPoint(x: 918, y: 158))
            context.addLine(to: CGPoint(x: 1_024, y: 158))
            context.strokePath()
        }

        let gradientRect = CleanV2Layout.gradientRect
        let gradient = CGGradient(colorsSpace: PlayerCardArtworkRenderer.sRGB, colors: [UIColor.clear.cgColor, UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: model.tuning.cleanGradientStrength).cgColor] as CFArray, locations: [model.tuning.cleanGradientStart, 1])
        if let gradient { context.drawLinearGradient(gradient, start: CGPoint(x: gradientRect.midX, y: gradientRect.minY), end: CGPoint(x: gradientRect.midX, y: gradientRect.maxY), options: []) }

        PlayerCardArtworkRenderer.drawCleanName(first: model.firstName, last: model.lastName, x: 70, y: model.tuning.cleanNameY, width: 860, context: context)
        if model.songTitle != nil || model.artistName != nil {
            if let icon = UIImage(systemName: "music.note")?.withTintColor(colors.displayAccent.uiColor, renderingMode: .alwaysOriginal) {
                icon.draw(in: CleanV2Layout.musicIconRect)
            }
            PlayerCardArtworkRenderer.drawText("WALK-UP MUSIC", in: CleanV2Layout.musicLabelRect, font: CleanV2Typography.condensed(size: 22, weight: .semibold), color: colors.displayAccent.uiColor, alignment: .left, tracking: 1.8, context: context)
            if let song = model.songTitle {
                let songFont = PlayerCardArtworkRenderer.fittedFont(song, maxSize: 44, minimumSize: 26, width: 880, fontProvider: { CleanV2Typography.display(size: $0, weight: .semibold) })
                PlayerCardArtworkRenderer.drawText(song, in: CleanV2Layout.songRect, font: songFont, color: .white, alignment: .left, lineBreakMode: .byTruncatingTail, context: context)
            }
            if let artist = model.artistName {
                let artistFont = PlayerCardArtworkRenderer.fittedFont(artist, maxSize: 27, minimumSize: 20, width: 880, fontProvider: { CleanV2Typography.text(size: $0, weight: .regular) })
                PlayerCardArtworkRenderer.drawText(artist, in: CleanV2Layout.artistRect, font: artistFont, color: .white.withAlphaComponent(0.62), alignment: .left, lineBreakMode: .byTruncatingTail, context: context)
            }
            PlayerCardArtworkRenderer.drawWaveform(in: CleanV2Layout.waveformRect, color: colors.displayAccent.uiColor, seed: PlayerCardArtworkRenderer.stableSeed(model.playerName), context: context)
        }
        PlayerCardArtworkRenderer.drawFooter(model, y: CleanV2Layout.footerY, font: CleanV2Typography.text(size: 22, weight: .medium), useCleanSpotlightTypography: true, context: context)
    }
}

private enum BroadcastPlayerCardRenderer {
    static func draw(_ model: PlayerCardModel, in context: CGContext) {
        let colors = BroadcastCardColorResolver.resolve(model.teamColor)
        PlayerCardArtworkRenderer.drawBackground(in: context, accent: colors.illuminationAccent, atmosphere: 0.045)
        let photoRect = CGRect(x: 42, y: 42, width: 996, height: model.tuning.broadcastPhotoHeight)
        PlayerCardArtworkRenderer.drawPhoto(model.photo, crop: model.crop, in: photoRect, context: context, cornerRadius: 18, edgeLight: colors.illuminationAccent, edgeLightStrength: 0.17)
        let broadcastAngle = model.tuning.broadcastAngle

        if let teamName = model.teamName {
            let teamText = teamName.uppercased()
            let teamFit = PlayerCardArtworkRenderer.fittedBroadcastNameFont(
                teamText,
                maxSize: 29,
                minimumSize: 22,
                width: 900,
                weight: .semibold,
                preferredTracking: 2,
                fontProvider: { BroadcastCardTypography.team(size: $0) }
            )
            let teamWidth = min(900, PlayerCardArtworkRenderer.measuredTextWidth(teamText, font: teamFit.font, tracking: teamFit.tracking))
            let teamX: CGFloat = 70
            PlayerCardArtworkRenderer.drawBroadcastText(teamText, in: CGRect(x: teamX, y: 76, width: max(1, teamWidth), height: 44), angle: broadcastAngle, font: teamFit.font, color: .white.withAlphaComponent(0.92), alignment: .left, tracking: teamFit.tracking, context: context)
            PlayerCardArtworkRenderer.drawBroadcastLine(from: CGPoint(x: teamX, y: 140), length: max(1, teamWidth), angle: broadcastAngle, color: colors.strongGraphicAccent.uiColor, width: 5, context: context)
        }
        let radians = broadcastAngle * .pi / 180
        let lowerThird = UIBezierPath()
        lowerThird.move(to: CGPoint(x: 0, y: model.tuning.broadcastLowerThirdY))
        lowerThird.addLine(to: CGPoint(x: 1_080, y: model.tuning.broadcastLowerThirdY - tan(radians) * 1_080))
        lowerThird.addLine(to: CGPoint(x: 1_080, y: 1_185))
        lowerThird.addLine(to: CGPoint(x: 0, y: 1_185))
        lowerThird.close()
        context.saveGState()
        context.addPath(lowerThird.cgPath)
        context.clip()
        let lowerThirdGradient = CGGradient(
            colorsSpace: PlayerCardArtworkRenderer.sRGB,
            colors: [
                UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: 0.14).cgColor,
                UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: 0.96).cgColor
            ] as CFArray,
            locations: [0, 1]
        )
        if let lowerThirdGradient {
            context.drawLinearGradient(lowerThirdGradient, start: CGPoint(x: 0, y: model.tuning.broadcastLowerThirdY - 110), end: CGPoint(x: 0, y: 1_185), options: [])
        }
        context.restoreGState()

        let tinted = UIBezierPath()
        tinted.move(to: CGPoint(x: 0, y: model.tuning.broadcastLowerThirdY - 22))
        tinted.addLine(to: CGPoint(x: 1_080, y: model.tuning.broadcastLowerThirdY - tan(radians) * 1_080 - 22))
        tinted.addLine(to: CGPoint(x: 1_080, y: 1_185))
        tinted.addLine(to: CGPoint(x: 0, y: 1_185))
        tinted.close()
        context.addPath(tinted.cgPath)
        context.setFillColor(colors.mutedGraphicAccent.uiColor.withAlphaComponent(model.tuning.broadcastPlaneOpacity).cgColor)
        context.fillPath()
        context.setStrokeColor(colors.strongGraphicAccent.uiColor.cgColor)
        context.setLineWidth(6)
        context.move(to: CGPoint(x: 0, y: model.tuning.broadcastLowerThirdY - 22))
        context.addLine(to: CGPoint(x: 1_080, y: model.tuning.broadcastLowerThirdY - tan(radians) * 1_080 - 22))
        context.strokePath()

        // Draw after the planes so the number visibly crosses the photo/field transition.
        PlayerCardArtworkRenderer.drawGiantNumber(model.playerNumber, in: CGRect(x: 660, y: model.tuning.broadcastGiantNumberY, width: 440, height: 420), color: colors.strongGraphicAccent.uiColor, opacity: model.tuning.broadcastNumberOpacity, angle: broadcastAngle, font: BroadcastCardTypography.decorativeJerseyNumber(size: 420 * 0.82), context: context)

        PlayerCardArtworkRenderer.drawName(
            first: model.firstName,
            last: model.lastName,
            x: 70,
            y: model.tuning.broadcastNameY,
            width: 940,
            maxLastSize: 102.5,
            context: context,
            angle: broadcastAngle,
            firstToLastOffset: 21,
            firstFontProvider: { BroadcastCardTypography.playerFirstName(size: $0) },
            lastFontProvider: { BroadcastCardTypography.playerLastName(size: $0) }
        )
        PlayerCardArtworkRenderer.drawBroadcastLine(from: CGPoint(x: 70, y: model.tuning.broadcastNameY + 190), length: 440, angle: broadcastAngle, color: colors.strongGraphicAccent.uiColor.withAlphaComponent(0.78), width: 3, context: context)
        if model.songTitle != nil || model.artistName != nil {
            // Music is a continuation of the Broadcast field with a thin angled
            // termination below it.
            let musicY = model.tuning.broadcastMusicY
            let musicFont = BroadcastCardTypography.sectionLabel(size: 21)
            let musicLabel = "♪  WALK-UP MUSIC"
            let musicWidth = PlayerCardArtworkRenderer.measuredTextWidth(musicLabel, font: musicFont, tracking: 1.7)
            PlayerCardArtworkRenderer.drawBroadcastText(musicLabel, in: CGRect(x: 96, y: musicY - 24, width: max(1, musicWidth), height: 34), angle: broadcastAngle, font: musicFont, color: colors.displayAccent.uiColor, alignment: .left, tracking: 1.7, context: context)
            var artistY: CGFloat = musicY + 76
            if let song = model.songTitle {
                let songWidth: CGFloat = 700
                let songFont = PlayerCardArtworkRenderer.fittedWrappedFont(song, maxSize: 42, minimumSize: 28, width: songWidth, maxLines: 2, weight: .semibold, fontProvider: { BroadcastCardTypography.songTitle(size: $0) })
                let songLines = PlayerCardArtworkRenderer.wrappedLineCount(song, font: songFont, width: songWidth, maxLines: 2)
                PlayerCardArtworkRenderer.drawBroadcastTextFromTopLeft(song, in: CGRect(x: 70, y: musicY + 20, width: songWidth, height: 96), angle: broadcastAngle, font: songFont, color: .white, alignment: .left, lineBreakMode: .byWordWrapping, context: context)
                artistY = songLines > 1 ? musicY + 120 : musicY + 76
            }
            if let artist = model.artistName {
                let artistWidth: CGFloat = 700
                let artistFont = PlayerCardArtworkRenderer.fittedWrappedFont(artist, maxSize: 25, minimumSize: 18, width: artistWidth, maxLines: 2, weight: .regular, fontProvider: { BroadcastCardTypography.artist(size: $0) })
                PlayerCardArtworkRenderer.drawBroadcastTextFromTopLeft(artist, in: CGRect(x: 70, y: artistY, width: artistWidth, height: 54), angle: broadcastAngle, font: artistFont, color: .white.withAlphaComponent(0.60), alignment: .left, lineBreakMode: .byTruncatingTail, context: context)
            }
            PlayerCardArtworkRenderer.drawWaveform(in: CGRect(x: 650, y: musicY + 30, width: 360, height: 93), color: colors.displayAccent.uiColor, seed: PlayerCardArtworkRenderer.stableSeed(model.playerName), angle: broadcastAngle, context: context)
            PlayerCardArtworkRenderer.drawBroadcastLine(from: CGPoint(x: 70, y: 1_220), length: 940, angle: broadcastAngle, color: colors.strongGraphicAccent.uiColor.withAlphaComponent(0.50), width: 2, context: context)
        }
        PlayerCardArtworkRenderer.drawFooter(model, y: 1_274, useBroadcastTypography: true, context: context)
    }
}

struct SpotlightBreakoutGeometry {
    static let protectedNameTop: CGFloat = 900

    struct Metrics: Equatable, Sendable {
        let sampledForegroundFraction: CGFloat
        let outsidePhotoFraction: CGFloat
        let outsideEnvelopeFraction: CGFloat
        let protectedZoneFraction: CGFloat

        var hasMeaningfulEscape: Bool {
            outsidePhotoFraction >= 0.02 && outsideEnvelopeFraction <= 0.02 && protectedZoneFraction <= 0.01
        }

        var summary: String {
            String(
                format: "outside photo %.1f%% · clipped %.1f%% · protected %.1f%%",
                outsidePhotoFraction * 100,
                outsideEnvelopeFraction * 100,
                protectedZoneFraction * 100
            )
        }
    }

    static func envelope(
        photoRect: CGRect,
        breakout: CGFloat,
        quality: SpotlightSegmentationQuality
    ) -> CGRect {
        let breakoutScale: CGFloat = quality == .usable ? 0.45 : 1.0
        let raw = photoRect.insetBy(
            dx: -photoRect.width * breakout * breakoutScale,
            dy: -photoRect.height * breakout * breakoutScale
        )
        let cappedMaxY = min(raw.maxY, protectedNameTop)
        return CGRect(
            x: raw.minX,
            y: raw.minY,
            width: raw.width,
            height: max(0, cappedMaxY - raw.minY)
        )
    }

    static func measure(
        mask: CGImage,
        crop: NormalizedPhotoCrop,
        photoRect: CGRect,
        envelope: CGRect,
        protectedZones: [CGRect] = [],
        maximumDimension: Int = 192
    ) -> Metrics? {
        let width = mask.width
        let height = mask.height
        guard width > 0, height > 0 else { return nil }
        let scale = min(1, CGFloat(maximumDimension) / CGFloat(max(width, height)))
        let sampleWidth = max(1, Int((CGFloat(width) * scale).rounded()))
        let sampleHeight = max(1, Int((CGFloat(height) * scale).rounded()))
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight)
        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .low
        context.draw(mask, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        let transform = SpotlightPhotoTransform(
            sourceSize: CGSize(width: width, height: height),
            crop: crop,
            destinationFrame: photoRect
        )
        var foreground = 0
        var outsidePhoto = 0
        var outsideEnvelope = 0
        var protected = 0
        for index in pixels.indices where pixels[index] > 32 {
            foreground += 1
            let x = index % sampleWidth
            let y = index / sampleWidth
            let normalizedPoint = CGPoint(
                x: (CGFloat(x) + 0.5) / CGFloat(sampleWidth),
                y: (CGFloat(y) + 0.5) / CGFloat(sampleHeight)
            )
            let projectedPoint = CGPoint(
                x: transform.fullImageDestination.minX + normalizedPoint.x * transform.fullImageDestination.width,
                y: transform.fullImageDestination.minY + normalizedPoint.y * transform.fullImageDestination.height
            )
            if !photoRect.contains(projectedPoint) { outsidePhoto += 1 }
            if !envelope.contains(projectedPoint) { outsideEnvelope += 1 }
            if protectedZones.contains(where: { $0.contains(projectedPoint) }) { protected += 1 }
        }
        guard foreground > 0 else { return nil }
        return Metrics(
            sampledForegroundFraction: CGFloat(foreground) / CGFloat(pixels.count),
            outsidePhotoFraction: CGFloat(outsidePhoto) / CGFloat(foreground),
            outsideEnvelopeFraction: CGFloat(outsideEnvelope) / CGFloat(foreground),
            protectedZoneFraction: CGFloat(protected) / CGFloat(foreground)
        )
    }
}

private enum SpotlightPlayerCardRenderer {
    static func draw(_ model: PlayerCardModel, in context: CGContext) {
        let colors = SpotlightCardColorResolver.resolve(model.teamColor)
        PlayerCardArtworkRenderer.drawBackground(in: context, accent: colors.atmosphericAccent, atmosphere: model.tuning.spotlightAtmosphere)
        let photoRect = CGRect(x: (PlayerCardModel.canvasSize.width - model.tuning.spotlightPhotoWidth) / 2, y: model.tuning.spotlightPhotoY, width: model.tuning.spotlightPhotoWidth, height: model.tuning.spotlightPhotoHeight)

        let backPlane = photoRect.offsetBy(dx: 34, dy: -28)
        context.setFillColor(colors.planeAccent.uiColor.withAlphaComponent(0.72).cgColor)
        context.fill(backPlane)
        let frontPlane = photoRect.offsetBy(dx: -26, dy: 34)
        context.setFillColor(UIColor(red: 0.04, green: 0.05, blue: 0.075, alpha: 0.96).cgColor)
        context.fill(frontPlane)
        // Keep the giant number behind the photo, but offset it far enough right that its graphic
        // structure remains visible around the centered portrait frame.
        PlayerCardArtworkRenderer.drawGiantNumber(model.playerNumber, in: CGRect(x: 500, y: 180, width: 560, height: 610), color: colors.numberAccent.uiColor, opacity: model.tuning.spotlightGiantNumberOpacity, context: context)
        PlayerCardArtworkRenderer.drawPhoto(model.photo, crop: model.crop, in: photoRect, context: context, cornerRadius: 22, edgeLight: colors.rimLightAccent, edgeLightStrength: 0.22)

        if let analysis = model.spotlightAnalysis, effectiveQuality(model, analysis: analysis) != .fallback, let photo = model.photo {
            let quality = effectiveQuality(model, analysis: analysis)
            let envelope = SpotlightBreakoutGeometry.envelope(
                photoRect: photoRect,
                breakout: model.tuning.spotlightBreakout,
                quality: quality
            )
            let rim = analysis.rimLightMask
            context.saveGState()
            context.setAlpha(model.tuning.spotlightRimLight * (quality == .usable ? 0.55 : 1))
            let sourceSize = photo.rollCallNormalizedUpImage().cgImage.map { CGSize(width: $0.width, height: $0.height) } ?? photo.size
            PlayerCardArtworkRenderer.drawMaskedColor(mask: rim, sourceSize: sourceSize, crop: model.crop, in: photoRect, color: colors.rimLightAccent.uiColor, alpha: 0.9, context: context, envelope: envelope.insetBy(dx: -18, dy: -18))
            context.restoreGState()
            PlayerCardArtworkRenderer.drawMaskedPhoto(photo, mask: analysis.processedMask, crop: model.crop, in: photoRect, context: context, envelope: envelope)
        }

        if let teamName = model.teamName {
            PlayerCardArtworkRenderer.drawText(teamName.uppercased(), in: CGRect(x: 70, y: 80, width: 700, height: 38), font: .systemFont(ofSize: 24, weight: .semibold), color: .white.withAlphaComponent(0.92), alignment: .left, tracking: 2, context: context)
            context.setStrokeColor(colors.displayAccent.uiColor.cgColor)
            context.setLineWidth(4)
            context.move(to: CGPoint(x: 70, y: 128))
            context.addLine(to: CGPoint(x: 250, y: 128))
            context.strokePath()
        }
        if let number = model.playerNumber {
            PlayerCardArtworkRenderer.drawText(number, in: CGRect(x: 900, y: 76, width: 120, height: 70), font: PlayerCardArtworkRenderer.fittedFont(number, maxSize: 56, weight: .black, width: 120), color: .white, alignment: .right, context: context)
        }
        PlayerCardArtworkRenderer.drawName(first: model.firstName, last: model.lastName, x: 70, y: 920, width: 940, maxLastSize: 94, context: context, alignment: .center)
        if model.songTitle != nil || model.artistName != nil {
            if let song = model.songTitle {
                PlayerCardArtworkRenderer.drawText("♪  \(song)", in: CGRect(x: 70, y: 1_095, width: 760, height: 54), font: PlayerCardArtworkRenderer.fittedFont(song, maxSize: 38, weight: .bold, width: 760), color: .white, alignment: .left, lineBreakMode: .byTruncatingTail, context: context)
            }
            if let artist = model.artistName {
                PlayerCardArtworkRenderer.drawText(artist, in: CGRect(x: 94, y: 1_148, width: 680, height: 40), font: PlayerCardArtworkRenderer.fittedFont(artist, maxSize: 24, weight: .regular, width: 680), color: .white.withAlphaComponent(0.60), alignment: .left, lineBreakMode: .byTruncatingTail, context: context)
            }
            PlayerCardArtworkRenderer.drawWaveform(in: CGRect(x: 820, y: 1_106, width: 200, height: 52), color: colors.displayAccent.uiColor, seed: PlayerCardArtworkRenderer.stableSeed(model.playerName), context: context)
        }
        PlayerCardArtworkRenderer.drawFooter(model, y: 1_274, useCleanSpotlightTypography: true, context: context)
    }

    private static func effectiveQuality(_ model: PlayerCardModel, analysis: SpotlightAnalysisResult) -> SpotlightSegmentationQuality {
        switch model.segmentationMode {
        case .auto: return analysis.quality
        case .forceExcellent: return .excellent
        case .forceUsable: return .usable
        case .forceFallback: return .fallback
        }
    }
}

private extension String {
    var cardTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var cardNilIfBlank: String? { let value = cardTrimmed; return value.isEmpty ? nil : value }
}

// MARK: - Spotlight analysis

final class SpotlightAnalysisService: @unchecked Sendable {
    static let shared = SpotlightAnalysisService()
    private let lock = NSLock()
    private var cache: [String: SpotlightAnalysisResult] = [:]
    private var cacheOrder: [String] = []
    private static let maximumCachedResults = 4
    static let analysisVersion = "spotlight-mask-v5"

    static func sourceIdentity(for photo: UIImage) -> String {
        guard let data = photo.pngData() else {
            return "image-\(photo.size.width)x\(photo.size.height)"
        }
        let checksum = data.reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return "png-\(String(checksum, radix: 16))"
    }

    static func cacheKey(for identity: String, crop: NormalizedPhotoCrop, backend: SpotlightSegmentationBackend) -> String {
        [identity, String(crop.x), String(crop.y), String(crop.width), String(crop.height), backend.rawValue, String(backend.requestRevision), analysisVersion].joined(separator: "|")
    }

    func analyze(photo: UIImage, crop: NormalizedPhotoCrop, identity: String, backend: SpotlightSegmentationBackend = .personInstance) async -> SpotlightAnalysisReport {
        let key = Self.cacheKey(for: identity, crop: crop, backend: backend)
        if let cached = cachedResult(for: key) {
            return SpotlightAnalysisReport(result: SpotlightAnalysisResult(
                mask: cached.mask,
                processedMask: cached.processedMask,
                rimLightMask: cached.rimLightMask,
                quality: cached.quality,
                maskBounds: cached.maskBounds,
                faceBounds: cached.faceBounds,
                personBounds: cached.personBounds,
                cacheKey: key,
                wasCacheHit: true,
                candidateCount: cached.candidateCount,
                selectionReason: cached.selectionReason,
                maskMetrics: cached.maskMetrics,
                backend: cached.backend,
                requestRevision: cached.requestRevision,
                candidateDiagnostics: cached.candidateDiagnostics,
                selectedInstanceIdentifier: cached.selectedInstanceIdentifier,
                maskRasterDiagnostics: cached.maskRasterDiagnostics
            ), diagnostic: .completed)
        }

        return await Task.detached(priority: .userInitiated) { [photo, backend] in
            guard let image = photo.rollCallNormalizedUpImage().cgImage else {
                return SpotlightAnalysisReport(result: nil, diagnostic: .imageUnavailable)
            }
            let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
            let faceRequest = VNDetectFaceRectanglesRequest()
            let observation: VNInstanceMaskObservation
            do {
                switch backend {
                case .personInstance:
                    let request = VNGeneratePersonInstanceMaskRequest()
                    request.revision = VNGeneratePersonInstanceMaskRequestRevision1
                    try handler.perform([request, faceRequest])
                    guard let result = request.results?.first else {
                        return SpotlightAnalysisReport(result: nil, diagnostic: .noObservation)
                    }
                    observation = result
                case .foregroundInstance:
                    let request = VNGenerateForegroundInstanceMaskRequest()
                    request.revision = VNGenerateForegroundInstanceMaskRequestRevision1
                    try handler.perform([request, faceRequest])
                    guard let result = request.results?.first else {
                        return SpotlightAnalysisReport(result: nil, diagnostic: .noObservation)
                    }
                    observation = result
                }
            } catch {
                let error = error as NSError
                return SpotlightAnalysisReport(
                    result: nil,
                    diagnostic: .visionRequestFailed(domain: error.domain, code: error.code, message: error.localizedDescription)
                )
            }
            guard !observation.allInstances.isEmpty else {
                return SpotlightAnalysisReport(result: nil, diagnostic: .noInstances)
            }

            let faces = faceRequest.results?.map { result -> CGRect in
                let box = result.boundingBox
                return CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
            } ?? []
            var candidates: [(identifier: Int, mask: CGImage, processed: SpotlightMaskProcessingResult, rasterDiagnostics: SpotlightMaskRasterDiagnostics)] = []
            var firstMaskFailure: SpotlightAnalysisDiagnostic?
            for identifier in observation.allInstances {
                let maskBuffer: CVPixelBuffer
                do {
                    maskBuffer = try observation.generateScaledMaskForImage(forInstances: IndexSet(integer: identifier), from: handler)
                } catch {
                    let error = error as NSError
                    firstMaskFailure = firstMaskFailure ?? .maskGenerationFailed(domain: error.domain, code: error.code, message: error.localizedDescription)
                    continue
                }
                guard let mask = Self.cgImage(from: maskBuffer) else {
                    firstMaskFailure = firstMaskFailure ?? .maskConversionFailed
                    continue
                }
                guard let maskStatistics = Self.maskStatistics(mask) else {
                    firstMaskFailure = firstMaskFailure ?? .emptyMask
                    continue
                }
                let nearestFace = faces.max { lhs, rhs in
                    Self.overlap(lhs, maskStatistics.normalizedBounds) < Self.overlap(rhs, maskStatistics.normalizedBounds)
                }
                let faceAnchor = nearestFace.flatMap { face in
                    Self.overlap(face, maskStatistics.normalizedBounds) >= 0.05 ? face : nil
                }
                guard let processed = SpotlightMaskProcessor.process(mask, faceBounds: faceAnchor) else {
                    firstMaskFailure = firstMaskFailure ?? .emptyMask
                    continue
                }
                candidates.append((identifier: identifier, mask: mask, processed: processed, rasterDiagnostics: SpotlightMaskRasterDiagnostics(image: mask)))
            }
            let rankedCandidates = candidates.map { candidate in
                SpotlightSubjectCandidate(
                    identifier: candidate.identifier,
                    bounds: candidate.processed.bounds,
                    faceOverlap: faces.map { Self.overlap($0, candidate.processed.bounds) }.max() ?? 0,
                    foregroundCoverage: candidate.processed.metrics.foregroundCoverage
                )
            }
            guard !candidates.isEmpty else {
                return SpotlightAnalysisReport(result: nil, diagnostic: firstMaskFailure ?? .noCandidateMasks)
            }
            let usableCandidates = rankedCandidates.filter { $0.area > SpotlightSubjectSelector.minimumCandidateArea }
            guard !usableCandidates.isEmpty else {
                let summary = rankedCandidates.map {
                    String(format: "id %d area %.3f coverage %.3f center %.3f score %.3f face %.3f", $0.identifier, $0.area, $0.foregroundCoverage, $0.centerScore(), $0.score(), $0.faceOverlap)
                }.joined(separator: "; ")
                return SpotlightAnalysisReport(
                    result: nil,
                    diagnostic: .noUsableSubjectDetails(candidateCount: rankedCandidates.count, summary: summary)
                )
            }
            guard let selection = SpotlightSubjectSelector.select(rankedCandidates),
                  let selected = candidates.first(where: { $0.identifier == selection.identifier }) else {
                let summary = usableCandidates.map {
                    String(format: "id %d area %.3f coverage %.3f center %.3f score %.3f face %.3f", $0.identifier, $0.area, $0.foregroundCoverage, $0.centerScore(), $0.score(), $0.faceOverlap)
                }.joined(separator: "; ")
                return SpotlightAnalysisReport(
                    result: nil,
                    diagnostic: .ambiguousSubjectDetails(candidateCount: usableCandidates.count, summary: summary)
                )
            }

            let normalizedBounds = selected.processed.bounds
            let nearestFace = faces.max { lhs, rhs in
                Self.overlap(lhs, normalizedBounds) < Self.overlap(rhs, normalizedBounds)
            }
            let face = nearestFace.flatMap { face in
                Self.overlap(face, normalizedBounds) >= 0.05 ? face : nil
            }
            let processedMask = selected.processed.mask
            let rimLightMask = Self.rimLightMask(from: processedMask) ?? processedMask
            let result = SpotlightAnalysisResult(
                mask: selected.mask,
                processedMask: processedMask,
                rimLightMask: rimLightMask,
                quality: selected.processed.quality,
                maskBounds: normalizedBounds,
                faceBounds: face,
                personBounds: normalizedBounds,
                cacheKey: key,
                wasCacheHit: false,
                candidateCount: rankedCandidates.count,
                selectionReason: selection.reason,
                maskMetrics: selected.processed.metrics,
                backend: backend,
                requestRevision: backend.requestRevision,
                candidateDiagnostics: rankedCandidates,
                selectedInstanceIdentifier: selection.identifier,
                maskRasterDiagnostics: selected.rasterDiagnostics
            )
            Self.shared.store(result)
            return SpotlightAnalysisReport(result: result, diagnostic: .completed)
        }.value
    }

    private func store(_ result: SpotlightAnalysisResult) {
        lock.lock()
        cache[result.cacheKey] = result
        cacheOrder.removeAll { $0 == result.cacheKey }
        cacheOrder.append(result.cacheKey)
        while cacheOrder.count > Self.maximumCachedResults {
            let evictedKey = cacheOrder.removeFirst()
            cache.removeValue(forKey: evictedKey)
        }
        lock.unlock()
    }

    private func cachedResult(for key: String) -> SpotlightAnalysisResult? {
        lock.lock()
        defer { lock.unlock() }
        guard let result = cache[key] else { return nil }
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
        return result
    }

    private static func cgImage(from buffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        return CIContext(options: [.useSoftwareRenderer: true]).createCGImage(ciImage, from: ciImage.extent)
    }

    private static func overlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let denominator = max(lhs.width * lhs.height, 0.0001)
        return min(max(intersection.width * intersection.height / denominator, 0), 1)
    }

    private static func rimLightMask(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        var source = [UInt8](repeating: 0, count: width * height)
        var output = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &source, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let radius = max(2, min(width, height) / 120)
        for y in 0..<height {
            for x in 0..<width where source[y * width + x] > 96 {
                let touchesBackground = stride(from: -radius, through: radius, by: max(1, radius / 2)).contains { offsetY in
                    stride(from: -radius, through: radius, by: max(1, radius / 2)).contains { offsetX in
                        let sampleX = x + offsetX
                        let sampleY = y + offsetY
                        return sampleX < 0 || sampleY < 0 || sampleX >= width || sampleY >= height || source[sampleY * width + sampleX] == 0
                    }
                }
                if touchesBackground {
                    let xProgress = CGFloat(x) / CGFloat(max(width - 1, 1))
                    let yProgress = CGFloat(y) / CGFloat(max(height - 1, 1))
                    let leftBias = 1 - xProgress
                    let upperBias = 1 - yProgress
                    let directionalWeight = min(1, max(0.12, leftBias * 0.72 + upperBias * 0.28))
                    output[y * width + x] = UInt8(directionalWeight * 255)
                }
            }
        }
        guard let outputContext = CGContext(data: &output, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        guard let raw = outputContext.makeImage() else { return nil }
        let rawImage = CIImage(cgImage: raw)
        let softened = rawImage
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.8])
            .cropped(to: rawImage.extent)
        return CIContext(options: [.useSoftwareRenderer: true]).createCGImage(softened, from: rawImage.extent)
    }

    private struct MaskStatistics {
        let normalizedBounds: CGRect
        let foregroundCoverage: CGFloat
    }

    private static func maskStatistics(_ image: CGImage) -> MaskStatistics? {
        let width = 96
        let height = 96
        var bytes = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var count = 0
        for y in 0..<height {
            for x in 0..<width where bytes[y * width + x] > 18 {
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y); count += 1
            }
        }
        guard count > 0 else { return nil }
        let bounds = CGRect(x: minX, y: minY, width: max(1, maxX - minX + 1), height: max(1, maxY - minY + 1))
        return MaskStatistics(
            normalizedBounds: CGRect(
                x: bounds.minX / CGFloat(width),
                y: bounds.minY / CGFloat(height),
                width: bounds.width / CGFloat(width),
                height: bounds.height / CGFloat(height)
            ),
            foregroundCoverage: CGFloat(count) / CGFloat(width * height)
        )
    }
}

// MARK: - Fixture and export services

struct PlayerCardFixture: Identifiable, @unchecked Sendable {
    let id: String
    let title: String
    let model: PlayerCardModel
}

enum LabPhotoFixture: String, CaseIterable, Identifiable {
    case fieldFullBody = "lab-field-full-body"
    case fieldActionWide = "lab-field-action-wide"
    case battingPortrait = "lab-batting-portrait"
    case battingSide = "lab-batting-side"
    case throwingWide = "lab-throwing-wide"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fieldFullBody: return "Field full body"
        case .fieldActionWide: return "Field action"
        case .battingPortrait: return "Batting portrait"
        case .battingSide: return "Batting side"
        case .throwingWide: return "Throwing wide"
        }
    }

    var image: UIImage? {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "jpeg", subdirectory: "LabPhotos") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)?.rollCallNormalizedUpImage()
    }
}

enum CardFixtureLibrary {
    static let ids = [
        "normal", "long-name", "long-team", "long-song", "long-artist", "no-music", "bright", "dark", "busy", "no-number",
        "close-up", "full-body", "subject-left", "subject-right", "subject-centered",
        "three-digit", "multiple-people", "helmet", "long-hair", "partial-occlusion",
        "difficult-background", "ambiguous-subject", "wild-color"
    ]

    static func fixture(id: String, template: PlayerCardTemplate, importedPhoto: UIImage? = nil, crop: NormalizedPhotoCrop? = nil, tuning: PlayerCardLabTuning = .default, colorOverride: CardRGBColor? = nil, segmentationMode: SpotlightSegmentationMode = .auto, analysis: SpotlightAnalysisResult? = nil) -> PlayerCardFixture {
        let photo = importedPhoto ?? generatedPhoto(for: id)
        let values: (String, String?, String, String?, String?, CardRGBColor) = {
            switch id {
            case "long-name": return ("Alexandria Montgomery-Summers", "107", "Piscataway Thunder Softball Association", "Can't Back Down — Extended Stadium Remix", "Demi Lovato, Alyson Stoner & Cast", CardRGBColor(red: 0.22, green: 0.07, blue: 0.70))
            case "no-music": return ("Ellie Fisher", "15", "P-Way Thunder", nil, nil, CardRGBColor(red: 0.05, green: 0.35, blue: 0.75))
            case "bright": return ("Ellie Fisher", "15", "P-Way Thunder", "Thunderstruck", "AC/DC", CardRGBColor(red: 0.98, green: 0.96, blue: 0.82))
            case "dark": return ("Ellie Fisher", "15", "P-Way Thunder", "Thunderstruck", "AC/DC", CardRGBColor(red: 0.02, green: 0.025, blue: 0.04))
            case "wild-color": return ("Ellie Fisher", "15", "P-Way Thunder", "Thunderstruck", "AC/DC", CardRGBColor(red: 0.91, green: 0.16, blue: 0.44))
            case "no-number": return ("Ellie Fisher", nil, "P-Way Thunder", "Thunderstruck", "AC/DC", CardRGBColor(red: 0.90, green: 0.37, blue: 0.06))
            case "three-digit": return ("Ellie Fisher", "107", "P-Way Thunder", "Thunderstruck", "AC/DC", CardRGBColor(red: 0.12, green: 0.48, blue: 0.86))
            case "long-team": return ("Ellie Fisher", "15", "Piscataway Thunder Softball Association", "Thunderstruck", "AC/DC", CardRGBColor(red: 0.12, green: 0.48, blue: 0.86))
            case "long-song": return ("Ellie Fisher", "15", "P-Way Thunder", "Can't Back Down — Extended Stadium Remix", "AC/DC", CardRGBColor(red: 0.12, green: 0.48, blue: 0.86))
            case "long-artist": return ("Ellie Fisher", "15", "P-Way Thunder", "Thunderstruck", "Demi Lovato, Alyson Stoner & Cast", CardRGBColor(red: 0.12, green: 0.48, blue: 0.86))
            case "busy": return ("Ellie Fisher", "15", "P-Way Thunder", "Thunderstruck", "AC/DC", CardRGBColor(red: 0.02, green: 0.58, blue: 0.40))
            default: return ("Ellie Fisher", "15", "P-Way Thunder", "Thunderstruck", "AC/DC", CardRGBColor(red: 0.95, green: 0.32, blue: 0.08))
            }
        }()
        let model = PlayerCardModel(template: template, playerName: values.0, playerNumber: values.1, teamName: values.2, songTitle: values.3, artistName: values.4, teamColor: colorOverride ?? values.5, photo: photo, crop: crop, spotlightAnalysis: analysis, segmentationMode: segmentationMode, tuning: tuning, brandIcon: PlayerCardArtworkRenderer.bundledBrandIcon)
        return PlayerCardFixture(id: id, title: id.replacingOccurrences(of: "-", with: " ").capitalized, model: model)
    }

    static func comparisonFixtures(template: PlayerCardTemplate, importedPhoto: UIImage? = nil, crop: NormalizedPhotoCrop? = nil, tuning: PlayerCardLabTuning = .default) -> [PlayerCardFixture] {
        ["normal", "long-name", "no-music", "bright", "dark", "wild-color"].map { fixture(id: $0, template: template, importedPhoto: importedPhoto, crop: crop, tuning: tuning) }
    }

    private static func generatedPhoto(for id: String) -> UIImage {
        let size = CGSize(width: 1_400, height: 1_800)
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            let context = rendererContext.cgContext
            let base: UIColor
            switch id {
            case "bright": base = UIColor(red: 0.90, green: 0.84, blue: 0.65, alpha: 1)
            case "dark": base = UIColor(red: 0.025, green: 0.04, blue: 0.09, alpha: 1)
            case "busy", "difficult-background": base = UIColor(red: 0.10, green: 0.28, blue: 0.20, alpha: 1)
            default: base = UIColor(red: 0.12, green: 0.24, blue: 0.40, alpha: 1)
            }
            context.setFillColor(base.cgColor); context.fill(CGRect(origin: .zero, size: size))
            for index in 0..<12 {
                let hue = CGFloat((index * 37) % 360) / 360
                UIColor(hue: hue, saturation: 0.42, brightness: id == "bright" ? 0.96 : 0.72, alpha: id == "busy" ? 0.38 : 0.18).setFill()
                context.fillEllipse(in: CGRect(x: CGFloat((index * 173) % 1_200), y: CGFloat((index * 241) % 1_580), width: 300, height: 300))
            }
            let subjectCenterX: CGFloat = {
                switch id {
                case "subject-left": return 390
                case "subject-right": return 1_010
                default: return 695
                }
            }()
            let headSize: CGFloat = id == "close-up" ? 510 : 350
            UIColor(red: 0.93, green: 0.72, blue: 0.48, alpha: 1).setFill()
            context.fillEllipse(in: CGRect(x: subjectCenterX - headSize / 2, y: id == "close-up" ? 70 : 210, width: headSize, height: headSize))
            UIColor(red: 0.92, green: 0.93, blue: 0.96, alpha: 1).setFill()
            let bodyX = subjectCenterX - (id == "full-body" ? 220 : 280)
            let bodyY: CGFloat = id == "close-up" ? 590 : 560
            let bodyHeight: CGFloat = id == "full-body" ? 1_100 : 1_140
            context.fill(CGRect(x: bodyX, y: bodyY, width: id == "full-body" ? 440 : 560, height: bodyHeight))
            UIColor(red: 0.10, green: 0.14, blue: 0.24, alpha: 1).setFill()
            context.fill(CGRect(x: bodyX - 120, y: id == "full-body" ? 1_320 : 1_050, width: 800, height: 640))
            if id == "multiple-people" || id == "ambiguous-subject" {
                UIColor(red: 0.64, green: 0.46, blue: 0.34, alpha: 1).setFill()
                context.fillEllipse(in: CGRect(x: 125, y: 310, width: 250, height: 250))
                UIColor(red: 0.25, green: 0.34, blue: 0.48, alpha: 1).setFill()
                context.fill(CGRect(x: 95, y: 550, width: 310, height: 780))
            }
            if id == "helmet" {
                UIColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1).setFill()
                context.fillEllipse(in: CGRect(x: subjectCenterX - headSize * 0.54, y: (id == "close-up" ? 70 : 210) - 12, width: headSize * 1.08, height: headSize * 0.52))
            }
            if id == "long-hair" {
                UIColor(red: 0.10, green: 0.06, blue: 0.04, alpha: 1).setFill()
                context.fillEllipse(in: CGRect(x: subjectCenterX - headSize * 0.62, y: (id == "close-up" ? 70 : 210) - 18, width: headSize * 1.24, height: headSize * 1.22))
                UIColor(red: 0.93, green: 0.72, blue: 0.48, alpha: 1).setFill()
                context.fillEllipse(in: CGRect(x: subjectCenterX - headSize / 2, y: id == "close-up" ? 70 : 210, width: headSize, height: headSize))
            }
            if id == "partial-occlusion" {
                UIColor.black.withAlphaComponent(0.60).setFill()
                context.fill(CGRect(x: subjectCenterX - 380, y: 520, width: 760, height: 250))
            }
        }
    }
}

enum CardExportService {
    static func writePNG(_ image: UIImage, named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("RollCallPlayerCardLab", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name).appendingPathExtension("png")
        guard let data = image.pngData() else { throw NSError(domain: "PlayerCardLab", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode the card as PNG."]) }
        try data.write(to: url, options: .atomic)
        return url
    }

    static func contactSheet(fixtures: [PlayerCardFixture], columns: Int = 3) -> UIImage {
        let cellWidth: CGFloat = 300
        let cellHeight: CGFloat = 420
        let sheetSize = CGSize(width: CGFloat(columns) * cellWidth, height: CGFloat((fixtures.count + columns - 1) / columns) * cellHeight)
        return UIGraphicsImageRenderer(size: sheetSize).image { rendererContext in
            let context = rendererContext.cgContext
            UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1).setFill(); context.fill(CGRect(origin: .zero, size: sheetSize))
            for (index, fixture) in fixtures.enumerated() {
                let x = CGFloat(index % columns) * cellWidth
                let y = CGFloat(index / columns) * cellHeight
                let card = PlayerCardArtworkRenderer.render(fixture.model)
                card.draw(in: CGRect(x: x + 10, y: y + 10, width: cellWidth - 20, height: 370))
                PlayerCardArtworkRenderer.drawText(fixture.title, in: CGRect(x: x + 12, y: y + 384, width: cellWidth - 24, height: 26), font: .systemFont(ofSize: 16, weight: .semibold), color: .black, alignment: .center, context: context)
            }
        }
    }
}

// MARK: - Development-only Player Card Lab

struct PlayerCardLabView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var template: PlayerCardTemplate = .broadcast(version: 1)
    @State private var fixtureID = "normal"
    @State private var teamColor = CardRGBColor.rollCallOrange
    @State private var tuning = PlayerCardLabTuning.default
    @State private var segmentationMode: SpotlightSegmentationMode = .auto
    @State private var segmentationBackend: SpotlightSegmentationBackend = .personInstance
    @State private var importedPhoto: UIImage?
    @State private var automaticPhotoCrop: NormalizedPhotoCrop?
    @State private var selectedLabPhotoID: String?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var spotlightAnalysis: SpotlightAnalysisResult?
    @State private var spotlightAnalysisDiagnostic: SpotlightAnalysisDiagnostic?
    @State private var spotlightBreakoutMetrics: SpotlightBreakoutGeometry.Metrics?
    @State private var spotlightAnalysisAttemptKey: String?
    @State private var spotlightAnalysisRetryGeneration = 0
    @State private var activeSpotlightRenderToken: UUID?
    @State private var renderedSpotlightDiagnosticState: SpotlightDiagnosticState?
    @State private var renderedImage: UIImage?
    @State private var exportedURL: URL?
    @State private var isRendering = false
    @State private var isAnalyzing = false
    @State private var isGeneratingContactSheet = false
    @State private var message: String?
    @State private var showTuning = true
    @State private var showDiagnostics = true
    @State private var showSpotlightOverlays = true
    @State private var showPinnedPreview = true

    private var currentFixture: PlayerCardFixture {
        CardFixtureLibrary.fixture(
            id: fixtureID,
            template: template,
            importedPhoto: importedPhoto,
            crop: automaticPhotoCrop,
            tuning: tuning,
            colorOverride: teamColor,
            segmentationMode: segmentationMode,
            analysis: spotlightAnalysis
        )
    }

    private var renderIdentity: String {
        let colorIdentity = [String(describing: teamColor.red), String(describing: teamColor.green), String(describing: teamColor.blue)].joined(separator: ",")
        let analysisIdentity = [spotlightAnalysis?.cacheKey ?? "no-analysis", spotlightAnalysis?.quality.rawValue ?? "none"].joined(separator: ",")
        return [template.title, String(template.version), fixtureID, colorIdentity, String(describing: tuning), segmentationMode.rawValue, segmentationBackend.rawValue, String(spotlightAnalysisRetryGeneration), analysisIdentity, photoIdentity, String(describing: automaticPhotoCrop)].joined(separator: "|")
    }

    private var photoIdentity: String {
        guard let photo = currentFixture.model.photo else { return "none" }
        let source = SpotlightAnalysisService.sourceIdentity(for: photo)
        return importedPhoto == nil ? "fixture-\(fixtureID)-\(source)" : "imported-\(source)"
    }

    private var displayedSpotlightDiagnosticState: SpotlightDiagnosticState {
        renderedSpotlightDiagnosticState ?? .notAnalyzed
    }

    private var displayedSpotlightAnalysisDiagnostic: SpotlightAnalysisDiagnostic {
        spotlightAnalysisDiagnostic ?? .notAnalyzed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                templateSection
                fixtureSection
                colorSection
                if template.title == "Spotlight" {
                    spotlightSection
                }
                tuningSection
                diagnosticsSection
                if template.title == "Spotlight", spotlightAnalysis != nil {
                    spotlightOverlaySection
                }
                exportSection
            }
            .padding(16)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if showPinnedPreview {
                previewSection(isPinned: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(.regularMaterial)
                    .allowsHitTesting(false)
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                }
            }
        .navigationTitle("Player Card Lab")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPinnedPreview.toggle()
                } label: {
                    Image(systemName: showPinnedPreview ? "eye.slash" : "eye")
                }
                .accessibilityLabel(showPinnedPreview ? "Hide preview" : "Show preview")
                .accessibilityIdentifier("player-card-preview-visibility")
                .accessibilityHint(showPinnedPreview ? "Hides the pinned card preview so the Lab details are easier to read." : "Shows the pinned card preview.")
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaPadding(.top, 12)
        .task(id: renderIdentity) {
            await renderCurrentCard()
        }
        .task(id: photoIdentity) {
            await prepareAutomaticPhotoCrop()
        }
        .onChange(of: fixtureID) { _, _ in
            if importedPhoto == nil {
                automaticPhotoCrop = nil
            }
            spotlightAnalysis = nil
            spotlightAnalysisDiagnostic = nil
            spotlightBreakoutMetrics = nil
            spotlightAnalysisAttemptKey = nil
            renderedSpotlightDiagnosticState = nil
            activeSpotlightRenderToken = UUID()
            exportedURL = nil
        }
        .onChange(of: template) { _, newTemplate in
            if newTemplate.title != "Spotlight" { spotlightAnalysis = nil }
            if newTemplate.title != "Spotlight" { spotlightAnalysisDiagnostic = nil }
            spotlightBreakoutMetrics = nil
            spotlightAnalysisAttemptKey = nil
            renderedSpotlightDiagnosticState = nil
            activeSpotlightRenderToken = UUID()
            exportedURL = nil
        }
        .onChange(of: segmentationBackend) { _, _ in
            spotlightAnalysis = nil
            spotlightAnalysisDiagnostic = nil
            spotlightBreakoutMetrics = nil
            spotlightAnalysisAttemptKey = nil
            renderedSpotlightDiagnosticState = nil
            activeSpotlightRenderToken = UUID()
            exportedURL = nil
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                    message = "Could not load that photo into the Lab."
                    return
                }
                importedPhoto = image.rollCallNormalizedUpImage()
                automaticPhotoCrop = nil
                selectedLabPhotoID = nil
                spotlightAnalysis = nil
                spotlightAnalysisDiagnostic = nil
                spotlightBreakoutMetrics = nil
                spotlightAnalysisAttemptKey = nil
                renderedSpotlightDiagnosticState = nil
                activeSpotlightRenderToken = UUID()
                message = "Imported photo is active for this Lab session only."
            }
        }
    }

    private func previewSection(isPinned: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Canonical preview")
                    .font(.headline)
                Spacer()
                if template.title == "Spotlight" {
                    StatusChip(
                        text: displayedSpotlightDiagnosticState.label,
                        role: displayedSpotlightDiagnosticState.role,
                        systemImage: displayedSpotlightDiagnosticState.systemImage,
                        emphasis: .subdued
                    )
                        .accessibilityIdentifier("spotlight-diagnostic-state")
                }
                Text("1080 × 1350 PNG")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                if let renderedImage {
                    Image(uiImage: renderedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
                        .accessibilityLabel("\(template.title) Player Card preview for \(currentFixture.title)")
                } else if isRendering || isAnalyzing {
                    ProgressView("Rendering \(template.title)…")
                } else {
                    ContentUnavailableView("No Preview", systemImage: "photo")
                }
            }
            .frame(maxWidth: isPinned ? .infinity : 560)
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .clipped()
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var templateSection: some View {
        GroupBox("Template") {
            Picker("Template", selection: $template) {
                ForEach(PlayerCardTemplate.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Player Card template")
        }
    }

    private var fixtureSection: some View {
        GroupBox("Fixture") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Fixture", selection: $fixtureID) {
                    ForEach(CardFixtureLibrary.ids, id: \.self) { id in
                        Text(id.replacingOccurrences(of: "-", with: " ").capitalized).tag(id)
                    }
                }
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Import owner-approved Lab photo", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.bordered)
                labPhotoFixtureSection
                if importedPhoto != nil {
                    Button("Use generated fixture photo") {
                        importedPhoto = nil
                        automaticPhotoCrop = nil
                        selectedLabPhotoID = nil
                        spotlightAnalysis = nil
                        spotlightAnalysisDiagnostic = nil
                        spotlightBreakoutMetrics = nil
                        spotlightAnalysisAttemptKey = nil
                        renderedSpotlightDiagnosticState = nil
                        activeSpotlightRenderToken = UUID()
                    }
                    .font(.footnote)
                }
                Text("Fixtures are session-only. No personal photos or rendered derivatives are committed by this Lab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var labPhotoFixtureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Embedded Lab photos")
                .font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                ForEach(LabPhotoFixture.allCases) { fixture in
                    Button {
                        guard let image = fixture.image else {
                            message = "Could not load \(fixture.title) into the Lab."
                            return
                        }
                        importedPhoto = image
                        automaticPhotoCrop = nil
                        selectedLabPhotoID = fixture.id
                        photoPickerItem = nil
                        spotlightAnalysis = nil
                        spotlightAnalysisDiagnostic = nil
                        spotlightBreakoutMetrics = nil
                        spotlightAnalysisAttemptKey = nil
                        renderedSpotlightDiagnosticState = nil
                        activeSpotlightRenderToken = UUID()
                        message = "\(fixture.title) is active for this Lab session only."
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Group {
                                if let image = fixture.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ContentUnavailableView("Missing", systemImage: "photo")
                                }
                            }
                            .frame(height: 78)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text(fixture.title)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selectedLabPhotoID == fixture.id ? Color.accentColor : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(fixture.title) Lab photo")
                }
            }
            Text("These five embedded photos are DEBUG-only Lab fixtures and are not used by the production card flow.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var colorSection: some View {
        GroupBox("Arbitrary team color") {
            VStack(alignment: .leading, spacing: 10) {
                ColorPicker("Live renderer color", selection: Binding(
                    get: { teamColor.swiftUIColor },
                    set: { teamColor = CardRGBColor(uiColor: UIColor($0)) }
                ), supportsOpacity: false)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TeamAccentPreset.allCases) { preset in
                            Button(preset.title) {
                                teamColor = CardRGBColor.from(preset)
                            }
                            .buttonStyle(.bordered)
                            .tint(Color(uiColor: CardRGBColor.from(preset).uiColor))
                        }
                    }
                }
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(teamColor.swiftUIColor)
                    .frame(height: 28)
                    .overlay(Text("Raw Lab color").font(.caption.weight(.semibold)).foregroundStyle(teamColor.luminance > 0.56 ? .black : .white))
            }
        }
    }

    private var spotlightSection: some View {
        GroupBox("Spotlight segmentation") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Mask backend", selection: $segmentationBackend) {
                    ForEach(SpotlightSegmentationBackend.allCases, id: \.self) { backend in
                        Text(backend.title).tag(backend)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Segmentation mode", selection: $segmentationMode) {
                    ForEach(SpotlightSegmentationMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Button("Compare Segmentation States") {
                    Task { await compareSegmentationStates() }
                }
                .buttonStyle(.bordered)
                Button("Compare Mask Backends") {
                    Task { await compareMaskBackends() }
                }
                .buttonStyle(.bordered)
                Button("Retry Current Analysis") {
                    spotlightAnalysis = nil
                    spotlightAnalysisDiagnostic = nil
                    spotlightBreakoutMetrics = nil
                    spotlightAnalysisAttemptKey = nil
                    spotlightAnalysisRetryGeneration += 1
                    activeSpotlightRenderToken = UUID()
                }
                .buttonStyle(.bordered)
                .disabled(currentFixture.model.photo == nil || isAnalyzing)
                Text("Person instances is the default. Foreground instances is a DEBUG-only A/B comparison; neither backend is silently substituted in production.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Forced states reuse the real mask when available; they never fabricate improved masks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var tuningSection: some View {
        DisclosureGroup("Provisional visual controls", isExpanded: $showTuning) {
            VStack(alignment: .leading, spacing: 12) {
                if template.title == "Clean" {
                    labSlider("Gradient start", keyPath: \.cleanGradientStart, range: 0.35...0.85)
                    labSlider("Gradient strength", keyPath: \.cleanGradientStrength, range: 0.55...1.0)
                    labSlider("Name Y", keyPath: \.cleanNameY, range: 680...820)
                    labSlider("Edge light", keyPath: \.cleanEdgeLight, range: 0.00...0.75)
                } else if template.title == "Broadcast" {
                    labSlider("Broadcast angle", keyPath: \.broadcastAngle, range: 7...17)
                    labSlider("Lower-third Y", keyPath: \.broadcastLowerThirdY, range: 620...900)
                    labSlider("Photo height", keyPath: \.broadcastPhotoHeight, range: 800...1_300)
                    labSlider("Player name Y", keyPath: \.broadcastNameY, range: 720...900)
                    labSlider("Music Y", keyPath: \.broadcastMusicY, range: 980...1_140)
                    labSlider("Tinted plane opacity", keyPath: \.broadcastPlaneOpacity, range: 0.25...0.85)
                    labSlider("Giant number opacity", keyPath: \.broadcastNumberOpacity, range: 0.10...1.0)
                    labSlider("Giant number Y", keyPath: \.broadcastGiantNumberY, range: 400...1_000)
                } else {
                    labSlider("Photo width", keyPath: \.spotlightPhotoWidth, range: 520...760)
                    labSlider("Photo height", keyPath: \.spotlightPhotoHeight, range: 700...900)
                    labSlider("Photo Y", keyPath: \.spotlightPhotoY, range: 140...260)
                    labSlider("Atmosphere", keyPath: \.spotlightAtmosphere, range: 0.10...0.60)
                    labSlider("Giant number opacity", keyPath: \.spotlightGiantNumberOpacity, range: 0.08...0.38)
                    labSlider("Rim light", keyPath: \.spotlightRimLight, range: 0.08...0.60)
                    labSlider("Breakout envelope", keyPath: \.spotlightBreakout, range: 0.04...0.22)
                }
                Button("Reset to spec defaults") {
                    tuning = .default
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
    }

    private var diagnosticsSection: some View {
        DisclosureGroup("DEBUG diagnostics", isExpanded: $showDiagnostics) {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Template version", value: "\(template.title) \(template.version)")
                LabeledContent("Canvas", value: "1080 × 1350, scale 1")
                LabeledContent("Photo source", value: importedPhoto == nil ? "Procedural fixture" : "Owner-imported session photo")
                if template.title == "Spotlight" {
                    LabeledContent("Cache", value: spotlightAnalysis?.wasCacheHit == true ? "Hit" : (spotlightAnalysis == nil ? "Not analyzed" : "Miss"))
                        LabeledContent("Rendered state", value: displayedSpotlightDiagnosticState.label)
                        LabeledContent("Analysis quality", value: spotlightAnalysis?.quality.rawValue.capitalized ?? "Not analyzed")
                        LabeledContent("Mask backend", value: spotlightAnalysis?.backend.title ?? segmentationBackend.title)
                        LabeledContent("Request revision", value: "\(spotlightAnalysis?.requestRevision ?? segmentationBackend.requestRevision)")
                        LabeledContent("Analysis diagnostic", value: displayedSpotlightAnalysisDiagnostic.detail)
                    if let analysis = spotlightAnalysis {
                        LabeledContent("Mask bounds", value: String(format: "%.2f, %.2f, %.2f, %.2f", analysis.maskBounds.minX, analysis.maskBounds.minY, analysis.maskBounds.width, analysis.maskBounds.height))
                        LabeledContent("Candidates", value: "\(analysis.candidateCount)")
                        if let selectionReason = analysis.selectionReason {
                            LabeledContent("Subject choice", value: selectionReason)
                        }
                        if let maskMetrics = analysis.maskMetrics {
                            LabeledContent("Mask cleanup", value: maskMetrics.summary)
                        }
                        if let rasterDiagnostics = analysis.maskRasterDiagnostics {
                            LabeledContent("Mask raster", value: rasterDiagnostics.summary)
                        }
                        if let spotlightBreakoutMetrics {
                            LabeledContent("Breakout", value: spotlightBreakoutMetrics.summary)
                        }
                        if !analysis.candidateDiagnostics.isEmpty {
                            let summary = analysis.candidateDiagnostics.map {
                                String(format: "#%d %.3f/%.3f", $0.identifier, $0.area, $0.score())
                            }.joined(separator: " · ")
                            LabeledContent("Candidate scores", value: summary)
                        }
                        Text("Overlays available in the diagnostic mask preview after analysis.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.footnote)
            .padding(.top, 8)
        }
    }

    private var spotlightOverlaySection: some View {
        GroupBox("Spotlight debug overlays") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Show bounds and protected zones", isOn: $showSpotlightOverlays)
                if showSpotlightOverlays, let analysis = spotlightAnalysis {
                    ZStack(alignment: .topLeading) {
                        if let renderedImage {
                            Image(uiImage: renderedImage)
                                .resizable()
                                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                        }
                        GeometryReader { proxy in
                            let size = proxy.size
                            let model = currentFixture.model
                            overlayRect(projectedSourceBounds(analysis.personBounds ?? analysis.maskBounds, in: model), in: size, color: .green, label: "subject")
                            overlayRect(spotlightBreakoutFrame(for: model), in: size, color: .orange, label: "breakout")
                            overlayRect(CGRect(x: 0.05, y: 0.66, width: 0.90, height: 0.18), in: size, color: .red, label: "protected name")
                            if let faceBounds = analysis.faceBounds {
                                overlayRect(projectedSourceBounds(faceBounds, in: model), in: size, color: .blue, label: "face")
                            }
                        }
                    }
                    .aspectRatio(4.0 / 5.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack(spacing: 10) {
                        maskPreview(title: "Raw mask", image: UIImage(cgImage: analysis.mask))
                        maskPreview(title: "Processed mask", image: UIImage(cgImage: analysis.processedMask))
                        maskPreview(title: "Rim mask", image: UIImage(cgImage: analysis.rimLightMask))
                    }
                    Text("Green subject bounds • orange breakout envelope • red protected typography zone • blue face bounds • rim mask and foreground use the same source-photo transform.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func spotlightPhotoFrame(for model: PlayerCardModel) -> CGRect {
        let frame = spotlightPhotoRect(for: model)
        return CGRect(x: frame.minX / PlayerCardModel.canvasSize.width, y: frame.minY / PlayerCardModel.canvasSize.height, width: frame.width / PlayerCardModel.canvasSize.width, height: frame.height / PlayerCardModel.canvasSize.height)
    }

    private func spotlightPhotoRect(for model: PlayerCardModel) -> CGRect {
        CGRect(
            x: (PlayerCardModel.canvasSize.width - model.tuning.spotlightPhotoWidth) / 2,
            y: model.tuning.spotlightPhotoY,
            width: model.tuning.spotlightPhotoWidth,
            height: model.tuning.spotlightPhotoHeight
        )
    }

    private func breakoutMetrics(for analysis: SpotlightAnalysisResult, model: PlayerCardModel) -> SpotlightBreakoutGeometry.Metrics? {
        let photoRect = spotlightPhotoRect(for: model)
        let quality: SpotlightSegmentationQuality = switch model.segmentationMode {
        case .auto: analysis.quality
        case .forceExcellent: .excellent
        case .forceUsable: .usable
        case .forceFallback: .fallback
        }
        guard quality != .fallback else { return nil }
        let envelope = SpotlightBreakoutGeometry.envelope(
            photoRect: photoRect,
            breakout: model.tuning.spotlightBreakout,
            quality: quality
        )
        return SpotlightBreakoutGeometry.measure(
            mask: analysis.processedMask,
            crop: model.crop,
            photoRect: photoRect,
            envelope: envelope,
            protectedZones: [CGRect(x: 54, y: 891, width: 972, height: 243)]
        )
    }

    private func spotlightBreakoutFrame(for model: PlayerCardModel) -> CGRect {
        let photoRect = spotlightPhotoRect(for: model)
        let quality: SpotlightSegmentationQuality = if let analysis = model.spotlightAnalysis {
            switch model.segmentationMode {
            case .auto: analysis.quality
            case .forceExcellent: .excellent
            case .forceUsable: .usable
            case .forceFallback: .fallback
            }
        } else {
            .fallback
        }
        let envelope = SpotlightBreakoutGeometry.envelope(
            photoRect: photoRect,
            breakout: model.tuning.spotlightBreakout,
            quality: quality
        )
        return CGRect(
            x: envelope.minX / PlayerCardModel.canvasSize.width,
            y: envelope.minY / PlayerCardModel.canvasSize.height,
            width: envelope.width / PlayerCardModel.canvasSize.width,
            height: envelope.height / PlayerCardModel.canvasSize.height
        )
    }

    private func projectedSourceBounds(_ sourceBounds: CGRect, in model: PlayerCardModel) -> CGRect {
        guard let photo = model.photo, let image = photo.rollCallNormalizedUpImage().cgImage else { return .zero }
        let photoRect = spotlightPhotoRect(for: model)
        let sourceSize = CGSize(width: image.width, height: image.height)
        let projected = SpotlightPhotoTransform(sourceSize: sourceSize, crop: model.crop, destinationFrame: photoRect).projectedSourceRect(sourceBounds)
        return CGRect(x: projected.minX / PlayerCardModel.canvasSize.width, y: projected.minY / PlayerCardModel.canvasSize.height, width: projected.width / PlayerCardModel.canvasSize.width, height: projected.height / PlayerCardModel.canvasSize.height)
    }

    private func overlayRect(_ normalizedRect: CGRect, in size: CGSize, color: Color, label: String) -> some View {
        let rect = CGRect(x: normalizedRect.minX * size.width, y: normalizedRect.minY * size.height, width: normalizedRect.width * size.width, height: normalizedRect.height * size.height)
        return Rectangle()
            .stroke(color, lineWidth: 2)
            .frame(width: max(1, rect.width), height: max(1, rect.height))
            .position(x: rect.midX, y: rect.midY)
            .overlay(alignment: .topLeading) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .padding(3)
                    .background(color.opacity(0.85))
                    .foregroundStyle(.black)
            }
    }

    private func maskPreview(title: String, image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold))
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 110)
                .background(Color.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exportSection: some View {
        GroupBox("Export and contact sheets") {
            VStack(alignment: .leading, spacing: 10) {
                Button("Export current card PNG") {
                    Task { await exportCurrentCard() }
                }
                .buttonStyle(.borderedProminent)
                Button {
                    Task { await generateTemplateContactSheet() }
                } label: {
                    HStack(spacing: 8) {
                        if isGeneratingContactSheet {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isGeneratingContactSheet ? "Generating comparison…" : "Generate template comparison contact sheet")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingContactSheet)
                if let exportedURL {
                    ShareLink(item: exportedURL) {
                        Label("Share latest Lab output", systemImage: "square.and.arrow.up")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                Text("Outputs are written to a temporary Lab directory and are not added to team state, packages, or the production share flow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func labSlider(_ title: String, keyPath: WritableKeyPath<PlayerCardLabTuning, CGFloat>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", tuning[keyPath: keyPath]))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { Double(tuning[keyPath: keyPath]) },
                set: { tuning[keyPath: keyPath] = CGFloat($0) }
            ), in: range)
        }
        .font(.footnote)
    }

    private func prepareAutomaticPhotoCrop() async {
        guard let photo = currentFixture.model.photo else {
            automaticPhotoCrop = nil
            return
        }

        automaticPhotoCrop = nil
        let options = await PlayerPhotoPreparationService().framingOptions(for: photo)
        guard !Task.isCancelled else { return }
        automaticPhotoCrop = options.card[.automatic]
    }

    private func renderCurrentCard() async {
        let renderIdentityAtStart = renderIdentity
        let renderToken = UUID()
        activeSpotlightRenderToken = renderToken
        isRendering = true
        isAnalyzing = false
        let fallbackModel = currentFixture.model
        let image = await Task.detached(priority: .userInitiated) {
            PlayerCardArtworkRenderer.render(fallbackModel)
        }.value
        guard !Task.isCancelled, activeSpotlightRenderToken == renderToken, renderIdentity == renderIdentityAtStart else { return }
        renderedImage = image
        if template.title == "Spotlight" {
            if let analysis = spotlightAnalysis {
                spotlightBreakoutMetrics = breakoutMetrics(for: analysis, model: fallbackModel)
            } else {
                spotlightBreakoutMetrics = nil
            }
            let needsAnalysis = fallbackModel.photo != nil && spotlightAnalysis == nil
            renderedSpotlightDiagnosticState = needsAnalysis
                ? .fallbackAnalyzing
                : SpotlightDiagnosticState.resolve(
                    mode: segmentationMode,
                    analysis: spotlightAnalysis,
                    isAnalyzing: false,
                    hasPhoto: fallbackModel.photo != nil,
                    diagnostic: spotlightAnalysisDiagnostic,
                    breakoutMetrics: spotlightBreakoutMetrics
                )
        } else {
            renderedSpotlightDiagnosticState = nil
        }
        isRendering = false

        guard template.title == "Spotlight", let photo = fallbackModel.photo, spotlightAnalysis == nil else { return }
        let identity = SpotlightAnalysisService.sourceIdentity(for: photo)
        let analysisKey = SpotlightAnalysisService.cacheKey(for: identity, crop: fallbackModel.crop, backend: segmentationBackend)
        guard spotlightAnalysisAttemptKey != analysisKey else { return }
        spotlightAnalysisAttemptKey = analysisKey
        isAnalyzing = true
        spotlightAnalysisDiagnostic = .analyzing
        renderedSpotlightDiagnosticState = .fallbackAnalyzing
        let report = await SpotlightAnalysisService.shared.analyze(
            photo: photo,
            crop: fallbackModel.crop,
            identity: identity,
            backend: segmentationBackend
        )
        guard !Task.isCancelled, activeSpotlightRenderToken == renderToken, renderIdentity == renderIdentityAtStart else { return }
        spotlightAnalysis = report.result
        spotlightAnalysisDiagnostic = report.diagnostic
        if let result = report.result {
            spotlightBreakoutMetrics = breakoutMetrics(for: result, model: fallbackModel)
        } else {
            spotlightBreakoutMetrics = nil
        }
        isAnalyzing = false
        if report.result == nil {
            renderedSpotlightDiagnosticState = SpotlightDiagnosticState.resolve(
                mode: segmentationMode,
                analysis: nil,
                isAnalyzing: false,
                hasPhoto: fallbackModel.photo != nil,
                diagnostic: report.diagnostic
            )
        }
    }

    private func exportCurrentCard() async {
        guard let renderedImage else { return }
        do {
            exportedURL = try CardExportService.writePNG(renderedImage, named: "\(template.title.lowercased())-\(fixtureID)")
            message = "Exported canonical PNG to the temporary Lab directory."
        } catch {
            message = error.localizedDescription
        }
    }

    private func generateTemplateContactSheet() async {
        guard !isGeneratingContactSheet else { return }
        isGeneratingContactSheet = true
        exportedURL = nil
        message = "Generating template comparison…"
        defer { isGeneratingContactSheet = false }

        let comparisonIDs = ["normal", "long-name", "no-music", "bright", "dark", "wild-color"]
        let totalFixtureCount = comparisonIDs.count * PlayerCardTemplate.allCases.count
        var fixtures: [PlayerCardFixture] = []
        var spotlightAnalysesByIdentity: [String: SpotlightAnalysisResult] = [:]
        for id in comparisonIDs {
            for item in PlayerCardTemplate.allCases {
                var fixture = CardFixtureLibrary.fixture(id: id, template: item, importedPhoto: importedPhoto, crop: automaticPhotoCrop, tuning: tuning, colorOverride: teamColor)
                if item.title == "Spotlight", let photo = fixture.model.photo {
                    let identity = "\(SpotlightAnalysisService.sourceIdentity(for: photo))|\(segmentationBackend.rawValue)"
                    if let cached = spotlightAnalysesByIdentity[identity] {
                        fixture = CardFixtureLibrary.fixture(id: id, template: item, importedPhoto: importedPhoto, crop: automaticPhotoCrop, tuning: tuning, colorOverride: teamColor, analysis: cached)
                    } else {
                        let report = await SpotlightAnalysisService.shared.analyze(
                            photo: photo,
                            crop: fixture.model.crop,
                            identity: SpotlightAnalysisService.sourceIdentity(for: photo),
                            backend: segmentationBackend
                        )
                        if let analysis = report.result {
                            spotlightAnalysesByIdentity[identity] = analysis
                            fixture = CardFixtureLibrary.fixture(id: id, template: item, importedPhoto: importedPhoto, crop: automaticPhotoCrop, tuning: tuning, colorOverride: teamColor, analysis: analysis)
                        }
                    }
                }
                fixtures.append(fixture)
                message = "Generating template comparison… \(fixtures.count) of \(totalFixtureCount)"
            }
        }
        let sheet = await Task.detached(priority: .userInitiated) {
            CardExportService.contactSheet(fixtures: fixtures, columns: 3)
        }.value
        do {
            exportedURL = try CardExportService.writePNG(sheet, named: "template-comparison-contact-sheet")
            message = "Generated a template comparison contact sheet."
        } catch {
            message = error.localizedDescription
        }
    }

    private func compareSegmentationStates() async {
        guard template.title == "Spotlight" else { return }
        let modes: [SpotlightSegmentationMode] = [.forceExcellent, .forceUsable, .forceFallback]
        let fixtures = modes.map { mode in
            let fixture = CardFixtureLibrary.fixture(id: fixtureID, template: .spotlight(version: 1), importedPhoto: importedPhoto, crop: automaticPhotoCrop, tuning: tuning, colorOverride: teamColor, segmentationMode: mode, analysis: spotlightAnalysis)
            let title = spotlightAnalysis == nil
                ? "\(mode.title) · no mask (fallback)"
                : mode.title
            return PlayerCardFixture(id: "\(fixtureID)-\(mode.rawValue)", title: title, model: fixture.model)
        }
        let sheet = await Task.detached(priority: .userInitiated) {
            CardExportService.contactSheet(fixtures: fixtures, columns: 3)
        }.value
        do {
            exportedURL = try CardExportService.writePNG(sheet, named: "spotlight-segmentation-comparison")
            message = "Generated Excellent / Usable / Fallback comparison."
        } catch {
            message = error.localizedDescription
        }
    }

    private func compareMaskBackends() async {
        let snapshotFixtureID = fixtureID
        let snapshotImportedPhoto = importedPhoto
        let snapshotTuning = tuning
        let snapshotTeamColor = teamColor
        let snapshotModel = currentFixture.model
        guard template.title == "Spotlight", let photo = snapshotModel.photo else {
            message = "Choose a Spotlight photo before comparing mask backends."
            return
        }

        let identity = SpotlightAnalysisService.sourceIdentity(for: photo)
        let crop = snapshotModel.crop
        var fixtures: [PlayerCardFixture] = []
        for backend in SpotlightSegmentationBackend.allCases {
            message = "Comparing \(backend.title)…"
            let report = await SpotlightAnalysisService.shared.analyze(
                photo: photo,
                crop: crop,
                identity: identity,
                backend: backend
            )
            if let analysis = report.result {
                let fixture = CardFixtureLibrary.fixture(
                    id: snapshotFixtureID,
                    template: .spotlight(version: 1),
                    importedPhoto: snapshotImportedPhoto,
                    crop: crop,
                    tuning: snapshotTuning,
                    colorOverride: snapshotTeamColor,
                    segmentationMode: .auto,
                    analysis: analysis
                )
                fixtures.append(PlayerCardFixture(
                    id: "\(snapshotFixtureID)-\(backend.rawValue)",
                    title: "\(backend.title) · \(analysis.quality.rawValue.capitalized)",
                    model: fixture.model
                ))
            } else {
                let fixture = CardFixtureLibrary.fixture(
                    id: snapshotFixtureID,
                    template: .spotlight(version: 1),
                    importedPhoto: snapshotImportedPhoto,
                    crop: crop,
                    tuning: snapshotTuning,
                    colorOverride: snapshotTeamColor,
                    segmentationMode: .forceFallback
                )
                fixtures.append(PlayerCardFixture(
                    id: "\(snapshotFixtureID)-\(backend.rawValue)",
                    title: "\(backend.title) · Fallback",
                    model: fixture.model
                ))
            }
        }

        let sheet = await Task.detached(priority: .userInitiated) {
            CardExportService.contactSheet(fixtures: fixtures, columns: 2)
        }.value
        do {
            exportedURL = try CardExportService.writePNG(sheet, named: "spotlight-mask-backend-comparison")
            message = "Generated a same-photo Person / Foreground backend comparison."
        } catch {
            message = error.localizedDescription
        }
    }
}

#Preview("Player Card Lab") {
    NavigationStack {
        PlayerCardLabView()
    }
}
#endif
