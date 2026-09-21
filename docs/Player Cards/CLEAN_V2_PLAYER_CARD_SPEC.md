# Impact Player Card Specification

**Product:** Roll Call  
**Feature:** Player Cards  
**Template:** Impact (internal renderer identity: `clean-v2`)
**Status:** Design specification / implementation source of truth  
**Lab authoring canvas:** 1080 × 1350 px (4:5);
**Production export:** 1200 × 1500 px (4:5), PNG, sRGB

---

> Naming note: the design formerly called Clean v2 is now displayed as **Impact**. The internal `clean`/`CleanV2` renderer identifiers remain stable so this display-name rename cannot change artwork selection or compatibility behavior. Production keeps the canonical 1080×1350 geometry and rasterizes it directly at 1200×1500.

## 1. Purpose

Impact is the restrained, premium, photo-first Roll Call player-card template.

It should feel like a polished share graphic rather than a screenshot of app UI. The visual language should be modern, confident, and sports-adjacent without drifting into generic youth-sports template aesthetics.

Impact should be reliable with essentially any valid uploaded rectangular player photo and must not depend on AI image generation, player cutouts, or successful foreground segmentation.

The card should be deterministic: given the same player data, crop, template version, and team color, it should render the same result every time.

---

## 2. Design Principles

1. **The player photo is the primary visual element.**
2. **The player name is the primary typographic element.**
3. **The card should read as one continuous composition, not stacked UI panels.**
4. **Team color should unify the design without taking over the design.**
5. **Visual effects should resemble lighting and atmosphere, not borders or decoration.**
6. **The walk-up song should feel integrated into the poster rather than displayed inside a media-player component.**
7. **The card should remain elegant when content is missing, unusually long, or visually awkward.**
8. **The exported player photo must remain recognizably and faithfully the uploaded photograph.**
9. **The same production renderer should be used for preview, development tools, snapshots, and export.**
10. **No current implementation choice should assume the team-color palette will remain limited to preset colors.**

---

## 3. Canonical Canvas

Impact uses a fixed graphic coordinate system rather than device-responsive layout.

- Canvas: **1080 × 1350 px**
- Aspect ratio: **4:5**
- Export format: **PNG**
- Color space: **sRGB**
- Export must not depend on device display scale.
- In-app previews scale the canonical composition uniformly.
- Device size and Dynamic Type must not alter the exported composition.

Approximate initial design tokens:

| Element | Initial target |
|---|---:|
| Outer visual inset | 42–48 px |
| Critical-content safe inset | 68–72 px |
| Hero photo top | ~44 px |
| Hero/photo region | ~825–850 px |
| Photo/name transition | lower ~210 px of hero |
| Music region | ~300–330 px |
| Footer | ~80–90 px |
| Outer corner radius | ~32 px |
| Hero photo corner radius | ~20 px |

These are starting values to tune in the Player Card Lab before final constants are frozen.

---

## 4. Overall Composition

The vertical rhythm should be:

```text
HERO PHOTO
team / jersey / player

NAME LOCKUP
photo fading into background

WALK-UP MUSIC
song / artist / waveform

MADE WITH ROLL CALL
```

Approximate structure:

```text
┌──────────────────────────────────────────┐
│                                          │
│  P-WAY THUNDER                     15    │
│  ──                                      │
│                                          │
│               HERO PHOTO                 │
│                                giant     │
│                                  15      │
│                                          │
│                                          │
│  ELLIE                                   │
│  FISHER                                  │
│          photo → dark gradient           │
│                                          │
│  WALK-UP MUSIC                           │
│  Can't Back Down                         │
│  Demi Lovato, Alyson Stoner…             │
│                                          │
│  ▂▅▇▃▆▂▅▇▅▃                              │
│                                          │
│  ───────── faint fading divider ─────    │
│  [icon] Made with Roll Call              │
│                                          │
└──────────────────────────────────────────┘
```

There should be no obvious box separating the photo, name, music, and footer regions.

