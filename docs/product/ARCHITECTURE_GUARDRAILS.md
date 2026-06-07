# Roll Call Architecture Guardrails

## State Model

Team state is durable.

Game Day state is temporary.

Restore context, not sessions.

The app should remember where the user belongs, not pretend to resume a formal game session.

## Data Model

Player requires only:
- Display name

Optional:
- Number
- Photo
- Intro
- Audio/song

Lineup order should be separate from player list order.

Special entries should be possible later:
- Team entrance
- Coach announcement
- Warmup
- Closing music

## Ownership

Export is archival, not entitlement.

Importing users should be able to play imported content.

## Sharing

Manual import/export first.

Cloud, accounts, and collaboration are deferred until strongly justified.

Do not build cloud just because sharing exists.

## Reliability

Donations never affect whether Game Day works.

Reliability is free.

All app features remain available without payment.

## Codex Working Agreement

These docs define default product behavior.

Codex should:
1. Work item-by-item.
2. Present the goal.
3. Explain the proposed change.
4. Identify tradeoffs.
5. Ask for sign-off before implementation.

If implementation conflicts with these docs:
- Stop.
- Explain the conflict.
- Recommend options.
- Wait for approval.

Do not silently reinterpret product intent.
