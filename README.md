# Roll Call

Roll Call is an iPhone app for making youth sports introductions feel more
personal on game day.

The app is built around a simple idea: setup should help a coach or parent make
decisions ahead of time, and Game Day should be fast, forgiving, and hard to
mess up while people are watching.

## Project Status

Active prototype.

Roll Call is built primarily for my own Apple-centric youth sports workflow,
but it may be useful to other families, coaches, schools, and community teams
with similar needs. The current source builds an iPhone app target, and the app
is in a real-use pause around version `0.7.0` build `25`.

There are rough edges. Apple Music behavior in particular depends on device
account state, App ID configuration, and provisioning that cannot be fully
verified in a simulator.

## What It Does

Roll Call helps a team prepare and run walk-up style player introductions.

Core flows include:

- Create and manage multiple teams
- Add players, numbers, photos, and custom intro recordings
- Pick Apple Music songs or import local audio
- Trim cue starts and lengths for player entrances
- Build and adjust today's lineup
- Run Game Day with announcer-only, song-only, or announcer-plus-song playback
- Fall back to built-in crowd audio when a player is incomplete
- Export, import, back up, and restore `.rollcall` team packages

The app is intentionally not a sports management platform. It does not try to
track stats, run a social network, require accounts, or make Game Day depend on
cloud services.

## Product Shape

Game Day is the product. Everything else supports Game Day.

The working priorities are:

1. Easy
2. Personal
3. Cool
4. Professional

The app should be complete and useful without ads, accounts, or reliability
paywalls. Premium ideas, if they happen later, should add delight or save time;
they should not make the free app feel broken.

See [docs/product/NORTH_STAR.md](docs/product/NORTH_STAR.md) and
[docs/product/PRODUCT_SCOPE.md](docs/product/PRODUCT_SCOPE.md) for the current
product boundaries.

## Current Limitations

- Full-song Apple Music playback requires the right MusicKit and device account
  setup.
- Some Apple Music fade and trim behavior still needs on-device field testing.
- Local audio import exists, but Apple Music is the primary path.
- Waveforms, per-cue gain, better onboarding, and recovery flows are deferred.
- The app currently targets iPhone; this is not a cross-platform project.

For the full current snapshot, see
[docs/WHERE_WE_STAND.md](docs/WHERE_WE_STAND.md).

## Building

Open [RollCall.xcodeproj](RollCall.xcodeproj) in Xcode and build the `RollCall`
scheme.

Useful context:

- The app target is iOS-focused.
- Physical-device installs require a valid local Apple development provisioning
  profile for `com.jkfisher.rollcall`.
- Full Apple Music behavior requires the MusicKit App Service to be enabled for
  the App ID.
- Build environment details live in
  [docs/development/BUILD_ENVIRONMENTS.md](docs/development/BUILD_ENVIRONMENTS.md).

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

Schools, nonprofits, public agencies, volunteer teams, and youth/community
sports organizations should feel comfortable reaching out if licensing,
premium content, or access terms get in the way of a good community use. Free
permission may be available.

## Repository Guide

- [docs/WHERE_WE_STAND.md](docs/WHERE_WE_STAND.md): current version, verified
  behavior, limitations, and next priorities
- [docs/product/NORTH_STAR.md](docs/product/NORTH_STAR.md): product philosophy
  in one page
- [docs/product/UX_RULEBOOK.md](docs/product/UX_RULEBOOK.md): interaction and
  UX rules
- [docs/product/PRODUCT_ROADMAP.md](docs/product/PRODUCT_ROADMAP.md): 1.0 and
  later-release direction
- [docs/product/ARCHITECTURE_GUARDRAILS.md](docs/product/ARCHITECTURE_GUARDRAILS.md):
  boundaries for future implementation work
- [ROLL-CALL-LICENSE-NOTICE.md](ROLL-CALL-LICENSE-NOTICE.md): noncommercial
  reuse, fork, attribution, and asset-boundary terms
- [docs/historical/](docs/historical/): older planning and design rationale

## Credits

Roll Call is by John Kenneth Fisher.

Bundled third-party software and audio attributions are tracked in
[ATTRIBUTIONS.md](ATTRIBUTIONS.md).
