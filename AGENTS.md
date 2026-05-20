# AGENTS.md — Universal Project Rules

This file is the single source of truth for AI coding agents across this project. It is read by both OpenAI Codex (natively) and Claude Code (via `CLAUDE.md` pointer).
Work safely, conservatively, and transparently.
Assume I may not deeply review code and may not notice hidden risks in my request.
If a change is destructive, user-visible, security-sensitive, privacy-sensitive, materially worse for the app’s core job, materially slower/heavier, architecturally surprising, or meaningfully expands scope, stop and ask first.
Follow everything in this file regardless of which agent is running. Conditional rule files apply when their triggers match the task.

## Roll Call Product Operating Principles

This is a compact summary for everyday work. Full product philosophy lives in `product/NORTH_STAR.md`; current UX guidance lives in `product/UX_RULEBOOK.md`; release and premium boundaries live in `product/PRODUCT_SCOPE.md`.

Default product bias:
- Roll Call is an iPhone-first walk-up cue app for game-day delight with nearly invisible operation.
- Game Day should feel ready when opened: coach taps the player, the right thing happens, kids and parents enjoy it.
- Prefer native iOS behavior and Apple conventions over custom UI unless there is a clear product benefit.
- Prefer speed, clarity, reliability, and field usability over feature count or configurability.
- Customization must earn its existence by adding real delight, reducing work, or protecting user investment.
- Preserve existing setup work and user-created content; do not make users redo meaningful customization without strong reason.
- Premium features may enhance delight or save time, but must never affect Game Day reliability or core success.
- Avoid accounts, cloud sync, social features, backend infrastructure, scoreboard systems, and broad sports-management scope unless explicitly approved.

Load the full product docs only when the task changes product behavior, navigation, workflow, scope, monetization, or meaningful UX tradeoffs. Do not load them for tiny/local implementation tasks unless needed.

## Rule Hierarchy

Apply instructions in this order:

1. Safety, security, privacy, data integrity, reversibility, and truthfulness
2. Explicit project approvals in the brief, milestone plan, or decision log
3. Project workflow and continuity rules
4. Default product, UX, implementation, and communication preferences

If there is a conflict, the higher-priority rule wins unless I explicitly override it.

### Documentation and Implementation Conflict Rule

Current implementation is authoritative for what the app actually does. If implementation appears to conflict with docs, redesign rationale, product scope, or historical notes:
1. surface the conflict,
2. explain the likely tradeoff or possible drift,
3. do not silently rewrite the app to match old docs,
4. ask whether the drift is intentional unless the safe fix is obvious and local.

Historical docs explain how we got here. They do not override the current app, current scope, or explicit user instructions.

## Session Startup

Use minimal startup context.

For tiny / low-risk tasks:
- read only the files needed for the current edit,
- do not automatically load project status, decision logs, or philosophy docs unless clearly relevant.

For normal / risky tasks, read relevant startup docs if they exist:
- `decisions/DECISIONS.md`
- `docs/WHERE_WE_STAND.md`
- current project brief or milestone plan

Use these docs to avoid contradicting approved decisions, current state, known risks, and open priorities.

## Safety-First Principles (Non-Negotiable)

- Do not run destructive commands or perform destructive actions without explicit approval.
  - Examples: deleting files, bulk modifications, irreversible migrations, removing user content, force-overwriting outputs, resetting data, discarding current work, or destructive rollback.
- Do not modify files outside the current repository or explicitly approved workspace.
- Do not introduce telemetry, analytics, tracking, ads, or background network calls unless I explicitly request them. Local-only crash logs and explicit user-initiated "send report" actions are acceptable without per-project approval, but must not phone home silently.
- Do not add new third-party dependencies unless they are necessary, justified, and called out before implementation.
- Never include secrets in code, config, logs, tests, screenshots, docs, or commits.
  - Store secrets in platform keychain/credential store or runtime environment variables. Use `.env` files only for local development and always include `.env` in `.gitignore`.
- Avoid "download and execute" patterns such as `curl | bash`.
- Do not silently weaken privacy, security, data integrity, or determinism through hidden retries, fallbacks, uploads, writes, overwrites, or permission expansion.
- If actual behavior differs from requested behavior, report both the requested result and the actual result, with the reason.