---

## 5. Hero Photo

### 5.1 General Behavior

The hero photo is a large rectangular image near the top of the card.

- Use the user's saved/approved crop as authoritative.
- Render with an aspect-fill strategy inside the hero frame.
- Impact must not silently recrop the image based on Vision results.
- Legacy face-heavy crops must still produce an intentional card.
- Foreground segmentation is not required.
- Person/face detection may inform decorative-element placement only.

The photograph should occupy approximately 65% of the total card height.

The actual photo may continue farther downward under the gradient than is visually apparent so the transition into the card background never exposes a seam.

### 5.2 Photo Fidelity

Impact enhances presentation but does not reinterpret the photograph.

Allowed:

- crop
- masking
- restrained contrast normalization if needed
- controlled darkening
- gradients
- subtle color-derived edge illumination
- light luminance-aware adaptation

Do not use:

- aggressive sharpening
- heavy saturation changes
- cinematic LUTs
- fake HDR
- AI upscaling
- face retouching
- global team-color tinting
- strong vignettes over the subject
- generative replacement or reinterpretation

The player should look like the person in the original photograph.

---

## 6. Photo-to-Card Gradient

The bottom of the hero image should dissolve naturally into the dark card background.

Conceptual progression:

```text
upper photo:           unchanged

~70% hero height:      extremely subtle darkening begins
~78%:                  clearly transitioning
~88%:                  strongly darkened
bottom:                visually matches card background
```

Requirements:

- Name text sits inside this transition.
- Darkening may be slightly stronger behind the name for readability.
- The transition should not look like a rectangular overlay.
- There should be no visible divider between the hero and music region.

---

## 7. Team-Color Edge Illumination

This is a signature Impact visual element.

The hero photo should receive subtle team-derived edge lighting that reads as ambient reflected light rather than a neon effect. Impact also uses a thin, solid, inset team-color border around the photo; this border is a separate restrained graphic treatment from the soft edge illumination.

### 7.1 Visual Construction

The effect should conceptually consist of:

1. a broad, soft accent-color bloom;
2. a narrower low-opacity edge illumination;
3. one or two restrained corner highlights.

The lighting must be asymmetric.

Preferred default lighting composition:

- strongest: upper-left / left edge
- secondary: upper-right / right edge
- minimal: lower edge, because the image is already fading into the card background

The result must never look like an evenly colored border.

All hero lighting effects must be composited before clipping to the rounded hero-photo shape.

---

## 8. Dynamic Team-Color System

### 8.1 Critical Requirement

**Impact must not use hardcoded visual variants for the team colors currently available in Roll Call.**

Roll Call is expected to support arbitrary user-selected team colors in the future, including selection from a full color wheel. The player-card rendering system must therefore derive all card colors algorithmically from the actual stored team color.

The implementation must work for any valid color input, not merely today's presets.

Current preset colors should be treated only as ordinary input examples and test fixtures.

### 8.2 Color Derivation Pipeline

The card should distinguish between the user's raw team color and derived colors optimized for different rendering roles.

```text
rawTeamColor
      ↓
resolvedTeamColor
      ↓
displayAccent
      ↓
illuminationAccent
```

**`rawTeamColor`**  
The exact team color stored by the app.

**`resolvedTeamColor`**  
A validated color representation used as the source for card derivation. If the stored team color is unavailable or invalid, fall back to Roll Call's normal default accent color.

**`displayAccent`**  
A dynamically derived version intended for legible graphic elements against the dark charcoal card.

Used for:

- readable jersey number;
- team-name accent rule;
- music waveform;
- selected small accent details;
- giant-number treatment as appropriate.

It should preserve the hue identity of the user's chosen team color while adjusting luminance/saturation only as necessary for legibility.

**`illuminationAccent`**  
A dynamically derived version intended to behave like emitted/reflected light when composited over photography.

Used for:

- photo edge illumination;
- faint outer-card atmospheric bloom.

It should preserve recognizable hue while constraining luminance and saturation into a useful lighting range.

