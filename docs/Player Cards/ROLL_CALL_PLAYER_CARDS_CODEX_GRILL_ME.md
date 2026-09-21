# `/grill-me` Prompt — Roll Call Player Cards: Three-Template Lab + Renderer Implementation

> Display naming update: the production/default card is **Spotlight**, the former Spotlight Lab card is **Testing**, Clean v2 is **Impact**, and Broadcast is unchanged. The implementation identifiers in this historical prompt remain unchanged where they describe renderer or Vision-analysis internals.

You are working in the existing Roll Call iOS project.

Before making implementation changes, **inspect the repository and read the existing Player Card design specs in full** from:

`/Users/jkfisher/Documents/Coding/Projects/Roll Call/docs/Player Cards`

Treat those documents as the product/design source of truth for the three templates:

- Impact
- Broadcast
- Testing

Do **not** duplicate or reinterpret those specs from memory. Read the files themselves before planning.

This is a `/grill-me` task. Your job is to:
1. inspect the existing implementation and repository architecture;
2. identify genuine architectural, technical, compatibility, testing, or scope decisions that still need owner input;
3. ask only questions that materially affect the implementation;
4. challenge assumptions where warranted;
5. avoid reopening product/visual decisions already explicitly settled in the specs;
6. after questions are resolved, produce and execute a disciplined implementation plan.

---

# Objective

Implement the new three-template Player Card system in a way that allows rapid visual iteration **before** replacing the current production sharing flow.

The immediate target is a development-only **Player Card Lab** that renders the real production card views for:

- Impact
- Broadcast
- Testing

The Lab must make it possible to compare templates, stress-test edge cases, tune provisional visual constants, inspect Spotlight segmentation behavior, export representative cards, and generate contact sheets without requiring a new full app build for every visual change.

The implementation should be production-quality in architecture, but **visual constants explicitly marked provisional in the specs must remain easy to tune until the owner reviews actual rendered cards**.

Do not prematurely lock them into opaque abstractions or scattered literals.

---

# Critical sequencing

Implement in this order unless repository inspection exposes a strong reason not to:

1. Inspect existing player-card/share implementation.
2. Read all three design specs in `/docs/Player Cards`.
3. Identify reusable existing code and migration constraints.
4. Build shared Player Card model/rendering infrastructure.
5. Build the development-only Player Card Lab.
6. Implement Clean.
7. Implement Broadcast.
8. Implement Spotlight fallback composition.
9. Implement Spotlight segmentation analysis/enhancement.
10. Add fixtures, diagnostic controls, exports, contact sheets, and snapshot coverage.
11. Validate preview/export parity.
12. Present the Lab for owner review.
13. **Do not replace the current production card/share experience until explicitly approved after visual review.**

The Lab comes first as the design-validation surface.

---

# Repository-first requirement

Before proposing architecture, inspect:

- current Player model/data model;
- current player-photo storage and crop behavior;
- current Player Card/share implementation;
- existing image rendering/export pipeline;
- existing use of SwiftUI `ImageRenderer`, Core Graphics, Vision, Core Image, or related utilities;
- any existing debug/developer menus;
- test targets and snapshot-test infrastructure;
- concurrency/caching conventions;
- app architecture and dependency boundaries;
- current team-color representation;
- current walk-up music metadata representation;
- app icon asset access for card footer branding.

Prefer adapting existing good infrastructure over introducing parallel systems.

Do not introduce third-party packages unless there is a compelling reason and owner approval.

---

# Source-of-truth rule

The design specs in `/docs/Player Cards` control:

- hierarchy;
- template identity;
- visual exclusions;
- arbitrary team-color behavior;
- fallback behavior;
- content edge cases;
- canonical output size;
- Lab requirements;
- snapshot/contact-sheet expectations;
- Spotlight segmentation principles.

If the codebase conflicts with a spec, surface the conflict.

If a spec leaves a technical detail open, use repository conventions and sound engineering judgment.

Do not ask the owner to reconfirm already-settled design decisions.

---

# Shared architecture

Aim for a clean shared family resembling the following concepts, but adapt names/shape to existing project architecture rather than blindly forcing this exact hierarchy:

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

