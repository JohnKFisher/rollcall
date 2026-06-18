# Roll Call — Application Overview

This document gives a non-code AI everything it needs to discuss the Roll Call app at a product level: what it is, who it's for, how the screens fit together, what the user can do on each one, and the principles that constrain future change. It is current as of build 63 / version 1.1.0.

If you are an AI reading this to help with planning: assume the human you are talking to is the sole developer and product owner. They want help thinking through changes, tradeoffs, and priorities — not generating code. Quote back the principles in this document when they conflict with a proposal.

---

## 1. What Roll Call Is

Roll Call is an iPhone app for **youth-sports walk-up cues**. The coach (or a parent, sibling, helper) sets up a roster ahead of time. When a player comes to bat (or step onto the field, or up to the line — it is sport-agnostic), the user taps the player's tile and the app plays that player's chosen audio cue: usually a short trimmed clip of their walk-up song, optionally introduced by a recorded "Now batting, number 17, Ellie..." announcement.

It is iPhone-first, all app features are free, optional in-app donations may be offered to support development, and it has no required account, no ads, no social features, and no cloud backend. All data lives on device. Teams can be exported as `.rollcall` packages and imported on another device, but that is a manual sharing model, not automated sync.

### The product priorities, in order

1. **Easy** — a coach should be ready in about five minutes
2. **Personal** — it should feel like *their* team, not a generic app
3. **Cool** — walkups should feel exciting in front of kids and parents
4. **Professional** — polish matters, but never at the cost of the above

### The single most important promise

> If the coach opens the app and taps Start Game right now, it should feel good in front of players, parents, and teammates.

Every product decision is filtered through that promise. Reliability of the live moment is sacred. Setup is allowed to be imperfect; Game Day is not.

---

## 2. Core Vocabulary

These words have specific meaning in Roll Call. Use them precisely when discussing changes.

- **Team** — the durable container. Has a name, accent color, roster of players, batting order, session state, announcer profile, and a small library of built-in crowd clips. A device can have many teams. One team is "selected" at a time.
- **Player** — belongs to a team. Has display name, optional uniform number, optional photo, optional cue (audio assignment), optional custom announcer recording, and an `isPresent` flag for today's lineup.
- **Cue** — the playable audio assignment for a player. Has a source (Apple Music song, local audio file, or built-in clip), a start time, a duration, a fade-out duration, and a pause-after-announcer value. A player without a cue falls back to a generic crowd cheer at Game Day.
- **Announcer / Announcement Cue** — an optional recorded voice clip ("Now batting, number 17, Ellie!") that the user records into the app. Separate from the song cue. Lives at the player level.
- **Lineup / Batting Order** — the ordered list of present players for today's game. Game Day plays in this order. The user can sort A-Z, sort by number, or drag manually. Manual order is preserved across launches.
- **Game Day** — the live screen where the actual walkups happen. The product's reason for existing.
- **Game Day Announcer Mode** — how cues play. Three values: `Announcer Only`, `Announcer+Song`, `Song Only`. Set per-team in session state, toggled from the live screen.
- **Clip / General Clip** — the team's built-in library of short crowd sounds (e.g. `Small Cheer`, `Crowd Swell`, `Big Cheer`) for live moments outside the walkup flow. Lives in its own tab.
- **Readiness** — Roll Call's confidence model. Answers "if I pressed Start Game right now, would it feel good?" Three states for players: ✓ Ready (has playable audio), ★ Enhanced (has audio + announcer intro), ○ Optional (everything else — photos, polish). Never a percentage. Never red. Never blocks Game Day.

---

## 3. First Run & Setup Guide

The very first time the user opens the app, they see a **full-screen welcome screen**: a softball image, large title "Welcome to Roll Call.", subtitle "Generate Walk-Up Music Cues for Youth Sports", and a single "Let's Get Started" button. This is the entire welcome — no tutorial carousel, no slideshow.

Tapping the button enters the **Setup Guide**, a guided onboarding sheet that walks the user through creating their first team. The Setup Guide is also reachable later from Settings → "Open Setup Guide" if the user wants to add another team via the guided flow.

