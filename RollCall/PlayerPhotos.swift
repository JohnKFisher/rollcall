import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UIKit
import Vision

struct NormalizedPhotoCrop: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let full = NormalizedPhotoCrop(x: 0, y: 0, width: 1, height: 1)

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: CGRect) {
        self.init(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    func clamped() -> NormalizedPhotoCrop {
        let clampedWidth = min(max(width, 0.01), 1)
        let clampedHeight = min(max(height, 0.01), 1)
        return NormalizedPhotoCrop(
            x: min(max(x, 0), 1 - clampedWidth),
            y: min(max(y, 0), 1 - clampedHeight),
            width: clampedWidth,
            height: clampedHeight
        )
    }
}

enum PlayerPhotoDetectionResult: String, Codable, Equatable, Sendable {
    case faceAndPerson
    case multiplePeople
    case faceOnly
    case personOnly
    case noUsableDetection
}

enum PlayerPhotoFramingMode: String, CaseIterable, Hashable, Sendable {
    case automatic
    case face
    case headAndShoulders
    case upperBody
    case fullBody
    case centered

    var title: String {
        switch self {
        case .automatic: return "Auto"
        case .face: return "Face"
        case .headAndShoulders: return "Head & Shoulders"
        case .upperBody: return "Upper Body"
        case .fullBody: return "Full Body"
        case .centered: return "Centered"
        }
    }
}

struct PlayerPhotoFramingOptionSet: Equatable, Sendable {
    var profile: [PlayerPhotoFramingMode: NormalizedPhotoCrop]
    var card: [PlayerPhotoFramingMode: NormalizedPhotoCrop]
}

struct PlayerPhotoAnalysis: Equatable, Sendable {
    var profileCrop: NormalizedPhotoCrop
    var cardCrop: NormalizedPhotoCrop
    var result: PlayerPhotoDetectionResult
}

struct PreparedPlayerPhoto: Sendable {
    var masterJPEG: Data
    var profileJPEG: Data
    var profileCrop: NormalizedPhotoCrop
    var cardCrop: NormalizedPhotoCrop
    var detectionResult: PlayerPhotoDetectionResult
}

enum PlayerPhotoPreparationError: LocalizedError {
    case unreadableImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Roll Call could not read that photo."
        case .encodingFailed:
            return "Roll Call could not prepare that photo."
        }
    }
}

enum PlayerPhotoFramingSourceIdentity: Equatable {
    case workingMaster(relativePath: String)
    case legacyProfile(relativePath: String)

    var relativePath: String {
        switch self {
        case .workingMaster(let relativePath), .legacyProfile(let relativePath):
            return relativePath
        }
    }

    func matches(_ player: Player) -> Bool {
        switch self {
        case .workingMaster(let relativePath):
            return player.photoSourceRelativePath == relativePath
        case .legacyProfile(let relativePath):
            return player.photoSourceRelativePath == nil
                && player.photoRelativePath == relativePath
        }
    }
}

struct PlayerPhotoFramingRequest: Equatable, Identifiable {
    let id: UUID
    let source: PlayerPhotoFramingSourceIdentity

    init(source: PlayerPhotoFramingSourceIdentity) {
        id = UUID()
        self.source = source
    }

    func validatedSourcePath(activeRequestID: UUID?, player: Player) -> String? {
        guard activeRequestID == id, source.matches(player) else { return nil }
        return source.relativePath
    }

    @discardableResult
    func applyProfileFraming(
        _ crop: NormalizedPhotoCrop,
        profileRelativePath: String,
        activeRequestID: UUID?,
        to player: inout Player
    ) -> Bool {
        guard let sourcePath = validatedSourcePath(activeRequestID: activeRequestID, player: player) else {
            return false
        }
        player.photoSourceRelativePath = sourcePath
        player.photoRelativePath = profileRelativePath
        player.profilePhotoCrop = crop
        return true
    }
}

