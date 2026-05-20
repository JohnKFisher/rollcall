# VISUAL LANGUAGE SYSTEM

Status:
- Planning document only
- No implementation is authorized by this document
- Any future implementation still requires a separate prompt/approval

Purpose:
- define a concrete visual language system for `Roll Call`
- keep the app fast, simple, game-day friendly, reliable, and low-friction
- make `Game Day` feel like the destination without turning the rest of the app into a dashboard
- preserve protected behavior zones while giving future UI work a clear design target

Source context:
- `historical/ux/pre-redesign-baseline/`
- `historical/ux/redesign-rationale/TARGET_UI_DIRECTION.md`
- `historical/ideas/roll_call_dev_notes.md`
- explicit interview decisions captured in this planning session

Protected-zone reminder:
- This document may describe approved product direction, but it does not authorize code changes by itself.
- Visual ideas that would affect `CuePlaybackEngine`, Apple Music flows, trim logic, persistence, `.rollcall` import/export, `PlayerEditorSheet` behavior, queue/playback behavior, or lineup semantics must still be handled carefully during implementation.

## 1. Design Principles

1. One primary thing per screen.
2. Never let visual energy outrun real usefulness.
3. Prefer fewer visible statuses, not more.
4. `Game Day` is the destination; the rest of the app supports it.
5. Preserve standard iOS behavior unless there is a strong reason to deviate.
6. Stay liquid-glass compliant by default, except where contrast or sunny-day readability would suffer.
7. Accessibility, outdoor readability, and tap confidence beat drama.
8. Prefer smart defaults and system rules over user-facing appearance controls.
9. Keep setup/admin screens calm and operational.
10. Let `Game Day` feel special through hierarchy and execution, not through gimmicks.

## 2. App Personality

Base personality:
- calm
- professional
- low-friction
- confident
- practical

Allowed energy:
- setup/admin screens: professional first, lightly polished
- `Game Day`: roughly `60/40` professional to sports energy
- `Clips`: same family as `Game Day`, but clearly calmer and more utility-like

What the app should never become:
- a media editor
- a power-user dashboard
- a sports-themed gimmick app
- a settings-heavy customization product

## 3. Color System

### Core palette direction

Base direction:
- bright, calm support screens
- dark, contrast-first live-side screens
- semantic colors remain independent from brand/team colors

Core accent family:
- warm athletic amber/orange outside team-specific live identity

Important hierarchy:
1. semantic state colors
2. team-derived accent on `Game Day`
3. core app accent on the broader app

### Semantic color roles

Define semantic roles, not final hex values:
- `accent`
- `live`
- `ready`
- `warning`
- `destructive`
- `disabled`
- `neutral-surface`
- `neutral-structure`

Rules:
- `warning` must not be confused with the warm app accent
- `live` must be stronger than `ready`
- `disabled` must be subdued but still readable
- no meaning may depend on color alone

### Team color usage

Team colors must be:
- derived
- protected
- contrast-checked
- subordinate to semantics

Rules:
- use one dominant derived team accent on neutral structure
- do not force literal raw team colors into UI if they hurt contrast or cohesion
- if a team has two strong colors, only one should usually lead the UI
- black usually behaves as structure, not as a feature accent

Usage by area:
- setup/admin tabs: subtle team accent only
- `Game Day`: moderate team presence
- `Clips`: modest team presence, less than `Game Day`

## 4. Typography Hierarchy

Typography feel:
- native but bolder
- no novelty font
- no faux-scoreboard gimmick type

Use a simple system hierarchy:
- `screen title`
- `section title`
- `card title`
- `primary identity`
- `body`
- `helper text`
- `chip/status label`

Rules:
- setup/admin tabs stay close to standard iOS text treatment
- `Game Day` gets stronger weight, larger identity emphasis, and firmer number treatment
- player names must outrank decorative text
- sports energy should come from weight and hierarchy, not a custom typeface

## 5. Spacing and Density Rules

