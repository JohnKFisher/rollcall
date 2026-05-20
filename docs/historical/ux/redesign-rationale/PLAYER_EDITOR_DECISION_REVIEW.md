# Player Editor Decision Review

Status:
- Owner feedback requested before implementation
- Do not treat this as final implementation approval
- No code changes are authorized by this document

Source context:
- `historical/ux/pre-redesign-baseline/`
- `historical/ux/redesign-rationale/VISUAL_LANGUAGE_SYSTEM.md`
- `historical/ux/redesign-rationale/PLAYER_EDITOR_SCREEN_SPEC.md`
- currently implemented `PlayerEditorSheet` in `RollCall/RootView.swift`

Purpose:
- review the proposed Player Editor direction before implementation
- challenge the current spec where it may be wrong or incomplete
- identify decisions that need owner approval
- protect the existing Apple Music, trim, photo, recording, persistence, and destructive-action behavior

## Design Stance To Review

The proposed direction is to make Player Editor feel like guided player setup, not a media editor.

That is probably right for the app, but the current spec may understate one important reality: this screen is where the operator fixes almost every thing that can make a player fail on Game Day. If the redesign becomes too gentle, important repair controls may become harder to find.

The safest design target is:
- clear first-screen setup status
- identity first
- song and Announcement Cue treated as Game Day readiness work
- trim treated as useful fine-tuning, not the emotional center
- local import visible enough to save the operator when Apple Music is wrong
- destructive actions explicit, scoped, and away from the main happy path
- save/close semantics left unchanged unless specifically approved

## 1. Top Setup Summary

### Current Problem

The current editor uses the navigation title plus a large `Form`. It does not immediately answer whether the player is ready, hidden, missing a song, missing an Announcement Cue file, or blocked by Apple Music access.

The Players row and Readiness tab already show some of this status, but once the user opens Player Editor, they have to scan several form sections to understand the player's state.

### Proposed Change

Add a compact setup summary at the top of the editor with plain status such as:
- `Ready for Game Day`
- `Needs a song cue`
- `Hidden from Game Day`
- `Announcement Cue file missing`
- `Apple Music access needed`

The summary should use existing player, cue, custom-intro, and readiness inputs only.

### Why This Helps

It gives the operator a fast answer before they scroll. It also makes the editor feel like setup and repair instead of a pile of unrelated fields.

Example: if a player is present but has no song, the editor should make that obvious before showing trim controls or advanced actions.

### What Might Be Lost Or Made Worse

A summary can accidentally become a second readiness system. If its labels do not match the Readiness tab, the app may tell the user two subtly different stories.

It can also overpromise Apple Music behavior. Current docs still treat full-song Apple Music playback and fade behavior as provisional on real subscribed devices, so the summary must not imply "verified playable" unless the runtime really knows that.

### What Behavior Stays Exactly The Same

- Existing readiness calculations stay unchanged.
- Apple Music capability checks stay unchanged.
- Cue file checks, custom Announcement Cue file checks, and photo checks stay unchanged.
- No automatic repair or deep-link behavior is added without separate approval.

### Owner Decision Needed

Should the top summary be a simple status overview only, or should it include a single recommended next action such as `Choose Song` or `Record Announcement Cue`?

Recommendation: start with status plus one plain next need, but no jump links or automatic repair actions.

## 2. Identity Section

### Current Problem

The current `Player` section mixes identity, a large photo picker, and Game Day presence. The photo is visually first, while name, number, pronunciation, and presence sit below it as standard form rows.

This makes the photo feel central even though the player's name, number, presence, and cue readiness usually matter more during setup.

### Proposed Change

Keep identity first, but rebalance it:
- display name
- uniform number
- pronunciation override
- photo thumbnail or placeholder
- present/hidden state

The photo should support identity without dominating the screen.

### Why This Helps

The operator can confirm they are editing the right player before thinking about media. It also keeps the editor aligned with the app's practical setup/admin style.

### What Might Be Lost Or Made Worse

Photo changes may become less discoverable if the thumbnail is too small or if the choose/replace action looks secondary. The current large `Tap to Choose Photo` target is obvious and forgiving.

### What Behavior Stays Exactly The Same

- Display name, uniform number, and pronunciation still edit the same `Player` fields.
- Photo still uses the existing Photos picker, basic cropper, and app-owned JPEG storage.
- The photo crop fallback still saves the original image if the cropper does not load in time.

### Owner Decision Needed

Should photo selection stay inside Identity as a supporting thumbnail/action, or should photo get its own later section?

