# Roll Call UX Rulebook

This document captures current product UX rules for Roll Call. The current implementation is authoritative when it differs from older docs; if a proposed change conflicts with these rules or `docs/DECISIONS.md`, surface the conflict before changing behavior.

## Onboarding

Goal: user hears a successful walkup in about 5 minutes.

Preferred flow:
1. Create team
2. Add first player
3. Add audio through the same song-selection and Make Your Clip flow used elsewhere
4. Try Game Day

Encourage adding 3 players, but allow exit after 1.

Do not use:
- Long tutorial carousel
- Required account
- Permission barrage
- Setup checklist that feels like homework
- Donation, rating, or upgrade prompts

## Navigation

App should preserve the last useful context unless a first-run or no-team state requires onboarding.

For a populated team, Game Day should remain immediately reachable. Do not auto-launch flows or trap the user.

Empty team should encourage:
- Add your first player

Game Day and Clips are the two live surfaces. A deliberate horizontal swipe may move only between those two surfaces, must preserve playback and screen state, and must stay disabled while modal, edit, import, prompt, or other blocking flows are active.

## Readiness

Readiness should encourage, not shame.

Core idea:
- Ready on Any Device = playable and portable as Roll Call-owned media
- Ready on This Device = playable here, but device/account/library dependent
- Preparing = Roll Call is trying to improve reliability or portability
- Needs Apple Music / Needs Repair = actionable repair state
- Optional = photos, themes, polish

Built-in fallback keeps Game Day safe, but does not count as player-specific readiness.

Avoid:
- Red error states for incomplete players
- Percentages that make setup feel like homework
- Blocking Game Day
- Hiding portability or Apple Music caveats

## Missing Data

Game Day never fails.

Playback fallback order:
1. Intro + song
2. Song only
3. Intro only
4. Generic cheering fallback

Missing data should degrade gracefully, never break the live moment.

## Game Day

Saved lineup loads by default.

Temporary Game Day changes are allowed.

Temporary changes should not automatically rewrite durable team setup.

No explicit End Game required.

User can leave the app without feeling like they must save/finalize anything.

Game Day and Clips are the only live screens. Their Light/Dark behavior, including the lineup sheet opened from Game Day, is defined in `docs/product/APPEARANCE_RULES.md`.

Do not interrupt Game Day with onboarding, rating, donation, repair, or background-preparation UI.

Background song preparation may continue around live use only when throttled so user-triggered playback stays more important.

## Clips

Clips is a live-use surface, not a setup dashboard.

Sound Effects are bundled crowd reactions.

Custom Clips are team-specific live clips that are independent from Player Songs after copying. Editing, reordering, adding, and deleting Custom Clips must require explicit Edit mode and must not silently change a player's song.

Leaving Clips, backgrounding, or entering flows where live control is not safe should exit Custom Clips edit mode and stop any edit-only playback.

## Donations and Support UX

Do not mention donations during onboarding.

If donations are offered, place them in calm support-oriented surfaces, not in the middle of task flows.

Never interrupt setup or Game Day with donation prompts.

Never let a user carefully configure something and then imply they should pay to finish using what they already set up.

Users should feel like they have the complete product without paying.

Support language should be calm: support, contribution, donate. Avoid premium, upgrade, unlock, or pay-to-finish framing.

Donation/support surfaces belong in Settings/About-style places, not Game Day, Clips, onboarding, import, or repair flows.

## Permissions

Ask only after intent.

Explain before the system permission prompt.

Example:
User taps Add Music -> explain why Music access is needed -> system prompt.

Music Library is the primary song source. Apple Music catalog search is an explicit secondary path. Files are an available fallback.

Explicit Apple Music filtering is a selection-time safety layer: hide explicit Apple Music search results by default, and confirm explicit Music Library selections because the native library picker cannot be filtered ahead of time.

## Confirmations

Confirm only irreversible or destructive actions.

Prefer recovery over constant confirmations.

Unsaved-editor confirmations should be based on user-authored changes, not background preparation or metadata refreshes.

## Recovery

Teams are the most important thing to protect.

Use Recently Deleted for:
- Deleted teams
- Deleted players
- Deleted Custom Clips

Deleted teams, players, and Custom Clips stay recoverable for 60 days unless permanently deleted.

Backups are for returning to an earlier app state. Recently Deleted is for everyday accidental deletes.

When import, restore, or package transfer cannot recover media, preserve what can be identified and route the user toward repair instead of silently erasing the setup.

## Teams, Import, and Sharing

Team package import/export belongs with team management. Settings may point users there, but should not become the catch-all team tools surface again.

`.rollcall` sharing is manual ownership and portability, not cloud sync.

Package previews should be honest about portable clips, device-dependent clips, Apple Music needs, preparing items, and repair-needed items.

Apple Music playlist creation is a team convenience, not backup, export, or sharing.

## Ratings

Ask only after repeated successful use.

Never ask during Game Day.

Use Roll Call's own rating sheet before handing off to the App Store review page. Settings/About may expose Rate Roll Call only after the earned threshold is met.
