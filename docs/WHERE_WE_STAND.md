# Where We Stand

Use this file as a concise project status snapshot for the current version, what works, known limitations, and next priorities.

## Roll Call

Current version: `0.6.0` (build `19`)

Status:
- Active prototype with a buildable iPhone app target at [RollCall.xcodeproj](/Users/jkfisher/Documents/Coding/Roll%20Call/RollCall.xcodeproj).
- The repository has been cleaned up so the working source of truth is back on the intended `RollCall/` and `RollCall.xcodeproj/` names.
- `0.6.0` build `19` is the real-use pause build. The intended next step is to use it in the field for a week or two and collect only practical, field-relevant issues.

What works now:
- Team selection, duplication, and confirmed removal
- Selected-team rename from the Teams panel
- Player roster editing
- Today’s lineup editing with present-player tracking, next-batter flow, persisted manual order, and one-tap A-Z / number sorting
- Dedicated Apple Music picker with app-wide recents, debounced search, subscription-aware guidance, row preview, and immediate selection
- Apple Music search that uses catalog-backed MusicKit results for subscribed full-song mode and reserves iTunes preview fallback for preview-only mode
- Local audio import plus video-to-audio extraction
- Trim-focused cue editor with song summary, suggested-hook vs start-at-beginning choices, start scrubber, preset lengths, Advanced fine tuning, and subscription-aware full-song vs preview-only Apple Music trimming
- Player Editor now uses compact Roll Call visual-language cards, status chips, helper text, and button hierarchy while preserving the PE-1/PE-2 workflow
- Cue timing preview from the editor
- Per-player optional custom intro recording
- Game Day announcer mode picker with `Announcer Only`, `Announcer+Song`, and `Song Only`
- Player roster and Game Day views now show custom-intro coverage alongside cue coverage
- Game Day player taps now fall back to built-in `Small Cheer` when the player has no selected song cue
- Apple Music cue caps, subscription-aware full-song playback, metadata hydration for full-song trim timelines, and cue prewarming hooks
- Apple Music full-song playback now forces the current cue trim start when replaying catalog songs, to avoid stale start-position behavior on reused selections
- Cue fade-out timing now runs inside the requested clip length for local audio and preview-based Apple Music playback
- Settings now includes a `Fade-Out Volume Automation` switch so Roll Call can either manage cue volume for fades or leave playback volume untouched
- Subscribed full-song Apple Music playback now routes through an internal MediaPlayer application-player path so the same Apple Music cue can attempt stepped fade-out in trim preview, cue preview, and Game Day without changing the cue model
- Experimental Apple Music local-copy flag and one-way conversion action
- Game Day dark live-side board with a thin TeamBar, top announcer-mode picker, compact live warning strip, Now Batting hero, On Deck area, centered `Prev / Edit Lineup / Next` row, divider before the grid, and obvious active tap-to-stop state
- General Clips tab using the shared cue engine with bundled licensed crowd clips tracked in `ATTRIBUTIONS.md`
- Readiness dashboard with Apple Music, asset, and cue-specific checks
- `.rollcall` package export/import with bundled local media, custom intro audio, and roster photos
- `.rollcall` export now produces a zipped single-file archive (with backward-compatible import support for older directory-style packages)
- AirDropped or shared `.rollcall` files can now open directly into Roll Call's existing import flow, the manual import picker accepts `.rollcall` files even when Files surfaces them as generic file data, and the app now advertises `.rollcall` as an editable document type it owns
- Settings import now uses an explicit document picker so `.rollcall` files and legacy package folders can actually be chosen on-device
- Manual backups plus in-app restore, with automatic pre-import backups and retention capped to the newest 10
- CSV roster import with preview before apply
- Branded launch screen based on the Music Triage splash style
- Developer Tools screen with experimental controls and support-bundle export
- Developer Tools now includes an experimental Apple Music team playlist sync button that updates `Roll Call - <Team Name>` from the selected team's catalog-backed Apple Music cues
- Field-use checklist for the `0.6.0` pause at [FIELD_USE_CHECKLIST.md](/Users/jkfisher/Documents/Coding/Roll%20Call/docs/FIELD_USE_CHECKLIST.md)

