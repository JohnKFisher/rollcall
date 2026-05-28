# UI Stabilization Audit

Status:
- Audit only
- No app code changes made or authorized by this document
- Intended as a stabilization queue, not a redesign plan

Reviewed sources:
- `docs/DECISIONS.md`
- `docs/WHERE_WE_STAND.md`
- `historical/ux/redesign-rationale/TARGET_UI_DIRECTION.md`
- `historical/ux/redesign-rationale/VISUAL_LANGUAGE_SYSTEM.md`
- `historical/ux/redesign-rationale/GAME_DAY_SCREEN_SPEC.md`
- `RollCall/RootView.swift`
- `RollCall/DesignSystem/TeamBanner.swift`
- `RollCall/DesignSystem/StatusChip.swift`
- `RollCall/DesignSystem/RollCallButtonStyles.swift`
- `RollCall/DesignSystem/RollCallCardStyles.swift`
- `RollCall/DesignSystem/RollCallTypography.swift`
- `RollCall/DesignSystem/RollCallSpacing.swift`

## Protected Current Choices

This audit intentionally does not recommend changing these owner-revised choices:
- reduced top titles
- thin TeamBar
- compact Readiness refresh placement
- current Game Day hierarchy
- current Players row density
- current Clips live-side treatment

## Summary

The current UI has a clear direction: calm setup/admin surfaces, darker live-side surfaces for `Game Day` and `Clips`, and a reusable design-system layer for cards, chips, buttons, text, spacing, and TeamBar.

The main stabilization opportunities are not broad redesigns. They are small consistency and accessibility fixes:
- TeamBar status data is passed in several places but not visibly rendered.
- Some newer screens use design-system components while older or modal surfaces still use raw SwiftUI fonts, colors, and button styles.
- A few compact horizontal layouts may collide with Dynamic Type or long content.
- Some custom touch controls and icon-only affordances need stronger accessibility labels, values, and traits.
- Several unused old helper functions remain after the newer status-chip language landed.

## Proposed Fixes

### 1. Render TeamBar Secondary Status Consistently

Screen:
- `Players`
- `Clips`
- `Game Day`
- `Readiness`
- `Teams`

Issue:
- `TeamBanner` accepts `secondaryStatus`, and callers pass useful values such as player/present counts or `Warnings`, but the current component visually renders only the team name. The secondary status is included in accessibility value only.

Why it matters:
- The thin TeamBar is intentionally compact, but it currently drops visible context that the app already computes. This makes `Warnings`, present-player count, and no-team helper status less discoverable, especially on screens where the TeamBar is meant to anchor roster context.

Risk level:
- Low to medium. Low if status is rendered as a compact trailing text or tiny chip within the existing 34-point strip. Medium if the fix changes TeamBar height, live-side density, or the current thin identity.

Exact files likely touched:
- `RollCall/DesignSystem/TeamBanner.swift`
- Possibly `RollCall/RootView.swift` only if individual call sites need shorter labels.

Owner approval required:
- No, if the TeamBar remains thin and read-only.
- Yes, if the TeamBar becomes taller, interactive, or visually more prominent.

### 2. Align TeamBar No-Team Tone Across Screens

Screen:
- `Players`
- `Clips`
- `Readiness`
- `Teams`
- `Game Day`

Issue:
- No-team status is passed as neutral on most standard screens, but as warning on `Game Day`. That may be correct for live use, but the visible result is currently hidden by the TeamBar status rendering gap. Once status is visible, standard screens need a deliberate no-team tone choice.

Why it matters:
- `No Team Selected` should feel like a setup prompt on admin screens and a live blocker on `Game Day`. Without an explicit tone split, the same state may read too urgent in setup or too quiet in live use.

Risk level:
- Low.

Exact files likely touched:
- `RollCall/RootView.swift`
- `RollCall/DesignSystem/TeamBanner.swift`

Owner approval required:
- No, if this only preserves the current intent with clearer visible tone.
- Yes, if it changes no-team behavior, navigation, or adds TeamBar actions.