struct PlayerPhotoPreparationService: Sendable {
    static let masterMaximumDimension: CGFloat = 3_000
    static let profilePixelSize = CGSize(width: 640, height: 640)

    func prepare(data: Data) async throws -> PreparedPlayerPhoto {
        try await Task.detached(priority: .userInitiated) {
            guard let master = Self.decodeWorkingMaster(from: data),
                  let cgImage = master.cgImage else {
                throw PlayerPhotoPreparationError.unreadableImage
            }

            let observations = (try? Self.detect(in: cgImage)) ?? (faces: [], people: [], upperBodies: [])
            let analysis = PlayerPhotoFramingGeometry.analyze(
                faces: observations.faces,
                people: observations.people,
                upperBodies: observations.upperBodies,
                imageSize: master.size
            )
            guard let masterJPEG = master.jpegData(compressionQuality: 0.9),
                  let profileImage = master.cropped(to: analysis.profileCrop, outputSize: Self.profilePixelSize),
                  let profileJPEG = profileImage.jpegData(compressionQuality: 0.86) else {
                throw PlayerPhotoPreparationError.encodingFailed
            }

            return PreparedPlayerPhoto(
                masterJPEG: masterJPEG,
                profileJPEG: profileJPEG,
                profileCrop: analysis.profileCrop,
                cardCrop: analysis.cardCrop,
                detectionResult: analysis.result
            )
        }.value
    }

    func framingOptions(for image: UIImage) async -> PlayerPhotoFramingOptionSet {
        let normalized = image.rollCallNormalizedUpImage()
        guard let cgImage = normalized.cgImage else {
            return PlayerPhotoFramingGeometry.framingOptions(
                faces: [],
                people: [],
                upperBodies: [],
                imageSize: image.size
            )
        }

        return await Task.detached(priority: .userInitiated) {
            let observations = (try? Self.detect(in: cgImage)) ?? (faces: [], people: [], upperBodies: [])
            return PlayerPhotoFramingGeometry.framingOptions(
                faces: observations.faces,
                people: observations.people,
                upperBodies: observations.upperBodies,
                imageSize: CGSize(width: cgImage.width, height: cgImage.height)
            )
        }.value
    }

    private static func decodeWorkingMaster(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(masterMaximumDimension),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    private static func detect(in image: CGImage) throws -> (faces: [CGRect], people: [CGRect], upperBodies: [CGRect]) {
        let faceRequest = VNDetectFaceRectanglesRequest()
        let fullPersonRequest = VNDetectHumanRectanglesRequest()
        fullPersonRequest.upperBodyOnly = false
        let upperBodyRequest = VNDetectHumanRectanglesRequest()
        upperBodyRequest.upperBodyOnly = true
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try handler.perform([faceRequest, fullPersonRequest, upperBodyRequest])

        func topLeftRect(_ visionRect: CGRect) -> CGRect {
            CGRect(
                x: visionRect.minX,
                y: 1 - visionRect.maxY,
                width: visionRect.width,
                height: visionRect.height
            )
        }

        let fullPeople = (fullPersonRequest.results ?? []).map { topLeftRect($0.boundingBox) }
        let upperBodies = (upperBodyRequest.results ?? []).map { topLeftRect($0.boundingBox) }
        return (
            (faceRequest.results ?? []).map { topLeftRect($0.boundingBox) },
            fullPeople,
            upperBodies
        )
    }
}

enum PlayerPhotoFramingGeometry {
    /// Matches the selected Broadcast card's rectangular photo viewport.
    static let playerCardPhotoViewportSize = CGSize(width: 1_092, height: 900)
    static let playerCardPhotoAspectRatio: CGFloat = playerCardPhotoViewportSize.width / playerCardPhotoViewportSize.height

