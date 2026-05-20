# Data and State

## Primary State Owners

### `AppModel`

- File: `RollCall/AppModel.swift`
- Type: `final class AppModel: ObservableObject`
- Role:
  - app-wide state owner
  - workflow coordinator
  - persistence orchestrator
  - import/export coordinator
  - Apple Music capability/search coordinator
  - lineup/session manager
  - custom announcer recorder coordinator

Published properties:
- `state: AppState`
- `isBusy`
- `lastError`
- `exportURL`
- `pendingRosterImport`
- `supportBundle`
- `announcerRegenerationStatus`
- `appleMusicPlaybackCapability`
- `customAnnouncerRecordingPhase`

### `CuePlaybackEngine`

- File: `RollCall/Services.swift`
- Type: `final class CuePlaybackEngine: NSObject, ObservableObject`
- Role:
  - runtime playback engine
  - active-cue tracking
  - cue prewarming
  - announcer-plus-cue sequencing
  - fade and stop scheduling

Published properties:
- `activeCueID`

## Environment Objects

None found.

The app passes `AppModel` explicitly through view initializers and injects `CuePlaybackEngine` into some subviews as an observed object.

## Local View State

The UI keeps significant local `@State` in `RootView.swift`.

Examples:
- root presentation flags in `RootView`
- selected player and current tab
- `PlayerEditorSheet` local editable `player` copy
- trim mode and trim-edit enablement
- import picker flags
- photo cropper transient state
- Apple Music picker search state

Important consequence:
- some UI flows are editing a local copy and only persist when `Save` or a side-effecting call updates `AppModel`
- other actions write immediately through `AppModel`

This mixed model is workable, but redesign work must distinguish carefully between:
- local draft state,
- immediate model mutation,
- async updates followed by `refreshPlayerFromModel()`.

## Persistence Layer

Primary persistence model:
- `AppState` in `RollCall/Models.swift`

Primary storage paths:
- state file: `Application Support/RollCall/state.json`
- assets directory: `Application Support/RollCall/Assets/`
- snapshots directory: `Application Support/RollCall/Snapshots/`

Path helper:
- `AppPaths` in `RollCall/Models.swift`

Persistence behavior:
- app state is codable JSON
- writes happen through `persist()`
- writes are async via `Task(priority: .utility)`
- writes use atomic file replacement

Snapshot/backup behavior:
- manual backups serialize a full `AppState`
- automatic backup occurs before package import
- newest 10 snapshots are retained

## Core Codable Models

Main app-domain models:
- `CueSource`
- `AppleMusicSource`
- `LocalAudioSource`
- `BuiltInClipSource`
- `Cue`
- `Player`
- `BuiltInClip`
- `TeamSessionState`
- `Team`
- `AppSettings`
- `ExperimentalSettings`
- `TrimDefaults`
- `ReadinessStatus`
- `SnapshotRecord`
- `AppState`
- `TeamPackageManifest`

Important current schema facts:
- `AppState.empty.schemaVersion` is `5`
- app version is stored into state and refreshed on load/init
- package manifest stores exported team plus metadata

## State Ownership by Concern

### Team and player data
- Owner: `AppState`
- Coordinator: `AppModel`

### Batting order and game-day mode
- Owner: `Team.session`
- Coordinator: `AppModel`

### Current selected team
- Owner: `AppState.selectedTeamID`
- Coordinator: `AppModel.selectTeam(_:)`

### Apple Music capability
- Owner: `AppModel.appleMusicPlaybackCapability`
- Source: `MusicCatalogService.playbackCapability()`

### Recent Apple Music selections
- Owner: `AppState.recentAppleMusicSelections`
- Coordinator: `rememberAppleMusicSelection(_:)`

### Preferred trim length
- Owner: `AppState.trimDefaults`
- Coordinator: `rememberPreferredLength(_:)`

### Busy/error UI state
- Owner: `AppModel`

### Active playback state
- Owner: `CuePlaybackEngine`

## Apple Music Integration Points

### Search and metadata
- `MusicCatalogService.search(term:mode:)`
- `MusicCatalogService.catalogBackedResult(for:)`
- `MusicCatalogService.song(for:)`

### Authorization and capability
- `MusicAuthorization`
- `MusicSubscription.current`
- capability mapping:
  - `.fullSong`
  - `.previewOnly`
  - `.unknown`

### Preview fallback
- when full catalog access is not available, the app can fall back to iTunes preview search
- preview results are capped to 20 seconds and flagged `isCatalogBacked = false`

### UI entry points
- `AppleMusicPickerSheet`
- player editor trim help text and cue limits

## Playback and Session Management

Playback backends:
- local and built-in audio: `AVAudioPlayer`
- preview URL playback: `AVPlayer`
- subscribed Apple Music playback: `MPMusicPlayerApplicationController` via `MediaPlayerCatalogPlaybackController`

Playback concerns handled by `CuePlaybackEngine`:
- single active cue rule
- same-cue tap toggles stop
- debounce window
- optional announcer pre-roll
- clip-length stop
- fade-out timing
- prewarming

Session/game-day concerns handled by `AppModel`:
- `nextBatterIndex`
- present-player filtering
- `advanceNextBatter()`
- `setGameDayAnnouncerMode(_:)`
- prewarm next cue after lineup-affecting changes

## Shared Managers and Services

Owned by `AppModel`:
- `audioAssetService`
- `musicCatalogService`
- `packageService`
- `announcerRenderer`
- `haptics`
- `readinessService`
- `playbackEngine`
- `customAnnouncerRecorder`

Notable pattern:
- `AppModel` directly constructs and owns most services rather than injecting them through protocols.
- This makes functionality easy to trace, but it increases coupling and limits isolated previews/tests.

## Legacy and Transitional State

Several legacy/transitional traces remain in the model layer:
- `generatedBuiltInAnnouncerRelativePath`
- legacy announcer payload decoding
- legacy package format compatibility
- team/session migration heuristics

These exist to preserve old data, not because the current product still fully exposes built-in voice flows.

## Risk Areas Where UI and Logic Are Tightly Coupled

1. Player editor local draft + async model refresh
   - `PlayerEditorSheet` edits local `player` state, but several actions also mutate `AppModel` directly and then re-sync.

2. Cue trim behavior
   - trim UI is not just cosmetic; it encodes duration caps, Apple Music capability differences, quarter-second rounding expectations, and live preview timing.

3. Root-level presentation state
   - global alerts, importers, and sheets depend on `RootView` local flags plus `AppModel` state.

4. Persistence timing
   - many actions end with `persist()`, `scheduleReadinessRefresh()`, and `prewarmNextBatterCue()`. Removing or deferring any of these without understanding their role is risky.

5. Announcer mode behavior
   - UI text says “Announcement Cues,” but the logic depends on custom announcement recordings and the selected team session mode.
