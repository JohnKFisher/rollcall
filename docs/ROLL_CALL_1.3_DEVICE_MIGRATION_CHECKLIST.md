# Roll Call 1.3 Physical-Device Migration Checklist

Use a source iPhone and a receiving iPhone with a normal production-like App Store/TestFlight build. Record app-level results separately from behavior controlled by Apple's migration infrastructure.

- [ ] Configure realistic data on the source iPhone: multiple teams, players, names/numbers, lineup order, photos/crops, settings, Apple Music selections, local/user-owned audio, and Announcement Cues.
- [ ] Make last-minute edits, then open/close the relevant editor or otherwise confirm Roll Call has reached durable state.
- [ ] Perform a normal Apple device migration or restore onto the receiving iPhone.
- [ ] Confirm all teams, players, names/numbers, lineup configuration, settings, and selected Game Day context remain present.
- [ ] Confirm photos, working photo sources, and crop geometry remain present and usable.
- [ ] Confirm local/user-owned audio and Announcement Cues remain present and playable.
- [ ] Confirm Apple Music selections remain represented with their original catalog identity and metadata, even when the receiving device needs re-resolution.
- [ ] Confirm readiness is recalculated for the receiving device rather than copied as trusted device state.
- [ ] Confirm device-local identity/qualification belongs to the receiving iPhone.
- [ ] Exercise Game Day and verify the established fallback chain when ideal media is unavailable.

App-level evidence includes state/configuration preservation, repairable unresolved Apple Music selections, local media behavior, readiness requalification, and Game Day behavior. Apple's migration/restore service determines whether the app container is transferred; this checklist does not prove that service's behavior in general.
