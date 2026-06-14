# Roll Call 1.2 Cue Creation And Audio Setup Revamp Handoff

Last updated: 2026-06-10

This document preserves the current decision state for the Roll Call 1.2 cue revamp after Phase 0 probe findings changed the plan. It is intended to be pasted or referenced in a future Codex session so work can resume from the updated truth instead of the original aggressive assumptions.

## Continuation Prompt

Use this file as the source of truth for the Roll Call 1.2 Cue Creation and Audio Setup Revamp.

Important update:

- Phase 0 is complete.
- Phase 0 did not fail. It succeeded with a disappointing result.
- The probe materially narrowed what local clip generation is likely to be able to do with public APIs.
- Do not restart from the old assumption that Roll Call can generally localize Apple Music songs.

Current repo/worktree at the time of this handoff update:

- Current working directory: `/Users/jkfisher/Documents/Coding/Roll Call/rollcall-release-1.2`
- Branch: `Release/1.2`
- Original user plan file: `/Users/jkfisher/Desktop/RollCall_1.2_Cue_Revamp_Plan.md`

## Core Philosophy

The purpose of 1.2 is still to fix the weakest part of Roll Call: selecting, previewing, trimming, and managing walk-up music.

The user-facing goal remains:

> Make picking a walk-up song feel like picking a song.

The revamp should optimize for ease of use, speed, reliability, user confidence, and field-ready Game Day behavior. The architecture may become more sophisticated, but the user experience should become simpler.

The user mental model remains:

- Players have a name, number, photo, announcement, and song.
- Announcement cues stay separate from song clips.
- Users should not need to understand internal clip architecture.
- Game Day remains focused on play/stop and should not become a setup dashboard.
- Advanced truth can exist, but it must be tucked away and only shown when someone wants to dig.

## What Changed After Phase 0

The old plan assumed Roll Call might aggressively create local generated clips for a broad set of Apple Music-backed songs.

Phase 0 materially changed that assumption.

Current understanding:

- Roll Call can reliably generate local clips only when public APIs expose a genuinely readable local file.
- That appears to be much more limited than hoped.
- In practice, the readable cases may mostly be purchased tracks, personally uploaded tracks, imported/local files, and possibly some downloaded library items.
- A downloaded Apple Music-backed song may improve reliability on the current device even when it still does not yield a packageable/generated local clip.
- Source-backed Apple Music playback remains a valid normal outcome for 1.2, not a failure mode, as long as the app is honest about readiness and portability.

The plan must now treat:

- `local clip generation` as a readable-local-media capability,
- `downloaded source-backed playback` as a device-reliability improvement,
- and `Apple Music-linked playback` as a normal supported path with clearer readiness and portability truth.

## Hard Boundaries

Hard rules:

- Use public APIs only.
- Do not hide or disguise what Roll Call is doing.
- Do not use private APIs.
- Do not capture system audio.
- Do not build DRM bypass behavior.
- Do not silently mutate the user's Music Library outside clearly user-approved behavior.
- Do not add a remote kill switch or backend.
- Keep all policy pivots source-controlled.

Important clarification:

- Roll Call should take advantage of legitimate readable-local wins when they exist.
- Roll Call should not build its product promise around unproven Apple Music extraction behavior.

## Biggest Product Reversal

The original 1.2 plan listed Device Music Library as first-class, Apple Music as second-class, and Files/imported audio as third-class. This remains correct and should be strengthened.

Settled priority:

1. Music Library is the primary source assumption.
2. Apple Music is a visible secondary expansion path: "if you have Apple Music, we can go there too."
3. Files/imported audio remains supported, but should feel like an optional fallback for people who want more control or portability, not the "real" path everyone is expected to use.

Important nuance:

- Do not let the plan imply that "to do this properly, you need to import files."
- The Apple Music path has already been working acceptably for many real cases.
- Portability matters, but it must not outweigh ease of use in the primary product story.

When implementation begins, update `docs/DECISIONS.md` to record the approved 1.2 source-priority change and the post-Phase-0 policy narrowing.

