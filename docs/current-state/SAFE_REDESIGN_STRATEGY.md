# Safe Redesign Strategy

This file is not a redesign spec. It is a risk-managed sequence for changing the UI later without breaking the current app.

## Guiding Rule

Redesign the shell and presentation surfaces before redesigning the behavior-dense flows.

## Best First Screens to Redesign

### 1. Settings

Why first:
- low behavior density
- actions already route through existing `AppModel` methods
- easy place to improve hierarchy without disturbing playback

Safe scope:
- section layout
- spacing
- typography
- iconography
- explanatory text

### 2. Teams

Why early:
- important but structurally simple
- mostly CRUD and selection behavior

Safe scope:
- row styling
- create-team affordance
- selected-team summary presentation

### 3. Readiness

Why early:
- presentation is currently plain
- underlying readiness logic is separate enough to preserve

Safe scope:
- cards instead of plain rows
- clearer warning grouping
- better visual status hierarchy

### 4. General Clips

Why early:
- relatively isolated
- playback uses existing cue engine

Safe scope:
- card/list restyle
- grouping and labeling improvements
- more obvious quick-play affordances

## Screens to Redesign Next, Carefully

### 5. Players Tab

Why medium risk:
- roster rows and quick-add are important but understandable
- player rows already carry a lot of state information

Safe approach:
- preserve tap-to-edit, swipe present toggle, and quick-add mechanics
- improve information grouping before changing interactions

### 6. Recovery & Backups and Developer Tools

Why medium risk:
- operational, but functionally simple
- can be made clearer without touching core playback logic

## Screens to Avoid Until Later

### 7. Player Editor

Why to defer:
- most behavior-dense screen in the app
- nested modals, async flows, local draft state, and trim math all meet here

### 8. Apple Music Picker and Trim Flow

Why to defer:
- capability honesty is critical
- current split between selection and trim was explicitly approved
- full-song versus preview-only behavior is a real product distinction

### 9. Game Day

Why to defer until there is a strong reason:
- this is the core live-use surface
- large tap targets and playback affordances matter more than polish
- layout changes could accidentally make live use worse even if the screen looks nicer

## Suggested Phased Rollout

### Phase 1: Low-risk shell polish

Targets:
- Settings
- Teams
- Readiness
- General Clips

Goal:
- establish a cleaner visual language without changing functional workflows

### Phase 2: Roster/list consistency

Targets:
- Players tab
- quick-add
- shared row/status-chip styling

Goal:
- improve discoverability and consistency while preserving current player-edit entry flow

### Phase 3: Editor-shell extraction

Targets:
- Player Editor outer layout only

Goal:
- componentize visual blocks without changing cue/record/import logic

### Phase 4: High-risk behavior surfaces

Targets:
- Apple Music picker/trim
- Game Day

Prerequisites:
- explicit human approval
- device smoke checklist
- willingness to regression-test playback and Apple Music behavior carefully

## Suggested Componentization Opportunities

These are future opportunities, not current implementation instructions.

- reusable status chip component
- reusable player identity row
- reusable section explainer text block
- reusable cue-source summary card
- reusable empty-state wrapper
- reusable app action button styles
- reusable settings action row

Important constraint:
- componentization should start from visual extraction, not by moving logic around blindly.

## Suggested Preview / Test Strategy for Future UI Work

### Manual smoke checklist should exist before major redesign

At minimum:
- create/select team
- add player
- edit player
- choose Apple Music song
- preview clip
- adjust start and length
- record announcement cue
- import local media
- mark player present/absent
- reorder lineup
- play in Game Day
- export/import package
- create/restore backup

### SwiftUI preview guidance

Future UI work should prefer:
- sample `AppState`
- fake/static players and teams
- preview-only wrappers around existing components

But:
- do not replace runtime `AppModel` behavior with preview-only assumptions without explicit separation.

## Where Visual Redesign Can Happen Safely in Isolation

- top-level section headers
- spacing systems
- row/card backgrounds
- typography hierarchy
- iconography consistency
- status chip visuals
- settings and about presentation
- readiness visual grouping

## What Should Require Explicit Human Approval Before Modification

- any Apple Music workflow changes
- any playback-control interaction changes in Game Day
- any change to trim defaults or trim semantics
- any storage-path or package-format changes
- any backup/restore semantics changes
- any permission prompt changes
- any removal of legacy compatibility code
- any attempt to replace the current playback backend behavior
