# Broadcast Player Card Specification

**Product:** Roll Call  
**Feature:** Player Cards  
**Template:** Broadcast  
**Status:** Design specification / implementation source of truth  
**Lab authoring canvas:** 1080 × 1350 px (4:5);
**Production export:** 1200 × 1500 px (4:5), PNG, sRGB

## 1. Purpose

Broadcast is Roll Call's polished sports-broadcast player-card template. It is more assertive than Impact but remains disciplined: a large player photograph, structured lower-third geometry, strong jersey-number treatment, and controlled team-color graphics. It should feel like a premium player-introduction graphic rather than a fake television interface.

Broadcast must work with the same ordinary uploaded player photographs as Impact and must not require person segmentation, generative imagery, or special photography.

The defining combination is **large photo + structured diagonal lower-third + assertive number + disciplined team-color geometry**.

## 2. Relationship to Other Templates

- **Impact:** restrained, photo-first poster.
- **Broadcast:** structured, confident player-introduction graphic.
- **Testing:** dramatic hero treatment with segmentation diagnostics.

Broadcast should clearly belong to the same Roll Call design family as Clean while providing a meaningfully stronger presentation. It must not become merely “Clean with diagonal lines.”

## 3. Core Principles

1. The photograph remains the dominant visual element.
2. Player identity outranks decorative graphics.
3. Graphics deliberately intrude into the photograph rather than softly dissolving into it.
4. One consistent shallow angle drives the geometric system.
5. Team color is derived dynamically from arbitrary input colors.
6. Larger team-colored areas use controlled derived tones rather than raw full-intensity color.
7. Every graphic element must convey real information, establish hierarchy, or support the template geometry.
8. Broadcast must not imitate television by adding fake television content.
9. Preview and export use the same production renderer.
10. Rendering is deterministic.

## 4. Canonical Canvas

- **1080 × 1350 px**
- **4:5**
- **PNG**
- **sRGB**
- Fixed logical coordinate system.
- Device size/display scale must not alter exported geometry.
- Dynamic Type must not recompose the exported graphic.

The same canvas as Clean allows direct template comparison in the Player Card Lab.

## 5. Overall Composition

```text
┌──────────────────────────────────────────┐
│  P-WAY THUNDER                           │
│  ━━━━━━━                         15      │
│                                          │
│               HERO PHOTO                 │
│                                          │
│                                   15     │
│                                          │
│    ELLIE                                 │
│    FISHER                                │
│━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━        │
│                                          │
│   ♪ WALK-UP MUSIC                        │
│   Can't Back Down                        │
│   Demi Lovato…            ▂▅▇▃▆▂▅       │
│                                          │
│ [icon] Made with Roll Call               │
└──────────────────────────────────────────┘
```

The lower-third is not a rounded box. It is a geometric field that enters the hero photograph at a shallow angle and transitions into the lower card surface.

## 6. Broadcast Angle

Use one consistent shallow diagonal throughout the template. Initial tuning target: **10°**.

Centralize it as the Broadcast tuning angle. The same angle should influence the lower-third leading edge, team accent rule, lower-third accent edge, music-region termination, waveform, and any secondary geometric plane. Do not introduce unrelated random angles.

## 7. Hero Photo

The hero photograph should occupy approximately **68–72%** of the visual composition. Initial targets: starts around `y ≈ 40`; effectively continues to `y ≈ 1060`; lower-third begins intruding around `y ≈ 855`; lower region becomes effectively opaque charcoal around `y ≈ 980–1020`. Player Card Lab exposes a Broadcast-only photo-height control for iterative tuning.

Requirements:
- use the user's authoritative saved crop;
- aspect-fill within the hero frame;
- do not silently recrop based on Vision;
- no required person segmentation;
- no player cutout;
- no generated background;
- use full-quality card-photo source rather than avatar thumbnail.

Broadcast photography should be slightly less atmospheric than Clean. Geometry does most of the visual work.

## 8. Lower-Third Geometry

Construct the lower-third from approximately three layers:
1. **Base dark plane** — neutral near-black charcoal.
2. **Team-derived translucent plane** — slightly offset along the Broadcast angle.
3. **Thin accent edge** — sharper team-derived structural line following the same angle.