Expected dynamic behavior includes:

- nearly black navy → lifted enough to create visible blue illumination;
- near-white yellow → restrained enough not to blow out image edges;
- highly saturated red → softened for light compositing while remaining clearly red;
- arbitrary color-wheel teal/purple/orange/etc. → handled using the same algorithm with no special-case palette lookup.

There should be **no preset-specific branch such as `if color == .yellow`, `if color == .blue`, etc.**

### 8.3 Photo-Aware Illumination Intensity

The renderer may sample luminance near the displayed image perimeter and adjust edge-light intensity within a narrow range.

- Bright photo edges → reduce glow.
- Dark photo edges → permit somewhat stronger glow.

This is a guardrail, not a creative randomizer.

The same photo and color must still render deterministically.

### 8.4 Accent Budget

Team-derived color should appear only in controlled locations:

- hero-photo edge illumination;
- giant translucent jersey number;
- small readable jersey number;
- short team-name accent rule;
- decorative music waveform;
- extremely faint outer-card atmospheric lighting.

Primary player-name text and song-title text remain neutral white/off-white.

The design should never become a full-card wash of the team color.

---

## 9. Team Identity

The team name appears in the upper-left of the hero region.

Style:

- uppercase;
- small;
- semibold;
- moderately tracked;
- neutral light text;
- short team-color accent line beneath.

Behavior:

- one line when possible;
- up to two lines for long team names;
- modest font reduction permitted;
- ellipsis only as an extreme fallback;
- when team name is absent, omit both the label and its accent rule;
- omission should not substantially reflow the composition.

Do not add filler slogans or team mottos.

---

## 10. Jersey Number

Impact uses two jersey-number treatments.

### 10.1 Readable Number

A small, clearly readable jersey number appears near the upper-right of the hero.

Preferred treatment:

```text
15
```

rather than `#15`.

Style:

- heavy system type;
- tabular digits where appropriate;
- derived display accent;
- visually clear but secondary to player name.

Support at least 1–3 characters/digits without changing the design architecture.

### 10.2 Giant Decorative Number

A large translucent jersey number sits over the hero photograph beneath functional text.

Default approximate region:

```text
x: 620 → beyond right canvas edge
y: 180 → 640
```

Characteristics:

- approximately 35–45% of hero height;
- partially clipped by hero boundaries when appropriate;
- very low opacity;
- same general type family/weight as readable number;
- may use translucent fill or restrained outline;
- derived from team color;
- should feel architectural rather than decorative.

If person/face bounds are available, position it predominantly on the emptier side of the photograph.

If detection is unavailable, default to the right.

Do not require foreground segmentation.

If no jersey number exists, omit both number treatments entirely.

---

## 11. Player Name Lockup

Preferred structure:

```text
ELLIE
FISHER
```

The name sits near the lower-left of the hero/photo transition.

### 11.1 Hierarchy

- first name: uppercase, medium/semibold, tracked modestly;
- last name: uppercase, heavy/black, dominant;
- last name should have roughly 1.8–2.2× the visual weight of the first name;
- both remain white or slightly warm off-white;
- do not use team color for the player name.

The name block uses the same main left anchor as the team and music content, approximately 68 px from the canvas edge.

Maximum intended width is approximately 75–80% of the canvas, with flexibility to extend rightward before shrinking.

### 11.2 Long-Name Rules

Names must never be truncated with an ellipsis.

Preferred adaptation order:

1. keep first and last names on separate lines;
2. use available horizontal width;
3. scale individual lines down within defined limits;
4. use a slightly condensed system-font width if needed;
5. use the minimum supported size only as the final fallback.

Do not automatically split a long surname into multiple lines.

If only one name component exists, display that component using the dominant name treatment instead of leaving an artificial blank line.

---

## 12. Typography System

Use Apple's system font family rather than a bundled display font.

The design derives character from:

- scale;
- weight;
- case;
- tracking;
- hierarchy;
- placement.

