# Where We Stand

Use this file as a concise project status snapshot for the current version, what works, known limitations, and next priorities.

## Roll Call

Current version: `1.0.0` (build `42`)

Status:
- Active prototype with a buildable iPhone app target at [RollCall.xcodeproj](/Users/jkfisher/Documents/Coding/Roll%20Call/RollCall.xcodeproj).
- The repository has been cleaned up so the working source of truth is back on the intended `RollCall/` and `RollCall.xcodeproj/` names.
- `1.0.0` build `42` prepares the App Store submission polish pass: clearer Setup Guide first-page/import copy, Gray and Black team colors, tighter onboarding trim layout, Suggested Hook applied immediately, added-player setup continuing into audio, default `Announcer+Song`, and updated feedback wording.
- `0.7.1` build `41` rephrases the Special Thanks attribution for the girls of the Piscataway Thunder Softball Team.
- `0.7.1` build `40` adds a Settings > About feedback email link whose subject includes the current app version, build number, and build environment.
- `0.7.1` build `39` keeps the Setup Guide on the three-player lineup recommendation after a sub-three lineup preview while enabling Got It, and mentions fine-tuning song clips in the Ready to Try handoff.
- `0.7.1` build `38` simplifies the Setup Guide Ready to Try panel so the only in-panel action is opening Game Day, with completion copy that points later roster polish back to the Players tab.
- `0.7.1` build `37` gives the Setup Guide lineup step two modes: fewer than three players emphasizes adding enough players to reach three while still allowing lineup review, and three or more players emphasizes opening Today’s Lineup before continuing.
- `0.7.1` build `36` asks users to confirm before closing the manually relaunched Setup Guide, recommending that first-time users complete onboarding once before leaving.
- `0.7.1` build `35` adds explanatory text to Today’s Lineup so setup and regular app users know to turn off absent players, arrange batting order, and expect Game Day to use those changes.
- `0.7.1` build `34` updates the Setup Guide Lineup step to encourage three players and adds an in-guide Add Another Player path back to the player form.
- `0.7.1` build `33` changes the Setup Guide audio heading after song selection so the return screen clearly reads as trim mode instead of the original choice step.
- `0.7.1` build `32` adds the draggable start selector to the simplified Setup Guide audio trim step, without the Player Editor's Enable/Done gate.
- `0.7.1` build `31` personalizes the Setup Guide audio prompt with the player's name and separates the song-pick reassurance into a second paragraph.
- `0.7.1` build `30` adjusts Setup Guide audio copy to make the crowd-cheer fallback clearer and more playful.
- `0.7.1` build `29` keeps the setup guide's audio step focused after song selection: it removes the Advanced Setup jump, stays on audio after choosing/importing a cue, and offers simple starting-point, length, and preview controls before Lineup.
- `0.7.1` build `28` polishes the setup guide: onboarding text fields are more visible, the optional player number field is labeled as optional, the milestone row reads as passive location context instead of buttons, and Back lets users revisit earlier team/player/audio/lineup answers during setup.
- `0.7.1` build `27` adds first-run onboarding: new installs start empty instead of with a sample team, setup can create/import/review teams, users are guided through team color, first player, audio or an explicit cheer fallback, lineup orientation, and Game Day, and Settings can reopen the setup guide at any time.
- `0.7.1` build `26` adds a live playback tail guard for songs and waits for Announcement Cue playback to actually finish before moving on, reducing the risk that Game Day cuts off or fades practical audio before the end of a cue.
- `0.7.0` build `25` collects the live-screen appearance setting, shared Game Day/Clips gradient background, Readiness check polish, Player Editor announcement cue copy, and Advanced Trim fade automation guidance. The live appearance matrix now lives in `docs/product/APPEARANCE_RULES.md` so future changes preserve Light Mode, Dark Mode, the forced-dark live setting, and the Game Day lineup sheet behavior together.
- `0.6.6` build `23` tightens live playback volume automation, adds an automatic pre-restore backup before backup restores, fixes the Game Day announcer mode Sendable warning, and keeps recent Readiness/roster copy and status polish together.
- `0.6.5` build `22` collects the latest live-surface UI copy and icon cleanup: Game Day player-tile labels/icons, fallback wording, Readiness announcement wording, Players row song/announcement states, Clips header treatment, and the local dark rendering for the Game Day announcer mode picker.
- `0.6.0` build `21` aligns the Readiness experience with the accepted product model: readiness now answers whether today’s lineup can confidently run Game Day, not whether setup is “complete.”
- The repository is now licensed for noncommercial source-available use with Roll Call-specific attribution, source-sharing, commercial-use, and asset-boundary terms.

