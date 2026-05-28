# Roll Call

Roll Call is an iPhone app for youth sports walk-up music, player introductions, and game-day cue playback.

For product details, screenshots, and the public app overview, visit:

https://sidelarklabs.com/rollcall/

This repository contains the source for Roll Call. Licensing and attribution details are available in [LICENSE](LICENSE), [ROLL-CALL-LICENSE-NOTICE.md](ROLL-CALL-LICENSE-NOTICE.md), and [ATTRIBUTIONS.md](ATTRIBUTIONS.md).

## How to Run Tests

In Xcode:

1. Open `RollCall.xcodeproj`.
2. Select the `Roll Call Debug` scheme.
3. Choose Product > Test.

From Terminal:

```sh
xcodebuild test \
  -project RollCall.xcodeproj \
  -scheme "Roll Call Debug" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /private/tmp/rollcall-derived
```

The unit suite is intentionally focused on fast core logic coverage for package import/export, roster CSV parsing, backup/restore safety, player persistence, lineup ordering, and readiness checks that do not require real audio playback or device-specific state.
