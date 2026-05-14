# Where We Stand

Use this file as a concise project status snapshot for the current version, what works, known limitations, and next priorities.

## Roll Call

Current version: `0.3.5` (build `4`)

Status:
- Active prototype with a buildable iPhone app target at [RollCall.xcodeproj](/Users/jkfisher/Documents/Coding/Roll%20Call/RollCall.xcodeproj).
- The repository has been cleaned up so the working source of truth is back on the intended `RollCall/` and `RollCall.xcodeproj/` names.

What works now:
- Team selection and duplication
- Selected-team rename from the Teams panel
- Player roster editing
- Today’s lineup editing with present-player tracking and next-batter flow
- Dedicated Apple Music picker with app-wide recents, debounced search, subscription-aware guidance, row preview, and immediate selection
- Apple Music search and playback recovery that falls back to preview-only results or preview clip playback when MusicKit catalog token access is unavailable
- Local audio import plus video-to-audio extraction
- Trim-focused cue editor with song summary, suggested-hook vs start-at-beginning choices, start scrubber, preset lengths, Advanced fine tuning, and subscription-aware full-song vs preview-only Apple Music trimming
- Cue timing preview from the editor
- Team-scoped Built-in Voice settings with phrase tokens, Apple voice selection, preview, and batch regeneration
- Per-player optional custom announcer recording with Game Day playback preferring custom intro over Built-in Voice
- Game Day announcer mode switch for cue-only vs announcer-plus-cue playback
- Game Day built-in announcer playback can recover by regenerating and storing a missing built-in intro on demand when no custom recording is available
- Apple Music cue caps, subscription-aware full-song playback, and cue prewarming hooks
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
- Apple Music full-song trimming now depends on a device account state that this environment cannot emulate, so it still needs an on-device feel pass with and without an active Apple Music playback subscription.
- The new Apple Music hook suggestion is intentionally conservative and still needs an on-device feel pass to judge whether its default entrance guesses are actually helpful.
- Protected mode currently focuses on exit confirmation and reduced Game Day editing affordances; it does not yet use Guided Access or OS-level lock-down helpers.
- Built-in announcer clips regenerate in batch when Built-in Voice settings are saved or a package is imported, but player name/number/pronunciation edits still invalidate the generated built-in intro and then rely on readiness until the next regeneration pass.
- Startup and tap responsiveness have been tightened by deferring/coalescing some follow-up work and moving snapshot restore I/O off the main actor, but this still needs an on-device feel pass to confirm the improvement.

Verification:
- `xcodebuild -project '/Users/jkfisher/Documents/Coding/Roll Call/RollCall.xcodeproj' -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath '/Users/jkfisher/Documents/Coding/Roll Call/.DerivedData' build`
- `xcrun swift-frontend -typecheck -primary-file RollCall/Services.swift RollCall/Models.swift RollCall/AppModel.swift RollCall/RootView.swift RollCall/RollCallApp.swift -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios18.0`
- Result in this session: the direct Swift frontend typecheck for the edited playback path succeeded. The icon set was regenerated as opaque PNGs so the prior app-icon alpha problem is gone, but the full generic iOS `xcodebuild` still stops later because local CoreSimulator services are unavailable for `actool` and storyboard compilation in this environment.

Recommended next priorities:
1. Launch `0.3.5` on-device and do a focused smoke pass for the Apple Music picker, full-song vs preview-only trim behavior, hook suggestion feel, local import, and announcer-enabled preview.
2. Replace placeholder built-in sounds with real licensed assets and add machine-readable attribution tracking.
3. Add focused verification around package import/export round-trips, support-bundle contents, and announcer-enabled cue playback on-device.
