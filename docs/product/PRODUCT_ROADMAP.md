# Roll Call Future Product Roadmap

This roadmap replaces the earlier 1.x / Later list with a clearer release sequence. It keeps the same product philosophy: Roll Call should remain a complete, free Game Day app first. Later paid or optional features may add delight, presentation polish, or time-saving tools, but they must not gate reliability, basic team ownership, or the ability to run Game Day.

## Guiding priorities

1. **Game Day must remain reliable.** Fallback audio, clear readiness, and recoverability matter more than novelty.
2. **Fix the current weak point next.** After practical low-risk improvements, the next major focus is the song selection and audio setup experience.
3. **Do not reinvent the wheel twice.** If a feature belongs in the larger Game Day revamp, do not build a fully designed temporary interface that will immediately be replaced.
4. **Stage improvements where it makes sense.** Small cleanup can ship before a larger redesign, but larger model/UI changes should be grouped coherently.
5. **Keep ownership free.** Import/export, manual sharing, backup/restore, core audio setup, and Game Day reliability stay free.

---

## 1.1 - Polish & Practical Improvements

**Purpose:** Ship low-risk improvements that make the existing app feel safer, cleaner, and more useful without delaying the larger audio work.

This release should not become a dumping ground for every easy idea. It should remain focused on practical improvements that do not require the Song Select or Game Day revamps.

### Target items

- **Public changelog / What’s New**
  - Show plain-language update notes once after app update.
  - Avoid nagging users or interrupting Game Day.
  
- **Team Color as App Accent**
  - Uses Team Color as accent on multiple pages.
  - Works in Light and Dark mode.

- **Recovery / Recently Deleted**
  - Add recovery for deleted teams and/or deleted players if implementation is straightforward enough for this release.
  - If this becomes larger than expected, keep it as an early 1.x trust feature rather than forcing it into 1.1.

- **Minor pre-revamp Game Day cleanup**
  - Save space.
  - Improve clarity.
  - Avoid changes that will be thrown away during the later Game Day revamp.

- **Finish/expand built-in crowd clips**
  - Replace any remaining weak placeholder clips with real built-in audio clips.
  - Add useful crowd/hype sounds such as applause, cheers, and simple fallback moments.

- **Keep screen awake option**
  - Add a setting to prevent the screen from sleeping during Game Day.
  - Should be opt-in or clearly explained if it affects battery life.

- **Playlist creation from team songs**
  - Promote from experiment if stable.
  - Let users create a playlist from team songs as a convenience feature.
  - This is included in 1.1 because it already exists experimentally.

- **Rating request**
  - Add only if it is polite and well-timed.
  - Never show during Game Day.
  - Prefer showing after repeated successful use.

- **Better .rollcall file icon / identity polish**
  - Refine if easy.
  - Do not spend significant time here before audio improvements.

- **Apple Music offline warning, if easy**
  - Add a simple warning if it can be done without waiting for the full Song Select revamp.
  - If it requires deeper picker/workflow changes, move it to 1.2.

- **Donation option - research or lightweight implementation**
  - Include as a roadmap item, but mark as tentative.
  - May move, change, or be removed based on App Store rules, product tone, and further discussion.
  - Should not feel like a paywall or guilt prompt.

### Explicitly not in 1.1

- Full Song Select revamp
- Full Game Day revamp
- Team Home
- Full Clips redesign
- Between-inning songs
- Plus subscription/paywall architecture
- Cloud sync

---

## 1.2 - Song Select & Audio Setup Revamp

**Purpose:** Fix the weakest part of the app: selecting, previewing, trimming, and understanding audio.

This should be the next major feature release after 1.1. If 1.1 threatens to slow this down significantly, keep 1.1 smaller rather than delaying 1.2.

### Target items

- **Improved song selection process**
  - Make it easier to choose the right source.
  - Reduce confusion between Apple Music, local/imported files, built-in clips, custom clips, and reusable song clips.

