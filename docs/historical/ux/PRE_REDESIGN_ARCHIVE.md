# Pre-Redesign UX Archive

Status: historical snapshot

The pre-redesign package captured the app as version 0.4.5, build 9, on 2026-05-14. It was created to map the existing UI before a redesign and to identify behavior that could not be changed casually.

## What the snapshot was protecting

- cue playback timing and fallback behavior;
- Apple Music capability and permission handling;
- persistence, lineup state, and app switching;
- `.rollcall` import/export compatibility;
- custom announcer recording and storage;
- the distinction between visual redesign and risky data or media changes.

The snapshot's most useful lesson was that the dangerous parts of a redesign were not necessarily the most visible ones. Game Day playback, Apple Music state, package compatibility, persistence, and media ownership needed stronger protection than cosmetic polish.

## What is no longer current

The baseline inventories, component catalog, screen-by-screen descriptions, old bug list, and redesign strategy described an earlier code and product state. They are not current implementation guidance. Current behavior belongs in [Application Overview](../../product/APP_OVERVIEW.md), [UX Rulebook](../../product/UX_RULEBOOK.md), and [Where We Stand](../../WHERE_WE_STAND.md).

The detailed baseline files are retired from the active archive. Their point-in-time snapshot remains recoverable through Git history.
