# Testing Player Card Specification

**Product:** Roll Call  
**Feature:** Player Cards  
**Template:** Testing (internal renderer identity: `spotlight`)
**Status:** Design specification / implementation source of truth  
**Lab authoring canvas:** 1080 × 1350 px (4:5) (DEBUG-only Testing renderer);
**Production Spotlight export:** 1200 × 1500 px (4:5), PNG, sRGB (existing default renderer)

---

> Naming note: the former Spotlight Lab design is now displayed as **Testing** and remains DEBUG-only. The internal `Spotlight...` analysis and renderer identifiers remain stable; the production/default card now uses the **Spotlight** display name and continues to use the existing production renderer.

## 1. Purpose

Testing is Roll Call's most dramatic player-card template.

Its defining idea is that the **player breaks free of the photograph**. The original rectangular photograph remains visibly part of the composition while an on-device segmented copy of the player may extend beyond its frame, pass in front of the giant jersey number, and receive subtle team-color rim lighting.

The drama must come from the actual player photograph, depth, scale, typography, lighting, and composition—not from fake sports-poster effects.

Spotlight must remain a finished premium card even when segmentation is unavailable or unsuitable.

---

## 2. Template Family

The three templates should be clearly distinct:

- **Impact:** photograph presented beautifully; restrained poster.
- **Broadcast:** photograph plus structured diagonal lower-third; polished player-introduction graphic.
- **Testing:** staged photograph plus cinematic depth; player may break free of the frame.

A useful implementation/visual test is:

**Impact | Broadcast | Testing Fallback | Testing Enhanced**

All four should immediately read as different presentations of the same player.

---

## 3. Core Principles

1. The player is the star.
2. The original photograph remains part of the design.
3. Segmentation enhances Spotlight but never determines whether Spotlight can render.
4. The segmented foreground uses pixels from the original photo; it is never AI-generated or reconstructed.
5. Background and foreground player layers must share exactly the same source-photo transform.
6. The giant jersey number is a major depth element.
7. Team color behaves primarily as studio-like light and atmosphere rather than flat fill.
8. Arbitrary future color-wheel values must work through one dynamic derivation system.
9. The template composition remains stable across photographs.
10. Preview, Lab, snapshots, and export use the same production renderer.
11. Rendering is deterministic.
12. All image analysis remains on-device.

---

## 4. Canonical Canvas

- **1080 × 1350 px**
- **4:5**
- **PNG**
- **sRGB**
- fixed logical coordinate system;
- device-independent exported geometry;
- full-quality source photograph;
- no network requirement.

Dynamic Type affects surrounding app/Lab UI, not exported artwork.

---

## 5. Core Composition

Testing should be more centered and poster-like than Broadcast.

Conceptually:

```text
┌──────────────────────────────────────────┐
│ P-WAY THUNDER                      15    │
│                                          │
│                 15                       │
│             ┌──────────────┐             │
│          ╭──│              │──╮          │
│          │  │    PHOTO     │  │          │
│          │  │              │  │          │
│          ╰──│              │──╯          │
│             └──────────────┘             │
│                                          │
│              ELLIE                       │
│              FISHER                      │
│                                          │
│ ♪ Can't Back Down              ▂▅▇▃     │
│   Demi Lovato…                          │
│                                          │
│ [icon] Made with Roll Call               │
└──────────────────────────────────────────┘
```

When segmentation is suitable, the player extends beyond the photo boundaries and creates additional depth.

Exact visual constants remain provisional until reviewed in the Player Card Lab.

---

## 6. Photo Frame

Initial target:

- photo frame roughly **58–64%** of card height;
- centered horizontally;
- slightly above vertical center;
- enough surrounding room for controlled breakout;
- lower edge transitions toward the name region.

The frame should be visible but refined:

- modest/tight rounded corners;
- subtle dark edge;
- restrained team-color illumination;
- optional offset backdrop planes.

No thick border.

The saved/user-selected crop is authoritative.

---

## 7. Offset Backdrop Planes

