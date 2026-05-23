# Decisions

Use this file as a concise decision log for project-specific architectural, behavioral, tooling, and scope decisions.

## 2026-05-23

- Approved: Volume Automation now defaults off for new or missing settings, while staying available in Settings and Advanced Trim guidance.
  Rationale: the advanced trim screen already teaches users where the feature matters, and the default should avoid surprising automatic volume changes.
  Status: approved

- Approved: first-run onboarding starts with a full-screen softball welcome image that visually matches the launch screen, then continues into the existing Setup Guide without changing the setup pages.
  Rationale: launch-to-first-run should feel more polished and emotionally tied to youth sports while preserving the current onboarding flow and completion state.
  Status: approved

- Approved: first-run Setup Guide should offer a visible Close button, and the lineup-step Got It action should work even with fewer than the recommended three players.
  Rationale: the three-player recommendation should remain helpful guidance, not a trap or a disabled-looking escape hatch during onboarding.
  Status: approved

- Approved: Roll Call 1.0.0 defaults new and missing-mode teams to `Announcer+Song`, keeps live-screen dark mode, Game Day haptics, and Volume Automation default-on, and keeps the Setup Guide moving from added player #2/#3 into that player's audio step instead of returning to Lineup.
  Rationale: the 1.0 submission should make the expected live experience the default while keeping onboarding focused on getting each real player to a usable walkup quickly.
  Status: approved

## 2026-05-22

- Approved: first-run onboarding starts from a true empty app state, not a seeded sample team, and guides users toward one real team, one player, audio or an explicit cheer fallback, lineup orientation, and Game Day.
  Rationale: Roll Call should make the first real walkup happen quickly without fake roster data, tutorial carousels, accounts, permission barrages, or homework-style setup pressure.
  Status: approved

- Approved: Settings includes a normal user-facing setup guide relaunch path with create-new-team, import `.rollcall`, and review-current-team options.
  Rationale: users may leave setup accidentally, want to create another team with guidance, or need repeatable onboarding for testing without hiding the path in Developer Tools.
  Status: approved

## 2026-05-20

- Approved: license Roll Call as noncommercial source-available software using PolyForm Noncommercial 1.0.0 as the base license, with separate Roll Call-specific attribution, source-sharing, commercial-use, small-snippet, and asset-boundary terms.
  Rationale: the project should remain very free for personal, educational, nonprofit, school, public agency, volunteer, youth, and community sports use while keeping commercial use permission-only and protecting Roll Call branding, personal materials, and third-party assets.
  Status: approved

## 2026-05-21

- Approved: live-screen appearance follows the explicit matrix in `docs/product/APPEARANCE_RULES.md`: setup screens always follow the device, `Game Day` and `Clips` force dark only when the device is dark or `Always Use Dark Live Screens` is enabled, and the Game Day lineup sheet follows the effective live appearance.
  Rationale: the setting is meant to protect live-use readability without turning the whole app dark or leaving live content stuck in a dark-only custom palette when the user intentionally allows Light Mode.
  Status: approved

- Approved: add a default-on setting that keeps `Game Day` and `Clips` in dark mode while allowing the rest of the app to follow the user's normal Light/Dark appearance.
  Rationale: the custom light-mode Game Day gradient can become hard to read in sunlight, while the live-use screens are the places where field visibility matters most. `Game Day` and `Clips` should share the same live-side background treatment so the live surfaces read as intentionally related.
  Status: approved

- Approved: Readiness should mean confidence for live Game Day use, with player-specific playable audio as the main Ready state, Announcement Cues as Enhanced, missing player audio as a helpful non-blocking need, and photos/presentation polish as optional upgrades that never reduce readiness.
  Rationale: this aligns the app with `docs/product/READINESS_MODEL.md` by encouraging setup without turning it into a warning-heavy completion checklist; built-in fallback remains live-safe but does not count as a player being Ready.
  Status: approved

## 2026-05-15

- Approved: AirDropped or shared `.rollcall` files should open directly into Roll Call's existing import flow, while preserving the current backup-first import semantics.
  Rationale: the app already treats `.rollcall` as the portable team handoff format, so direct file opening reduces friction without introducing live sync or changing package contents.
  Status: approved

## 2026-05-18

- Approved: Roll Call uses one bundle identifier, `com.jkfisher.rollcall`, across Debug, Internal, and Release build environments while centralizing production-safety gates in `BuildEnvironment` and `FeatureFlags`.
  Rationale: one app identity keeps App Store Connect, MusicKit, signing, and `.rollcall` document ownership aligned; Internal TestFlight replaces the installed app rather than creating a side-by-side build.
  Status: approved

- Approved: Developer Tools may include an experimental Apple Music team playlist sync button that creates or fully replaces the exact-name playlist `Roll Call - <Team Name>` for the selected team.
  Rationale: the feature should stay out of normal app flows while giving coaches a quick Apple Music playlist mirror of the selected team's catalog-backed song cues; local, built-in, missing, preview-only, and duplicate cues are skipped.
  Status: approved

## 2026-05-16

- Approved: Game Day announcer mode should become a three-way control with `Announcer Only`, `Announcer+Song`, and `Song Only`, plus a centered `Prev / Edit Lineup / Next` row above the player grid.
  Rationale: the live board needs clearer top-down structure and explicit playback intent, while the lower controls should prioritize lineup navigation without making accidental player taps too easy.
  Status: approved

## 2026-05-13

- Approved: remove Built-in Voice from the product for now and center custom recorded intros only, with Game Day using either cue-only playback or custom-intro-plus-cue playback.
  Rationale: Apple speech generation/export has proven too unreliable on-device for this app's core job, so a simpler custom-intro-only model is safer and clearer.
  Status: approved

