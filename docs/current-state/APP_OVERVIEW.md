# App Overview

## What the App Does

`Roll Call` is an iPhone-first walk-up music app for softball/baseball game-day use.

Current product shape:
- choose or create a team,
- add players,
- assign each player a song cue,
- optionally record a per-player custom announcement cue,
- mark players present,
- manage batting order,
- enter `Game Day`,
- tap a player to play either:
  - cue only, or
  - custom announcement cue followed by the player cue.

The app also includes:
- a built-in crowd-clip library (`General Clips`),
- readiness checks,
- backup/restore,
- `.rollcall` package export/import,
- CSV roster import,
- developer-facing experimental controls and support-bundle export.

## Primary User Workflows

1. Team setup
   - Create/select a team in `Teams`
   - Add players in `Players`
   - Optionally import roster CSV

2. Cue assignment
   - Open a player sheet from `Players`
   - Choose an Apple Music song or import device-owned media
   - Trim the clip
   - Optionally record a custom announcement cue
   - Save

3. Lineup prep
   - Open `Game Day`
   - Adjust lineup order in `Today’s Lineup`
   - Mark players present or absent
   - Choose `Cue Only` or `Announcement Cues`

4. Live use
   - Tap players in `Game Day`
   - Advance the next batter
   - Stop playback if needed

5. Recovery and portability
   - Export selected team as `.rollcall`
   - Import `.rollcall`
   - Create manual backups
   - Restore backups

## Main App Modes and Screens

- `Players`
- `Clips`
- `Game Day`
- `Readiness`
- `Teams`
- `Settings`

Major secondary screens:
- `PlayerEditorSheet`
- `AppleMusicPickerSheet`
- `AdvancedTrimSheet`
- `BasicPhotoCropperSheet`
- `LineupEditorSheet`
- `RecoveryCenterView`
- `DeveloperToolsView`

## Current Architectural Style

This is a pragmatic, code-first SwiftUI prototype with a deliberately small file count.

Current shape:
- UI entry point: `RollCall/RollCallApp.swift`
- Primary UI composition: `RollCall/RootView.swift`
- Main state owner and app coordinator: `RollCall/AppModel.swift`
- Models and persistence structs: `RollCall/Models.swift`
- Platform/services/audio/import/export logic: `RollCall/Services.swift`

Architectural characteristics:
- one root `ObservableObject` (`AppModel`) drives nearly all app state,
- one secondary `ObservableObject` (`CuePlaybackEngine`) exposes playback activity,
- no `EnvironmentObject` graph,
- no formal reducer/store architecture,
- no separate feature folders,
- many user flows are coordinated directly from view code through async calls into `AppModel`.

This makes the app readable in one pass, but it also means UI structure and product behavior are tightly interleaved.

## Current Strengths

- Functional surface is concentrated in a few files, so the app is inspectable.
- Core product workflows are already present end-to-end.
- App-owned asset storage reduces dependence on external file paths.
- Apple Music path is subscription-aware rather than pretending preview-only and full-song access are the same.
- Readiness checks and backup flows show reliability-first product thinking.
- Package export/import includes copied local assets rather than path references.
- Game Day uses a distinct, intentionally bigger interaction surface rather than reusing generic list rows.

## Known Instability Areas

- Full-song Apple Music playback is still marked provisional in project status and uses an internal `MediaPlayer` backend workaround.
- Apple Music behavior depends on real device authorization, subscription state, and MusicKit App Service setup.
- `RootView.swift` is very large, so layout changes can accidentally affect behavior.
- `PlayerEditorSheet` has many local state variables and multiple modal/file-picker/photo-picker branches.
- Photo cropping has a timed fallback that saves the uncropped image if the cropper does not render quickly.
- Packaging/build tooling in this session could not produce simulator screenshots because `ZIPFoundation` module resolution failed in the local environment.

## Dependencies, Services, and Frameworks

Apple/system frameworks in use:
- `SwiftUI`
- `UIKit`
- `Foundation`
- `AVFoundation`
- `AVFAudio`
- `PhotosUI`
- `MusicKit`
- `MediaPlayer`
- `Network`
- `UniformTypeIdentifiers`

Third-party package:
- `ZIPFoundation`

Internal service groupings:
- `AudioAssetService`
- `MusicCatalogService`
- `CuePlaybackEngine`
- `ReadinessService`
- `PackageService`
- `CustomAnnouncerRecorder`
- `AnnouncerSpeechRenderer`

## Areas Likely Coupled Tightly to Functionality

- `PlayerEditorSheet` trim and cue-source UI
- `CuePlaybackEngine` playback/timing/debounce/fade behavior
- `AppModel` lineup normalization and persistence timing
- `MusicCatalogService` Apple Music search and capability gating
- `PackageService` import/export compatibility logic
- `AppPaths` asset/state/snapshot storage layout
- readiness status generation for missing assets and Apple Music conditions