Recommendation: keep it in Identity, but make the action obvious enough that photo setup is not hidden.

## 3. Present Today / Hidden From Game Day

### Current Problem

The current toggle says `Present Today`. The consequence is important but implicit: absent players are hidden from Game Day and participate differently in lineup/readiness behavior.

That can be confusing because "present" sounds like attendance, while the practical live-use outcome is "show or hide this player during Game Day."

### Proposed Change

Keep the `Present Today` toggle, but show nearby consequence copy or status:
- on: `Present today`
- off: `Hidden from Game Day`

Do not change the underlying semantics.

### Why This Helps

It connects setup language to live-use behavior. This matters because the roster row also has a swipe action for `Mark In` / `Mark Out`, and users may manage presence outside the editor.

### What Might Be Lost Or Made Worse

`Hidden from Game Day` may sound stronger than intended, almost like removing or disabling the player. If the language is too alarming, users may hesitate to mark players out.

### What Behavior Stays Exactly The Same

- `Present Today` still writes to the player state.
- Absent players remain hidden from Game Day.
- Roster row swipe presence management remains valid.
- Lineup and readiness behavior do not change.

### Owner Decision Needed

Should the control be labeled primarily as attendance (`Present Today`) or live visibility (`Show in Game Day`)?

Recommendation: keep `Present Today` as the control label and show `Hidden from Game Day` as consequence/status when off.

## 4. Song Cue Section

### Current Problem

The current `Cue Source` section is simple, but it does not fully communicate source status. Apple Music is primary, local import is tucked into a separate `More Audio Options` disclosure, preview lives in trim, and `Clear Song` is down in `Clear Audio`.

That structure protects the primary path, but it can make the cue feel split across multiple sections.

### Proposed Change

Make song cue setup a single clear block:
- selected cue summary or `No song selected`
- `Choose Song` / `Change Song`
- Apple Music capability/source caveat when relevant
- `Preview Clip` when a cue exists
- local import fallback access
- `Clear Song` visible but not prominent

### Why This Helps

The operator sees the cue as one setup object instead of separate source, trim, import, preview, and clear fragments.

It also preserves the approved product boundary: Apple Music first, local import still available.

### What Might Be Lost Or Made Worse

If too much is pulled into one section, song cue may become the whole screen again. If local import is too prominent, the app may stop feeling Apple Music first. If it is too hidden, the fallback becomes hard to find when Apple Music is the wrong source.

### What Behavior Stays Exactly The Same

- Apple Music picker remains the dedicated picker.
- App-wide recents remain app-wide.
- Row tap still selects immediately and returns.
- Separate preview behavior in the picker remains separate from selection.
- Catalog-backed full-song versus preview-only behavior remains distinct.
- Existing local import and video-to-audio extraction behavior remains unchanged.

### Owner Decision Needed

How visible should local import be inside the cue section?

Recommendation: show it as a secondary fallback action inside the song cue section, not as a primary peer to `Choose Song` and not buried so deeply that it feels unsupported.

## 5. Trim Section

### Current Problem

The current `Clip Trim` section appears only after a cue exists and contains useful controls: Apple Music trim help, `Suggested Hook`, `Start at Beginning`, `Preview Clip`, gated start scrub, length chips, and `Advanced`.

This flow is strong, but it can make Player Editor feel like an audio editor if trim gets too much visual weight.

### Proposed Change

Treat trim as "cue fine-tuning" after the user has a selected cue:
- keep `Suggested Hook` and `Start at Beginning`
- keep preset lengths primary
- keep start scrub behind `Enable` / `Done`
- keep quarter-second precision and fade in `Advanced`
- keep `Preview Clip` close enough to cue/trim to be useful

### Why This Helps

The user can choose a song quickly, accept a reasonable default, and only tune if needed. This matches the existing approved trim direction: helpful defaults, explicit reversible choices, precision controls tucked into `Advanced`.

### What Might Be Lost Or Made Worse

If trim is visually demoted too far, users may miss the fact that Roll Call's core value includes choosing the right walk-up moment. If trim is too prominent, it competes with identity and readiness.

There is also a current behavior conflict to respect: the start scrub is intentionally gated because accidental trim edits were too easy.

### What Behavior Stays Exactly The Same

- Existing trim math, duration clamps, cue limits, and saved cue structure stay unchanged.
- `Suggested Hook` and `Start at Beginning` stay explicit.
- Length chips stay preset-first.
- `Enable` / `Done` continues to protect start scrub.
- `AdvancedTrimSheet` remains the precision/fade place.

### Owner Decision Needed