- **Better Apple Music picker**
  - Improve permissions, search, selection clarity, and preview/full-track expectations.
  - Make Apple Music behavior feel intentional rather than mysterious.

- **Pick from Apple local Music library / downloaded Apple Music**
  - Treat as a real intended feature.
  - Test experimentally first if needed, but plan it as part of the user-facing audio revamp.
  - This is distinct from importing audio files from Files, which already exists.

- **Local/imported audio improvements**
  - Polish the existing Files-based audio import flow.
  - Make the relationship between imported audio and player audio clearer.

- **Improved hook finding**
  - Help users find the best walk-up moment in a song.
  - Keep the tool simple; do not turn Roll Call into a full audio editor.

- **Cue point UX improvements**
  - Make start point, preview, trim, and save behavior easier to understand.
  - Reduce accidental wrong-start moments.

- **Advanced trim polish**
  - Refine existing trim/cue tools.
  - Keep the feature focused on walk-up usage, not heavy editing.

- **Better waveform / graph**
  - Add a more useful visual aid for finding the right section of a song.
  - “Waveform” does not need to be a full pro-audio waveform if a simpler graph-like visualization solves the user problem.

- **Album art**
  - Show album art when available during song selection and preview.
  - Use it to improve confidence that the correct song was selected.

- **Better preview behavior**
  - Make it clearer what is being previewed.
  - Distinguish preview clips, full-track playback where available, local audio, and saved clips.

- **Apple Music offline / availability language**
  - Add honest warnings about streaming/offline limitations.
  - Avoid overpromising that Apple Music content will always work offline or without network access.

- **Improved clip creation process**
  - Create a reusable source -> section -> preview -> save/use flow.
  - This flow should be shared by the Clips screen when creating custom clips.

- **Clips screen: Add Clip entry point**
  - Add “Add Clip” from the Clips screen.
  - Reuse the improved song selection / cue editor flow.
  - Store custom clips distinctly from built-in clips and player audio so they can be displayed differently in the later Game Day revamp.

### Possible but not required for 1.2

- **Make Local Copy of Apple Music selection**
  - Treat as related but higher-risk.
  - This overlaps with the older “Save Apple Music clip as local file” roadmap item.
  - Do not ship unless platform behavior, App Store suitability, and user expectations are clear.

- **Sample songs in Recent**
  - Keep as a later enhancement unless it naturally falls out of the new picker design.

### Explicitly not in 1.2

- Full Game Day revamp
- Team Home
- Full Plus monetization
- Heavy audio engineering tools
- Per-cue gain controls
- Full DAW-style waveform editing
- Lyrics-based song selection unless it unexpectedly becomes easy and clearly useful

---

## 1.3 - Game Day & Clips Revamp

**Purpose:** Redesign Game Day enough to make live use easier without making it complicated. The central idea is easier access to players, sound clips, non-player song clips, and possibly between-inning songs from one screen or from a much more efficient live workflow.

This should include light object-model cleanup so the app stops blurring together player audio, built-in clips, custom clips, song clips, and special-purpose audio.

### Target items

- **Game Day revamp**
  - Medium-size redesign.
  - Improve access to players, quick clips, reusable song clips, and live actions.
  - Do not turn Game Day into a complex production console.

- **Minor object-model cleanup**
  - Clearly distinguish:
    - Player audio
    - Built-in sound clips
    - Custom user clips
    - Custom song clips
    - Between-inning songs, if included
    - Special entries such as team entrance, coach announcement, warmup, or closing music, if included
  - Keep compatibility/migration safe.

- **Improved Clips model**
  - Treat built-in clips, custom clips, and custom song clips as related but distinct.
  - Avoid creating confusing duplicate terms in the UI.

- **Custom user clips**
  - If not fully completed in 1.2, finish here.
  - Custom clip creation may begin earlier, but the live-use UI belongs in this revamp.

- **All Clips library**
  - One place for built-in clips, custom sounds, and custom song clips.
  - The library can organize clips by type while still feeling like one feature.