One or two abstract planes may sit behind the rectangular photo to give fallback Spotlight depth.

Conceptually:

```text
      ╱ muted team plane
   ┌──────────────┐
   │    PHOTO     │
   └──────────────┘
        ╲ dark plane
```

These are staging/backdrop elements, not Broadcast-style lower-third geometry.

Use:

- neutral dark plane;
- darker/muted team-derived plane;
- restrained offset direction;
- low enough opacity to avoid visual clutter.

Exact offset and opacity should be tunable in the Lab.

---

## 8. Signature Layered-Photo Technique

Conceptual layer stack:

```text
1. dark card atmosphere
2. backdrop planes / atmospheric graphics
3. giant jersey number
4. original rectangular photograph
5. team-color lighting
6. segmented player from the same photograph
7. critical typography
8. music
9. footer
```

The segmented foreground player must consist of the user's actual photo pixels masked by on-device segmentation.

No synthetic player imagery.

---

## 9. Shared Photo Transform

Background photo and segmented foreground must use the exact same source-image transformation.

Conceptual pipeline:

```text
source photo
     ↓
SpotlightPhotoTransform
     ├── background photo rendering
     └── foreground player rendering
              ↓
        segmentation mask
```

Create an explicit shared transform abstraction, conceptually:

```swift
SpotlightPhotoTransform
```

It should account for:

- source dimensions;
- orientation normalization;
- crop;
- scale;
- translation;
- logical render frame.

Do not independently `aspectFill` the segmented player.

The foreground must align pixel-for-pixel with the underlying photograph before it is permitted to escape the photo clip.

---

## 10. Segmentation Architecture

Spotlight uses Apple on-device person-segmentation/Vision capabilities where appropriate.

Segmentation is optional enhancement data.

Internal render-quality states:

```swift
enum SpotlightSegmentationQuality {
    case excellent
    case usable
    case fallback
}
```

These states are not exposed to users.

---

## 11. Excellent Segmentation

When the mask is strong:

- use full controlled breakout;
- allow head/helmet above photo boundary;
- allow shoulders/arms across side boundaries;
- allow torso/body farther into permitted lower transition;
- giant number may sit behind player;
- use normal Spotlight directional rim light;
- controlled depth effects are enabled.

The breakout still obeys protected zones and maximum envelopes.

---

## 12. Usable Segmentation

When the mask is acceptable but uncertain:

- use conservative breakout;
- prioritize head/shoulders;
- reduce side extension;
- reduce lower extension;
- reduce rim-light width/opacity;
- avoid optional name overlap;
- preserve more of the original rectangular photo around uncertain edges.

Restraint should conceal segmentation weakness.

---

## 13. Fallback

When segmentation fails, is unavailable, is ambiguous, or is clearly poor:

- render Spotlight immediately and completely;
- retain centered/staged photograph;
- retain offset planes;
- retain giant jersey number;
- retain strong team-color atmosphere;
- retain Spotlight typography;
- retain music/footer treatment;
- omit foreground player cutout;
- omit mask-derived rim light.

Fallback must look like an intentional premium Spotlight card, not an error state.

---

## 14. Conservative Quality Classification

Do not assume the framework supplies a perfect universal mask-confidence score.

Use conservative heuristics based on available signals such as:

- existence of meaningful person region;
- mask area relative to image;
- excessive boundary contact;
- face/person observations when available;
- mask fragmentation;
- isolated regions;
- dominant mask region relative to likely player bounds.

This must not become a custom machine-learning project.

When uncertain, degrade conservatively:

```text
excellent → usable
usable → fallback
```

Visible segmentation artifacts are worse than a restrained card.

---

## 15. Multiple People

Youth-sports photos commonly contain teammates, coaches, siblings, or spectators.

Attempt to associate the intended player with the expected focal/crop region and available face/person observations.

Existing player/profile crop information may be used where it helps identify the intended subject.

If one subject cannot be selected confidently:

**use fallback.**

Do not break out an entire group merely because segmentation found multiple people.

Manual subject-selection UI is not required for Spotlight v1 unless real-world Lab testing demonstrates a genuine need.