    static func analyze(
        faces: [CGRect],
        people: [CGRect],
        upperBodies: [CGRect] = [],
        imageSize: CGSize
    ) -> PlayerPhotoAnalysis {
        let options = framingOptions(
            faces: faces,
            people: people,
            upperBodies: upperBodies,
            imageSize: imageSize
        )
        let validFaces = faces.map(clampUnitRect).filter { !$0.isEmpty }
        let validPeople = people.map(clampUnitRect).filter { !$0.isEmpty }
        let validUpperBodies = upperBodies.map(clampUnitRect).filter { !$0.isEmpty }
        let detectionPeople = validPeople.isEmpty ? validUpperBodies : validPeople
        let selectedPerson = bestCandidate(in: detectionPeople)
        let selectedFace = selectPrimaryFace(from: validFaces)
        let faceMatchesSelectedPerson = selectedFace.map { face in
            selectedPerson?.insetBy(dx: -0.04, dy: -0.04)
                .contains(CGPoint(x: face.midX, y: face.midY)) == true
        } ?? true
        let hasMultiplePeople = validFaces.count > 1
            || detectionPeople.count > 1
            || (selectedFace != nil && selectedPerson != nil && !faceMatchesSelectedPerson)

        let result: PlayerPhotoDetectionResult
        if hasMultiplePeople {
            result = .multiplePeople
        } else if selectedFace != nil, selectedPerson != nil {
            result = .faceAndPerson
        } else if selectedFace != nil {
            result = .faceOnly
        } else if selectedPerson != nil {
            result = .personOnly
        } else {
            result = .noUsableDetection
        }

        return PlayerPhotoAnalysis(
            profileCrop: options.profile[.automatic] ?? .full,
            cardCrop: options.card[.automatic] ?? .full,
            result: result
        )
    }

    static func framingOptions(
        faces: [CGRect],
        people: [CGRect],
        upperBodies: [CGRect] = [],
        imageSize: CGSize
    ) -> PlayerPhotoFramingOptionSet {
        let validFaces = faces.map(clampUnitRect).filter { !$0.isEmpty }
        let validPeople = people.map(clampUnitRect).filter { !$0.isEmpty }
        let validUpperBodies = upperBodies.map(clampUnitRect).filter { !$0.isEmpty }
        let selectedPerson = bestCandidate(in: validPeople)
        let selectedFace = selectPrimaryFace(from: validFaces)
        let selectedUpperBody = bestUpperBody(
            in: validUpperBodies,
            matching: selectedPerson,
            face: selectedFace
        )

        let profileAnchor: CGRect
        if let selectedFace {
            profileAnchor = selectedFace.insetBy(dx: -selectedFace.width * 0.6, dy: -selectedFace.height * 0.85)
                .offsetBy(dx: 0, dy: selectedFace.height * 0.35)
        } else if let selectedPerson {
            profileAnchor = CGRect(
                x: selectedPerson.minX,
                y: selectedPerson.minY,
                width: selectedPerson.width,
                height: min(selectedPerson.height * 0.58, 1 - selectedPerson.minY)
            )
        } else {
            profileAnchor = CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.5)
        }

        let cardFallback = CGRect(x: 0.12, y: 0.06, width: 0.76, height: 0.88)
        let faceAnchor = selectedFace.map {
            $0.insetBy(dx: -$0.width * 1.8, dy: -$0.height * 2.1)
                .offsetBy(dx: 0, dy: $0.height * 0.55)
        } ?? cardFallback
        let upperBodyAnchor = selectedUpperBody
            ?? selectedPerson.map(upperPortion(of:))
            ?? faceAnchor
        let headAndShouldersAnchor = headAndShoulders(
            face: selectedFace,
            upperBody: selectedUpperBody,
            fallback: upperBodyAnchor
        )
        let fullBodyAnchor = selectedPerson ?? selectedUpperBody ?? faceAnchor
        let automaticCardBodyAnchor: CGRect
        if let selectedFace {
            automaticCardBodyAnchor = bestAssociatedBody(in: validUpperBodies, matching: selectedFace)
                ?? bestAssociatedBody(in: validPeople, matching: selectedFace).map(upperPortion(of:))
                ?? faceAnchor
        } else {
            automaticCardBodyAnchor = upperBodyAnchor
        }
        let automaticCardAnchor = automaticCardBodyAnchor.union(faceAnchor)

