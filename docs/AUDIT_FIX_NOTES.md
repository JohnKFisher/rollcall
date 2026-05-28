# Audit Fix Notes

Working notes for fixes that come out of the full-app audit. These are not public release notes yet; use them as raw material for the public changelog later.

## Unreleased Audit Fixes

- Package imports now wait for the automatic pre-import backup to finish before adding the imported team. If the backup cannot be written, the import stops instead of proceeding without the promised recovery point.
- Incoming `.rollcall` files that arrive while Roll Call is busy now stay queued and retry automatically when the current import, export, backup, or restore operation finishes.
- First-launch `.rollcall` files opened from Share, AirDrop, or Files now land on the imported-team handoff so new users can review readiness or open Game Day instead of falling back into generic setup.
- Roster CSV import now explains the expected `name, number` format, warns about possible duplicate rows before import, and creates an automatic backup before adding players.
- Readiness now refreshes automatically when network status, audio route, or device output volume changes, keeping Game Day warnings closer to the current field setup.
- Support bundles now redact team names and stable IDs while keeping team counts and diagnostics useful for troubleshooting.
- Saved app state and `.rollcall` packages now reject future schema versions explicitly, preserving newer saved state as a recovery copy and asking users to update Roll Call instead of attempting a partial load/import.
- If saved app state exists but cannot be decoded at launch, Roll Call now preserves a recovery copy of the unreadable `state.json` before starting from an empty state and surfaces a clear warning.
- App state persistence now uses a serialized, versioned writer so rapid edits cannot let an older queued snapshot overwrite newer saved state.
- Game Day live playback now validates stored local and built-in cue assets before selecting them, falling back to `Small Cheer` when a configured cue file is missing.
- Shared media assets are now protected when duplicated teams or players reference the same local files. Clearing, replacing, or removing one player no longer deletes or overwrites an asset that another player still uses.
- Restoring a backup now asks for confirmation before replacing current teams, players, and clips, makes clear that current settings stay in place, and still creates the automatic safety backup first.
- Closing the Player Editor with unsaved changes now asks before discarding edits, protecting trim adjustments and other player updates that have not been saved yet.
- Player Editor copy now makes the mixed save behavior clearer: song, imported audio, and Announcement Cue changes save right away, while name, number, photo, and trim edits still depend on Save.
- Package import wording now clearly says `.rollcall` imports add a new team and leave existing teams unchanged.
- Package imports now reject unsafe asset references and only read simple file names from the package asset folder.
- Package imports now reject incomplete packages when a player cue references a local audio asset that is missing from the package.
- Game Day player grid tiles now preserve the button accessibility trait while keeping their custom VoiceOver labels, values, and hints.
- Release-facing docs now agree on version `1.0.1` build `54`, and the README now points readers to the public Roll Call website.
- Fix for misfiring onboarding
- Fix .rollcall icons/import/import process
- Fix Fade-out ending too soon
- Sidelark links updated



## Draft Public Release notes for 1.0.1


This bugfix update focuses on reliability and safer imports/backups.

Highlights include:

* Improved handling of .rollcall files - fixed registering with iOS, and safer/clearer imports from Share, AirDrop, and Files.
* Improved safety around imports and restores that could inadvertently cause overwrites.
* Improved CSV roster import.
* Improved Game Day readiness warnings when device setttings change.
* Improved Game Day playback reliability by handling missing files with "cheer" backup instead of failing silently.
* Fixed an issue where automated audio fade-outs (if enabled in settings) could end too soon making the last moment of the song too loud.
* Improved handling of shared audio files when duplicating teams or players.
* Improved handling of app data created by different versions of Roll Call.
* Improved support bundle privacy.
* Updated internal links and references to "Sidelark Labs" (though Sidelark Labs is still just me. Hi, by the way! I'm John!)
* Many other minor fixes and tweaks to enhance usability.