## Source Browsing Decisions

The new song picker should still be one integrated `Choose Song` experience, not a separate source picker first.

Music Library browsing should include:

- Recently Added
- Artists
- Albums
- Songs
- Search

Search behavior:

- Search defaults to the device Music Library.
- Search field copy should be `Search Library`.
- Apple Music catalog search is explicit, not automatic.
- In Search mode, show a visible `Library | Apple Music` scope control.
- If Library search has no good result, show a clear action such as `Search Apple Music for "term"`.
- If the user explicitly switches to Apple Music scope, typing can search Apple Music because that is now an explicit Apple Music action.

Apple Music catalog behavior:

- Selecting an Apple Music catalog result does not automatically add it to the user's Music Library.
- Adding a catalog song to the library is not a promised reliability fix.
- If a future `Add to Library` action exists, it should be for user convenience, not sold as "this makes local generation work."

Permission behavior:

- Do not request Music access at app launch.
- Request Music access only when the user enters song picking.
- Show a short one-time primer before the system permission prompt.
- Primer should lead with Music Library, not Apple Music.

Suggested primer copy:

`Roll Call uses Music access so you can choose songs from this iPhone's music library. If you use Apple Music, you can also search Apple Music for songs that are not already in your library.`

If Music access is denied:

- Files import becomes the primary recovery path.
- Show an `Enable Music Access` / `Open Settings` recovery path.
- Apple Music catalog search should remain available only if implementation testing proves it can be used clearly and separately.

## Revised Product Promise

The old implied promise was too broad.

The revised 1.2 promise should be:

`Roll Call makes a local clip when your selected song exposes a usable local file. Otherwise it keeps the original song linked for playback and tells you how reliable that setup is.`

This should be treated as a product principle, not just implementation detail.

## Readiness And Portability Truth

1.2 must distinguish between:

- `Ready on this device`
- `Portable to another device/package`

These are not the same.

Examples:

- A generated local clip can be both ready and portable.
- A downloaded Apple Music-backed song may be ready on this device but not portable.
- A preserved Apple Music link on import may be neither ready nor portable on the receiving device until repaired.

This distinction must shape the model, readiness copy, export warnings, and import audit.

## Local Generation Policy

The old aggressive Apple Music generation plan should no longer be treated as the baseline.

Revised policy:

- Roll Call should generate a local clip whenever the selected source already exposes a readable local file through public APIs.
- Roll Call should not assume that an Apple Music-linked song can usually be turned into a local clip.
- Apple Music-linked songs should normally be treated as source-backed unless a readable local asset is actually present.
- If a downloaded song later becomes readable enough for legitimate local generation, Roll Call may upgrade it to a true generated local clip automatically under the same retry/policy rules.

Practical policy stance for 1.2:

- imported/local files: local generation expected
- readable library media: local generation expected
- Apple Music-linked media without readable local asset: source-backed by default
- downloaded Apple Music-linked media: improved readiness on this device when available, but still not assumed portable

Suggested policy concepts:

- `localClipGenerationEnabled`
- `appleMusicHandlingPolicy = readableLocalOnly`
- `autoDownloadEligibleSongsEnabled`

No remote kill switch.

Non-Release Developer Tools may still expose diagnostics and policy inspection.

## Auto-Download Research And Policy

The question of whether Roll Call can legitimately trigger or request download for eligible songs should remain in the plan, but as a narrow research/implementation branch rather than the foundation of 1.2.

Settled direction:

- Auto-download help should be a Settings option.
- Default: on.
- It should be explained in plain language.
- It exists to improve `ready on this device`.
- It must not be presented as a portability guarantee.
- Internally, if a legitimate download later yields a readable local asset, Roll Call should take advantage of that and generate a portable local clip when allowed.

Suggested setting copy requirement:

`Automatically download eligible songs when possible to improve Game Day reliability. Roll Call only tries this for songs you choose, and you can turn it off.`

Auto-download behavior:

- Only through legitimate public APIs if available.
- Trigger first at clear user-driven moments.
- If the first attempt fails for a retryable reason, allow one or two delayed reattempts.
- No open-ended background retry loop.
- No arbitrary silent attempts days later.

Allowed trigger moments:

- Right after song save/assignment.
- During an explicit `Improve Reliability` or similar action.
- During import repair for a known affected song.

Delayed retries are allowed only because the user has effectively approved the feature through the default-on setting or explicit use of the relevant action.

## App Review Stance

The App Review story should also narrow.

Suggested base wording:

`Roll Call lets users select a short walk-up clip of up to 20 seconds for local game-day playback. When a selected song exposes a usable local file through public APIs, the app can render a local playback asset with fades for reliable live use. Otherwise the app keeps the original song linked for playback and shows the user what is ready on this device and what may depend on Apple Music or network availability.`

Important implication:

- Do not write App Review notes that imply broad Apple Music extraction/localization.
- Be direct about "when possible through public APIs."

## Durable Model Direction

`Cue` should not remain the long-term persisted player song model.

New durable model:

```text
Team
  teamClips: [SongClip]
  Players
    songAssignment: SongAssignment?

SongAssignment
  private clip snapshot OR shared teamClipID
  player-specific override behavior

SongClip
  originalSource metadata
  selected window: start, duration, fadeOut
  generatedAsset status/reference
  playback readiness state
  portability state
  retry metadata
  optional display name for reusable Team Clips

Cue
  internal playback recipe only
```

Settled model principles:

- `SongClip` stores the creative truth.
- Generated local files are disposable playback assets.
- `Cue` remains the object passed into `CuePlaybackEngine`.
- `Cue` should not be the persisted player-song source of truth after migration.
- Existing `Player.cue` values should be decoded and migrated into new player-specific `SongAssignment`s.
- New saves should write the new model, not only `Player.cue`.
- Add tests that fail if new player edits only write old cue state.

The model should be able to express separate truths such as:

- linked to Apple Music
- playable with current membership/access
- downloaded on this device
- local clip ready
- portable in export/import
- preserved as metadata only for later repair

## Generated Asset Model

Generated local assets are disposable derived playback files, not the source of creative truth.

Each `SongClip` should preserve:

- original source metadata
- requested selection
- rendered selection if the app had to adjust to fit available audio
- generated asset reference if ready
- generation status
- readiness summary inputs
- portability summary inputs
- retry metadata
- generation policy/version
- source lineage if edited from an already generated asset

Generation statuses should be designed around the narrowed truth, for example:

- `localClipReady`
- `localClipPending`
- `sourceBackedReady`
- `sourceBackedDownloaded`
- `needsAppleMusic`
- `needsRepair`

Internal sub-statuses may still track transient/permanent failure reasons, but top-level user-facing readiness should stay simpler.

## Generation And Reliability Job Behavior

Saving a clip persists the song selection immediately. Reliability improvement and local generation are queued follow-up work.

Settled behavior:

- Save should not block until generation finishes.
- Save should not fail solely because local generation fails.
- Job truth lives on the clip/model state, not a fragile external queue file.
- One active preparation job at a time is enough for 1.2.
- Manual `Try Now` or `Improve Reliability` can bump a clip forward.
- Preparation pauses during Game Day and Clips.
- Preparation pauses in Low Power Mode unless user explicitly requests it.
- Local/imported/readable device-library clips can generate offline.
- Apple Music-linked preparation may require network or device conditions depending on what is being attempted.
- Every job uses a generation/reliability key.
- Stale results must be discarded.

Safe retry moments:

- after app launch and state load
- returning to foreground
- opening Player Editor
- opening Readiness
- after Music authorization changes
- after import/restore for repairable songs

Unsafe retry moments:

- during live Game Day playback
- during Clips live-use screen
- during Low Power Mode unless user explicitly requests retry

## Generated Asset Rendering

Rendered playback assets should still be M4A/AAC unless testing shows unacceptable latency or quality.

Rendering behavior:

- process internally as needed for fades/envelope
- output final generated playback assets as `.m4a`
- store generation metadata so format can change later and assets can regenerate
- generated local clips should be baked playback files with fades included
- editing always goes back to original source metadata when available

Fade behavior:

- bake a very tiny fade-in by default
- bake fade-out into generated clips
- fade-out remains part of the generation key

Length behavior:

- all 1.2 song clips are capped at 20 seconds
- 20 seconds is flexibility, not the recommendation
- between-inning/team-event cues remain future scope

## Editable Source Behavior

The editor should prefer original full source when available, otherwise the best available proxy, and never be limited to only the generated clip unless that is the only remaining usable source.

Source priority for editing:

1. Original full readable local source
2. Apple Music full/proxy timeline when legitimately available
3. Preview/proxy timeline when only preview is available
4. Existing generated local clip as limited fallback

Repair behavior:

- If original source becomes available again, Roll Call should prefer regenerating from original source rather than repeatedly editing an already-rendered local clip.
- If a downloaded source later becomes readable enough for true local generation, Roll Call may upgrade automatically.
- If mapping is uncertain, preserve the current assignment and offer optional repair instead of guessing.

## Save Semantics

The song flow should remain draft-first with explicit Save.

Flow:

```text
Choose Song -> Clip Editor draft -> Preview/drag/length -> Save
```

Settled behavior:

- choosing a song should not immediately mutate the player
- Save assigns the player song or saves the Team Clip
- after Save, readiness prep and generation begin or queue

## Reusable Team Clips

Reusable clips remain team-scoped for 1.2.

Team Clips behavior:

- Team Clips live under the team in the model.
- Standalone reusable clips should be supported.
- Not every player assignment should automatically become a Team Clip.
- Duplicate detection should be exact and gentle.

Player editing behavior:

- editing from a player should protect the player first
- editing a shared Team Clip from Team Clips can update the shared clip
- editing from a player should default to a player-specific copy when needed

## Source-Backed Apple Music Is Normal, Not Shameful

This is an explicit product rule after Phase 0:

- source-backed Apple Music playback is a normal supported outcome for 1.2
- it is not a second-rate hack
- it should not be presented as "broken" merely because it is not portable
- the app should be honest about its limitations without scaring mainstream users into feeling they must switch to file import

Files/imported audio remain the strongest fallback for maximum control and portability, but that should stay an optional deeper path.

## Game Day And Clips Status

Game Day and Clips must stay operationally calm.

This is a core North Star rule:

- complexity is allowed in the architecture
- complexity is allowed in readiness/import/repair
- complexity is not allowed to spill onto the live Game Day path

Playback choice:

- use generated local asset if ready
- use source-backed playback otherwise
- use existing fallback behavior if no song is playable

Game Day should mostly reduce truth to simple operational states such as:

- ready
- works here
- needs attention before game time

Do not surface full dependency trees on the live screen.

## Readiness As The Translation Layer

Readiness should be the main place where Roll Call translates messy audio truth into simple coaching guidance.

Layering:

- Picker/editor: choose and shape the song
- Readiness: explain whether it is dependable
- Import/repair: fix broken or limited cases
- Game Day: stay simple and live-focused

Readiness should have two levels:

1. Primary simple label
2. Optional deeper explanation on tap

Candidate simple labels:

- `Ready`
- `Ready Here`
- `Needs Apple Music`
- `Needs Repair`

Candidate deeper explanations:

- downloaded on this device
- not portable in exports
- linked song preserved but not playable here
- local clip included

Readiness should also distinguish urgency:

- `Fix now`: threatens live use on this device
- `Can wait`: works here, but could be improved
- `Info only`: deeper explanation for users who choose to inspect

## Player Editor, Settings, And Advanced Surfaces

Detailed generation/policy state should live:

1. in Readiness first
2. in Player Editor / Clip Editor second
3. in Settings / Developer Tools only for diagnostics and advanced controls

Settings should include:

- the plain-language auto-download option
- any future user-facing reliability preference that is worth exposing

