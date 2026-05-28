# Audit Remaining Issues

Created during the post-audit fix pass so the remaining work is not dependent on chat history.

Source of truth notes:
- The original full audit report was not saved in the repository before fixes started.
- Closed items below are derived from `docs/AUDIT_FIX_NOTES.md` and the current uncommitted hotfix worktree.
- Remaining items below are repo-backed from `docs/WHERE_WE_STAND.md`, current product docs, and audit follow-up context.
- Treat this as the durable triage board going forward. Update it when an item is fixed, deferred, or intentionally left alone.

## Current Fixes Already In This Hotfix

These are believed handled in the current uncommitted `hotfix/quickfixes` worktree, pending final review/commit:

1. **Unreadable saved state no longer silently resets without recovery.**
   - Status: Fixed in current hotfix.
   - Notes: Launch now preserves a recovery copy of unreadable `state.json` before starting from empty state and surfaces a warning.

2. **Rapid app-state writes cannot let an older queued snapshot overwrite newer state.**
   - Status: Fixed in current hotfix.
   - Notes: Persistence now uses a serialized, versioned writer.

3. **Missing stored local or built-in cue files no longer block Game Day fallback.**
   - Status: Fixed in current hotfix.
   - Notes: Game Day validates playable local/built-in cue assets before selecting them and can fall back to `Small Cheer`.

4. **Shared media assets are protected when duplicated players or teams reference the same files.**
   - Status: Believed fixed in current hotfix.
   - Notes: Clearing, replacing, or removing one player should no longer delete an asset still referenced by another player.
   - Follow-up: Verify the current implementation covers local song cues, photos, custom announcer recordings, and generated announcer assets before closing.

5. **Backup restore is confirmed before replacing current app data.**
   - Status: Fixed in current hotfix.
   - Notes: Restore asks for confirmation and still creates a safety backup first.

6. **Closing Player Editor with unsaved edits is confirmed.**
   - Status: Fixed in current hotfix.
   - Notes: Protects trim, identity, cue, and other edits that have not been saved.

7. **Package import wording now says imports add a new team.**
   - Status: Fixed in current hotfix.
   - Notes: Reduces confusion that import might replace existing teams.

8. **Package imports reject unsafe asset references.**
   - Status: Fixed in current hotfix.
   - Notes: Import now reads simple asset file names from the package asset folder instead of trusting arbitrary relative paths.

9. **Game Day player grid tiles preserve button accessibility traits.**
   - Status: Fixed in current hotfix.
   - Notes: Tiles keep custom VoiceOver labels, values, and hints while exposing button behavior.

10. **Release-facing version docs were aligned.**
    - Status: Fixed in current hotfix.
    - Notes: Release-facing docs now agree on version `1.0.1` build `54`.

## Remaining Issues To Discuss

No active remaining issues are queued for this audit pass. The only open items are deferred/accepted risks below.

## Deferred / Accepted Risk

- **Issue 12: Fixed 3-column Game Day grid may be cramped on small screens or large text.**
  - Status: Deferred / accepted risk.
  - Reason: Game Day layout is product-sensitive and owner-protected; adaptive grid work should wait for a dedicated visual/accessibility pass rather than this audit hardening pass.
  - Future check: Test the smallest supported iPhone size with large accessibility text and a roster with duplicate/long names.

- **Issue 14: No automated tests found for the highest-risk flows.**
  - Status: Deferred / accepted risk.
  - Reason: Adding a test target is useful engineering-quality work, but it is project-structure work and outside this low-risk audit hardening pass.
  - Future check: Start with focused tests for state decode, package import/export, backup restore, missing-file playback fallback, and queued incoming `.rollcall` files.

Priority Order
Discuss First
Discuss Soon
Defer / Optional
Issue 12: Deferred / accepted risk
Issue 14: Deferred / accepted risk


## Working Rule

Do not fix these directly from this document without a discussion decision. Go one issue at a time and mark each as fixed, deferred, accepted, or needs more investigation.
