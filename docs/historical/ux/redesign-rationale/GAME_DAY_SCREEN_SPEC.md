# Game Day Screen Spec

Status:
- Planning document only
- No code implementation is authorized by this document
- No playback-engine, queue, lineup, Apple Music, persistence, model, or `PlayerEditorSheet` changes are authorized by this document

Source context:
- `historical/ux/pre-redesign-baseline/`
- `historical/ux/redesign-rationale/TARGET_UI_DIRECTION.md`
- `historical/ux/redesign-rationale/VISUAL_LANGUAGE_SYSTEM.md`
- current implemented UI direction from `Settings`, `Readiness`, `Teams`, `Players`, and `Clips`

## 1. Screen Purpose

`Game Day` is the primary live-use destination for the person running walk-up cues during an actual game.

It must accomplish five jobs under pressure:

1. Make the current live target obvious at a glance.
2. Make the next batter obvious without requiring lineup-sheet access.
3. Let the operator start or stop playback confidently with minimal thought.
4. Preserve manual recovery through a visible player grid when the expected queue/next-batter flow is not enough.
5. Surface only live-critical warnings, while leaving full diagnosis and repair to `Readiness`, `Players`, `Teams`, and `Settings`.

The screen should feel darker, more focused, and more dramatic than `Clips`, but the drama must come from hierarchy, contrast, scale, and playback state. It should not become a dashboard, a media editor, or a decorated sports poster.

## 2. Design Context From Current UI Direction

The polished support/setup screens have established this direction:

- `Settings`: quiet, grouped, operational, closest to standard iOS.
- `Readiness`: bright, calm, carded checklist with grouped issue families and plain status chips.
- `Teams`: calm management surface with selected-team summary and clear lifecycle actions.
- `Players`: efficient roster setup with identity rows, cue status, and first-order edit entry points.
- `Clips`: darker live-side companion surface with a `TeamBanner`/TeamBar, live background, compact cards, quick play affordances, and lower energy than `Game Day`.

`Game Day` should be the next step in that system:

- darker than `Clips`
- lower density than `Clips`
- more stateful than `Clips`
- more identity-forward than `Players`
- more urgent than `Readiness`
- still utility-first

The evolved `TeamBanner` is now effectively a thin `TeamBar`. This spec uses `TeamBar` to describe its intended role even if the current component name remains `TeamBanner`.

## 3. Top-To-Bottom Layout

The required screen hierarchy is:

1. `TeamBar`
2. live warning strip, only when needed
3. `Now Batting` hero
4. `Next Batter` / `On Deck` area
5. control row
6. fallback player grid

### 3.1 TeamBar

Purpose:
- anchor team context without stealing live-use attention
- remain read-only
- maintain the same thin utility-strip structure used on other screens

Content:
- selected team name
- compact secondary status
- subtle live-side accent

Secondary status priority:
1. live-critical warning summary, such as `Warnings`
2. otherwise present-player count, such as `12 players - 9 present`
3. no-team state, such as `Choose or create a team`

Visual treatment:
- thin, stable height
- darker live-side material than setup screens
- more contrast than `Clips`, but not a hero element
- no large logo, mascot, or decorative identity block

Not in scope:
- team switching
- quick actions
- interactive banner behavior

Those are behavior changes and require approval.

### 3.2 Live Warning Strip

Purpose:
- show only issues that could affect immediate live playback confidence
- keep the operator from discovering preventable failures only after tapping

Placement:
- directly below `TeamBar`
- above the hero
- omitted entirely when there are no live-critical warnings

Visual treatment:
- compact strip, not a card stack
- plainspoken label
- strong enough to notice, weaker than active playback
- no more than one line if possible
- may include a concise count plus one leading issue

Example labels:
- `Apple Music access needed`
- `3 present players need cues`
- `Volume is low`
- `Network unavailable for Apple Music cues`
- `Next batter has no cue`

### 3.3 Now Batting Hero