---

## 16. Mask Processing

Expected pipeline:

```text
raw segmentation mask
       ↓
small edge cleanup
       ↓
very subtle feather
       ↓
foreground composition
```

Do not aggressively sharpen mask edges.

Do not create a fuzzy halo.

If Vision includes equipment such as bats, gloves, helmets, or gear as part of the player region, preserve it. Do not attempt object-specific reconstruction/removal.

---

## 17. Breakout Envelope

Even excellent masks must be constrained to a fixed template-defined permitted area.

Conceptually:

```text
        upper breakout
      ┌────────────────┐
  ┌───┼──── PHOTO ─────┼───┐
  │   │                │   │
  │   │                │   │
  └───┼────────────────┼───┘
      │ lower breakout │
      └────────────────┘
```

Protected from foreground intrusion:

- team label;
- readable jersey number;
- critical player-name readability zone;
- core music metadata;
- footer.

Potentially allowed:

- above photo top;
- beyond photo sides;
- into transitional space above the name.

For Spotlight v1, keep the segmented player below the player-name text layer.

Any future overlap with the surname must be deliberately approved after visual Lab review.

---

## 18. Collision Priorities

Highest to lowest:

1. player / visible face
2. player name
3. original photo
4. song title
5. team name
6. readable jersey number
7. artist
8. segmented breakout extent
9. giant decorative number
10. waveform
11. offset planes
12. rim light
13. atmospheric effects

Footer remains protected in its fixed region.

The amount of breakout is disposable. If a foreground limb threatens important text, constrain the breakout.

---

## 19. Giant Jersey Number

The giant number is one of Spotlight's primary signatures.

It may become substantially larger than Broadcast's decorative number and extend beyond the photo frame.

With segmentation:

- number sits behind segmented player;
- player naturally occludes portions through layer ordering;
- no special AI/object reconstruction is needed.

Without segmentation:

- number remains integrated behind/around the staged photograph;
- fallback retains a dramatic composition.

Possible treatment:

- large translucent fill;
- restrained partial outline;
- subtle tonal gradient;
- dynamically derived team-color influence.

Exact size, position, clipping, outline/fill balance, and opacity remain Lab-tunable.

---

## 20. Readable Jersey Number

Keep a small readable number in the upper-right for family consistency.

Spotlight should make this simpler than Broadcast:

- neutral white/off-white number;
- small team-derived accent if useful;
- no broadcast-style open frame;
- no pill/badge.

If no jersey number exists, remove both readable and giant number treatments and number-only decoration.

Never invent `00`.

---

## 21. Team Label

Upper-left:

```text
P-WAY THUNDER
──────
```

Use:

- uppercase;
- modest tracking;
- restrained size;
- neutral light text;
- short team-derived accent rule.

If team name is absent, omit label/rule without redesigning the card.

---

## 22. Player Name

Spotlight should have the boldest name treatment of the three templates.

Initial direction:

```text
ELLIE
FISHER
```

Prefer centered or slightly-left-of-center placement beneath the hero.

- first name smaller/lighter;
- surname very large/heavy;
- surname may approach card width for short names;
- neutral white/off-white;
- system typography.

Exact centering/offset remains Lab-tunable.

### Long-name adaptation

1. normal size;
2. use full permitted width;
3. reduce font size;
4. use slightly condensed system width;
5. reduce tracking;
6. defined minimum size.

Never ellipsize the surname.

If only one name component exists, use it as the dominant name.

---

## 23. Optional Player/Name Overlap

The architecture may permit the segmented player to overlap a small portion of the upper surname region in the future.

For initial implementation:

**default this effect off.**

The player remains below critical name typography.

Whether overlap improves depth should be decided by viewing actual Lab renders, not prose.

---

## 24. Team-Color Philosophy

Spotlight has the largest team-color budget of the three templates, but team color should behave primarily as **studio lighting and atmosphere**.

Allowed:

- broad glow behind player/photo;
- mask-derived directional rim light;
- muted color in offset backdrop planes;
- giant-number influence;
- small functional accents.