## Ask-First Gate

Stop and ask first unless the behavior is already clearly approved by the project brief, the decision log (`decisions/DECISIONS.md`), the current milestone plan, or an explicit user instruction.

Especially ask before:
- destructive actions or irreversible outputs,
- user-visible behavior changes,
- compatibility breaks,
- permission or entitlement changes,
- new network behavior,
- new long-running background work,
- materially heavier behavior,
- architectural pivots,
- reduced privacy/security,
- or major/minor version changes,
- or scope expansion beyond the request.

If approval is needed, present options when meaningful with pros/cons and recommend one.

If a project-specific brief, milestone plan, or decision log explicitly approves behavior that would otherwise require re-asking under these general rules, follow that approval while still honoring safety, privacy, reversibility, and transparency. If there is a conflict, the stricter safety/privacy rule wins unless I explicitly override it.

Later sections may mention specific examples, but this section is the controlling ask-first rule.

## Working With Me

- Ask clarifying questions freely when they will improve the result, expose a tradeoff, or reduce the chance of a wrong turn.
- Prefer asking one question at a time and waiting for an answer before asking the next question.
- Offer concise, high-signal suggestions when they are likely to materially improve safety, usability, maintainability, or fit. Avoid speculative or low-value suggestion sprawl.
- Distinguish clearly between what I asked for, what you recommend, and what is optional.
- Do not treat suggestions as approved changes unless I explicitly approve them.
- I value back-and-forth iteration and course correction more than one giant "finished" pass.
- Small related improvements are welcome when low-risk, clearly disclosed, and tightly related to the request. Avoid broad rewrites or exploratory expansion without approval.
- Be clear, direct, and practical. Do not hide uncertainty behind confident language. Surface meaningful tradeoffs. When there are real choices, present them cleanly and recommend one. Avoid unnecessary jargon when a plain description will do. Be helpful without becoming overeager or sprawling.
- Behavior-changing edits remain subject to the Ask-First Gate.

## Implementation Style

- Prefer the simplest solution that genuinely solves the problem.
- Prefer small, reviewable steps over large, sweeping rewrites.
- Prefer straightforward code over clever code.
- Prefer explicitness over hidden indirection.
- Keep comments concise, useful, and focused on intent.
- Avoid broad tooling churn unless it clearly helps.
- Do not modify dependency manifests, lockfiles, formatter rules, lint rules, compiler settings, CI config, or build scripts unless the task actually requires it. If such changes are required, call them out explicitly in the plan and summary.
- Follow the project's existing code formatting and linting conventions. If none exist, use the language's community-standard formatter (e.g., swift-format for Swift, rustfmt for Rust, Prettier for JS/TS) with default settings.
- Preserve existing behavior unless the requested task requires changing it.
- Update docs when behavior, setup, architecture, or operational expectations materially change.
- For risky or user-visible work, prefer opt-in or isolated rollout paths unless already approved.

## Execution Discipline

- Prefer smallest practical edit.
- Preserve structure/naming unless task requires change.
- Escalate to larger refactors only when:
    - repeated fixes fail,
    - implementation blocks progress,
    - replacement is clearly safer or materially simpler.
- Ask before broad refactors.
- Stop after completion.

## Task Workflow

Use the lightest workflow that safely fits the task.

### Tiny / Low-Risk Tasks

For tiny, low-risk tasks, do not produce a full formal plan unless useful.

A tiny / low-risk task means all are true:
- expected edit is small and localized,
- no user data, permissions, migrations, security, privacy, CI/release, dependency, or architecture impact,
- no destructive behavior,
- no compatibility break,
- no broad refactor,
- no meaningful performance/output-quality risk.

For these tasks:
- briefly state the intended edit,
- make the change,
- run the narrowest relevant check,
- summarize files changed and verification performed.

### Normal / Risky Tasks

For anything non-trivial, risky, ambiguous, broad, user-visible, or behavior-changing, provide before coding:
1. short plan,
2. files expected to change,
3. any new dependencies, permissions, entitlements, migrations, external tools, or network behavior,
4. risk level: low / medium / high.

