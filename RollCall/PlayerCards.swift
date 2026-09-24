import SwiftUI
import UIKit

struct PlayerCardContent: Equatable, Sendable {
    var playerName: String
    var playerNumber: String?
    var teamName: String?
    var songTitle: String?
    var artistName: String?
    var accentPreset: TeamAccentPreset

    init(
        playerName: String,
        playerNumber: String?,
        teamName: String?,
        songTitle: String?,
        artistName: String?,
        accentPreset: TeamAccentPreset
    ) {
        self.playerName = playerName
        self.playerNumber = playerNumber
        self.teamName = teamName
        self.songTitle = songTitle
        self.artistName = artistName
        self.accentPreset = accentPreset
    }

    init(player: Player, team: Team) {
        playerName = player.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        playerNumber = player.uniformNumber.nilIfBlank
        teamName = team.name.nilIfBlank
        accentPreset = team.accentPreset

        let source = team.songClip(for: player)?.originalSource
            ?? team.cue(for: player).map { SongSource(cueSource: $0.source) }
        switch source {
        case .appleMusic(let source):
            songTitle = source.title.nilIfBlank
            artistName = source.artistName.nilIfBlank
        case .localAudio(let source):
            let parts = source.displayName.rollCallSongParts
            songTitle = parts.title
            artistName = parts.artist
        case .builtInClip(let source):
            songTitle = source.displayName.nilIfBlank
            artistName = nil
        case nil:
            songTitle = nil
            artistName = nil
        }
    }
}

// MARK: - Production Impact and Broadcast artwork

enum PlayerCardProductionTemplate: Hashable, Sendable {
    case impact
    case broadcast
}

struct PlayerCardProductionTuning: Equatable, Sendable {
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
}

struct PlayerCardProductionModel: @unchecked Sendable {
    static let canvasSize = CGSize(width: 1_080, height: 1_350)

    let template: PlayerCardProductionTemplate
    let playerName: String
    let firstName: String?
    let lastName: String
    let playerNumber: String?
    let teamName: String?
    let songTitle: String?
    let artistName: String?
    let teamColor: PlayerCardProductionRGBColor
    let photo: UIImage?
    let crop: NormalizedPhotoCrop
    let tuning: PlayerCardProductionTuning
    let brandIcon: UIImage?

    init(
        template: PlayerCardProductionTemplate,
        content: PlayerCardContent,
        photo: UIImage?,
        crop: NormalizedPhotoCrop? = nil,
        tuning: PlayerCardProductionTuning = PlayerCardProductionTuning(),
        brandIcon: UIImage? = nil
    ) {
        let normalizedName = content.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = normalizedName.split(separator: " ").map(String.init)
        playerName = normalizedName
        firstName = parts.count > 1 ? parts.dropLast().joined(separator: " ").nilIfBlank : nil
        lastName = (parts.last ?? normalizedName).trimmingCharacters(in: .whitespacesAndNewlines)
        playerNumber = content.playerNumber?.nilIfBlank
        teamName = content.teamName?.nilIfBlank
        songTitle = content.songTitle?.nilIfBlank
        artistName = content.artistName?.nilIfBlank
        teamColor = PlayerCardProductionRGBColor.from(content.accentPreset)
        self.template = template
        self.photo = photo
        self.crop = crop ?? (photo.map {
            PlayerPhotoFramingGeometry.centeredCrop(
                aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
                imageSize: $0.size
            )
        } ?? .full)
        self.tuning = tuning
        self.brandIcon = brandIcon ?? PlayerCardProductionArtworkRenderer.bundledBrandIcon
    }
}

struct PlayerCardProductionRGBColor: Equatable, Sendable {
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
            self = PlayerCardProductionRGBColor(red: 0.98, green: 0.35, blue: 0.08)
        }
    }

    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
    var luminance: CGFloat { 0.2126 * red + 0.7152 * green + 0.0722 * blue }
    var swiftUIColor: Color { Color(uiColor: uiColor) }

    static let rollCallOrange = PlayerCardProductionRGBColor(red: 1, green: 0.35, blue: 0.08)
    static let white = PlayerCardProductionRGBColor(red: 1, green: 1, blue: 1)

    static func from(_ preset: TeamAccentPreset) -> PlayerCardProductionRGBColor {
        PlayerCardProductionRGBColor(uiColor: preset.theme.uiColor(.fill).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
    }
}

struct PlayerCardProductionCleanDerivedColors: Sendable {
    let displayAccent: PlayerCardProductionRGBColor
    let illuminationAccent: PlayerCardProductionRGBColor
    let numberAccent: PlayerCardProductionRGBColor
    let contrastAccent: PlayerCardProductionRGBColor
}

struct PlayerCardProductionBroadcastDerivedColors: Sendable {
    let displayAccent: PlayerCardProductionRGBColor
    let strongGraphicAccent: PlayerCardProductionRGBColor
    let mutedGraphicAccent: PlayerCardProductionRGBColor
    let illuminationAccent: PlayerCardProductionRGBColor
    let contrastAccent: PlayerCardProductionRGBColor
}

private enum PlayerCardProductionColorMath {
    static func hsv(_ color: PlayerCardProductionRGBColor) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
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

    static func color(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> PlayerCardProductionRGBColor {
        PlayerCardProductionRGBColor(uiColor: UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1))
    }

    static func clamp(_ value: CGFloat, _ lower: CGFloat = 0, _ upper: CGFloat = 1) -> CGFloat {
        min(max(value, lower), upper)
    }

    static func readableAccent(from raw: PlayerCardProductionRGBColor) -> PlayerCardProductionRGBColor {
        let hsb = hsv(raw)
        let saturation = hsb.saturation < 0.08 ? 0.18 : clamp(max(hsb.saturation, 0.42), 0.42, 0.92)
        let brightness = raw.luminance > 0.82 ? 0.70 : max(hsb.brightness, 0.62)
        return color(hue: hsb.hue, saturation: saturation, brightness: clamp(brightness, 0.55, 0.88))
    }

    static func light(from raw: PlayerCardProductionRGBColor, saturation: CGFloat, brightness: CGFloat) -> PlayerCardProductionRGBColor {
        let hsb = hsv(raw)
        return color(hue: hsb.hue, saturation: clamp(saturation), brightness: clamp(brightness))
    }

    static func mix(_ lhs: PlayerCardProductionRGBColor, _ rhs: PlayerCardProductionRGBColor, amount: CGFloat) -> PlayerCardProductionRGBColor {
        let t = clamp(amount)
        return PlayerCardProductionRGBColor(
            red: lhs.red + (rhs.red - lhs.red) * t,
            green: lhs.green + (rhs.green - lhs.green) * t,
            blue: lhs.blue + (rhs.blue - lhs.blue) * t
        )
    }
}