```text
PHOTO
    ╲
     ╲  thin strong accent
      ╲────────────
       ╲ muted team-tinted plane
        ╲████████████████
         █ neutral dark base █
```

The upper portion should retain some underlying photographic texture. The planes become increasingly opaque lower down until the music area has a stable dark surface. Do not turn the lower-third into a rounded SwiftUI panel.

## 9. Player Name

Preferred lockup:

```text
ELLIE
  FISHER
━━━━━━━━━━━━━━
```

Initial anchor: `x ≈ 70 px`, `y ≈ 850 px`. The first name sits approximately 50% closer to the surname, and the name rule remains below the surname with deliberate clearance. These are part of the Broadcast geometry, not decorative punctuation.

- First name: Barlow Condensed Semibold, uppercase, modest positive tracking.
- Last name: Barlow Condensed ExtraBold, uppercase, dominant, neutral or slightly tight tracking.
- Name text: neutral white/off-white.
- Do not use team color for player name.

## 10. Long Player Names

Surname remains single-line and never ellipsized. Adaptation order:
1. use normal region;
2. extend toward number zone when collision-free;
3. reduce font size within bounds;
4. reduce tracking;
5. use defined minimum size.

Do not distort the font horizontally and never ellipsize the surname.

The lower-third does not grow taller. Decorative number yields before player identity. If only one name component exists, use it as the dominant line.

## 11. Jersey Number System

### 11.1 Upper Readable Number

Broadcast does not render a separate readable jersey number in the upper
corner. The upper-corner number and its surrounding strokes are intentionally
removed; the jersey number remains available only as the large decorative
number below.

### 11.2 Large Decorative Number

Default region: `x: 660 → 1100`, `y: 420 → 840`. Player Card Lab exposes a
Broadcast-only Y-axis control for this number.

- bold translucent fill, restrained outline, or combination;
- Barlow Condensed Black, using the same jersey-number role as the former readable treatment;
- visually around 12–22% opacity depending on color/photo;
- crosses photo/lower-third transition;
- no segmentation required;
- Vision bounds may bias placement toward negative space;
- never preserve the number at the expense of the player's face.

If no jersey number exists, remove the decorative number treatment.

## 12. Team Label

Upper-left:

```text
P-WAY THUNDER
━━━━━━━━
```

Barlow Condensed Semibold, uppercase, moderately tracked, slightly larger than
the earlier treatment, neutral light text, team-derived structural accent
rule. The underline matches the measured rendered label width and sits below
the label with approximately half the previous gap, without overlapping it.
Allow two lines for long names, then tighten
tracking/reduce size, with ellipsis only as pathological fallback. If absent,
omit label and rule without substantially moving other content.

## 13. Dynamic Team-Color System

**Broadcast must derive its complete visual palette algorithmically from the actual stored team color.** It must support arbitrary future color-wheel selections and contain no hardcoded designs/correction tables for today's preset team colors.

```text
rawTeamColor
      ↓
resolvedTeamColor
      ↓
├── displayAccent
├── strongGraphicAccent
├── mutedGraphicAccent
├── illuminationAccent
└── contrastAccent
```

- `rawTeamColor`: exact stored team color.
- `resolvedTeamColor`: validated source; missing/invalid falls back to Roll Call default accent.
- `displayAccent`: optimized for smaller readable accents against charcoal.
- `strongGraphicAccent`: preserves hue closely for thin structural graphics.
- `mutedGraphicAccent`: darker/subdued derivative for larger translucent planes.
- `illuminationAccent`: optimized for reflected/emitted-light behavior over photography.
- `contrastAccent`: derived light/dark companion used only where needed for sufficient contrast.

There must be no preset-specific logic such as `if color == .yellow` or `if color == .blue`. Current presets are test fixtures only.

### Color extremes

**Very light:** thin accents may remain faithful; larger planes darken substantially; illumination is capped; no large pale full-opacity areas.

**Very dark:** thin accents are lifted enough to remain visible; muted planes may stay dark; number/illumination can gain energy.