Also:
- call out meaningful uncertainty or hidden risk,
- note likely impact on performance, reliability, compatibility, output quality, or user data,
- check `decisions/DECISIONS.md` for relevant prior decisions before proposing something that may have already been decided,
- state which conditional rule files were reviewed and why. If none, say "none."

### Verification Output

Always report verification, but scale detail to risk.

For tiny / low-risk tasks:
- report the exact check run, or say not run with reason.

For normal / risky tasks:
- provide exact build/run/test steps,
- include before/after measurements when performance, reliability, or output quality may have changed.

If the task could affect user data, permissions, fallbacks, or long-running work, verify the relevant safety conditions from the applicable conditional rule files.

### Verification Scope Discipline

Match verification scope to change scope.

- Prefer the narrowest meaningful verification.
- For localized changes, prefer targeted tests, focused builds, or limited smoke checks over full-suite runs.
- Do not run expensive builds or broad test suites unless:
  - the change meaningfully affects shared behavior,
  - the task explicitly requires it,
  - or localized verification is insufficient.
- If broader verification was intentionally skipped, say so briefly.

## Context and Execution Efficiency

Use the minimum context, output, and verification needed to make a safe change.

### Context Discipline

- Read only the files, symbols, tests, logs, and nearby code needed for the current task.
- Prefer targeted search over broad discovery.
- Stop gathering context once enough evidence exists to make a safe bounded change.
- Do not repeatedly re-read unchanged docs unless new information suggests they matter.

### Command and Output Discipline

When shell access exists and `rtk` is available on PATH, prefer RTK wrappers for commands that would otherwise produce large or noisy output.

Examples:
- `rtk ls`
- `rtk tree`

Do not use RTK when exact raw output matters, output is already small, RTK is unavailable, or RTK itself is being debugged.

For potentially large output:
- prefer byte-capped output (`head -c`, `tail -c`)
- narrow commands before increasing output size
- avoid dumping logs, generated files, build artifacts, or large JSON unless needed

### Tool Discipline

Treat searches, file reads, and commands as expensive.

- Reuse existing context when sufficient.
- Avoid repeating searches or verification unnecessarily.
- Prefer acting on strong evidence over gathering excessive context.

### Debugging Discipline

Prefer the smallest plausible fix first.

- Try one focused fix before broad investigation.
- Use failures to narrow the next hypothesis.
- After 2 failed attempts at the same problem, stop and reassess before continuing.
- Report blockers instead of continuing to guess.

### Communication Discipline

- Report decisions, verification, blockers, and outcomes.
- Do not provide transcripts of routine work.
- Prefer concise summaries over repeated rationale.
- Prefer editing files over pasting large generated content inline.
- Avoid repeating rationale across plan, implementation notes, and summaries.

## Decision Log

Maintain `decisions/DECISIONS.md` as a living decision log for the project.

**When to update it:** when a meaningful architectural, design, scope, tooling, or behavioral decision is made or approved; when an open question is resolved; when a decision is reversed or superseded.

**Format:** date, short decision summary, brief rationale (why this over alternatives), status (approved / reversed / superseded).

**Rules:**
- Append new entries; do not delete or rewrite old ones. Mark superseded entries as such.
- Keep entries concise — one to three sentences each.
- Do not use the decision log for task status, changelogs, or TODO lists. Those belong in `docs/WHERE_WE_STAND.md` or issue trackers.
- Do not propose something that contradicts an approved decision without flagging the conflict.

## Status Document

For projects with meaningful versioning, milestone releases, or durable rollback points, maintain a concise status document at `docs/WHERE_WE_STAND.md`.

**When to update it:** at the end of every session that changes the project materially; on major or minor version bumps; when a durable known-good anchor is created; when I ask; when implemented-vs-missing status materially changes.

**What to include:** project name, current version/build, plain-language overall status, what works now, what is partial, what is not implemented yet, known limitations and trust warnings, setup/runtime requirements, important operational risks, recommended next priorities, most recent durable known-good anchor if one exists.

**Rules:**
- Keep it short, practical, and written for a tech-savvy but programming-new owner.
- Do not let it become marketing copy, vague filler, or a changelog dump.
- Update it at session end if the project state changed.

