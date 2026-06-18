# Working Changelog

Internal notes for building public-facing changelogs. Keep entries understandable to non-technical users, but not fully polished. This has been cleared to be ready for the 1.2 development run.

## Unreleased

### Added

- Added Custom Clips to the live Clips page for quick team-specific song cues that are not tied to a player announcement. [public candidate] [needs review]
- Added an import check that explains which Player Songs and Custom Clips arrived ready, which still depend on Apple Music, and which saved choices need repair on this device. [public candidate] [needs review]
- Added a Music Library-first song picker with Recently Added, Artists, Albums, Songs, Library search, explicit Apple Music search, and an optional Files fallback. [public candidate] [needs review]
- Added a focused clip editor with a draggable song window, clip-length choices up to 20 seconds, preview, advanced start/fade controls, and a simple saved readiness result. [public candidate] [needs review]
- The clip editor now starts analyzing readable audio as soon as a song is selected, reuses the result when the editor opens, and fills in a real waveform without blocking interaction. Songs that do not expose readable audio show a clearly regular placeholder pattern instead of pretending Roll Call can inspect them. [public candidate] [needs review]
- Clip preview now shows a moving playhead across the selected waveform window and removes it as soon as preview playback stops. [public candidate] [needs review]

### Changed

- Refreshed the app icon and `.rollcall` team file icons so exported packages match the latest Roll Call artwork with a full-bleed file icon treatment; the app icon now builds from the Icon Composer source so its dark and tinted variants are included. [public candidate] [needs review]
- Team export now previews how many clips will travel as local audio, remain Apple Music links, are still preparing, or need repair before creating the package. [public candidate] [needs review]
- Imported Apple Music-linked songs now check this device's Music access automatically when possible. The import check shows Apple Music as ready, unavailable, or still needing the user's permission instead of asking everyone to verify manually. [public candidate] [needs review]
- Player Songs and Custom Clips can be copied into each other through `Use Existing Clip`; every copy is independent, so later edits and deletion never silently change the source. [public candidate] [needs review]
- The Clips page now separates built-in Sound Effects from ordered Custom Clips, keeps live tiles playback-only, and places adding, editing, reordering, and deletion behind an explicit Edit action. [public candidate] [needs review]
- The Clips page now shows the five built-in Sound Effects in a compact row with sound-specific icons and highlights the active playing clip with the same live blue treatment used on Game Day. [needs review]
- Custom Clip tiles now use a denser three-wide layout that better matches the Game Day player grid, without separate visible play buttons. [needs review]
- The Custom Clips edit sheet now opens with reorder handles visible immediately, matching the lineup editor. [needs review]
- Custom Clip preparation can now continue carefully while Clips or Game Day is open, but waits for live playback to be idle so tap-to-play sounds stay responsive. [needs review]
- The active-team picker now shows each team in its own team color, with a matching highlight around the current team. [needs review]
- Onboarding now uses the same Music Library-first song choices and waveform clip editor as Player setup, so selecting, trimming, previewing, and saving a first walk-up song works consistently throughout Roll Call. [public candidate] [needs review]
- Volume Automation now applies only to source-backed Apple Music. Local, generated, built-in, and Announcement Cue files play at their encoded volume without additional runtime fading or volume resets.
- Song readiness now says `Ready on Any Device` for portable Roll Call-owned clips and `Ready on This Device` for device-dependent playback. Tapping the status explains what it means for playback, Apple Music, and team exports.
- Apple Music catalog search now keeps its search field visibly anchored at the top of the screen beneath a large title, more closely matching the familiar Music Library picker layout.
- Advanced clip editing now uses exact Start, Length, and Fade Out values with quarter-second and one-second adjustment buttons instead of imprecise sliders.
- Make Your Clip now shows the current preview time between the selected window's start and end times while the clip is playing.
- New song clips now start at a 12-second length by default for everyone, then remember any length you choose later; the editor also recommends 10-12 seconds for best game pace.
- Song selection now opens Apple's familiar Music library picker by default. Apple Music catalog search and file import remain clearly available as separate choices and use the same clip editor afterward. [public candidate] [needs review]
- Choosing a song or imported file now creates a draft first. The player's existing Game Day cue is not replaced until Save is tapped in the clip editor. [public candidate] [needs review]

