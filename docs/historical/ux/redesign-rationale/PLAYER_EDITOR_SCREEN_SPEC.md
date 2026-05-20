# Player Editor Screen Spec

Status:
- Planning document only
- No code implementation is authorized by this document
- No Apple Music, trim, playback, persistence, modal-flow, readiness-calculation, or model changes are authorized by this document

Source context:
- `historical/ux/pre-redesign-baseline/`
- `historical/ux/redesign-rationale/VISUAL_LANGUAGE_SYSTEM.md`
- current implemented UI direction from `Settings`, `Readiness`, `Teams`, `Players`, `Clips`, and `Game Day`

## 1. Screen Purpose

`Player Editor` is the guided setup surface for making one player usable on Game Day.

It should help the operator answer five questions quickly:

1. Is this the right player?
2. Is the player present for Game Day?
3. Does the player have a playable song cue or an intentional fallback?
4. Does the player have a custom announcer intro when the team mode needs one?
5. Are there any obvious setup problems before saving?

The screen should feel like guided setup, not a media editor. It may contain media-related controls, but the emotional center is player readiness, not audio engineering.

## 2. Design Context From Current UI Direction

The current app direction is no longer plain default iOS everywhere. The lower-risk screens have started defining a calmer Roll Call system:

- `Settings`: quiet, grouped, operational, closest to standard iOS.
- `Readiness`: bright, calm, carded checklist with grouped issue families and plain status chips.
- `Teams`: calm management surface with selected-team summary, section groups, and explicit lifecycle tools.
- `Players`: efficient roster setup with a thin team banner, quick add, identity rows, cue status, custom-intro status, and tap-to-edit entry.
- `Clips`: darker live-side companion surface with compact live cards and quick play affordances.
- `Game Day`: dark live-use board with TeamBar, announcer mode picker, live warning strip, Now Batting hero, On Deck area, control row, and manual fallback grid.

`Player Editor` should belong to the setup/admin family, not the live-side family:

- brighter and calmer than `Game Day` and `Clips`
- more guided than `Settings`
- more focused than `Players`
- more repair-oriented than `Teams`
- less diagnostic than `Readiness`
- less technical than a trim or media-editing tool

## 3. Current PlayerEditor Responsibilities

The current `PlayerEditorSheet` is responsible for all of this in one large form:

- load a local editable draft of the selected `Player`
- edit display name
- edit uniform number
- edit pronunciation override
- toggle `Present Today`
- choose or replace a player photo through `PhotosPicker`
- launch the basic photo cropper full-screen cover
- save cropped or fallback original photo into app-owned assets
- choose or change an Apple Music song
- refresh Apple Music playback capability when the editor opens
- refresh Apple Music cue metadata for the player when possible
- assign selected Apple Music results to the player
- apply initial Apple Music trim suggestions after assignment
- show Apple Music trim help text
- choose between `Suggested Hook` and `Start at Beginning`
- preview the current cue
- gate start-trim editing behind `Enable` / `Done`
- scrub cue start and optionally live-preview scrub changes
- choose preset cue lengths
- remember preferred cue length
- open `AdvancedTrimSheet` for quarter-second start, length, and fade controls
- import local audio or video as a fallback source
- record a custom announcer intro
- stop custom-announcer recording
- preview stored custom-announcer audio
- surface missing custom-announcer-file state
- cancel active recording when the editor disappears
- show the experimental `Make Local Copy` action when enabled for Apple Music cues
- clear the selected song after destructive confirmation
- clear only the custom announcer after destructive confirmation
- save the local draft back to `AppModel`
- close without saving explicit draft changes through the toolbar `Close` path
- refresh local draft state from the selected team after async operations

This density is the main problem. The redesign should not remove responsibilities casually; it should make the existing responsibilities easier to understand.

## 4. Protected Behavior Zones

These areas must be treated as protected during any future implementation.

### 4.1 Apple Music Selection and Capability

Protected:
- current Apple Music picker entry
- app-wide recents behavior
- search and preview behavior
- immediate row selection behavior
- capability banner/guidance
- distinction between catalog-backed full-song capability and preview-only fallback
- 20-second preview cap behavior where applicable

