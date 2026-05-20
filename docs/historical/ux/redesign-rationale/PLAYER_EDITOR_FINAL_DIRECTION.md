# Player Editor Final Direction

Status:
- Owner-approved direction for the next Player Editor implementation pass
- Planning and implementation guidance only
- No code changes are authorized by this document by itself

Source context:
- `historical/ux/pre-redesign-baseline/`
- `historical/ux/redesign-rationale/VISUAL_LANGUAGE_SYSTEM.md`
- `historical/ux/redesign-rationale/PLAYER_EDITOR_SCREEN_SPEC.md`
- `historical/ux/redesign-rationale/PLAYER_EDITOR_DECISION_REVIEW.md`
- current implemented `PlayerEditorSheet` in `RollCall/RootView.swift`

## 1. Final Screen Purpose

Player Editor exists to prepare one player for confident Game Day use without cognitive overload.

It is:
- guided player setup
- a focused player configuration surface
- a place to confirm identity, choose a song cue, tune the clip, and manage an Announcement Cue

It is not:
- a media editor
- a roster lineup screen
- an audio workstation
- a Game Day session-state surface
- a delete-player management screen

The emotional center is readiness for real Game Day use, with Song Cue as the primary setup section and Trim as part of that song workflow.

## 2. Final Section Order

Use a stable static order:

1. Setup Summary
2. Identity
3. Song Cue
4. Fine Tune Clip / Trim
5. Announcement Cue
6. Experimental, if enabled
7. Contextual destructive actions as appropriate

Do not dynamically reorder sections based on announcer mode, missing fields, or current setup state.

### Setup Summary

Use a compact setup summary with:
- one primary status
- optionally one recommended next need/action

Do not include:
- missing photo
- present/hidden status
- jump links
- repair wizard behavior
- deep-link behavior
- multiple dashboard-style calls to action

### Identity

Identity includes:
- name
- number
- supporting photo thumbnail/action

Photo is optional and supportive. Name and number are the primary operational identity.

Do not show:
- `Present Today`
- `Hidden from Game Day`
- pronunciation override

### Song Cue

Song Cue is the primary setup section.

It should clearly show:
- no cue / selected cue
- `Choose Song` / `Change Song`
- compact source/capability context
- preview when available
- contextual access to local import through a compact secondary reveal

### Fine Tune Clip / Trim

Trim belongs directly after Song Cue and before Announcement Cue.

It should:
- be visible when a cue exists
- not be hidden or collapsed away
- keep `Suggested Hook` visible
- keep `Start at Beginning` visible
- keep preset lengths visible
- keep `Preview Clip` nearby
- keep `Advanced` as the precision/fade area
- feel visually calmer than cue selection
- avoid making Player Editor feel like an audio editor

### Announcement Cue

Use `Announcement Cue` as the user-facing term.

Announcement Cue comes after Trim. It remains important, but should not interrupt the song-selection and trim workflow.

### Experimental

Keep experimental controls visible only when their existing feature flags make them visible.

Do not make experimental Apple Music local-copy behavior look like a normal primary workflow.

### Destructive Actions

Place destructive actions contextually:
- `Clear Song` near Song Cue
- `Clear Announcement Cue` near Announcement Cue

Keep them visually quiet/subdued, explicitly confirmed, and scoped to the asset they clear.

Do not add `Delete Player` in this pass.

## 3. What Changed From `PLAYER_EDITOR_SCREEN_SPEC.md`

The final direction overrides these parts of the earlier screen spec:

- Remove `Present Today` / `Hidden from Game Day` from Player Editor.
  Presence is lineup/game-session state, not player setup/configuration. The underlying model and state behavior remain unchanged and may stay accessible from Players list or Lineup.

- Remove pronunciation override from visible Player Editor UI.
  The schema/model field may remain for future use. Do not migrate, delete, or rewrite stored data.

- Setup Summary must not include present/hidden status or missing photo.
  It may show one primary status and optionally one next need/action, but it must not become a dashboard or repair wizard.

- Identity is reduced to operational identity.
  It includes name, number, and supporting photo. The earlier spec's identity list included pronunciation and present status; those are no longer approved for this screen.