### Fixed

- Filled accent buttons now choose a readable black or white foreground from the selected team color, so light accents like Gold stay legible in dark mode. [needs review]
- Source-backed Apple Music and Music Library fades now line up with generated local clips: the fade ends at the selected clip endpoint instead of drifting into the stop-safety tail. [needs review]
- The welcome screen's `Let's Get Started` button is readable in both light and dark mode.
- Music Library songs now preview through the exact selected library item, preserving arbitrary start times for cloud-backed library songs instead of relying on partial asset URLs or mismatched catalog playback.
- Apple Music-based Custom Clips no longer keep bouncing back to `Preparing` after Roll Call has already settled them as source-backed or unavailable on this device. [needs review]
- Edited Player Songs and Custom Clips no longer play or export an older generated clip while the updated selection is being prepared.
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

- Editing, copying, or duplicating a song with a prepared local clip now keeps the original song and timing as the editable source, and changing fade timing no longer reuses an older baked clip while the new version prepares. [needs review]
- Importing a team no longer drops an identifiable song choice or rejects the entire team just because one local audio file is missing. Roll Call preserves the assignment, marks it for repair, and keeps the rest of the team usable. [public candidate] [needs review]
- Roll Call now automatically removes only generated clips it can prove are unused. It retains clips referenced by active teams, Custom Clips, player assignments, Recently Deleted, and readable backups, and skips cleanup whenever preparation or storage state is uncertain. [needs review]
- Deleted Custom Clips stay in Recently Deleted for 60 days and restore to their original team and saved position when possible. Player Songs copied from them remain unchanged. [public candidate] [needs review]
- Roll Call can now prepare a local playback clip when the selected song exposes a readable file, while keeping Apple Music-linked songs working through their original source when no readable file is available. Preparation pauses during live-use screens and never replaces a working local clip with a failed retry. [needs review]
- Roll Call 1.2 now preserves each player's song choice in a richer model that separates the original song, selected timing, local preparation state, device readiness, and export portability. Existing teams and older `.rollcall` files migrate automatically when opened. [needs review]

### Internal / Maintenance
- Developer Tools can now duplicate the selected team's Player Songs into independent Custom Clips for faster review setup.
- Generated Clip Storage in Developer Tools now shows visible progress and a last-inspected time when checking generated clip storage.
- Removed the Music Render Probe entry from Developer Tools now that Phase 0 findings are captured.
- Removed failed Apple Music Local Copies and Apple Music Transition Crossfade experiments from Developer Tools while keeping the existing release fading and generated-clip paths in place.
- Removed the legacy premium-unlock testing flag and Developer Tools controls now that Roll Call's product policy is all-features-free.
- Checked-in app version metadata now reads `1.2` build `71` for the fade-audit fixes and continued hands-on review.
- Checked-in app version metadata now reads `1.2` build `70` after the icon refresh for continued hands-on review.
- Checked-in app version metadata now reads `1.2` build `69` for post-plan hands-on issue review.
- Checked-in app version metadata now reads `1.2` build `68` for the completed Phase 5 implementation and automated Phase 6 verification pass.
- Non-Release Developer Tools can inspect generated-clip storage and request confirmed manual cleanup. Support bundles now use aggregate, redacted cue diagnostics without audio, song metadata, roster names, filenames, or source/model identifiers.
- State persistence now captures its target file when a save is queued, preventing delayed writes from being redirected if the app storage root changes during tests.
- Added a one-at-a-time song preparation queue with deterministic stale-result protection, bounded retries, Low Power pauses, live-use throttling, and generated `.m4a` storage. iOS does not expose a supported API for apps to request Apple Music offline downloads, so Roll Call does not attempt or imply that behavior.
- Added the Phase 1 cue-revamp model and saved-state migration foundation while keeping the current playback and editing paths working through the existing cue recipe.
- Checked-in app version metadata now reads `1.2` build `66` for the current `release/1.2` cue-revamp baseline.