Known limitations:
- Waveforms and per-cue gain remain intentionally deferred.
- Physical-device installs now depend on a valid local Apple development provisioning profile for `com.jkfisher.rollcall`; full-song Apple Music also requires the MusicKit App Service to be enabled for that App ID in Apple Developer.
- Apple Music full-song trimming now depends on a device account state and MusicKit App Service configuration that this environment cannot emulate, so it still needs an on-device feel pass with and without an active Apple Music playback subscription after App ID registration/provisioning refresh.
- The new subscribed-song MediaPlayer backend is implemented but still unproven on a real subscribed device; until that on-device check passes, full-song Apple Music fade behavior should still be treated as provisional.
- The new Apple Music hook suggestion is intentionally conservative and still needs an on-device feel pass to judge whether its default entrance guesses are actually helpful.
- Roll Call now gives only lightweight Focus guidance for interruptions; it still does not have OS-level Do Not Disturb or Guided Access integration.
- In `Announcer Only`, players without a recorded Announcement Cue fall back to `Small Cheer`; in `Announcer+Song`, missing announcers are skipped and missing songs fall back to `Small Cheer`.
- The no-song Game Day fallback clip is currently code-defaulted to `Small Cheer`; a user-facing selector for changing that default is not implemented yet.
- Local audio import still exists as a fallback path, but it has been moved behind a secondary disclosure in the player editor so Apple Music remains the obvious primary flow.
- Startup and tap responsiveness have been tightened by deferring/coalescing some follow-up work and moving snapshot restore I/O off the main actor, but this still needs an on-device feel pass to confirm the improvement.

Verification:
- `xcrun swiftc -parse RollCall/RootView.swift`
- `xcrun swift-frontend -typecheck -module-cache-path /private/tmp/rollcall-module-cache -primary-file RollCall/RootView.swift RollCall/Services.swift RollCall/Models.swift RollCall/AppModel.swift RollCall/RollCallApp.swift -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios18.0`
- `xcodebuild -project '/Users/jkfisher/Documents/Coding/Roll Call/RollCall.xcodeproj' -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath '/Users/jkfisher/Documents/Coding/Roll Call/.DerivedData' build`
- `xcodebuild -project '/Users/jkfisher/Documents/Coding/Roll Call/RollCall.xcodeproj' -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath '/Users/jkfisher/Documents/Coding/Roll Call/.DerivedData' CODE_SIGNING_ALLOWED=NO build`
- Result in this `0.6.0` build `19` real-use pause bump: an out-of-sandbox `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` succeeded, and the built app reported `CFBundleShortVersionString = 0.6.0` and `CFBundleVersion = 19`.
- `xcrun swift-frontend -typecheck -primary-file RollCall/Services.swift RollCall/Models.swift RollCall/AppModel.swift RollCall/RootView.swift RollCall/RollCallApp.swift -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios18.0`
- Result in this `0.5.2` build bump: source build succeeded with signing disabled. A normal signed build reached codesign, then failed on stale extended-attribute detritus in the existing workspace `.DerivedData` app product; a fresh temp DerivedData build could not resolve `ZIPFoundation` because sandboxed network access to GitHub was unavailable.
- Result in the most recent Player Editor visual pass: `RootView.swift` parsed successfully, but standalone typecheck could not load `ZIPFoundation`, and sandboxed `xcodebuild` could not complete because Xcode/SwiftPM tried to write diagnostics under `/Users/jkfisher/Library/Caches/org.swift.swiftpm` while the approval path for an out-of-sandbox build was unavailable. Simulator screenshots were also blocked in this pass by the same build/run limitation. The remaining verification is a full local Xcode build plus Player Editor simulator/on-device smoke screenshots for no-cue, configured cue, trim-visible, and Announcement Cue states.
- Result in the most recent verified build session before this version bump: the in-sandbox check was blocked by cache and CoreSimulator restrictions, but an out-of-sandbox `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' build` completed successfully for `0.4.9` (build `13`) before the Game Day visual pass. XcodeBuildMCP then completed simulator build/run verification after the Game Day redesign. The remaining verification is an on-device smoke pass for AirDrop-opened `.rollcall` imports, manual picker selection of AirDropped `.rollcall` files stored in Files, whether Files now prefers Roll Call as the open target for `.rollcall`, subscribed Apple Music MediaPlayer fade behavior with the setting on and off, repeated non-zero trim starts, preview-only fallback trimming, custom-intro playback, and bright-condition Game Day readability.

Recommended next priorities:
1. Enable the MusicKit App Service for App ID `com.jkfisher.rollcall`, refresh signing/provisioning, then launch `0.5.2` on-device and do a focused smoke pass for subscribed-device full-song trimming, repeated non-zero trim starts, MediaPlayer fade-out behavior in preview and Game Day, preview-only fallback trimming, custom-intro playback, direct AirDrop `.rollcall` opening, whether Files prefers Roll Call for `.rollcall`, and manual picker selection from Files.
2. Add focused verification around package import/export round-trips, AirDrop/open-in-place imports, support-bundle contents, and backup retention behavior after repeated imports.
3. If the MediaPlayer path is still flaky on-device, run one bounded silent-track crossfade experiment and then explicitly decide whether Apple Music field playback remains supportable without a local-only pivot.
