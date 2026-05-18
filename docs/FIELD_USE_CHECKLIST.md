# Roll Call Field Use Checklist

Use this checklist for the `0.6.0` build `19` real-use pause. The goal is not to keep coding during the pause; it is to notice what actually matters when Roll Call is used around a real team.

## Before the First Real Use

- Install the current `0.6.0` build `19` app on the actual field device.
- Confirm the device can launch Roll Call without Xcode attached.
- Confirm the selected team is the team you intend to use.
- Open Settings and create a manual backup.
- Export a `.rollcall` package for the selected team and keep it somewhere easy to find.
- If another device may be used, AirDrop or share that `.rollcall` package and confirm it imports.

## Team Setup Smoke Pass

- Open Players and confirm every active player is present.
- Confirm player names, numbers, and photos are recognizable enough for field use.
- Confirm today's lineup order matches the real batting order.
- Use the A-Z or number sort only if you actually want to overwrite the current manual order.
- Mark absent players as not present before Game Day.

## Audio Smoke Pass

- Open the readiness dashboard and check the cue warnings before the game.
- Spot-check a few players with Apple Music cues.
- Spot-check at least one player with a custom Announcement Cue, if any are configured.
- Confirm the fallback cheer behavior is acceptable for players without song cues.
- If using full-song Apple Music, test one cue with a non-zero trim start.
- If using fade-out automation, test one cue with the setting on and one with it off.
- Confirm the current audio route is the speaker or external output you expect.

## Game Day Smoke Pass

- Open Game Day before the first batter.
- Confirm the announcer mode is the intended mode: `Announcer Only`, `Announcer+Song`, or `Song Only`.
- Tap the first batter and confirm playback starts quickly enough.
- Use `Next` and `Prev` once before the game starts to confirm the lineup is moving as expected.
- Tap an active player again and confirm playback stops clearly.
- Check the screen in bright conditions and note any unreadable areas.

## During Real Use

- Write down only field-relevant friction, not every possible improvement.
- Note whether the problem happened once or repeatedly.
- Capture the exact player, cue type, announcer mode, and audio route when audio behavior is wrong.
- If import/export or backup behavior seems risky, stop and make a fresh manual backup before experimenting.

## After Each Use

- Create a manual backup.
- Export the team package if meaningful roster, lineup, photo, or cue changes were made.
- Write a short note with the top three issues that actually affected field use.
- Separate must-fix blockers from polish wishes.

## Do Not Chase During the Pause

- Waveforms and per-cue gain.
- New fallback clip selector.
- New Apple Music backend experiments.
- Broad UI redesign.
- Any new Game Day behavior unless real use proves the current behavior is blocking.