Global density rule:
- balanced by default, roomy where it matters

Screen density targets:
- `Game Day`: low density, big targets, strong separation
- `Clips`: slightly denser than `Game Day`, still live-side
- `Readiness`: medium density with grouped operational cards
- `Players` / `Teams`: medium density, efficient but readable
- `Settings`: quiet grouped density, closest to standard iOS
- `PlayerEditorSheet`: medium density, chunked carefully, no visual crowding

Spacing tiers:
- `tight`: metadata, chips, compact inline status
- `standard`: rows, grouped actions, normal card internals
- `large`: section separation and major visual breaks

Rules:
- do not compress a screen into dashboard density
- if space gets tight on `Game Day`, reduce hero drama before reducing utility

## 6. Card Styles

Shape language:
- moderately rounded rectangular
- mild classic-Mac roundrect feel
- no heavy capsule overuse
- no sharp aggressive tiles as the default language

Card families:
- `utility cards`
- `status cards`
- `identity rows/cards`
- `live cards`

Rules:
- setup/admin cards should feel lightly inset and native
- `Readiness` can use stronger grouped card treatment
- `Game Day` live cards should feel firmer, darker, and more contrast-first
- `Clips` should share the live-side family but with simpler layout and lower intensity

## 7. Button Styles

Button philosophy:
- standard iOS foundation with a clearer Roll Call hierarchy

Shared button families:
- `primary`
- `secondary`
- `quiet`
- `destructive`
- `live-control`

Rules:
- outside `Game Day`, keep buttons mostly native in behavior and scale
- destructive actions must remain literal and unmistakable
- do not spread hero-button treatment across setup screens
- `Game Day` live controls may feel firmer and more tile-like than the rest of the app

## 8. Status Chip Language

Tone:
- plainspoken
- directive
- calm
- non-technical

Examples of desired tone:
- `Apple Music access needed`
- `3 players still need a song`
- `No team selected`
- `Custom intro missing file`

Avoid:
- developer-console phrasing
- vague cheerful filler
- softened warning language that hides urgency

Status state intent:
- `live`: strongest treatment
- `ready`: calm and confident
- `warning`: clear and noticeable, but not louder than `live`
- `disabled`: quiet, low-energy, unmistakably inactive

Status styling rule:
- text first
- color second
- shape/supporting contrast third

## 9. Screen Layout Patterns

### Top-level tab order

Approved navigation order for planning:
1. `Game Day`
2. `Clips`
3. `Players`
4. `Teams`
5. `Readiness`
6. `Settings`

Reasoning:
- live-use cluster first
- setup cluster second
- operational/admin surfaces last

### Launch behavior direction

Approved for planning:
- tab order and launch destination do not have to be the same
- launch should be conditional
- launch into `Game Day` when there is:
  - a selected team
  - players on the roster
  - at least one genuinely playable player
- otherwise fall back to `Players`

Note:
- This is a product/navigation direction recorded in the plan, not an implementation authorization by itself.

### Team banner

Persistent team banner placement:
- `Game Day`
- `Clips`
- `Players`
- `Teams`
- `Readiness`
- not `Settings`

Banner rules:
- read-only
- stable height
- very thin utility-strip feel
- mild roundrect treatment
- near-global consistency
- remains visible even when no team is selected

Banner content rules:
- team name
- subtle derived team identity
- one compact secondary status slot

Secondary slot priority:
- show `Warnings` when needed
- otherwise show lighter context like player count / present-today count

No-team state:
- keep banner visible
- show `No Team Selected`
- optionally use a subdued prompt like `Choose or create a team`

Live-side banner rule:
- same structure everywhere
- slightly richer contrast/material treatment on `Game Day` and `Clips`

## 10. Game Day Readability Rules

`Game Day` is the core live-use surface and may break from the rest of the app more than any other screen.

### Overall feel

`Game Day` should be:
- darker
- contrast-first
- special
- obviously live
- still recognizably iOS

