# TARGET UI DIRECTION

This document proposes a safe, phased UI direction for `Roll Call` without changing app code, business logic, playback behavior, storage behavior, or package semantics.

It is intentionally a planning document only.

## Source Basis

Reviewed inputs:
- `docs/current-state/README.md`
- `docs/current-state/APP_OVERVIEW.md`
- `docs/current-state/SCREEN_INVENTORY.md`
- `docs/current-state/NAVIGATION_FLOW.md`
- `docs/current-state/DATA_AND_STATE.md`
- `docs/current-state/FUNCTIONALITY_PROTECTION_ZONES.md`
- `docs/current-state/UI_STYLE_AUDIT.md`
- `docs/current-state/SAFE_REDESIGN_STRATEGY.md`
- `docs/current-state/COMPONENT_CATALOG.md`
- `docs/current-state/VISUAL_REFERENCES.md`
- `docs/current-state/KNOWN_BUGS_AND_TECH_DEBT.md`
- `docs/roll_call_dev_notes.md`
- `docs/DECISIONS.md`
- `docs/WHERE_WE_STAND.md`

Important visual-documentation limitation:
- live screenshots were not captured in the current-state package; the existing visual references are code-derived because simulator capture was blocked by the `ZIPFoundation` build issue.

Important interpretation note from `docs/roll_call_dev_notes.md`:
- those notes are directional concepts and structural thoughts
- they are not finalized designs, immediate implementation requirements, or pixel-perfect specs
- they explicitly say major redesign work should not outrank stability, correct behavior, responsiveness, usability, or reliable playback flow

## Planning Constraints

These areas are protected and should be treated as black-box runtime zones during UI redesign unless explicit approval is given:
- `CuePlaybackEngine`
- Apple Music capability/search/subscription flows
- trim logic and trim defaults
- persistence and app-owned asset paths
- `.rollcall` import/export and backup semantics
- `PlayerEditorSheet` behavior and nested modal flow
- MediaPlayer-backed subscribed Apple Music playback behavior

This document therefore focuses on:
- view-layer redesign
- layout and hierarchy changes
- visual consistency
- safe component extraction
- presentation-layer clarity

This document does not propose:
- playback-engine rewrites
- business-logic rewrites
- persistence/model rewrites
- Apple Music product-flow replacement
- package-format or restore/import behavior changes

## Directional Priority

The current dev notes reinforce this sequencing:
- immediate priority remains stability, correct behavior, responsiveness, usability, and reliable playback flow
- this document is a future-facing alignment tool, not a reason to jump into a broad redesign now
- UI work should stay staged so low-risk clarity improvements happen before high-risk live-use workflow changes

## 1. Product Feel

Target feel:
- fast
- simple
- game-day friendly
- low-friction
- reliable
- confident without feeling heavy

The app should feel like a purpose-built game utility, not a complex media editor.

That means:
- primary screens should surface the next likely action quickly
- setup screens should stay plain and understandable
- live-use screens should be big, legible, and obvious under pressure
- warning states should help the coach recover, not lecture them
- advanced options should exist, but not dominate the main path

Design tone:
- practical first
- branded enough to feel intentional
- not decorative for its own sake
- not visually noisy

## 2. Proposed Navigation

### Recommendation

Keep the app at six top-level tabs for now:
- `Game Day`
- `Players`
- `Clips`
- `Teams`
- `Readiness`
- `Settings`

This is still a simplified structure because it keeps the current screen count stable, avoids new navigation depth, and makes the live-use hierarchy clearer without merging protected workflows prematurely.

This is intentionally an interim recommendation, not a claim that the final bottom-tab flow is settled. The dev notes explicitly say the tab structure likely needs a fuller rethink later.

### Why this structure

- `Game Day` is the core live-use destination.
- `Players` remains the main setup/editing entry point.
- `Clips` stays separate because it uses the same cue surface but a different content type.
- `Teams` deserves its own clear management surface.
- `Readiness` should stay distinct until its warnings can safely point users to the right repair surfaces.
- `Settings` should hold app-level controls, recovery, sharing, About, and advanced tools.

### Now

Safe now:
- keep six tabs
- improve tab order, titles, and icon consistency only after approval
- make the shell visually clearer without changing modal flow or destination logic

Lowest-risk recommendation:
- preserve the current functional separation
- redesign the visual hierarchy inside each tab before changing the information architecture

### Next

Reasonable next step after low-risk UI work:
- visually promote `Game Day` as the primary destination in copy, layout, and tab emphasis
- keep `Players` as the default selected tab until game-day readiness and team-selection affordances are clearer

