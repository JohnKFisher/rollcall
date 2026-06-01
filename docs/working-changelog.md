# Working Changelog

Internal notes for building public-facing changelogs. Keep entries understandable to non-technical users, but not fully polished.

## Unreleased

### Added
- [public candidate] Roll Call can now be installed on iPhones running iOS 17 or later.
- [public candidate] Team colors now shape Roll Call's accent styling across the app, including Game Day, Clips, setup progress, primary actions, and selected controls.


### Changed
- The selected team's color wash now appears across Roll Call pages, not just Game Day and Clips.
- Gray and Black team colors now use adaptive neutral accent treatments so they stay readable in both Light Mode and Dark Mode.

### Fixed
- Team accent styling now also applies correctly to iOS 26 Liquid Glass tab bars and primary buttons.
- Black team accents no longer turn into bright white controls in Dark Mode.
- [public candidate] Game Day playback is more reliable when moving quickly between batters; older fade-out cleanup can no longer stop the next player's cue.

### Reliability / Data Safety
- Playback and preview cleanup now ignore stale stop tasks after a newer cue starts, reducing silent or stuck Game Day playback after rapid taps.

### Internal / Maintenance
- Semantic colors such as warning, destructive, ready, disabled, and live playback remain separate from team accent colors.