Should trim be visually prominent as part of the main cue card, or treated as a quieter fine-tuning section after the cue is selected?

Recommendation: treat trim as fine-tuning, but keep the selected start/length visible so the user knows the cue has shape.

## 6. Custom Announcer Intro Section

### Current Problem

The current section is labeled `Announcement Cue`, but this review and some planning text still use "custom intro" language. The feature is not just decorative: Game Day modes can make the recording central, especially `Announcer Only` and `Announcer+Song`.

The section currently appears before local import and trim. That placement may be correct if announcer readiness matters as much as song readiness, but it may also interrupt the song setup flow.

### Proposed Change

Keep a distinct Announcement Cue section with:
- short explanation of where it plays
- current status
- record/re-record action
- stop action while recording
- disabled/transition state
- preview action when stored audio exists
- missing-file warning
- `Clear Custom Announcer` destructive action somewhere clear but not prominent

Use `Announcement Cue` for user-facing copy unless owner decides otherwise. Use "custom intro" only as explanatory internal language if needed.

### Why This Helps

It keeps the feature visible as Game Day setup rather than a novelty. It also protects the recording state machine, which is riskier than a normal button row.

### What Might Be Lost Or Made Worse

If this section appears before trim, users who mainly care about choosing and shaping a song may feel interrupted. If it appears after trim, users in `Announcer Only` workflows may miss the most important setup item.

### What Behavior Stays Exactly The Same

- Start, stop, transitioning, idle, preview, and missing-file states stay unchanged.
- Recording cancellation on editor dismissal stays unchanged.
- Stored-file existence remains the source of truth for whether the cue is usable.
- Clear action removes only the custom Announcement Cue recording, not the song.

### Owner Decision Needed

Should Announcement Cue appear before trim or after trim?

Recommendation: put Announcement Cue before detailed trim if the top summary says it is needed, otherwise put it after the cue summary and before fine-tuning. If implementation needs a single static order, choose: Song Cue, Announcement Cue, Trim.

## 7. Photo Handling

### Current Problem

Photo handling is currently very obvious at the top of the form, but it is also visually dominant. The photo cropper is basic by design and has a timed fallback that may save the uncropped original if the cropper does not load.

Current docs also note that missing photos usually should not be treated as a live-use failure unless the team depends on photos.

### Proposed Change

Keep photo as identity support:
- show current photo or placeholder
- keep choose/replace action
- preserve basic cropper
- preserve fallback behavior and error surface
- avoid making missing photo look like a critical setup failure by default

### Why This Helps

It keeps the editor focused on Game Day usability while still making player identity richer.

### What Might Be Lost Or Made Worse

If photo becomes too quiet, users may not add pictures even though photos help visually distinguish players in roster and Game Day. If photo stays too large, it may crowd out cue and readiness work.

### What Behavior Stays Exactly The Same

- Photos picker entry stays.
- Basic drag/pinch cropper stays.
- Squircle/rounded-rect presentation stays aligned with current app display shape.
- Fallback-to-original behavior stays.
- App-owned JPEG storage stays.

### Owner Decision Needed

Should missing photo be treated as a quiet optional identity enhancement, or should it appear in the top setup summary when absent?

Recommendation: keep missing photo quiet unless future owner direction says photos are required for this team's Game Day workflow.

## 8. Destructive Actions

### Current Problem

Current destructive actions live under `Clear Audio`:
- `Clear Song`
- `Clear Custom Announcer`

Both use confirmation prompts. This is good, but the section groups two different asset types under one label, and `Clear Custom Announcer` is intentionally scoped to only the custom recording.

### Proposed Change

Keep destructive actions explicit and scoped:
- `Clear Song` near song cue, but visually quiet
- `Clear Custom Announcer` near Announcement Cue, but visually quiet
- confirmations remain literal
- no bundled "reset player" action unless separately approved

### Why This Helps

Users can find the clear action near the thing they are clearing without scanning a generic danger section. The action remains less prominent than setup.

### What Might Be Lost Or Made Worse

Moving clear actions into their sections can make destructive buttons appear more often in the normal path. If they are too visible, users may hit them by accident or feel the screen is danger-heavy.

### What Behavior Stays Exactly The Same

- `Clear Song` removes the current cue for this player.
- `Clear Custom Announcer` removes only the custom Announcement Cue recording.
- Both actions keep `Are you sure?` confirmations.
- No team/player deletion behavior is added here.

### Owner Decision Needed

Should destructive actions live inside the relevant section, or remain grouped at the bottom?

