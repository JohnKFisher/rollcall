# Screen Inventory

This inventory focuses on every user-facing screen, sheet, full-screen cover, and system presentation path visible in the current app.

## 1. Launch Screen

- Screen name: Launch Screen
- File(s): `RollCall/LaunchScreen.storyboard`, `RollCall/Assets.xcassets/John.imageset/John.heic`
- Purpose: branded startup surface before SwiftUI loads
- Entry points: app launch
- Main controls/buttons: none
- Data dependencies: none
- Visual/layout observations:
  - dark navy background
  - centered square card
  - large circular-ish hero image (`John`)
  - heavy uppercase `ROLL CALL`
  - subheading `GAME DAY • CUES`
- Known UX problems:
  - visually more stylized than most in-app screens
  - branding tone does not fully match the mostly utilitarian in-app lists/forms
- Stable or fragile: stable
- Screenshots: no live capture in this session; code/storyboard inspected directly
- Related components: none

## 2. Root Tab Shell

- Screen name: Root Tab Container
- File(s): `RollCall/RootView.swift`
- Purpose: hosts the six primary tabs and global overlays/alerts/sheets
- Entry points: app launch after `RollCallApp`
- Main controls/buttons:
  - `Players`
  - `Clips`
  - `Game Day`
  - `Readiness`
  - `Teams`
  - `Settings`
- Data dependencies: `AppModel`, global busy state, global error text, pending roster import state
- Visual/layout observations:
  - orange app-wide tint
  - system tab bar
  - global busy capsule overlay near the top
- Known UX problems:
  - many unrelated alerts/sheets are attached at root level
  - root container is responsible for both navigation and cross-cutting workflow state
- Stable or fragile: fragile
- Screenshots: unavailable from live run
- Related components: roster preview sheet, package import picker, global alerts

## 3. Players Tab

- Screen name: Players
- File(s): `RollCall/RootView.swift`
- Purpose: player roster management and entry point into detailed player editing
- Entry points:
  - tab bar
  - default selected tab on launch
- Main controls/buttons:
  - quick add fields
  - `Add Player`
  - player rows
  - swipe action: `Mark In` / `Mark Out`
- Data dependencies:
  - `appModel.selectedTeam`
  - player cue/custom-intro status
  - player photos from app storage
- Visual/layout observations:
  - standard `NavigationStack` + `List`
  - quick add section at top
  - roster rows show photo, player identity, cue status chip, announcement cue status chip
- Known UX problems:
  - row status is information-dense
  - cue and announcer status rely partly on color chips
  - alphabetical sort is hard-coded for display, not a user-configurable view
- Stable or fragile: medium stability
- Screenshots: unavailable from live run
- Related components:
  - `PlayerQuickAddView`
  - `PlayerPhotoThumbnail`
  - `PlayerEditorSheet`

## 4. Player Quick Add

- Screen name: Player Quick Add
- File(s): `RollCall/RootView.swift`
- Purpose: fast entry of player name and uniform number
- Entry points: top of `Players`
- Main controls/buttons:
  - `Player name`
  - `Number`
  - `Dismiss Keyboard`
  - `Add Player`
  - keyboard toolbar `Done` / `Add`
- Data dependencies: `appModel.addPlayer`
- Visual/layout observations:
  - compact inline form
  - designed for repeated use
- Known UX problems:
  - number input uses number pad, so keyboard accessory buttons matter a lot
- Stable or fragile: stable
- Screenshots: unavailable
- Related components: keyboard-dismiss overlay

## 5. Player Editor Sheet

- Screen name: Player Editor
- File(s): `RollCall/RootView.swift`
- Purpose: core per-player setup/editing screen
- Entry points:
  - tap player row in `Players`
- Main controls/buttons:
  - photo picker
  - name/number/pronunciation fields
  - `Present Today`
  - `Choose Song` / `Change Song`
  - record/stop/preview announcement cue
  - `Import Audio or Video`
  - cue trim controls
  - `Advanced`
  - `Make Local Copy` when experiment enabled
  - `Clear Song`
  - `Clear Custom Announcer`
  - `Save`
- Data dependencies:
  - current `Player`
  - `AppModel.appleMusicPlaybackCapability`
  - asset existence checks
  - cue timeline/duration calculations
  - recording state
- Visual/layout observations:
  - implemented as one large `Form`
  - progressive disclosure for local import and advanced trim
  - Apple Music trim is preset-first rather than slider-heavy
- Known UX problems:
  - very high responsibility density
  - multiple modals launched from within one form
  - local `@State` and model refresh interactions make this screen easy to destabilize
- Stable or fragile: fragile
- Screenshots: unavailable
- Related components:
  - `AppleMusicPickerSheet`
  - `AdvancedTrimSheet`
  - `BasicPhotoCropperSheet`
  - `StartScrubControl`
  - `FlowChipRow`

## 6. Apple Music Picker Sheet

