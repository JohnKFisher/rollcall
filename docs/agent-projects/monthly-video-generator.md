# Monthly Video Generator Project Profile

Read this when the repository/task is Monthly Video Generator or touches video generation, rendering, export, FFmpeg/external tools, HDR/color/brightness/timing, output filenames, temp/render cleanup, source media safety, or packaged distribution.

Do not read this for unrelated projects.

## Identity

Monthly Video Generator is a Sidelark Labs project. Future bundle identifiers should use `com.sidelarklabs.*` unless a project decision says otherwise.

## Protected core areas

This project's core value is reliable video output. Treat these as protected:

- render path,
- color, HDR, brightness, and timing,
- final export behavior,
- source media safety,
- app-owned temp/render cleanup,
- output filenames and generated descriptions,
- external tool/FFmpeg behavior,
- Plex/Infuse/Apple TV compatibility assumptions.

General rules live in universal files: `media-render-export.md`, `long-running-work.md`, `untrusted-input-tools.md`, `user-data-permissions.md`, `dependencies-assets.md`, and `ci-release-distribution.md`.

Treat final exported media as the project's primary deliverable.

Changes affecting rendering, codecs, timing, HDR, metadata, filenames, thumbnails, or compatibility require verification of final output quality before completion.

## UX defaults

Prefer setup-first, preset-first, and ready/not-ready guidance. Reduce cognitive load. Keep codec/HDR/FFmpeg internals out of primary flows unless the user is in Advanced settings.

## Verification quirks

If scripts exist, prefer the project's documented test/build scripts. For SwiftPM verification, a clean scratch path under `/private/tmp` may be useful when stale `.build` or signing/xattr issues appear.

Good defaults:

- docs/copy-only: `git diff --check`,
- small SwiftUI layout/copy batch: `git diff --check`, then one focused build if compile risk exists,
- view-model/state changes: targeted view-model tests,
- render/export/HDR/media behavior: targeted tests plus focused build/smoke check when risk justifies it,
- packaging/signing/release: read `ci-release-distribution.md` and use the documented build/package path.

Do not repeatedly rerun full Swift builds after small UI/copy changes. Batch checks and scale to risk.
