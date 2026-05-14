# Where We Stand

Use this file as a concise project status snapshot for the current version, what works, known limitations, and next priorities.

## Roll Call

Current version: `0.3.7` (build `6`)

Status:
- Active prototype with a buildable iPhone app target at [RollCall.xcodeproj](/Users/jkfisher/Documents/Coding/Roll%20Call/RollCall.xcodeproj).
- The repository has been cleaned up so the working source of truth is back on the intended `RollCall/` and `RollCall.xcodeproj/` names.

What works now:
- Team selection and duplication
- Selected-team rename from the Teams panel
- Player roster editing
- Today’s lineup editing with present-player tracking, next-batter flow, persisted manual order, and one-tap A-Z / number sorting
- Dedicated Apple Music picker with app-wide recents, debounced search, subscription-aware guidance, row preview, and immediate selection
- Apple Music search that uses catalog-backed MusicKit results for subscribed full-song mode and reserves iTunes preview fallback for preview-only mode
- Local audio import plus video-to-audio extraction
- Trim-focused cue editor with song summary, suggested-hook vs start-at-beginning choices, start scrubber, preset lengths, Advanced fine tuning, and subscription-aware full-song vs preview-only Apple Music trimming
- Cue timing preview from the editor
- Team-scoped Built-in Voice settings with phrase tokens, Apple voice selection, preview, and batch regeneration
- Per-player optional custom announcer recording with Game Day playback preferring custom intro over Built-in Voice
- Game Day announcer mode switch for cue-only vs announcer-plus-cue playback, with cue playback continuing even when built-in voice regeneration is unavailable
- Apple Music cue caps, subscription-aware full-song playback, metadata hydration for full-song trim timelines, and cue prewarming hooks
- Experimental Apple Music local-copy flag and one-way conversion action
- Game Day big-button player grid with active playback highlighting, Focus guidance, and a plain stop-audio affordance
- General Clips tab using the shared cue engine with bundled licensed crowd clips tracked in `ATTRIBUTIONS.md`
- Readiness dashboard with Apple Music, asset, and cue-specific checks
- `.rollcall` package export/import with bundled local media, custom announcer audio, generated built-in announcer audio, roster photos, and saved Built-in Voice profile data
- Manual backups plus in-app restore, with automatic pre-import backups and retention capped to the newest 10
- CSV roster import with preview before apply
- Branded launch screen based on the Music Triage splash style
- Developer Tools screen with experimental controls and support-bundle export

Known limitations:
- Waveforms and per-cue gain remain intentionally deferred.
- Physical-device installs now depend on a valid local Apple development provisioning profile for `com.jkfisher.rollcall`; full-song Apple Music also requires the MusicKit App Service to be enabled for that App ID in Apple Developer.
- Apple Music full-song trimming now depends on a device account state and MusicKit App Service configuration that this environment cannot emulate, so it still needs an on-device feel pass with and without an active Apple Music playback subscription after App ID registration/provisioning refresh.
- The new Apple Music hook suggestion is intentionally conservative and still needs an on-device feel pass to judge whether its default entrance guesses are actually helpful.
- Roll Call now gives only lightweight Focus guidance for interruptions; it still does not have OS-level Do Not Disturb or Guided Access integration.
- Built-in announcer clips regenerate in batch when Built-in Voice settings are saved or a package is imported, but invalid player/profile text still surfaces as readiness warnings until the next successful regeneration pass.
- Startup and tap responsiveness have been tightened by deferring/coalescing some follow-up work and moving snapshot restore I/O off the main actor, but this still needs an on-device feel pass to confirm the improvement.

Verification:
- `xcodebuild -project '/Users/jkfisher/Documents/Coding/Roll Call/RollCall.xcodeproj' -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath '/Users/jkfisher/Documents/Coding/Roll Call/.DerivedData' build`
- `xcrun swift-frontend -typecheck -primary-file RollCall/Services.swift RollCall/Models.swift RollCall/AppModel.swift RollCall/RootView.swift RollCall/RollCallApp.swift -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios18.0`
- Result in this session: the direct Swift frontend typecheck for the edited playback path succeeded. A follow-up generic iOS build proved that adding a local `com.apple.developer.music.user-token` entitlement is invalid for this target; MusicKit must be enabled as an App ID App Service instead. The remaining verification is an on-device smoke pass for full-song trimming after the App ID/provisioning refresh.

Recommended next priorities:
1. Enable the MusicKit App Service for App ID `com.jkfisher.rollcall`, refresh signing/provisioning, then launch `0.3.7` on-device and do a focused smoke pass for subscribed-device full-song trimming, preview-only fallback trimming, announcer-enabled playback, and the new Game Day active-state visuals.
2. Add focused verification around package import/export round-trips, support-bundle contents, and backup retention behavior after repeated imports.
3. Decide whether any future Focus integration should stay guidance-only or expand into App Intents / Shortcut-assisted setup.