What works now:
- Team selection, duplication, and confirmed removal
- First-run setup guide for creating or importing teams, with a Settings entry that can reopen onboarding at any time and a simplified post-song trim step before lineup handoff
- Stored team accent color presets, now including Gray and Black, used by the TeamBar accent
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
- Game Day announcer mode picker with `Announcer Only`, `Announcer+Song`, and `Song Only`, defaulting new/missing-mode teams to `Announcer+Song`
- Player roster and Game Day views now show custom-intro coverage alongside cue coverage
- Player roster rows now say whether a song is selected and whether an announcement is recorded using the current simplified announcement language
- Game Day player taps now fall back to built-in `Small Cheer` when the player has no selected song cue
- Apple Music cue caps, subscription-aware full-song playback, metadata hydration for full-song trim timelines, and cue prewarming hooks
- Apple Music full-song playback now forces the current cue trim start when replaying catalog songs, to avoid stale start-position behavior on reused selections
- Game Day playback now gives local, preview, and catalog song cues a short tail guard before app-driven stop/fade cleanup, and Announcement Cues are sequenced from actual playback completion instead of a fixed duration sleep.
- Cue fade-out timing now runs before app-driven stop cleanup for local audio and preview-based Apple Music playback, with the short tail guard preserving the audible end of the cue.
- Settings now includes a `Fade-Out Volume Automation` switch so Roll Call can either manage cue volume for fades or leave playback volume untouched
- Advanced Trim now notes that Fade Out timing is only used when `Fade-Out Volume Automation` is enabled in Settings.
- Settings now includes a default-on `Always Use Dark Live Screens` switch. Setup screens always follow the device appearance; `Game Day`, `Clips`, and the Game Day lineup sheet render dark when the device is dark or the setting is on, otherwise they render in normal Light Mode. Both live screens share a reusable system-background gradient with a centralized accent tint for future editability.
- Subscribed full-song Apple Music playback now routes through an internal MediaPlayer application-player path so the same Apple Music cue can attempt stepped fade-out in trim preview, cue preview, and Game Day without changing the cue model
- Experimental Apple Music local-copy flag and one-way conversion action
- Main tab roots now use a pinned, full-width TeamBar at the top of the screen instead of repeating panel-name headers; Game Day keeps its dark live-side board with a top announcer-mode picker, compact live warning strip, Now Batting hero, On Deck area, centered `Prev / Edit Lineup / Next` row, divider before the grid, and obvious active tap-to-stop state
- General Clips tab using the shared cue engine with bundled licensed crowd clips tracked in `ATTRIBUTIONS.md`, now visually aligned with Game Day through the same live-side gradient background.
- Readiness confidence dashboard with player-specific audio as Ready, Announcement Cues as Enhanced, missing player audio as a non-blocking need, optional polish separated from readiness, direct player repair routing, and before-start device checks kept separate from player status
- `.rollcall` package export/import with bundled local media, custom intro audio, and roster photos
- `.rollcall` export now produces a zipped single-file archive (with backward-compatible import support for older directory-style packages)
- AirDropped or shared `.rollcall` files can now open directly into Roll Call's existing import flow, the manual import picker accepts `.rollcall` files even when Files surfaces them as generic file data, and the app now advertises `.rollcall` as an editable document type it owns
- Settings import now uses an explicit document picker so `.rollcall` files and legacy package folders can actually be chosen on-device
- Manual backups plus in-app restore, with automatic pre-import backups and retention capped to the newest 10
- CSV roster import with preview before apply
- Branded launch screen based on the Music Triage splash style
- Developer Tools screen with experimental controls and support-bundle export
- Developer Tools now includes an experimental Apple Music team playlist sync button that updates `Roll Call - <Team Name>` from the selected team's catalog-backed Apple Music cues
- Build-environment support now separates `Debug`, `Internal`, and `Release` configurations/schemes, with centralized `BuildEnvironment` / `FeatureFlags` guardrails so Release hides Developer Tools and experimental testing surfaces
- Settings > About now shows app version, build number, build environment, and an email feedback link with version details in the subject
- Settings > About > Attributions & Licenses now includes a Special Thanks section for the girls of the Piscataway Thunder Softball Team
- Repo README and license notice now describe the public noncommercial fork policy, commercial-permission boundary, small-snippet exception, and third-party asset attributions.

