# Roll Call Open Issues

This document records known, unfixed issues that need a deliberate future pass. An issue listed here is not approved for implementation. Current implementation and the stabilization audit remain authoritative; this file is a durable handoff for work that is intentionally being deferred.

## [P1] Audio-session interruptions have no state or reactivation recovery

**Area:** Playback  
**Confidence:** Needs validation  
**Status:** Open. No implementation is approved by this note.

### Summary

Roll Call does not currently model external audio-session interruptions or media-service resets. A phone call, Siri, an alarm, Bluetooth/headphone route loss, or a media-services reset can stop playback while the app still believes a cue is active. The next player tap can then be interpreted as “Stop” rather than “Play,” requiring a second tap or leaving Game Day without audio.

### Current evidence

- `AppModel.observeReadinessInputs` observes `AVAudioSession.routeChangeNotification` and output-volume KVO for readiness refresh only.
- The app has no handling for `AVAudioSession.interruptionNotification`, interruption type/options, or `AVAudioSession.mediaServicesWereResetNotification`.
- `CuePlaybackEngine` owns `activeCueID` and clears it through scheduled stop, cue-begin, and explicit-stop paths, not from actual audio-session interruption callbacks.
- `CuePlaybackEngine.play` treats a tap on the same active cue as Stop and returns a cancelled result. If an interruption leaves `activeCueID` stale, the first recovery tap can stop stale state instead of replaying.
- There are no interruption or route-loss tests.

### Historical attempted fix and rollback

An earlier interruption-handling integration was rolled back. It caused Game Day songs to stop while announcements continued playing. That regression violated the live-playback invariant, so the established playback path was restored.

Do not reintroduce that design or infer that a compile/build pass proves interruption recovery is safe. Any replacement must be device-tested before acceptance.

### Why this matters

Audio interruptions and route changes are normal during a live game. Stale playing state, a required two-tap restart, failure to reactivate the session, or broken volume restoration can make Roll Call appear unreliable in front of an audience.

### Safer future direction

Design one app-owned interruption coordinator or testable interruption state reducer before changing playback behavior. The design should:

- cancel stale timers/progress and clear or explicitly mark active playback when an interruption begins;
- preserve only the minimum intent needed for an honest UI;
- reactivate the audio session when permitted after interruption end;
- never automatically resume a walk-up cue after a phone/Siri interruption without explicit product approval;
- make the next player tap start the intended cue immediately;
- rebuild affected playback controllers after a media-services reset;
- reconcile route loss safely while keeping readiness refresh separate from live playback state.

### Guardrails

- Preserve tap-to-stop for a genuinely active cue.
- Preserve the existing fallback chain: intro + song, song only, intro only, generic cheering fallback.
- Do not add unrelated modal UI, rating, support, repair, or permission prompts during Game Day.
- Do not add automatic playback after an interruption without a separate owner decision.
- Do not change bundle identifiers, stored data, media ownership, or the app’s iOS floor as part of this issue.
- Keep live playback ahead of background preparation and maintenance work.

### Acceptance criteria

- When interruption begins, the UI no longer presents a stopped cue as actively playing.
- After interruption ends, one explicit player tap starts the intended cue.
- Existing tap-to-stop behavior remains correct for cues that are genuinely active.
- The fallback chain remains available when the preferred media cannot play.
- Phone/Siri interruption, alarm-like interruption, Bluetooth/headphone removal, and media-services reset do not leave unrecoverable playback state.
- Volume automation and restoration do not inherit stale or incorrect state.
- Game Day is not interrupted by unrelated prompts or repair surfaces.

### Required engineering verification

Add deterministic reducer/state tests for:

- interruption begin and end;
- interruption options that permit or do not permit resumption;
- stale completion/callback protection;
- route loss and route return;
- media-services reset and playback-controller reconstruction;
- one-tap restart after recovery;
- preservation of normal tap-to-stop behavior;
- fallback behavior after recovery.

### Required device verification

On a physical device, test interruptions during each meaningful playback phase:

- announcement intro;
- local song;
- Apple Music song;
- preview playback;
- fade-in/fade-out or volume automation;
- Bluetooth/headphone removal and return;
- media-services reset if it can be induced safely.

For every case, verify the visible playback state, one-tap restart, no unexpected auto-resume, fallback behavior, audio-session reactivation, and volume restoration. Use disposable/test data and do not treat simulator-only results as owner acceptance.

### Source record

Full audit context: [SOL_ROLL_CALL_1.3_STABILIZATION_AUDIT.md](../SOL_ROLL_CALL_1.3_STABILIZATION_AUDIT.md#p1-audio-session-interruptions-have-no-state-or-reactivation-recovery).

