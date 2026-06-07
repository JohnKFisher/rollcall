# Roll Call Readiness Model

Status: Accepted Product Direction
Confidence: High

---

## Purpose

Readiness exists to answer one question:

> If the user presses Start Game right now, will this feel good in front of people?

Readiness is NOT:

- completion percentage
- setup progress
- account completion
- checklist score
- “how much effort has the user invested”

Readiness exists only to help users feel confident using Roll Call live.

---

## Core Principle

A player is ready as soon as they have something meaningful to play.

Readiness should encourage.

Readiness should never shame.

---

# Player Readiness

Players have exactly three conceptual states.

---

## ✓ Ready

Definition:

Player has playable audio.

Examples:

- Apple Music song
- Imported local audio
- Intro + song
- Any future supported playable media

Outcome:

This player will work during Game Day.

This is the success state.

UI goals:

- Positive
- Calm
- No warning language

Examples:

✓ Ellie  
✓ Julia

---

## ★ Enhanced

Definition:

Player is already Ready and also has an announcer intro.

Examples:

"Now batting, number 17, Ellie..."

Outcome:

This player feels more exciting and more stadium-like.

This should feel like an enhancement.

NOT a requirement.

UI goals:

- Celebratory
- Discovery-oriented
- Encourage usage

Examples:

★ Ellie  
★ Emma

---

## ○ Optional Upgrades

Definition:

Everything else.

Examples:

- Player photo
- Team colors
- Presentation styles
- Theme packs
- Extra polish
- Optional presentation polish

Outcome:

Makes things cooler.

Never affects readiness.

UI goals:

- Never imply incompleteness
- Never imply failure

Examples:

○ Team logo missing  
○ No player photo

These should not reduce confidence.

---

# Explicitly Rejected Models

The following approaches are intentionally rejected.

---

## Percent Complete

Rejected:

❌ Setup 64%

Reason:

Creates guilt.

Users begin optimizing completion instead of preparing for Game Day.

---

## Multi-Level Completion Scores

Rejected:

Bronze
Silver
Gold
Platinum

Reason:

Turns setup into homework.

---

## Missing Features = Error State

Rejected:

❌ Player incomplete

Reason:

Player may already work perfectly.

---

# Team Readiness

Team readiness should answer:

> Can I confidently run Game Day?

NOT:

> How complete is my setup?

---

## Team Status States

### 🟢 Ready for Game Day

Definition:

Every player has playable audio.

Examples:

🟢 All players playable

---

### 🟡 Some Players Need Audio

Definition:

One or more players will use fallback behavior.

Examples:

🟡 3 players missing audio

Action:

Offer help.

Never block.

---

Optional secondary metrics:

⭐ 8 players have announcer intros

This is celebration.

Not pressure.

---

# Missing Data Philosophy

Roll Call never fails.

Fallback order:

1. Intro + Song
2. Song
3. Intro
4. Generic cheering

No player should feel broken.

---

# Discovery Philosophy

Announcer intros are important.

But they are non-obvious.

Do not teach them in onboarding.

Do not force setup.

Do not interrupt.

Instead:

Reveal them after success.

Example:

🎤 Nice!

Want to add announcer intros?

They make walkups feel way more like the real thing.

[ Try It ]

---

# Codex Implementation Notes

If implementing readiness:

DO:
- Optimize for confidence
- Optimize for discoverability
- Use positive language

DO NOT:
- Use percentages
- Gate Game Day
- Treat photos/styles as requirements
- Show warning-heavy UI
- Introduce setup completion mechanics

When uncertain:

Ask:

> Does this help users feel ready?

If not:

Do not include it in readiness.