- Trim moves before Announcement Cue.
  The earlier spec placed custom announcer intro before photo/fine tuning. The final order treats trim as part of the song workflow, so it follows Song Cue directly.

- Local import moves near Song Cue.
  It should no longer sit in a detached `More Audio Options` section. It should appear as contextual fallback access, such as `Other Audio Options`, without becoming a peer primary action.

- Destructive actions become contextual.
  The old bottom `Clear Audio` grouping should give way to quiet scoped actions near the thing being cleared, while retaining confirmation.

## 4. What Changed From `PLAYER_EDITOR_DECISION_REVIEW.md`

The owner decisions resolve the review's open questions this way:

- Top summary: status plus optional single next need/action is approved; no jump links, repair wizard, deep links, or multi-CTA dashboard.
- Presence: remove from Player Editor entirely instead of relabeling it.
- Photo: keep in Identity as optional support; do not show missing photo in summary or readiness.
- Local import: place near Song Cue in a compact disclosure/secondary reveal; do not keep it detached and do not make it primary.
- Trim: keep visible when a cue exists; do not collapse it away.
- Announcement Cue order: after Trim.
- Destructive actions: place near related sections, quiet/subdued, confirmed, and scoped.
- Save/Close: preserve current behavior.
- Missing photo: not a readiness problem.
- User-facing term: `Announcement Cue`, not `Custom Intro`.
- Section order: static and predictable; no dynamic reordering.
- First-screen outcome: guided setup without cognitive overload, led by identity and Song Cue readiness rather than attendance/session state.

## 5. Implementation-Safe Visual Changes

The next implementation pass may safely do these if kept local to `PlayerEditorSheet` and existing helper views:

- Add a compact setup summary derived from existing in-memory player/cue/custom-announcer state.
- Reorder visible sections to the approved static order.
- Remove the visible `Present Today` row from the editor without deleting or changing the underlying `Player.isPresent` model behavior.
- Remove the visible pronunciation override field without deleting or changing the underlying stored field.
- Rebalance Identity so name and number are primary and the photo action is smaller/supportive.
- Rename/reframe `Cue Source` as `Song Cue`.
- Move local import into a compact contextual disclosure near Song Cue.
- Move Trim directly after Song Cue and keep existing trim controls visible when a cue exists.
- Keep `Preview Clip` close to Song Cue/Trim without changing preview behavior.
- Move `Clear Song` and `Clear Announcement Cue` to quiet contextual placements while preserving existing confirmation and action wiring.
- Apply visual language system polish: spacing, grouping, calm setup/admin card treatment, button hierarchy, plain status chips, and readable helper text.

These changes must not alter model shape, save semantics, asset writes, import/export, playback, Apple Music capability behavior, trim math, recording behavior, or photo cropper behavior.

## 6. Behavior-Sensitive Items Requiring Extra Caution

### Trim Enable Nuance

Owner-approved direction:
- preserve existing `Enable` / `Done` protection when returning to edit an existing player/cue
- allow initial cue setup trim adjustment without requiring an extra `Enable` step, if it can be done safely

This is behavior-sensitive because the current locked scrubber was added to prevent accidental edits inside a scrollable editor.

Do not implement this refinement unless it can be done safely and locally without changing:
- trim math
- cue persistence semantics
- preview timing
- live scrub behavior
- duration clamps
- Apple Music full-song versus preview-only behavior
- cue source semantics

If implementation cannot reliably distinguish initial setup from existing cue edit using local view state, keep the existing `Enable` / `Done` behavior and document the deferral.

### Setup Summary Truthfulness

The summary must not create a second readiness system. Use existing state and existing readiness meanings. Avoid promising Apple Music playback/fade reliability beyond what the app actually knows.

### Save / Close

Preserve current `Save` / `Close` behavior. Do not add autosave, unsaved-change prompts, draft recovery, immediate-save conversion, or new cancellation semantics.

Remember: some media actions already apply through `AppModel` and refresh local state. Do not make UI copy imply that `Close` fully cancels those operations.

### Recording State Machine

Announcement Cue recording is not just a button. Preserve:
- starting
- recording
- stopping
- idle
- transition disabled state
- missing stored-file warning
- preview stored cue
- cancel recording on editor dismissal