The background remains predominantly charcoal.

Avoid large raw-color slabs.

---

## 25. Dynamic Spotlight Color Pipeline

Critical requirement:

**All Spotlight colors must be derived algorithmically from the arbitrary stored team color.**

Conceptually:

```text
rawTeamColor
      ↓
resolvedTeamColor
      ↓
├── displayAccent
├── atmosphericAccent
├── rimLightAccent
├── numberAccent
├── planeAccent
└── contrastAccent
```

No preset-specific branches.

Current Roll Call colors are ordinary test fixtures only.

Future unrestricted color-wheel selections must require no Spotlight redesign.

---

## 26. Color Roles

### `displayAccent`
For small readable/structural accents.

### `atmosphericAccent`
Broad heavily blurred team-color light field behind player/photo.

- darker than raw team color;
- reduced saturation for extreme inputs;
- low opacity.

### `rimLightAccent`
More luminous, cleaner derivative used for mask-derived directional edge light.

### `numberAccent`
Optimized for the giant translucent jersey number and adapted for photo/background contrast.

### `planeAccent`
Dark/muted derivative for offset photo-backdrop planes.

### `contrastAccent`
Derived light/dark companion used only where source hue cannot provide sufficient practical contrast.

---

## 27. Lighting Model

Initial conceptual lighting:

```text
Primary light
→ team-derived
→ upper-left or side

Secondary light
→ subtle neutral/cool-white
→ opposing side
```

This avoids a monochromatic color wash.

The team-derived source establishes identity; the neutral source provides shape and polish.

Exact source positions and intensity remain Lab-tunable.

---

## 28. Rim-Light Construction

Generate rim light from the segmentation mask.

Conceptually:

```text
player mask
    ↓
slight dilation
    ↓
blur
    ↓
attenuate original interior
    ↓
rimLightAccent tint
    ↓
directional opacity/bias mask
```

Do not create a uniform neon/sticker outline.

The rim should read as directional light:

- stronger on one side;
- selective around head/helmet/shoulder;
- weak or absent on opposing edges.

Quality behavior:

```text
excellent → normal Spotlight rim
usable    → reduced rim
fallback  → no mask-derived rim
```

Fallback retains broad atmospheric lighting.

---

## 29. Arbitrary Color Extremes

Stress-test:

- near black;
- near white;
- highly saturated yellow;
- cyan;
- magenta;
- deep navy;
- deep maroon;
- forest green;
- orange;
- purple;
- brown;
- gray;
- very low saturation;
- arbitrary random color-wheel values.

Inspect specifically:

- rim-light clipping;
- atmospheric glow;
- giant-number visibility;
- backdrop-plane visibility;
- small accent contrast.

Very pale colors must not become white glare. Very dark colors should be lifted enough to register. Extreme saturation should be moderated where necessary to behave like light.

All corrections are formula-driven.

---

## 30. Atmosphere

Prefer native deterministic rendering:

- broad blurred color fields;
- neutral secondary illumination;
- subtle vignette;
- extremely restrained grain.

Do not require bundled smoke assets initially.

Do not attempt to recreate generated concept-art haze literally.

Only add a reusable static texture later if actual Lab renders demonstrate a real need and it is deliberately approved.

---

## 31. Music Treatment

Spotlight should initially use a simpler music treatment than Broadcast because the hero already carries substantial visual complexity.

Preferred initial treatment:

```text
♪ Can't Back Down
  Demi Lovato, Alyson Stoner…        ▂▅▇▃▆
```

Initially omit the explicit `WALK-UP MUSIC` label.

The music note plus song title should provide sufficient meaning.

Whether the label needs to return is a Lab-review decision.

### Song
- neutral white/off-white;
- semibold/bold;
- maximum two lines.

### Artist
- muted gray;
- maximum two lines;
- ellipsis permitted.

### Waveform
- small;
- deterministic;
- team-derived accent;
- decorative rather than actual audio waveform.

No album art or playback controls.

---

## 32. No-Music State