Known limitations:
- Waveforms and per-cue gain remain intentionally deferred.
- Physical-device installs now depend on a valid local Apple development provisioning profile for `com.jkfisher.rollcall`; full-song Apple Music also requires the MusicKit App Service to be enabled for that App ID in Apple Developer.
- Apple Music full-song trimming now depends on a device account state and MusicKit App Service configuration that this environment cannot emulate, so it still needs an on-device feel pass with and without an active Apple Music playback subscription after App ID registration/provisioning refresh.
- The new subscribed-song MediaPlayer backend is implemented but still unproven on a real subscribed device; until that on-device check passes, full-song Apple Music fade behavior should still be treated as provisional.
- The new Apple Music hook suggestion is intentionally conservative and still needs an on-device feel pass to judge whether its default entrance guesses are actually helpful.
- Roll Call now gives only lightweight Focus guidance for interruptions; it still does not have OS-level Do Not Disturb or Guided Access integration.
- In `Announcer Only`, players without a recorded Announcement Cue fall back to `Small Cheer`; in `Announcer+Song`, missing announcers are skipped and missing songs fall back to `Small Cheer`. This fallback is live-safe but does not count as player-specific Ready status in Readiness.
- The no-song Game Day fallback clip is currently code-defaulted to `Small Cheer`; a user-facing selector for changing that default is not implemented yet.
- Local audio import still exists as a fallback path, but it has been moved behind a secondary disclosure in the player editor so Apple Music remains the obvious primary flow.
- Startup and tap responsiveness have been tightened by deferring/coalescing some follow-up work and moving snapshot restore I/O off the main actor, but this still needs an on-device feel pass to confirm the improvement.