- Approved: resolve the MusicKit token failure by enabling the MusicKit App Service for App ID `com.jkfisher.rollcall`, not by adding a local entitlement.
  Rationale: Apple's token service rejected the bundle ID as an unregistered client, and Xcode rejected `com.apple.developer.music.user-token` as an invalid entitlement for this target.
  Status: approved

- Approved: subscribed Apple Music mode must use catalog-backed MusicKit selections only, with preview fallback reserved for preview-only devices.
  Rationale: silently using iTunes preview results on a subscribed device makes the trim UI lie about full-song selection; a clear failure is safer than assigning the wrong 20-second window.
  Status: approved

- Approved: keep Apple Music clips capped at 20 seconds, but let subscribed devices trim from the full-song timeline instead of the preview-only window.
  Rationale: the app's core job is still a fast, controlled walk-up clip, but the chosen clip must come from the real song when the user has the playback rights for it.
  Status: approved

- Approved: remove protected/panic Game Day behavior and replace it with lighter Focus guidance plus a plain stop-playback affordance.
  Rationale: the old controls added friction and clutter without delivering true OS-level lock-down behavior, so the simpler game board is a better fit for the current product.
  Status: approved

- Approved: make lineup order persist across days and launches, auto-alphabetize only before the first manual customization, and move manual recovery language from "safety snapshots" to clearer backup terminology.
  Rationale: coaches need the lineup to stay where they left it, while backup/recovery should remain available without feeling like a daily workflow.
  Status: approved

- Approved: replace the placeholder General Clips tones with a bundled licensed crowd clip set tracked in `ATTRIBUTIONS.md`.
  Rationale: the feature now needs to feel polished out of the box, and the licensing trail must live in the repo alongside the shipped assets.
  Status: approved

## 2026-05-14

- Approved: subscribed full-song Apple Music playback may use an internal MediaPlayer application-player backend to preserve the Apple Music-first selection flow while pursuing reliable fade-capable playback.
  Rationale: MusicKit `ApplicationMusicPlayer` keeps the picker and trim model honest, but it still hard-stops subscribed catalog playback; swapping the playback backend internally is safer than unsupported local capture/export experiments.
  Status: approved

- Approved: hide local audio import from the main cue-source section, but keep it available behind a secondary fallback affordance.
  Rationale: Apple Music should stay primary in the product flow, while dependable device-owned media remains available without competing visually as the default setup path.
  Status: approved

- Approved: when a Game Day player is tapped without a selected song cue, play the built-in `Small Cheer` clip as the default fallback.
  Rationale: this keeps tap behavior useful even when player setup is incomplete, while preserving a single implementation point for a future user-selectable default fallback cue.
  Status: approved

- Approved: switch `.rollcall` export/import to a true zipped single-file archive format, while keeping import compatibility with existing directory-style packages.
  Rationale: sharing should produce one expected file instead of a package folder, but prior exports must remain usable.
  Status: approved

- Approved: selected teams can be removed from the Teams panel through an explicit destructive confirmation action.
  Rationale: team management needs a complete lifecycle, but deletion should stay visible, scoped to the current team, and hard to trigger accidentally.
  Status: approved

## 2026-05-12

- Approved: Apple Music cue editing should adapt to subscription capability, using full-song trimming for active playback subscriptions and preview-only trimming otherwise.
  Rationale: the core job is choosing the right 20-second walk-up moment, but the app must still behave honestly and usefully on devices that can search Apple Music without being allowed to play the full catalog.
  Status: approved

- Approved: move announcer behavior to a team-scoped Built-in Voice profile plus optional per-player custom recordings, with Game Day choosing custom intro first, built-in fallback second, and no-intro mode as a team session control.
  Rationale: announcer wording, voice choice, package portability, and custom-recording override behavior need a stable product model instead of per-cue ad hoc intro state.
  Status: superseded

- Approved: move Apple Music song choice into a dedicated recents-plus-search picker and make cue shaping a separate trim-focused step with preset-first controls and opt-in precision.
  Rationale: the old inline search plus raw timing sliders made a common setup path feel awkward; the new flow keeps song choice, clip feel, and fine adjustments separated without rewriting the cue model.
  Status: approved

- Approved: recover the prototype with a reliability-first implementation order before chasing broader polish.
  Rationale: debounce, protected Game Day flow, lineup coherence, readiness depth, and restore/import safety are more important to the app's core job than deferred waveform/gain polish.
  Status: approved

- Approved: ship the General Clips feature using the current generated placeholder sounds for now, with real licensed applause/cheer assets and attributions tracked as follow-up work.
  Rationale: the app needs the feature surface and cue-path behavior now, but asset sourcing should not block the product workflow implementation.
  Status: approved

## 2026-05-11

- Approved: ship an experimental Apple Music local-copy lane behind an advanced off-by-default setting.
  Rationale: keep the supported app behavior App-Store-safe by default while still allowing a removable, isolated power-user conversion path.
  Status: approved

- Approved: treat successful experimental Apple Music copies as ordinary local audio in the product model.
  Rationale: playback, editing, export, duplication, and restore should not special-case prior Apple Music origin once a local file exists.
  Status: approved

- Recorded: the working app bootstrap has been moved back onto the intended `RollCall/` and `RollCall.xcodeproj/` names.
  Rationale: the rebuilt tree is now the validated source of truth, and the older broken bootstrap artifacts were removed to keep the repo clean.
  Status: approved

- Approved: `.rollcall` exports are directory-backed packages containing a manifest plus copied app-managed assets.
  Rationale: sharing/import must remain portable for offline local audio, announcer renders, and roster photos instead of depending on paths from the exporting device.
  Status: approved