        func crop(_ anchor: CGRect, _ aspectRatio: CGFloat) -> NormalizedPhotoCrop {
            NormalizedPhotoCrop(aspectCrop(containing: anchor, aspectRatio: aspectRatio, imageSize: imageSize))
        }

        return PlayerPhotoFramingOptionSet(
            profile: [
                .automatic: crop(profileAnchor, 1),
                .face: crop(faceAnchor, 1),
                .headAndShoulders: crop(headAndShouldersAnchor, 1),
                .upperBody: crop(upperBodyAnchor, 1),
                .fullBody: crop(fullBodyAnchor, 1),
                .centered: centeredCrop(aspectRatio: 1, imageSize: imageSize)
            ],
            card: [
                .automatic: crop(automaticCardAnchor, playerCardPhotoAspectRatio),
                .face: crop(faceAnchor, playerCardPhotoAspectRatio),
                .headAndShoulders: crop(headAndShouldersAnchor, playerCardPhotoAspectRatio),
                .upperBody: crop(upperBodyAnchor, playerCardPhotoAspectRatio),
                .fullBody: crop(fullBodyAnchor, playerCardPhotoAspectRatio),
                .centered: centeredCrop(aspectRatio: playerCardPhotoAspectRatio, imageSize: imageSize)
            ]
        )
    }

    /// The largest centred crop of `imageSize` at `aspectRatio`.
    ///
    /// The anchor must be the full frame, not a zero-sized centre point.
    /// `aspectCrop` grows its anchor multiplicatively (`max(w, h * ratio)`), so a
    /// zero-sized anchor stays zero for every input and yields a degenerate crop —
    /// which `NormalizedPhotoCrop.clamped()` then floors to 0.01 x 0.01, blowing a
    /// 1% sliver of the photo up across the whole viewport.
    static func centeredCrop(aspectRatio: CGFloat, imageSize: CGSize) -> NormalizedPhotoCrop {
        NormalizedPhotoCrop(aspectCrop(containing: CGRect(x: 0, y: 0, width: 1, height: 1), aspectRatio: aspectRatio, imageSize: imageSize))
    }

    private static func bestCandidate(in candidates: [CGRect]) -> CGRect? {
        candidates.max { score($0) < score($1) }
    }

    /// Selects the most prominent face using its size, image position, and distance from an edge.
    /// Human-rectangle detections are not used to constrain this choice because Vision can miss the
    /// primary subject while still detecting a secondary person near an edge.
    static func selectPrimaryFace(from faces: [CGRect]) -> CGRect? {
        faces
            .map(clampUnitRect)
            .filter { !$0.isEmpty }
            .sorted(by: isPreferredPrimaryFace)
            .first
    }

    /// Larger faces get a prominence advantage; central faces get a modest position advantage;
    /// faces within 6% of an image edge receive up to a 0.12 penalty.
    static func primaryFaceScore(for rawRect: CGRect) -> CGFloat {
        let rect = clampUnitRect(rawRect)
        let area = rect.width * rect.height
        let centerDistance = hypot(rect.midX - 0.5, rect.midY - 0.5)
        let edgeMargin = min(min(rect.minX, rect.minY), min(1 - rect.maxX, 1 - rect.maxY))
        let edgePenalty = max(0, (0.06 - edgeMargin) / 0.06) * 0.12
        return area * 4 - centerDistance * 0.35 - edgePenalty
    }