Purpose:
- make the current live target and playback state unmistakable
- be the emotional center of the screen
- absorb most of the drama

Position:
- immediately below warning strip, or below `TeamBar` when no warnings exist

Hero priority:
1. player name
2. playing state / cue state
3. player number
4. photo
5. song/cue information

The player name must win over every decorative element. If space gets tight, reduce photo size, background treatment, and hero height before shrinking operational text or controls too far.

### 3.4 Next Batter / On Deck Area

Purpose:
- make the next expected player visible without opening the lineup sheet
- support mental preparation and manual correction

Placement:
- below the `Now Batting` hero
- visually connected, but clearly subordinate

Recommended shape:
- substantial secondary card or horizontal strip
- same live-side family as the hero
- lower contrast, smaller type, less photo emphasis

### 3.5 Control Row

Purpose:
- keep core transport and lineup access predictable
- avoid hiding stop/recovery affordances

Placement:
- below the hero/on-deck stack
- above the fallback grid

Controls should be visible before the fallback grid becomes the main focus.

### 3.6 Fallback Player Grid

Purpose:
- provide a manual recovery and direct-tap surface
- preserve the current app's practical game-day usefulness
- support the operator when the real-world batting order differs from the expected next batter

Placement:
- below controls
- visible as a secondary surface
- scrolls if needed

The grid is quieter than the hero, but it must remain easy to hit.

## 4. Above-The-Fold Rule

On a normal iPhone, without scrolling, the screen should show:

- the `TeamBar`
- the warning strip when needed
- the full `Now Batting` hero
- the `Next Batter` / `On Deck` area
- the full control row
- at least the top slice of the fallback player grid

Target:
- one partial fallback row must be visible
- more than one fallback row is welcome only if it does not compromise hero clarity or controls

If vertical space is tight:

1. reduce hero photo drama
2. reduce decorative padding
3. tighten secondary metadata
4. preserve controls
5. preserve at least a visible grid cue

Do not solve space pressure by hiding controls, hiding the next batter, or pushing the entire fallback grid fully below the fold.

## 5. Now Batting Hero Spec

### 5.1 Player Name

Requirements:
- largest text on the screen
- full display name by default
- no text-over-photo dependency
- supports long names through wrapping or sensible scale reduction

Treatment:
- native system type, heavier weight
- no novelty scoreboard font
- high contrast against dark live surface

### 5.2 Player Number

Requirements:
- visible but subordinate to player name
- formatted as `#12` when a number exists
- absent or quietly replaced with `No number` only when useful

Treatment:
- firm, athletic weight
- can sit near the name as an identity marker
- should not outrank cue state

### 5.3 Optional Photo Treatment

The photo may be prominent, but it is optional support for identity, not the source of truth.

Recommended:
- large squircle/rounded-rect photo or identity image area
- clear placeholder when no photo exists
- no busy text over the photo
- optional small status overlay only if contrast remains strong

If the player has no photo:
- use a calm identity placeholder
- avoid making the missing photo feel like a failure during live use
- do not show a warning here unless the missing photo directly affects the live flow, which it usually does not

### 5.4 Song / Cue Information

Requirements:
- show the active cue label when available
- show source or brief cue context only if it helps live operation
- keep details compact

Recommended labels:
- `Cue: Thunderstruck`
- `Announcement Cue + Song`
- `Built-in fallback: No Song Yet`
- `Preview clip`

Avoid:
- technical source strings
- raw file paths
- over-promising full-song Apple Music playback
- long editor-like metadata

### 5.5 Playing State

When playback is active, the hero must make that unmistakable.

Required signals:
- explicit text, such as `Playing`
- strong live visual state in the hero
- matching active state on the main play/tap control
- optional active echo on the fallback tile for that player

Recommended treatment:
- strongest state lives in hero
- button echoes the state
- fallback grid echoes only enough for orientation