Remove:

- note;
- song title;
- artist;
- waveform.

Do not show placeholder copy.

Negative space should remain intentional.

---

## 33. Footer

Use the same quiet family branding:

```text
[Roll Call icon] Made with Roll Call
```

- actual app icon;
- `Made with` muted;
- `Roll Call` slightly brighter/semibold;
- fixed protected region;
- no slogan;
- no QR code;
- no website;
- no App Store badge.

Spotlight's visual budget belongs to the player.

---

## 34. Missing Data

### No number
Remove both jersey-number treatments and number-only decoration.

### No team name
Remove team label and associated rule.

### No team color
Use Roll Call's normal validated fallback accent.

### No music
Use no-music state.

### No photo
Do not generate Spotlight. Do not substitute a generic silhouette/avatar.

### Missing first or last name
Use the available component as dominant name.

Never invent data to preserve the layout.

---

## 35. Loading Behavior

When Spotlight is selected:

1. render fallback Spotlight immediately;
2. begin segmentation asynchronously;
3. upgrade preview to usable/excellent if analysis succeeds;
4. optionally use a subtle transition if visually appropriate.

Do not block on segmentation and do not make the user watch a segmentation spinner.

The user should perceive an immediate card that may become subtly richer.

---

## 36. Export Behavior

Prefer the best segmentation result already available.

If analysis is still underway, implementation may briefly await it when completion is imminent, but sharing must never hang indefinitely.

A valid fallback Spotlight is always an acceptable export.

Exact timeout/concurrency mechanics may be chosen during implementation while preserving this UX rule.

---

## 37. Segmentation Analysis and Cache

Do not rerun Vision on SwiftUI redraws.

Conceptual cache key:

```text
photo identity
+ crop/source transform version
+ orientation-relevant state
+ segmentation algorithm version
```

Invalidate when:

- source photo changes;
- crop changes;
- orientation/source geometry changes;
- segmentation algorithm/version changes.

Do **not** invalidate because of:

- name;
- team name;
- jersey number;
- song;
- team color;
- lighting tuning;
- typography tuning.

Potential cached result:

```swift
SpotlightSegmentationResult {
    mask
    quality
    detectedPersonBounds
    detectedFaceBounds
    selectedSubjectBounds
}
```

Architecture should permit persistence across launches if later worthwhile, but persistent caching is not required to prove v1.

---

## 38. Segmentation Performance

Vision analysis must not block the main UI thread.

Behavioral targets:

- fallback appears immediately;
- cached Spotlight feels immediate;
- changing arbitrary team color remains interactive;
- editing metadata does not retrigger segmentation;
- export reuses analysis;
- Lab exposes cache hit/miss information for debugging.

No hard millisecond budget is specified until real-device profiling.

---

## 39. Template Versioning

Give renderers explicit internal template versions from the beginning.

Conceptually:

```swift
PlayerCardTemplate.clean(version: 2)
PlayerCardTemplate.broadcast(version: 1)
PlayerCardTemplate.spotlight(version: 1)
```

Exact API is implementation-defined.

Versioning should support:

- snapshot evolution;
- cache invalidation;
- deliberate visual-output changes;
- future migration behavior.

---

## 40. Player Card Lab

The shared template-agnostic Lab must support:

```text
[ Impact ] [ Broadcast ] [ Testing ]
```

The same fixture/player data should switch among templates without changing canvas dimensions.

Spotlight visual constants should remain intentionally tunable until the user reviews actual renders.

---

## 41. Spotlight Lab — Composition Controls

Development-only controls:

- photo width;
- photo height;
- photo Y;
- photo corner radius;
- backdrop-plane X/Y offsets;
- backdrop-plane opacity;
- giant-number X/Y;
- giant-number size;
- giant-number opacity;
- giant-number outline/fill balance;
- name X/Y;
- first-name size;
- surname size.

After approval, selected values become production tokens.

---

## 42. Spotlight Lab — Lighting Controls

Development-only controls:

- atmosphere strength;
- atmosphere radius;
- primary-light X/Y;
- neutral secondary-light strength;
- rim-light width;
- rim-light blur;
- rim-light opacity;
- rim-light direction/bias.

---

## 43. Spotlight Lab — Breakout Controls

Development-only controls:

- breakout top;
- breakout left;
- breakout right;
- breakout bottom;
- conservative-breakout multiplier;
- mask feather.

Breakout remains constrained by protected zones regardless of tuning.

---

## 44. Segmentation Diagnostics

Development UI:

```text
Segmentation mode:
[ Auto ] [ Force Excellent ] [ Force Usable ] [ Force Fallback ]
```

Debug overlays:

- raw mask;
- processed mask;
- breakout envelope;
- protected zones;
- face bounds;
- person bounds;
- selected subject bounds;
- rim-light mask.

Forced states exercise renderer presentation behavior; they must not pretend to create a better real segmentation mask.

---

## 45. Compare Segmentation States

Add a development action:

```text
[ Compare Segmentation States ]
```

Generate the same Spotlight fixture side-by-side as:

```text
Excellent | Usable | Fallback
```

This is a key design-review surface.

It should make clear:

1. whether fallback still looks like a premium Spotlight card;
2. whether usable mode is conservative enough;
3. what value excellent segmentation actually adds.

---

## 46. Required Spotlight Photo Fixtures

Include deliberately difficult cases:

- clean portrait;
- full-body player;
- close-up face/shoulders;
- horizontal-ish crop;
- vertical crop;
- subject left;
- subject right;
- subject centered;
- subject near top;
- subject near bottom;
- helmet;
- long hair;
- bat crossing body;
- glove;
- catcher's gear;
- soccer ball near body;
- busy dugout;
- grass;
- chain-link fence;
- crowd;
- dark uniform/dark background;
- bright uniform/bright background;
- backlit player;
- low-contrast photo;
- partially obscured player;
- multiple teammates;
- player plus coach.

Use representative project test photos where appropriate rather than relying on one unusually easy image.

---

## 47. Shared Template Contact Sheet

Generate:

```text
              CLEAN      BROADCAST      SPOTLIGHT

Normal        [card]       [card]         [card]
Long Name     [card]       [card]         [card]
No Music      [card]       [card]         [card]
Bright Photo  [card]       [card]         [card]
Dark Photo    [card]       [card]         [card]
Wild Color    [card]       [card]         [card]
```

For Spotlight, use the best real segmentation result in the normal template-comparison sheet.

Use the separate segmentation-state comparison for diagnostics.

---

## 48. Snapshot / Visual Regression Strategy

Do not treat Apple's exact Vision mask pixels as the visual contract.

Renderer snapshots should inject controlled fixtures:

- known excellent mask;
- known imperfect/usable mask;
- no mask.

Protect:

- full breakout;
- conservative breakout;
- fallback;
- giant number behind subject;
- directional rim;
- no-number state;
- no-music state;
- long surname;
- long song;
- bright arbitrary team color;
- dark arbitrary team color;
- subject-left;
- subject-right;
- protected text zones;
- footer placement;
- fallback visual identity;
- preview/export parity.

Test actual Vision integration separately.

This prevents framework-level segmentation changes from invalidating unrelated renderer snapshots.

---

## 49. Shared Renderer Architecture

Conceptual family:

```text
PlayerCardModel

PlayerCardRenderer
├── CleanPlayerCard
├── BroadcastPlayerCard
└── SpotlightPlayerCard

PlayerCardLab
├── CardFixtureLibrary
├── CardContactSheetGenerator
├── CardExportService
└── CardDebugOverlays

TeamColorDerivation
├── CleanCardColorResolver
├── BroadcastCardColorResolver
└── SpotlightCardColorResolver

SpotlightAnalysisService
├── Person segmentation
├── Subject selection
├── Quality classification
├── Mask processing
└── Cache
```

This expresses separation of responsibilities, not a requirement to create unnecessary protocol/abstraction complexity.

Codex should choose idiomatic Swift/SwiftUI implementation details.

---

