<!--
Historical document.
Purpose: baseline snapshot of the app before the completed redesign.
Not current implementation; use it to understand why redesign decisions were made.
-->

# Roll Call Current-State Documentation

This folder is a point-in-time documentation package for the current `Roll Call` iPhone app as it exists in this checkout on 2026-05-14.

Version documented:
- App version: `0.4.5`
- Build: `9`
- App target: `RollCall`
- Bundle ID: `com.jkfisher.rollcall`

What this package is for:
- preserve current behavior before future UI/UX redesign work,
- identify functionality that is fragile or tightly coupled to the UI,
- reduce the risk of breaking Apple Music, playback, persistence, or packaging flows,
- give future redesign work a safe starting map rather than forcing fresh reverse engineering.

What this package is not:
- not a redesign plan disguised as implementation,
- not a refactor proposal,
- not a claim that the current architecture is ideal,
- not proof that every runtime path was validated on-device in this session.

Verification status for this documentation pass:
- Core source and project metadata were inspected directly: `RollCall/RootView.swift`, `RollCall/AppModel.swift`, `RollCall/Services.swift`, `RollCall/Models.swift`, `RollCall/RollCallApp.swift`, `RollCall.xcodeproj/project.pbxproj`, `decisions/DECISIONS.md`, `docs/WHERE_WE_STAND.md`, `ATTRIBUTIONS.md`, `RollCall/LaunchScreen.storyboard`.
- A simulator screenshot/build pass was attempted through XcodeBuildMCP and failed twice before launch due `ZIPFoundation` module resolution/compiler-target incompatibility in the local build environment, so this package contains code-derived visual documentation rather than live screen captures.

Recommended reading order:
1. [APP_OVERVIEW.md](./APP_OVERVIEW.md)
2. [SCREEN_INVENTORY.md](./SCREEN_INVENTORY.md)
3. [NAVIGATION_FLOW.md](./NAVIGATION_FLOW.md)
4. [DATA_AND_STATE.md](./DATA_AND_STATE.md)
5. [FUNCTIONALITY_PROTECTION_ZONES.md](./FUNCTIONALITY_PROTECTION_ZONES.md)
6. [UI_STYLE_AUDIT.md](./UI_STYLE_AUDIT.md)
7. [KNOWN_BUGS_AND_TECH_DEBT.md](./KNOWN_BUGS_AND_TECH_DEBT.md)
8. [SAFE_REDESIGN_STRATEGY.md](./SAFE_REDESIGN_STRATEGY.md)
9. [COMPONENT_CATALOG.md](./COMPONENT_CATALOG.md)
10. [VISUAL_REFERENCES.md](./VISUAL_REFERENCES.md)

Executive summary:
- The app is a local-first, iPhone-only softball/baseball walk-up music tool with Apple Music as the primary song-selection path and device-owned media as a fallback.
- The current implementation is intentionally direct: one `AppModel`, one large `RootView.swift`, one `Services.swift` file containing most platform/service logic, and a codable `AppState` persisted into Application Support.
- The highest-risk areas for future redesign are not visual. They are cue playback timing, Apple Music capability gating, package import/export compatibility, lineup/session persistence, and custom-announcer recording/storage.
- The safest early redesign targets are Settings, Teams, Readiness, and General Clips. The riskiest targets are Player Editor trim flows, Apple Music picker/trim flows, and Game Day playback surfaces.
