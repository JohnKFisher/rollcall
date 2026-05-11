# Roll Call — iPhone Walk-Up Music App Master Plan

## Overview

Roll Call is an iPhone-first softball/baseball walk-up music app designed for real-world game-day use.

Primary goals:
- reliable game-day playback
- simple UX for non-technical sports parents/coaches
- Apple Music integration where possible
- fully local/offline fallback workflows
- safe data handling and exports
- strong future-proofing without overengineering

---

# Product Priorities

## Priority Order

### 1. Reliability
Reliability wins every architectural tradeoff.

The app must:
- launch quickly
- survive app switching
- play cues reliably
- handle poor network conditions gracefully
- avoid data loss
- degrade safely when Apple Music fails

### 2. Simplicity + Apple Music Convenience
The app should make common workflows extremely easy:
- add player
- assign cue
- enter game mode
- tap player
- sound plays

Apple Music workflows should feel natural.

### 3. Advanced Tweaking
Advanced functionality should exist, but remain hidden from normal users.

The app should:
- feel simple by default
- support obsessive tweaking only when requested

---

# Core App Structure

## Main Tabs

### Players Tab
Displays:
- player buttons
- name
- optional number
- optional photo
- cue status

Tap:
- plays cue sequence

Long press:
- optional future advanced actions

---

### General Clips Tab
Contains:
- applause
- cheers
- fallback sounds
- hype clips
- misc effects

General clips use the SAME underlying cue engine as player cues.

---

# Cue Architecture

## Cue Sequence

A cue is NOT just a song.

A cue is:
1. optional announcer intro
2. optional pause
3. music playback
4. fadeout
5. automatic stop

---

# Audio Rules

## Single Playback
Only one cue plays at a time.

Starting a new cue:
- rapidly fades current cue
- starts new cue

Tapping active cue again:
- rapid fade stop

---

## Debounce
Prevent accidental double presses.

Default:
- ~0.5 second tap lockout

Configurable later.

---

# Apple Music Support

## Supported Goals
The app should:
- search Apple Music
- choose songs
- seek to cue points
- store metadata references
- preload playback

---

## Reality Check
MusicKit officially supports:
- playback
- seeking
- library/catalog access

MusicKit does NOT officially support:
- exporting songs
- extracting audio
- saving trimmed clips

Therefore:
- Apple Music integration must be resilient
- local imported audio remains the safest path

---

## Apple Music Cue Limits
Apple Music cues:
- max 20 seconds
- treated as lightweight playback events
- may require Apple Music availability

This helps:
- reliability
- responsiveness
- future App Store safety

---

## Experimental Extraction Layer
For personal/testing builds ONLY:

If technically possible:
- experimental Apple Music extraction/caching may exist

Requirements:
- isolated behind feature flags
- removable cleanly later
- never required for app functionality

---

# Imported Audio

## Supported Imports
Allow:
- audio files
- video files

If video:
- extract audio
- discard video immediately

---

## Internal Storage
Imported assets should:
- copy into app-managed storage
- NOT reference external paths

Reasons:
- portability
- reliability
- offline support
- clean exports

---

# Editing Philosophy

## Progressive Disclosure
Do NOT build:
- separate basic editor
- separate advanced editor

Instead:
- one editor
- advanced controls hidden/collapsible

---

## Basic Editing
Normal users should be able to:
- pick song
- set in point
- set out point
- preview
- save

---

## Advanced Editing
Advanced users may:
- fine-tune timing
- adjust fades
- nudge cue points
- adjust gain
- inspect waveforms

---

# Waveforms

Waveforms:
- imported local audio only initially
- lightweight rendering
- removable if complexity outweighs benefit

Do NOT build a DAW.

---

# Photos

## One Photo Per Player
Only one photo supported.

---

## Optimization
Photos should:
- resize automatically
- compress intelligently
- avoid huge storage waste

No need to preserve gigantic originals.

---

# Team Management

## Multiple Teams
Support:
- multiple projects/teams
- duplication
- easy switching

---

## Team Duplication
Allow:
- safe experimentation
- alternate cue setups
- season rollover

---

# Import / Export

## Canonical Package Format
Primary export:
`.rollcall`

Internally contains:
- manifest JSON
- imported audio
- photos
- metadata

---

## Sharing
Packages should support:
- AirDrop
- Files app
- iCloud Drive
- Messages

