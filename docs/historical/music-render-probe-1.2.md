# Music Render Probe 1.2

Last updated: 2026-06-09

## 2026-06-10 Phase 2 Follow-Up

The Phase 2 SDK/API review confirmed that public iOS APIs do not let Roll Call request or control an Apple Music offline download. `MPMediaLibrary.addItem(withProductID:)` can add an item to the library, but that is not a download request and provides no reliable download-state workflow.

Phase 2 therefore implements only the supported paths:

- inspect existing Music Library items,
- observe `isCloudItem`,
- use `assetURL` only when iOS exposes a readable file,
- generate from that readable file,
- otherwise retain normal source-backed Apple Music playback.

## Purpose

Phase 0 adds a non-Release in-app `Music Render Probe` so Roll Call can test real renderability inside the app's own bundle, permission, and playback context before the broader 1.2 cue revamp changes land.

The probe is intentionally manual:

- assign real device-library songs to specific probe categories,
- assign Apple Music search results to catalog-focused categories,
- optionally assign an app-owned local import as a control sample,
- run the probe only after an explicit tap,
- keep results ephemeral unless the user explicitly exports the redacted summary.

## What The Probe Tests

For each assigned sample, Roll Call records two separate attempts:

1. `Full Source`
2. `Preview / Proxy`

That distinction matters:

- `Full Source` success is evidence that Roll Call can render a local clip from readable source media.
- `Preview / Proxy` success is useful fallback evidence, but it does **not** prove that aggressive Apple Music local generation is viable for 1.2.

## Probe Categories

- Readable Library Song
- Purchased Library Song
- Imported Library Song
- Apple Music In Library
- Downloaded Apple Music
- Apple Music Not In Library
- Catalog-Only Apple Music
- App-Owned Local Import

These categories are manual on purpose. If the current device cannot provide a clean example for a category, mark that category `untested` instead of guessing.

## Implemented Failure Categories

- Permission Needed
- Network Needed
- Source Unavailable
- Protected / Unreadable
- Render Failed (Transient)
- Render Failed (Permanent)
- Policy Disabled

## Current Findings

This coding session implemented the probe surface and its redacted summary export, but did **not** run a real-device probe pass.

Current status by category:

| Category | Status | Notes |
| --- | --- | --- |
| Readable Library Song | untested | assign on device and run |
| Purchased Library Song | untested | assign on device and run |
| Imported Library Song | untested | assign on device and run |
| Apple Music In Library | untested | assign on device and run |
| Downloaded Apple Music | untested | assign on device and run |
| Apple Music Not In Library | untested | assign on device and run |
| Catalog-Only Apple Music | untested | assign on device and run |
| App-Owned Local Import | untested | assign on device and run |

## Initial Policy Recommendation

Until a real-device probe pass records concrete successful `Full Source` cases, treat Apple Music-derived local generation as **not yet proven** for 1.2.

Practical starting policy:

- local/imported/readable library media: proceed with local generation work,
- Apple Music-derived media: keep the initial planning stance conservative and treat `sourceBackedOnly` as the fallback-safe assumption until probe evidence says otherwise.

This is a provisional policy anchor, not a final App Review conclusion.

## Candidate User-Facing Status Language

- `Local clip ready`
- `Preview fallback only`
- `Needs Apple Music to play`
- `Needs music access`
- `Needs network to try again`
- `This song could not be turned into a local clip`
- `Clip render failed. Try again.`

## Next Device Pass

Run the probe on a real iPhone with:

- one clearly readable device-library song,
- one purchased song if available,
- one imported library song if available,
- one Apple Music song saved in library,
- one downloaded Apple Music song,
- one Apple Music song not saved in library,
- one catalog-only Apple Music case,
- one app-owned local import already present in Roll Call.

After that pass:

1. replace the `untested` rows above with actual outcomes,
2. tighten the initial 1.2 generation policy in `docs/DECISIONS.md`,
3. update any user-facing status language that turned out to be misleading in practice.
