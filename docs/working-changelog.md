# Working Changelog

Internal notes for building public-facing changelogs. Keep entries understandable to non-technical users, but not fully polished.

## Unreleased

### Added
- [public candidate] Roll Call can now be installed on iPhones running iOS 17 or later.
- [public candidate] Team colors now shape Roll Call's accent styling across the app, including Game Day, Clips, setup progress, primary actions, and selected controls.
- [public candidate] Added an optional Keep Screen Awake setting so Game Day and Clips can prevent auto-lock during live use, with a battery-use note in Settings.
- [public candidate] Added an in-app What's New sheet for update notes, with a Settings > About entry and a Full Changelog link.
- [public candidate] Teams can now update a managed Apple Music playlist from their Apple Music song cues, with a preview of included and skipped songs before anything changes.


### Changed
- The What's New sheet now uses a more compact layout with less repeated version text.
- The Full Changelog link in What's New is now easier to recognize as a tappable web link.
- Missing player-photo placeholders and the player editor now better reflect the selected team's accent color.
- Apple Music playlist wording now says create or update where Roll Call may do either.
- The selected team's color wash now appears across Roll Call pages, not just Game Day and Clips.
- Gray and Black team colors now use adaptive neutral accent treatments so they stay readable in both Light Mode and Dark Mode.

### Fixed
- Team accent styling now also applies correctly to iOS 26 Liquid Glass tab bars and primary buttons.
- Black team accents no longer turn into bright white controls in Dark Mode.
- The Apple Music playlist preview and What's New panels now use the selected team's color wash.
- [public candidate] Game Day playback is more reliable when moving quickly between batters; older fade-out cleanup can no longer stop the next player's cue.

### Reliability / Data Safety
- Playback and preview cleanup now ignore stale stop tasks after a newer cue starts, reducing silent or stuck Game Day playback after rapid taps.

### Internal / Maintenance
- Semantic colors such as warning, destructive, ready, disabled, and live playback remain separate from team accent colors.
