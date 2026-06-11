# Working Changelog

Internal notes for building public-facing changelogs. Keep entries understandable to non-technical users, but not fully polished. This has been cleared to be ready for the 1.2 development run.

## Unreleased

### Added

- Added a Music Library-first song picker with Recently Added, Artists, Albums, Songs, Library search, explicit Apple Music search, and an optional Files fallback. [public candidate] [needs review]
- Added a focused clip editor with a draggable song window, clip-length choices up to 20 seconds, preview, advanced start/fade controls, and a simple saved readiness result. [public candidate] [needs review]

### Changed

- Song selection now opens Apple's familiar Music library picker by default. Apple Music catalog search and file import remain clearly available as separate choices and use the same clip editor afterward. [public candidate] [needs review]
- Choosing a song or imported file now creates a draft first. The player's existing Game Day cue is not replaced until Save is tapped in the clip editor. [public candidate] [needs review]

### Fixed

- Fixed a crash when selecting a clip length equal to the song's full available window, including 20-second preview-backed songs.
- Fixed a crash that could occur when song preparation checked Apple Music library availability after opening Players, Teams, or another setup screen on the simulator. [needs review]

### Reliability / Data Safety

- Roll Call can now prepare a local playback clip when the selected song exposes a readable file, while keeping Apple Music-linked songs working through their original source when no readable file is available. Preparation pauses during live-use screens and never replaces a working local clip with a failed retry. [needs review]
- Roll Call 1.2 now preserves each player's song choice in a richer model that separates the original song, selected timing, local preparation state, device readiness, and export portability. Existing teams and older `.rollcall` files migrate automatically when opened. [needs review]

### Internal / Maintenance
- State persistence now captures its target file when a save is queued, preventing delayed writes from being redirected if the app storage root changes during tests.
- Added a one-at-a-time song preparation queue with deterministic stale-result protection, bounded retries, Low Power/live-use pauses, and generated `.m4a` storage. iOS does not expose a supported API for apps to request Apple Music offline downloads, so Roll Call does not attempt or imply that behavior.
- Added the Phase 1 cue-revamp model and saved-state migration foundation while keeping the current playback and editing paths working through the existing cue recipe.
- Checked-in app version metadata now reads `1.2` build `66` for the current `release/1.2` cue-revamp baseline.
- `release/1.2` now includes an internal-only `Music Render Probe` in Developer Tools for manually testing which device-library and Apple Music cases can really render to local clips through public APIs, plus a redacted summary export for the findings note.
