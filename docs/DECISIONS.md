# Decisions

Use this file as a concise decision log for project-specific architectural, behavioral, tooling, and scope decisions.

## 2026-05-12

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
