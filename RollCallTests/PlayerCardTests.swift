import XCTest
import UIKit
@testable import RollCall

final class PlayerCardTests: XCTestCase {
    func testShippingDesignsAreOrderedAndExcludeInternalTemplates() {
        XCTAssertEqual(
            PlayerCardDesign.shippingDesigns,
            [.spotlight, .impact, .broadcast]
        )
        XCTAssertEqual(PlayerCardDesign.shippingDesigns.map(\.title), ["Spotlight", "Impact", "Broadcast"])
    }

    func testLastPlayerCardDesignPreferenceFallsBackForMissingOrUnknownValues() throws {
        XCTAssertNil(AppSettings.default.lastPlayerCardDesignID)
        XCTAssertEqual(AppSettings.default.lastPlayerCardDesign, .spotlight)

        let invalid = try JSONDecoder().decode(
            AppSettings.self,
            from: Data(#"{"lastPlayerCardDesignID":"testing"}"#.utf8)
        )
        XCTAssertEqual(invalid.lastPlayerCardDesignID, "testing")
        XCTAssertEqual(invalid.lastPlayerCardDesign, .spotlight)

        var saved = AppSettings.default
        saved.lastPlayerCardDesignID = PlayerCardDesign.impact.rawValue
        let reread = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(reread.lastPlayerCardDesign, .impact)
    }

    func testSelectedDesignRendersFourByFiveAtExpectedPixelSize() throws {
        let player = playerWithSong()
        let team = team(containing: player, accent: .blue)
        let photo = samplePhoto()

        let image = PlayerCardRenderer().render(
            content: PlayerCardContent(player: player, team: team),
            photo: photo,
            crop: PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: photo.size)
        )
        XCTAssertEqual(image.size, PlayerCardRenderer.outputSize)
        XCTAssertEqual(image.size.width / image.size.height, 4.0 / 5.0, accuracy: 0.0001)
        XCTAssertNotNil(image.pngData())
    }

    func testAllProductionDesignsRenderAtTheProductionCanvasSize() throws {
        let player = playerWithSong()
        let team = team(containing: player, accent: .blue)
        let photo = samplePhoto()
        let crop = PlayerPhotoFramingGeometry.centeredCrop(
            aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
            imageSize: photo.size
        )

        var images: [PlayerCardDesign: Data] = [:]
        for design in PlayerCardDesign.allCases {
            let image = PlayerCardRenderer().render(
                content: PlayerCardContent(player: player, team: team),
                photo: photo,
                crop: crop,
                design: design
            )
            XCTAssertEqual(image.size, PlayerCardRenderer.outputSize)
            images[design] = try XCTUnwrap(image.pngData())
        }

        XCTAssertNotEqual(images[.spotlight], images[.impact])
        XCTAssertNotEqual(images[.spotlight], images[.broadcast])
        XCTAssertNotEqual(images[.impact], images[.broadcast])
    }

    func testSpotlightDesignKeepsTheExistingDefaultRenderer() throws {
        let player = playerWithSong()
        let team = team(containing: player, accent: .blue)
        let photo = samplePhoto()
        let crop = PlayerPhotoFramingGeometry.centeredCrop(
            aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
            imageSize: photo.size
        )
        let content = PlayerCardContent(player: player, team: team)

        let implicitDefault = PlayerCardRenderer().render(content: content, photo: photo, crop: crop)
        let explicitSpotlight = PlayerCardRenderer().render(content: content, photo: photo, crop: crop, design: .spotlight)

        XCTAssertEqual(try XCTUnwrap(implicitDefault.pngData()), try XCTUnwrap(explicitSpotlight.pngData()))
    }

