# Public Changelog 1.2

## Version 1.2

Roll Call 1.2 is a major audio setup update. It makes choosing, previewing, trimming, saving, sharing, and repairing walk-up songs clearer and safer, while adding team-specific Custom Clips for quick live-use song cues.

### Song Picking And Clip Editing

- Song selection now opens Apple's familiar Music Library picker by default. Apple Music search and file import remain available as separate choices, and all three paths continue into the same clip editor.
- Choosing a song or imported file now opens a draft editor first. A player's existing Game Day song is not replaced until Save is tapped.
- The new Make Your Clip editor includes a draggable song window, preview, clip length choices up to 20 seconds, exact Start/Length/Fade Out controls, and clearer save results.
- New song clips now start at 12 seconds by default, remember later length choices, and recommend 10-12 seconds for game pace.
- When Roll Call can read the selected audio, the clip editor can show an audio shape and moving preview playhead to make finding the right moment easier. Songs that cannot be inspected use a clear placeholder instead.
- Album art appears during song picking when available.
- The Setup Guide now uses the same song choices and Make Your Clip editor as Player setup, so first-time audio setup and later edits work the same way.

### Safer Song Choices

- Roll Call now hides explicit Apple Music search results by default and asks for confirmation before using explicit songs selected from the Music Library.
- When explicit filtering is off, explicit Apple Music results are labeled. The filter also applies to recent Apple Music selections.
- Existing saved songs and imported files are not changed by the explicit-song setting.

### Custom Clips

- Added team-specific Custom Clips to the live Clips page for quick song cues that are not tied to a player.
- Built-in Sound Effects and Custom Clips are now separated. Sound Effects stay in a compact live row, and Custom Clips appear as ordered team-specific clips.
- Custom Clips are tap-to-play during live use. Adding, editing, reordering, and deleting Custom Clips happen behind an explicit Edit action.
- Player Songs and Custom Clips can be copied into each other through Use Existing Clip. Each copy is independent, so later edits or deletion never silently change the original.
- Deleted Custom Clips stay in Recently Deleted for 60 days and restore to their original team and saved position when possible. Player Songs copied from them remain unchanged.
- Custom Clips, their order, and local audio when available now travel in team exports and backups. Imported teams keep unavailable Custom Clips in place and route them toward repair.
- The Clips page has been tightened up with sound-specific icons, a denser Custom Clips layout, clearer active-playback highlighting, and an Edit button placed with the Custom Clips it manages.

### Clearer Readiness, Sharing, And Repair

- Song readiness now distinguishes Ready on Any Device from Ready on This Device, with tap-to-explain details for playback, Apple Music, and team exports.
- Before creating a `.rollcall` team package, Roll Call previews how many Player Songs and Custom Clips will travel as local audio, remain Apple Music links, are still preparing, or need repair.
- After importing a team, Roll Call explains which Player Songs and Custom Clips arrived ready, which depend on Apple Music, and which saved choices need repair on this device.
- Imported Apple Music-linked songs now check this device's Music access automatically when possible, so import results can show ready, unavailable, or still needing permission.
- When an imported song or clip cannot play on this device, Roll Call preserves the saved choice and routes it toward repair instead of silently dropping it.
- Importing a team no longer rejects the whole team or drops an identifiable song choice because one local audio file is missing.
- Roll Call can prepare a local playback clip when iOS makes the selected audio readable. When that is not available, Apple Music-linked songs can still play from their original source.
- Apple Music songs may still depend on Apple Music availability, subscription status, network conditions, or what is already stored on the device. Roll Call does not control Apple Music offline downloads or promise that every Apple Music song can become a local clip.

### Game Day And Clips

- Game Day and Clips can now be switched with a deliberate horizontal swipe, with a small visual nudge and light haptic feedback. Playback continues uninterrupted whether coaches swipe or use the tab bar.
- The swipe shortcut is limited to the two live surfaces and stays disabled during modal, edit, import, and prompt flows.
- Song and Custom Clip preparation can continue carefully while Game Day or Clips is open, but waits until live playback is idle so tap-to-play sounds stay responsive.

### Fixes And Reliability

- Apple Music and Music Library fades now end at the selected clip endpoint, matching locally prepared clips more closely.
- Volume Automation now applies only to Apple Music playback where Roll Call cannot bake the fade into a local clip. Local, prepared, built-in, and Announcement Cue files play at their saved volume without extra runtime fading or volume resets.
- Music Library songs now preview through the exact selected library item, preserving chosen start times more reliably.
- Apple Music searches with no matching songs now show the normal no-results state instead of incorrectly reporting that search is unavailable.
- Apple Music search no longer shows Search Unavailable: Cancelled when newer typing replaces an in-progress search.
- Import Audio or Video now opens the Files browser directly, and cancelling returns cleanly to the Player Editor.
- Clip editor fixes: moving the selected window stops active preview first, the full waveform rail is draggable, changing clip length keeps the same song start, and selecting the full available clip length no longer crashes.
- Closing an unchanged Player Editor no longer shows a discard warning just because song details or readiness refreshed in the background.
- Apple Music-based Custom Clips no longer bounce back to Preparing after Roll Call has settled their availability on this device.
- Fixed a crash that could occur during Apple Music library availability checks while moving between setup screens.
- Edited Player Songs and Custom Clips no longer play or export an older generated clip while the updated selection is being prepared.
- Editing, copying, or duplicating a song with a prepared local clip now keeps the original song and timing as the editable source.
- Roll Call now removes only generated clips it can prove are unused, and skips cleanup when preparation or storage state is uncertain.
- Existing teams and older `.rollcall` files migrate automatically into the richer 1.2 song model when opened.

### Polish

- Settings now has a separate About Roll Call screen for version, feedback, release notes, rating/support, and credits. Team sharing and guided setup are grouped together, and Volume Automation now lives with Music & Playback.
- Refreshed the app icon and exported `.rollcall` team file icons to match the latest Roll Call artwork.
- Team color polish: active teams are easier to spot in the picker, and filled buttons choose readable text colors for light/dark team accents.
