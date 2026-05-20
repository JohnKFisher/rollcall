# Functionality Protection Zones

This is the most important file in this package.

The areas below should not be casually touched during future UI redesign work. They are either timing-sensitive, state-sensitive, compatibility-sensitive, or coupled to platform behavior that the UI only partially reveals.

## 1. `CuePlaybackEngine`

- File: `RollCall/Services.swift`
- Risk level: very high

Why it is risky:
- Controls the app’s core job: actually playing cues.
- Combines multiple playback backends:
  - `AVAudioPlayer`
  - `AVPlayer`
  - `MPMusicPlayerApplicationController`
- Enforces one-active-cue behavior.
- Handles same-button retap stop behavior.
- Applies debounce.
- Sequences optional announcer audio before the main cue.
- Schedules fades and stop timing asynchronously.

How future UI work should interact safely:
- Treat it as a black-box runtime engine unless there is a deliberate playback project.
- UI changes should call existing entry points (`play`, `stop`, `prewarm`, `previewAsset`) rather than recreating playback logic in views.
- Do not change timing constants, task cancellation behavior, or fade math as part of visual redesign.
- If a new design changes button press cadence or adds repeated gesture-triggered previews, regression-test debounce and repeated-tap behavior.

## 2. Apple Music Capability and Search Gating

- Files: `RollCall/AppModel.swift`, `RollCall/Services.swift`
- Risk level: very high

Why it is risky:
- Apple Music in this app is not a single mode.
- The UI changes behavior based on:
  - authorization state,
  - playback subscription capability,
  - MusicKit App Service availability,
  - whether a result is catalog-backed or preview-only.
- The picker/trim UI would become dishonest if redesign work hides or blurs these distinctions.

How future UI work should interact safely:
- Preserve the distinction between:
  - full-song catalog-backed selection
  - preview-only fallback selection
- Preserve capability banner/guidance somewhere visible.
- Do not replace the current flow with a generic “search and play” UI without carrying forward capability messaging and the 20-second cap rules.
- Treat `appleMusicPlaybackCapability`, `isCatalogBacked`, and preview URL presence as product-critical state, not implementation noise.

## 3. MediaPlayer Catalog Playback Backend

- File: `RollCall/Services.swift`
- Risk level: very high

Why it is risky:
- Full-song Apple Music playback currently depends on a provisional internal `MediaPlayer` path.
- It uses KVC volume setting (`setValue(_:forKey: "volume")`) to approximate stepped fade behavior.
- Project status explicitly says this path is still unproven on a real subscribed device.

How future UI work should interact safely:
- Avoid changing UI copy in a way that over-promises fade behavior for subscribed Apple Music playback.
- Do not assume preview behavior and full-song behavior are equivalent.
- Any redesign that changes full-song preview, playback transport, or trim-preview expectations should require explicit human approval and on-device testing.

## 4. `PlayerEditorSheet`

- File: `RollCall/RootView.swift`
- Risk level: very high

Why it is risky:
- This is the most behavior-dense UI in the app.
- It coordinates:
  - local player draft state
  - Apple Music selection
  - trim presets
  - advanced trim
  - local media import
  - photo import/crop
  - custom announcer recording
  - experimental local-copy path
  - destructive clear actions
- Many of these flows interact asynchronously and then refresh local view state from `AppModel`.

How future UI work should interact safely:
- Keep redesign changes incremental.
- Prefer extracting purely visual wrappers first, while keeping existing action wiring.
- Do not rewrite this screen wholesale before establishing feature-by-feature tests/checklists.
- Preserve the existing `refreshPlayerFromModel()` points and state transitions until they are deliberately replaced with a clearer model.

## 5. Custom Announcement Cue Recording and Storage

- Files: `RollCall/AppModel.swift`, `RollCall/Services.swift`
- Risk level: high

Why it is risky:
- Recording changes audio session category and state.
- Save logic validates that the flat stored file exists and is non-empty.
- Playback later depends on that exact stored asset path existing.
- UI labels and readiness checks depend on stored-file existence, not just a flag.

How future UI work should interact safely:
- Do not redesign recording controls without preserving the state machine:
  - starting
  - recording
  - stopping
  - idle
- Keep “missing file” states visible somewhere.
- Do not convert announcement cue storage to ephemeral or draft-only behavior without an explicit product/storage decision.