### Photo Flow

Preserve:
- `PhotosPicker`
- basic cropper full-screen cover
- drag/pinch crop interaction
- timed fallback saving the original photo if the cropper does not load
- app-owned JPEG storage
- error text when fallback is used

### Local Import

Moving local import visually must not change:
- importer allowed content types
- imported media storage
- video-to-audio extraction behavior
- package/export semantics
- error surfaces

### Apple Music

Do not change:
- Apple Music picker entry
- app-wide recents
- search behavior
- preview behavior
- row-tap immediate selection
- capability guidance
- full-song versus preview-only distinctions
- 20-second cue limits

## 7. Explicit Out-Of-Scope Items

Do not implement or change these in the next pass:

- RootView-wide architecture refactor
- splitting `PlayerEditorSheet` into new files unless explicitly approved
- model/schema changes
- migrations
- deleting pronunciation override data
- deleting presence state
- changing `Player.isPresent` semantics
- changing Lineup or Game Day presence behavior
- changing Save / Close semantics
- autosave
- unsaved-change prompts
- draft recovery
- Apple Music picker redesign
- Apple Music capability logic
- playback engine behavior
- trim math, duration clamps, or cue persistence structure
- recording storage behavior
- photo cropper behavior
- import/export behavior
- `.rollcall` package format
- readiness calculation changes
- dynamic section reordering
- `Delete Player`

Future consideration:
- `Delete Player` may be added later as a separate entity-level destructive action, probably outside the main happy-path setup flow and with explicit confirmation. It is not part of PE-1 or PE-2.

## 8. Acceptance Criteria For The Next Implementation Pass

For PE-1 visual/structure implementation:

- Player Editor uses the final static section order.
- Setup Summary appears at the top with one primary status and at most one next need/action.
- Setup Summary does not show missing photo, present state, or hidden-from-Game-Day state.
- `Present Today` / `Hidden from Game Day` is not visible in Player Editor.
- Pronunciation override is not visible in Player Editor.
- Name and number remain editable.
- Photo remains optional, visible as a supporting identity action, and does not dominate the screen.
- Song Cue is the primary setup section and clearly shows no cue / selected cue state.
- `Choose Song` / `Change Song` still opens the existing Apple Music picker.
- Local import is available near Song Cue through a compact secondary reveal such as `Other Audio Options`.
- Local import is not presented as a primary peer to `Choose Song`.
- Trim appears directly after Song Cue when a cue exists.
- `Suggested Hook`, `Start at Beginning`, preset lengths, `Preview Clip`, and `Advanced` remain available.
- Announcement Cue appears after Trim.
- User-facing copy says `Announcement Cue`.
- `Clear Song` appears near Song Cue, remains quiet/subdued, and still requires confirmation.
- `Clear Announcement Cue` appears near Announcement Cue, remains quiet/subdued, and still requires confirmation.
- Existing Save and Close toolbar behavior is unchanged.
- Existing media/photo/recording/model refresh behavior is unchanged.
- Existing experimental section remains gated by the existing flag.

Verification for PE-1:
- Build the app for an iOS simulator or generic iOS destination.
- Launch/smoke-check the Player Editor if simulator tooling is available.
- Verify the removed fields are absent from the editor but no model/schema files changed.
- Verify Apple Music picker still opens from `Choose Song` / `Change Song`.
- Verify local import presenter still opens from the contextual reveal.
- Verify trim controls still appear for a player with a cue.
- Verify Announcement Cue record/preview/clear controls still appear in their expected states.
- Verify Save and Close still perform their current actions.

For PE-2 trim Enable refinement:

- Only attempt after PE-1 is stable.
- Initial cue assignment may leave trim start adjustment enabled for the immediate setup moment.
- Returning to edit an existing player/cue keeps the current `Enable` / `Done` protection.
- No trim math, cue persistence, preview timing, or cue source semantics change.
- If safe local detection is not straightforward, defer PE-2.

Verification for PE-2:
- Add or run focused manual smoke coverage for new cue assignment versus returning to an existing cue.
- Confirm accidental scrub protection still exists for existing cues.
- Confirm `Suggested Hook`, `Start at Beginning`, live scrub preview, length chips, and `Advanced` still behave as before.
- Confirm repeated non-zero Apple Music start behavior is not touched.

