# Working Changelog

Internal notes for building public-facing changelogs. Keep entries understandable to non-technical users, but not fully polished.

## Unreleased

### Added
- [public candidate] Roll Call can now be installed on iPhones running iOS 17 or later.
- [public candidate] Team colors now shape Roll Call's accent styling across the app, including Game Day, Clips, setup progress, primary actions, and selected controls.
- [public candidate] Added an optional Keep Screen Awake setting so Game Day and Clips can prevent auto-lock during live use, with a battery-use note in Settings.
- [public candidate] Added an in-app What's New sheet for update notes, with a Settings > About entry and a Full Changelog link.
- [public candidate] Roll Call can now politely ask for a rating after repeated successful Game Day use, while still waiting until a later non-live screen instead of interrupting Game Day, and explicit `Rate Roll Call` taps now go straight to the App Store review page.
- [public candidate] Teams can now update a managed Apple Music playlist from their Apple Music song cues, with a preview of included and skipped songs before anything changes.
- [public candidate] Added a new Recovery screen with Recently Deleted for teams and players, including 60-day recovery, item-by-item restore, and item-by-item permanent delete.


### Changed
- [public candidate] Built-in crowd clips now use a smaller, more sports-specific set built around cheers, a stadium swell, a chant, and rhythmic clap instead of generic audience-applause sounds.
- [needs review] Game Day's player grid now flows forward from the batter after On Deck and wraps through the lineup so the live board reads more like the expected batting order while still keeping every player available to tap.
- [needs review] If you tap a later player out of order on Game Day, the big hero now temporarily switches to a `Lineup Override` state for that player without reshuffling the lineup grid or On Deck card.
- [needs review] Game Day now uses smaller announcer and song status icons across the live board so player tiles, Now Batting, and On Deck can show what is available with less repeated gray text.
- [needs review] Game Day's Now Batting and On Deck headers now carry the player number in the compact status line instead of giving the number its own larger placement.
- The What's New sheet now uses a more compact layout with less repeated version text.
- The Full Changelog link in What's New is now easier to recognize as a tappable web link.
- Missing player-photo placeholders and the player editor now better reflect the selected team's accent color.
- Apple Music playlist wording now says create or update where Roll Call may do either.
- Apple Music access and picker wording now better explain that full-song playback depends on the user's subscription and song availability on this device.
- The selected team's color wash now appears across Roll Call pages, not just Game Day and Clips.
- Gray and Black team colors now use adaptive neutral accent treatments so they stay readable in both Light Mode and Dark Mode.
- Recovery's Recently Deleted list now keeps the same restore details while fitting more items on screen at once.
- [public candidate] `.rollcall` files now use a bolder full-bleed Roll Call icon treatment instead of the older small centered badge, making shared team files easier to recognize in Files and share sheets.

### Fixed
- Team accent styling now also applies correctly to iOS 26 Liquid Glass tab bars and primary buttons.
- Black team accents no longer turn into bright white controls in Dark Mode.
- The Apple Music playlist preview and What's New panels now use the selected team's color wash.
- [public candidate] Game Day playback is more reliable when moving quickly between batters; older fade-out cleanup can no longer stop the next player's cue.

### Reliability / Data Safety
- Playback and preview cleanup now ignore stale stop tasks after a newer cue starts, reducing silent or stuck Game Day playback after rapid taps.
- [needs review] Game Day now refreshes next-batter warmup when you open the Game Day tab or return to the app there, giving Apple Music cues a fresher prewarm attempt before live use.
- [public candidate] If deleted items are missing some saved media, Roll Call now tells you what could not be recovered and offers a clear `Restore What We Can` fallback instead of silently restoring a broken result.
- Shared team media now stays on the device while any active team or Recovery item still references it, and regenerated built-in announcer files now clean up old unused copies instead of leaving orphaned assets behind.

### Internal / Maintenance
- Semantic colors such as warning, destructive, ready, disabled, and live playback remain separate from team accent colors.
- Non-Release Developer Tools now includes rating diagnostics and a threshold testing control that can flip the rating flow between earned and not earned while resetting automatic prompt attempts.
- Non-Release Developer Tools can now launch the exact same rating-request sheet used in the real app, while still keeping separate native StoreKit and App Store review diagnostics.