- Screen name: Choose Song
- File(s): `RollCall/RootView.swift`
- Purpose: Apple Music search and recent-song selection
- Entry points:
  - `Choose Song`
  - `Change Song`
- Main controls/buttons:
  - search field
  - recent song rows
  - search result rows
  - row tap selects immediately
  - separate preview button
  - `Close`
- Data dependencies:
  - `recentAppleMusicSelections`
  - `appleMusicPlaybackCapability`
  - `searchAppleMusic(term:)`
  - `previewAppleMusicSearchResult(_:)`
- Visual/layout observations:
  - list-based sheet
  - capability banner at top
  - preview button is a small secondary control on the right
- Known UX problems:
  - preview affordance is small
  - search errors surface both inline and through global app error state
- Stable or fragile: medium
- Screenshots: unavailable
- Related components: `AppleMusicRow`

## 7. Advanced Trim Sheet

- Screen name: Advanced Trim
- File(s): `RollCall/RootView.swift`
- Purpose: quarter-second cue and fade nudging
- Entry points:
  - `Advanced` button in player editor
- Main controls/buttons:
  - `-0.25` / `+0.25` for start
  - `-0.25` / `+0.25` for length
  - `-0.25` / `+0.25` for fade
  - `Done`
- Data dependencies: bound `Cue`, cue limits
- Visual/layout observations:
  - medium-height sheet
  - intentionally utilitarian
- Known UX problems:
  - precise but not visually rich
  - easy to break if future redesign changes bound cue math carelessly
- Stable or fragile: medium
- Screenshots: unavailable
- Related components: `formattedCueTime(_:)`

## 8. Basic Photo Cropper Full-Screen Cover

- Screen name: Adjust Photo
- File(s): `RollCall/RootView.swift`
- Purpose: crop imported player photos
- Entry points:
  - pick photo in player editor
- Main controls/buttons:
  - drag/pinch canvas
  - `Reset`
  - `Cancel`
  - `Use Photo`
- Data dependencies: in-memory `UIImage`
- Visual/layout observations:
  - custom black backdrop
  - centered crop square
  - full-screen presentation
- Known UX problems:
  - fallback path bypasses cropper after 1.5s if render is delayed
  - no explicit zoom percentage or crop preview beyond live canvas
- Stable or fragile: fragile
- Screenshots: unavailable
- Related components: `UIImage.normalizedUpImage()`

## 9. General Clips Tab

- Screen name: General Clips
- File(s): `RollCall/RootView.swift`, `RollCall/Models.swift`, `RollCall/BuiltInAudio/*`
- Purpose: built-in hype/crowd sounds separate from player cues
- Entry points: tab bar
- Main controls/buttons:
  - clip rows
  - play tap
- Data dependencies:
  - selected team built-in clips
  - bundled audio files copied into app storage on launch
- Visual/layout observations:
  - simple list
  - each row has label, short helper text, play icon
- Known UX problems:
  - lightweight relative to the importance of game-day use
  - no grouping, favorites, or quick-stop control here
- Stable or fragile: stable
- Screenshots: unavailable
- Related components: `CuePlaybackEngine`

## 10. Game Day Tab

- Screen name: Game Day
- File(s): `RollCall/RootView.swift`
- Purpose: live playback board for present players
- Entry points: tab bar
- Main controls/buttons:
  - intro mode segmented control
  - player grid buttons
  - `Advance Next Batter`
  - `Stop Audio`
  - `Lineup`
- Data dependencies:
  - selected team
  - present players in batting order
  - next batter state
  - cue playback active state
  - custom announcement cue availability
- Visual/layout observations:
  - most custom-styled part of the app
  - gradient background
  - large card-like player buttons
  - “portrait-first game board” framing
- Known UX problems:
  - visually distinct from the rest of the app, so redesign consistency work may be tempting but risky
  - large button grid is tightly tied to tap-to-play behavior
- Stable or fragile: fragile
- Screenshots: unavailable
- Related components:
  - `GameDayBackground`
  - `GameDayHeader`
  - `GameDayPlayerGrid`
  - `LineupEditorSheet`

## 11. Today’s Lineup Sheet

- Screen name: Today’s Lineup
- File(s): `RollCall/RootView.swift`
- Purpose: reorder batting order and mark players present
- Entry points:
  - `Lineup` button in `Game Day`
- Main controls/buttons:
  - drag reorder rows
  - `Sort A-Z`
  - `Sort by Number`
  - presence toggles
  - `Close`
- Data dependencies:
  - selected team session batting order
  - player presence state
- Visual/layout observations:
  - list-based editor with always-active move mode
- Known UX problems:
  - list edit affordances are iOS-standard but somewhat plain
  - future styling must not interfere with drag/reorder behavior
- Stable or fragile: medium
- Screenshots: unavailable
- Related components: `moveBattingOrder`, lineup normalization

## 12. Readiness Tab

