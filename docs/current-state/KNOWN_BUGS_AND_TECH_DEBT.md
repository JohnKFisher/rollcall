# Known Bugs and Tech Debt

This file combines confirmed issues, provisional areas, transitional logic, and structural debt observed during this documentation pass.

## Known or Explicitly Acknowledged Functional Risks

### 1. Full-song Apple Music playback remains provisional

- Source: `docs/WHERE_WE_STAND.md`, `RollCall/Services.swift`
- Detail:
  - subscribed full-song playback now uses an internal `MediaPlayer` backend
  - project status still says the path is unproven on a real subscribed device
- Risk:
  - fade behavior and repeat-play start positioning may still be wrong on-device

### 2. Apple Music feature correctness depends on external Apple configuration

- Source: `docs/WHERE_WE_STAND.md`, `docs/DECISIONS.md`
- Detail:
  - MusicKit App Service and signing/provisioning are required for the intended full-song path
- Risk:
  - the UI can be correct while the environment still blocks the real behavior

### 3. Photo cropper fallback may save uncropped image

- Source: `RollCall/RootView.swift`
- Detail:
  - if cropper rendering is delayed, a timer saves the original image and reports an error
- Risk:
  - user can end up with an uncropped photo even though they initiated a crop flow

## Temporary / Transitional Implementations

### 4. Built-in voice removal is incomplete at code-cleanup level

- Source: `RollCall/AppModel.swift`, `RollCall/Models.swift`
- Detail:
  - user-facing built-in voice paths now return “removed from Roll Call”
  - legacy announcer fields and generation functions still exist
- Interpretation:
  - this looks intentional as a compatibility bridge, not a completed cleanup

### 5. MediaPlayer volume control uses KVC

- Source: `RollCall/Services.swift`
- Detail:
  - `player.setValue(volume, forKey: "volume")`
- Risk:
  - clearly marked in code as a provisional on-device experiment
  - future OS behavior could make it brittle

### 6. Apple Music local-copy path is intentionally experimental

- Source: `RollCall/RootView.swift`, `RollCall/AppModel.swift`, `docs/DECISIONS.md`
- Detail:
  - hidden behind an explicit developer-facing toggle
  - not the primary product path
- Risk:
  - easy for redesign work to accidentally surface too prominently or treat as supported default behavior

## Structural Tech Debt

### 7. `RootView.swift` is oversized

- File size: ~2011 lines in this checkout
- Problem:
  - most user-facing screens and many helper views live in one file
- Risk:
  - visual edits can have broad unintended side effects

### 8. `AppModel.swift` is also oversized and highly central

- File size: ~1500 lines
- Problem:
  - app state ownership, persistence, playback coordination, imports, Apple Music flows, lineup logic, backups, and recording coordination all converge here
- Risk:
  - future redesign work may accidentally become architectural surgery

### 9. No obvious automated test coverage in this repo snapshot

- Observed from file inventory
- Risk:
  - UI redesign work will rely heavily on manual smoke testing unless tests are added later

## Fragile Logic Areas

### 10. Mixed local draft state and immediate model mutation in Player Editor

- Source: `RollCall/RootView.swift`
- Problem:
  - some controls update local `player`
  - some actions call `AppModel` immediately and then re-read model state
- Risk:
  - save/dismiss behavior can become inconsistent after redesign if local and persisted states drift

### 11. Global error handling is coarse

- Source: `RollCall/AppModel.swift`, `RollCall/RootView.swift`
- Problem:
  - many unrelated failures funnel into `lastError`
- Risk:
  - multi-step redesign flows may surface errors in confusing contexts

### 12. Readiness refresh is partly deferred/coalesced

- Source: `RollCall/AppModel.swift`
- Problem:
  - some operations call `scheduleReadinessRefresh()`, some `refreshReadiness()`, some both through `busy`
- Risk:
  - changing timing or removing refreshes can produce stale state

## Dead-Code Candidates or Cleanup Candidates

These are candidates, not confirmed-safe removals.

### 13. `movePlayers(from:to:)`

- Source: `RollCall/AppModel.swift`
- Observation:
  - no current UI use was found during this pass

### 14. Built-in announcer generation pipeline

- Source: `RollCall/AppModel.swift`
- Observation:
  - substantial generation/render code remains despite built-in voice removal from the active product path
- Caution:
  - legacy data compatibility and future reconsideration may be why it remains

### 15. `generatedBuiltInAnnouncerRelativePath`

- Source: `RollCall/Models.swift`
- Observation:
  - appears primarily legacy/transitional in the current product shape

## Duplicate or Inconsistent Product Signals

### 16. Announcer product history is visible in code/data

- `docs/DECISIONS.md` includes a superseded announcer decision and a later approval removing built-in voice from the product for now.
- Model and renderer code still retain older announcer concepts.
- This is not necessarily wrong, but it is a current-state inconsistency future redesigners need to know about.

### 17. Visual polish level varies sharply by screen

- Launch screen and Game Day are more branded.
- Settings/Recovery/Readiness are much more utilitarian.
- This inconsistency is a design debt item, not a runtime bug.

## Build / Environment Issues Observed During This Documentation Pass

### 18. Simulator visual capture could not be completed in this session

- Tool path attempted: XcodeBuildMCP `build_run_sim`
- Failure:
  - `unable to resolve module dependency: 'ZIPFoundation'`
  - incompatible built module target warnings in the local environment
- Interpretation:
  - this blocked screenshot capture in this session
  - it does not by itself prove a source-level runtime bug in the app