Do not replace this with a generic song picker or hide Apple Music capability caveats.

### 4.2 Trim Flow

Protected:
- `Suggested Hook`
- `Start at Beginning`
- preset length chips
- `Enable` / `Done` safety gate for start scrub
- live scrub preview behavior
- `Advanced` sheet entry
- quarter-second advanced controls
- fade controls inside `Advanced`
- trim math, duration clamps, cue limits, and saved cue structure

The screen may visually clarify trim. It must not casually redesign trim.

### 4.3 Playback and Preview

Protected:
- `Preview Clip` action
- cue preview entry point
- custom announcer preview entry point
- Apple Music preview behavior in the picker
- `CuePlaybackEngine` stop/debounce/fade/timing behavior
- repeated non-zero Apple Music trim-start behavior

Visual changes must not imply stronger playback guarantees than the runtime has.

### 4.4 Custom Announcer Recording and Storage

Protected:
- start recording
- stop recording
- transition/disabled state
- stored asset existence check
- missing-file warning
- preview stored custom intro
- clear custom intro only
- cancel recording on editor dismissal

Recording is a state machine, not just a button row.

### 4.5 Photo Import and Crop Fallback

Protected:
- `PhotosPicker` entry
- basic cropper full-screen cover
- drag/pinch crop interaction
- timed fallback that saves original photo if cropper does not load
- app-owned JPEG storage
- error text when fallback is used

Do not create a state where photo selection appears successful but no asset is saved.

### 4.6 Present / Hidden From Game Day

Protected:
- `Present Today` writes to the player state
- absent players are hidden from Game Day
- presence participates in lineup and readiness behavior
- roster row swipe action remains a valid presence-management path

Copy may be clearer, but semantics must not change.

### 4.7 Readiness Semantics

Protected:
- readiness calculation inputs
- warning, failed, ready, and unknown meanings
- custom-intro file-existence checks
- cue asset existence checks
- Apple Music authorization/capability checks
- photo checks

The editor may show readiness cues, but it must not invent a second readiness system.

### 4.8 Persistence and Draft State

Protected:
- current local draft behavior
- save path through `appModel.updatePlayer(player)`
- async refresh points after media/photo/recording operations
- app-owned relative asset paths
- cue model shape
- no storage-path changes

Any change to save semantics, autosave behavior, draft recovery, or model structure requires approval.

## 5. Proposed Information Hierarchy

The redesigned editor should read top-to-bottom as guided setup:

1. Player setup summary
2. Identity and Game Day status
3. Song cue setup
4. Custom announcer intro
5. Photo
6. Fine tuning
7. Advanced / destructive actions

The first screenful should communicate the player’s usable state without requiring scrolling through trim controls.

### 5.1 Top Summary

Purpose:
- orient the operator immediately
- summarize the setup state in plain language
- avoid making the navigation title carry all context

Suggested content:
- player name or `New Player Details`
- uniform number if present
- `Present` / `Hidden from Game Day`
- song cue status
- custom intro status
- one primary next setup need, if any

Tone examples:
- `Ready for Game Day`
- `Needs a song cue`
- `Hidden from Game Day`
- `Custom intro file missing`
- `Apple Music access needed`

This summary should use existing state only. It must not change readiness calculation semantics.

### 5.2 Identity Before Media

Identity fields should appear before media controls because they define the player, not the cue.

Required identity content:
- photo thumbnail or placeholder
- display name
- uniform number
- pronunciation override
- present status

The photo should support identity, not dominate the screen.

### 5.3 Cue Setup Before Trim

Song/cue selection should appear before trim because the operator cannot trim what has not been selected.

Recommended cue hierarchy:
1. selected cue summary or `No song selected`
2. primary action: `Choose Song` / `Change Song`
3. secondary action: local import fallback
4. caveat text based on Apple Music capability/source
5. preview action only when a cue exists
6. trim controls after cue summary

### 5.4 Custom Intro As Setup, Not Decoration

Custom announcer intro should be a clear setup block near cue setup because Game Day mode can make it important.

It should not feel like an optional novelty tucked at the bottom.

