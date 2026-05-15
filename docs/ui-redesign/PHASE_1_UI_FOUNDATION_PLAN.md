# PHASE 1 UI FOUNDATION PLAN

Status:
- Planning document only
- No app code implementation is authorized by this document
- No screen redesign is included in this phase

Purpose:
- translate `docs/ui-redesign/VISUAL_LANGUAGE_SYSTEM.md` into a safe, concrete Phase 1 implementation plan
- establish a reusable design-system foundation before any screen-level redesign work begins
- keep all work view-layer-only

Primary source documents:
- `docs/current-state/`
- `docs/ui-redesign/TARGET_UI_DIRECTION.md`
- `docs/ui-redesign/VISUAL_LANGUAGE_SYSTEM.md`

Constraint inputs reviewed for this plan:
- `docs/current-state/SAFE_REDESIGN_STRATEGY.md`
- `docs/current-state/FUNCTIONALITY_PROTECTION_ZONES.md`
- `docs/current-state/COMPONENT_CATALOG.md`
- `docs/agent-rules/apple.md`

## Scope

This phase includes only:
- semantic color roles
- typography hierarchy
- spacing tiers
- button families
- card families
- status-chip language
- `TeamBanner` component

This phase does not include:
- screen redesigns
- `Game Day` redesign
- `PlayerEditorSheet` redesign
- playback behavior changes
- navigation behavior changes
- persistence changes
- Apple Music logic changes
- queue/lineup behavior changes
- import/export changes

## Implementation Philosophy

Phase 1 should land as one controlled, low-risk PR/commit that:
- adds a small design-system layer
- adds preview coverage for that layer
- avoids touching runtime behavior
- avoids broad edits inside `RollCall/RootView.swift`
- leaves all existing screens visually unchanged for now

The safest version of Phase 1 is:
- add new Swift files
- wire them into the Xcode project
- build previews and compile-check them
- do not adopt them in runtime screens yet, except where a future explicit prompt asks for it

## 1. Files to Create

Recommended new folder:
- `RollCall/DesignSystem/`

Reasoning:
- the repo is currently small and flat
- one new folder is enough structure without forcing a large architecture change
- this keeps the Phase 1 foundation easy to find and easy to revert if needed

Recommended files:

1. `RollCall/DesignSystem/RollCallDesignSystem.swift`
- umbrella/shared type definitions used across the design system
- holds cross-file enums that should not be duplicated
- should stay small and declarative

2. `RollCall/DesignSystem/RollCallColors.swift`
- semantic color-role definitions
- standard-surface versus live-surface color resolution helpers
- no final brand-hex overreach

3. `RollCall/DesignSystem/RollCallTypography.swift`
- text-role definitions
- font/style mapping using standard SwiftUI text styles and weights
- no custom font system

4. `RollCall/DesignSystem/RollCallSpacing.swift`
- spacing tier definitions
- shared insets/padding constants
- keeps future redesign work out of magic numbers

5. `RollCall/DesignSystem/RollCallButtonStyles.swift`
- button-family definitions
- shared `ButtonStyle` implementations and small convenience wrappers/modifiers

6. `RollCall/DesignSystem/RollCallCardStyles.swift`
- card-family definitions
- shared background/corner/material/inset styling
- utility `SectionCard` or equivalent shared card container

7. `RollCall/DesignSystem/StatusChip.swift`
- reusable chip component
- supports the approved plainspoken status language and semantic roles

8. `RollCall/DesignSystem/TeamBanner.swift`
- reusable read-only team context banner
- supports standard and live-side variants
- supports no-team state without new behavior

Optional file only if previews become noisy:
- `RollCall/DesignSystem/RollCallDesignSystemPreviewData.swift`

Recommendation:
- avoid this optional ninth file unless preview samples become large enough to distract from the implementation
- for Phase 1, colocated previews inside each file are probably cleaner

## 2. Files to Touch

### Mandatory existing file touch

1. `RollCall.xcodeproj/project.pbxproj`
- add the new Swift files to the target
- keep this change mechanical and limited