enum PlayerCardProductionCleanColorResolver {
    static func resolve(_ raw: PlayerCardProductionRGBColor) -> PlayerCardProductionCleanDerivedColors {
        let display = PlayerCardProductionColorMath.readableAccent(from: raw)
        let illumination = PlayerCardProductionColorMath.light(from: raw, saturation: max(PlayerCardProductionColorMath.hsv(raw).saturation * 0.72, 0.20), brightness: 0.78)
        let number = PlayerCardProductionColorMath.mix(display, .white, amount: 0.10)
        let contrast = display.luminance > 0.58 ? PlayerCardProductionRGBColor(red: 0.04, green: 0.05, blue: 0.07) : .white
        return PlayerCardProductionCleanDerivedColors(displayAccent: display, illuminationAccent: illumination, numberAccent: number, contrastAccent: contrast)
    }
}

enum PlayerCardProductionBroadcastColorResolver {
    static func resolve(_ raw: PlayerCardProductionRGBColor) -> PlayerCardProductionBroadcastDerivedColors {
        let display = PlayerCardProductionColorMath.readableAccent(from: raw)
        let hsb = PlayerCardProductionColorMath.hsv(raw)
        let strong = PlayerCardProductionColorMath.light(from: raw, saturation: max(hsb.saturation, 0.48), brightness: max(hsb.brightness, 0.64))
        let muted = PlayerCardProductionColorMath.light(from: raw, saturation: min(max(hsb.saturation * 0.55, 0.18), 0.60), brightness: min(max(hsb.brightness * 0.52, 0.18), 0.42))
        let illumination = PlayerCardProductionColorMath.light(from: raw, saturation: min(max(hsb.saturation * 0.68, 0.18), 0.75), brightness: 0.70)
        let contrast = raw.luminance > 0.58 ? PlayerCardProductionRGBColor(red: 0.04, green: 0.05, blue: 0.07) : PlayerCardProductionRGBColor(red: 0.96, green: 0.97, blue: 1)
        return PlayerCardProductionBroadcastDerivedColors(displayAccent: display, strongGraphicAccent: strong, mutedGraphicAccent: muted, illuminationAccent: illumination, contrastAccent: contrast)
    }
}

struct PlayerCardProductionPhotoTransform: @unchecked Sendable {
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


enum PlayerCardProductionArtworkRenderer {
    static let outputSize = CGSize(width: 1_200, height: 1_500)
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    static func stableSeed(_ value: String) -> Int {
        value.utf8.reduce(17) { ($0 &* 31) &+ Int($1) } & 0x7FFF
    }

    static let bundledBrandIcon: UIImage? = {
        guard let image = UIImage(named: "AppIcon-iOS-Default-1024@1x"), image.size.width > 0, image.size.height > 0 else { return nil }
        return image
    }()

