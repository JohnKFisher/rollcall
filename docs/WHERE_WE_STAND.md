# Where We Stand

Use this file as a concise project status snapshot for the current version, what works, known limitations, and next priorities.

## Roll Call

Current version: `0.2.0` (build `3`)

Status:
- Active prototype with a buildable iPhone simulator app at [RollCall.xcodeproj](/Users/jkfisher/Documents/Coding/Roll%20Call/RollCall.xcodeproj).
- The repository has been cleaned up so the working source of truth is back on the intended `RollCall/` and `RollCall.xcodeproj/` names.

What works now:
- Team selection and duplication
- Selected-team rename from the Teams panel
- Player roster editing
- Today’s lineup editing with present-player tracking and next-batter flow
- Dedicated Apple Music picker with app-wide recents, debounced search, row preview, and immediate selection
- Local audio import plus video-to-audio extraction
- Trim-focused cue editor with song summary, suggested-hook vs start-at-beginning choices, start scrubber, preset lengths, and Advanced fine tuning
- Cue timing preview from the editor
- Team-scoped Built-in Voice settings with phrase tokens, Apple voice selection, preview, and batch regeneration
- Per-player optional custom announcer recording with Game Day playback preferring custom intro over Built-in Voice
- Game Day announcer mode switch for cue-only vs announcer-plus-cue playback
- Apple Music cue caps and cue prewarming hooks
- Experimental Apple Music local-copy flag and one-way conversion action
- Game Day big-button player grid with protected mode, haptics toggle, and panic stop
- General Clips tab using the shared cue engine
- Readiness dashboard with Apple Music, asset, and cue-specific checks
- `.rollcall` package export/import with bundled local media, custom announcer audio, generated built-in announcer audio, roster photos, and saved Built-in Voice profile data
- Safety snapshots plus in-app restore
- CSV roster import with preview before apply
- Branded launch screen based on the Music Triage splash style
- Developer Tools screen with experimental controls and support-bundle export

Known limitations:
- Built-in safety sounds still use generated placeholders; real licensed crowd-style assets and `ATTRIBUTIONS.md` work remain future follow-up.
- Waveforms and per-cue gain remain intentionally deferred.
- Physical-device installs now depend on a valid local Apple development provisioning profile for `com.jkfisher.rollcall`; project signing is configured, but first-run provisioning may still need Xcode account/device approval on this Mac.
- The current verification environment cannot complete asset catalog compilation because local CoreSimulator runtimes are unavailable to `actool` in this session, so the latest pass reached Swift compilation successfully but still could not complete a full device/simulator build.
- The new Apple Music hook suggestion is intentionally conservative and still needs an on-device feel pass to judge whether its default entrance guesses are actually helpful.
- Protected mode currently focuses on exit confirmation and reduced Game Day editing affordances; it does not yet use Guided Access or OS-level lock-down helpers.
- Built-in announcer clips regenerate in batch when Built-in Voice settings are saved or a package is imported, but player name/number/pronunciation edits still invalidate the generated built-in intro and then rely on readiness until the next regeneration pass.
- Startup and tap responsiveness have been tightened by deferring/coalescing some follow-up work and moving snapshot restore I/O off the main actor, but this still needs an on-device feel pass to confirm the improvement.

Verification:
- `xcodebuild -project '/Users/jkfisher/Documents/Coding/Roll Call/RollCall.xcodeproj' -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath '/Users/jkfisher/Documents/Coding/Roll Call/.DerivedData' build`
- Result in this session: all edited Swift sources compiled; the build then failed in asset compilation because no simulator runtimes were available to `actool` in the local environment.

Recommended next priorities:
1. Launch `0.2.0` in Simulator or on-device and do a focused smoke pass for the new Apple Music picker, trim workflow, hook suggestion feel, local import, and announcer-enabled preview.
2. Replace placeholder built-in sounds with real licensed assets and add machine-readable attribution tracking.
3. Add focused verification around package import/export round-trips, support-bundle contents, and announcer-enabled cue playback on-device.