    private static func isPreferredPrimaryFace(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let lhsScore = primaryFaceScore(for: lhs)
        let rhsScore = primaryFaceScore(for: rhs)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.minX != rhs.minX { return lhs.minX < rhs.minX }
        if lhs.minY != rhs.minY { return lhs.minY < rhs.minY }
        if lhs.width != rhs.width { return lhs.width > rhs.width }
        return lhs.height > rhs.height
    }

    private static func bestUpperBody(in bodies: [CGRect], matching person: CGRect?, face: CGRect?) -> CGRect? {
        let matching = bodies.filter { body in
            if let face {
                return body.insetBy(dx: -0.04, dy: -0.04)
                    .contains(CGPoint(x: face.midX, y: face.midY))
            }
            if let person {
                return person.insetBy(dx: -0.08, dy: -0.08).intersects(body)
            }
            return true
        }
        return bestCandidate(in: matching.isEmpty ? bodies : matching)
    }

    /// Selects a body observation that has plausible geometric association with the selected face.
    /// Vision rectangles use top-left normalized coordinates here. This is intentionally separate
    /// from `bestUpperBody`, whose global fallback remains available to explicit framing presets.
    static func bestAssociatedBody(in candidates: [CGRect], matching rawFace: CGRect) -> CGRect? {
        let face = clampUnitRect(rawFace)
        guard !face.isEmpty else { return nil }

        return candidates
            .map(clampUnitRect)
            .filter { isGeometricallyAssociated(face: face, body: $0) }
            .sorted { isStrongerAssociation(face: face, lhs: $0, rhs: $1) }
            .first
    }

    private static func isGeometricallyAssociated(face: CGRect, body: CGRect) -> Bool {
        guard !body.isEmpty else { return false }

        let horizontalTolerance = max(0.01, face.width * 0.1)
        let faceCenterX = face.midX
        guard faceCenterX >= body.minX - horizontalTolerance,
              faceCenterX <= body.maxX + horizontalTolerance,
              horizontalOverlapFraction(face: face, body: body) >= 0.5 else {
            return false
        }

        let verticalTolerance = max(0.01, face.height * 0.25)
        let faceCenterFromBodyTop = face.midY - body.minY
        return faceCenterFromBodyTop >= -verticalTolerance
            && faceCenterFromBodyTop <= body.height * 0.55
    }

    private static func isStrongerAssociation(face: CGRect, lhs: CGRect, rhs: CGRect) -> Bool {
        let lhsOverlap = horizontalOverlapFraction(face: face, body: lhs)
        let rhsOverlap = horizontalOverlapFraction(face: face, body: rhs)
        if lhsOverlap != rhsOverlap { return lhsOverlap > rhsOverlap }

        let lhsDistance = normalizedDistanceToHead(face: face, body: lhs)
        let rhsDistance = normalizedDistanceToHead(face: face, body: rhs)
        if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
        if lhs.minX != rhs.minX { return lhs.minX < rhs.minX }
        if lhs.minY != rhs.minY { return lhs.minY < rhs.minY }
        if lhs.width != rhs.width { return lhs.width < rhs.width }
        return lhs.height < rhs.height
    }

    private static func horizontalOverlapFraction(face: CGRect, body: CGRect) -> CGFloat {
        let overlap = max(0, min(face.maxX, body.maxX) - max(face.minX, body.minX))
        return overlap / max(face.width, 0.001)
    }

    private static func normalizedDistanceToHead(face: CGRect, body: CGRect) -> CGFloat {
        let expectedHeadX = body.midX
        let expectedHeadY = body.minY + body.height * 0.25
        let dx = (face.midX - expectedHeadX) / max(body.width, 0.001)
        let dy = (face.midY - expectedHeadY) / max(body.height, 0.001)
        return hypot(dx, dy)
    }

    private static func upperPortion(of person: CGRect) -> CGRect {
        CGRect(x: person.minX, y: person.minY, width: person.width, height: min(person.height * 0.62, 1 - person.minY))
    }