Verification:
- Result in this `0.7.1` build `29` setup-audio guide pass: `xcrun swiftc -parse RollCall/Models.swift RollCall/Services.swift RollCall/AppModel.swift RollCall/RootView.swift` succeeded; sandboxed `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` was blocked by SwiftPM/Xcode cache permissions; the same signing-disabled build succeeded out of sandbox. Xcode still emits the unrelated AppIntents metadata note because no AppIntents framework dependency is present.
- Result in this `0.7.1` build `28` setup polish pass: `xcrun swiftc -parse RollCall/RootView.swift` succeeded; `git diff --check` succeeded; sandboxed `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` was blocked by SwiftPM/Xcode cache permissions; the same signing-disabled build succeeded out of sandbox. Xcode still emits the unrelated AppIntents metadata note because no AppIntents framework dependency is present.
- Result in this `0.7.1` build `27` onboarding pass: `xcrun swiftc -parse RollCall/Models.swift RollCall/Services.swift RollCall/AppModel.swift RollCall/RootView.swift` succeeded; raw `swift-frontend` typecheck could not load `ZIPFoundation`, which is expected outside the Xcode package context; sandboxed `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` was blocked by SwiftPM/Xcode cache permissions; the same signing-disabled build succeeded out of sandbox; XcodeBuildMCP build/run on `iPhone 17 Pro` succeeded. Screenshot capture also succeeded, but the simulator already had an existing `Home Team` state, so it verified launch on the existing app state rather than a pristine first-run screen.
- Result in this `0.7.1` build `26` playback-tail repair: `xcrun swiftc -parse RollCall/Models.swift RollCall/Services.swift RollCall/AppModel.swift RollCall/RootView.swift` succeeded; an out-of-sandbox `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` succeeded. On-device audio feel still needs confirmation because this environment cannot reproduce the iPhone speaker/Apple Music runtime path.
- Result in this `0.7.0` build `25` checkpoint: `xcrun swiftc -parse RollCall/Models.swift RollCall/Services.swift RollCall/AppModel.swift RollCall/RootView.swift` succeeded; `git diff --check` succeeded. Full Xcode build and simulator visual verification were not run in this pass.
- Result in this `0.6.7` build `24` patch bump: `xcrun swiftc -parse RollCall/Models.swift RollCall/Services.swift RollCall/AppModel.swift RollCall/RootView.swift` succeeded; `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` succeeded out of sandbox. Xcode still emits the unrelated AppIntents metadata note because no AppIntents framework dependency is present.
- Result in this shared live-background follow-up: `xcrun swiftc -parse RollCall/RootView.swift` succeeded.
- Result in this `0.6.6` build `23` safety/playback pass: `xcrun swiftc -parse RollCall/Models.swift RollCall/Services.swift RollCall/AppModel.swift RollCall/RootView.swift` succeeded; an out-of-sandbox `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` succeeded. The previous `GameDayAnnouncerModePicker` Sendable warning is fixed; Xcode still emits the unrelated AppIntents metadata note because no AppIntents framework dependency is present.
- Result in this live-screen appearance setting pass: `xcrun swiftc -parse RollCall/Models.swift RollCall/AppModel.swift RollCall/RootView.swift` succeeded; sandboxed `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination generic/platform=iOS -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` was blocked by SwiftPM/Xcode cache permissions; the same signing-disabled build succeeded out of sandbox. The build still reports the pre-existing `GameDayAnnouncerModePicker` Sendable warning.
- Result in this `0.6.5` build `22` UI copy/icon pass: `xcrun swiftc -parse RollCall/Models.swift RollCall/Services.swift RollCall/RootView.swift` succeeded; `git diff --check` succeeded. Full Xcode build and simulator visual verification were not run in this pass.
- Result in the pinned-TeamBar navigation pass: `xcrun swiftc -parse RollCall/RootView.swift` succeeded; an out-of-sandbox `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` succeeded. The build still reports the pre-existing `GameDayAnnouncerModePicker` Sendable warning.
- Result in this `0.6.0` build `21` readiness-model pass: `xcrun swiftc -parse RollCall/Models.swift RollCall/Services.swift RollCall/RootView.swift` succeeded; an out-of-sandbox `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build` succeeded; XcodeBuildMCP build/run on `iPhone 17 Pro` succeeded. Simulator smoke confirmed Readiness shows player-audio confidence, optional upgrades stay separate, `Open Game Day` switches to the live board, fallback remains visible without a fallback warning strip, and a `Needs Audio` row opens the player editor. The build still reports the pre-existing `GameDayAnnouncerModePicker` Sendable warning.
- `xcrun swiftc -parse RollCall/RootView.swift`
- `xcrun swift-frontend -typecheck -module-cache-path /private/tmp/rollcall-module-cache -primary-file RollCall/RootView.swift RollCall/Services.swift RollCall/Models.swift RollCall/AppModel.swift RollCall/RollCallApp.swift -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios18.0`
- `xcodebuild -project '/Users/jkfisher/Documents/Coding/Roll Call/RollCall.xcodeproj' -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath '/Users/jkfisher/Documents/Coding/Roll Call/.DerivedData' build`
- `xcodebuild -project '/Users/jkfisher/Documents/Coding/Roll Call/RollCall.xcodeproj' -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath '/Users/jkfisher/Documents/Coding/Roll Call/.DerivedData' CODE_SIGNING_ALLOWED=NO build`
- Result in this `0.6.0` build `20` attribution update: an out-of-sandbox `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS Simulator' -derivedDataPath .DerivedData/Verification CODE_SIGNING_ALLOWED=NO build` succeeded. The sandboxed attempt failed before compile because it could not reach GitHub to resolve `ZIPFoundation`.
- `xcrun swift-frontend -typecheck -primary-file RollCall/Services.swift RollCall/Models.swift RollCall/AppModel.swift RollCall/RootView.swift RollCall/RollCallApp.swift -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios18.0`
- Result in this `0.5.2` build bump: source build succeeded with signing disabled. A normal signed build reached codesign, then failed on stale extended-attribute detritus in the existing workspace `.DerivedData` app product; a fresh temp DerivedData build could not resolve `ZIPFoundation` because sandboxed network access to GitHub was unavailable.
- Result in the most recent Player Editor visual pass: `RootView.swift` parsed successfully, but standalone typecheck could not load `ZIPFoundation`, and sandboxed `xcodebuild` could not complete because Xcode/SwiftPM tried to write diagnostics under `/Users/jkfisher/Library/Caches/org.swift.swiftpm` while the approval path for an out-of-sandbox build was unavailable. Simulator screenshots were also blocked in this pass by the same build/run limitation. The remaining verification is a full local Xcode build plus Player Editor simulator/on-device smoke screenshots for no-cue, configured cue, trim-visible, and Announcement Cue states.
- Result in the most recent verified build session before this version bump: the in-sandbox check was blocked by cache and CoreSimulator restrictions, but an out-of-sandbox `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' build` completed successfully for `0.4.9` (build `13`) before the Game Day visual pass. XcodeBuildMCP then completed simulator build/run verification after the Game Day redesign. The remaining verification is an on-device smoke pass for AirDrop-opened `.rollcall` imports, manual picker selection of AirDropped `.rollcall` files stored in Files, whether Files now prefers Roll Call as the open target for `.rollcall`, subscribed Apple Music MediaPlayer fade behavior with the setting on and off, repeated non-zero trim starts, preview-only fallback trimming, custom-intro playback, and bright-condition Game Day readability.

Recommended next priorities:
1. Run a pristine-install simulator or device smoke pass for onboarding: create team, skip/select accent, add player, use Apple Music/local audio or Try with Cheer, open lineup orientation, hand off to Game Day, reopen Setup Guide from Settings, and import a `.rollcall` package from onboarding.
2. Enable the MusicKit App Service for App ID `com.jkfisher.rollcall`, refresh signing/provisioning, then launch `1.0.0` on-device and do a focused smoke pass for subscribed-device full-song trimming, repeated non-zero trim starts, MediaPlayer fade-out behavior in preview and Game Day, preview-only fallback trimming, custom-intro playback, direct AirDrop `.rollcall` opening, whether Files prefers Roll Call for `.rollcall`, manual picker selection from Files, and bright-field readability with `Always Use Dark Live Screens` on and off.
3. Add focused verification around package import/export round-trips, AirDrop/open-in-place imports, support-bundle contents, and backup retention behavior after repeated imports.

Build environment docs:
- [BUILD_ENVIRONMENTS.md](/Users/jkfisher/Documents/Coding/Roll%20Call/docs/development/BUILD_ENVIRONMENTS.md)