    static func render(_ model: PlayerCardProductionModel) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.saveGState()
            context.scaleBy(
                x: outputSize.width / PlayerCardProductionModel.canvasSize.width,
                y: outputSize.height / PlayerCardProductionModel.canvasSize.height
            )
            context.setFillColor(UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: 1).cgColor)
            context.fill(CGRect(origin: .zero, size: PlayerCardProductionModel.canvasSize))
            switch model.template {
            case .impact:
                PlayerCardProductionImpactRenderer.draw(model, in: context)
            case .broadcast:
                PlayerCardProductionBroadcastRenderer.draw(model, in: context)
            }
            context.restoreGState()
        }
    }

    static func drawBackground(in context: CGContext, accent: PlayerCardProductionRGBColor, atmosphere: CGFloat = 0.08) {
        let colors = [
            UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: 1).cgColor,
            accent.uiColor.withAlphaComponent(atmosphere).cgColor,
            UIColor(red: 0.015, green: 0.019, blue: 0.03, alpha: 1).cgColor
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: sRGB, colors: colors, locations: [0, 0.52, 1]) else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: 80, y: 40), end: CGPoint(x: 1_000, y: 1_350), options: [])
    }

    static func drawPhoto(_ image: UIImage?, crop: NormalizedPhotoCrop, in rect: CGRect, context: CGContext, cornerRadius: CGFloat, edgeLight: PlayerCardProductionRGBColor? = nil, edgeLightStrength: CGFloat = 0, clipRect: CGRect? = nil, revealRect: CGRect? = nil) {
        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
        if let revealRect {
            let hole = revealRect.intersection(rect)
            if !hole.isNull, !hole.isEmpty {
                let path = CGMutablePath()
                path.addRect(rect)
                path.addRect(hole)
                context.addPath(path)
                context.clip(using: .evenOdd)
            }
        }
        if let clipRect {
            context.clip(to: clipRect)
        }
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
    static func drawAsymmetricEdgeLight(in rect: CGRect, accent: PlayerCardProductionRGBColor, strength: CGFloat, context: CGContext, cornerRadius: CGFloat) {
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
        let transform = PlayerCardProductionPhotoTransform(sourceSize: CGSize(width: image.width, height: image.height), crop: crop, destinationFrame: rect)
        context.interpolationQuality = .high
        UIImage(cgImage: image, scale: 1, orientation: .up).draw(in: transform.fullImageDestination)
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
                drawBroadcastTextFromTopLeft(firstName.uppercased(), in: CGRect(x: firstRect.minX, y: firstRect.minY, width: firstWidth, height: firstRect.height), angle: angle, font: firstFit.font, color: .white.withAlphaComponent(0.92), alignment: alignment, tracking: firstFit.tracking, context: context)
                drawBroadcastTextFromTopLeft(last.uppercased(), in: CGRect(x: lastRect.minX, y: lastRect.minY, width: lastWidth, height: lastRect.height), angle: angle, font: lastFit.font, color: .white, alignment: alignment, tracking: lastFit.tracking, lineBreakMode: .byClipping, context: context)
            }
        } else {
            let lastFit = fittedBroadcastNameFont(last.uppercased(), maxSize: maxLastSize, minimumSize: 30, width: width, weight: .black, fontProvider: lastFontProvider)
            let lastRect = CGRect(x: x, y: y + 18, width: width, height: 124)
            if angle == 0 {
                drawText(last.uppercased(), in: lastRect, font: lastFit.font, color: .white, alignment: alignment, tracking: lastFit.tracking, lineBreakMode: .byClipping, context: context)
            } else {
                let lastWidth = min(width, measuredTextWidth(last.uppercased(), font: lastFit.font, tracking: lastFit.tracking))
                drawBroadcastTextFromTopLeft(last.uppercased(), in: CGRect(x: lastRect.minX, y: lastRect.minY, width: lastWidth, height: lastRect.height), angle: angle, font: lastFit.font, color: .white, alignment: alignment, tracking: lastFit.tracking, lineBreakMode: .byClipping, context: context)
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
                fontProvider: { PlayerCardProductionCleanTypography.condensed(size: $0, weight: .medium) }
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
                fontProvider: { PlayerCardProductionCleanTypography.condensed(size: $0, weight: .heavy) }
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
                fontProvider: { PlayerCardProductionCleanTypography.condensed(size: $0, weight: .heavy) }
            )
            drawText(lastText, in: CGRect(x: x, y: y + 18, width: width, height: 124), font: lastFont, color: .white, alignment: .left, tracking: lastTracking, context: context)
        }
    }

    static func drawFooter(_ model: PlayerCardProductionModel, y: CGFloat, font: UIFont = .systemFont(ofSize: 22, weight: .semibold), useBroadcastTypography: Bool = false, useCleanSpotlightTypography: Bool = false, context: CGContext) {
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


private enum PlayerCardProductionCleanTypography {
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

enum PlayerCardProductionCleanLayout {
    static let photoRect = CGRect(x: 44, y: 44, width: 992, height: 936)
    static let gradientRect = CGRect(x: 44, y: 650, width: 992, height: 330)

    static let musicIconRect = CGRect(x: 70, y: 1_014, width: 22, height: 22)
    static let musicLabelRect = CGRect(x: 100, y: 1_008, width: 470, height: 36)
    static let songRect = CGRect(x: 70, y: 1_053, width: 880, height: 58)
    static let artistRect = CGRect(x: 70, y: 1_111, width: 880, height: 48)
    static let waveformRect = CGRect(x: 70, y: 1_195, width: 560, height: 46)
    static let musicAccentRect = CGRect(x: 56, y: musicLabelRect.minY, width: 5, height: waveformRect.maxY - musicLabelRect.minY)
    static let footerY: CGFloat = 1_274
}

private enum PlayerCardProductionImpactRenderer {
    static func draw(_ model: PlayerCardProductionModel, in context: CGContext) {
        let colors = PlayerCardProductionCleanColorResolver.resolve(model.teamColor)
        PlayerCardProductionArtworkRenderer.drawBackground(in: context, accent: colors.illuminationAccent, atmosphere: 0.065)
        let photoRect = PlayerCardProductionCleanLayout.photoRect
        PlayerCardProductionArtworkRenderer.drawPhoto(model.photo, crop: model.crop, in: photoRect, context: context, cornerRadius: 0)
        PlayerCardProductionArtworkRenderer.drawAsymmetricEdgeLight(in: photoRect, accent: colors.illuminationAccent, strength: model.tuning.cleanEdgeLight, context: context, cornerRadius: 0)

        if let teamName = model.teamName {
            PlayerCardProductionArtworkRenderer.drawText(teamName.uppercased(), in: CGRect(x: 70, y: 82, width: 690, height: 40), font: PlayerCardProductionCleanTypography.condensed(size: 25, weight: .semibold), color: .white.withAlphaComponent(0.92), alignment: .left, tracking: 2.2, context: context)
        }
        if let number = model.playerNumber {
            let numberBadgeRect = CGRect(x: 904, y: 74, width: 120, height: 76)
            context.setFillColor(colors.displayAccent.uiColor.cgColor)
            context.fill(numberBadgeRect)
            let numberFont = PlayerCardProductionArtworkRenderer.fittedFont(number, maxSize: 60, minimumSize: 30, width: 120, fontProvider: { PlayerCardProductionCleanTypography.condensed(size: $0, weight: .black) })
            PlayerCardProductionArtworkRenderer.drawText(number, in: numberBadgeRect.insetBy(dx: 8, dy: 0), font: numberFont, color: colors.contrastAccent.uiColor, alignment: .center, context: context)
        }

        let gradientRect = PlayerCardProductionCleanLayout.gradientRect
        let gradient = CGGradient(colorsSpace: PlayerCardProductionArtworkRenderer.sRGB, colors: [UIColor.clear.cgColor, UIColor(red: 0.025, green: 0.032, blue: 0.05, alpha: model.tuning.cleanGradientStrength).cgColor] as CFArray, locations: [model.tuning.cleanGradientStart, 1])
        if let gradient { context.drawLinearGradient(gradient, start: CGPoint(x: gradientRect.midX, y: gradientRect.minY), end: CGPoint(x: gradientRect.midX, y: gradientRect.maxY), options: []) }
        context.saveGState()
        context.setStrokeColor(colors.displayAccent.uiColor.cgColor)
        context.setLineWidth(3)
        context.stroke(photoRect.insetBy(dx: 1.5, dy: 1.5))
        context.restoreGState()

        PlayerCardProductionArtworkRenderer.drawCleanName(first: model.firstName, last: model.lastName, x: 70, y: model.tuning.cleanNameY, width: 860, context: context)
        if model.songTitle != nil || model.artistName != nil {
            context.setFillColor(colors.displayAccent.uiColor.cgColor)
            context.fill(PlayerCardProductionCleanLayout.musicAccentRect)
            if let icon = UIImage(systemName: "music.note")?.withTintColor(colors.displayAccent.uiColor, renderingMode: .alwaysOriginal) {
                icon.draw(in: PlayerCardProductionCleanLayout.musicIconRect)
            }
            PlayerCardProductionArtworkRenderer.drawText("WALK-UP MUSIC", in: PlayerCardProductionCleanLayout.musicLabelRect, font: PlayerCardProductionCleanTypography.condensed(size: 22, weight: .semibold), color: colors.displayAccent.uiColor, alignment: .left, tracking: 1.8, context: context)
            if let song = model.songTitle {
                let songFont = PlayerCardProductionArtworkRenderer.fittedFont(song, maxSize: 44, minimumSize: 26, width: 880, fontProvider: { PlayerCardProductionCleanTypography.display(size: $0, weight: .semibold) })
                PlayerCardProductionArtworkRenderer.drawText(song, in: PlayerCardProductionCleanLayout.songRect, font: songFont, color: .white, alignment: .left, lineBreakMode: .byTruncatingTail, context: context)
            }
            if let artist = model.artistName {
                let artistFont = PlayerCardProductionArtworkRenderer.fittedFont(artist, maxSize: 27, minimumSize: 20, width: 880, fontProvider: { PlayerCardProductionCleanTypography.text(size: $0, weight: .regular) })
                PlayerCardProductionArtworkRenderer.drawText(artist, in: PlayerCardProductionCleanLayout.artistRect, font: artistFont, color: .white.withAlphaComponent(0.62), alignment: .left, lineBreakMode: .byTruncatingTail, context: context)
            }
            PlayerCardProductionArtworkRenderer.drawWaveform(in: PlayerCardProductionCleanLayout.waveformRect, color: colors.displayAccent.uiColor, seed: PlayerCardProductionArtworkRenderer.stableSeed(model.playerName), context: context)
        }
        PlayerCardProductionArtworkRenderer.drawFooter(model, y: PlayerCardProductionCleanLayout.footerY, font: PlayerCardProductionCleanTypography.text(size: 22, weight: .medium), useCleanSpotlightTypography: true, context: context)
    }
}

private enum PlayerCardProductionBroadcastRenderer {
    static func draw(_ model: PlayerCardProductionModel, in context: CGContext) {
        let colors = PlayerCardProductionBroadcastColorResolver.resolve(model.teamColor)
        PlayerCardProductionArtworkRenderer.drawBackground(in: context, accent: colors.illuminationAccent, atmosphere: 0.045)
        let photoRect = CGRect(x: 42, y: 42, width: 996, height: model.tuning.broadcastPhotoHeight)
        PlayerCardProductionArtworkRenderer.drawPhoto(model.photo, crop: model.crop, in: photoRect, context: context, cornerRadius: 18, edgeLight: colors.illuminationAccent, edgeLightStrength: 0.17)
        let broadcastAngle = model.tuning.broadcastAngle

        if let teamName = model.teamName {
            let teamText = teamName.uppercased()
            let teamFit = PlayerCardProductionArtworkRenderer.fittedBroadcastNameFont(
                teamText,
                maxSize: 29,
                minimumSize: 22,
                width: 900,
                weight: .semibold,
                preferredTracking: 2,
                fontProvider: { BroadcastCardTypography.team(size: $0) }
            )
            let teamWidth = min(900, PlayerCardProductionArtworkRenderer.measuredTextWidth(teamText, font: teamFit.font, tracking: teamFit.tracking))
            let teamX: CGFloat = 70
            PlayerCardProductionArtworkRenderer.drawBroadcastText(teamText, in: CGRect(x: teamX, y: 76, width: max(1, teamWidth), height: 44), angle: broadcastAngle, font: teamFit.font, color: .white.withAlphaComponent(0.92), alignment: .left, tracking: teamFit.tracking, context: context)
            PlayerCardProductionArtworkRenderer.drawBroadcastLine(from: CGPoint(x: teamX, y: 140), length: max(1, teamWidth), angle: broadcastAngle, color: colors.strongGraphicAccent.uiColor, width: 5, context: context)
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
            colorsSpace: PlayerCardProductionArtworkRenderer.sRGB,
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
        PlayerCardProductionArtworkRenderer.drawGiantNumber(model.playerNumber, in: CGRect(x: 660, y: model.tuning.broadcastGiantNumberY, width: 440, height: 420), color: colors.strongGraphicAccent.uiColor, opacity: model.tuning.broadcastNumberOpacity, angle: broadcastAngle, font: BroadcastCardTypography.decorativeJerseyNumber(size: 420 * 0.82), context: context)

        PlayerCardProductionArtworkRenderer.drawName(
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
        PlayerCardProductionArtworkRenderer.drawBroadcastLine(from: CGPoint(x: 70, y: model.tuning.broadcastNameY + 190), length: 440, angle: broadcastAngle, color: colors.strongGraphicAccent.uiColor.withAlphaComponent(0.78), width: 3, context: context)
        if model.songTitle != nil || model.artistName != nil {
            // Music is a continuation of the Broadcast field with a thin angled
            // termination below it.
            let musicY = model.tuning.broadcastMusicY
            let musicFont = BroadcastCardTypography.sectionLabel(size: 21)
            let musicLabel = "♪  WALK-UP MUSIC"
            let musicWidth = PlayerCardProductionArtworkRenderer.measuredTextWidth(musicLabel, font: musicFont, tracking: 1.7)
            PlayerCardProductionArtworkRenderer.drawBroadcastText(musicLabel, in: CGRect(x: 96, y: musicY - 24, width: max(1, musicWidth), height: 34), angle: broadcastAngle, font: musicFont, color: colors.displayAccent.uiColor, alignment: .left, tracking: 1.7, context: context)
            var artistY: CGFloat = musicY + 76
            if let song = model.songTitle {
                let songWidth: CGFloat = 700
                let songFont = PlayerCardProductionArtworkRenderer.fittedWrappedFont(song, maxSize: 42, minimumSize: 28, width: songWidth, maxLines: 2, weight: .semibold, fontProvider: { BroadcastCardTypography.songTitle(size: $0) })
                let songLines = PlayerCardProductionArtworkRenderer.wrappedLineCount(song, font: songFont, width: songWidth, maxLines: 2)
                PlayerCardProductionArtworkRenderer.drawBroadcastTextFromTopLeft(song, in: CGRect(x: 70, y: musicY + 20, width: songWidth, height: 96), angle: broadcastAngle, font: songFont, color: .white, alignment: .left, lineBreakMode: .byWordWrapping, context: context)
                artistY = songLines > 1 ? musicY + 120 : musicY + 76
            }
            if let artist = model.artistName {
                let artistWidth: CGFloat = 700
                let artistFont = PlayerCardProductionArtworkRenderer.fittedWrappedFont(artist, maxSize: 25, minimumSize: 18, width: artistWidth, maxLines: 2, weight: .regular, fontProvider: { BroadcastCardTypography.artist(size: $0) })
                PlayerCardProductionArtworkRenderer.drawBroadcastTextFromTopLeft(artist, in: CGRect(x: 70, y: artistY, width: artistWidth, height: 54), angle: broadcastAngle, font: artistFont, color: .white.withAlphaComponent(0.60), alignment: .left, lineBreakMode: .byTruncatingTail, context: context)
            }
            PlayerCardProductionArtworkRenderer.drawWaveform(in: CGRect(x: 650, y: musicY + 30, width: 360, height: 93), color: colors.displayAccent.uiColor, seed: PlayerCardProductionArtworkRenderer.stableSeed(model.playerName), angle: broadcastAngle, context: context)
            PlayerCardProductionArtworkRenderer.drawBroadcastLine(from: CGPoint(x: 70, y: 1_220), length: 940, angle: broadcastAngle, color: colors.strongGraphicAccent.uiColor.withAlphaComponent(0.50), width: 2, context: context)
        }
        PlayerCardProductionArtworkRenderer.drawFooter(model, y: 1_274, useBroadcastTypography: true, context: context)
    }
}



struct PlayerCardRenderer {
    /// The display name of the production/default card design. This is a label only; the
    /// renderer implementation and all persisted player-photo settings remain unchanged.
    static let designName = "Spotlight"
    static let outputSize = CGSize(width: 1_200, height: 1_500)

    func render(
        content: PlayerCardContent,
        photo: UIImage?,
        crop: NormalizedPhotoCrop?,
        brandIcon: UIImage? = nil,
        design: PlayerCardDesign = .defaultDesign
    ) -> UIImage {
        guard design == .spotlight else {
            let model = PlayerCardProductionModel(
                template: design == .impact ? .impact : .broadcast,
                content: content,
                photo: photo,
                crop: crop,
                brandIcon: brandIcon
            )
            return PlayerCardProductionArtworkRenderer.render(model)
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: Self.outputSize, format: format).image { context in
            let canvas = CGRect(origin: .zero, size: Self.outputSize)
            drawSpotlight(content: content, photo: photo, crop: crop, brandIcon: brandIcon, canvas: canvas, context: context.cgContext)
        }
    }

    private func drawSpotlight(content: PlayerCardContent, photo: UIImage?, crop: NormalizedPhotoCrop?, brandIcon: UIImage?, canvas: CGRect, context: CGContext) {
        let accent = content.accentPreset.theme.uiColor(.fill).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        UIColor(red: 0.035, green: 0.043, blue: 0.06, alpha: 1).setFill()
        context.fill(canvas)
        accent.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 32))
        let photoRect = CGRect(origin: CGPoint(x: 54, y: 82), size: PlayerPhotoFramingGeometry.playerCardPhotoViewportSize)
        context.saveGState()
        UIBezierPath(roundedRect: photoRect, cornerRadius: 34).addClip()
        drawPhoto(photo, crop: crop, in: photoRect, accent: accent, context: context)
        context.restoreGState()
        drawGradient(from: .clear, to: UIColor.black.withAlphaComponent(0.94), in: CGRect(x: 54, y: 590, width: 1_092, height: 392), context: context)

        if let teamName = content.teamName {
            let teamText = teamName.uppercased()
            let teamFit = fittedBroadcastFont(text: teamText, maxSize: 32, minimumSize: 24, width: 940, preferredTracking: 2, fontProvider: { BroadcastCardTypography.team(size: $0) })
            let teamWidth = min(940, NSAttributedString(string: teamText, attributes: [.font: teamFit.font, .kern: teamFit.tracking]).size().width)
            let teamX: CGFloat = 100
            drawText(teamText, in: CGRect(x: teamX, y: 104, width: max(1, teamWidth), height: 50), font: teamFit.font, color: .white.withAlphaComponent(0.92), alignment: .left, tracking: teamFit.tracking)
            context.setStrokeColor(accent.cgColor)
            context.setLineWidth(4)
            context.move(to: CGPoint(x: teamX, y: 168))
            context.addLine(to: CGPoint(x: teamX + max(1, teamWidth), y: 168))
            context.strokePath()
        }
        drawPlayerName(content.playerName, in: CGRect(x: 90, y: 755, width: 980, height: 202))

        let songPanel = CGRect(x: 54, y: 975, width: 1_092, height: content.songTitle == nil ? 208 : 310)
        UIColor(red: 0.095, green: 0.105, blue: 0.13, alpha: 1).setFill()
        UIBezierPath(roundedRect: songPanel, cornerRadius: 34).fill()
        accent.setFill()
        UIBezierPath(roundedRect: CGRect(x: 54, y: 975, width: 18, height: songPanel.height), byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 34, height: 34)).fill()
        drawText(content.songTitle == nil ? "READY FOR GAME DAY" : "WALK-UP MUSIC", in: CGRect(x: 100, y: 1_019, width: 900, height: 38), font: BroadcastCardTypography.sectionLabel(size: 25), color: accent, alignment: .left, tracking: 2.5)
        if let song = content.songTitle {
            let songFont = fittedFont(text: song, maxSize: 52, minimumSize: 26, width: 948, fontProvider: { BroadcastCardTypography.songTitle(size: $0) })
            drawText(song, in: CGRect(x: 98, y: 1_071, width: 948, height: 92), font: songFont, color: .white, alignment: .left)
            if let artist = content.artistName {
                drawText(artist, in: CGRect(x: 100, y: 1_173, width: 900, height: 48), font: BroadcastCardTypography.artist(size: 31), color: .white.withAlphaComponent(0.7), alignment: .left)
            }
        }
        drawAttribution(in: CGRect(x: 54, y: 1_382, width: 1_092, height: 66), color: .white.withAlphaComponent(0.7), icon: brandIcon, context: context)
    }


    private func drawPhoto(_ image: UIImage?, crop: NormalizedPhotoCrop?, in rect: CGRect, accent: UIColor, context: CGContext) {
        guard let image,
              let prepared = image.cropped(to: crop ?? .full, outputSize: rect.size) else {
            accent.setFill()
            context.fill(rect)
            let symbol = UIImage(systemName: "person.crop.rectangle.fill")?.withTintColor(readableForeground(over: accent).withAlphaComponent(0.35), renderingMode: .alwaysOriginal)
            symbol?.draw(in: rect.insetBy(dx: rect.width * 0.32, dy: rect.height * 0.32))
            return
        }
        prepared.draw(in: rect)
    }

    private func drawGradient(from start: UIColor, to end: UIColor, in rect: CGRect, context: CGContext) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [start.cgColor, end.cgColor] as CFArray, locations: [0, 1]) else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
    }

    /// The bundled brand mark used by the card attribution.
    ///
    /// Deliberately **not** `UIImage(named: "AppIcon")`. The app icon lives in an
    /// asset catalog / Icon Composer bundle that exposes no decodable image to
    /// `UIImage`, and its initializer raises `NSInternalInconsistencyException`
    /// ("Need an imageRef") from `_UIImageCGImageContent` rather than returning
    /// nil — an Objective-C exception Swift cannot catch, which terminated the
    /// process while rendering any Player Card. Use the loose card-safe copy of
    /// the app icon here instead of asking UIKit to decode the AppIcon catalog.
    private static let bundledBrandIcon: UIImage? = drawableIcon(
        UIImage(named: "AppIcon-iOS-Default-1024@1x")
    )

    private static func drawableIcon(_ image: UIImage?) -> UIImage? {
        guard let image, image.size.width > 0, image.size.height > 0 else { return nil }
        return image
    }

    private func drawAttribution(in rect: CGRect, color: UIColor, icon: UIImage?, context: CGContext) {
        let iconRect = CGRect(x: rect.minX, y: rect.midY - 23, width: 46, height: 46)
        let resolvedIcon = Self.drawableIcon(icon) ?? Self.bundledBrandIcon
        let textInset: CGFloat = resolvedIcon == nil ? 0 : 62
        if let resolvedIcon {
            UIGraphicsGetCurrentContext()?.saveGState()
            let path = UIBezierPath(roundedRect: iconRect, cornerRadius: 10)
            path.addClip()
            resolvedIcon.draw(in: iconRect)
            UIGraphicsGetCurrentContext()?.restoreGState()
        }
        BroadcastCardTypography.drawFooterText(in: CGRect(x: rect.minX + textInset, y: rect.minY, width: rect.width - textInset, height: rect.height), color: color, size: 25, context: context)
    }

    private func drawPlayerName(_ displayName: String, in rect: CGRect) {
        let parts = BroadcastCardTypography.nameParts(displayName)
        let first = parts.first.uppercased()
        let last = parts.last.uppercased()
        let firstFit = fittedBroadcastFont(text: first, maxSize: 49, minimumSize: 30, width: rect.width, preferredTracking: 1.8, fontProvider: { BroadcastCardTypography.playerFirstName(size: $0) })
        let lastFit = fittedBroadcastFont(text: last, maxSize: 108, minimumSize: 40, width: rect.width, preferredTracking: 0, fontProvider: { BroadcastCardTypography.playerLastName(size: $0) })

        if !first.isEmpty {
            drawText(first, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 56), font: firstFit.font, color: .white.withAlphaComponent(0.92), alignment: .left, tracking: firstFit.tracking)
            drawText(last, in: CGRect(x: rect.minX, y: rect.minY + 50, width: rect.width, height: rect.height - 50), font: lastFit.font, color: .white, alignment: .left, tracking: lastFit.tracking, lineBreakMode: .byClipping)
        } else {
            drawText(last, in: rect, font: lastFit.font, color: .white, alignment: .left, tracking: lastFit.tracking, lineBreakMode: .byClipping)
        }
    }

    private func fittedBroadcastFont(text: String, maxSize: CGFloat, minimumSize: CGFloat, width: CGFloat, preferredTracking: CGFloat, fontProvider: (CGFloat) -> UIFont) -> (font: UIFont, tracking: CGFloat) {
        for tracking in [preferredTracking, preferredTracking - 0.5, 0, -0.5] {
            var size = maxSize
            while size >= minimumSize {
                let font = fontProvider(size)
                let measured = NSAttributedString(string: text, attributes: [.font: font, .kern: tracking]).size().width
                if measured <= width { return (font, tracking) }
                size -= 1
            }
        }
        return (fontProvider(minimumSize), -0.8)
    }

    private func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment, tracking: CGFloat = 0, lineBreakMode: NSLineBreakMode = .byTruncatingTail) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreakMode
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .kern: tracking
        ]
        NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private func fittedFont(text: String, maxSize: CGFloat, weight: UIFont.Weight, width: CGFloat) -> UIFont {
        var size = maxSize
        while size > 24 {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            if NSString(string: text).size(withAttributes: [.font: font]).width <= width { return font }
            size -= 2
        }
        return .systemFont(ofSize: size, weight: weight)
    }

    private func fittedFont(text: String, maxSize: CGFloat, minimumSize: CGFloat, width: CGFloat, fontProvider: (CGFloat) -> UIFont) -> UIFont {
        var size = maxSize
        while size > minimumSize {
            let font = fontProvider(size)
            if NSString(string: text).size(withAttributes: [.font: font]).width <= width { return font }
            size -= 1
        }
        return fontProvider(minimumSize)
    }

    private func readableForeground(over color: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.58 ? .black : .white
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var rollCallSongParts: (title: String?, artist: String?) {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        for separator in [" — ", " – ", " - "] {
            let pieces = value.components(separatedBy: separator)
            if pieces.count >= 2 {
                return (pieces.dropFirst().joined(separator: separator).nilIfBlank, pieces.first?.nilIfBlank)
            }
        }
        return (value.nilIfBlank, nil)
    }
}