### Setup Guide structure

The guide has four numbered milestones rendered as a breadcrumb at the top: **Team → Player → Audio → Lineup**. The active step is highlighted; completed steps show checkmarks. On the final "You're ready to try Roll Call" screen, all four are checkmarked.

Setup Guide steps:

1. **Team** — name the team, pick an accent color from eight presets (Roll Call Orange, Red, Gold, Green, Blue, Purple, Gray, Black). Or "Add Team from Another User's .rollcall File" instead.
2. **Player** — add a first player (name required, uniform number optional). On returning to this step later, this screen becomes "Review your first/second/third player." for editing.
3. **Audio** — assign walkup audio. Primary choice is "Add Song" (Apple Music). Secondary is "Use Local Audio". A "Try with a Crowd Cheering" option lets the user defer audio entirely and use the built-in cheer fallback. After audio is assigned, the screen turns into a simple trim selector (start point + length chips: 6, 8, 10, 12, 15 seconds, plus a Preview button).
4. **Lineup** — two variants:
    - With fewer than 3 players: title reads "Three players make lineup click." The primary action is "Add One More Player to Reach Three." A secondary "Open Lineup Anyway" is available. "Got It" is hidden until the user opens the lineup at least once.
    - With 3+ players: title reads "Now check the lineup." Primary action is "Open Today's Lineup." "Got It" still requires the user to actually open the lineup first.

Opening the lineup (during the guide or later) shows the **Lineup Editor sheet** described in §5. After dismissing it, "Got It" becomes available. Pressing "Got It" advances to the final handoff screen: **"You're ready to try Roll Call."** with a single "Open Game Day" button. That tap completes onboarding and routes the user to the Game Day tab.

### Setup Guide can also be entered for additional teams later

From Settings, "Open Setup Guide" launches a **manual chooser** variant first: "What would you like to set up?" with two choices: "Create New Team" (re-runs the guide) or "Add Team from .rollcall File" (jumps to file picker). The first run skips this chooser and goes straight into team creation.

Back navigation in the guide is bidirectional — there is a Back chevron in the toolbar, and Close is available once at least one team exists (with a confirmation: "Close Setup Guide?").

---

## 4. Main Navigation — The Six Tabs

Once onboarding is complete, the app's main UI is a six-tab `TabView`. The order is:

1. **Game Day** (`play.rectangle.fill`)
2. **Clips** (`music.note.list`)
3. **Players** (`person.3.fill`)
4. **Teams** (`list.number`)
5. **Readiness** (`checklist`)
6. **Settings** (`gearshape.fill`)

Every tab (except the live ones) shows a **team banner** at the top with the selected team's name, accent color, and a small status line (e.g. "12 players • 9 present"). The banner is consistent across tabs so the user always knows which team is active. On Game Day, the banner shows a "Warnings" badge if anything live needs attention.

There is no automatic launch into Game Day on app open; the app remembers which tab the user was on. The principle is "open to the last team, don't trap the user in a flow."

---

## 5. Tab Details

### 5.1 Game Day (the live screen)

The center of the product. Dark by default in Live appearance (toggleable in Settings: "Always Use Dark Live Screens"). Layout, top to bottom:

- **Announcer Mode Picker** — segmented control for the three modes (Announcer Only / Announcer+Song / Song Only). Selection is per-team and persists.
- **Live Warning Strip** (only shown when needed) — e.g. "No present players in the lineup", or a count of live readiness issues. Yellow or red tinted.
- **Now Batting Hero card** — large player tile for the currently-playing or next-up player. Shows photo, name, number, the cue title (song name, or "Announcer Only", or "Fallback: Small Cheer"). Tap to play. A visible playing indicator appears while audio is active. If the coach taps a later player out of sequence, this card temporarily relabels itself as `Lineup Override` and shows that player until playback ends.
- **On Deck card** — smaller tile for the player after the real lineup next batter. Greys out when there is no next batter (one-player roster), and does not temporarily change during a lineup override tap.
- **Control Row** — a "Lineup" button that opens the lineup editor sheet. Plus playback controls when audio is active (stop).
- **Player Grid** — all present players as tappable tiles that continue the visible lineup after `On Deck`, wrapping through the rest of the order so everyone stays available on the board. Tapping any tile still triggers that player's walkup immediately (the grid is sequence-oriented visually, but the coach can still tap whoever is actually at bat).