- **Game Day quick clips**
  - Decide how many clips should be available during live use.
  - Consider pinned/favorite clips if the full library would be too much for Game Day.

- **Pinned/favorite clips**
  - Optional, but likely useful if Game Day needs a smaller quick-access set.
  - Keep this as part of the revamp rather than a separate mini-feature unless it proves trivial.

- **Use a clip as player audio**
  - Allow a compatible general clip to be assigned to a player when reasonable.

- **Convert/move player audio into Clips**
  - Provide a Settings-side utility if needed.
  - This should support moving/reusing compatible audio between categories without corrupting the model.
  - Prefer duplicate/reuse over destructive moves when safer.

- **Duplicate clip**
  - Include if it is a safer or simpler alternative to move/convert.

- **Jump to player improvements**
  - Current functionality exists but needs a stronger live-use design.
  - Do not bury this several clicks deep.

- **Lineup sheet/popup reconsideration**
  - Keep current compromise if it works.
  - Only redesign if it supports the broader Game Day revamp.

- **Between-inning songs**
  - Include here if there is a natural place in the redesigned Game Day model.
  - Do not build a fully designed standalone interface in 1.1/1.2 if it will be replaced here.

- **Special entries**
  - Consider team entrance, coach/team announcement, warmup, and closing music.
  - Include only if they fit cleanly into the same model as other non-player audio.

- **Ongoing presentation polish**
  - Improve live-screen clarity, spacing, hierarchy, and tap confidence.
  - Maintain outdoor readability.

### Likely not in 1.3

- Full Team Home if it grows beyond a light entry point
- Plus presentation packs
- AI-generated announcers
- Cloud sync
- Remote control

---

## 1.4 - Team Home, Team Identity, and Setup Flow

**Purpose:** Give the selected team a clearer home base after the audio and Game Day foundations are stronger.

Team Home should be a light hybrid, not a heavy dashboard. It should help the user understand the selected team and quickly get to the next useful action.

### Target items

- **Team Home**
  - Selected team identity.
  - Big Game Day entry point.
  - Readiness/status summary.
  - A few setup/action cards.
  - Avoid becoming a giant dashboard.

- **Navigation refinement**
  - Re-evaluate tab order and destination structure after the Game Day revamp.
  - Current six-tab structure can stay until there is a clear reason to change it.
  - Team Home may make some current navigation feel redundant or clearer.

- **Team identity: logo**
  - Add logo support if still desired.
  - Not strategically essential, but likely user-pleasing and reasonably easy.

- **Presentation-level team identity**
  - Make team colors, logo, and photos show up better in live/presentation contexts.
  - Keep readability and contrast above visual flair.

- **Accent color usage**
  - Already largely addressed for 1.1-era builds, but continue refining if needed.

- **Light Mode / Dark Mode polish**
  - Already largely done, but continue fixing edge cases.

- **App icon tweak**
  - Later polish item if worthwhile.

- **Sample team**
  - Possible helper for screenshots, demos, and user orientation.
  - Include only if it clearly helps onboarding, screenshots, or testing.

- **Tips and Tricks panel**
  - Possible lightweight help feature.
  - Keep optional and non-intrusive.

- **Archive**
  - Only if team clutter becomes real.
  - Do not build just because it is a conventional app feature.

---

## 1.5 - Power Tools and Advanced Convenience

**Purpose:** Add time-saving tools for heavier users once the core audio and Game Day flows are stronger.

These features are useful, but they should not come before fixing the main audio pain point.

### Target items

- **Batch editing**
  - High-value power feature.
  - Possible Plus candidate, but basic ownership and safety should remain free.

- **Batch player updates**
  - Numbers, colors, photos, cue clearing, present/absent, defaults, etc.

- **Batch audio operations**
  - Assign fallback audio, clear cues, duplicate settings, or apply audio-related defaults.

- **Better roster import/update flow**
  - Existing import largely works.
  - Improve only if there is a clear user pain point around updating existing players.

