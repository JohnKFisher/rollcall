# Component Catalog

This is a reusable-UI inventory of what currently exists, even when it is implemented inline rather than as a formal design-system component.

## Buttons

### Bordered Prominent Action Buttons

Examples:
- `Add Player`
- `Preview Clip`
- `Stop Recording`
- some trim mode chips

Current style:
- native `.borderedProminent`
- often tinted orange

Used in:
- quick add
- player editor
- trim flow

### Bordered Secondary Buttons

Examples:
- `Change Song`
- `Advanced`
- `Sort A-Z`
- `Sort by Number`
- `Create Backup`

Current style:
- native `.bordered`

### Destructive Buttons

Examples:
- `Remove`
- `Clear Song`
- `Clear Custom Announcer`

Current style:
- standard iOS destructive roles and alerts

## Cards

### Game Day Player Card

- File: `RollCall/RootView.swift`
- Purpose: large tap target for live playback
- Contents:
  - photo
  - number
  - name
  - cue label
  - announcement cue status
  - active playback label when playing

### Busy Capsule Overlay

- File: `RollCall/RootView.swift`
- Purpose: global in-progress indicator

## List Rows

### Player Roster Row

- photo thumbnail
- identity stack
- cue status chip
- announcement cue status chip

### Apple Music Result Row

- title
- artist
- capability badge
- separate preview button

### Readiness Row

- status icon
- title
- detail

### General Clip Row

- clip title
- helper text
- play icon

## Modals and Sheets

### Player Editor Sheet

- largest current modal workflow

### Apple Music Picker Sheet

- search + recents + preview

### Advanced Trim Sheet

- fine-tune controls

### Lineup Editor Sheet

- reorder and presence management

### Roster Preview Sheet

- confirm CSV import

### Activity Share Sheet

- UIKit bridge for share flows

### Package Import Picker

- UIKit document picker bridge

## Player-Related Controls

### `PlayerPhotoThumbnail`

- reusable photo/placeholder presentation
- used in roster, game-day grid, lineup rows, and editor

### Presence Toggle

- explicit boolean control for whether a player is active today

### Player Quick Add Fields

- fast inline add pattern with keyboard toolbar support

## Playback Controls

### Game Day Player Buttons

- main live playback trigger

### `Preview Clip`

- cue preview button in player editor

### Apple Music Preview Button

- small right-side button in picker rows

### `Stop Audio`

- shown only when playback is active in Game Day header

## Forms

Main current form patterns:
- grouped `Form` sections in Player Editor
- grouped `List` sections in Settings/Teams/Recovery/Developer Tools

Repeated subpatterns:
- explanatory footnote text under functional controls
- progressive disclosure for advanced or fallback paths

## Alerts and Confirmations

Current alert patterns:
- global error alert
- experimental feature opt-in alert
- rename team alert
- remove team confirmation
- clear-audio confirmation inside player editor

Observation:
- the app already favors explicit destructive confirmations

## Custom Controls

### `StartScrubControl`

- custom trim-start scrubber
- supports drag seek and long-press live scrub preview behavior

### `FlowChipRow`

- fixed set of preset clip-length chips

### `KeyboardDismissTapOverlay`

- utility overlay to dismiss keyboard without blocking touches

## Repeated Styling Patterns

- orange accent and tint
- rounded capsules for statuses
- rounded rectangles for player photos/cards
- green for success/active/ready
- orange for cue emphasis
- red for destructive or missing states
- footnote secondary explanatory copy

## Components That Already Feel Reusable Enough for Future Extraction

- `PlayerPhotoThumbnail`
- roster status chip pair
- Apple Music result row
- readiness row
- form section explainer text
- game-day player card