struct PlayerCardImageView: View {
    let image: UIImage
    let playerName: String
    let design: PlayerCardDesign

    init(image: UIImage, playerName: String, design: PlayerCardDesign = .defaultDesign) {
        self.image = image
        self.playerName = playerName
        self.design = design
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
            .accessibilityLabel("\(design.title) Player Card preview for \(playerName)")
    }
}

struct PlayerCardPreviewRenderIdentity: Equatable, Sendable {
    let content: PlayerCardContent
    let photoRelativePath: String?
    let photoSourceRelativePath: String?
    let playerCardPhotoCrop: NormalizedPhotoCrop?
}

struct PlayerCardPreviewRenderRequest: Equatable, Identifiable, Sendable {
    let id: UUID
    let identity: PlayerCardPreviewRenderIdentity

    init(identity: PlayerCardPreviewRenderIdentity) {
        id = UUID()
        self.identity = identity
    }
}

struct PlayerCardPreviewRenderResult: @unchecked Sendable {
    let request: PlayerCardPreviewRenderRequest
    let cards: [PlayerCardDesign: UIImage]
    let framingImage: UIImage?
    let framingOptions: PlayerPhotoFramingOptionSet?
    let usesWorkingMaster: Bool
    let errorMessage: String?
}

struct PlayerCardPreviewRenderGate {
    private(set) var activeRequest: PlayerCardPreviewRenderRequest?
    private(set) var publishedResult: PlayerCardPreviewRenderResult?