Tap interactions degrade gracefully. If a player has no cue and announcer mode is "Song Only" or "Announcer+Song", playback falls back to a built-in cheer. If a player has no recorded announcer in "Announcer Only" mode, same. Game Day never fails silently and never errors out — it always plays *something*.

### 5.2 Clips (the General Clips tab)

A team's library of built-in crowd reactions, separate from per-player cues. Defaults now focus on a smaller sports-oriented set: a friendly fallback cheer, a rhythmic clap, a general stadium swell, a stronger rally cheer, a bigger cheer, and a simple chant option. Each clip is a card with title, duration text, and a large play button (circle, accent color). Tapping plays the clip immediately. This tab uses the same Live appearance treatment as Game Day so it doubles as a "during a live moment, fire a crowd reaction" surface.

Clips currently are a fixed bundled set per team — the user cannot add custom clips. (This is on the 1.x list as "Improved Clips" and "Ability to add songs to clips.")

### 5.3 Players (roster management)

A grouped list of the selected team's roster, sorted alphabetically.

- **Top section: Add Player (quick add)** — an inline name/number field with an Add button. Fast roster entry.
- **Roster section** — each row shows photo, name, number, an audio-status icon, a custom-intro-status icon (if applicable), and a "marked out" treatment (dimmed) if the player is not present. Tapping a row opens the **Player Editor sheet** (see §6.1). Swipe left exposes a "Mark Out" / "Mark In" action.

If no team is selected, the tab shows a ContentUnavailable view nudging the user toward Teams.

### 5.4 Teams (team lifecycle)

Three sections:

- **Selected Team** — the active team's summary card, an Accent Preset Grid for changing color, and a "Team Actions" menu (Rename, Duplicate, Update Apple Music Playlist, Import Roster CSV, Remove).
- **Create Team** — single text field and "Create Team" button.
- **Teams** — list of every team on device with selection state.

This is where team identity and lifecycle live, intentionally separated from everyday roster work in the Players tab.

### 5.5 Readiness

The "are we good to play?" view. Per the Readiness Model (`docs/product/READINESS_MODEL.md`), it is intentionally encouraging, never shaming. Cards, in order:

- **Readiness Overview Card** — overall summary plus "Open Game Day" button.
- **Player Audio Card** — list of players, each showing ✓ Ready (has audio) or "Needs Audio" (will use fallback). Tap to open the player editor.
- **Enhancements Card** — announcer-intro upgrades (★ Enhanced). Discoverability surface for the announcer feature, not a requirement.
- **Optional Upgrades Card** — photo additions and other cosmetic polish.
- **Game Day Checks Card** — device-level conditions: audio route, network, Apple Music auth, volume automation, lineup configured. These can issue "Request Apple Music Access" or similar action prompts.

There is no percentage score, no Bronze/Silver/Gold, no red player errors. A player without audio is "Needs Audio," not "Incomplete."

### 5.6 Settings

A scroll view of grouped sections:

- **Team Package** — Export Selected Team, Share Latest .rollcall Package (only shows once an export exists), Add Team from .rollcall Package.
- **Setup Guide** — Open Setup Guide (returns user to the guided flow for a new or imported team).
- **Game Day** — three toggles: Always Use Dark Live Screens (default on), Game Day Haptics, Volume Automation (off by default; lets Roll Call adjust system volume for fades).
- **Recovery** — navigation into Recovery, where `Recently Deleted` handles everyday team/player undelete for 60 days and backups remain available for restoring an earlier app state.
- **About** — version, build, environment chip, copyright credit to John Kenneth Fisher, GitHub link, Email Feedback link (pre-fills version metadata), Attributions & Licenses link.
- **Advanced / Developer Tools** (only visible when feature flag is on) — environment gates, runtime testing flags, experimental actions, diagnostics.

