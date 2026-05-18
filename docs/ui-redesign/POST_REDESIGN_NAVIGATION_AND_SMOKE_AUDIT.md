# Post-Redesign Navigation and Smoke Audit

Status:
- Audit only
- No app code changes made or authorized by this document
- Focused on post-redesign navigation, grouping, and obvious smoke-level UX friction

Reviewed sources:
- `docs/DECISIONS.md`
- `docs/WHERE_WE_STAND.md`
- `docs/roll_call_dev_notes.md`
- `docs/ui-redesign/TARGET_UI_DIRECTION.md`
- `docs/ui-redesign/VISUAL_LANGUAGE_SYSTEM.md`
- `docs/ui-redesign/GAME_DAY_SCREEN_SPEC.md`
- `docs/ui-redesign/PLAYER_EDITOR_FINAL_DIRECTION.md`
- `docs/ui-redesign/STABILIZATION_AUDIT.md`
- `RollCall/RootView.swift`
- `RollCall/DesignSystem/TeamBanner.swift`

Verification:
- Code inspection of the current implemented top-level tabs, major screen shells, Game Day board, Player Editor, Apple Music picker, and TeamBanner.
- `xcodebuild -project RollCall.xcodeproj -scheme RollCall -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build`
- Result: no-sign build succeeded.
- A signed generic iOS build reached code signing but failed with `resource fork, Finder information, or similar detritus not allowed`, which appears to be the existing signing/package artifact issue rather than a navigation/UI compile failure.
- Live simulator walkthrough was not completed in this pass because the available XcodeBuildMCP session had no project/scheme/simulator defaults configured.

## Protected Current Choices

This audit does not recommend changing these owner-revised choices:
- compact top titles
- thin TeamBar
- current Game Day hierarchy
- current Clips live-side companion treatment
- current Players row density
- Player Editor PE-1 / PE-2 section direction
- the dedicated Apple Music picker with row-tap-to-select and separate preview button

## Summary

The redesigned screens now read as two conceptual zones:

- Live-use / playback: `Game Day`, `Clips`
- Setup / administration: `Players`, `Teams`, `Readiness`, `Settings`

The current implementation does not fully communicate that architecture in the bottom tab bar. The implemented tab order is:

1. `Players`
2. `Clips`
3. `Game Day`
4. `Readiness`
5. `Teams`
6. `Settings`

That order worked while setup was the dominant surface, but after the Game Day, Clips, and Player Editor passes it now splits both major zones. `Clips` and `Game Day` are adjacent but reversed, while `Readiness` sits between live use and `Teams`, making the setup/admin group feel interrupted.

The main recommendation is a tab-order decision, not a broad redesign:

1. `Game Day`
2. `Clips`
3. `Players`
4. `Teams`
5. `Readiness`
6. `Settings`

This keeps all six current tabs, preserves screen ownership, and makes the app's evolved architecture visible without merging workflows.

## Issues Found

### 1. Current Tab Order Hides the New Live-Use Priority

Screen or navigation area:
- Bottom tab bar

Issue:
- `Players` remains first and the default selected tab, while `Game Day` is third. After the redesign, `Game Day` is clearly the live-use destination and `Clips` is its live-side companion.

Why it matters:
- The app now visually teaches that live operation is the destination, but the tab order still teaches that roster setup is the product center. That mismatch is small during setup and more noticeable when opening the app for an actual game.

Severity:
- Important

Likely file(s) touched:
- `RollCall/RootView.swift`
- Possibly `docs/DECISIONS.md` if the owner approves a durable navigation decision

Owner approval needed:
- Yes. Tab order and default selected tab are user-visible product behavior.

### 2. `Clips` and `Game Day` Are Adjacent but Reversed

Screen or navigation area:
- Bottom tab bar

Issue:
- The current order places `Clips` before `Game Day`.

Why it matters:
- `Clips` is now intentionally a lower-energy companion surface, not the primary live board. Putting it before `Game Day` makes the companion feel like the lead live-use surface.

Severity:
- Important

Likely file(s) touched:
- `RollCall/RootView.swift`

Owner approval needed:
- Yes.

### 3. `Readiness` Splits the Setup / Administration Cluster

Screen or navigation area:
- Bottom tab bar

Issue:
- `Readiness` currently appears before `Teams`, so the setup/admin sequence is `Players`, then later `Readiness`, then `Teams`, then `Settings`.

Why it matters:
- `Readiness` is a pre-game checklist and diagnostic surface, but its issues often point back to `Players` or `Teams`. Placing it after `Teams` would make it read more like "check the setup you just managed" instead of a tab wedged between live use and team administration.

