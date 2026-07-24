# Cue Revamp 1.2: Historical Implementation Record

Status: historical summary

The 1.2 cue revamp addressed the weakest part of the product: choosing, previewing, trimming, saving, sharing, and repairing walk-up audio.

## The important reversal

The original plan assumed that Roll Call could broadly turn Apple Music songs into portable local clips. The Phase 0/Phase 2 investigation narrowed that assumption:

- Public APIs expose readable media only in some cases.
- Roll Call can generate a local clip when it genuinely has a readable local source.
- Source-backed Apple Music or Music Library playback remains a normal supported outcome when a readable local source is unavailable.
- A downloaded or library-available song does not automatically become a packageable Roll Call-owned file.

The probe did not fail. It established a more honest product boundary.

## What the implementation carried forward

- Music Library is the primary song-selection path; Apple Music search and file import remain explicit alternatives.
- Song and file selections open a draft clip editor before replacing the saved assignment.
- The saved source-and-timing recipe remains meaningful even when a generated local asset is unavailable.
- Readiness distinguishes `Ready on Any Device`, `Ready on This Device`, `Preparing`, `Needs Apple Music`, and `Needs Repair`.
- Team packages preserve saved choices and explain portability or repair needs instead of silently dropping unavailable media.
- Game Day keeps a safe fallback path and does not require portable local generation for every cue.

## Hard boundaries

The revamp stayed within public APIs. It did not add private APIs, system-audio capture, DRM bypass, silent Music Library mutation, a remote policy switch, or a backend. These boundaries remain current product and architecture constraints.

## Evidence boundary

The implementation work, focused tests, and simulator/build checks do not by themselves prove every physical-device Apple Music, audible playback, export, or App Store release scenario. Current remaining verification belongs in [Where We Stand](../../WHERE_WE_STAND.md), not in this historical handoff.

This record replaces the former continuation prompt and separate music-render probe guide. Those files are retired as active instructions.