---

## 6. Key Sheets & Modals

### 6.1 Player Editor sheet

Opened from any player row (Players tab, Readiness list, Game Day tile long-press). The most feature-rich screen in the app. Sections, top to bottom:

- **Setup Summary** — at-a-glance status card.
- **Identity** — display name, uniform number, photo (PhotosPicker → in-app crop).
- **Song Cue** — choose Apple Music song, choose Local Audio, swap source, clear cue. Shows the assigned song title and source.
- **Fine Tune Clip** (only when a cue exists) — start scrubber, length chips, suggested-hook / start-at-beginning modes, preview, and an "Advanced Trim" navigation that opens a more detailed editor.
- **Announcement Cue** — record a custom intro via in-app mic recording. Buttons: Start/Stop Recording, Preview, Clear. A warning is shown if the file reference exists but the audio file is missing.
- **Remove Player** at the bottom, destructive role.

The editor is large and rich because per-player setup is where most setup time is spent. But the Setup Guide deliberately avoids most of this complexity — it only touches identity and song cue, leaving photos, announcer recordings, and advanced trim for later.

### 6.2 Lineup Editor sheet

Opened from Game Day's Lineup button, from the Setup Guide's lineup step, or from anywhere else lineup is editable. Sections:

- A short helper paragraph: "Turn off players who are not here today, then drag players into batting order."
- **Lineup section** — Sort A-Z and Sort by Number buttons, then the drag-reorderable list. Each row shows player photo, name, number, and a Present toggle.
- **Status section** — a footer reminding the user that manual order is preserved across launches until they re-sort.

This sheet uses the system Edit mode for dragging. Closing returns to wherever it was opened from.

### 6.3 Apple Music Picker sheet

Title "Choose Song." Search Apple Music's catalog and select a song. Behind the scenes, the app first checks Apple Music authorization; if not granted, it shows a primer alert ("Use Apple Music?") explaining why before triggering the system prompt. Once a song is picked, the app auto-applies a "suggested hook" trim (its best guess at a good 10-second segment) and returns to the audio step or to the player editor.

### 6.4 Advanced Trim sheet

Reachable from the Player Editor's Fine Tune Clip section. A more detailed view with finer scrub control. Not used in the Setup Guide.

### 6.5 Roster Preview sheet

Appears when the user imports a roster CSV. Lists the rows about to be imported. Confirm or cancel.

### 6.6 Photo Crop full-screen cover

Triggered after picking a player photo. Pan/zoom/rotate then save.

---

## 7. Audio, Playback, and Fallbacks

### Audio sources

- **Apple Music** — the primary, recommended source. Requires Apple Music authorization. On accounts with an active Apple Music subscription and MusicKit App Service entitlement, Roll Call can play arbitrary positions in full-length tracks. Without that, the app falls back to whatever preview snippet is available.
- **Local audio / video** — files imported from the device, including video files (only the audio track is used). Used when the user prefers their own media or when Apple Music isn't available.
- **Built-in clips** — short crowd reactions bundled with the app. Used both as the General Clips library and as the fallback when a player has no cue.

### Fallback order (per UX Rulebook)

When playback is requested but the configured cue can't fully execute:

1. Intro + Song
2. Song only
3. Intro only
4. Generic cheering (built-in)

Game Day never fails. The user might get a smaller cue than they expected, but never silence or an error dialog.

### Volume Automation

Off by default. When enabled, source-backed Apple Music and Music Library songs use the current device volume as their starting point, then ramp down during the selected fade-out window. Local, generated, built-in, and Announcement Cue files play at their encoded volume because generated local clips already bake in their fade envelope.

---

## 8. Game Day Modes

Set per-team, toggled from the live screen.

