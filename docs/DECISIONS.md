# Decisions

Use this file as a concise decision log for project-specific architectural, behavioral, tooling, and scope decisions.

## 2026-05-13

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

## 2026-05-12

- Approved: Apple Music cue editing should adapt to subscription capability, using full-song trimming for active playback subscriptions and preview-only trimming otherwise.
  Rationale: the core job is choosing the right 20-second walk-up moment, but the app must still behave honestly and usefully on devices that can search Apple Music without being allowed to play the full catalog.
  Status: approved

- Approved: move announcer behavior to a team-scoped Built-in Voice profile plus optional per-player custom recordings, with Game Day choosing custom intro first, built-in fallback second, and no-intro mode as a team session control.
  Rationale: announcer wording, voice choice, package portability, and custom-recording override behavior need a stable product model instead of per-cue ad hoc intro state.
  Status: approved

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