### 5.5 Fine Tuning After Usability

Trim controls belong after the selected cue is established and after the editor has communicated basic usability.

The user should never have to understand start scrub, duration chips, or `Advanced` before knowing whether the player has a cue at all.

## 6. Required Sections

Future visual implementation should preserve these sections, even if names are refined.

### 6.1 Setup Summary

Required:
- compact readiness/status summary for this player
- present/hidden state
- song cue state
- custom intro state
- one plain next action or issue, when useful

Safe now:
- visual summary based on existing player/cue/custom-intro fields
- status chips using existing visual language

Approval required:
- deep links that jump to repair subsections
- automatic repair actions
- new readiness logic

### 6.2 Player Identity

Required:
- photo thumbnail
- display name
- uniform number
- pronunciation override
- present status

Recommended:
- keep fields close together
- keep `Present Today` visually explicit and easy to understand
- describe hidden-from-Game-Day consequence near the toggle

### 6.3 Song Cue

Required:
- current selected cue summary, if any
- `Choose Song` / `Change Song`
- source/capability caveat
- local import fallback access
- `Preview Clip` when a cue exists
- `Clear Song` destructive action somewhere clear but not prominent

Recommended:
- make the selected cue feel like a setup card, not a raw form row
- keep local import visible but quieter than Apple Music
- avoid raw source strings or file paths

### 6.4 Custom Announcer Intro

Required:
- short explanation of where the intro plays
- current status
- record/start action
- stop action while recording
- transition disabled state
- preview action when stored audio exists
- missing-file warning
- `Clear Custom Announcer` destructive action somewhere clear but not prominent

Recommended:
- use `Custom Intro` wording where space is tight, with explanation text making the Game Day role clear
- show missing-file state as a warning, not a silent disabled control

### 6.5 Photo

Required:
- current photo or placeholder
- choose/replace photo action
- preserve cropper flow
- preserve fallback behavior

Recommended:
- keep photo in identity area unless future approval moves photo to its own focused block
- make missing photo quiet unless readiness says it matters

### 6.6 Trim

Required when a cue exists:
- Apple Music trim help text when provided by current logic
- `Suggested Hook`
- `Start at Beginning`
- `Preview Clip`
- start control with `Enable` / `Done`
- length presets
- `Advanced`

Recommended:
- label the block as cue fine-tuning
- keep preset controls first-order
- keep precision controls behind `Advanced`
- keep fade references quiet and caveated

### 6.7 Advanced / Destructive

Required:
- `Make Local Copy` only when the existing experimental flag and cue source allow it
- `Clear Song`
- `Clear Custom Announcer`
- destructive confirmations

Recommended:
- place destructive controls at the bottom
- keep experimental actions visually separate from normal setup
- avoid making `Make Local Copy` feel like the recommended path

## 7. What Should Be Prominent vs Quiet

### Prominent

These should be easy to see without hunting:

- player name
- present/hidden-from-Game-Day state
- whether the player has a song cue
- the selected song title and artist when present
- whether a custom intro exists or is missing when relevant
- primary next action to make the player usable
- `Choose Song` for players without a cue
- `Change Song` for players with a cue
- `Preview Clip` once a cue exists
- missing-file and Apple Music capability warnings

### Quiet

These should remain available but not dominate:

- pronunciation override
- local import fallback
- start scrub details
- exact cue start time
- exact cue duration
- advanced trim
- fade details
- experimental local copy action
- destructive clear actions
- photo absence when it is not blocking live use

### Never Buried

These must not be hidden in a collapsed advanced section:

- present/hidden status
- no song selected
- selected song identity
- custom intro missing-file warning
- Apple Music capability caveat when it affects the selected cue
- save/close controls

## 8. Song / Cue Setup Flow

The desired flow is:

1. Show current cue state.
2. If no cue exists, make `Choose Song` the clear primary action.
3. If a cue exists, show song/source summary and make `Change Song` available.
4. Keep local import as a secondary fallback path.
5. After cue assignment, show preview and trim setup.
6. Keep destructive `Clear Song` separate from normal cue setup.

### 8.1 No Cue State

