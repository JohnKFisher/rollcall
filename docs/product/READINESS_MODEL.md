# Roll Call Readiness Model

Status: Accepted Product Direction
Confidence: High

This document defines the product meaning of readiness. It should stay aligned with the visible Readiness tab, Player Editor song status, package preview/repair language, and Game Day fallback behavior.

---

## Purpose

Readiness answers one question:

> If the user opens Game Day right now, will this feel good in front of people?

Readiness is not a completion percentage, account score, setup checklist, or measure of how much effort the user has invested. It exists to help coaches trust the live moment.

## Core Principle

A player is ready when they have their own meaningful playable audio. Built-in fallback keeps Game Day safe, but it does not count as player-specific readiness.

Readiness should encourage. It should never shame, block, or turn setup into homework.

---

## Player Readiness

### Ready on Any Device

Definition: Roll Call has a playable app-owned local clip for the selected song window, or another future portable source with the same reliability.

Meaning:
- The player should work in Game Day.
- The clip is expected to travel in `.rollcall` team packages when export can include the media.
- This is the strongest readiness state because it is not tied to the current device account.

Tone: calm, confident, and positive.

### Ready on This Device

Definition: The player's song can play here from a source-backed route such as Apple Music, Music Library state, or preview-backed playback, but it is not currently portable as a Roll Call-owned local clip.

Meaning:
- The player should work on this device in Game Day.
- The song may require the same Music Library, Apple Music authorization, subscription state, network, or device-local availability after import on another device.
- This is still a valid success state, not a failure.

Tone: honest and reassuring. Explain the device boundary when tapped; do not bury the caveat in warning language.

### Preparing

Definition: Roll Call is trying to prepare a more portable or more reliable clip for a saved source.

Meaning:
- A previous playable route may still be used while preparation runs.
- Preparation is one job at a time, preserves older working clips when regeneration fails, and is throttled around live Game Day and Clips use.
- Low Power Mode may pause automatic preparation; explicit retry actions may bypass only that pause.

Tone: patient and non-alarming. Do not imply the coach must wait before using Game Day unless the player has no playable route.

### Needs Apple Music

Definition: The saved song depends on Apple Music or Music Library access that is not currently available.

Meaning:
- The user may need to grant Music access, sign in, enable subscription playback, restore library availability, or choose another source.
- Existing song choice should be preserved so the user can repair it.

Tone: actionable, not blaming.

### Needs Repair

Definition: Roll Call cannot currently read or play the saved source.

Meaning:
- The user should choose the song again or import a replacement before relying on that player's own walkup.
- Game Day fallback still protects the live moment.
- Import should preserve the unavailable item and route the user toward repair instead of silently deleting the setup.

Tone: clear and practical. This is a repair state, not a data-loss state.

---

## Enhancements

### Enhanced

Definition: A player who is already ready also has an Announcement Cue, such as "Now batting, number 17, Ellie."

Meaning:
- The player feels more stadium-like.
- This is a celebratory upgrade, never a requirement.

Announcer intros are important but non-obvious. Reveal them after the user has had a success; do not force them during onboarding.

### Optional Upgrades

Definition: Everything that can make the team feel cooler without changing whether Game Day works.

Examples:
- Player photo
- Team color
- Future themes or presentation styles
- Extra visual polish

Optional upgrades must never reduce confidence or imply that a player is incomplete.

---

## Team Readiness

Team readiness should answer:

> Can I confidently run Game Day?

Team readiness should not answer:

> How complete is my setup?

### Ready for Game Day

Definition: Every present player has player-specific playable audio.

Meaning: The team can run Game Day without relying on the generic fallback for player walkups.

### Some Audio Needs Attention

Definition: One or more players are missing player-specific audio, need Apple Music, are still preparing without another playable route, or need repair.

Meaning: Offer direct repair paths, but never block Game Day.

Optional secondary metrics, such as how many players have announcer intros or photos, should be framed as celebration or polish, not readiness debt.

---

## Device-Level Game Day Checks

Keep device and environment checks separate from player readiness. Examples:

- Audio route
- Network reachability when source-backed playback may need it
- Music authorization and subscription state
- Volume Automation setting and behavior
- At least one present player in the lineup

These checks can warn or offer actions, but they should not turn player cards red or convert optional setup into required setup.

---

## Missing Data Philosophy

Roll Call never fails the live tap silently.

Playback fallback order:

1. Intro + song
2. Song only
3. Intro only
4. Generic cheering fallback

Fallback protects Game Day. It does not mean the player's setup is lost, and it does not mean fallback should be counted as that player's own ready state.

---

## Explicitly Rejected Models

Do not use:

- Percent complete, such as "Setup 64%"
- Bronze, Silver, Gold, Platinum, or similar tiers
- "Player incomplete" as a primary status
- Red error styling for missing optional features
- Blocking Game Day because setup could be better

Reasons:
- Percentages create guilt.
- Tiers turn setup into homework.
- Missing polish does not mean the player is broken.
- Game Day reliability depends on graceful fallback, not perfect setup.

---

## Implementation Notes

Do:
- Optimize for confidence.
- Use positive, plain language.
- Make repair actions direct.
- Keep portability and device-specific readiness honest.
- Preserve user choices during import, repair, and regeneration.

Do not:
- Gate Game Day.
- Treat photos, themes, or announcer intros as requirements.
- Hide Apple Music or device-dependency caveats.
- Delete or overwrite a saved song choice just because it cannot play here yet.
- Introduce setup-completion mechanics.

When uncertain, ask:

> Does this help users feel ready?

If not, leave it out of readiness.