### Later

Possible later direction, with approval:
- make `Game Day` the default selected tab
- move it to the first tab position if not already first
- move `Clips` closer to `Game Day` if that better matches real live-use flow
- reconsider the full bottom-tab order once lower-risk shell work and validation are complete

Why this is later:
- changing the default landing tab is a behavior change
- current docs still show `Players` as the default launch tab
- the app still has important setup/admin workflows that may be more common during onboarding than during live use

## 3. Persistent Team Banner

### Goal

Add a thin, persistent current-team banner across major screens so the app feels like it is always working on one active roster, not a loose collection of utility tabs.

### Suggested data shown

Safe-now banner contents:
- selected team name
- player count
- present-today count
- one short readiness cue such as `Ready`, `Warnings`, or `No Team Selected`

Optional later contents:
- current lineup status
- quick entry to lineup sheet
- accent styling tied to team identity or color context

### Where it should appear

Recommended:
- `Players`
- `Clips`
- `Game Day`
- `Readiness`

Optional:
- `Teams`

Probably not:
- `Settings`
- `Recovery & Backups`
- `Developer Tools`
- modal edit sheets
- import/export system presenters

Reasoning:
- it helps when the user is acting on team-specific content
- it becomes noise on app-level or operational screens

### Safety notes

Safe now:
- read existing selected-team state only
- do not add new selection behavior
- do not add hidden team switching from the banner in the first pass

Approval-gated later:
- making the banner interactive
- adding readiness shortcuts or lineup shortcuts
- adding real team colors if that requires new persisted theme data

## 4. Game Day Redesign

### Target direction

`Game Day` should become a clearer live board with stronger top-of-screen focus and less visual competition from the player grid.

### Proposed layout

Top section:
- thin team banner
- compact mode/status row

Primary live card:
- large `Now Batting` area
- clear player name and number
- cue status
- custom-intro status when relevant
- explicit active state when audio is currently playing

Secondary live card:
- `Next Batter`
- smaller than `Now Batting`
- clear readiness state
- prewarm expectation/status copy such as `Next cue preparing` or `Ready`

Control row:
- `Play Queue` or `Lineup` button
- `Previous Batter`
- `Next Batter`
- `Stop Audio`

Grid section:
- player grid remains present
- lower on the screen
- visually quieter than the live card
- still large enough for reliable taps
- likely trends toward a cleaner three-column emphasis first, with denser layouts considered later only if real use supports them

### Key interaction goals

- the current batter should be obvious at a glance
- the next batter should be obvious without opening lineup
- active playback should be unmistakable
- stop state should be visible and literal
- lineup access should feel like queue management, not a hidden admin task

### Queue-Forward Direction

The dev notes point toward a more queue-centered long-term `Game Day`:
- a prominent `Now Batting / Next Batter` section
- explicit `Play Queue`
- manual `Previous` and `Next`
- smoother visual advancement as queue playback progresses

That is a valid target direction, but this document treats it as a presentation goal unless and until deeper runtime behavior changes are explicitly approved.

### Prewarm expectations

The UI may surface prewarm expectations, but should not imply guarantees the engine does not currently make.

Safe language:
- `Preparing next cue`
- `Ready`
- `Check clip setup`

Unsafe language without approval/testing:
- anything promising seamless crossfade
- anything promising instant playback under all Apple Music states
- anything that treats preview-only and full-song Apple Music behavior as identical
- anything that implies queue-driven automatic advancement is already safely implemented without runtime verification

### Hard boundary

This redesign should keep using the existing playback entry points and existing `nextBatter`/prewarm behavior.

Do not propose:
- playback-engine changes
- tap-gesture semantics changes
- debounce changes
- announcer sequencing changes
- fade-behavior changes
- queue-runtime behavior changes

Those require explicit approval.

## 5. General Clips Redesign

### Goal

Make `General Clips` feel like it belongs to the same product family as `Game Day`, without changing clip logic or playback behavior.

### Proposed direction

- reuse the thin team banner
- switch from plain rows to larger clip cards or grouped list cards
- give each clip a strong, obvious play button
- use the same visual language as Game Day for active, ready, and neutral states
- keep helper text short and useful

### Desired relationship to Game Day

`General Clips` should feel like the bench-side soundboard companion to `Game Day`, not a separate admin tool.

That means:
- similar cards
- similar status chips
- similar button language
- similar spacing and typography