Avoid:
- making the entire screen pulse or shout
- relying on color alone
- subtle-only active state
- animation that harms readability or ignores Reduce Motion

### 5.6 Unavailable / Missing Cue State

If the current player has no directly assigned cue but the existing app can use the current fallback cue behavior, the UI must be truthful.

Possible labels:
- `No assigned cue`
- `Fallback available`
- `Check player cue`
- `Cannot play this player`

State rules:
- if tapping would currently play a fallback, do not label the player as completely unplayable
- if no playable cue exists, make the primary action disabled or clearly unavailable
- do not invent a new cue-repair flow inside `Game Day`
- route deeper repair expectations to `Players` or `Readiness` in later approved work only

Any change to fallback behavior, cue selection behavior, or missing-cue playback behavior requires approval and is not Phase 1 implementation.

## 6. Next Batter / On Deck Spec

Prominence:
- clearly visible above the fold
- second-most important identity surface on the screen
- visually subordinate to `Now Batting`

Content:
- label: `Next Batter` or `On Deck`
- player name
- player number when available
- compact cue readiness state
- optional tiny photo or initials

Recommended readiness labels:
- `Ready`
- `Preparing next cue`
- `Needs cue`
- `No present players`
- `Lineup unclear`

How it differs from `Now Batting`:

- smaller type
- less dramatic photo treatment
- lower contrast background
- no primary play state unless that player is also currently active
- more preparatory language, less live language

Truthfulness rule:
- `Preparing next cue` is allowed as expectation/status copy.
- Do not promise instant playback, seamless transition, automatic advancement, or verified Apple Music readiness unless the runtime actually supports and verifies that behavior.

## 7. Controls Spec

### 7.1 Primary Play / Stop Behavior

Current engine behavior:
- tapping the same cue again stops playback
- a separate `Stop Audio` button currently appears in the header only when playback is active

Preferred design direction:
- the primary player/cue action should be tap-to-play and tap-again-to-stop
- no always-visible separate stop button as the main design pattern
- active playback must be obvious enough that re-tap stop does not feel accidental or mysterious

Phase boundary:
- Showing the existing tap-again-to-stop behavior more clearly is visual-only.
- Removing the separate stop affordance or changing when stop appears requires approval / not Phase 1 implementation.
- Changing debounce, stop timing, fade behavior, or active-cue rules requires approval / not Phase 1 implementation.

### 7.2 Previous / Next Controls

`Next`:
- should be visible in the control row
- should use existing `advanceNextBatter()` behavior unless explicitly approved otherwise
- label can be `Next` or `Next Batter`

`Previous`:
- desirable for queue-confidence symmetry
- not currently established as implemented behavior in the inspected state
- requires approval / not Phase 1 implementation if it needs new model or queue behavior

Rules:
- do not imply automatic queue advancement unless implemented and tested
- do not add hidden lineup mutation through visual-only work
- do not change present-player filtering

### 7.3 Lineup / Queue Access

Current behavior:
- `Lineup` opens `Today's Lineup`
- lineup controls reorder players and mark presence

Recommended visual placement:
- in the control row, not hidden only in the navigation bar
- label should be decided before implementation: `Lineup`, `Today's Lineup`, or `Queue`

Boundary:
- moving the existing access point into the visual control row may be a visual/navigation presentation change, but it still affects live workflow and should be explicitly approved before implementation.
- changing lineup editor behavior, reorder mechanics, presence behavior, or next-batter persistence requires approval / not Phase 1 implementation.

### 7.4 Stop Separate Or Tap-To-Stop

Preferred direction:
- tap-to-stop on the active cue should be the primary stop model
- an emergency stop affordance may remain available if real-device testing shows tap-to-stop is not panic-safe enough

Decision needed:
- whether Phase 1 keeps a visible `Stop` control for safety while also making tap-to-stop clearer
- whether a separate stop should be removed later

Boundary:
- removing `Stop Audio` from the interface requires approval / not Phase 1 implementation.