## 50. Preview / Export Parity

The same actual production renderer must power:

- in-app preview;
- Player Card Lab;
- snapshot tests;
- exported image.

Do not create a simplified Lab mockup.

---

## 51. Determinism

Given identical:

- player data;
- source photo;
- crop;
- template version;
- segmentation result;
- raw team color;

Spotlight must produce the same composition.

No true randomness in:

- waveform;
- lighting placement;
- number placement;
- typography adaptation;
- geometry;
- palette derivation.

---

## 52. Privacy

All player-photo processing and segmentation remains on-device.

Spotlight must not upload youth/player photographs to an external AI or image-processing service.

No network dependency is required to create the card.

---

## 53. Explicit Exclusions

Spotlight does **not** use:

- generative AI imagery;
- synthetic player pixels;
- remote segmentation/image processing;
- invented stadium backgrounds;
- flames;
- lightning;
- sparks;
- particle explosions;
- mandatory smoke textures;
- fake statistics;
- fake player positions;
- fake TV/network branding;
- fake `LIVE` indicators;
- motivational slogans;
- filler copy;
- fake autographs;
- aggressive beauty/face processing;
- manually painted neon subject outlines;
- mandatory segmentation;
- user-facing segmentation quality controls;
- hardcoded team-color variants;
- nondeterministic layouts.

The drama comes from the real player photograph, depth, scale, typography, lighting, and composition.

---

## 54. Deliberately Provisional Visual Values

These should remain tunable until reviewed visually in the Player Card Lab:

- exact hero-photo width/height;
- photo vertical position;
- photo corner radius;
- backdrop-plane offsets/visibility;
- giant-number size/position;
- giant-number clipping;
- giant-number fill/outline balance;
- atmospheric-light strength;
- light-source positions;
- name centered vs. slightly left;
- exact name sizing;
- player/name overlap;
- breakout distances;
- conservative-breakout multiplier;
- rim-light width/intensity;
- music-label omission vs. restoration.

The implementation must make these cheap to tune without architectural rewrites or repeated production builds.

---

## 55. Acceptance Criteria

Spotlight is ready for production integration when:

1. Fallback Testing clearly differs from both Impact and Broadcast.
2. Fallback looks like a finished premium card without segmentation.
3. Enhanced Spotlight adds obvious depth without appearing gimmicky.
4. Original photograph remains recognizable as part of the composition.
5. Foreground player aligns perfectly with the underlying photo.
6. Excellent segmentation permits convincing controlled breakout.
7. Usable segmentation is visibly more conservative.
8. Poor/ambiguous segmentation automatically produces a good fallback.
9. Multiple-person ambiguity does not produce obviously wrong group cutouts.
10. Giant number creates depth and yields to player/name readability.
11. Rim light reads as directional illumination rather than a sticker outline.
12. Arbitrary color-wheel values produce coherent atmosphere and contrast.
13. Long names remain readable without ellipsis.
14. No-number and no-music states look intentional.
15. Protected text/footer zones remain safe from breakout.
16. Spotlight appears immediately while analysis runs asynchronously.
17. Cached Spotlight feels immediate.
18. Metadata/team-color changes do not unnecessarily rerun Vision.
19. Lab can force and compare Excellent, Usable, and Fallback states.
20. Shared template contact sheets make Impact/Broadcast/Testing differences obvious.
21. Preview and export match.
22. Representative snapshots and Vision integration tests pass.
23. No network, generative AI, or mandatory segmentation is required.
24. Actual Lab review confirms the provisional visual constants.

---

## 56. Final Visual Test

Before production integration, show the same representative player as:

```text
Clean | Broadcast | Spotlight Fallback | Spotlight Enhanced
```

The desired result:

- all four are immediately distinguishable;
- none looks like an error/degraded version;
- Spotlight Enhanced is meaningfully more dramatic than Spotlight Fallback;
- Spotlight Fallback still deserves the Spotlight name;
- the actual player—not added effects—remains the visual focus.

If those conditions are not met, continue tuning in the Lab before integrating the production share flow.