Do not scatter magic font sizes throughout SwiftUI.

Create a centralized token system conceptually similar to:

```swift
CleanCardTypography.playerLastName
CleanCardTypography.playerFirstName
CleanCardTypography.songTitle
CleanCardTypography.artist
CleanCardTypography.team
CleanCardTypography.jerseyNumber
CleanCardTypography.sectionLabel
CleanCardTypography.footer
```

Relative visual hierarchy:

1. player / photograph
2. last name
3. song title
4. first name
5. readable jersey number
6. team name
7. artist
8. `WALK-UP MUSIC`
9. Roll Call footer

Elements lower in the hierarchy should yield first when space becomes constrained.

---

## 13. Walk-Up Music Region

The music area should be integrated directly into the dark lower card surface.

Do not place it inside a large rounded rectangle or card-within-a-card.

Preferred hierarchy:

```text
WALK-UP MUSIC

Can't Back Down
Demi Lovato, Alyson Stoner, Anna Maria Perez de Taglé & Cast

▂▃▅▇▆▃▂▅▇▅▃▂
```

### 13.1 Label

`WALK-UP MUSIC`

- small uppercase;
- semibold;
- tracked;
- neutral/light typography;
- accompanied by a small team-color music note or short accent marker.

### 13.2 Song Title

- preserve proper title capitalization;
- do not force uppercase;
- white/off-white;
- semibold/bold;
- visually smaller than the player's last name;
- maximum two lines;
- modest size reduction allowed;
- wrap before aggressive shrinking.

### 13.3 Artist

- regular/medium;
- muted gray;
- maximum two lines;
- ellipsis allowed after two lines.

### 13.4 Do Not Include

- album artwork;
- play button;
- progress bar;
- playback duration;
- transport controls;
- any element that makes the card look like a media-player UI.

---

## 14. Decorative Waveform

The waveform is a visual symbol of audio, not a representation of the actual song waveform.

Requirements:

- approximately 18–30 bars;
- low profile;
- restrained irregularity;
- partially fading toward ends;
- team-derived display accent;
- approximately 50–65% of content width;
- should sit beneath or alongside music information without dominating it.

It may use:

- one fixed pattern; or
- a stable seeded pattern.

It must never use nondeterministic randomness.

Do not render a waveform when no walk-up music is selected.

---

## 15. Music-Region Layout Behavior

Approximate perceived spacing:

```text
WALK-UP MUSIC
8–14 px
Song title
6–10 px
Artist
22–30 px
Waveform
```

The music block starts at a fixed design anchor rather than being pushed down by variable name height.

The footer also remains fixed.

Overflow adaptation order:

1. use horizontal width;
2. wrap where allowed;
3. reduce discretionary vertical spacing slightly;
4. reduce font size within defined limits;
5. truncate artist text only.

Do not solve overflow by:

- moving the footer;
- changing hero height;
- shrinking the entire card;
- overlapping other elements.

Short content must not cause the layout to collapse upward.

---

## 16. No Walk-Up Music State

If no song is selected:

- omit `WALK-UP MUSIC`;
- omit song title;
- omit artist;
- omit waveform;
- do not show `No walk-up music selected`;
- do not show placeholder copy;
- retain the footer and intentionally use the extra negative space.

The no-music card should look minimal, not incomplete.

---

## 17. Outer Card Treatment

Use a very dark charcoal rather than absolute black.

Recommended visual ingredients:

- nearly imperceptible vertical/radial background gradient;
- extremely fine subtle texture/grain;
- faint dynamically derived team-color atmospheric bloom near selected outer edges.

The outer accent should be substantially weaker than the hero-photo edge light.

Do not draw a full colored stroke around the card.

Preferred concept:

- subtle accent presence near one upper edge;
- much weaker echo near an opposite lower edge;
- should feel like internal lighting influencing the surface.

---

## 18. Footer and Roll Call Branding

Reserve a narrow bottom band, approximately 7–9% of card height.

Content:

