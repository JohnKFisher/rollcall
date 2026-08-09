# Where We Stand

Use this file as the concise status snapshot for the current checked-in app. Detailed decisions belong in [DECISIONS.md](./DECISIONS.md); public release wording belongs in [product/PUBLIC_CHANGELOG.md](./product/PUBLIC_CHANGELOG.md).

## Current release

- Version: `1.2.2`
- Build: `80`
- The app is an iPhone-first, on-device walk-up cue app. The full feature set remains free, with optional support contributions in Settings/About.

## What is in place

- Game Day remains the protected live workflow: choose a player, play the cue, and fall back safely when player-specific audio or an announcement is unavailable.
- Music Library is the primary song path. Apple Music search and file import remain explicit alternatives, and all paths use the shared draft clip editor.
- Readiness distinguishes `Ready on Any Device`, `Ready on This Device`, `Preparing`, `Needs Apple Music`, and `Needs Repair`. Readiness informs setup but never blocks Game Day.
- Local clip generation is limited to media that public APIs expose as genuinely readable. Source-backed Apple Music or Music Library playback remains a supported, honest device-dependent path.
- Custom Clips are team-specific live clips independent from Player Songs after copying. They support explicit edit mode, ordering, Recently Deleted recovery, and package export/import.
- Team packages and backups preserve team ownership and saved media choices. Missing or unavailable media is reported for repair rather than silently discarded.
- Teams support roster editing, lineup order/presence, CSV import, package sharing/import, and managed Apple Music playlist creation.
- Settings includes recovery, readiness-related preferences, What's New, rating/support surfaces, Attributions & Licenses, and non-Release Developer Tools.
- Support purchases are optional StoreKit contributions. They do not unlock features, affect readiness or Game Day, or travel with teams and backups. Transaction updates are observed from app launch.
- Build environments are separated into Debug, Internal, and Release configurations with centralized feature-flag safety. See [Build Environments](./development/BUILD_ENVIRONMENTS.md).

## Known limitations and remaining proof

- Final release confidence still needs physical-device checks for Music Library selection, Apple Music authorization/subscription states, audible source-backed versus generated playback, package transfer, and repair behavior.
- The current iOS 17 deployment floor and the known iPad/Game Day playback path still deserve a representative device smoke pass before a future release claim treats them as fully field-proven.
- Full-song Apple Music trimming, source-backed fade behavior, hook suggestions, and Apple Music playlist mutation remain device/account-sensitive and should not be treated as simulator-proven.
- Waveforms and per-cue gain remain intentionally deferred.
- Recovery and support-bundle surfaces have automated coverage, but manual checks should use disposable data and confirm that user names, filenames, song metadata, and purchase state stay out of exported support/team artifacts.

## Immediate priorities

1. Complete the final physical-device audio and Apple Music pass.
2. Transfer a mixed team package to another device and verify local, source-backed, missing, and repair outcomes.
3. Smoke export preview, import audit, recovery, and non-Release storage-inspection surfaces with disposable data.

## Current references

- [Application Overview](./product/APP_OVERVIEW.md)
- [Product Opportunities](./product/PRODUCT_OPPORTUNITIES.md)
- [Decisions](./DECISIONS.md)
- [Working Changelog](./WORKING_CHANGELOG.md)
- [Historical Archive](./historical/README.md)