    private static func headAndShoulders(face: CGRect?, upperBody: CGRect?, fallback: CGRect) -> CGRect {
        guard let upperBody else { return fallback }

        let shoulderWidth = upperBody.width * 1.12
        let shoulderX = upperBody.midX - shoulderWidth / 2
        let top = min(upperBody.minY, face?.minY ?? upperBody.minY)
        let upperBodyHeight = min(upperBody.height * 0.7, 1 - top)
        let torso = CGRect(x: shoulderX, y: top, width: shoulderWidth, height: upperBodyHeight)
        return face.map { torso.union($0) } ?? torso
    }

    private static func score(_ rect: CGRect) -> CGFloat {
        let centerDistance = hypot(rect.midX - 0.5, rect.midY - 0.5)
        return rect.width * rect.height * 4 - centerDistance * 0.35
    }

    private static func aspectCrop(containing rawAnchor: CGRect, aspectRatio: CGFloat, imageSize: CGSize) -> CGRect {
        let anchor = clampUnitRect(rawAnchor)
        let normalizedImageAspect = max(imageSize.width / max(imageSize.height, 1), 0.001)
        let normalizedTargetWidthPerHeight = aspectRatio / normalizedImageAspect

        var width = max(anchor.width, anchor.height * normalizedTargetWidthPerHeight)
        var height = max(anchor.height, width / normalizedTargetWidthPerHeight)
        if width > 1 {
            width = 1
            height = min(1, width / normalizedTargetWidthPerHeight)
        }
        if height > 1 {
            height = 1
            width = min(1, height * normalizedTargetWidthPerHeight)
        }

        let center = CGPoint(x: anchor.midX, y: anchor.midY)
        return clampUnitRect(CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
    }

    private static func clampUnitRect(_ rect: CGRect) -> CGRect {
        let width = min(max(rect.width, 0), 1)
        let height = min(max(rect.height, 0), 1)
        return CGRect(
            x: min(max(rect.minX, 0), 1 - width),
            y: min(max(rect.minY, 0), 1 - height),
            width: width,
            height: height
        )
    }
}

extension UIImage {
    func cropped(to normalizedCrop: NormalizedPhotoCrop, outputSize: CGSize) -> UIImage? {
        let normalized = rollCallNormalizedUpImage()
        guard let cgImage = normalized.cgImage else { return nil }
        let crop = normalizedCrop.clamped().cgRect
        let pixelRect = CGRect(
            x: crop.minX * CGFloat(cgImage.width),
            y: crop.minY * CGFloat(cgImage.height),
            width: crop.width * CGFloat(cgImage.width),
            height: crop.height * CGFloat(cgImage.height)
        ).integral
        guard let cropped = cgImage.cropping(to: pixelRect), cropped.width > 0, cropped.height > 0 else { return nil }
        let croppedImage = UIImage(cgImage: cropped, scale: 1, orientation: .up)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }

    func rollCallNormalizedUpImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

struct PhotoFramingEditorSheet: View {
    let image: UIImage
    let initialCrop: NormalizedPhotoCrop
    let aspectRatio: CGFloat
    let framingOptions: [PlayerPhotoFramingMode: NormalizedPhotoCrop]
    let title: String
    let onCancel: () -> Void
    let onApply: (NormalizedPhotoCrop) -> Void

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var initialized = false
    @State private var viewportSize: CGSize = .zero
    @State private var selectedCrop: NormalizedPhotoCrop
    @State private var selectedMode: PlayerPhotoFramingMode?