**Very saturated:** thin accents may retain saturation; larger planes desaturate/darken; illumination softens; avoid stacking saturated elements.

All behavior is formula-driven.

## 14. Visual Color Budget

Conceptual target:
- ~80–85% neutral/photo;
- ~10–15% dark team-influenced structure;
- ~5% visibly strong accent.

This is a visual guideline, not literal pixel accounting.

## 15. Color Architecture

Use a dedicated `BroadcastCardColorResolver`, returning a structured palette such as:

```swift
BroadcastDerivedColors(
    displayAccent: ...,
    strongGraphicAccent: ...,
    mutedGraphicAccent: ...,
    illuminationAccent: ...,
    contrastAccent: ...
)
```

Shared low-level color math may be reused across templates, but Broadcast should not simply inherit Clean's derived palette. Centralize opacity tokens for lower-third tint, accent line, large number, photo glow, and outer atmosphere.

## 16. Photo Edge Lighting

Broadcast retains a small amount of Clean's team-derived edge illumination for family resemblance, but geometry is the primary visual device. Modest luminance-aware intensity adaptation is allowed if deterministic.

## 17. Bright, Dark, Busy, and Unusual Photos

**Bright:** strengthen lower-third transition and structural contrast as needed; do not globally darken photo.

**Dark:** do not automatically brighten player; accents may be lifted; lower-third remains distinguishable.

**Busy:** subtle localized dark backing gradients may protect upper team label/readable number. Never use boxes/pills.

**Face-heavy:** decorative number yields/moves rather than interfering with face.

**Subject far left/right:** Vision may inform large-number placement, but do not mirror the entire layout.

## 18. Walk-Up Music Region

Treat music as structured broadcast information, not a media player.