### Preferred runtime-touch count

Preferred:
- no runtime Swift files touched at all

Why:
- this phase is foundation-only
- touching `RootView.swift` too early raises the risk of accidental layout or behavior changes

### Existing files that should ideally remain untouched in Phase 1

- `RollCall/RootView.swift`
- `RollCall/AppModel.swift`
- `RollCall/Models.swift`
- `RollCall/Services.swift`
- `RollCall/RollCallApp.swift`

### If an implementation absolutely needs one minimal runtime touch

Only acceptable candidate:
- `RollCall/RootView.swift`

But only for:
- a trivial compile-safe helper reference
- or a preview-only host wrapper if there is no cleaner alternative

Preferred rule:
- do not do this in Phase 1 unless compilation truly forces it

## 3. Exact Component API Proposals

The APIs below are intentionally concrete enough for implementation, but still conservative and view-layer-only.

### 3.1 Shared umbrella types

File:
- `RollCall/DesignSystem/RollCallDesignSystem.swift`

Proposed types:

```swift
enum RollCallSurfaceVariant {
    case standard
    case live
}
```

```swift
enum RollCallSecondaryStatusTone {
    case neutral
    case warning
}
```

Rationale:
- `standard` versus `live` will be reused by colors, cards, buttons, chips, and the banner
- this avoids each file inventing its own surface-mode concept

### 3.2 Semantic colors

File:
- `RollCall/DesignSystem/RollCallColors.swift`

Proposed API:

```swift
enum RollCallColorRole: CaseIterable {
    case accent
    case live
    case ready
    case warning
    case destructive
    case disabled
    case neutralSurface
    case neutralStructure
}
```

```swift
extension Color {
    static func rollCall(
        _ role: RollCallColorRole,
        surface: RollCallSurfaceVariant = .standard
    ) -> Color
}
```

Optional helper if implementation wants more explicit naming:

```swift
enum RollCallColors {
    static func color(
        _ role: RollCallColorRole,
        surface: RollCallSurfaceVariant = .standard
    ) -> Color
}
```

Recommendation:
- pick either `Color.rollCall(...)` or `RollCallColors.color(...)`
- do not ship both in Phase 1
- my preference is `Color.rollCall(...)` because it keeps call sites short

### 3.3 Typography

File:
- `RollCall/DesignSystem/RollCallTypography.swift`

Proposed API:

```swift
enum RollCallTextRole {
    case screenTitle
    case sectionTitle
    case cardTitle
    case primaryIdentity
    case body
    case helperText
    case chipLabel
}
```

```swift
struct RollCallTextStyle: ViewModifier {
    let role: RollCallTextRole
    let surface: RollCallSurfaceVariant
}
```

```swift
extension View {
    func rollCallText(
        _ role: RollCallTextRole,
        surface: RollCallSurfaceVariant = .standard
    ) -> some View
}
```

Rationale:
- modifier-based application is safer than inventing wrapper views for all text
- it keeps future runtime adoption small and local

### 3.4 Spacing

File:
- `RollCall/DesignSystem/RollCallSpacing.swift`

Proposed API:

```swift
enum RollCallSpacingTier: CGFloat {
    case tight = 8
    case standard = 12
    case large = 20
}
```

```swift
enum RollCallInsets {
    static let card = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    static let section = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
}
```

Notes:
- the exact numeric values above are safe starting defaults, not a forever spec
- keep them centralized so later tuning is easy

### 3.5 Buttons

File:
- `RollCall/DesignSystem/RollCallButtonStyles.swift`

Proposed API:

```swift
enum RollCallButtonFamily {
    case primary
    case secondary
    case quiet
    case destructive
    case liveControl
}
```

```swift
struct RollCallButtonStyle: ButtonStyle {
    let family: RollCallButtonFamily
    let surface: RollCallSurfaceVariant
}
```

```swift
extension Button {
    func rollCallButtonStyle(
        _ family: RollCallButtonFamily,
        surface: RollCallSurfaceVariant = .standard
    ) -> some View
}
```

Optional wrapper APIs for future convenience, but not required in Phase 1:

```swift
struct PrimaryActionButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let isEnabled: Bool
    let action: () -> Void
}
```

```swift
struct QuietActionButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let isEnabled: Bool
    let action: () -> Void
}
```

Recommendation:
- implement the `ButtonStyle` first
- do not require wrapper buttons in Phase 1 unless previews become materially clearer with them

### 3.6 Cards

File:
- `RollCall/DesignSystem/RollCallCardStyles.swift`

Proposed API:

```swift
enum RollCallCardFamily {
    case utility
    case status
    case identity
    case live
}
```

```swift
struct RollCallCardModifier: ViewModifier {
    let family: RollCallCardFamily
    let surface: RollCallSurfaceVariant
}
```

```swift
extension View {
    func rollCallCard(
        _ family: RollCallCardFamily = .utility,
        surface: RollCallSurfaceVariant = .standard
    ) -> some View
}
```

```swift
struct SectionCard<Content: View>: View {
    let family: RollCallCardFamily
    let surface: RollCallSurfaceVariant
    let content: Content

    init(
        family: RollCallCardFamily = .utility,
        surface: RollCallSurfaceVariant = .standard,
        @ViewBuilder content: () -> Content
    )
}
```

Rationale:
- card modifier plus `SectionCard` gives both low-level and convenience usage
- future screen adoption can pick the lighter tool

### 3.7 Status chip

File:
- `RollCall/DesignSystem/StatusChip.swift`

Proposed API:

```swift
enum StatusChipRole {
    case live
    case ready
    case warning
    case destructive
    case disabled
    case neutral
}
```

```swift
enum StatusChipEmphasis {
    case subdued
    case standard
    case strong
}
```

```swift
struct StatusChip: View {
    let text: String
    let role: StatusChipRole
    let systemImage: String?
    let emphasis: StatusChipEmphasis

    init(
        text: String,
        role: StatusChipRole,
        systemImage: String? = nil,
        emphasis: StatusChipEmphasis = .standard
    )
}
```

Rules the implementation should honor:
- text-first meaning
- no reliance on color alone
- strong role differentiation
- plainspoken labels only

### 3.8 Team banner

File:
- `RollCall/DesignSystem/TeamBanner.swift`

Proposed API:

```swift
enum TeamBannerVariant {
    case standard
    case liveSide
}
```

```swift
struct TeamBannerSecondaryStatus: Equatable {
    let text: String
    let tone: RollCallSecondaryStatusTone

    init(
        text: String,
        tone: RollCallSecondaryStatusTone = .neutral
    )
}
```

```swift
struct TeamBanner: View {
    let teamName: String?
    let secondaryStatus: TeamBannerSecondaryStatus?
    let accentColor: Color?
    let variant: TeamBannerVariant

    init(
        teamName: String?,
        secondaryStatus: TeamBannerSecondaryStatus? = nil,
        accentColor: Color? = nil,
        variant: TeamBannerVariant = .standard
    )
}
```

Behavior rules for the component:
- read-only
- fixed-height visual structure
- supports nil team gracefully
- no embedded navigation or selection logic
- no model mutation

## 4. Token Definitions

Phase 1 should define semantic tokens, not final art direction.

### Color roles

Required roles:
- `accent`
- `live`
- `ready`
- `warning`
- `destructive`
- `disabled`
- `neutralSurface`
- `neutralStructure`

Token rules:
- no hardcoded per-screen oranges/greens/reds in the new components
- `warning` must remain distinct from the warm app accent
- `disabled` must reduce energy, not readability
- live-side screens may resolve the same role differently than bright support screens via `RollCallSurfaceVariant`

### Typography roles

Required roles:
- `screenTitle`
- `sectionTitle`
- `cardTitle`
- `primaryIdentity`
- `body`
- `helperText`
- `chipLabel`

Token rules:
- map to standard SwiftUI text styles and weights
- do not introduce a custom font or a point-size matrix
- use weights and text styles, not fake scoreboard typography

### Spacing tiers

Required tiers:
- `tight`
- `standard`
- `large`