Recommended message:
- `No song cue selected`
- `Choose a song so this player can be used confidently on Game Day.`

Primary action:
- `Choose Song`

Secondary action:
- `Import from Device`

Do not:
- show trim controls before a cue exists
- imply Game Day cannot function at all if the current approved fallback behavior can still play `Small Cheer`
- make fallback behavior look equivalent to a selected cue

### 8.2 Selected Apple Music Cue

Recommended summary:
- song title
- artist
- source/capability line
- clip length and start summary, if compact

Capability copy must remain truthful:
- catalog-backed full-song behavior and preview-only behavior are not equivalent
- fade behavior for full-song Apple Music must not be over-promised
- preview-only caps must stay visible where the current logic requires them

### 8.3 Selected Local Cue

Recommended summary:
- display title
- local/imported source indication
- clip length and start summary, if compact

Avoid:
- raw file paths
- implying user-owned source files remain externally linked after import

### 8.4 Local Import Fallback

Current behavior:
- `Import Audio or Video` is inside `More Audio Options` as a fallback path.

Future visual direction:
- keep it visible enough to find when Apple Music is not right
- keep it quieter than the primary Apple Music path
- label it as device-owned media fallback

Approval required:
- changing the source priority
- changing the import modal
- adding additional import sources
- changing storage semantics

## 9. Custom Announcer Intro Flow

The custom announcer intro flow should answer:

1. Is there a stored custom intro?
2. Is the stored intro file missing?
3. Can I record or replace it?
4. Can I preview it?
5. What happens in Game Day?

### 9.1 Empty State

Recommended message:
- `No custom intro recorded`
- `Game Day can play this recording in Announcer Only or before the song in Announcer+Song.`

Primary action:
- current `appModel.customAnnouncerButtonTitle(for:)` behavior

Do not invent new recording modes or default announcer behavior.

### 9.2 Recording State

Requirements:
- make recording state unmistakable
- keep `Stop Recording` prominent
- respect existing transition disabled state
- do not add background recording or delayed save semantics

### 9.3 Stored State

Requirements:
- show stored/ready status
- show `Preview Announcement Cue`
- offer record/replace using existing button behavior
- keep clear action separate and destructive

### 9.4 Missing File State

Requirements:
- warning must remain visible
- language should say the reference exists but the audio file is missing from app storage
- do not present the intro as ready

Approval required:
- automatic regeneration
- silent cleanup of missing references
- changing clear semantics
- changing readiness treatment

## 10. Photo Handling

Photo should support player recognition, especially in `Players` and `Game Day`, but Player Editor should not become a photo editor.

### 10.1 Current Behavior To Preserve

- choose image with `PhotosPicker`
- load image data
- open `BasicPhotoCropperSheet`
- allow pinch to zoom and drag to position
- save cropped JPEG to app-owned assets
- if cropper does not report ready within 1.5 seconds, save original image and surface an error
- keep photo path as relative app-owned asset reference

### 10.2 Proposed Presentation

Recommended:
- place photo thumbnail in the identity section
- use clear label: `Choose Photo` / `Replace Photo`
- keep the current image visibly tied to the player identity
- make missing photo quiet unless the readiness system flags it

Do not:
- add a new gallery
- add photo filters
- require a photo before saving
- change crop shape or output semantics without approval

Approval required:
- changing cropper presentation
- changing fallback timing
- changing crop/output dimensions or storage behavior
- adding photo removal if it changes persistence or package behavior

## 11. Present / Hidden-From-Game-Day Status

The current `Present Today` toggle is critical because it determines whether the player appears in Game Day.

Future copy should make the consequence clear:
- `Present Today`
- secondary text: `Shown on Game Day`
- off-state secondary text: `Hidden from Game Day`

Recommended visual behavior:
- place presence near identity, not near destructive or advanced actions
- use a clear status chip in the setup summary
- avoid treating absence as an error
- avoid hiding the toggle under advanced controls

Do not:
- change lineup filtering
- change default presence
- auto-mark present based on cue readiness
- auto-hide players based on missing song or intro
- change readiness calculation for absent players

## 12. Trim Controls and Apple Music Caveats

Trim should remain confidence-oriented:

- select an obvious start suggestion
- choose a simple length
- preview
- only then adjust start or advanced precision if needed

### 12.1 Main Trim Path

Required order:
1. source/capability caveat when relevant
2. `Suggested Hook` / `Start at Beginning`
3. `Preview Clip`
4. start scrub with `Enable` / `Done`
5. length presets
6. `Advanced`

Reason:
- the approved flow keeps precision out of the main path
- the start scrub is intentionally guarded because it sits inside a scrollable editor
- fade and quarter-second edits are useful but not everyday setup

### 12.2 Apple Music Caveats

Must remain visible when relevant:
- full-song catalog-backed playback depends on Apple Music capability and device/account conditions
- preview-only fallback may have shorter or constrained audio
- full-song MediaPlayer fade behavior has not been broadly proven on subscribed devices
- Apple Music trim should not be described as equivalent to local-file trim unless proven

Do not:
- promise exact full-song behavior where capability is uncertain
- hide preview-only limitations
- make fade controls prominent in a way that implies all sources behave identically

### 12.3 Advanced Trim

Keep `Advanced` as a separate precision sheet unless explicitly approved otherwise.

Approval required:
- replacing `AdvancedTrimSheet`
- adding waveform editing
- adding dual-handle trim
- changing preset lengths
- changing default trim suggestion behavior
- changing fade defaults or fade math
- changing live scrub preview timing

## 13. Validation / Readiness Cues

Player Editor should show local setup cues, not become the full Readiness tab.

Allowed visual cues:
- `Ready for Game Day`
- `Needs Song`
- `Hidden from Game Day`
- `Custom Intro Ready`
- `Custom Intro Missing File`
- `Apple Music Access Needed`
- `Photo Missing` only if driven by existing readiness/check state

Rules:
- use existing model/readiness facts only
- no new readiness calculations
- no greenwashing of warnings
- no color-only meaning
- use plainspoken labels
- route broad diagnosis to `Readiness` conceptually, without implementing new navigation unless approved

Recommended hierarchy:
- setup summary: one overall status plus key chips
- section headers/cards: local issue next to the relevant setup area
- destructive/advanced areas: no readiness status unless directly relevant

Approval required:
- new readiness score
- new blocking validation before save
- new inline repair actions
- new deep links from readiness warnings
- changing what counts as ready

## 14. Visual-Only Changes Safe To Implement Now

These are safe only if they preserve current actions, modal entry points, state refreshes, and data flow exactly.

- replace the single dense `Form` appearance with clearer visual section grouping
- add a top setup-summary card based on existing player/cue/custom-intro/presence state
- restyle identity fields using existing bindings
- restyle the photo picker label/thumbnail while preserving `PhotosPicker`
- restyle cue summary for selected song/local cue
- restyle Apple Music/local import actions without changing their destinations
- restyle custom intro status and action grouping
- move destructive clear actions into a quieter bottom section, keeping confirmations
- improve helper copy around `Present Today`, Apple Music caveats, custom intro role, and local import fallback
- restyle trim controls without changing order, bindings, math, or control availability
- apply existing visual language tokens, card styles, button styles, spacing tiers, and status chips
- improve accessibility labels/copy if they do not change behavior or promises

Important boundary:
- visual-only does not mean arbitrary rearrangement if the rearrangement changes workflow expectations, hides protected caveats, or changes modal timing.

## 15. Changes That Require Approval Later

These require explicit approval before implementation:

- changing Apple Music picker flow
- changing Apple Music capability messaging meaning
- changing Apple Music search, recents, preview, or selection behavior
- changing local import behavior or supported file types
- changing trim defaults, preset lengths, trim math, fade math, or preview timing
- changing `AdvancedTrimSheet`
- adding waveform editing or a more media-editor-like trim UI
- changing playback behavior from any preview control
- changing custom intro sequencing in Game Day
- changing recording start/stop/cancel behavior
- changing custom-intro storage, recovery, or missing-file cleanup semantics
- changing photo cropper modal flow
- changing photo fallback timing or storage
- changing save/autosave/draft semantics
- changing player model, cue model, asset paths, or schema
- changing presence filtering, lineup normalization, or Game Day visibility rules
- changing readiness calculations
- adding required validation gates before save
- adding modal-flow changes such as replacing sheets/full-screen covers, nesting new modals, or adding repair wizards
- adding new dependencies
- adding background work
- changing experimental `Make Local Copy` visibility rules or behavior