```text
♪ WALK-UP MUSIC

  Can't Back Down
  Demi Lovato, Alyson Stoner...

                       ╱▂▄▆█▅▃▂▄▇
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Use a neutral dark base continuous with the lower-third and a thin structural termination using the Broadcast angle. Do not add a separate short horizontal lead-in line beside or above the music label. No rounded panel.

## 19. Music Typography

**Label:** Barlow Condensed Semibold, small uppercase, positively tracked, neutral/light, with small team-derived accent mark.

**Song:** SF Pro Display Semibold, proper capitalization, normal width and tracking, neutral white/off-white, max two lines, wrap before aggressive shrinking, subordinate to last name.

**Artist:** SF Pro Text Regular, normal tracking, muted gray, max two lines, ellipsis permitted.

The default Broadcast music group sits approximately 50% closer to the player
name lockup than the earlier spacing treatment.

Do not use team color for song/artist.

## 20. Broadcast Waveform

Decorative, deterministic, tighter/more geometric than Clean. Prefer a lower-right region above the bottom structural line, approximately 50% larger than the earlier Broadcast treatment, shifted left enough to keep the rotated waveform fully visible, and rotated to the shared Broadcast angle so it aligns with the diagonal geometry. It may shorten/reduce height before important metadata yields. Team-derived accent. No waveform when no music exists.

## 21. No-Music State

Remove music label, note, song, artist, and waveform. Template-level Broadcast geometry may remain but becomes quieter. Do not display app-state placeholder copy.

## 22. Footer

```text
[Roll Call icon] Made with Roll Call
```

Align to Broadcast grid. Small real app icon; `Made with` uses SF Pro Text Regular and stays muted; `Roll Call` uses SF Pro Text Semibold and is slightly brighter. No large team-color plane, slogan, website, QR code, or App Store badge. Footer region remains fixed.

## 23. Content Collision Priority

Highest to lowest:
1. player/photo
2. player name
3. song title
4. team name
5. artist
6. walk-up music label
7. large decorative number
8. waveform
9. secondary accent geometry
10. atmospheric effects

Footer is protected in its fixed region. Content may yield; core framework remains stable.

## 24. Overflow Behavior

For music/content overflow:
1. wrap within permitted line counts;
2. tighten discretionary spacing slightly;
3. reduce font size within limits;
4. shorten/reduce waveform;
5. truncate artist if necessary.

Do not move footer, grow lower-third, change hero height, overlap content, or shrink entire card.

## 25. Missing Data

- **No number:** remove the decorative number treatment.
- **No team:** remove team label/rule.
- **No photo:** do not generate Broadcast; production UI explains photo requirement.
- **One name component:** use as dominant line.
- **No music:** use no-music behavior above.

Never invent content.

## 26. Outer Card Atmosphere

Very dark charcoal base, nearly imperceptible neutral gradient, subtle grain, and faint dynamically derived team-color atmospheric bloom. Quieter than Clean because Broadcast has stronger internal geometry. No complete colored outer stroke.

## 27. Typography Architecture

Use centralized Broadcast-specific typography tokens. Barlow Condensed is the
identity/sports-graphics layer; SF Pro is the natural-language music and Roll
Call branding layer. This deliberately replaces the earlier system-font-only
rule while preserving disciplined hierarchy and avoiding a cliché varsity,
fake-TV, or esports treatment.

```swift
BroadcastCardTypography.team
BroadcastCardTypography.jerseyNumber
BroadcastCardTypography.decorativeJerseyNumber
BroadcastCardTypography.playerFirstName
BroadcastCardTypography.playerLastName
BroadcastCardTypography.sectionLabel
BroadcastCardTypography.songTitle
BroadcastCardTypography.artist
BroadcastCardTypography.footer
```

The Barlow Condensed Semibold, ExtraBold, and Black files are bundled with the
app and registered for deterministic rendering. Song title, artist, and footer
use SF Pro tokens; the footer keeps `Made with` Regular and `Roll Call`
Semibold. Preview, export, and Player Card Lab share these tokens.

Broadcast Player Card Lab defaults and controls include:

- broadcast angle: default `10.0°`;
- lower-third Y: default `865.00`, range `620` to `900` pixels;
- photo height: default `1020`, range `800` to `1300` pixels;
- player-name Y: default `850`, range `720` to `900` pixels;
- music-block Y: default `1080`, range `980` to `1140` pixels;
- tinted-plane opacity: default `0.40`, range `0.25` to `0.85`;
- giant-number opacity: default `0.60`, range `0.10` to `1.0`;
- giant-number Y: default `650`, range `400` to `1000` pixels.

The default bottom structural line remains fixed while the player-name and
music-block controls compress the space above it without shrinking the text.

## 28. Accessibility

Export is fixed graphic artwork and does not reflow with Dynamic Type. Production preview UI and Player Card Lab remain accessible SwiftUI interfaces with VoiceOver labels and practical contrast protection.

## 29. Export

Canonical output: **1080 × 1350 px, 4:5, PNG, sRGB**, full-quality source photo, fixed dimensions, local/on-device, no network requirement, deterministic. Future aspect ratios should be purpose-built variants rather than stretched/cropped exports.

## 30. Renderer Architecture

Template-specific:

```swift
BroadcastPlayerCard
BroadcastCardLayout
BroadcastCardTypography
BroadcastCardColorResolver
```

Shared:

```swift
PlayerCardModel
PlayerCardLab
CardFixtureLibrary
CardExportService
CardContactSheetGenerator
TeamColor derivation primitives
```

`BroadcastCardLayout` centralizes canvas, angle, hero frame, lower-third geometry, plane offsets, name anchors, number regions, team label, music region, waveform, and footer. Do not scatter magic values through view code.

## 31. Preview / Export Parity

The same production Broadcast renderer powers in-app preview, Player Card Lab, snapshot tests, and exported PNG. The Lab must not contain a simplified mock.

## 32. Player Card Lab

Extend the template-agnostic Lab created for Clean:

```text
[ Impact ] [ Broadcast ]
```

and later:

```text
[ Impact ] [ Broadcast ] [ Testing ]
```

The same fixture can switch templates without changing preview canvas.

### Broadcast-specific tuning controls

- Broadcast angle
- lower-third intrusion height
- base-plane opacity
- tinted-plane offset
- tinted-plane opacity
- accent-edge thickness
- name X/Y
- large-number X/Y
- large-number size
- large-number opacity
- upper number-frame dimensions
- team-label position
- music-region Y
- waveform X/Y/width
- photo edge-light intensity

These are development-only. Approved values become versioned tokens.

## 33. Arbitrary Color Development Tool

The Broadcast Lab should include a development-only arbitrary color picker. Dragging anywhere in color space updates the actual production card immediately. This validates future-proof color derivation and is not automatically a shipped version of the future user color picker.

## 34. Required Fixtures

Content/photo fixtures:
- normal player
- long player name
- long team name
- very long song/artist
- no jersey number
- no music
- bright photograph
- dark photograph
- busy photograph
- face-heavy crop
- full-body crop
- subject far left
- subject far right
- three-digit number

Color stress fixtures:
- near-black
- near-white
- high-saturation red
- green
- blue
- yellow
- cyan
- magenta
- orange
- purple
- brown
- gray
- very low saturation
- very high saturation
- several arbitrary non-preset color-wheel values

## 35. Contact Sheets

Support a Broadcast-only contact sheet and a template-comparison sheet:

```text
                CLEAN        BROADCAST