### 3. Stabilize Dynamic Type in Readiness Header Rows

Screen:
- `Readiness`

Issue:
- `ReadinessOverviewCard` places the title/date stack, refresh button, and summary chip in one top `HStack`. `ReadinessIssueFamilyCard` and `ReadinessCheckRow` also place titles and status chips in baseline-aligned horizontal rows.

Why it matters:
- With larger Dynamic Type, long readiness titles, or `Needs Attention` status, these rows can become crowded. The current compact refresh placement is approved and should stay, but the surrounding layout could wrap more gracefully.

Risk level:
- Low.

Exact files likely touched:
- `RollCall/RootView.swift`

Owner approval required:
- No, if the refresh button remains compact and in the current header area.
- Yes, if the refresh control is moved to a different hierarchy or made visually larger.

### 4. Replace Raw Button Styles in Player Setup With Roll Call Button Families

Screen:
- `Players`
- `PlayerEditorSheet`
- `AdvancedTrimSheet`

Issue:
- Several setup and editor controls still use raw `.bordered`, `.borderedProminent`, `.tint(.orange)`, or `.gray.opacity(...)` styling while `Teams`, `Settings`, and live controls use the newer Roll Call button styles.

Why it matters:
- The app now has a defined button family system. Mixing raw system buttons with custom Roll Call buttons makes the newer screens feel more intentional than the editor surfaces, even when the workflow is sound.

Risk level:
- Low to medium. Low for visual-only style swaps. Medium if button sizing changes inside forms or trim controls.

Exact files likely touched:
- `RollCall/RootView.swift`
- Possibly `RollCall/DesignSystem/RollCallButtonStyles.swift` if the existing button families need one form-friendly variant.

Owner approval required:
- No for narrow visual alignment that preserves labels, behavior, and placement.
- Yes if the trim/edit workflow, unlock behavior, or control order changes.

### 5. Normalize Status Language Between Player Rows and StatusChip

Screen:
- `Players`
- `PlayerEditorSheet`
- `Game Day`

Issue:
- Player rows use inline `Label` text for `No cue`, `Hidden from Game Day`, `Announcer missing`, and `No announcer cue`, while other screens use `StatusChip` for similar state. `Game Day` also has custom `GameDayStatePill` state language.

Why it matters:
- The current row density is approved and should remain, but status semantics are split across multiple local visual patterns. That makes it easier for warning, disabled, and ready states to drift in color, wording, or emphasis.

Risk level:
- Medium. Player rows are dense and current density is protected, so any status-chip adoption must avoid making rows taller or noisier.

Exact files likely touched:
- `RollCall/RootView.swift`
- Possibly `RollCall/DesignSystem/StatusChip.swift` if a very compact inline chip variant is needed.

Owner approval required:
- Yes if row height, density, or visible information hierarchy changes.
- No for purely internal cleanup or exact visual preservation.

### 6. Improve Accessibility for Custom Trim Scrubber

Screen:
- `PlayerEditorSheet`

Issue:
- `StartScrubControl` exposes an accessibility value, but it does not provide a clear accessibility label, adjustable action, hint, or disabled-state explanation when the unlock gate is off.

Why it matters:
- The scrubber is a custom gesture control. VoiceOver and switch-control users need to understand what it controls and how to adjust it. The current overlay text `Tap Enable to adjust start` is visual-only context unless mirrored into accessibility.

Risk level:
- Low.

Exact files likely touched:
- `RollCall/RootView.swift`

Owner approval required:
- No, if behavior remains unchanged and only accessibility metadata/actions are added.
- Yes, if the unlock model or trim interaction changes.

### 7. Improve Accessibility for Game Day Player Tiles

Screen:
- `Game Day`

Issue:
- The `Now Batting` hero has a custom accessibility label, but fallback player grid tiles rely mostly on combined child text. The tile action changes between play and stop depending on active state, yet the button does not expose an explicit action hint per tile.

Why it matters:
- `Game Day` is a high-pressure live surface. VoiceOver users should hear whether tapping a tile will play a cue, play a fallback, or stop the active cue.