```text
[Roll Call icon]  Made with Roll Call
```

Rules:

- left-aligned;
- use actual Roll Call app icon;
- icon remains small;
- `Made with` in muted gray;
- `Roll Call` slightly brighter and/or semibold;
- mixed-case normal system typography;
- no team-color emphasis required;
- do not place filler content on the right merely for symmetry.

Do not include:

- promotional slogans;
- website address;
- QR code;
- App Store badge;
- secondary tagline.

A very faint horizontal separator may appear above the footer, fading at both ends rather than running as a hard full-width line.

---

## 19. Card and Photo Geometry

Approximate hierarchy:

```text
Outer card radius: ~32 px
Hero photo corners: square (90°)
Photo border: thin, solid, inset team-color stroke
```

The photo border must not change the established photo dimensions, crop, or position.

Avoid repeated UI-style rounded containers elsewhere in Impact.

---

## 20. Missing Data Rules

### No jersey number
Omit both number treatments. Do not substitute `00`, `—`, or invented content.

### No team name
Omit team label and accent rule.

### No photo
Do not generate Impact. The production UI should communicate that a player photo is required.

### Missing first or last name
Use whichever name exists as the dominant name element.

The renderer must never invent content to preserve the layout.

---

## 21. Bright / Dark Photo Safeguards

The renderer should not globally "fix" photographs.

For bright images:

- strengthen the lower gradient enough to protect text readability;
- reduce edge-light intensity when perimeter luminance is already high.

For dark images:

- preserve the photograph;
- allow somewhat stronger edge illumination when useful;
- do not automatically brighten faces.

Do not perform face-specific exposure correction.

---

## 22. Accessibility

The exported player card is graphic artwork and should not reflow based on Dynamic Type.

The surrounding production preview UI and Player Card Lab remain normal accessible SwiftUI interfaces.

Requirements:

- VoiceOver labels for interactive preview/lab controls;
- normal accessible controls in app UI;
- practical high contrast for important card text;
- Dynamic Type must not alter exported card geometry or typography.

---

## 23. Export Requirements

Canonical Impact export:

- **1080 × 1350 px**
- **PNG**
- **sRGB**
- fixed dimensions independent of screen/device;
- full-quality source image, not a thumbnail;
- local/on-device processing;
- no network dependency;
- deterministic rendering.

If alternate social-share aspect ratios are added later, they should be purpose-built layout variants rather than stretched/cropped versions of this canvas.

---

## 24. Renderer Architecture

The Impact card should be implemented as an isolated production renderer driven by a card model.

Conceptually:

```swift
CleanPlayerCard
PlayerCardModel
CleanCardLayout
CleanCardTypography
CleanCardColors
```

`CleanCardLayout` should centralize:

- canvas size;
- hero frame;
- visual insets;
- critical-content safe inset;
- name anchors;
- jersey-number zones;
- music region;
- waveform frame;
- footer region;
- gradient thresholds;
- corner radii.

`CleanCardColors` should centralize dynamic color derivation from arbitrary team-color input.

Do not scatter layout values, font sizes, or team-color corrections through view code.

---

## 25. Preview / Export Parity

The actual production card view must be used for:

- in-app preview;
- Player Card Lab;
- snapshot tests;
- exported PNG.

Do not maintain separate "approximate preview" and "final export" designs unless technically unavoidable.

What the developer approves in the Lab should be what the user exports.

---

## 26. Player Card Lab

Impact was first implemented in the development-only Player Card Lab and is now available through the production selector.

The Lab should render the actual production card implementation.

### 26.1 Required Fixtures

Include representative states such as:

- normal player;
- long player name;
- long team name;
- very long song / artist;
- no jersey number;
- no walk-up music;
- bright photograph;
- dark photograph;
- very light team color;
- very dark team color;
- highly saturated team color;
- arbitrary custom color-wheel values;
- three-digit jersey number;
- face-heavy crop;
- waist-up crop;
- full-body crop;
- subject far left;
- subject far right.