Normal          [card]        [card]
Long Name       [card]        [card]
Bright Photo    [card]        [card]
Dark Photo      [card]        [card]
No Music        [card]        [card]
Wild Color      [card]        [card]
```

Spotlight later becomes a third column.

## 36. Snapshot / Visual Regression Tests

Protect representative cases including:
- Broadcast-angle consistency
- lower-third geometry
- player-name alignment
- large-number placement
- upper number frame
- arbitrary-color derivation
- bright/dark/busy photo contrast
- no-number state
- no-music state
- long surname
- long song/artist
- footer placement
- waveform containment
- preview/export parity

Use curated visual color extremes plus unit tests of the color resolver rather than snapshotting every possible color.

## 37. Determinism

**Given identical player data, source photo/crop, template version, and raw team color, Broadcast must render the same composition every time.** This includes palette derivation, number placement, waveform, geometry, lighting, typography adaptation, and export. No true randomness.

## 38. Explicit Exclusions

Broadcast does **not** use:
- fake `LIVE` indicators
- fake TV-network logos
- faux scoreboards
- tickers
- fake statistics
- arbitrary numbers pretending to be statistics
- stadium backgrounds
- mandatory segmentation
- player cutouts
- smoke, sparks, or particles
- excessive diagonal stripes
- meaningless technical microtext
- slogans
- `PLAYER SPOTLIGHT` filler labels
- album artwork
- playback controls
- rounded UI-style information containers
- hardcoded designs for current team-color presets
- nondeterministic layout variation

**Do not add visual elements merely because they make the card look more like sports television. Every element must represent real information, establish hierarchy, or support the template's geometry.**

## 39. Acceptance Criteria

Broadcast is ready for production integration when:
1. It clearly feels more assertive and structured than Clean.
2. Photograph remains dominant.
3. Lower-third feels like intentional broadcast geometry, not UI.
4. One consistent shallow angle governs the system.
5. Player name remains dominant over decoration.
6. Large jersey number adds drama without compromising player.
7. Upper number reads clearly without becoming a pill/badge.
8. Team-color geometry is visible but disciplined.
9. Arbitrary color-wheel inputs work without preset-specific logic.
10. Bright, dark, and busy photos retain functional readability.
11. Music feels like broadcast information, not a media player.
12. No-music/no-number states look intentional.
13. Long names/metadata remain usable.
14. Footer remains quiet and fixed.
15. Preview and export match.
16. Lab arbitrary-color testing works.
17. Broadcast and Clean can be compared through shared fixtures/contact sheets.
18. Representative visual regression tests pass.
19. No network, generative AI, or mandatory segmentation is required.
20. Broadcast remains sophisticated rather than becoming a parody of sports television.

## 40. Future Compatibility

Architecture should accommodate unrestricted team-color selection via color wheel, Spotlight/additional templates, alternate purpose-built share ratios, future real player metadata, and shared color-derivation primitives without forcing identical palettes across templates.

Broadcast itself should remain a stable, deterministic template with a strong but restrained visual identity.
