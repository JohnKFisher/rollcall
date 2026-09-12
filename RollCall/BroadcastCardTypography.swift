import CoreGraphics
import CoreText
import Foundation
import UIKit

/// Typography tokens shared by the production Broadcast renderer and the
/// Player Card Lab. Clean V2 and Spotlight intentionally do not use these
/// tokens.
enum BroadcastCardTypography {
    private static let semiboldPostScriptName = "BarlowCondensed-SemiBold"
    private static let extraBoldPostScriptName = "BarlowCondensed-ExtraBold"
    private static let blackPostScriptName = "BarlowCondensed-Black"
    private static let fontSubdirectory = "BarlowCondensed"

    private static let registrationStatus: Bool = {
        let names = [semiboldPostScriptName, extraBoldPostScriptName, blackPostScriptName]
        let bundle = Bundle(for: BundleToken.self)
        var missing: [String] = []

        for name in names where UIFont(name: name, size: 12) == nil {
            let url = bundle.url(forResource: name, withExtension: "ttf", subdirectory: fontSubdirectory)
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: fontSubdirectory)
                ?? bundle.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf")

            guard let url,
                  let provider = CGDataProvider(url: url as CFURL),
                  let font = CGFont(provider) else {
                missing.append(name)
                continue
            }

            var registrationError: Unmanaged<CFError>?
            _ = CTFontManagerRegisterGraphicsFont(font, &registrationError)
            if UIFont(name: name, size: 12) == nil {
                missing.append(name)
            }
        }

#if DEBUG
        if !missing.isEmpty {
            print("BroadcastCardTypography: bundled Barlow font registration failed for \(missing.joined(separator: ", ")); using the condensed SF Pro fallback.")
        }
#endif
        return missing.isEmpty
    }()

    static var fontsAreRegistered: Bool {
        registrationStatus
    }

    static func team(size: CGFloat) -> UIFont {
        barlow(semiboldPostScriptName, size: size, fallbackWeight: .semibold)
    }

    static func jerseyNumber(size: CGFloat) -> UIFont {
        barlow(blackPostScriptName, size: size, fallbackWeight: .black)
    }

    static func decorativeJerseyNumber(size: CGFloat) -> UIFont {
        barlow(blackPostScriptName, size: size, fallbackWeight: .black)
    }

    static func playerFirstName(size: CGFloat) -> UIFont {
        barlow(semiboldPostScriptName, size: size, fallbackWeight: .semibold)
    }

    static func playerLastName(size: CGFloat) -> UIFont {
        barlow(extraBoldPostScriptName, size: size, fallbackWeight: .heavy)
    }

    static func sectionLabel(size: CGFloat) -> UIFont {
        barlow(semiboldPostScriptName, size: size, fallbackWeight: .semibold)
    }

    static func songTitle(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func artist(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .regular)
    }

    static func footer(size: CGFloat) -> UIFont {
        footerRollCall(size: size)
    }

    static func footerMadeWith(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .regular)
    }

    static func footerRollCall(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func drawFooterText(in rect: CGRect, color: UIColor, size: CGFloat, context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byClipping
        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "Made with ", attributes: [
            .font: footerMadeWith(size: size),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]))
        attributed.append(NSAttributedString(string: "Roll Call", attributes: [
            .font: footerRollCall(size: size),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]))
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    static func nameParts(_ displayName: String) -> (first: String, last: String) {
        let parts = displayName.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let last = parts.last else { return ("", "") }
        return (parts.dropLast().joined(separator: " "), last)
    }

    private static func barlow(_ postScriptName: String, size: CGFloat, fallbackWeight: UIFont.Weight) -> UIFont {
        _ = registrationStatus
        if let font = UIFont(name: postScriptName, size: size) {
            return font
        }

        let fallback = UIFont.systemFont(ofSize: size, weight: fallbackWeight)
        let traits = fallback.fontDescriptor.symbolicTraits.union(.traitCondensed)
        guard let descriptor = fallback.fontDescriptor.withSymbolicTraits(traits) else { return fallback }
        return UIFont(descriptor: descriptor, size: size)
    }

    private final class BundleToken {}
}