Safe initial numeric proposal:
- `tight = 8`
- `standard = 12`
- `large = 20`

Why this is safe now:
- concrete enough to implement
- still easy to tune later without rewriting screen code

### Button families

Required families:
- `primary`
- `secondary`
- `quiet`
- `destructive`
- `liveControl`

Rules:
- `liveControl` exists in Phase 1, but should not be applied to runtime `Game Day` yet
- it exists so previews and later work do not invent a second button language

### Card families

Required families:
- `utility`
- `status`
- `identity`
- `live`

Rules:
- `live` family exists in Phase 1 for previews and later use
- it should not trigger screen redesign work by itself

## 5. Preview Strategy

Before any screen redesign begins, Phase 1 should ship with preview coverage for the design-system layer itself.

Required previews:

1. Color role preview
- show every `RollCallColorRole`
- show both `.standard` and `.live` surface variants
- verify the roles do not collapse into each other

2. Typography preview
- show every `RollCallTextRole`
- verify hierarchy and weight progression
- use short and long sample text

3. Spacing preview
- small stacked sample showing `tight`, `standard`, and `large`
- useful mainly as a sanity check

4. Button family preview
- show all `RollCallButtonFamily` values
- standard and live surfaces
- enabled and disabled states

5. Card family preview
- show all `RollCallCardFamily` values
- standard and live surfaces
- simple placeholder content only

6. Status chip preview
- `live`
- `ready`
- `warning`
- `destructive`
- `disabled`
- `neutral`
- short and longer labels

7. Team banner preview
- no team selected
- selected team with neutral secondary status
- selected team with warning secondary status
- long team name
- bright support-screen variant
- live-side variant
- accent color example using a derived yellow/black-friendly accent

Preview implementation rule:
- previews should use local sample values
- do not require `AppModel`
- do not require real persistence or service state
- do not reach into `RootView` for preview hosting

## 6. Safety Strategy

Phase 1 must stay strictly view-layer-only.

### Safety rules

1. No model changes
- do not edit `Team`, `Player`, `Cue`, `ReadinessStatus`, or persisted settings just to support the design system

2. No service changes
- do not edit `CuePlaybackEngine`, `MusicCatalogService`, `PackageService`, readiness logic, recording logic, or asset-path logic

3. No navigation changes
- do not touch tab order, default tab behavior, or sheet flow in this phase

4. No runtime adoption requirement
- Phase 1 is allowed to ship as foundation + previews only
- screen usage comes later

5. Data-in, no-side-effects components
- `StatusChip` and `TeamBanner` should receive plain values from call sites
- they must not perform async work, lookups, mutations, or file access

6. No new persisted theme data
- team accent remains an optional input
- do not add a team color field or migration in Phase 1

7. No preview coupling to app state
- preview data should be local and static

### Recommended implementation discipline

- create the new files first
- add previews
- compile
- only after that consider whether any minimal runtime reference is needed
- prefer zero runtime usage in Phase 1

## 7. Risk List

### Risk 1: accidental `RootView.swift` creep

Why it matters:
- most UI lives there
- touching it early can turn “foundation” into stealth redesign

Mitigation:
- no runtime screen adoption in Phase 1
- if `RootView.swift` changes at all, it should be an explicit exception

### Risk 2: accidental protected-zone coupling

Why it matters:
- `Game Day`, `PlayerEditorSheet`, Apple Music, readiness, and playback are all tightly behavior-coupled

Mitigation:
- component APIs accept plain display inputs only
- no service/model calls inside the new design-system views

### Risk 3: accidental theme-data expansion

Why it matters:
- team-color support could tempt new persisted properties

Mitigation:
- keep `accentColor` optional
- let the caller supply a color later
- Phase 1 does not invent a storage model for team colors

### Risk 4: wrapper components changing behavior

Why it matters:
- action wrappers can accidentally alter hit-testing, disabled states, or button roles

Mitigation:
- prefer modifiers and `ButtonStyle`s as the default tool
- use wrapper views only when they stay behavior-neutral

