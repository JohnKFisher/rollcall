# Working Changelog

Internal notes for building public-facing changelogs. Keep entries understandable to non-technical users, but not fully polished. This has been cleared to be ready for the 1.2 development run.

## Unreleased

### Added


### Changed


### Fixed


### Reliability / Data Safety

- Roll Call 1.2 now preserves each player's song choice in a richer model that separates the original song, selected timing, local preparation state, device readiness, and export portability. Existing teams and older `.rollcall` files migrate automatically when opened. [needs review]

### Internal / Maintenance
- Added the Phase 1 cue-revamp model and saved-state migration foundation while keeping the current playback and editing paths working through the existing cue recipe.
- Checked-in app version metadata now reads `1.2` build `66` for the current `release/1.2` cue-revamp baseline.
- `release/1.2` now includes an internal-only `Music Render Probe` in Developer Tools for manually testing which device-library and Apple Music cases can really render to local clips through public APIs, plus a redacted summary export for the findings note.
