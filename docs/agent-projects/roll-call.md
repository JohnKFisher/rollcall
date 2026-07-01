# Roll Call Project Profile

Read this when the repository/task is Roll Call or clearly touches Roll Call product behavior, release/App Store work, support docs, Apple Music/media behavior, import/export packages, or existing Roll Call project docs.

Do not read this for unrelated projects.

## Identity

Roll Call is a public App Store app: `Roll Call: Walk-Up Music`.

Known exception: Roll Call must keep its existing bundle identifier. Do not propose or perform a bundle ID migration unless John explicitly asks.

## Product promise

Roll Call is an iPhone-first walk-up cue app for game-day delight with nearly invisible operation.

Game Day is the core promise: coach taps the player, the right thing happens, kids and parents enjoy it.

Do not weaken Game Day reliability, player/team setup preservation, Apple Music/media readiness, or field usability for monetization, configurability, polish, or broad sports-management scope unless John explicitly approves.

## Protected core workflows

Treat these as protected Roll Call behavior:

- Apple Music authorization, clip assignment, playback, unavailable-content handling, and permission failures,
- player intro cues and announcer audio,
- Game Day behavior,
- built-in clips/SFX behavior,
- readiness warnings,
- roster import,
- `.rollcall` import/export packages,
- player/team data safety,
- App Store/TestFlight metadata, review, signing, entitlements, privacy, and release packaging.

Unless John explicitly requests otherwise, this primary workflow should continue working after relevant changes:

1. Create or open a team.
2. Create or edit a player.
3. Assign walk-up media.
4. Enter Game Day.
5. Play the player’s introduction.

When changes affect player data, media playback, ordering, imports, announcements, readiness, UI navigation, Apple Music behavior, or `.rollcall` packages, verify Game Day behavior before considering the task complete.

Preserve backward compatibility for existing exported packages and user data unless explicitly approved.

Changes to protected workflows require verification proportional to risk and may trigger Apple, media/render/export, migration/format, user-data, diagnostics, and CI/release rules.

## Project docs routing

Prefer current docs/status first. Read historical docs only when historical context is explicitly relevant.

Likely project docs, if present:

- `docs/DECISIONS.md`
- `docs/WHERE_WE_STAND.md`
- `docs/WORKING_CHANGELOG.md`
- release notes / App Store / TestFlight / support docs
- privacy, terms, licenses, Sidelark Labs site pages

Do not inline long Roll Call history into agent rules. Route to the relevant current project doc when needed.

## Scope and monetization guardrail

Do not add or expand accounts, cloud sync, social features, backend infrastructure, scoreboard systems, generalized sports-management features, subscriptions, premium gates, or support/donation features unless John explicitly asks.

Premium, support, donation, or monetization features must never reduce Game Day reliability, player/team setup preservation, Apple Music/media readiness, or the core walk-up cue flow.

Roll Call `.rollcall` exports, team backups, and shared team data must not include support/purchase state. Restoring another person’s team data must never make the app claim the current user supported Roll Call.