It should not be:
- chrome-heavy
- gimmicky
- dashboard-dense
- jumbotron-themed

### Top-of-screen stack

Approved stack:
1. team banner
2. warning strip when needed
3. `Now Batting / Next Batter` hero area
4. control row
5. quieter fallback player grid

### Live hero hierarchy

Primary live hierarchy:
1. current batter identity
2. live/playing state
3. next batter
4. controls
5. fallback player grid

Current player rules:
- current player name must win if there is tension
- current player photo may be prominent
- current player photo can be a larger hero image area
- full player name should stay in its own strong text area, not rely on text-over-photo
- a small over-photo element is acceptable if it does not harm contrast

Next batter rules:
- substantial secondary card
- clearly subordinate to `Now Batting`
- must show calm/clear operational state like `Ready`, `Preparing`, or `Needs Attention`

### Live controls

Control placement:
- dedicated row below the hero cards

Playback interaction direction:
- no separate stop button
- the same cue button should stop playback on re-tap
- `playing` state must be visually obvious enough to prevent panic double-taps during short stutters

Playing-state expression:
- strongest signal lives in the hero area
- echo active state in the main cue button
- optionally echo it in the active fallback tile
- do not make the whole screen shout at once

### Warning strip

Rules:
- compact
- top-adjacent to the live hero
- only the most live-relevant issues
- plainspoken
- not a full readiness dump

### Fallback player grid

Fallback grid direction:
- clearly secondary to the hero
- still easy to hit
- likely `3-across` by default
- `4-across` only if real-device readability and tap confidence remain strong

Tile rules:
- name first, minimal extras
- first name by default in compact grid
- promote more text when needed for ambiguity
- one strong secondary cue only

Secondary cue priority:
1. `playing`
2. `next`
3. serious missing-usefulness warning
4. otherwise no extra cue

### Above-the-fold rule

Target for a normal iPhone:
- banner
- warning strip when needed
- full live hero
- control row
- at least a visible slice of the fallback grid
- target more than one fallback row if the composition allows it

If space gets tight:
- reduce hero drama first
- preserve utility and manual recovery visibility

### Sports language

Allowed on `Game Day`:
- `Now Batting`
- `Next Batter`
- `On Deck`
- `Playing`

Keep sports language concentrated here rather than spread across the app.

## 11. Setup and Admin Screen Rules

### Players

Should feel like:
- roster management first
- stronger identity/status rows second

Rules:
- stay efficient
- do not become a gallery
- use lightly carded identity/status treatment

### Teams

Should feel like:
- simple management
- stronger selected-team identity

Rules:
- basic iOS management behavior
- more satisfying active-team state
- no over-branded team browser

### Readiness

Should feel like:
- a pre-game checklist
- operational
- clear
- not scary

Rules:
- grouped cards by issue family
- stronger status treatment than ordinary setup screens
- overall shell remains bright and calm
- this is not a mini `Game Day`

### Clips

Should feel like:
- the live-side companion to `Game Day`
- same family, lower energy

Rules:
- darker live-side family is allowed
- layout must be structurally simpler and less dramatic than `Game Day`
- calmer state treatment than `Game Day`

### Settings

Should feel like:
- quiet
- plain
- well-grouped
- operational

Rules:
- closest screen to standard grouped iOS
- almost no decorative energy
- clear separation of normal actions, recovery, About, and advanced tools

### Player Editor

Protected-zone rule:
- use new spacing, cards, button hierarchy, chips, and typography only as outer-shell polish
- do not let visual cleanup become stealth workflow redesign

## 12. Accessibility Requirements

Accessibility rules are not optional.

Requirements:
- accessibility wins over dramatic composition
- no color-only meaning
- contrast beats prettier glass
- respect Dynamic Type
- let `Game Day` reflow rather than break
- respect Reduce Motion
- any pulse/shimmer must be removable
- disabled controls remain readable
- text over photos must maintain real contrast

Real-device requirement:
- any future `Game Day` implementation must be checked on a real iPhone in bright outdoor conditions