    init(
        image: UIImage,
        initialCrop: NormalizedPhotoCrop,
        aspectRatio: CGFloat,
        framingOptions: [PlayerPhotoFramingMode: NormalizedPhotoCrop],
        title: String,
        onCancel: @escaping () -> Void,
        onApply: @escaping (NormalizedPhotoCrop) -> Void
    ) {
        self.image = image
        self.initialCrop = initialCrop
        self.aspectRatio = aspectRatio
        self.framingOptions = framingOptions
        self.title = title
        self.onCancel = onCancel
        self.onApply = onApply
        _selectedCrop = State(initialValue: initialCrop)
        _selectedMode = State(initialValue: Self.matchingMode(for: initialCrop, options: framingOptions))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Pinch to zoom, then drag to position.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Try a framing starting point")
                        .font(.subheadline.weight(.semibold))

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(PlayerPhotoFramingMode.allCases, id: \.self) { mode in
                            Button {
                                selectFramingMode(mode)
                            } label: {
                                Text(mode.title)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .padding(.horizontal, 8)
                                    .foregroundStyle(selectedMode == mode ? .white : .primary)
                                    .background(
                                        selectedMode == mode ? Color.accentColor : Color(uiColor: .secondarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use \(mode.title) framing")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .zIndex(1)

                GeometryReader { geometry in
                    let viewport = fittedViewport(in: geometry.size)
                    ZStack {
                        Color.black
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: viewport.width, height: viewport.height)
                            .scaleEffect(zoom)
                            .offset(offset)
                            .clipped()
                            .gesture(dragGesture(viewport: viewport))
                            .simultaneousGesture(magnifyGesture(viewport: viewport))
                            .accessibilityElement()
                            .accessibilityLabel("Photo framing")
                            .accessibilityValue("Zoom \(Int(zoom * 100)) percent")
                            .accessibilityAdjustableAction { direction in
                                switch direction {
                                case .increment: setZoom(zoom + 0.2)
                                case .decrement: setZoom(zoom - 0.2)
                                @unknown default: break
                                }
                            }
                            .accessibilityAction(named: "Move photo left") { nudgePhoto(x: -24, y: 0) }
                            .accessibilityAction(named: "Move photo right") { nudgePhoto(x: 24, y: 0) }
                            .accessibilityAction(named: "Move photo up") { nudgePhoto(x: 0, y: -24) }
                            .accessibilityAction(named: "Move photo down") { nudgePhoto(x: 0, y: 24) }

                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.9), lineWidth: 2)
                            .frame(width: viewport.width, height: viewport.height)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        viewportSize = viewport
                        initializeIfNeeded(viewport: viewport)
                    }
                    .onChange(of: geometry.size) { _, _ in
                        viewportSize = viewport
                        initialized = false
                        initializeIfNeeded(viewport: viewport)
                    }
                }
                .padding(.horizontal, 16)
                .zIndex(0)

                HStack(spacing: 12) {
                    Button("Reset") {
                        resetToSelectedFraming()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        setZoom(zoom - 0.2)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Zoom out")

                    Button {
                        setZoom(zoom + 0.2)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Zoom in")
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use Framing") {
                        onApply(currentCrop(viewport: viewportSize))
                    }
                    .disabled(viewportSize.width <= 1)
                }
            }
        }
    }

    private func fittedViewport(in available: CGSize) -> CGSize {
        let maximum = CGSize(width: max(available.width, 1), height: max(available.height, 1))
        if maximum.width / maximum.height > aspectRatio {
            return CGSize(width: maximum.height * aspectRatio, height: maximum.height)
        }
        return CGSize(width: maximum.width, height: maximum.width / aspectRatio)
    }

    private func baseScale(viewport: CGSize) -> CGFloat {
        max(viewport.width / max(image.size.width, 1), viewport.height / max(image.size.height, 1))
    }

    private func initializeIfNeeded(viewport: CGSize) {
        guard !initialized, viewport.width > 1, viewport.height > 1 else { return }
        initialize(viewport: viewport, crop: selectedCrop)
    }