- Screen name: Readiness
- File(s): `RollCall/RootView.swift`, `RollCall/Services.swift`
- Purpose: readiness snapshot of playback conditions and missing assets
- Entry points: tab bar
- Main controls/buttons:
  - readiness rows
  - `Refresh`
- Data dependencies:
  - `state.lastReadiness`
  - `ReadinessService.snapshot(for:)`
- Visual/layout observations:
  - plain list
  - icon + title + detail rows
- Known UX problems:
  - status relies on color and icon semantics
  - there is no drill-in detail screen
- Stable or fragile: stable
- Screenshots: unavailable
- Related components: `ReadinessCheck`, `ReadinessStatus`

## 13. Teams Tab

- Screen name: Teams
- File(s): `RollCall/RootView.swift`
- Purpose: create/select/manage teams
- Entry points: tab bar
- Main controls/buttons:
  - team name text field
  - `Create Team`
  - selectable team rows
  - `More` menu:
    - rename
    - duplicate
    - import roster CSV
    - remove selected team
- Data dependencies:
  - `state.teams`
  - `selectedTeamID`
- Visual/layout observations:
  - plain list + create form
  - selected team section with menu-based actions
- Known UX problems:
  - lifecycle actions are hidden behind `More`
  - rename/remove are root alerts, not dedicated flows
- Stable or fragile: medium
- Screenshots: unavailable
- Related components: rename alert, remove confirmation, CSV importer

## 14. Roster Preview Sheet

- Screen name: Roster Preview
- File(s): `RollCall/RootView.swift`
- Purpose: confirm CSV import before applying player rows
- Entry points:
  - CSV import from Teams
- Main controls/buttons:
  - preview list
  - `Cancel`
  - `Import`
- Data dependencies:
  - `pendingRosterImport`
- Visual/layout observations:
  - simple confirmation list
- Known UX problems:
  - no inline edit/cleanup before import
- Stable or fragile: stable
- Screenshots: unavailable
- Related components: `PackageService.parseRosterCSV`

## 15. Settings Tab

- Screen name: Settings
- File(s): `RollCall/RootView.swift`
- Purpose: package actions, haptics, recovery entry, developer entry, about info
- Entry points: tab bar
- Main controls/buttons:
  - `Export Selected Team`
  - `Share Latest .rollcall Package`
  - `Import .rollcall Package`
  - `Game Day Haptics`
  - navigation to recovery
  - navigation to developer tools
  - GitHub link
- Data dependencies:
  - export URL
  - settings toggle
- Visual/layout observations:
  - straightforward grouped settings list
- Known UX problems:
  - operational actions and app metadata are mixed in one screen
- Stable or fragile: stable
- Screenshots: unavailable
- Related components: share sheet, package import sheet

## 16. Recovery & Backups

- Screen name: Recovery & Backups
- File(s): `RollCall/RootView.swift`, `RollCall/AppModel.swift`
- Purpose: manual backup creation and backup restore
- Entry points:
  - `Settings` -> `Recovery & Backups`
- Main controls/buttons:
  - `Create Backup`
  - `Restore Backup`
- Data dependencies:
  - `state.snapshots`
- Visual/layout observations:
  - simple list with explanation text
- Known UX problems:
  - no diff/preview before restore
  - restore is only protected by button intent, not a second confirmation screen
- Stable or fragile: medium
- Screenshots: unavailable
- Related components: snapshot persistence in Application Support

## 17. Developer Tools

- Screen name: Developer Tools
- File(s): `RollCall/RootView.swift`
- Purpose: experimental toggle and support bundle export
- Entry points:
  - `Settings` -> `Developer Tools`
- Main controls/buttons:
  - enable experimental Apple Music local copies
  - `Generate Support Bundle`
  - `Share Latest Support Bundle`
- Data dependencies:
  - `state.experimental`
  - `supportBundle`
- Visual/layout observations:
  - settings-like list
  - clearly labeled as non-primary workflow
- Known UX problems:
  - developer-only content lives inside the shipping app shell
- Stable or fragile: stable
- Screenshots: unavailable
- Related components: support bundle export, experimental Apple Music path

## 18. System Document and Share Presentations

- Screen name: Package Import Picker / CSV Importer / Audio-Video Importer / Share Sheet / Photos Picker
- File(s): `RollCall/RootView.swift`
- Purpose: system-managed import/export surfaces
- Entry points:
  - package import
  - CSV import
  - media import
  - package share
  - support bundle share
  - photo selection
- Main controls/buttons: system-provided
- Data dependencies: selected file URLs, selected photos, share items
- Visual/layout observations:
  - mostly native UIKit/system surfaces
- Known UX problems:
  - user flow depends on several modal transitions and security-scoped resource access
- Stable or fragile: fragile as workflow glue, stable as system UI
- Screenshots: unavailable
- Related components:
  - `RollCallPackageImportSheet`
  - `ActivityShareSheet`
  - SwiftUI `fileImporter`
  - `PhotosPicker`