Severity:
- Important

Likely file(s) touched:
- `RollCall/RootView.swift`

Owner approval needed:
- Yes.

### 4. Default Launch to `Players` May Now Be Contextually Correct but Conceptually Ambiguous

Screen or navigation area:
- App launch / initial selected tab

Issue:
- `selectedTab` defaults to `.players`. That remains useful for first-time setup, but after the redesign it conflicts with `Game Day` as the app's primary destination.

Why it matters:
- This is the one place where navigation and onboarding needs genuinely pull in different directions. Launching into `Players` is still safer when no team or playable player exists. Launching into `Game Day` may feel right for a ready roster but risky before readiness and team-selection affordances are fully validated.

Severity:
- Nice-to-have now; important before a release positioned around live use

Likely file(s) touched:
- `RollCall/RootView.swift`
- Possibly `AppModel` only if conditional launch logic is introduced later

Owner approval needed:
- Yes. Conditional launch or changing the default tab is a behavior change and should be deferred until explicitly approved.

### 5. TeamBar Computes Context That Is Not Visibly Rendered

Screen or navigation area:
- TeamBar on `Players`, `Clips`, `Game Day`, `Readiness`, and `Teams`

Issue:
- Call sites pass secondary status such as player/present counts or `Warnings`, but `TeamBanner` visually renders only the team name. The status appears only in accessibility value.

Why it matters:
- The redesign depends on the TeamBar as a lightweight orientation device across team-scoped screens. If its secondary status is hidden, the top-level screens lose a small but useful grouping cue, especially when moving between live and setup areas.

Severity:
- Important

Likely file(s) touched:
- `RollCall/DesignSystem/TeamBanner.swift`
- Possibly `RollCall/RootView.swift` if shorter status strings are needed

Owner approval needed:
- No if the TeamBar stays thin, read-only, and visually modest.
- Yes if the TeamBar becomes taller, interactive, or more prominent.

### 6. `Readiness` Feels Like a Setup/Admin Tab, Not a Live Tab

Screen or navigation area:
- `Readiness`

Issue:
- The screen itself is calm, bright, carded, and diagnostic, which places it conceptually in setup/admin. Its current tab position, not its internal design, is the awkward part.

Why it matters:
- A user may reasonably expect the sequence to be: manage team, manage players, check readiness, then run Game Day. The current order makes `Readiness` look more like a live-use neighbor than a preparation checkpoint.

Severity:
- Important

Likely file(s) touched:
- `RollCall/RootView.swift`

Owner approval needed:
- Yes for tab movement.

### 7. `Settings` Starts With Team Package Actions

Screen or navigation area:
- `Settings`

Issue:
- The first Settings section is `Team Package`, with export/import actions before Game Day preferences, recovery, About, and developer tools.

Why it matters:
- This is not wrong, and the section is well grouped. The only smoke-level concern is that package actions are team-scoped and relatively high-impact, so their top placement can make Settings feel partly like team administration rather than purely app-level controls.

Severity:
- Nice-to-have

Likely file(s) touched:
- `RollCall/RootView.swift`

Owner approval needed:
- Yes if section order changes.
- No for copy-only clarification inside the existing structure.

### 8. `Team Actions` Menu Hides Important Team Lifecycle Commands

Screen or navigation area:
- `Teams`

Issue:
- Rename, duplicate, roster CSV import, and remove are grouped behind one `Team Actions` menu.

Why it matters:
- This is a reasonable compact management choice, but after the Teams polish the surface looks calm enough that some users may not notice rename/import/remove live inside the menu. It is mild friction, not a broken flow.

Severity:
- Nice-to-have

Likely file(s) touched:
- `RollCall/RootView.swift`

Owner approval needed:
- Yes if commands are promoted out of the menu or the lifecycle layout changes.
- No for a small label/copy tweak that preserves the menu.

### 9. Game Day `Next` Uses a Custom HStack Instead of `Label`

Screen or navigation area:
- `Game Day` control row

Issue:
- `Prev` uses `Label("Prev", systemImage: "chevron.left")`, while `Next` uses a custom `HStack` with text plus icon.

Why it matters:
- The visible behavior is correct, but the asymmetry is a small polish inconsistency in a core live control row. It can also make accessibility and future styling slightly easier to drift.

Severity:
- Nice-to-have

Likely file(s) touched:
- `RollCall/RootView.swift`

