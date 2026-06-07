# Roll Call UX Rulebook

## Onboarding

Goal: user hears a successful walkup in about 5 minutes.

Preferred flow:
1. Create team
2. Add first player
3. Add audio
4. Try Game Day

Encourage adding 3 players, but allow exit after 1.

Do not use:
- Long tutorial carousel
- Required account
- Permission barrage
- Setup checklist that feels like homework

## Team Home

App should open to the last team.

Team Home should make Game Day one tap away.

Empty team should encourage:
- Add your first player

Do not auto-launch flows or trap the user.

## Readiness

Readiness should encourage, not shame.

Core idea:
- Ready = playable
- Enhanced = announcer intro
- Optional = photos, themes, polish

Avoid:
- Red error states for incomplete players
- Percentages that make setup feel like homework
- Blocking Game Day

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

## Donations and Support UX

Do not mention donations during onboarding.

If donations are offered, place them in calm support-oriented surfaces, not in the middle of task flows.

Never interrupt setup or Game Day with donation prompts.

Never let a user carefully configure something and then imply they should pay to finish using what they already set up.

Users should feel like they have the complete product without paying.

## Permissions

Ask only after intent.

Explain before the system permission prompt.

Example:
User taps Add Music -> explain why Music access is needed -> system prompt.

## Confirmations

Confirm only irreversible or destructive actions.

Prefer recovery over constant confirmations.

## Recovery

Teams are the most important thing to protect.

Use Recently Deleted eventually for:
- Deleted teams
- Deleted players
- Possibly replaced imports

Archive/recovery can come later, not necessarily 1.0.

## Ratings

Ask only after repeated successful use.

Never ask during Game Day.