### Risk 5: preview-only code leaking into runtime assumptions

Why it matters:
- preview mocks can accidentally become hidden design dependencies

Mitigation:
- keep preview helpers small and local
- no preview-only logic in runtime paths

### Risk 6: project-file churn

Why it matters:
- this repo does not appear to use file-system-synced groups
- adding files will require project-file edits

Mitigation:
- keep `project.pbxproj` edits mechanical
- add only the planned design-system files in one batch

## 8. Acceptance Criteria

Phase 1 is complete when all of the following are true:

1. New design-system files exist under `RollCall/DesignSystem/`
2. The Xcode project includes those files correctly
3. Semantic roles exist for:
- colors
- typography
- spacing
- buttons
- cards

4. Reusable components exist for:
- `StatusChip`
- `TeamBanner`

5. Required previews exist for:
- color roles
- typography roles
- spacing tiers
- button families
- card families
- status chips
- team banner variants

6. No runtime screen redesign has happened
7. `RootView.swift`, `AppModel.swift`, `Models.swift`, and `Services.swift` remain unchanged unless a truly minimal exception is documented
8. No behavior has changed in:
- playback
- navigation
- persistence
- Apple Music
- queue/lineup
- import/export

9. The diff is still small enough to review as one controlled PR/commit
10. The design-system layer compiles cleanly

Recommended success smell:
- after Phase 1, a later prompt should be able to restyle `Players`, `Teams`, or `Readiness` mostly by applying the new tokens/components, not by inventing another styling system

## 9. Recommended First Implementation Prompt

Use this exact prompt next:

```text
Using these documents:
- /docs/current-state/
- /docs/ui-redesign/TARGET_UI_DIRECTION.md
- /docs/ui-redesign/VISUAL_LANGUAGE_SYSTEM.md
- /docs/ui-redesign/PHASE_1_UI_FOUNDATION_PLAN.md

Implement Phase 1 only.

Before writing code:
1. Re-read PHASE_1_UI_FOUNDATION_PLAN.md fully.
2. Treat the plan as authoritative unless implementation reveals a concrete technical issue.
3. If implementation pressure suggests broader architectural changes, STOP and explain rather than improvising.

Create the design-system foundation described in PHASE_1_UI_FOUNDATION_PLAN.md.

Do:
- create the new Swift files under RollCall/DesignSystem/
- wire them into the Xcode project
- implement semantic color roles
- implement typography roles
- implement spacing tiers
- implement button families
- implement card families
- implement StatusChip
- implement TeamBanner
- add SwiftUI previews for all Phase 1 tokens/components

Hard rules:
- do not redesign any runtime screen yet
- do not redesign Game Day
- do not redesign PlayerEditorSheet
- do not change playback behavior
- do not change navigation behavior
- do not change persistence
- do not change Apple Music logic
- do not change queue/lineup behavior
- do not change import/export behavior
- avoid touching RootView.swift unless absolutely required for compilation
- prefer zero runtime screen adoption in this phase

Implementation preferences:
- keep the new code view-layer-only
- use standard Apple/SwiftUI APIs
- prefer modifiers and styles over behavior-heavy wrappers
- keep project-file edits mechanical and limited

All previews must compile independently without requiring:
- AppModel
- Apple Music authorization
- persistence
- RootView
- live services
- package imports

Avoid speculative abstraction.

Do not:
- create generic design systems for hypothetical future apps
- over-generalize tokens
- introduce protocol-heavy architecture
- introduce dependency injection changes
- add environment containers
- add runtime theme engines

This design system exists ONLY for Roll Call.
Prefer practical, explicit SwiftUI code over theoretically elegant architecture.

Verification:
- run the narrowest compile/build check that proves the new files are wired correctly
- report exactly which existing files, if any, had to be touched outside the new DesignSystem folder
```

## 10. Final Note

If implementation pressure in Phase 1 starts pushing toward:
- screen-level redesign
- new stored theme data
- navigation/tab changes
- playback state changes
- or `RootView.swift` churn

that is a sign the work has escaped Phase 1 and should pause before continuing.