This is a responsibility map, not a mandate to create unnecessary protocols or abstraction layers.

Prefer simple, idiomatic Swift/SwiftUI.

---

# Canonical renderer requirements

All templates share:

- canonical artwork size: **1080 × 1350**
- aspect ratio: **4:5**
- PNG
- sRGB
- deterministic rendering
- on-device processing
- full-quality player photo source
- fixed graphic coordinate system independent of device UI size

The **same real production renderer** must power:

- Lab preview;
- exported card;
- snapshot tests;
- eventual production sharing.

Do not build a simplified visual mockup exclusively for the Lab.

---

# Player Card Lab

Create a development-only Lab available through the most natural existing DEBUG-only entry point.

At minimum support:

```text
[ Impact ] [ Broadcast ] [ Testing ]
```

with the same player fixture/data switchable among templates.

The Lab should allow rapid use through Xcode previews where practical and also be accessible on a real device in DEBUG builds.

The owner should not need to navigate the normal production flow repeatedly just to judge visual changes.

---

# Fixtures

Build a reusable fixture library that covers at least:

- normal representative player;
- long first/last name;
- long team name;
- long song title;
- long artist metadata;
- no jersey number;
- no music;
- bright photo;
- dark photo;
- busy photo;
- close-up crop;
- full-body crop;
- subject left;
- subject right;
- subject centered;
- three-digit number;
- arbitrary team-color extremes.

For Spotlight also include difficult segmentation cases described in its spec, including multiple people, helmets, long hair, equipment, partial occlusion, difficult backgrounds, and ambiguous subject selection.

Prefer real representative development/test assets already available in the repo when appropriate.

Do not depend solely on one easy Ellie photo.

---

# Arbitrary team-color requirement

This is critical.

Current preset team colors must **not** become hardcoded rendering branches.

Future Roll Call functionality is intended to allow users to choose essentially any team color from a color wheel.

All three templates must derive their visual palettes algorithmically from the stored color.

The template-specific color resolvers may share low-level color math, but Impact, Broadcast, and Testing need different output roles because they use color differently.

Test extreme values such as:

- near-black;
- near-white;
- saturated red;
- green;
- blue;
- yellow;
- cyan;
- magenta;
- orange;
- purple;
- brown;
- gray;
- low saturation;
- high saturation;
- arbitrary off-preset color-wheel values.

The Lab must include a DEBUG-only live arbitrary color picker so actual production rendering can be inspected across the color space without changing app presets.

Changing team color must not retrigger Spotlight Vision analysis.

---

# Provisional design controls

The specs deliberately leave some exact visual constants provisional until the owner can see the actual renderer.

Expose sensible DEBUG-only Lab controls for those values instead of burying them.

Centralize tunable values into template-specific layout/style token structures.

Do not scatter magic numbers throughout SwiftUI view bodies.

Include Reset-to-Spec/default actions.

Once visual review is complete, these controls may be collapsed into fixed production tokens.

---

# Clean implementation

Implement Clean according to its spec.

Key architectural expectations include:

- no segmentation dependency;
- photo-first layout;
- user-selected crop remains authoritative;
- soft photo/lower-field transition;
- dynamic team-color edge illumination;
- large subtle decorative jersey number;
- integrated music region rather than nested UI panel;
- quiet `Made with Roll Call` footer;
- no invented filler copy;
- deterministic decorative waveform;
- graceful no-team/no-number/no-music behavior.

Use Clean as the first proof that:

- canonical rendering works;
- fixtures work;
- Lab/export parity works;
- dynamic arbitrary-color derivation works;
- contact-sheet generation works.

---

# Broadcast implementation

Implement Broadcast according to its spec.

Key differences from Clean must remain obvious:

- deliberate shallow diagonal geometry;
- structured lower-third rather than soft fade;
- stronger visible jersey-number composition;
- stronger but disciplined graphic use of dynamically derived team color;
- broadcast-information treatment for music;
- no fake TV/network elements;
- no fake stats;
- no UI-card/pill aesthetic.

Centralize the shared broadcast angle and geometric tokens.

Broadcast must be visibly more assertive than Clean, not merely the same renderer with diagonal lines added.

---

# Spotlight implementation