Recommendation: put each destructive action inside its relevant section, visually separated from primary actions and still confirmed.

## 9. Save / Close Behavior

### Current Problem

The current editor has a local `player` draft and toolbar actions:
- `Close` dismisses the sheet.
- `Save` calls `appModel.updatePlayer(player)` and dismisses.

But not everything is purely draft-based. Some actions call `AppModel` immediately and then refresh local state, including Apple Music assignment, media import, recording, and clear actions. This means "Close without saving" may not always mean "nothing changed."

### Proposed Change

Do not change save/close behavior during visual implementation. Instead, make the UI avoid implying stronger semantics than the app currently has.

Potential future copy to review separately:
- keep `Close` if mixed immediate-save behavior remains
- consider `Done` only if the owner accepts that some actions apply immediately
- add unsaved-change prompts only after a separate persistence decision

### Why This Helps

This avoids accidentally changing draft recovery, media asset writes, recording state, and model refresh behavior while doing a visual redesign.

### What Might Be Lost Or Made Worse

Leaving the current behavior unchanged preserves ambiguity. A user may reasonably think `Close` cancels everything, but media/recording/clear operations may already have changed model or app-owned assets.

### What Behavior Stays Exactly The Same

- Local draft behavior stays.
- `Save` path through `appModel.updatePlayer(player)` stays.
- Async refresh points after media/photo/recording operations stay.
- No autosave, undo, or unsaved-changes prompt is added.

### Owner Decision Needed

Should future implementation preserve the current `Close` / `Save` model exactly, or should Player Editor move toward clearer `Done` / immediate-save semantics?

Recommendation: preserve current behavior for the first visual pass, then make save semantics a separate product decision.

## 10. Section Order

### Current Problem

Current order is:
1. Player
2. Cue Source
3. Announcement Cue
4. More Audio Options
5. Clip Trim
6. Experimental, when enabled
7. Clear Audio

The spec proposes:
1. Player setup summary
2. Identity and Game Day status
3. Song cue setup
4. Custom announcer intro
5. Photo
6. Fine tuning
7. Advanced / destructive actions

There is a conflict: the spec says photo should support identity, but also lists Photo after custom intro. It also separates fine tuning from song cue while the current app uses preview and trim together.

### Proposed Change

Use this review order as the implementation candidate:
1. Setup summary
2. Identity, including photo and presence
3. Song cue
4. Announcement Cue
5. Trim / cue fine-tuning, only when a cue exists
6. Secondary options, including local import if not placed in Song Cue
7. Experimental, only when enabled
8. Destructive actions, either section-local or bottom-grouped based on owner decision

### Why This Helps

It keeps the first screen about the player and whether they can be used. It also keeps trim out of the way until the song exists.

### What Might Be Lost Or Made Worse

This order may still be wrong for teams that use `Announcer Only` heavily. In that mode, Announcement Cue can be more important than song cue.

### What Behavior Stays Exactly The Same

- No navigation, modal, playback, recording, trim, import, or persistence behavior changes.
- This is only information architecture unless separately approved.

### Owner Decision Needed

Which static section order should implementation use?

Recommendation: `Summary -> Identity/photo/presence -> Song Cue -> Announcement Cue -> Trim -> Secondary/Experimental -> Destructive`.

## 11. Local Import Visibility

### Current Problem

Local import currently lives in `More Audio Options` under `Import from Device`, with helper text calling it a fallback path. This supports the Apple Music-first product boundary.

But local import is still important when Apple Music access is unavailable, the desired cue is device-owned, or Apple Music playback remains unreliable on a real subscribed device.

### Proposed Change

Keep local import as a visible secondary fallback inside or adjacent to Song Cue.

Do not make it equal to Apple Music. Do not hide it behind multiple taps.

### Why This Helps

It keeps the main path clean while preserving a real escape hatch.

### What Might Be Lost Or Made Worse

If it appears as a peer primary button, the screen may stop communicating "Apple Music first." If it stays in a disclosure, it may feel like an advanced/debug feature rather than a supported fallback.

### What Behavior Stays Exactly The Same

- Local import remains supported.
- Video-to-audio extraction remains supported.
- Imported local media remains app-owned and package/export compatible.
- Experimental Apple Music local-copy remains separate and off by default.

### Owner Decision Needed

Should local import be:
1. a secondary button in the Song Cue section,
2. a disclosure directly under Song Cue,
3. or left in a separate `More Audio Options` section?

Recommendation: option 2 if the screen feels crowded, option 1 if on-device testing shows fallback discoverability is too weak.

## 12. Trim Prominence