## 6. App-Owned Persistence Paths and Path Validation

- Files: `RollCall/Models.swift`, `RollCall/Services.swift`
- Risk level: high

Why it is risky:
- The app depends on specific Application Support layout:
  - `state.json`
  - `Assets/`
  - `Snapshots/`
- `AppPaths.assetURL(relativePath:)` prevents unsafe path traversal and absolute-path use.
- Package import/export and readiness checks assume this asset model.

How future UI work should interact safely:
- UI redesign should continue to treat media as app-owned internal assets once imported.
- Do not surface or depend on raw absolute filesystem paths in UI state.
- Any change to storage layout, file naming, or asset retention needs separate approval and migration planning.

## 7. Package Export/Import Compatibility

- File: `RollCall/Services.swift`
- Risk level: high

Why it is risky:
- `.rollcall` export/import is a real portability feature, not just a convenience.
- Current behavior supports:
  - zipped single-file archive export
  - backward-compatible import of old directory-style packages
- Export copies local media, custom announcement cues, and photos into package assets.
- Import rewrites assets into app-owned storage and remaps relative paths.

How future UI work should interact safely:
- UI redesign can restyle package actions freely, but should not change package semantics without explicit approval.
- Preserve clear distinction between:
  - export/share
  - import
  - backup/restore
- Do not merge package import with backup restore in a way that confuses their data effects.

## 8. Lineup Normalization and Next-Batter Logic

- File: `RollCall/AppModel.swift`
- Risk level: high

Why it is risky:
- Batting order persistence is product-approved behavior.
- The app preserves manual order across launches and only auto-alphabetizes before customization.
- Present-player filtering affects `nextBatterIndex`.
- Reorder, sort, duplicate, import, and restore all feed the same normalization rules.

How future UI work should interact safely:
- Redesign row visuals, drag handles, and labels freely only if move semantics remain identical.
- Do not add hidden auto-sorting, implicit reset behavior, or layout-driven reorder side effects without explicit approval.
- Regression-test:
  - reorder
  - sort
  - present toggle
  - duplicate team
  - import roster
  - restore backup

## 9. Readiness Calculations

- File: `RollCall/Services.swift`
- Risk level: medium-high

Why it is risky:
- Readiness is a reliability surface, not decoration.
- It checks:
  - audio route
  - volume
  - network
  - Apple Music auth
  - present-player coverage
  - cue asset existence
  - custom announcement cue file existence
  - photo existence

How future UI work should interact safely:
- Keep the underlying readiness semantics intact even if the presentation changes.
- Avoid “greenwashing” warnings into softer language without product approval.
- Preserve the difference between warning, failed, ready, and unknown states.

## 10. Photo Import and Crop Fallback

- File: `RollCall/RootView.swift`
- Risk level: medium-high

Why it is risky:
- There is a timed fallback that saves the original photo if the cropper does not render within 1.5 seconds.
- This is user-protective behavior, but it is subtle and easy to break if the photo flow is restructured.

How future UI work should interact safely:
- If this flow is redesigned, explicitly decide whether to keep, remove, or replace the timed fallback.
- Do not accidentally create a state where photo import appears successful but no asset is saved.

## 11. Global Busy/Error Overlay Model

- Files: `RollCall/RootView.swift`, `RollCall/AppModel.swift`
- Risk level: medium

Why it is risky:
- `isBusy` and `lastError` are global UX channels used by many workflows.
- Redesign work that localizes or suppresses them can hide failures from import/export/Apple Music/recording flows.

How future UI work should interact safely:
- It is safe to restyle the busy and error surfaces.
- It is not safe to remove them without replacing their visibility and timing behavior.

## 12. Built-In Voice Legacy/Transitional Code

- Files: `RollCall/AppModel.swift`, `RollCall/Models.swift`
- Risk level: medium

Why it is risky:
- Product decisions say built-in voice has been removed from the active product path.
- But legacy fields, decoders, generation code, and data migration traces still exist.
- A redesign could incorrectly assume these are dead and remove them, breaking backward compatibility or older saved state.

How future UI work should interact safely:
- Treat these as “transitional compatibility code” until a deliberate cleanup project is approved.
- Do not casually delete legacy announcer fields or migration logic during a visual pass.