Owner approval needed:
- No if the control row keeps the same labels, order, and behavior.
- Yes if the row hierarchy or transport semantics change.

### 10. Player Editor Still Looks More System-Form Than the Polished Top-Level Screens

Screen or navigation area:
- `PlayerEditorSheet`

Issue:
- PE-1 / PE-2 have improved the editor's section order and conceptual flow, but the implemented sheet still uses mostly raw `Form`, standard sections, `.bordered` buttons, and raw orange/red/gray styling.

Why it matters:
- This is not a functional regression. The workflow is clearer now. The smoke issue is that the editor is the main setup surface behind `Players`, so it can feel visually older than the newly polished top-level screens.

Severity:
- Nice-to-have

Likely file(s) touched:
- `RollCall/RootView.swift`
- Possibly `RollCall/DesignSystem/RollCallButtonStyles.swift`

Owner approval needed:
- No for narrow visual alignment that preserves PE-1 / PE-2 behavior.
- Yes if the editor workflow, save/close semantics, trim interaction, media flow, or section order changes.

### 11. Song Picker Row Split Is Correct but Needs Continued Visual Care

Screen or navigation area:
- `AppleMusicPickerSheet`

Issue:
- Row tap selects immediately, while the small play button previews. This is an approved and useful split, but the visual distinction must remain unmistakable because the actions are very different.

Why it matters:
- Accidentally selecting when intending to preview would be setup friction. The current code now includes explicit preview accessibility labeling, which helps; this should remain protected in future polish.

Severity:
- Nice-to-have

Likely file(s) touched:
- `RollCall/RootView.swift`

Owner approval needed:
- Yes for any change to row-tap selection or preview behavior.
- No for purely visual/accessibility reinforcement.

### 12. `Readiness` Is a Future Merge Candidate but Not Redundant Today

Screen or navigation area:
- `Readiness`

Issue:
- `Readiness` overlaps conceptually with `Players` and `Teams` because many readiness findings are repaired there.

Why it matters:
- The tab is still useful as a pre-game checklist because it gathers cross-cutting checks in one place. It should not be merged now. But over time, if issue routing becomes strong enough, `Readiness` could become a pre-game layer, checklist entry point, or contextual status inside setup rather than a permanent top-level tab.

Severity:
- Nice-to-have

Likely file(s) touched:
- Future work could touch `RollCall/RootView.swift`, readiness routing in `AppModel`, and related docs

Owner approval needed:
- Yes. Any merge or routing change would be a navigation and behavior change.

## Recommended Updated Tab Order

Recommended:

1. `Game Day`
2. `Clips`
3. `Players`
4. `Teams`
5. `Readiness`
6. `Settings`

Conceptual reasoning:
- `Game Day` is the primary live-use destination.
- `Clips` is live-use/playback, but companion-like and lower stakes than `Game Day`, so it belongs immediately after it.
- `Players` and `Teams` are the main setup/admin surfaces and should sit together.
- `Readiness` checks the setup and bridges into pre-game confidence, so it belongs after the concrete setup surfaces.
- `Settings` remains last because it holds app-level operations, recovery, About, and developer tools.

This order communicates the evolved architecture without adding tabs, removing tabs, merging workflows, or changing any playback/setup behavior.

## Redundant or Future-Merge Candidates

Current assessment:
- No tab is clearly redundant today.
- `Clips` should stay separate for now. It is playback-adjacent, but not Game Day; merging it into Game Day would risk turning Game Day into a broader soundboard/dashboard.
- `Readiness` is the most plausible future-merge or future-routing candidate, but only after the repair paths are stronger and owner-approved.
- `Teams` should remain separate for now because team lifecycle actions are conceptually different from player setup and are potentially destructive.
- `Settings` should remain separate and last.

## High-Risk Navigation Changes to Defer

Defer unless explicitly approved:
- Making `Game Day` the default launch tab unconditionally.
- Adding conditional launch routing based on selected team, playable players, or readiness.
- Merging `Clips` into `Game Day`.
- Merging `Readiness` into `Players` or `Teams`.
- Turning TeamBar into an interactive team switcher or readiness shortcut.
- Adding deep-link repair routing from readiness findings into Player Editor or Teams.
- Changing Game Day tap/play/stop behavior while adjusting navigation.

## Bottom Line

The app's screens now mostly express the intended live/setup split. The remaining mismatch is the tab shell. A simple reordered six-tab structure would communicate the redesign better while keeping the implementation and product model conservative:

`Game Day`, `Clips`, `Players`, `Teams`, `Readiness`, `Settings`.
