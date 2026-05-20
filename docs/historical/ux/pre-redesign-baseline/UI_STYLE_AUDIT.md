# UI Style Audit

## Overall Character

The current UI is mostly native iOS utility UI with one deliberately more theatrical surface: `Game Day`.

Broadly:
- most screens use `NavigationStack` + `List` or `Form`
- typography is almost entirely system-default
- orange is the dominant accent
- status chips and system symbols carry a lot of meaning
- `Game Day` uses a stronger branded treatment than the rest of the app

## Navigation Style

- Six-tab `TabView`
- Each tab wrapped in its own `NavigationStack`
- Secondary workflows use sheets more than deep navigation pushes
- Alerts and system importers are used heavily

Current effect:
- low structural complexity
- but a lot of modal branching from root and player-edit flows

## Color Usage

Primary recurring color:
- orange tint (`.tint(.orange)`)

Common status colors:
- green for success/ready/active
- orange for cue emphasis and warnings
- red for destructive/missing/error
- gray/secondary for absence or neutral states

Distinct surface:
- `Game Day` uses orange-tinted gradient backgrounds and green active-playback emphasis

Observations:
- the color system is functional rather than formalized
- repeated colors are mostly hard-coded in place
- there is no visible design-token layer

## Typography

- almost entirely system typography
- frequent use of:
  - `.headline`
  - `.subheadline`
  - `.caption`
  - `.title`
  - `.title3`
- semibold/bold weight used to separate primary action/status information

Observations:
- readable and native
- minimal brand-specific typographic identity
- many dense status rows rely on size/weight contrast rather than layout separation

## Spacing Patterns

Repeated patterns:
- grouped sections in lists/forms
- chip-like paddings around status labels
- medium card padding in `Game Day`
- small vertical spacing in roster and picker rows

Observations:
- spacing is serviceable and consistent enough within each screen
- cross-screen spacing language is less consistent because `Game Day` is stylistically different

## Repeated Components

Repeated UI patterns already present:
- status chips/capsules
- `PlayerPhotoThumbnail`
- bordered/borderedProminent action buttons
- list rows with left identity and right status/action
- `ContentUnavailableView` empty states
- simple card treatment in `Game Day`

## Inconsistencies

1. `Game Day` versus the rest of the app
   - `Game Day` feels like a product surface
   - most other tabs feel like administration screens

2. Launch screen versus runtime screens
   - launch screen is more branded and stylized than most in-app UI

3. Status expression varies
   - some statuses use chips
   - some use inline explanatory text
   - some use alerts
   - some use readiness rows

4. Control affordance density
   - Player editor is much denser than other screens
   - General Clips is sparse by comparison

## Accessibility Concerns

Likely concerns from code inspection:
- status meaning depends partly on color
- some preview buttons are small icon-only controls
- `FlowChipRow` may be tight for large Dynamic Type sizes
- `StartScrubControl` is custom and may need further accessibility validation beyond its current value label
- game-day card density may become challenging at larger text sizes
- photo cropper gestures are instruction-light and rely on touch precision

## Areas That Feel Placeholder or MVP

- Readiness presentation is functional but plain
- General Clips rows are serviceable but minimal
- Settings combines unrelated concerns without much hierarchy
- Recovery screen is intentionally basic
- Developer Tools is clearly operational rather than polished

## Areas That Already Work Well

- Game Day has a distinct purpose-built feel
- Player roster rows communicate setup status quickly
- Apple Music picker split between row-select and separate preview is explicit
- Trim flow favors obvious presets and opt-in precision
- destructive actions are reasonably literal in wording

## AI-Generated / Duplicated / Inconsistent Signals

Signals worth noting for future cleanup, not immediate change:
- `RootView.swift` contains a very high amount of UI and helper logic in one file
- some product language reflects older announcer concepts while product decisions have shifted
- built-in voice removal is reflected in user-facing error strings, but some legacy announcer data/model support remains underneath
- the app visually mixes polished branded moments with straightforward prototype-admin surfaces
