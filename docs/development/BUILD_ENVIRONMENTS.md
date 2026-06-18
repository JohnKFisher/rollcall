# Build Environments

Roll Call uses one codebase with three build environments:

- `Debug`: local development on simulator or a development device.
- `Internal`: trusted TestFlight builds for trying incomplete or risky work before it is public.
- `Release`: public App Store builds.

All three currently use the same bundle identifier, `com.jkfisher.rollcall`. That keeps App Store Connect, MusicKit setup, document ownership, and signing aligned. It also means an Internal TestFlight build replaces the installed public app on a device.

## Xcode Schemes

Use these shared schemes in Xcode:

- `Roll Call Debug`: local development. Run uses the `Debug` build configuration.
- `Roll Call Internal`: internal TestFlight. Archive uses the `Internal` build configuration.
- `Roll Call Release`: public App Store. Archive uses the `Release` build configuration.

The older `RollCall` scheme still exists for compatibility and archives with `Release`.

## Feature Flags

The build and feature-flag entry points are:

- `BuildEnvironment.current`
- `FeatureFlags`
- `AppModel.featureFlags`
- persisted runtime toggles in `ExperimentalSettings`

Release builds must always resolve to:

- `showDeveloperSettings = false`
- `showExperimentalFeatures = false`

Debug builds force developer settings and experimental visibility on so local work is easy to exercise. Internal builds show Developer Tools, but experimental visibility comes from local persisted toggles. Roll Call's live product policy is all-features-free, and failed Apple Music local-copy / transition-crossfade experiments should stay removed from Developer Tools.

## Adding A Feature Flag

1. Add the persisted runtime toggle to `ExperimentalSettings` only if the flag should be adjustable while the app is running.
2. Add the centralized computed behavior to `FeatureFlags`.
3. Gate UI and actions through `appModel.featureFlags`, not scattered `#if DEBUG` checks.
4. Add the toggle and explanation to Developer Tools when it is safe for Debug/Internal testers to change.
5. Confirm `FeatureFlags.assertReleaseSafety()` still prevents unsafe Release exposure.

## App Store Archive Checklist

Before uploading a public build:

1. Select the `Roll Call Release` scheme.
2. Confirm Product > Scheme > Edit Scheme > Archive uses `Release`.
3. Confirm Settings > About shows environment `Release` in the built app.
4. Confirm Settings does not show `Advanced / Developer Tools`.
5. Confirm unfinished tabs, buttons, screens, and coming-soon UI are not visible.
6. Archive and distribute through the normal App Store Connect upload path.

For internal TestFlight-only validation, use `Roll Call Internal` and archive with `Internal`.