### 7.5 Visual State When Playback Is Active

Required:
- hero says `Playing`
- primary action changes label/state
- active cue/player tile has a clear state
- controls remain tappable and understandable

Recommended:
- active color stronger than `ready`
- active border or glow on hero, not every surface
- no more than one motion effect, and only if Reduce Motion is respected

Avoid:
- making warning color and active color compete
- full-screen alarm treatment
- vague icons without text

## 8. Fallback Player Grid Spec

### 8.1 Layout

Default:
- 3-across grid

Reason:
- the grid is secondary to the hero, but still a live recovery surface
- 3-across balances tap confidence, visible options, and name readability

Do not switch to 4-across unless real-device testing proves:
- first names remain readable
- Dynamic Type does not collapse the layout
- thumb taps remain confident
- active/missing states remain distinguishable

### 8.2 Text Priority

Primary:
- first name by default

Secondary:
- uniform number
- one cue/status marker only when needed

Name ambiguity:
- if two present players share the same first name, promote enough of the last name to distinguish them
- do not require the operator to infer from number alone

### 8.3 Minimal Secondary Cue

Secondary cue priority:

1. `Playing`
2. `Next`
3. serious missing-usefulness warning
4. no secondary cue

Examples:
- `Playing`
- `Next`
- `Needs cue`
- `No cue`

Avoid:
- song title, artist, custom intro status, and readiness warning all competing in each tile
- editor-style metadata
- multi-chip rows inside grid tiles

### 8.4 Tile States

Active:
- strongest tile state
- clear text label
- aligns with hero active state

Next:
- visible but calmer than active
- should not look currently playing

Missing cue:
- warning state only when it affects whether the player can be useful from the grid
- if fallback playback is available, use careful copy such as `Fallback`

Disabled/unplayable:
- subdued but readable
- no color-only distinction
- tap should not look inviting if nothing can happen

### 8.5 Tap Confidence Rules

Tiles must:
- remain large enough for rushed thumb taps
- have stable dimensions
- not shift size when active state appears
- use the full tile as the tap target
- avoid tiny nested buttons
- keep the active/next state visible after a tap

If a tile tap would do something different from current behavior, that requires approval / not Phase 1 implementation.

## 9. Warning Strip Spec

Warnings that belong here:

- no team selected
- no present players
- no playable present players
- next batter has no cue or only fallback
- Apple Music access needed for assigned Apple Music cues
- Apple Music network unavailable when Apple Music cues exist
- volume low
- audio route unknown
- active playback failed
- lineup/next-batter state unclear

Warnings that do not belong here:

- every readiness row
- missing player photos unless the photo is needed for live identification and the team has chosen to depend on photos
- package export/import warnings
- backup age
- developer/experimental status
- long Apple Music capability explanations
- raw error dumps
- file path diagnostics
- custom intro details unless announcement mode is active and the next/current player is affected

How it differs from full `Readiness`:

- warning strip is an immediate live-use interruption layer
- `Readiness` is the full pre-game checklist and diagnostic surface
- warning strip summarizes and prioritizes; it does not repair
- warning strip should not become a scrollable warning dashboard

## 10. State Matrix