## 16. Implementation Phases

### Phase PE-0: Baseline / Inventory

Goal:
- capture the current editor responsibilities and visible states before implementation

Work:
- document no-cue player state
- document selected Apple Music cue state
- document selected local cue state
- document custom intro empty/recording/stored/missing-file states
- document photo empty/selected/crop fallback states if possible
- document present and hidden-from-Game-Day states
- document experimental local-copy visibility when enabled

No code changes.

Exit criteria:
- baseline notes or screenshots
- protected behavior checklist ready for implementation work

### Phase PE-1: Visual Shell Only

Goal:
- make the editor less dense without changing behavior

Work:
- establish setup-summary card
- group sections into guided setup order
- apply existing Roll Call card/button/status language
- keep all existing controls wired exactly as they are

Allowed:
- layout and styling
- copy clarification
- section ordering if it does not hide required controls or alter modal timing

Not allowed:
- new modals
- new validation
- new save behavior
- Apple Music, trim, playback, recording, photo, readiness, persistence, or model changes

### Phase PE-2: Cue and Custom Intro Clarity

Goal:
- make the two Game Day-critical audio areas clearer

Work:
- selected cue summary card
- no-cue state
- custom-intro status card
- missing-file warning presentation
- keep local import as secondary fallback
- keep trim controls protected

Not allowed:
- picker redesign
- trim redesign
- recording redesign
- playback changes

### Phase PE-3: Trim Presentation Cleanup

Goal:
- make trim feel understandable without becoming a media editor

Work:
- clarify main trim path
- keep `Suggested Hook` / `Start at Beginning`
- keep preset lengths prominent
- keep start scrub gated
- keep `Advanced` separate
- improve caveat placement

Not allowed:
- changing trim behavior, math, presets, defaults, preview timing, fade behavior, or Apple Music semantics

### Phase PE-4: Approval-Gated Workflow Changes

Goal:
- consider deeper changes only after visual shell proves useful

Possible future topics:
- more guided repair flow
- different modal structure
- stronger readiness-to-editor navigation
- photo removal
- clearer replacement flow for custom intro
- deeper source-selection redesign

Required before work:
- explicit approval
- updated behavior spec
- targeted smoke checklist
- rollback plan

## 17. Open Questions

- Should the top summary say `Ready for Game Day` only when both song and current Game Day announcer-mode needs are satisfied, or should it avoid an overall ready label and show separate status chips only?
- Should `Present Today` be renamed or paired with a stronger visible off-state label like `Hidden from Game Day`?
- Should custom announcer copy use `Custom Intro` everywhere visible, or keep `Announcement Cue` in some places for continuity?
- How prominent should custom intro be when the selected team is currently in `Song Only` mode?
- Should local import stay under a disclosure-style secondary area, or be visible as a quiet secondary button in the Song Cue section?
- Should photo stay in the identity section, or become its own section after identity once the editor is visually redesigned?
- Should missing photo ever appear in the editor summary, or only in Readiness and roster/game-day visual placeholders?
- Should `Clear Song` and `Clear Custom Announcer` live together at the bottom, or next to their respective sections with quieter destructive treatment?
- Should the editor show the currently selected Game Day announcer mode as context, or would that over-couple the editor to Game Day?
- Should Phase PE-1 be limited to card/spacing/button restyle only, or may it also reorder sections into the proposed guided setup hierarchy?

## 18. Summary

`Player Editor` should become a calm guided setup sheet for one player.

The safe redesign target is clarity:
- show whether this player is usable on Game Day
- keep identity and presence obvious
- make song setup easier to understand
- make custom intro state visible and truthful
- keep trim useful but quiet
- preserve Apple Music, playback, photo, readiness, persistence, and modal behavior until explicitly approved otherwise

The screen can look much better before it behaves differently. That is the right order for this part of Roll Call.
