# Redesign UX Archive

Status: historical record of completed direction-setting work

The redesign work established a calmer setup/admin experience and a clearer live-use split:

- `Game Day` and `Clips` are live surfaces where playback should stay obvious and forgiving.
- `Players`, `Teams`, `Readiness`, and `Settings` are preparation or administration surfaces.
- A thin TeamBar provides team context without taking over the screen.
- Player Editor can be rich because it is a setup surface, while Game Day remains focused on play/stop and lineup context.
- The visual system favors native controls, readable status, calm cards, clear hierarchy, and accessibility-preserving density.
- Current implementation wins when it differs from an old design specification.

## Important protected choices

The redesign did not authorize broad model or playback changes. It preserved player/team data, cue timing, Apple Music behavior, import/export, recording, and save/close semantics unless separately approved. It also treated Game Day fallback and team ownership as protected product behavior.

## Stabilization lessons

The later audits found small consistency and accessibility opportunities—visible TeamBar status, Dynamic Type resilience, custom-control accessibility, and consistent status language—but explicitly kept them separate from a broad redesign. These observations are useful for future work only when they fit the current product docs and receive the appropriate approval.

The detailed screen specifications, decision reviews, visual-language documents, navigation audits, and stabilization queue are retired as active guidance. Their rationale and protected boundaries are summarized here; exact historical material remains in Git history.
