# Working Changelog

Internal notes for building public-facing changelogs. Keep entries understandable to non-technical users, but not fully polished.

## Unreleased

### Added
- [public candidate] Roll Call can now be installed on iPhones running iOS 17 or later.

### Changed
-

### Fixed
- [public candidate] Game Day playback is more reliable when moving quickly between batters; older fade-out cleanup can no longer stop the next player's cue.

### Reliability / Data Safety
- Playback and preview cleanup now ignore stale stop tasks after a newer cue starts, reducing silent or stuck Game Day playback after rapid taps.

### Internal / Maintenance
-