## 9. Exact Recommended Codex Implementation Prompt For PE-1/PE-2

Use this prompt for PE-1:

```text
Using:
- /historical/ux/pre-redesign-baseline/
- /historical/ux/redesign-rationale/VISUAL_LANGUAGE_SYSTEM.md
- /historical/ux/redesign-rationale/PLAYER_EDITOR_SCREEN_SPEC.md
- /historical/ux/redesign-rationale/PLAYER_EDITOR_DECISION_REVIEW.md
- /historical/ux/redesign-rationale/PLAYER_EDITOR_FINAL_DIRECTION.md
- the current implemented app UI

Implement PE-1 for Player Editor only.

Scope:
- Update only the Player Editor presentation/section structure needed to match PLAYER_EDITOR_FINAL_DIRECTION.md.
- Keep the work local to PlayerEditorSheet and existing nearby helper views unless a tiny local helper is clearly safer.
- Do not modify models, persistence, Apple Music picker behavior, playback engine, trim math, import/export, recording storage, photo cropper behavior, package format, readiness calculations, or Save/Close semantics.

Required PE-1 behavior:
- Add the compact setup summary with one primary status and at most one next need/action.
- Do not include missing photo or present/hidden status in the summary.
- Remove Present Today / Hidden from Game Day from the visible Player Editor UI without changing underlying state/model behavior.
- Remove pronunciation override from the visible Player Editor UI without deleting or migrating stored data.
- Make Identity contain name, number, and a supporting photo thumbnail/action.
- Make Song Cue the primary setup section.
- Move local import near Song Cue inside a compact secondary reveal such as Other Audio Options.
- Keep local import secondary, not a primary peer to Choose Song.
- Put Fine Tune Clip / Trim directly after Song Cue and before Announcement Cue.
- Keep Suggested Hook, Start at Beginning, preset lengths, Preview Clip, and Advanced visible/available when a cue exists.
- Use Announcement Cue as the user-facing term.
- Put Announcement Cue after Trim.
- Put Clear Song near Song Cue and Clear Announcement Cue near Announcement Cue, visually quiet/subdued, with existing confirmations and scoped wording.
- Keep Experimental visible only under the existing feature flag.
- Preserve current Save and Close behavior exactly.

Do not implement PE-2 trim Enable nuance in this pass.

Before editing, report:
- files expected to change
- risk level
- conditional rule files reviewed
- why the change is visual/structure-only

After editing, verify with the narrowest meaningful build/smoke checks available and summarize exact files changed and checks run.
```

Use this prompt for PE-2 only after PE-1 is stable:

```text
Using:
- /historical/ux/pre-redesign-baseline/
- /historical/ux/redesign-rationale/PLAYER_EDITOR_FINAL_DIRECTION.md
- the current implemented PlayerEditorSheet after PE-1

Implement PE-2 only if it can be done safely and locally: refine the Trim Enable behavior so initial cue setup can adjust trim without requiring an extra Enable tap, while returning to edit an existing player/cue preserves the existing Enable/Done protection.

Do not change trim math, cue persistence, preview timing, live scrub behavior, duration clamps, Apple Music full-song versus preview-only behavior, cue source semantics, Save/Close behavior, or playback engine behavior.

If safe local detection of initial setup versus existing cue edit is not straightforward, do not implement the refinement. Instead, document why PE-2 should remain deferred.

Before editing, identify the exact local state signal you will use to distinguish initial cue setup from existing cue editing and explain why it cannot corrupt persisted cue state.

After editing, verify:
- new cue assignment trim adjustment path
- returning to edit an existing cue still requires Enable
- Suggested Hook and Start at Beginning still work
- length presets still work
- Advanced still opens and edits the same values
- Preview Clip still uses the existing preview path
```

## 10. Summary

The final Player Editor direction is a guided setup screen with Song Cue first among setup tasks, Trim directly attached to that song workflow, and Announcement Cue after the clip is shaped.

The next implementation should be conservative: restructure and clarify the visible editor while preserving the behavior-heavy systems already in place. PE-1 should not change core behavior. PE-2 is a separate, risk-gated interaction refinement.