Developer Tools may include:

- policy flags
- diagnostics
- manual retries
- probe surfaces

## Export And Import

New 1.2 `.rollcall` packages may require 1.2+ when they contain the new Team Clips model.

Compatibility:

- 1.2 must continue importing older packages
- 1.2 packages with new song clip model do not need to import into 1.1
- avoid degraded compatibility export that flattens truth

Hard export rule:

- only true generated local clips should be treated as packageable portable assets
- a downloaded source-backed song must not be treated as portable just because it is available on this device

Export should include:

- team clip library
- player assignments
- generated local assets when present and allowed
- original source metadata for every clip
- readiness/repair-relevant status where useful

Export-side warning is required.

Suggested export preview copy:

`Some songs may not work for the recipient unless they have Apple Music or similar access to the linked songs. Local clips are included only when Roll Call has generated them.`

Suggested export preview rows:

- `Local clips included: X`
- `Works here only: X`
- `Needs Apple Music: X`
- `Still preparing: X`

If pending jobs exist, offer:

`Try Preparing Clips First`

## Import Audit And Repair

Import must no longer be treated as just "did the file open."

1.2 should include an import audit that tells the recipient what actually arrived in a playable state on this device.

Suggested import outcomes:

- `Local clip included`
- `Apple Music link restored`
- `Needs Apple Music`
- `Song could not be restored here`

Important import rule:

- if an imported Apple Music-linked song cannot play here, preserve the assignment metadata when possible instead of dropping it
- mark it as not playable here
- explain why
- offer repair paths

That preserves setup work and reduces destructive loss.

Repair should be a first-class flow, not an edge-case error.

Repair actions may include:

- replace song
- relink to Apple Music on this device
- recheck Apple Music access and source availability
- regenerate local clip if a readable asset later appears

Receiving device rules:

- included generated local clips should work without Apple Music
- Apple Music-linked references should not be presented as ready unless the receiving device actually satisfies the requirements
- if the receiver lacks Apple Music, messaging must say that plainly

## Generated Asset Store And Cleanup

Generated assets should still live in an app-wide generated asset store, referenced by team-scoped clips.

Suggested area:

`Application Support/RollCall/GeneratedClips/`

Cleanup policy:

- implement automatic conservative cleanup
- only remove generated files with no references anywhere
- delete failed temp files immediately
- retain extra files if uncertain

Cleanup must retain generated assets referenced by:

- active teams
- Team Clips
- player-specific assignments
- Recently Deleted retention
- pending/retry jobs
- backup snapshots if current backup behavior references asset files

## Support Bundle And Privacy

Support bundles should include redacted generation/readiness diagnostics but no audio files.

Include:

- counts by status
- source type counts
- retry counts
- last failure categories
- total generated asset disk usage
- active policy flags

Exclude by default:

- audio files
- song titles/artists
- player names/team names
- raw identifying source IDs when possible

## Phase 0: Music Render Probe

Phase 0 is complete.

Purpose:

Prove which Music Library and Apple Music items can actually be rendered through public APIs inside the real app context.

Outcome:

- the probe succeeded in narrowing reality
- broad aggressive Apple Music local generation is not a safe baseline assumption for 1.2
- readable-local generation remains valid and important
- downloaded/source-backed reliability is now a separate concern from portability

Phase 0 findings should now be treated as inputs to the rest of the plan, not an open prerequisite.

Phase 0 deliverables:

- `docs/engineering/music-render-probe-1.2.md`
- a `docs/DECISIONS.md` entry choosing the narrowed initial 1.2 generation/reliability policy
- candidate user-facing status language for readiness/export/import/repair

## Implementation Phases

### Phase 1: Models And Migration

Add:

- `SongClip`
- `SongAssignment`
- `SongSource`
- `GeneratedClipAsset`
- readiness state inputs
- portability state inputs
- retry metadata
- generation/reliability policy flags

Migrate:

- existing `Player.cue` -> private player `SongAssignment`
- do not automatically promote existing cues to Team Clips
- decode old packages/state
- encode new model for 1.2

Tests:

- old state migration
- existing teams still open/play
- existing packages still import
- new player edits do not only write `Player.cue`

### Phase 2: Generation And Reliability Engine

Status: complete as of 2026-06-10, with the Apple Music download-request branch closed as unsupported by public APIs.

Add:

- `SongClipGenerationService`
- `SongClipGenerationQueue`
- reliability-prep behavior for source-backed songs
- generation key
- one-job-at-a-time queue
- retry/backoff
- pause/resume rules
- cancel/key validation

Scope:

- local generation for readable-local media
- bounded reliability work for Apple Music-linked songs
- optional auto-download help if legitimate API support exists

Phase 2 result:

- readable app-owned and device-library sources can render generated `.m4a` clips
- preparation is serialized, key-validated, retry-bounded, and paused around live use/Low Power Mode
- existing ready generated assets survive failed regeneration attempts
- Apple Music library state and readable `assetURL` availability can be observed
- iOS exposes no public API to request or control an Apple Music offline download
- `MPMediaLibrary.addItem(withProductID:)` only adds to the library and is not used as a download substitute
- `autoDownloadEligibleSongsEnabled` remains off because the promised behavior cannot be implemented honestly
- generated-clip package/export/import handling remains Phase 5

Tests:

- generation status transitions
- retryable vs permanent failures
- stale result discard
- old generated asset rollback/safety
- source-backed readiness transitions
- downloaded-to-generated upgrade path if supported

### Phase 3: Picker And Editor

Status: implemented on 2026-06-10; simulator build, launch, navigation smoke check, and the existing 59-test executed suite pass. A high-level physical-device check passed on 2026-06-14; broader real-device edge-case verification remains in Phase 6.

Create reusable flow:

- `SongPickerView`
- `SongClipEditorView`
- `SongShapeRailView`
- supporting services/view models

Picker:

- Music Library first
- Recently Added, Artists, Albums, Songs, Search
- Search scope: Library | Apple Music
- Apple Music explicit
- Files fallback
- permission primer

Editor:

- draft-first explicit Save
- interactive song-shape rail
- full selected window
- length chips including 20s
- preview selected clip
- advanced trim retained
- readiness/result summary after save

Implemented notes:

- `SongPickerFlow.swift` contains the native Music library picker bridge, native-style Apple Music catalog search, reusable draft editor, and song-shape rail.
- The original custom Music Library category dashboard was replaced after simulator review. Player Editor now exposes native Music Library selection first, explicit Apple Music catalog search second, and Files third.
- Music permission remains just-in-time and uses the approved Library-first primer.
- Library songs need a usable Apple playback/store identifier for the current Apple Music cue/playback model. Rows without one remain visible but unavailable rather than creating an unreliable saved cue.
- Imported files are copied into an unsaved draft, removed if the draft is cancelled, and assigned only after Save.
- Saving updates only the player's song assignment and starts the Phase 2 preparation queue.
- The Player Editor now reports `Preparing`, `Ready`, `Ready Here`, `Needs Apple Music`, or `Needs Repair`.

### Phase 4: Team Clips

Status: implemented on 2026-06-14 in build 67; simulator build/run, Team Clips UI smoke check, 23 focused tests, and the full 73-test executed serial suite pass.

Add:

- Team Clips list/section
- standalone clip creation
- custom names
- exact duplicate detection
- shared/private assignment behavior
- copy-safe player editing
- protected deletion choices
- advanced `Save Player Songs to Team Clips` tool

Implemented notes:

- Team Clips live on the Teams tab and can be created independently through Music Library, Apple Music search, or Files using the Phase 3 draft editor.
- Clips support custom names, exact creative duplicate reuse, and explicit shared player assignment.
- Player Editor offers Team Clips as a source. Shared clips display as shared and require `Make Player Copy to Edit` before player-specific editing.
- Editing from Team Clips updates the shared clip intentionally.
- Deleting an assigned Team Clip offers to keep private player copies or remove the clip from those players.
- The advanced promotion tool converts private player songs into shared Team Clips and reuses exact matches.
- Shared assignments resolve through playback, readiness, package previews, roster surfaces, and Apple Music playlist summaries.
- Team Clip asset references participate in conservative cleanup protection.