| State | Primary visual treatment | Main copy | Controls | Grid |
| --- | --- | --- | --- | --- |
| No team selected | TeamBar visible with warning tone; no hero drama | `No Team Selected` / `Choose or create a team` | Lineup/play controls unavailable | Hidden or replaced by calm empty state |
| No players | TeamBar shows team; hero becomes setup empty state | `No players yet` | Play unavailable; lineup access may be available only if existing behavior supports it | Hidden or empty |
| No playable players | Warning strip present; hero uses warning state | `No playable present players` | Play unavailable | Tiles disabled or warning-marked based on existing state |
| Ready team | Full live layout | `Now Batting` plus player identity | Play/next/lineup available using existing behavior | 3-across secondary grid |
| Player missing cue | Hero or tile shows warning only where relevant | `No assigned cue`, `Fallback available`, or `Needs cue` | Do not change fallback behavior | Tile warning if live-useful |
| Currently playing | Strongest live state in hero | `Playing` plus cue label | Active primary action shows stop/tap-to-stop meaning; existing stop behavior preserved | Active tile echoed |
| Playback failed | Warning strip plus failed state near hero | plain error summary from existing app error where possible | Recovery controls remain visible | Grid remains usable unless error blocks playback globally |
| Apple Music unavailable | Warning strip if Apple Music cues are relevant | `Apple Music access needed` or `Network unavailable for Apple Music cues` | Do not alter Apple Music gating | Apple Music-dependent tiles show warning if known |
| Queue empty / lineup unclear | Hero or on-deck area moves to lineup warning | `No present players` / `Lineup unclear` | Existing lineup access emphasized visually | Grid reflects present players if any |

State truthfulness rules:

- do not mark a cue as guaranteed ready unless existing readiness/playback state supports that claim
- do not hide missing-cue states behind a green ready treatment
- do not imply that Apple Music full-song behavior is equivalent to preview/local playback
- do not imply queue behavior that is not implemented

## 11. Interaction Boundaries

### Visual-only changes safe to implement first

These are safe only if they keep existing actions and data flow intact:

- darker live-side background aligned with `Clips`
- TeamBar placement and live-side treatment
- warning strip presentation using existing readiness/error/player state
- Now Batting hero layout using existing selected team, next batter, cue, and active playback state
- On Deck/Next Batter presentation using existing `team.nextBatter`
- control-row styling around existing actions
- 3-across fallback grid restyle using existing tap-to-play behavior
- active/missing/next visual state styling
- copy cleanup that does not change capability promises or behavior

### Behavior changes that require explicit approval later

- making `Game Day` the default launch tab
- changing top-level tab order
- changing tap/play/stop semantics
- removing the separate stop affordance
- adding previous-batter behavior
- changing `advanceNextBatter()` behavior
- auto-advancing the visual current/next batter after playback ends
- changing queue behavior
- changing lineup behavior, presence filtering, reorder rules, or persistence
- changing Apple Music capability, search, preview, trim, or playback behavior
- changing cue fallback behavior for players without assigned cues
- changing prewarm behavior or promises
- changing playback engine timing, debounce, fade, or stop rules
- adding repair deep links from warning strip or hero
- adding new stored team color/theme data
- adding PlayerEditor repair flows from `Game Day`

## 12. Implementation Phases

### Phase GD-0: Screenshot / Current Baseline

Goal:
- capture the current Game Day state before changes

Work:
- capture no-team state
- capture ready team state
- capture active playback state
- capture no-present-players state
- note current above-the-fold visibility

No code changes.

Exit criteria:
- baseline screenshots or documented blocker
- list of current controls and states visible on-device or simulator

### Phase GD-1: Visual Shell Only

Goal:
- align `Game Day` with the live-side visual system without changing behavior

Work:
- apply darker live-side surface
- place the thin TeamBar at the top
- reserve warning-strip area
- establish spacing and scroll container rules

Allowed:
- visual shell components
- static or existing-state-driven warning strip shell

Not allowed:
- playback changes
- queue changes
- lineup changes
- Apple Music changes

### Phase GD-2: Hero / Card Layout Using Existing State

Goal:
- introduce the `Now Batting` and `Next Batter` hierarchy using existing state only

Work:
- build `Now Batting` hero from existing selected team / next batter / active cue state
- build `Next Batter` area from existing `team.nextBatter`
- reflect active playback from existing `CuePlaybackEngine.activeCueID`
- keep labels truthful about missing cue and fallback behavior

Not allowed:
- new queue semantics
- automatic advancement
- new playback state machine
- prewarm guarantees beyond current behavior

### Phase GD-3: Fallback Grid Refinement