- **Announcer Only** — plays only the recorded custom announcer intro. If a player has no custom intro, falls back to a small cheer. Useful for quiet venues or when songs aren't appropriate.
- **Announcer+Song** — plays the announcer intro first, then the song cue after a configurable `pauseAfterAnnouncer` gap. The fullest experience.
- **Song Only** — plays just the song cue, no announcer. Default for users who haven't recorded intros.

The mode is on `Team.session.gameDayAnnouncerMode`, persisted, and survives backgrounding. It is treated as a live decision (it lives in the team's session state, not its setup), and the picker is on the live screen rather than buried in setup, because mode often changes between innings.

---

## 9. Readiness Model — Detailed

Player states:

- **✓ Ready** — has playable audio (song or imported file). This player will work.
- **★ Enhanced** — Ready *and* has a custom announcer recording. Feels celebratory; the app uses this as a discovery surface for the announcer feature.
- **○ Optional** — anything else (photo missing, etc.). Never implies the player is broken.

Team states:

- **🟢 Ready for Game Day** — every player has playable audio.
- **🟡 Some Players Need Audio** — one or more will use fallback. Offers help; never blocks.

Game Day Checks (device-level, separate from player setup):

- Audio route
- Network reachability
- Apple Music authorization & subscription
- Volume Automation (only flagged if user toggled it on)
- Lineup configured (at least one present player)

The model **rejects**:

- Percentage complete
- Bronze/Silver/Gold tiers
- "Player incomplete" / red error states for incomplete-but-playable players

Discovery is preferred over pressure. Announcer intros are surfaced post-success ("Nice! Want to add announcer intros?") rather than during onboarding.

---

## 10. Data, Sharing, and Recovery

### `.rollcall` packages

A `.rollcall` file is a portable archive of a single team: roster, cues, photos, custom announcer recordings, team identity, session state. Created from Settings -> Export Selected Team. Added via Settings -> Add Team from .rollcall Package, or by sending the file to the device (Files, AirDrop, etc.).

Import adds the package as a new team and leaves existing teams unchanged. Imports automatically create a recovery backup first.

### Roster CSV import

Available from Teams → Team Actions menu. Imports name + uniform number rows from a CSV; opens a Roster Preview sheet for confirmation before applying. This is a fast way to seed a roster but does not import audio.

### Recovery

Reached from Settings → Recovery. The screen now leads with **Recently Deleted**, a mixed newest-first list of deleted teams and players. Deleted items stay there for 60 days unless restored or permanently deleted. Team restores are full-fidelity; player restores return to the original team and try to rejoin the prior batting-order position while marking the player present today. If a player's original team is still deleted, the row stays visible and explains that the team must be restored first.

Restore is the primary action. Permanent delete is secondary and confirmed item by item. If some saved media is missing, Roll Call explains what could not be recovered and offers a `Restore What We Can` fallback instead of silently restoring a partial result.

The lower part of Recovery still contains manual **Backups**. Automatic backups are taken before package imports and before restoring from a backup. Only the newest 10 are kept. Backups are for returning to an earlier app state, not for everyday deleted-player or deleted-team recovery.

---

## 11. Explicit Constraints & Non-Goals

Be very cautious when proposing features that step on these lines.

**Will not build:**

- Required user accounts
- Cloud sync (manual `.rollcall` sharing is the substitute)
- Social features (no public profiles, no sharing-network)
- Ads of any kind
- Sports management / stats / scoreboard tooling
- Event production software
- Analytics or play-by-play history
- Remote control or multi-device coordination
- Heavy audio engineering tools (waveforms, per-cue gain, etc. — these are deferred indefinitely)
- Required cloud backups

**Reliability rules:**

- Donations must never affect Game Day reliability or feature access.
- Game Day must always do *something* when tapped — fallbacks are mandatory.

**UX rules:**

- No long tutorial carousels.
- No permission barrage (ask only after the user expressed intent).
- No setup-as-homework feel (no percentages, no checklists styled as required).
- No donation pressure or guilt prompts after the user has invested setup effort.
- No ratings prompt during Game Day.
- Confirm only irreversible actions; prefer recovery over constant confirmations.

---

## 12. Where The Roadmap Points

1.0 is submitted and is intended as the complete free experience. Post-launch direction (from `docs/product/PRODUCT_ROADMAP.md`):

**Near-term (1.x candidates):**

- Team Home (a "what now?" landing screen, currently the Game Day tab serves this role indirectly)
- Improved Clips (custom user clips, sample songs in "Recent")
- Improved Readiness
- Improved Backup/Restore + Recently Deleted
- Improved Photo Editing
- Improved hook-finding (the "suggested" auto-trim heuristic)
- Better sharing convenience
- Improved song selection and clip creation flows
- Adding songs to clips

**Likely future free feature candidates (later):**

- Presentation styles / Game Day visual themes
- Announcer Studio (richer announcer authoring — multiple presets, varied templates)
- Batch editing
- Save Apple Music clip as a local file (currently feature-flagged Experimental)
- Lyric-based song selection
- Multiple intro/song presets per player
- Presentation packs
- Cloud sync (low priority)

**Support framing:**

- Priority order for future feature value: Creativity > Save Time > Pretty > Control.
- Donations may support the app, but must stay optional and calm.
- Never gate the real app.

---

## 13. Useful Mental Models for Planning Conversations

When discussing a proposed change, the following framings tend to lead to good decisions:

- **"Does this help the coach feel ready when they tap Start Game?"** — readiness must always answer yes.
- **"Is this preparation work or live execution work?"** — preparation can be a little tedious; live execution must be smooth and forgiving.
- **"Does this teach setup as homework, or as discovery?"** — Roll Call prefers discovery (reveal features after the user has had a small win) over front-loaded teaching.
- **"Who pays the reliability cost if this is half-set-up?"** — anything user-visible at Game Day must degrade gracefully, never break.
- **"Does this preserve user ownership of their team?"** — import/export, recovery, backups, and the "no required account" stance all support a coach feeling like they own their roster.
- **"Is this iPhone-first?"** — iPad and other targets are not currently in scope.

When uncertain, the developer's preferred resolution is to surface the conflict, present options with tradeoffs, and wait for approval — not to build silently.

---

## 14. Things This Document Does Not Cover

For deeper specifics, the live docs in the repo are:

- `docs/product/NORTH_STAR.md` — the one-page product philosophy
- `docs/product/PRODUCT_SCOPE.md` — release boundaries and donations/support rules
- `docs/product/UX_RULEBOOK.md` — onboarding, readiness, missing-data, permissions, confirmations, recovery, ratings
- `docs/product/READINESS_MODEL.md` — the detailed readiness reasoning
- `docs/product/PRODUCT_ROADMAP.md` — what is in 1.0, 1.x candidates, future free features, support options, non-goals
- `docs/product/APPEARANCE_RULES.md` — Light/Dark/Live appearance rules
- `docs/product/ARCHITECTURE_GUARDRAILS.md` — technical guardrails (the user is unlikely to ask an AI to discuss these without specifically requesting it)
- `docs/WHERE_WE_STAND.md` — current implementation status snapshot
- `docs/DECISIONS.md` — append-only decision log

If a planning discussion runs up against a question this overview can't answer, ask the developer whether one of the above is the right source rather than guessing.

---

## Appendix: A Suggested Place To Add Screenshots Later

This document is currently text-only because most AI tools cannot follow image references reliably. If you (the developer) want to enrich it with simulator screenshots for human readers, the most useful captures would be:

1. The Welcome screen (full-screen launch image with "Let's Get Started")
2. The Setup Guide's milestone breadcrumb on each of its four states (Team active, Player active, Audio active, Lineup active, all-complete handoff)
3. The Game Day live screen with a Now Batting hero and the player grid
4. The Player Editor sheet at full scroll (Identity → Song Cue → Fine Tune → Announcement Cue)
5. The Lineup Editor sheet showing the drag handles and Present toggles
6. The Readiness tab with at least one player in each state (Ready, Enhanced, Optional)
7. The Teams tab with multiple teams in the list

These can be inlined as `![alt](path)` references next to the relevant section headers.