### Phase 5: Readiness, Playback, Export, Import, Repair

Status: implemented on 2026-06-14 in build 68. Generated local clips are preferred when valid, shared Team Clips now enter the same bounded preparation queue as private player clips, readiness distinguishes portable/device-dependent/repair states, export previews package truth, generated assets round-trip, import audits receiving-device outcomes, and missing-but-identifiable assignments are preserved for repair.

Playback:

- generated local asset if ready
- source-backed playback otherwise
- `Cue` remains internal playback recipe

Readiness:

- team-level simple guidance
- fix-now vs can-wait distinction
- deeper detail on tap

Game Day/Clips:

- operational truth only
- quiet paused-prep status if useful
- no per-player prep spinners

Export:

- include packageable generated local clips
- warn clearly about Apple Music-linked limitations

Import:

- import audit required
- preserve broken-but-identifiable assignments when possible
- offer repair

Repair:

- first-class flow, not an afterthought

### Phase 6: Cleanup And Verification

Status: implementation and automated verification completed on 2026-06-14 in build 68. Conservative cleanup, non-Release inspection/manual cleanup, redacted support diagnostics, package portability/import audit/repair coverage, Debug launch, public Release build, and the full 88-test executed serial suite pass. The remaining release gate is physical/manual verification: the simulator automation bridge cannot tap its visible Settings row, and real Music Library, Apple Music, AirDrop/cross-device portability, and audible repair behavior require physical devices.

Add:

- conservative generated asset cleanup
- diagnostics/manual cleanup in non-Release
- support bundle redacted diagnostics
- full regression coverage

Verification:

- unit tests for model, migration, generation, package, cleanup
- simulator smoke for picker/editor/readiness/import
- real-device feel pass for Music Library and Apple Music behavior
- export/import portability smoke
- repair-flow smoke
- App Review wording review

## Proposed File Split

Add new files instead of growing `RootView.swift` further:

- `RollCall/SongClipModels.swift`
- `RollCall/SongLibraryService.swift`
- `RollCall/SongClipGenerationService.swift`
- `RollCall/SongClipGenerationQueue.swift`
- `RollCall/SongPickerView.swift`
- `RollCall/SongClipEditorView.swift`
- `RollCall/SongShapeRailView.swift`
- `RollCall/TeamClipsView.swift`
- readiness/import-repair views/services as needed

## Tests First

Implementation should still start with model/service tests before broad UI work.

Priority test areas:

- legacy `Player.cue` migration
- SongAssignment private vs shared behavior
- generation key equality
- readiness/portability classification
- retry status/backoff
- package import/export honesty
- generated asset inclusion/exclusion by policy
- downloaded-is-not-portable rule
- preserved-assignment import repair
- conservative cleanup
- source-backed playback recipe creation
- support diagnostics redaction

## Open Work At Handoff

The implementation phases are complete. Do not restart Phase 0 through Phase 6.

Next action:

Run the final physical-device/manual 1.2 verification checklist, fix only concrete failures, and then prepare release notes and the App Store submission build.

Before coding:

- report cwd, branch, and `git status --short`
- review relevant conditional rules: Apple APIs, user data/permissions, diagnostics privacy, and build/release context if needed
- provide a short implementation plan, expected files, dependencies/permissions, and risk level

Implementation sequencing recommendation:

1. Verify Music Library and Apple Music playback states on-device.
2. Export a mixed portable/source-linked team and import it on another device.
3. Exercise Player and Team Clip repair plus conservative manual cleanup with disposable data.
4. Re-run the full suite after any device-driven fix, then update release notes.

Do not re-open the old broad aggressive Apple Music generation assumption unless new public-API evidence clearly proves more than Phase 0 found.