But it should not:
- add queue logic
- add favorites/model state unless separately approved
- change how built-in clips are sourced or played

### Later Possibility

The dev notes also float future user-added General Clips.

That should remain later and approval-gated because it expands product scope beyond visual alignment and would introduce new content-management behavior.

## 6. Readiness Redesign

### Goal

Turn readiness from a plain status list into an actionable pre-game checklist.

### Proposed direction

Replace flat rows with grouped cards such as:
- Audio Output
- Apple Music Access
- Missing Player Cues
- Missing Custom Intros
- Missing Photos
- Team Selection / Present Players

Each card can show:
- severity
- short plain-English summary
- affected count if applicable
- concise explanation

### Future action links

Future cards can include `Fix This` affordances that route to the relevant screen, for example:
- missing cue -> relevant player or `Players`
- team selection issue -> `Teams`
- Apple Music auth issue -> relevant setup area
- missing intro -> relevant player editor

### Safe now vs later

Safe now:
- visual grouping
- severity cards
- clearer wording
- better distinction between `ready`, `warning`, `failed`, and `unknown`

Requires approval:
- direct deep links into setup flows
- auto-filtering the destination screen
- any change to readiness calculation semantics
- any softening of warning meaning

## 7. Settings Organization

### Goal

Make `Settings` feel organized and calm, with advanced/operational tools clearly separated from normal use.

The dev notes mention renaming a prior `More` concept to `Settings`. The current app already reflects that naming direction, so the remaining work here is organization and clarity inside `Settings`, not a tab rename.

### Proposed structure

Section 1: `Team Package`
- export selected team
- share latest `.rollcall`
- import `.rollcall`

Section 2: `Game Day`
- game-day haptics
- future low-risk game-day preferences if approved

Section 3: `Recovery`
- backups
- restore

Section 4: `About`
- app version/build
- GitHub link
- copyright

Section 5: `Advanced`
- `Developer Tools`
- experimental controls
- support bundle actions

### Direction for Developer Tools

`Developer Tools` should remain clearly separated and visually framed as advanced/experimental, not part of the normal setup flow.

Safe now:
- better sectioning
- clearer labels
- separate advanced styling

Requires approval:
- moving experimental toggles into normal setup screens
- surfacing support/debug tooling more prominently in the main app

## 8. Visual Style Direction

### Goal

Introduce a lightweight style system that improves consistency without turning the app into an overbuilt design-system project.

### Safe core style tokens

- one primary accent
- one destructive accent
- one success accent
- one warning accent
- one neutral surface color
- one card corner radius
- one main content spacing scale

### Visual language

- cards for emphasis surfaces
- large game-day controls
- consistent primary/secondary/destructive button treatments
- status chips with text-first meaning, not color-only meaning
- stronger typography hierarchy
- consistent vertical spacing between sections

### Typography hierarchy

Suggested scale:
- screen title
- section title
- card title
- primary body
- helper text
- chip/status label

Keep it simple and system-native.

### Spacing rules

Suggested rhythm:
- small spacing for chip groups and tight metadata
- medium spacing for rows and cards
- large spacing between major sections

### Team-color accent

Recommended direction:
- eventually allow the active team identity to tint selected accents in `Game Day`, `Clips`, and the team banner

Important honesty:
- current-state docs and inspected files do not show an existing persisted per-team color model
- a real team-color system would likely require new product decisions and possibly new model state

Therefore:
- safe now: formalize a single app accent and a few semantic colors
- later with approval: add team-specific accenting if the owner wants a true team identity layer

## 9. Component Opportunities

These are safe component-extraction targets later, provided extraction starts as visual wrapper work and does not move business logic.

Recommended candidates:
- `TeamBannerView`
- `GameDayPrimaryCueCard`
- `GameDaySecondaryCueCard`
- `PlayerCueCard`
- `StatusChip`
- `ReadinessIssueCard`
- `GeneralClipCard`
- `SectionExplainerText`
- `PrimaryActionRow`
- `EmptyStateCard`

Extraction rule:
- start by passing existing state/actions through
- do not redesign model ownership while extracting visuals

## 10. Safe Implementation Phases

### Phase 0: baseline and visual references

Goal:
- establish a safe before-state

Work:
- add or improve SwiftUI previews where practical
- capture screenshots only when the build environment is healthy again
- document baseline screen states for Players, Game Day, Clips, Readiness, Teams, and Settings
- create a manual smoke checklist before UI edits

Important honesty:
- screenshots do not currently exist in the checked docs package from the recent pass

Safe now:
- yes