- **Better sharing convenience**
  - Basic manual sharing/import/export stays free.
  - Additional convenience features can be evaluated carefully.

- **Easier sharing as a power feature**
  - Potentially premium if it saves time without restricting ownership.
  - Danger zone: never make basic import/export feel paywalled.

- **Support / diagnostic bundle**
  - Existing debug tooling largely covers this, but release-version support export may be useful.
  - Exclude copyrighted media by default.
  - Include app version, readiness/playback diagnostics, package/import diagnostics, and relevant logs if appropriate.

- **Runtime diagnostics improvements**
  - Continue improving playback/readiness/package/import diagnostics.

- **Schema/version migration visibility**
  - Add only if package evolution or migrations make this necessary.

---

## 1.6 / 2.0 - Monetization, Plus, and Larger Experiments

**Purpose:** Explore optional paid features only after the free app feels complete and trustworthy.

The exact version number depends on timing and product strategy. These should not block the 1.2 audio revamp or the 1.3 Game Day revamp.

### Donation / support option

- **Donation option**
  - Possible stopgap before fuller monetization.
  - Research App Store rules, product tone, and whether this creates pressure or confusion.
  - May move earlier, change form, or be removed.

### Strong Plus candidates

- **Presentation styles**
  - Different live visual treatments.
  - Free baseline presentation style must remain strong.

- **Game Day styles**
  - Alternative Game Day modes/treatments.
  - Must not affect reliability.

- **Announcer Studio**
  - Advanced announcer intro creation.
  - Keep basic announcer intros available in the free app.

- **Batch editing**
  - Potential premium time-saver.
  - Do not gate basic team ownership.

- **Easier sharing**
  - Only premium if it is clearly extra convenience.
  - Basic import/export remains free.

- **Premium presentation packs**
  - Clean monetization candidate if the free app remains polished.

### Possible Plus / future candidates

- **Multiple intro presets**
  - Same family as announcer template options.
  - Could be part of Announcer Studio.

- **Multiple song presets**
  - Let a player have multiple saved song/audio options.

- **Advanced templates**
  - Event/game templates, special announcements, or presentation templates.

- **Playlist creation from team songs**
  - Already planned for 1.1 as a practical feature because it exists experimentally.
  - Could still have future premium expansions if appropriate, but the basic version should not be moved here if it remains simple.

- **Make Local Copy of Apple Music selection / Save Apple Music clip as local file**
  - Treat these as the same general idea.
  - Platform/legal/App Store risk.
  - Do not ship until tested and clearly acceptable.

- **Lyric-based song selection**
  - Unlikely near-term.
  - Possible future discovery feature, but not core.

- **Cloud sync**
  - Possible but low priority and high complexity.
  - Avoid unless there is strong evidence it is needed.

- **AI-generated announcers**
  - Desired long-term idea, but likely a rabbit hole to make good, affordable, and reliable.
  - Revisit after larger pain points are fixed.

### Weak / not currently compelling

- Analytics/history
- Remote control
- Audio engineering tools
- Heavy waveform editing
- Per-cue gain controls

---

## Explicit Non-Goals

Do not build unless the product strategy changes substantially:

- Social features
- Public profiles
- Public team/player profiles
- Ads
- Required accounts
- Required cloud
- Required cloud backup
- Sports management / stats platform
- Scoreboard system
- Event production software
- Social network
- Reliability paywalls
- Premium-gated Game Day success
- Heavy audio engineering tools

---

## Ongoing / Internal

These items are not headline release features but should remain part of responsible development.

- Experimental Features screen
- Feature flag cleanup
- Environment gates / developer tools
- Debug-only tools kept out of normal user flows
- Runtime diagnostics
- Package/import/export safety
- Migration safety
- App Store suitability notes for risky experiments
- Continued backup/restore safety improvements
- Continued sharing/import conflict handling improvements
- Continued readiness clarity improvements