    mutating func begin(identity: PlayerCardPreviewRenderIdentity) -> PlayerCardPreviewRenderRequest {
        let request = PlayerCardPreviewRenderRequest(identity: identity)
        activeRequest = request
        publishedResult = nil
        return request
    }

    mutating func invalidate() {
        activeRequest = nil
        publishedResult = nil
    }

    func accepts(
        _ request: PlayerCardPreviewRenderRequest,
        currentIdentity: PlayerCardPreviewRenderIdentity
    ) -> Bool {
        activeRequest == request && request.identity == currentIdentity
    }

    @discardableResult
    mutating func publish(
        _ result: PlayerCardPreviewRenderResult,
        currentIdentity: PlayerCardPreviewRenderIdentity
    ) -> Bool {
        guard accepts(result.request, currentIdentity: currentIdentity) else { return false }
        publishedResult = result
        return true
    }

    func currentResult(for identity: PlayerCardPreviewRenderIdentity) -> PlayerCardPreviewRenderResult? {
        guard let activeRequest,
              activeRequest.identity == identity,
              let publishedResult else { return nil }
        return currentResult(for: activeRequest, currentIdentity: identity)
    }

    func currentResult(
        for request: PlayerCardPreviewRenderRequest,
        currentIdentity: PlayerCardPreviewRenderIdentity
    ) -> PlayerCardPreviewRenderResult? {
        guard accepts(request, currentIdentity: currentIdentity),
              let publishedResult,
              publishedResult.request == request else { return nil }
        return publishedResult
    }