### Phase 1: style tokens and reusable visual components

Goal:
- create a lightweight shared visual language

Work:
- centralize a minimal set of colors, spacing, button treatments, and chips
- extract visual-only shared components
- do not change workflow behavior

Safe now:
- yes

### Phase 2: Settings, Readiness, and Teams polish

Goal:
- improve the clearest low-risk surfaces first

Work:
- reorganize Settings sections
- restyle Readiness as actionable cards
- improve Teams visual hierarchy
- introduce the team banner where appropriate

Safe now:
- yes, as long as behavior and routing stay the same

### Phase 3: General Clips visual alignment

Goal:
- make General Clips feel like part of the live-use product

Work:
- align cards, chips, spacing, and button language with Game Day
- keep the underlying clip playback path unchanged

Safe now:
- yes

### Phase 4: Game Day redesign

Goal:
- make the live board clearer and more focused

Work:
- promote `Now Batting` / `Next Batter`
- add clearer control grouping
- reduce visual dominance of the grid
- improve active/stop/prewarm presentation

Requires approval before implementation:
- yes

Reason:
- this is the core live-use screen
- even presentation-only changes can affect usability under pressure
- the dev notes point toward a stronger queue-centered live workflow, which raises the risk of accidental behavior drift if implemented too early

### Phase 5: Player Editor

Goal:
- consider visual cleanup only after the shell is stable

Work:
- outer-layout cleanup
- section clarity
- visual component extraction

Requires approval before implementation:
- yes

Reason:
- `PlayerEditorSheet` is a protected zone with heavy state and modal coupling

## 11. Approval Gates

The following changes should require explicit human approval before implementation:
- making `Game Day` the default launch tab
- reordering top-level tabs
- broadly rethinking the bottom-tab model
- changing any `Game Day` tap/play/stop interaction semantics
- changing previous/next batter behavior
- introducing or changing queue-playback behavior, including automatic visual advancement tied to runtime playback
- changing lineup editor behavior, reorder mechanics, or presence mechanics
- changing Apple Music picker flow, capability messaging, or trim entry flow
- changing trim defaults, trim math, or preview behavior
- changing cue prewarm behavior or any playback-engine behavior
- changing announcer sequencing or custom-intro rules
- changing readiness calculation semantics
- adding deep links or `Fix This` navigation from readiness cards
- adding a true per-team color system if it requires new stored state
- adding user-created General Clips or clip-library management
- changing settings/import/export/backup semantics
- changing Player Editor structure beyond visual-only extraction
- moving experimental/developer features into normal user flows

## 12. Open Questions

These should be answered before code changes begin:
- Should `Game Day` stay non-default during the first redesign pass, or is making it primary part of the intended product shift?
- Should top-level tab order actually change, or should only the visual emphasis change first?
- If tab order changes later, should `Clips` move immediately after `Game Day`?
- Should the team banner be display-only at first, or should it eventually include quick actions?
- Is `Readiness` meant to remain a separate tab long-term, or eventually become a stronger pre-game layer that routes into setup areas?
- Should `General Clips` remain an always-separate tab, or eventually feel more like a companion board to `Game Day`?
- Is future user-added General Clips support actually desired, or should General Clips stay built-in only for now?
- Is a per-team accent/theme actually wanted, or is a stronger single app accent enough?
- How much visual energy should `Game Day` keep relative to the simpler setup/admin screens?
- Should `Settings` keep recovery and developer areas in the same tab, or should one of those become more isolated later?
- When `Game Day` is redesigned, should the lineup button be framed as `Lineup`, `Queue`, or another term the owner prefers?
- Does the owner want `Previous Batter` surfaced explicitly, or should navigation stay biased toward `Next Batter` only unless there is a strong use case?
- If queue-forward `Game Day` is the long-term direction, should UI-only auto-advance cues wait until verified runtime support exists underneath them?

## Recommended Overall Direction

Safe now:
- establish a lightweight style layer
- add shared visual components
- polish Settings, Readiness, Teams, and General Clips
- introduce a thin current-team banner on team-specific top-level screens

Next:
- visually align the whole shell around a game-day-first product feel
- keep protected flows behaviorally intact

Later, with approval:
- redesign `Game Day`
- decide whether `Game Day` becomes the default tab
- consider Player Editor shell cleanup only after lower-risk surfaces are stable

The guiding principle should remain:
- make the app feel more focused and more intentional
- without turning it into a media editor
- and without destabilizing the protected playback, Apple Music, trim, persistence, and package flows that already exist