Risk level:
- Low.

Exact files likely touched:
- `RollCall/RootView.swift`

Owner approval required:
- No, if this adds labels/hints only.
- Yes, if tile layout, density, or live hierarchy changes.

### 8. Replace Text Arrows in Game Day Control Row With Icon Labels

Screen:
- `Game Day`

Issue:
- The control row labels use text arrows: `<- Prev` and `Next ->`. Elsewhere, the app generally uses SF Symbols for icon-supported commands.

Why it matters:
- Text arrows feel like an older/prototype pattern and may read awkwardly with VoiceOver. SF Symbol labels would better match the app's icon language while preserving the current centered `Prev / Edit Lineup / Next` row.

Risk level:
- Low.

Exact files likely touched:
- `RollCall/RootView.swift`

Owner approval required:
- No, if the same three controls remain in the same row with the same behavior and compact scale.
- Yes, if the row layout, hierarchy, or control prominence changes.

### 9. Make Clips Header More Resilient to Long Text

Screen:
- `Clips`

Issue:
- `ClipsHeaderCard` places an icon, title/detail text, spacer, and a `Ready` chip in one horizontal row. The current live-side treatment is approved, but long localized text or larger Dynamic Type may crowd the trailing chip.

Why it matters:
- `Clips` is intentionally compact and companion-like. A small wrapping rule can preserve that treatment without making the header feel cramped.

Risk level:
- Low.

Exact files likely touched:
- `RollCall/RootView.swift`

Owner approval required:
- No, if the current live-side treatment, card role, and compactness remain.
- Yes, if the Clips screen becomes more dashboard-like or visually closer to Game Day.

### 10. Consolidate Remaining Raw Orange/Green/Red Status Colors

Screen:
- `PlayerEditorSheet`
- `AppleMusicPickerSheet`
- `StartScrubControl`
- `BasicPhotoCropperSheet`
- `PlayerPhotoThumbnail`

Issue:
- Some surfaces still use raw `.orange`, `.green`, `.red`, or hard-coded opacity colors rather than semantic design-system roles.

Why it matters:
- Semantic roles help keep warnings, live state, readiness, destructive actions, and disabled states distinguishable. Raw colors increase the chance that accent, warning, and live states drift or collide.

Risk level:
- Low to medium. Low for one-for-one semantic color replacement. Medium where color is part of a custom control or live feedback state.

Exact files likely touched:
- `RollCall/RootView.swift`
- Possibly `RollCall/DesignSystem/RollCallColors.swift` if a missing semantic role is needed.

Owner approval required:
- No for exact semantic color substitutions.
- Yes if the perceived meaning, priority, or warning strength changes.

### 11. Remove Unused Old Status Helper Functions

Screen:
- Code hygiene only; no user-facing screen if removed safely.

Issue:
- Old helper functions such as `cueStatusText`, `cueStatusBackground`, `cueStatusForeground`, `customIntroStatusText`, `customIntroStatusForeground`, and `customIntroStatusBackground` remain near the bottom of `RootView.swift`, but the visible UI has moved toward inline labels and `StatusChip`.

Why it matters:
- Dead helpers make it harder to tell which status language is current and which is leftover. Removing them would reduce the chance that future edits revive older visual patterns by accident.

Risk level:
- Low if confirmed unused by the compiler/search before removal.

Exact files likely touched:
- `RollCall/RootView.swift`

Owner approval required:
- No, if the helpers are truly unused and removal is compile-verified.
- Yes if any helper is still used or removal requires changing visible UI.

### 12. Decide Whether Players Should Stay List-Based While Other Setup Screens Are Card-Based

Screen:
- `Players`

Issue:
- `Players` uses `List` with inset grouped sections, while `Teams`, `Readiness`, and `Settings` use custom `ScrollView` plus `SectionCard` groupings. This is the largest remaining top-level shell difference outside the live screens.

