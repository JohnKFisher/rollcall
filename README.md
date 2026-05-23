# Roll Call

Roll Call is an iPhone app for youth sports walk-up music, player introductions,
and game-day cue playback.

The 1.0 app has been submitted to the App Store. It is built for coaches,
parents, and community teams who want game day to feel more personal without
turning setup into homework.

## Status

Current release line: `1.0.0`

Current checked-in build: `49`

App Store status: submitted for initial App Store review on May 23, 2026.

Roll Call 1.0 is intended to be a complete free app. It does not require an
account, does not include ads, and does not put Game Day reliability behind a
paywall.

## What Roll Call Does

Roll Call helps a team prepare and run walk-up style introductions:

- create and manage multiple teams,
- add players, numbers, photos, and optional announcement recordings,
- choose Apple Music songs or import local audio/video,
- trim each player cue to a short walk-up moment,
- use built-in fallback crowd audio when a player is not fully configured,
- set today's lineup and player availability,
- run Game Day in announcer-only, song-only, or announcer-plus-song mode,
- use General Clips for quick crowd sounds,
- export, import, back up, and restore `.rollcall` team packages.

The app is intentionally not a sports management platform. It does not track
stats, host social profiles, require cloud sync, or depend on a backend service
for Game Day.

## First Run

New installs start with a full-screen welcome screen and a short setup guide.
The setup guide helps users create or import a team, pick team colors, add a
first player, choose music or use a cheer fallback, review lineup basics, and
open Game Day.

The setup guide can also be reopened from Settings.

## Game Day Model

Game Day is the center of the product. The app should feel ready when a coach
opens it on the field:

- player tiles are built around today's lineup,
- tapping a player plays the configured cue,
- incomplete players fall back to a built-in cheer,
- the current session can run as `Announcer Only`, `Announcer+Song`, or
  `Song Only`,
- live screens can stay dark for bright-field readability,
- readiness checks keep player setup separate from device/game-day conditions.

## Apple Music And Audio

Apple Music is the primary song-selection path. On devices with an active Apple
Music playback subscription and the correct MusicKit configuration, Roll Call
can work from full-song Apple Music timelines. Without that capability, the app
falls back to available preview clips where possible.

Local audio and video import remain available as a secondary path for
device-owned media.

Volume Automation is available in Settings for cue fades and subscribed Apple
Music full-song behavior, but it is off by default in new settings.

## Current Limitations

- Full-song Apple Music behavior depends on Apple Music account state, MusicKit
  App Service configuration, and provisioning that cannot be fully proven in a
  simulator.
- Subscribed Apple Music fade behavior still needs a final on-device feel pass.
- Waveforms and per-cue gain are intentionally deferred.
- Roll Call provides lightweight focus guidance, not OS-level Do Not Disturb or
  Guided Access control.
- The app is iPhone-first.

For the detailed current snapshot, see
[docs/WHERE_WE_STAND.md](docs/WHERE_WE_STAND.md).

## Building

Open [RollCall.xcodeproj](RollCall.xcodeproj) in Xcode and build the
`RollCall` scheme.

Useful context:

- Bundle identifier: `com.jkfisher.rollcall`
- Marketing version: `1.0.0`
- Current project build: `49`
- Physical-device installs require local Apple development provisioning.
- Full Apple Music behavior requires the MusicKit App Service for the App ID.
- Build environment details live in
  [docs/development/BUILD_ENVIRONMENTS.md](docs/development/BUILD_ENVIRONMENTS.md).

## Product Direction

Roll Call's working priorities are:

1. Easy
2. Personal
3. Cool
4. Professional

Future work should continue to protect the core promise: if the coach taps
Start Game right now, the experience should feel good in front of players,
parents, and teammates.

Product boundaries and release thinking live in:

- [docs/product/NORTH_STAR.md](docs/product/NORTH_STAR.md)
- [docs/product/PRODUCT_SCOPE.md](docs/product/PRODUCT_SCOPE.md)
- [docs/product/UX_RULEBOOK.md](docs/product/UX_RULEBOOK.md)
- [docs/product/PRODUCT_ROADMAP.md](docs/product/PRODUCT_ROADMAP.md)

## Reuse And Licensing

Roll Call is source-available for noncommercial use under the
[PolyForm Noncommercial License 1.0.0](LICENSE), with project-specific terms in
[ROLL-CALL-LICENSE-NOTICE.md](ROLL-CALL-LICENSE-NOTICE.md).

It is free for personal, educational, nonprofit, public agency, volunteer,
youth, and community sports use. Commercial use, including internal use by
for-profit businesses, requires separate written permission.

Public noncommercial forks and modified builds are welcome when they:

- use a distinct app or product name,
- preserve source and documentation attribution,
- visibly credit "Derived from Roll Call by John Kenneth Fisher" in the app,
- publish corresponding modified source when distributing modified builds,
- replace Roll Call branding, icons, John-specific images, personal likeness,
  and sample personal/team media unless separately permitted.

Small standalone code snippets may be reused commercially. Attribution is
appreciated but not required for those snippets.

Third-party materials remain under their own licenses. See
[ATTRIBUTIONS.md](ATTRIBUTIONS.md) for ZIPFoundation and bundled Mixkit sound
effect details.

## Repository Guide

- [docs/WHERE_WE_STAND.md](docs/WHERE_WE_STAND.md): current version, verified
  behavior, limitations, and next priorities
- [docs/product/NORTH_STAR.md](docs/product/NORTH_STAR.md): product philosophy
- [docs/product/UX_RULEBOOK.md](docs/product/UX_RULEBOOK.md): interaction and
  UX rules
- [docs/product/PRODUCT_SCOPE.md](docs/product/PRODUCT_SCOPE.md): release and
  product boundaries
- [docs/product/PRODUCT_ROADMAP.md](docs/product/PRODUCT_ROADMAP.md): 1.x and
  later-release direction
- [docs/product/Public Changelog.md](docs/product/Public%20Changelog.md):
  public-facing release notes
- [ROLL-CALL-LICENSE-NOTICE.md](ROLL-CALL-LICENSE-NOTICE.md): noncommercial
  reuse, fork, attribution, and asset-boundary terms
- [docs/historical/](docs/historical/): older planning and design rationale

## Credits

Roll Call is by John Kenneth Fisher.

Bundled third-party software and audio attributions are tracked in
[ATTRIBUTIONS.md](ATTRIBUTIONS.md).