Check for:
- contrast
- glance readability
- tap confidence
- whether the hero crowds out the grid
- whether `playing` state is obvious enough to prevent accidental re-triggering during stutters

## 13. Do / Don’t Examples

### Do

- make one thing clearly primary on each screen
- keep setup screens calm and forward-moving
- let `Game Day` feel special through hierarchy, not clutter
- use practical, plainspoken labels
- use derived team color carefully
- keep the team banner consistent
- let `Readiness` act like an operational checklist
- prefer smart display rules over settings toggles

### Don’t

- do not turn screens into dashboards
- do not fill every row with chips and metadata
- do not make `Clips` feel like a co-equal hero to `Game Day`
- do not use gimmicky sports chrome
- do not lean on glass when it weakens contrast
- do not add appearance preferences unless a strong reason exists
- do not hide important state behind tiny icon-only controls
- do not rely on text laid over busy photos

## 14. Component Naming Recommendations

Use practical descriptive names.

Good examples:
- `TeamBanner`
- `StatusChip`
- `PrimaryActionButton`
- `GameDayHero`
- `NowBattingCard`
- `NextBatterCard`
- `FallbackPlayerTile`
- `ReadinessCard`
- `PlayerIdentityRow`

Naming rules:
- keep shared infrastructure names practical
- reserve sports-specific naming mainly for `Game Day`
- avoid cute or vague brand-internal names

## 15. Safe Implementation Order

Recommended sequence:

### Phase 1: shared visual foundation

Build:
- semantic color roles
- typography hierarchy
- spacing tiers
- button families
- card families
- status-chip language
- team banner

### Phase 2: low-risk support screens

Apply the system to:
- `Players`
- `Teams`
- `Readiness`
- `Settings`

### Phase 3: live-side companion screen

Apply to:
- `Clips`

### Phase 4: `Game Day`

Implement the live-side hero, controls, warning strip, and fallback-grid hierarchy only after the shared system is stable.

### Phase 5: protected editor-shell polish

Apply visual-shell cleanup only to:
- `PlayerEditorSheet`
- related setup sheets

Do not broaden this into behavior changes without explicit approval.

## 16. Open Decisions

- whether `Players` and `Teams` eventually merge into one interface
- exact final `Game Day` hero proportions after real mock/screen testing
- whether fallback grid settles at `3-across` or can safely support `4-across`
- exact live-side relationship between `Game Day` and `Clips` once real screens are visible
- exact visual strength of the warm app accent versus team-derived accent after real palette exploration
- exact visual proportion of the current-player hero photo once mockups prove whether more than one fallback row still fits comfortably

## 17. Explicit Guardrails

The planning doc should actively prevent these future mistakes:
- turning the app into a dashboard
- making more than one thing primary on a screen
- adding visual preference knobs without strong justification
- letting `Game Day` drama outrun real usability
- using sports theming instead of hierarchy and clarity

## 18. Requires Approval Notes

The following ideas are recorded here as approved planning directions, but future implementation must still be deliberate because they touch behavior-sensitive areas:

- stronger queue-forward `Game Day` presentation
- auto-advancing visual flow toward next batter when playback ends
- stronger current/next prewarm emphasis
- conditional launch into `Game Day` versus `Players`

Implementation caution:
- these items must not be implemented casually inside protected zones
- future work should preserve truthfulness about actual playback readiness and Apple Music behavior
- if implementation pressure reveals hidden risk, pause and re-approve the specific behavior change

## 19. Summary

`Roll Call` should feel like a calm, iPhone-native setup tool that exists in service of one darker, clearer, more special live destination: `Game Day`.

The system should:
- stay mostly standard iOS outside live use
- use liquid-glass thoughtfully rather than dogmatically
- preserve strong contrast for bright-field conditions
- keep team identity present but controlled
- protect the app from dashboard sprawl
- and make `Game Day` feel purpose-built without becoming theatrical