    private func initialize(viewport: CGSize, crop selectedCrop: NormalizedPhotoCrop) {
        guard viewport.width > 1, viewport.height > 1 else { return }
        let crop = selectedCrop.clamped().cgRect
        let base = baseScale(viewport: viewport)
        let effective = viewport.width / max(crop.width * image.size.width, 1)
        zoom = min(max(effective / base, 1), 8)
        lastZoom = zoom
        let displayedWidth = image.size.width * base * zoom
        let displayedHeight = image.size.height * base * zoom
        offset = CGSize(
            width: -(crop.minX * image.size.width * base * zoom) - (viewport.width - displayedWidth) / 2,
            height: -(crop.minY * image.size.height * base * zoom) - (viewport.height - displayedHeight) / 2
        )
        clampOffset(viewport: viewport)
        lastOffset = offset
        initialized = true
    }

    private func magnifyGesture(viewport: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(max(lastZoom * value, 1), 8)
                clampOffset(viewport: viewport)
            }
            .onEnded { _ in
                lastZoom = zoom
                clampOffset(viewport: viewport)
                lastOffset = offset
            }
    }

    private func dragGesture(viewport: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                clampOffset(viewport: viewport)
            }
            .onEnded { _ in
                clampOffset(viewport: viewport)
                lastOffset = offset
            }
    }

    private func setZoom(_ value: CGFloat) {
        zoom = min(max(value, 1), 8)
        if viewportSize.width > 1 {
            clampOffset(viewport: viewportSize)
        }
        lastZoom = zoom
        lastOffset = offset
    }

    private func nudgePhoto(x: CGFloat, y: CGFloat) {
        guard viewportSize.width > 1 else { return }
        offset.width += x
        offset.height += y
        clampOffset(viewport: viewportSize)
        lastOffset = offset
    }

    private func clampOffset(viewport: CGSize) {
        let base = baseScale(viewport: viewport)
        let scaledWidth = image.size.width * base * zoom
        let scaledHeight = image.size.height * base * zoom
        let maxX = max((scaledWidth - viewport.width) / 2, 0)
        let maxY = max((scaledHeight - viewport.height) / 2, 0)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
    }

    private func currentCrop(viewport: CGSize) -> NormalizedPhotoCrop {
        let base = baseScale(viewport: viewport)
        let effective = base * zoom
        let displayedWidth = image.size.width * effective
        let displayedHeight = image.size.height * effective
        let originX = (viewport.width - displayedWidth) / 2 + offset.width
        let originY = (viewport.height - displayedHeight) / 2 + offset.height
        return NormalizedPhotoCrop(
            x: -originX / effective / image.size.width,
            y: -originY / effective / image.size.height,
            width: viewport.width / effective / image.size.width,
            height: viewport.height / effective / image.size.height
        ).clamped()
    }

    private func selectFramingMode(_ mode: PlayerPhotoFramingMode) {
        guard let crop = framingOptions[mode] else { return }
        selectedMode = mode
        selectedCrop = crop
        resetViewport()
        if viewportSize.width > 1, viewportSize.height > 1 {
            initialize(viewport: viewportSize, crop: crop)
        }
    }

    private func resetToSelectedFraming() {
        resetViewport()
        if viewportSize.width > 1, viewportSize.height > 1 {
            initializeIfNeeded(viewport: viewportSize)
        }
    }

    private func resetViewport() {
        zoom = 1
        lastZoom = 1
        offset = .zero
        lastOffset = .zero
        initialized = false
    }

    private static func matchingMode(
        for crop: NormalizedPhotoCrop,
        options: [PlayerPhotoFramingMode: NormalizedPhotoCrop]
    ) -> PlayerPhotoFramingMode? {
        PlayerPhotoFramingMode.allCases.first { mode in
            guard let option = options[mode] else { return false }
            return cropsMatch(crop, option)
        }
    }

    private static func cropsMatch(_ lhs: NormalizedPhotoCrop, _ rhs: NormalizedPhotoCrop) -> Bool {
        let tolerance = 0.002
        return abs(lhs.x - rhs.x) <= tolerance
            && abs(lhs.y - rhs.y) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