    func shareableImage(
        for design: PlayerCardDesign,
        currentIdentity: PlayerCardPreviewRenderIdentity
    ) -> UIImage? {
        currentResult(for: currentIdentity)?.cards[design]
    }
}

struct PlayerCardShareCompletionGate {
    private(set) var didRecordSuccess = false

    mutating func claimSuccessfulCompletion(completed: Bool, hasError: Bool) -> Bool {
        guard completed, !hasError, !didRecordSuccess else { return false }
        didRecordSuccess = true
        return true
    }
}

private struct PlayerCardShareArtifact {
    let image: UIImage
    let design: PlayerCardDesign
}

struct PlayerCardPreviewSheet: View {
    private struct RenderOutput: @unchecked Sendable {
        let cards: [PlayerCardDesign: UIImage]
        let framingImage: UIImage?
        let usesWorkingMaster: Bool
    }

    @Environment(\.dismiss) private var dismiss
    @Binding var player: Player
    let team: Team
    let initialDesign: PlayerCardDesign
    let onDesignChanged: (PlayerCardDesign) -> Void
    let onGenerated: () -> Void
    let onGenerationFailed: (String) -> Void
    let onSharePresented: () -> Void
    let onShareCompleted: (PlayerCardDesign) -> Void
    let onCardFramingAdjusted: () -> Void