Goal:
- make the manual grid secondary, readable, and reliable

Work:
- switch toward 3-across default
- prioritize first names
- add active/next/missing visual states
- keep full-tile tap targets

Verification:
- real-device tap confidence check before considering denser layouts

Not allowed:
- changing tile tap behavior
- changing fallback cue behavior
- changing present-player filtering

### Phase GD-4: Approved Behavior Refinements Only

Goal:
- consider behavior changes only after the visual redesign proves itself

Possible refinements, each requiring explicit approval:
- previous-batter behavior
- separate stop removal or emergency stop redesign
- visual auto-advance after playback completion
- queue-forward flow
- lineup access terminology and placement changes
- deeper warning-to-repair routing

No GD-4 item should be implemented as cleanup during GD-1 through GD-3.

## 13. Real-Device Testing Checklist

Test on a normal iPhone in real or simulated game-like conditions.

Outdoor readability:
- text remains readable in bright conditions
- active playback state is visible at a glance
- warning strip is noticeable but not overpowering
- photo treatment does not reduce contrast
- team accent does not compromise semantic colors

Tap confidence:
- primary play/tap-to-stop target is easy to hit
- fallback tiles are easy to hit with one hand
- controls do not shift after playback starts
- `Next` and `Lineup` are not accidentally hit during normal play
- grid tile labels remain legible under motion and glare

Active playback clarity:
- operator can answer "what is playing?" in one glance
- active hero, button, and tile agree
- playback failure is visible without hiding recovery controls
- warning and active states are visually distinct

No-panic-stop behavior:
- operator understands how to stop audio immediately
- tap-to-stop does not feel hidden
- any separate stop affordance, if kept, is visible and literal
- short playback stutters do not cause confusing double-tap behavior

Dynamic Type and accessibility:
- long names do not collide with controls
- large text preserves the hierarchy
- no state depends only on color
- Reduce Motion disables any motion treatment
- VoiceOver order follows the visual hierarchy: TeamBar, warning, Now Batting, On Deck, controls, grid

Functional regression smoke:
- selected team still appears
- present players still populate
- lineup sheet still opens
- existing advance-next behavior still works
- same-cue tap-to-stop behavior still works
- Apple Music warning/capability language remains truthful

## 14. Open Questions

Decisions needed before implementation:

1. Should the main label be `Now Batting`, `At Bat`, or another phrase?
2. Should the secondary label be `Next Batter` or `On Deck`?
3. Should the control-row lineup button say `Lineup`, `Today's Lineup`, or `Queue`?
4. In Phase GD-1/GD-2, should the existing visible `Stop Audio` affordance remain while tap-to-stop is made clearer?
5. Is a `Previous` control desired enough to approve new behavior later, or should Phase 1 stay next-only?
6. Should missing assigned cues show `Fallback available` when the current fallback behavior can play a built-in cue?
7. How prominent should player photos be if they reduce the number of visible fallback tiles?
8. Should the warning strip include custom announcement cue issues only when announcement mode is active?
9. Should `Game Day` eventually become the default launch tab once readiness is good?
10. Should top-level tab order change later, or should `Game Day` be visually primary while keeping current navigation order for now?
11. Should any warning strip item link to a repair screen later, or should repair stay in `Readiness` and setup tabs?
12. Should team-derived accent be used in Game Day Phase 1 if no new stored team-color data exists, or should it stay on the current app accent until a separate color decision?

## 15. Summary Direction

`Game Day` should become a dark, live-first board with one unmistakable center: who is up now and whether audio is playing.

The screen should earn its drama through:

- a thin, consistent TeamBar
- a compact live warning strip
- a strong Now Batting hero
- a useful but subordinate On Deck area
- clear controls
- a 3-across manual fallback grid

The implementation path must protect the app's core job. Visual shell work can move first, but playback, queue, lineup, Apple Music, persistence, and editor behavior stay approval-gated.