    func testPlayerCardDesignPersistenceDefaultsOldPlayersToSpotlightAndPreservesUnknownIDs() throws {
        var player = RollCallTestFixtures.player(id: UUID(), name: "Legacy", number: "7")
        player.playerCardDesign = .broadcast
        let encoded = try JSONEncoder().encode(player)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        object.removeValue(forKey: "playerCardDesignID")
        let oldPlayer = try JSONDecoder().decode(Player.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(oldPlayer.playerCardDesign, .spotlight)
        XCTAssertNil(oldPlayer.playerCardDesignID)

        object["playerCardDesignID"] = "future-v9"
        let futurePlayer = try JSONDecoder().decode(Player.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(futurePlayer.playerCardDesign, .spotlight)
        XCTAssertEqual(futurePlayer.playerCardDesignID, "future-v9")
        let reencoded = try JSONEncoder().encode(futurePlayer)
        let reread = try JSONDecoder().decode(Player.self, from: reencoded)
        XCTAssertEqual(reread.playerCardDesignID, "future-v9")
    }

    func testMissingOptionalContentAndPhotoStillRender() {
        var player = RollCallTestFixtures.player(id: UUID(), name: "Taylor", number: "")
        player.songAssignment = nil
        var team = team(containing: player, accent: .purple)
        team.name = ""

        let image = PlayerCardRenderer().render(
            content: PlayerCardContent(player: player, team: team),
            photo: nil,
            crop: nil
        )

        XCTAssertEqual(image.size, PlayerCardRenderer.outputSize)
        XCTAssertNotNil(image.jpegData(compressionQuality: 0.8))
    }

    func testLegacyTightCropRendersWithoutMaster() {
        let player = playerWithSong()
        let team = team(containing: player, accent: .red)
        let tight = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 500)).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 500, height: 500))
        }
        let crop = PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: tight.size)

        XCTAssertNotNil(PlayerCardRenderer().render(content: PlayerCardContent(player: player, team: team), photo: tight, crop: crop).pngData())
    }

    func testTeamAccentChangesRenderedGraphic() throws {
        let player = playerWithSong()
        let photo = samplePhoto()
        let crop = PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio, imageSize: photo.size)
        let blue = PlayerCardRenderer().render(
            content: PlayerCardContent(player: player, team: team(containing: player, accent: .blue)),
            photo: photo,
            crop: crop
        )
        let red = PlayerCardRenderer().render(
            content: PlayerCardContent(player: player, team: team(containing: player, accent: .red)),
            photo: photo,
            crop: crop
        )

        XCTAssertNotEqual(try XCTUnwrap(blue.pngData()), try XCTUnwrap(red.pngData()))
    }

    func testGeneratedAppleMusicClipKeepsOriginalArtistOnCard() throws {
        var player = playerWithSong()
        var clip = try XCTUnwrap(player.songAssignment?.privateClip)
        clip.generatedAsset = GeneratedClipAsset(
            relativePath: "prepared.m4a",
            status: .ready,
            renderedSelection: clip.requestedSelection,
            generationKey: clip.generationKey,
            generatedAt: .now
        )
        player.songAssignment = .privateClip(clip)

        let content = PlayerCardContent(player: player, team: team(containing: player, accent: .blue))

        XCTAssertEqual(content.songTitle, "Thunderstruck")
        XCTAssertEqual(content.artistName, "AC/DC")
    }

    /// Regression guard for the crash where the attribution mark was loaded with
    /// `UIImage(named: "AppIcon")`. That initializer raises an uncatchable
    /// Objective-C exception for an asset-catalog/Icon Composer app icon, so every
    /// Player Card render terminated the process. The renderer must resolve its
    /// brand mark without ever constructing an image from the app icon.
    func testDefaultBrandIconRendersWithoutRaising() throws {
        let player = playerWithSong()
        let team = team(containing: player, accent: .gold)

        let card = PlayerCardRenderer().render(
            content: PlayerCardContent(player: player, team: team),
            photo: samplePhoto(),
            crop: PlayerPhotoFramingGeometry.centeredCrop(
                aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
                imageSize: samplePhoto().size
            ),
            brandIcon: nil
        )

        XCTAssertEqual(card.size, PlayerCardRenderer.outputSize)
        XCTAssertNotNil(card.pngData())
    }

    /// The renderer intentionally uses a loose PNG rather than the special
    /// AppIcon catalog. Keep the resource in the app bundle so the safe source
    /// used by the crash repair cannot silently disappear from a Release build.
    func testAppBundleContainsDrawableBrandIconResource() throws {
        let appBundle = Bundle(identifier: "com.jkfisher.rollcall") ?? .main
        let resourceURL = try XCTUnwrap(
            appBundle.url(forResource: "AppIcon-iOS-Default-1024@1x", withExtension: "png")
        )
        let image = try XCTUnwrap(UIImage(contentsOfFile: resourceURL.path))

        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertNotNil(image.cgImage)
    }

    func testBroadcastTypographyFontsAndLicenseAreBundled() throws {
        XCTAssertTrue(BroadcastCardTypography.fontsAreRegistered)
        XCTAssertEqual(BroadcastCardTypography.team(size: 12).fontName, "BarlowCondensed-SemiBold")
        XCTAssertEqual(BroadcastCardTypography.playerLastName(size: 12).fontName, "BarlowCondensed-ExtraBold")
        XCTAssertEqual(BroadcastCardTypography.jerseyNumber(size: 12).fontName, "BarlowCondensed-Black")
        XCTAssertEqual(BroadcastCardTypography.decorativeJerseyNumber(size: 12).fontName, "BarlowCondensed-Black")
        let appBundle = Bundle(identifier: "com.jkfisher.rollcall") ?? .main

        for name in [
            "BarlowCondensed-SemiBold",
            "BarlowCondensed-ExtraBold",
            "BarlowCondensed-Black"
        ] {
            let url = try XCTUnwrap(
                appBundle.url(forResource: name, withExtension: "ttf", subdirectory: "BarlowCondensed")
                    ?? appBundle.url(forResource: name, withExtension: "ttf")
            )
            XCTAssertGreaterThan(try Data(contentsOf: url).count, 10_000)
        }

        let licenseURL = try XCTUnwrap(
            appBundle.url(forResource: "OFL", withExtension: "txt", subdirectory: "BarlowCondensed")
                ?? appBundle.url(forResource: "OFL", withExtension: "txt")
        )
        let license = try String(contentsOf: licenseURL, encoding: .utf8)
        XCTAssertTrue(license.contains("Copyright 2017 The Barlow Project Authors"))
        XCTAssertTrue(license.contains("SIL OPEN FONT LICENSE Version 1.1"))
    }

    func testBroadcastTypographyRendersLongContentAndOneTwoThreeDigitNumbers() throws {
        for name in ["Ellie Fisher", "Alexandria Montgomery-Summers"] {
            for number in ["7", "15", "123"] {
                let content = PlayerCardContent(
                    playerName: name,
                    playerNumber: number,
                    teamName: "P-WAY THUNDER LONG TEAM NAME",
                    songTitle: "A Very Long Walk-Up Song Title That Still Wraps",
                    artistName: "The Very Long Artist Name",
                    accentPreset: .blue
                )

                let image = PlayerCardRenderer().render(content: content, photo: nil, crop: nil, design: .broadcast)
                XCTAssertEqual(image.size, PlayerCardRenderer.outputSize)
                XCTAssertNotNil(image.pngData())
            }
        }
    }

    /// The renderer must still produce a complete card when no brand mark can be
    /// loaded at all, rather than drawing the attribution text under a gap.
    func testExplicitlySuppliedBrandIconIsUsedAndZeroSizedIconIsIgnored() throws {
        let player = playerWithSong()
        let team = team(containing: player, accent: .blue)
        let content = PlayerCardContent(player: player, team: team)

        let marked = PlayerCardRenderer().render(
            content: content,
            photo: nil,
            crop: nil,
            brandIcon: UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
                UIColor.systemPink.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            }
        )
        let unmarked = PlayerCardRenderer().render(content: content, photo: nil, crop: nil, brandIcon: UIImage())

        XCTAssertEqual(marked.size, PlayerCardRenderer.outputSize)
        XCTAssertEqual(unmarked.size, PlayerCardRenderer.outputSize)
        XCTAssertNotEqual(try XCTUnwrap(marked.pngData()), try XCTUnwrap(unmarked.pngData()))
    }

    private func playerWithSong() -> Player {
        var player = RollCallTestFixtures.player(id: UUID(), name: "Alex Ramirez", number: "12")
        player.songAssignment = .privateClip(
            SongClip(cue: Cue(
                id: UUID(),
                label: "Thunderstruck",
                source: .appleMusic(AppleMusicSource(songID: "fixture", title: "Thunderstruck", artistName: "AC/DC", duration: 292, previewURL: nil)),
                startTime: 0,
                duration: 12,
                fadeOutDuration: 0.35,
                pauseAfterAnnouncer: 0.2
            ))
        )
        return player
    }

    private func team(containing player: Player, accent: TeamAccentPreset) -> Team {
        var team = RollCallTestFixtures.team(players: [player])
        team.name = "Northside Falcons"
        team.accentPreset = accent
        return team
    }

    private func samplePhoto() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1_000, height: 1_500)).image { context in
            UIColor(red: 0.12, green: 0.22, blue: 0.38, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_000, height: 1_500))
            UIColor.systemOrange.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 300, y: 180, width: 400, height: 400))
            UIColor.white.setFill()
            context.fill(CGRect(x: 230, y: 570, width: 540, height: 780))
        }
    }

}