    @State private var renderGate = PlayerCardPreviewRenderGate()
    @State private var renderTaskID = UUID()
    @State private var shareArtifact: PlayerCardShareArtifact?
    @State private var framingRequest: PlayerCardPreviewRenderRequest?
    @State private var selectedDesignID: String

    init(
        player: Binding<Player>,
        team: Team,
        initialDesign: PlayerCardDesign = .defaultDesign,
        onDesignChanged: @escaping (PlayerCardDesign) -> Void = { _ in },
        onGenerated: @escaping () -> Void,
        onGenerationFailed: @escaping (String) -> Void,
        onSharePresented: @escaping () -> Void,
        onShareCompleted: @escaping (PlayerCardDesign) -> Void,
        onCardFramingAdjusted: @escaping () -> Void
    ) {
        self._player = player
        self.team = team
        self.initialDesign = initialDesign
        self.onDesignChanged = onDesignChanged
        self.onGenerated = onGenerated
        self.onGenerationFailed = onGenerationFailed
        self.onSharePresented = onSharePresented
        self.onShareCompleted = onShareCompleted
        self.onCardFramingAdjusted = onCardFramingAdjusted
        self._selectedDesignID = State(initialValue: initialDesign.rawValue)
    }

    private var selectedDesign: PlayerCardDesign {
        PlayerCardDesign(rawValue: selectedDesignID) ?? .defaultDesign
    }

    private var renderIdentity: PlayerCardPreviewRenderIdentity {
        PlayerCardPreviewRenderIdentity(
            content: PlayerCardContent(player: player, team: team),
            photoRelativePath: player.photoRelativePath,
            photoSourceRelativePath: player.photoSourceRelativePath,
            playerCardPhotoCrop: player.playerCardPhotoCrop
        )
    }

    private var currentRenderResult: PlayerCardPreviewRenderResult? {
        renderGate.currentResult(for: renderIdentity)
    }

    private var designSelection: Binding<PlayerCardDesign> {
        Binding(
            get: { selectedDesign },
            set: { design in selectDesign(design, animated: true) }
        )
    }

    private var carouselSelection: Binding<String?> {
        Binding(
            get: { selectedDesignID },
            set: { id in
                guard let id,
                      let design = PlayerCardDesign(rawValue: id),
                      PlayerCardDesign.shippingDesigns.contains(design) else { return }
                selectedDesignID = design.rawValue
            }
        )
    }

    var body: some View {
        let result = currentRenderResult

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Player Card design", selection: designSelection) {
                        ForEach(PlayerCardDesign.shippingDesigns) { design in
                            Text(design.title).tag(design)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(team.accentPreset.color())
                    .accessibilityIdentifier("player-card-design-selector")
                    .padding(.horizontal, 20)

                    PlayerCardCarousel(
                        playerName: player.displayName,
                        renderedImages: result?.cards ?? [:],
                        renderError: result?.errorMessage,
                        selectedDesign: selectedDesign,
                        selection: carouselSelection,
                        onSelect: { design in selectDesign(design, animated: true) }
                    )

                    Button(action: presentShare) {
                        Label("Share or Save This Card", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.primary)
                    .disabled(result?.cards[selectedDesign] == nil)
                    .accessibilityHint("Shares or saves the currently selected Player Card design.")

                    if let result, result.framingImage != nil, result.framingOptions != nil {
                        Button {
                            framingRequest = result.request
                        } label: {
                            Label("Adjust Player Card Photo", systemImage: "crop")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Changes only the framing used in the shared Player Card.")
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("\(selectedDesign.title) Player Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: presentShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(result?.cards[selectedDesign] == nil)
                }
            }
            .onChange(of: selectedDesignID) { _, newValue in
                guard let design = PlayerCardDesign(rawValue: newValue),
                      PlayerCardDesign.shippingDesigns.contains(design) else { return }
                onDesignChanged(design)
            }
            .task(id: renderTaskID) {
                let identity = renderIdentity
                let request = renderGate.begin(identity: identity)
                await render(request)
            }
            .onChange(of: renderIdentity) { _, _ in
                renderGate.invalidate()
                framingRequest = nil
                renderTaskID = UUID()
            }
            .sheet(isPresented: Binding(
                get: { shareArtifact != nil },
                set: { if !$0 { shareArtifact = nil } }
            )) {
                if let shareArtifact {
                    PlayerCardActivityShareSheet(items: [shareArtifact.image]) {
                        onShareCompleted(shareArtifact.design)
                    }
                        .onAppear(perform: onSharePresented)
                }
            }
            .fullScreenCover(item: $framingRequest) { request in
                if let result = renderGate.currentResult(for: request, currentIdentity: renderIdentity),
                   let framingImage = result.framingImage,
                   let framingOptions = result.framingOptions {
                    PhotoFramingEditorSheet(
                        image: framingImage,
                        initialCrop: effectiveCardCrop(
                            for: framingImage,
                            usesWorkingMaster: result.usesWorkingMaster
                        ),
                        aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
                        framingOptions: framingOptions.card,
                        title: "Adjust Player Card Photo",
                        onCancel: { framingRequest = nil },
                        onApply: { crop in
                            guard renderGate.currentResult(
                                for: request,
                                currentIdentity: renderIdentity
                            )?.request == result.request else {
                                framingRequest = nil
                                return
                            }
                            if player.photoSourceRelativePath != nil, !result.usesWorkingMaster {
                                player.photoSourceRelativePath = nil
                                player.profilePhotoCrop = nil
                            }
                            player.playerCardPhotoCrop = crop
                            framingRequest = nil
                            onCardFramingAdjusted()
                        }
                    )
                } else {
                    EmptyView()
                }
            }
        }
    }

    private func selectDesign(_ design: PlayerCardDesign, animated: Bool) {
        guard PlayerCardDesign.shippingDesigns.contains(design) else { return }
        guard selectedDesign != design else {
            return
        }

        let update = {
            selectedDesignID = design.rawValue
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.25), update)
        } else {
            update()
        }
    }