### Current Problem

Trim is a product strength, but the screen should not feel like a media editor. The current controls are useful and somewhat prominent once a cue exists.

### Proposed Change

Make trim visually subordinate to cue selection:
- selected cue status first
- trim summary visible
- detailed controls grouped under `Fine Tune Clip` or similar
- `Advanced` remains a secondary precision action

### Why This Helps

It communicates that Roll Call chooses and plays a short walk-up moment without forcing every user into audio-editing mode.

### What Might Be Lost Or Made Worse

Users may not realize they can adjust the start point if trim is too collapsed or quiet. The app's "right 20 seconds" value could become less visible.

### What Behavior Stays Exactly The Same

- Trim remains available whenever a cue exists.
- The current 20-second and source-specific limits remain unchanged.
- Fine tuning remains reversible through explicit controls, not hidden automation.

### Owner Decision Needed

Should the main editor always show trim controls when a cue exists, or should it show a compact trim summary with a disclosure for detailed controls?

Recommendation: show controls when a cue exists, but use quieter visual hierarchy and the existing `Enable` gate to prevent accidental edits.

## 13. Custom Intro Before Or After Trim

### Current Problem

The current app places Announcement Cue before Clip Trim. The spec says custom intro should be setup, not decoration, but also calls trim fine-tuning after usability.

The unresolved question is whether "usable" means "has a song cue shaped correctly" or "has song and announcement readiness for the selected Game Day mode."

### Proposed Change

Decide order based on product priority:
- If Announcement Cue is core setup, put it before trim.
- If song shaping is the main player setup task, put trim before Announcement Cue.
- If the summary can show missing needs clearly, keep the body order stable and let the summary carry urgency.

### Why This Helps

This prevents the future implementation from accidentally burying a feature that matters in Game Day modes.

### What Might Be Lost Or Made Worse

Dynamic order based on mode might be clever but confusing. A static order is easier to learn. A dynamic "missing items first" order may be useful but risks feeling unstable.

### What Behavior Stays Exactly The Same

- Game Day announcer modes stay unchanged.
- Missing custom intro warnings stay unchanged.
- Song cue and trim behavior stay unchanged.
- No dynamic section reordering is implemented without approval.

### Owner Decision Needed

Should custom intro appear before or after trim?

Recommendation: before trim. The order should be `Song Cue -> Announcement Cue -> Trim`, because song and announcer readiness are setup, while trim is fine-tuning.

## Spec Conflicts And Use-Case Risks

1. The spec says the photo should support identity, but its proposed hierarchy places Photo after Custom Intro. That should be resolved before implementation.
2. The spec treats trim as fine-tuning, but the app's core value includes selecting the right short cue moment. Trim should be visually calmer, not hidden.
3. The current `Close` / `Save` behavior is not a clean cancel/save model because several media actions apply immediately. Any copy or layout that suggests full cancellation would be misleading.
4. Apple Music full-song behavior is still dependent on device subscription, Apple Developer configuration, and provisional playback behavior. The editor must not summarize it as simply "ready" unless existing readiness logic supports that truthfully.
5. Local import is intentionally not primary, but it is still a real fallback. Hiding it too deeply may make the app worse in exactly the situations where Apple Music fails.
6. Announcement Cue copy should remain consistent. The app currently uses `Announcement Cue`; reverting visibly to `Custom Intro` may undo a prior copy cleanup unless explicitly approved.

## Questions For Owner Feedback

1. Should the top setup summary include only status, or status plus one recommended next action?
2. Should the primary presence label remain `Present Today`, or should it become more direct, such as `Show in Game Day`?
3. Should photo stay in the Identity section as a smaller supporting control, or move into its own section?
4. Should local import be a visible secondary action in Song Cue, a disclosure under Song Cue, or remain in `More Audio Options`?
5. Should trim controls be always visible when a cue exists, or should the editor show a compact trim summary first?
6. Should Announcement Cue appear before or after trim?
7. Should destructive actions move into the relevant sections, or stay grouped near the bottom?
8. Should the first implementation preserve current `Close` / `Save` behavior exactly, even though some media actions apply immediately?
9. Should missing photo ever appear in the top setup summary, or stay quiet unless photos become required for a team workflow?
10. Is `Announcement Cue` still the preferred user-facing term, or do you want the editor to use `Custom Intro` in compact places?
11. Should the editor order ever change based on Game Day announcer mode, or should the section order stay static and predictable?
12. What is the most important first-screen outcome: confirming player identity, exposing readiness problems, or getting to song selection quickly?
