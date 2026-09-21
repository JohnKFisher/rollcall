# Roll Call 1.3 Persistence Hardening

Roll Call 1.3 continues to use local JSON and file-backed storage under the app's Application Support directory:

- `state.json` is authoritative portable app state.
- `Assets/` contains imported local audio, photos, and Announcement Cues.
- `GeneratedClips/` contains rebuildable derived audio where available.
- `Snapshots/` contains local rollback snapshots of state; referenced media is not copied into a snapshot.
- Apple Music catalog IDs, metadata, preview URLs, and Music Library persistent IDs represent user intent and device-dependent resolution hints, not portable audio.
- Device qualification and readiness observations are re-established for the current device and environment.

`AppStatePersistenceCodec` is the single AppState compatibility seam. It performs ordered top-level migrations, leaves team-package schema 9 independent, and rejects future or malformed state before normal lifecycle work begins. Schema-10 state remains readable; new state uses schema 11 for the device-qualification field.

Unreadable or future primary state is preserved byte-for-byte before recovery. If `state.json` is missing while meaningful Roll Call files remain, Roll Call enters the existing recovery launch flow, leaves those files untouched, and does not speculate about their contents. Startup generated-clip cleanup audits rather than deletes; explicit cleanup remains available from Recovery.

This document does not claim anything about Apple's Quick Start, iCloud Backup, or physical device-restore implementation. Those behaviors require owner validation on real devices.