    private func presentShare() {
        guard let renderedImage = renderGate.shareableImage(
            for: selectedDesign,
            currentIdentity: renderIdentity
        ) else { return }
        shareArtifact = PlayerCardShareArtifact(image: renderedImage, design: selectedDesign)
    }

    private func render(_ request: PlayerCardPreviewRenderRequest) async {
        guard renderGate.accepts(request, currentIdentity: renderIdentity) else { return }
        let identity = request.identity
        let sourceURL = assetURL(relativePath: identity.photoSourceRelativePath)
        let legacyURL = assetURL(relativePath: identity.photoRelativePath)
        let content = identity.content
        let storedCrop = identity.playerCardPhotoCrop

        let renderWork = Task.detached(priority: .userInitiated) { () -> RenderOutput? in
            let sourceImage = Self.loadPhoto(at: sourceURL)
            let image = sourceImage ?? Self.loadPhoto(at: legacyURL)
            let crop = image.map { image in
                let usableStoredCrop = sourceURL == nil || sourceImage != nil ? storedCrop : nil
                return usableStoredCrop ?? PlayerPhotoFramingGeometry.centeredCrop(
                    aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
                    imageSize: image.size
                )
            }
            let renderer = PlayerCardRenderer()
            var cards: [PlayerCardDesign: UIImage] = [:]
            for design in PlayerCardDesign.shippingDesigns {
                guard !Task.isCancelled else { return nil }
                cards[design] = renderer.render(content: content, photo: image, crop: crop, design: design)
            }
            guard !Task.isCancelled else { return nil }
            return RenderOutput(
                cards: cards,
                framingImage: image,
                usesWorkingMaster: sourceImage != nil
            )
        }
        let output = await withTaskCancellationHandler {
            await renderWork.value
        } onCancel: {
            renderWork.cancel()
        }

        guard !Task.isCancelled,
              let output,
              renderGate.accepts(request, currentIdentity: renderIdentity) else { return }

        let framingOptions: PlayerPhotoFramingOptionSet?
        if let framingImage = output.framingImage {
            framingOptions = await PlayerPhotoPreparationService().framingOptions(for: framingImage)
        } else {
            framingOptions = nil
        }

        guard !Task.isCancelled,
              renderGate.accepts(request, currentIdentity: renderIdentity) else { return }

        var resultCards = output.cards
        var errorMessage: String?
        guard let selectedCard = output.cards[selectedDesign], selectedCard.cgImage != nil else {
            resultCards = [:]
            errorMessage = "Roll Call couldn't finish this card. Please try again."
            let result = PlayerCardPreviewRenderResult(
                request: request,
                cards: resultCards,
                framingImage: output.framingImage,
                framingOptions: framingOptions,
                usesWorkingMaster: output.usesWorkingMaster,
                errorMessage: errorMessage
            )
            guard renderGate.publish(result, currentIdentity: renderIdentity) else { return }
            onGenerationFailed("unknown")
            return
        }

        let result = PlayerCardPreviewRenderResult(
            request: request,
            cards: resultCards,
            framingImage: output.framingImage,
            framingOptions: framingOptions,
            usesWorkingMaster: output.usesWorkingMaster,
            errorMessage: nil
        )
        guard renderGate.publish(result, currentIdentity: renderIdentity) else { return }
        onGenerated()
    }

    private func effectiveCardCrop(for image: UIImage, usesWorkingMaster: Bool) -> NormalizedPhotoCrop {
        if (player.photoSourceRelativePath == nil || usesWorkingMaster),
           let crop = player.playerCardPhotoCrop {
            return crop
        }
        return PlayerPhotoFramingGeometry.centeredCrop(
            aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
            imageSize: image.size
        )
    }

    private func assetURL(relativePath: String?) -> URL? {
        guard let relativePath,
              let url = try? AppPaths.assetURL(relativePath: relativePath) else { return nil }
        return url
    }

    nonisolated private static func loadPhoto(at url: URL?) -> UIImage? {
        guard let url,
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

private struct PlayerCardCarousel: View {
    let playerName: String
    let renderedImages: [PlayerCardDesign: UIImage]
    let renderError: String?
    let selectedDesign: PlayerCardDesign
    @Binding var selection: String?
    let onSelect: (PlayerCardDesign) -> Void

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(max(geometry.size.width * 0.78, 220), 360)
            let cardHeight = cardWidth * 1.25
            let sideInset = max(0, (geometry.size.width - cardWidth) / 2)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(PlayerCardDesign.shippingDesigns) { design in
                        card(for: design, width: cardWidth, height: cardHeight)
                            .id(design.id)
                    }
                }
                .padding(.horizontal, sideInset)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selection, anchor: .center)
            .frame(height: cardHeight + 28)
        }
        .aspectRatio(0.94, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Player Card designs")
        .accessibilityHint("Swipe horizontally to compare designs, or use the selector above.")
    }

    @ViewBuilder
    private func card(for design: PlayerCardDesign, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let image = renderedImages[design] {
                PlayerCardImageView(image: image, playerName: playerName, design: design)
            } else if let renderError {
                ContentUnavailableView(
                    "Card Unavailable",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text(renderError)
                )
            } else {
                ProgressView("Creating \(design.title)…")
            }
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(design)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(design.title) Player Card preview for \(playerName)")
        .accessibilityValue(design == selectedDesign ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(design == selectedDesign ? .isSelected : [])
        .accessibilityAction(named: Text("Select")) {
            onSelect(design)
        }
    }
}

private struct PlayerCardActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onCompleted: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompleted: onCompleted)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, activityError in
            context.coordinator.activityDidComplete(
                completed: completed,
                activityError: activityError
            )
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    final class Coordinator {
        private let onCompleted: () -> Void
        private var completionGate = PlayerCardShareCompletionGate()

        init(onCompleted: @escaping () -> Void) {
            self.onCompleted = onCompleted
        }

        func activityDidComplete(completed: Bool, activityError: Error?) {
            guard completionGate.claimSuccessfulCompletion(
                completed: completed,
                hasError: activityError != nil
            ) else { return }
            onCompleted()
        }
    }
}