Implement Spotlight in two distinct layers of capability.

## 1. Spotlight fallback first

Before Vision work, build a complete fallback Testing card that is already visually distinct from Impact and Broadcast through:

- staged/centered hero photo;
- offset backdrop planes;
- much larger giant jersey number;
- stronger studio-like team-color atmosphere;
- bold Spotlight name treatment;
- simplified music treatment;
- fixed footer.

Fallback must look like a finished premium design.

## 2. Segmentation enhancement

Then add on-device Vision/person-segmentation enhancement.

Internal presentation states:

```text
excellent
usable
fallback
```

These are not user-facing.

The foreground segmented player must use **pixels from the same source photograph**, aligned using the same shared photo transform as the underlying rectangular photo.

Never independently crop or scale the extracted foreground.

Segmentation may enable:

- controlled breakout beyond photo boundaries;
- giant number behind player;
- directional team-color rim light;
- additional perceived depth.

It must never become required to create Spotlight.

---

# Spotlight segmentation rules

Implement conservatively.

If subject selection or mask quality is uncertain:

```text
excellent → usable
usable → fallback
```

Prefer a restrained card over visible segmentation artifacts.

Multiple-person ambiguity should fall back rather than extracting an obviously wrong group.

Define explicit protected zones and breakout envelopes so segmented limbs/equipment cannot cover critical content.

For initial production behavior, keep the foreground player below critical player-name typography.

Do not implement user-facing segmentation-quality controls.

---

# Spotlight async behavior

When Spotlight is selected:

1. show fallback immediately;
2. run segmentation asynchronously;
3. upgrade to usable/excellent when ready;
4. never block normal preview behind a segmentation spinner.

Cache analysis so normal SwiftUI redraws do not rerun Vision.

Cache invalidation should be tied to source/crop/analysis-version geometry, not player metadata or team color.

Expose cache hit/miss status in DEBUG diagnostics.

---

# Spotlight debug tools

In the Lab provide:

```text
Segmentation state:
[ Auto ] [ Force Excellent ] [ Force Usable ] [ Force Fallback ]
```

and useful overlays such as:

- raw mask;
- processed mask;
- breakout envelope;
- protected zones;
- detected face bounds;
- detected person bounds;
- selected-subject bounds;
- rim-light mask.

Forced states are for presentation testing; do not fabricate improved real masks.

Also implement:

```text
[ Compare Segmentation States ]
```

to render the same fixture as:

```text
Excellent | Usable | Fallback
```

side-by-side.

This is an important owner-review tool.

---

# Contact sheets

Support at least:

## Template comparison

```text
              CLEAN      BROADCAST      SPOTLIGHT

Normal        [card]       [card]         [card]
Long Name     [card]       [card]         [card]
No Music      [card]       [card]         [card]
Bright Photo  [card]       [card]         [card]
Dark Photo    [card]       [card]         [card]
Wild Color    [card]       [card]         [card]
```

Use the same fixture data per row.

## Spotlight segmentation comparison

```text
Excellent | Usable | Fallback
```

for representative Spotlight fixtures.

Provide an easy development action to generate/export these.

---

# Snapshot and test strategy

Add regression coverage appropriate to the repository's existing test setup.

Prefer:

- deterministic fixture data;
- controlled injected Spotlight masks for renderer snapshots;
- separate integration tests for actual Vision behavior.

Do **not** make Apple's exact segmentation pixels the visual snapshot contract.

Cover at minimum:

- canonical canvas dimensions;
- Clean core layout;
- Broadcast angle/lower-third geometry;
- Spotlight fallback;
- Spotlight excellent breakout;
- Spotlight usable/conservative breakout;
- no-number state;
- no-music state;
- long surname;
- long music metadata;
- bright/dark arbitrary colors;
- footer placement;
- waveform containment;
- protected Spotlight text zones;
- preview/export parity.

Add unit tests for color derivation where useful.

---

# Template versioning

Introduce an explicit internal concept of card-template versioning if the existing architecture does not already have one.

Example concept only:

```swift
clean(version: 2)
broadcast(version: 1)
spotlight(version: 1)
```

Use versioning where useful for:

- snapshot evolution;
- renderer changes;
- cache invalidation;
- deliberate output-format evolution.

Do not overengineer migration behavior that current product requirements do not need.

---

# Visual exclusions

Respect the exclusions in the specs.

Across these designs, avoid adding things such as:

- fake LIVE indicators;
- fake network logos;
- fake scoreboards;
- fake player statistics;
- fake player positions;
- filler technical microtext;
- generic motivational slogans;
- fake autographs;
- invented stadiums;
- generative backgrounds;
- flames/lightning/sparks;
- excessive sports-poster particles;
- heavy beauty filters;
- playback controls;
- arbitrary rounded UI panels;
- hardcoded color variants.

Do not add elements merely because they look "sporty."

---

# Production-flow boundary

This is important:

**Do not replace or remove the current production Player Card/share experience as part of the first implementation pass.**

Build the new system and Lab alongside it.

The owner needs to see real Impact/Broadcast/Testing renders first and tune them interactively.

After visual approval, production integration becomes a separate explicit step.

Avoid creating a risky migration before the designs are validated.

---

# Code quality expectations

- Respect existing Roll Call architecture and appearance rules.
- Keep rendering code deterministic.
- Avoid unnecessary third-party dependencies.
- Keep Vision work off the main actor/thread where appropriate.
- Avoid rerunning expensive image analysis.
- Prefer composable SwiftUI/Core Graphics/Core Image/Vision primitives over generated static artwork.
- Use static assets only when the spec genuinely calls for them.
- Keep template-specific logic separate enough that changing Spotlight does not destabilize Clean.
- Share primitives where useful, not merely for abstraction purity.
- Add comments only where the math/coordinate-space/segmentation behavior is non-obvious.
- Preserve existing app behavior outside this feature.

---

# Build/test policy

Follow this repository's existing `AGENTS.md` and project-specific build/test instructions.

Use the repo's established build-number policy and report the old/new build number if this work produces a build under the project's rules.

Run the most relevant automated tests during implementation.

Do not report success solely because code compiles. Exercise the Lab and generated outputs sufficiently to verify that the rendering system actually functions.

---

# What `/grill-me` should ask about

Ask questions only where repository inspection reveals a real unresolved owner decision, such as:

- compatibility/deployment-target implications of a required Apple framework/API;
- migration implications of the current player photo/crop model;
- whether an existing image source is insufficient for full-quality card export;
- material architectural conflicts with existing share/export code;
- test-fixture licensing/privacy issues;
- a choice between meaningfully different production integration strategies;
- a conflict between a design spec and current product behavior.

Do **not** ask questions like:

- whether Clean should use a soft fade;
- whether Broadcast should use diagonal geometry;
- whether Spotlight should fall back without segmentation;
- whether arbitrary future team colors should be supported;
- whether Spotlight should use fake stadiums;
- whether the footer should say `Made with Roll Call`.

Those are already decided.

When several technically valid implementation options exist and owner input genuinely matters, give **2–3 concrete options with your recommendation and tradeoffs**.

---

# Expected first response

Do not begin coding blindly.

First:

1. inspect the repo;
2. read all three Player Card specs;
3. inspect the current player-card/photo/share architecture;
4. summarize the relevant current state;
5. identify any actual conflicts or migration concerns;
6. ask the minimum set of `/grill-me` questions needed before implementation.

If no meaningful owner decisions remain, say so and present the implementation plan rather than inventing questions.

The goal is to remove ambiguity **without re-litigating settled design work**.

---

# Final implementation review deliverables

Before asking for visual approval, provide:

1. summary of architecture implemented;
2. files/components added or materially changed;
3. how to open the Player Card Lab;
4. how to use the template selector;
5. how to change fixtures/team colors;
6. how to use the provisional visual controls;
7. how to force Spotlight segmentation states;
8. how to show Spotlight debug overlays;
9. how to generate/export a single card;
10. how to generate template comparison contact sheets;
11. how to generate Spotlight segmentation-state comparisons;
12. tests run and results;
13. any known rendering/segmentation issues;
14. any provisional values that especially need owner visual judgment.

Then stop and request visual review.

**Do not proceed to replacing the current production share flow until explicitly approved.**