## Git Workflow and Recovery

- Default branch strategy is commit-to-main unless I specify otherwise. Do not create feature branches, pull requests, or branch-based workflows without being asked.
- Write commit messages as short imperative sentences, ≤72 characters for the subject line. e.g. `Add login screen`, `Fix empty CSV export crash`. Add a body paragraph for non-obvious changes explaining why, not just what.
- At session end, commit completed work with a clear message. Leave work-in-progress uncommitted and note what remains in the change summary.
- If no baseline commit exists, the Ask-First Gate applies before material edits.
- For medium- or high-risk tasks, create or recommend a rollback point before material edits.
- Prefer small, reviewable commits at stable milestones over large opaque changes.
- History rewrites, resets, and destructive git actions require Ask-First approval.
- If I explicitly identify a state as known good, create or recommend a durable rollback anchor using the repo's normal workflow.
- Before any rollback or reset-like action, explain exactly what target would be restored and what current work could be lost.

## Versioning

- Use an ever-increasing build number for every commit across the life of the project.
- Do not bump the minor or major version without my explicit approval. Bumps can be suggested with brief reasoning, but not applied automatically.
- App marketing version and build number must come from source-controlled files, not from local caches, `.build/`, DerivedData, or other untracked machine-specific state. Before any release build, report the exact version that will be produced and stop if local state could alter it. Update versioning files in the same commit as the build change.
- Prefer deterministic versioning that reproduces the same app version/build from the same committed source.
- For projects that publish through CI, prefer workflows where a pushed checked-in version bump on `main` automatically creates or updates the corresponding GitHub Release. Do not require a separate manual tag push unless the project brief or decision log explicitly prefers tag-driven releases.

## Performance, Reliability, and Output Quality

- Assume real-world datasets can be large.
- Avoid loading everything at once when streaming, paging, batching, or incremental work is feasible.
- Prefer event-driven updates over polling loops where practical.
- Bound concurrency deliberately.
- Handle errors explicitly. No silent failures.
- Prefer actionable error surfaces over generic failures.

If a change risks meaningful regression in core functionality, performance, reliability, or output quality, the Ask-First Gate applies unless already approved.

Before implementing a materially heavier or lower-quality approach, provide:
1. baseline behavior,
2. expected impact or risk envelope,
3. safer alternatives, including a no-regression option,
4. recommendation.

If exact baseline numbers are not yet available, provide a measurement plan before coding and actual before/after measurements after implementation.

## Compatibility and Interface Stability (If relevant)

If the project already has users, saved data, config files, scripts, documented commands, or public/internal interfaces:

- Preserve existing behavior by default.
- Do not rename, remove, or repurpose interfaces without approval unless the change is clearly internal and unused.
- If a compatibility break is necessary, explain:
  1. what breaks,
  2. who or what is affected,
  3. the migration path,
  4. the rollback path.
- Prefer additive changes, compatibility shims, or deprecation paths over abrupt breaking changes.

## Integrity

- Do not present unverified, mocked, scaffolded, placeholder, or partial work as complete.
- Keep docs, comments, tests, screenshots, and status aligned with actual behavior.
- Do not weaken or rewrite tests merely to make failures disappear.
- State uncertainty, incomplete verification, limitations, and deferred work clearly.
- Distinguish between implemented, partial, and planned behavior when relevant.

## About Screen

- About Screen of all apps must give copyright credit to "John Kenneth Fisher" and include a clickable link to the public GitHub page if one exists.


## Conditional Rule Triggers

- Use progressive disclosure. Load rule files only when directly relevant or risk increases. 
- At planning time identify candidate rule files; load only those required.

| Trigger | Load |
|---|---|
| Product/UX/scope | product docs |
| Resume work | WHERE_WE_STAND, DECISIONS |
| Build/release | BUILD_ENVIRONMENTS |
| Data/permissions | user-data-permissions |
| Apple APIs | apple |
| Long-running work | long-running-work |
| External input | untrusted-input-tools |
| Migrations | migration-format-safety |
| AI | ai-inference |
| Diagnostics | diagnostics-privacy |
| Distribution/assets | about-distribution, readme, third-party-assets |
| Historical context | docs/historical |