Why it matters:
- The difference may be intentional because roster editing benefits from native list behavior, swipe actions, keyboard handling, and row density. Still, it is the most obvious place where an older iOS pattern remains next to the newer Roll Call card language.

Risk level:
- Medium to high. Changing away from `List` could affect swipe actions, row performance, keyboard behavior, edit ergonomics, and current protected row density.

Exact files likely touched:
- `RollCall/RootView.swift`
- Possibly `RollCall/DesignSystem/RollCallCardStyles.swift`

Owner approval required:
- Yes. This should be treated as a future design decision, not a stabilization default.

### 13. Audit Navigation Tab Order Against Current Implementation

Screen:
- App shell

Issue:
- The implemented tab order is `Players`, `Clips`, `Game Day`, `Readiness`, `Teams`, `Settings`. The visual language planning document records a planning direction of `Game Day`, `Clips`, `Players`, `Teams`, `Readiness`, `Settings`, while earlier target direction notes say launch/tab behavior needs careful approval.

Why it matters:
- This is a visible product hierarchy inconsistency between implementation and planning docs. It may be intentionally deferred, but it should be explicit so future agents do not treat the mismatch as accidental.

Risk level:
- Medium. Tab order and launch destination are behavior/product changes.

Exact files likely touched:
- `RollCall/RootView.swift`
- `historical/ux/redesign-rationale/VISUAL_LANGUAGE_SYSTEM.md` or another decision/status doc if the current order is intentionally retained.

Owner approval required:
- Yes for any tab order or launch destination change.
- No for documenting that the current order is intentionally retained.

### 14. Add Accessibility Labels to Icon-Only Play Buttons

Screen:
- `Clips`
- `AppleMusicPickerSheet`

Issue:
- `GeneralClipCard` has a good button-level accessibility label and hint, but its visible circular play icon is hidden. `AppleMusicRow` has a separate icon-only preview button with no explicit accessibility label or hint.

Why it matters:
- In the song picker, row tap selects immediately while the small play button previews. That split is intentionally approved, so the preview button needs to be unmistakable to assistive technologies.

Risk level:
- Low.

Exact files likely touched:
- `RollCall/RootView.swift`

Owner approval required:
- No, if labels/hints only.
- Yes, if picker row selection or preview behavior changes.

### 15. Improve Long-Name Handling in Team and Player Identity Areas

Screen:
- `TeamBar`
- `Teams`
- `Game Day`
- `Players`

Issue:
- Several identity areas use one-line text with minimum scale factors. This is appropriate for compact live surfaces, but long team/player names can still compress heavily, especially in `Game Day` hero and TeamBar.

Why it matters:
- Coaches may use long team names or player names. Over-compressed names can become hard to read during live use. The current reduced titles and row density should remain, but name handling can be made more predictable.

Risk level:
- Medium. Name wrapping can change heights and screen balance.

Exact files likely touched:
- `RollCall/RootView.swift`
- `RollCall/DesignSystem/TeamBanner.swift`

Owner approval required:
- Yes for any visible height/hierarchy changes in `Game Day`, TeamBar, or Players rows.
- No for tiny truncation/accessibility-label improvements that preserve layout.

## Lowest-Risk Stabilization Order

1. Add missing accessibility labels, hints, and values for custom controls and icon-only buttons.
2. Remove confirmed-unused old status helper functions.
3. Render TeamBar secondary status while preserving the current thin height.
4. Make compact horizontal rows wrap more gracefully under Dynamic Type.
5. Replace raw colors/button styles only where the visual result stays equivalent.
6. Revisit larger shell differences such as `Players` list styling and tab order only with owner approval.

## Explicit Non-Recommendations

These are not recommended as stabilization tasks:
- increasing top navigation title prominence
- thickening the TeamBar
- moving or enlarging the Readiness refresh control
- changing the current `Game Day` top-to-bottom hierarchy
- reducing current `Players` row density
- making `Clips` more dramatic or dashboard-like
- changing tab order, launch destination, queue behavior, playback behavior, Apple Music behavior, import/export behavior, persistence, or lineup semantics without explicit owner approval