---

## CSV Import
Support lightweight roster import:
- name
- number

CSV is intentionally less technical than JSON.

---

# Data Safety

## Autosave
Continuous autosave.

No explicit Save workflow.

---

## Schema Versioning
All saved data should include:
- schema version
- migration support

Critical for future updates.

---

## Source Data vs Cache Data

### Source-of-truth
- players
- cues
- lineup
- settings

### Disposable Cache
- waveforms
- announcer audio
- thumbnails
- temporary generated assets

Caches should always be rebuildable.

---

# Backup System

## Automatic Snapshots
Create safety snapshots before:
- imports
- overwrites
- destructive edits
- migrations

---

## Restore
Provide lightweight restore/recycle-bin workflows.

---

# Game Day Mode

## Goals
Game Day Mode should:
- use huge buttons
- remain simple
- be outdoor readable
- reduce accidental taps
- hide editing complexity

---

## Layout
Portrait only in v1.

Likely:
- 2-column layout
- large buttons
- strong contrast
- minimal clutter

---

## Outdoor Visibility
Support:
- light mode
- dark mode

Optimize for:
- sunlight readability
- contrast
- large typography

Team colors:
- accents only
- never compromise readability

---

## Panic Stop
Persistent emergency stop button:
- always visible
- immediately stops playback

---

## Haptics
Support:
- success haptic
- warning haptic
- optional disable

---

## Protected Mode
Optional protection:
- confirm before exit
- hide editing
- reduce accidental interactions

May recommend Guided Access.

---

# Lineup System

## Today’s Roster
Before game:
- mark present/not present
- drag batting order
- review readiness warnings

---

## Daily Reset Logic
Same day:
- preserve lineup state

Next day:
- create fresh session
- optionally reuse prior lineup

---

## Next Batter Workflow

Advance button:
- advances lineup
- preloads next cue

BUT:
- does NOT auto-play

Playback still requires intentional tap.

---

## Prewarming
When:
- announcer speech plays
- next batter selected

The app should:
- preload music assets
- reduce playback latency

---

# Readiness Check

The app should test:
- Bluetooth/audio route
- volume
- network quality
- Apple Music availability
- missing files
- cue readiness

Warn clearly when:
- Apple Music cues may fail in poor network conditions

---

# Offline Philosophy

Imported audio:
- expected fully offline

Apple Music:
- may not always be offline reliable
- app should warn users honestly

---

# Built-In Safety Sounds

Bundle:
- applause
- crowd cheer
- fallback hype sounds

Requirements:
- legally licensed
- CC0/public domain/etc.

---

# Licensing Rules

Codex must:
- explain all licenses
- identify redistribution rules
- identify App Store implications

Never silently include questionable assets.

---

# Developer Settings

## Experimental Features Screen

Separate hidden/developer page containing:
- feature flags
- explanations
- risks
- App Store suitability notes
- debugging tools

Purpose:
- prevent experimental features from becoming forgotten permanent hacks

---

# Support Bundle

Generate diagnostic bundle from developer settings.

Include:
- app version
- schema version
- logs
- feature flags
- playback diagnostics
- readiness results

Exclude copyrighted media by default.

---

# Technical Recommendations

## Preferred Stack
- SwiftUI-first
- native Apple APIs first
- minimal dependencies

---

## Avoid
Do NOT build:
- accounts
- cloud sync
- social features
- backend infrastructure
- subscriptions
- scoreboard systems

Roll Call is:
- a cue playback app
- with lineup assistance

NOT:
- a sports management platform

---

# Suggested Architecture

## TeamStore
Handles:
- manifests
- imports/exports
- migrations
- backups

## CueEngine
Handles:
- sequencing
- fades
- playback
- announcer speech
- preload logic

## AudioProvider Layer
Abstracts:
- Apple Music
- local audio
- experimental extraction

## GameSessionManager
Handles:
- lineup state
- daily sessions
- current batter
- prewarming

## CacheManager
Handles:
- waveforms
- thumbnails
- generated announcer clips

## DiagnosticsManager
Handles:
- logs
- support bundles
- readiness checks

---

# Final Product Goal

Roll Call should feel:
- trustworthy
- fast
- low stress
- polished
- simple for non-technical users

The best version is not the one with the most features.

It is the one where:
- a stressed parent taps a player button
- and the right thing happens immediately.