The color fixtures must specifically verify that the renderer works with arbitrary dynamically supplied colors and not just Roll Call's current preset palette.

### 26.2 Temporary Tuning Controls

Development-only controls should expose likely iteration points:

- hero height;
- gradient start;
- gradient strength;
- name Y position;
- first-name size;
- last-name size;
- giant-number X/Y;
- giant-number size;
- giant-number opacity;
- photo edge-light intensity;
- outer-card glow intensity;
- music block Y;
- waveform width;
- waveform height;
- footer Y.

These are design-development controls, not user-facing customization options.

After approval, final values become versioned constants/tokens.

### 26.3 Lab Actions

Required:

- **Reset to spec values**
- **Export current card**
- **Generate Clean test set**
- **Generate contact sheet**

The canonical export action should produce the exact 1080 × 1350 PNG.

The contact sheet should show multiple representative cards simultaneously so problems that only appear with certain names, crops, songs, numbers, or colors are easy to spot.

---

## 27. Snapshot / Visual Regression Tests

After visual tuning is approved, capture reference snapshots for a representative core fixture set.

Tests should catch regressions such as:

- name movement;
- broken typography scaling;
- giant number becoming too prominent;
- photo gradient disappearing;
- edge illumination becoming excessive;
- arbitrary custom team colors rendering badly;
- footer wrapping or moving;
- long songs colliding with waveform/footer;
- no-music state leaving labels or waveform behind;
- hero-photo clipping errors;
- preview/export divergence.

Do not make every tiny anti-aliasing difference a permanent blocker; protect meaningful visual structure and layout.

---

## 28. Determinism

**Given the same player data, crop, template version, source image, and team color, Impact must render the same card every time.**

This applies to:

- waveform;
- lighting geometry;
- color derivation;
- number placement;
- layout;
- typography;
- export.

If Vision metadata is cached or used to select a decorative-number side, the resulting choice should also remain stable for the same source/crop.

---

## 29. Explicit Exclusions

Impact does **not** use:

- AI-generated imagery;
- required foreground/person segmentation;
- player cutouts;
- fake stadium backgrounds;
- smoke;
- sparks;
- particles;
- lightning;
- grunge overlays;
- album artwork;
- media playback controls;
- nested UI-style cards;
- decorative pills;
- promotional slogans;
- filler copy;
- neon borders;
- heavy photo filters;
- arbitrary random layouts;
- hardcoded color variants tied to today's preset team colors;
- user-facing controls for glow strength, typography, waveform style, or layout tuning.

More dramatic treatments belong in Testing, Broadcast, or future templates.

---

## 30. Impact Acceptance Criteria

Impact is ready for production integration when:

1. The card clearly feels like a finished share graphic rather than an app screenshot.
2. The photo remains the dominant visual element.
3. The two-line name lockup is strong and readable.
4. The giant jersey number is visible but restrained.
5. The small jersey number remains clearly readable.
6. The hero photo fades seamlessly into the lower card.
7. Team-color edge illumination reads as light, never a border.
8. Arbitrary team colors are derived dynamically and render successfully without palette-specific code.
9. The walk-up music area contains no nested UI-style panel.
10. The waveform is decorative, restrained, and deterministic.
11. The no-music state looks intentional.
12. Long names/team names/song metadata remain usable.
13. Footer branding is present but quiet.
14. Preview and exported PNG match.
15. The Player Card Lab can generate individual exports, fixture sets, and a contact sheet.
16. Representative visual regression tests pass.
17. The implementation has no network or generative-AI dependency.
18. Impact remains visually restrained enough to serve as a selectable production card style.

---

## 31. Future Compatibility

The implementation should leave room for Roll Call to add:

- unrestricted user-selected team colors via color wheel;
- additional player-card templates;
- optional segmentation-based effects in Spotlight;
- alternate share aspect ratios;
- additional controlled color-derived visual treatments.

Impact itself should remain stable, deterministic, and deliberately restrained.
