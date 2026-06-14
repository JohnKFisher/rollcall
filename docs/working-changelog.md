# Working Changelog

Internal notes for building public-facing changelogs. Keep entries understandable to non-technical users, but not fully polished. This has been cleared to be ready for the 1.2 development run.

## Unreleased

### Added

- Added an import check that explains which team clips arrived ready, which still depend on Apple Music, and which saved song choices need repair on this device. [public candidate] [needs review]
- Added Team Clips, a reusable team-level walk-up clip library with standalone creation, custom names, shared player assignments, and an advanced tool for saving existing player songs into the library. [public candidate] [needs review]
- Added a Music Library-first song picker with Recently Added, Artists, Albums, Songs, Library search, explicit Apple Music search, and an optional Files fallback. [public candidate] [needs review]
- Added a focused clip editor with a draggable song window, clip-length choices up to 20 seconds, preview, advanced start/fade controls, and a simple saved readiness result. [public candidate] [needs review]
- The clip editor now starts analyzing readable audio as soon as a song is selected, reuses the result when the editor opens, and fills in a real waveform without blocking interaction. Songs that do not expose readable audio show a clearly regular placeholder pattern instead of pretending Roll Call can inspect them. [public candidate] [needs review]
- Clip preview now shows a moving playhead across the selected waveform window and removes it as soon as preview playback stops. [public candidate] [needs review]

### Changed

- Team export now previews how many clips will travel as local audio, remain Apple Music links, are still preparing, or need repair before creating the package. [public candidate] [needs review]
- Shared Team Clips now use the same background preparation and portable local-clip path as player-specific songs, so one prepared shared clip benefits every assigned player. [public candidate] [needs review]
- Players can now use a shared Team Clip. Editing from a player first creates a private player copy, while editing from Team Clips intentionally updates everyone using that shared clip. [public candidate] [needs review]
- Onboarding now uses the same Music Library-first song choices and waveform clip editor as Player setup, so selecting, trimming, previewing, and saving a first walk-up song works consistently throughout Roll Call. [public candidate] [needs review]
- Volume Automation now applies only to source-backed Apple Music. Local, generated, built-in, and Announcement Cue files play at their encoded volume without additional runtime fading or volume resets.
- Song readiness now says `Ready on Any Device` for portable Roll Call-owned clips and `Ready on This Device` for device-dependent playback. Tapping the status explains what it means for playback, Apple Music, and team exports.
- Apple Music catalog search now keeps its search field visibly anchored at the top of the screen beneath a large title, more closely matching the familiar Music Library picker layout.
- Advanced clip editing now uses exact Start, Length, and Fade Out values with quarter-second and one-second adjustment buttons instead of imprecise sliders.
- Song selection now opens Apple's familiar Music library picker by default. Apple Music catalog search and file import remain clearly available as separate choices and use the same clip editor afterward. [public candidate] [needs review]
- Choosing a song or imported file now creates a draft first. The player's existing Game Day cue is not replaced until Save is tapped in the clip editor. [public candidate] [needs review]

### Fixed

- Closing an unchanged Player Editor no longer shows a discard warning just because song metadata or preparation readiness refreshed in the background.
- Import Audio or Video now opens the Files browser directly. Cancelling returns to the Player Editor instead of leaving behind an empty Import Audio sheet.
- Apple Music searches with no matching songs now show the normal no-results state instead of incorrectly reporting that search is unavailable.
- Apple Music search no longer shows `Search Unavailable: Cancelled` when an in-progress search is normally replaced by newer typing.
- Moving the selected waveform window now stops an active clip preview immediately before changing its start position.
- Restored finger dragging across the waveform after the selected window switched to true timeline sizing; the full waveform rail is now the drag target.
- Changing the clip length now keeps the selected window anchored to the same song start instead of visually sliding along the waveform.
- Fixed a crash when selecting a clip length equal to the song's full available window, including 20-second preview-backed songs.
- Fixed a crash that could occur when song preparation checked Apple Music library availability after opening Players, Teams, or another setup screen on the simulator. [needs review]

### Reliability / Data Safety

- Importing a team no longer drops an identifiable song choice or rejects the entire team just because one local audio file is missing. Roll Call preserves the assignment, marks it for repair, and keeps the rest of the team usable. [public candidate] [needs review]
- Roll Call now automatically removes only generated clips it can prove are unused. It retains clips referenced by active teams, Team Clips, player assignments, Recently Deleted, and readable backups, and skips cleanup whenever preparation or storage state is uncertain. [needs review]
- Deleting a Team Clip now explains when players use it and can preserve each assignment as a private player copy. Exact clip duplicates are reused, and shared clips are protected from premature audio-file cleanup. [needs review]
- Roll Call can now prepare a local playback clip when the selected song exposes a readable file, while keeping Apple Music-linked songs working through their original source when no readable file is available. Preparation pauses during live-use screens and never replaces a working local clip with a failed retry. [needs review]
- Roll Call 1.2 now preserves each player's song choice in a richer model that separates the original song, selected timing, local preparation state, device readiness, and export portability. Existing teams and older `.rollcall` files migrate automatically when opened. [needs review]

### Internal / Maintenance
- Checked-in app version metadata now reads `1.2` build `68` for the completed Phase 5 implementation and automated Phase 6 verification pass.
- Non-Release Developer Tools can inspect generated-clip storage and request confirmed manual cleanup. Support bundles now use aggregate, redacted cue diagnostics without audio, song metadata, roster names, filenames, or source/model identifiers.
- Checked-in app version metadata now reads `1.2` build `67` for the Phase 4 Team Clips implementation.
- State persistence now captures its target file when a save is queued, preventing delayed writes from being redirected if the app storage root changes during tests.
- Added a one-at-a-time song preparation queue with deterministic stale-result protection, bounded retries, Low Power/live-use pauses, and generated `.m4a` storage. iOS does not expose a supported API for apps to request Apple Music offline downloads, so Roll Call does not attempt or imply that behavior.
- Added the Phase 1 cue-revamp model and saved-state migration foundation while keeping the current playback and editing paths working through the existing cue recipe.
- Checked-in app version metadata now reads `1.2` build `66` for the current `release/1.2` cue-revamp baseline.
- `release/1.2` now includes an internal-only `Music Render Probe` in Developer Tools for manually testing which device-library and Apple Music cases can really render to local clips through public APIs, plus a redacted summary export for the findings note.
