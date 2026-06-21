# Roll Call Support Plan

Status: design handoff for a future implementation worktree.
Date: 2026-06-20

## Purpose

Roll Call will remain a complete, free, ad-free app. Optional support purchases may help maintain and improve the app, but support must never unlock features, improve reliability, raise limits, or affect Game Day behavior.

This plan supersedes the older roadmap assumption that support options are only a distant 1.6 / 2.0 exploration. The roadmap should be replanned separately after this support path is implemented or scheduled.

## Product Principles

- All Roll Call features stay free.
- Multiple teams stay free.
- Imports, exports, backups, restore, readiness, Game Day, Clips, Apple Music support, and audio reliability stay free.
- Support must never be required to finish setup or use a team.
- Support prompts must never appear during onboarding, team setup, imports, exports, readiness checks, Game Day, Clips, active playback, or other live-use moments.
- The support experience should feel like a calm contribution page, not a paywall.
- No dark patterns, countdowns, "best value" badges, feature comparison tables, pressure copy, or recurring nags.
- No ads, accounts, analytics, backend, tracking, or custom receipt server are part of this support system.

## Placement

Add a `Support Roll Call` screen.

Place it in:

- Main Settings as a calm top-level row near `About Roll Call`, not above core team/game/music settings.
- `About Roll Call -> Support` as a secondary entry.
- A small footer link from the earned rating prompt.

Do not place support links in onboarding, setup guidance, Game Day, Clips, readiness, import/export flows, or active playback surfaces.

The support screen may be visible if a user manually opens Settings before creating a team, but onboarding must not mention it.

## Rating Prompt Integration

The existing earned-use rating prompt may mention support, but it remains rating-first.

Recommended shape:

- Primary action: `Rate Roll Call`
- Secondary action: `Email Support Instead`
- Plain dismiss: `Not Now`
- Small footer link: `You can also support development in Settings.`

The footer link opens the full `Support Roll Call` screen, not purchase options directly.

The current rating-prompt cap should remain: show at the earned-use threshold, allow one later retry, then stop automatic asks. There should be no new "hide support prompts" setting.

## Support Screen Copy

Use "support" and "contribution" language in shipped UI. Avoid "donation" in visible app copy and App Store-facing text.

Recommended opening copy:

> Roll Call is free, ad-free, and fully functional for every team.
>
> Optional support helps keep the app maintained, compatible with iOS updates, and improving over time.
>
> Support never unlocks Game Day features, teams, imports, exports, or reliability.

Keep copy short. Avoid pleading, guilt, or a long developer story.

Do not include GitHub, public project, or manifesto links on the support screen. About should handle credits and public project links.

## Purchase Model

Implement both:

- One-time support purchases using consumable in-app purchases.
- Optional recurring support using auto-renewable subscriptions.

Support purchases and subscriptions are voluntary contribution paths only. They do not unlock app functionality.

Recurring subscriptions are an explicit promise of ongoing app maintenance, compatibility, bug fixing, and free improvements for every team. They are not a promise of premium priority, special treatment, or exclusive features.

## Product IDs

Use fully namespaced product IDs.

Suggested IDs:

- `com.sidelarklabs.rollcall.support.small`
- `com.sidelarklabs.rollcall.support.medium`
- `com.sidelarklabs.rollcall.support.large`
- `com.sidelarklabs.rollcall.support.legendary`
- `com.sidelarklabs.rollcall.support.monthly`
- `com.sidelarklabs.rollcall.support.yearly`

The app should define the expected product IDs, ordering, and local display intent. StoreKit should provide availability and localized price strings.

## One-Time Support

Use consumable in-app purchases.

One-time tier names should be warm and softball-adjacent rather than donor-size/status labels.

Recommended tiers:

- `Tip of the Cap`
- `Dugout High Five`
- `Walk-Up Hero`
- `Grand Slam Legend`


Each row should show:

- Contribution name first.
- Short playful subtitle second.
- Localized price clearly on the trailing side.

Example:

`Dugout High Five`
`A little extra cheer for the team`
`$2.99`

Keep the actual product name clearly about support. Avoid titles that imply the user is buying a real-world item that will be fulfilled.

## Recurring Support

Use auto-renewable subscriptions.

Recurring names should be plain and non-status-based:

- `Season Supporter`
- `All-Star Season Supporter`

Avoid names like `MVP`, status badges, "best value," or any language that ranks supporters.

Each row should show:

- Contribution name first.
- Maintenance-oriented subtitle.
- Localized price and recurrence clearly on the trailing side.

Example:

`Season Supporter`
`Monthly support to keep Roll Call maintained for every team`
`$0.99/mo`

`All-Star Season Supporter`
`Yearly support for compatibility, fixes, and improvements`
`$7.99/yr`

The recurring tab should include short pre-purchase fine print:

> Recurring support renews automatically until canceled in your Apple ID subscriptions. You can manage or cancel anytime. Support does not unlock features.

Also include low-prominence footer actions:

- `Restore Support`
- `Manage Subscriptions`

## Screen Layout

Use a segmented control:

- `One-Time`
- `Recurring`

Default selection: `One-Time`.

Recommended screen order:

1. Short explanatory copy (Make it clear that this app is 100% free, and tips are extremely appreciated but completely optional.)
2. Gratitude/status area only if verified support exists.
3. Segmented control.
4. Product rows for the selected segment.
5. Restore/manage actions where relevant.
6. Optionality/footer copy.

Do not show both one-time and recurring sections stacked by default; six purchase options at once risks making the page feel like a store.

## Supporter State

Separate current entitlement from gratitude.

Show active subscription state only when StoreKit confirms an active subscription:

- `Season Supporter Active`

Show gratitude when there is verified past support:

- `Thanks for supporting Roll Call`

Past support can come from a verified one-time purchase, a prior subscription, StoreKit transaction history, or a local cache of previously verified support.

Do not show empty supporter status for non-supporters.

Acknowledgment stays only in Settings/About. Do not show supporter badges in Game Day, Clips, teams, players, exports, shared files, or live surfaces.

## StoreKit Behavior

Use StoreKit 2.

Implementation requirements:

- Load expected products from App Store Connect via StoreKit.
- Display only available products, using localized prices from StoreKit.
- Handle purchases through StoreKit 2.
- Verify transactions locally.
- Finish transactions.
- Observe subscription status changes.
- Restore recurring support when requested.
- Provide a manage-subscriptions path.
- Record minimal local supporter state for UI comfort.

StoreKit is the source of truth for active recurring support. Local cache is only a convenience layer for previously verified support/gratitude and last-known UI state.

Suggested local cache:

- last known active subscription status
- whether verified support has ever been seen on this install
- last successful support product/date if available

Do not store dollar totals.
Do not sync support state through Roll Call.
Do not treat local cache as proof of an active subscription.

## Restore And History

Consumable one-time support is repeatable and should not be described as a durable restorable entitlement.

Use restore language focused on subscriptions:

- `Restore Support`

If StoreKit transaction history shows prior one-time support, the app may show gratitude. Do not promise that one-time support "restores" like a permanent unlock.

Recommended explanatory copy near restore:

> One-time contributions can be made again any time. If Roll Call can see past support on this Apple ID, it will show a thank-you here.

## Purchase Feedback

Purchase feedback stays local to the Support screen.

On success:

- Show a calm inline confirmation such as `Thanks for supporting Roll Call.`
- Update the Settings/About supporter state.

If the user leaves before completion:

- Quietly update supporter state when StoreKit reports completion.
- Do not show delayed global thank-you popups.

If renewal, cancellation, or expiration changes arrive later:

- Update state quietly.
- Do not interrupt Game Day, Clips, playback, setup, import/export, or other flows.

## Failure Handling

StoreKit failures should be quiet by default and clear after user action.

Recommended behavior:

- If all support products fail to load: show `Support options are unavailable right now. Please try again later.` with a retry action.
- If some products load: show available products and a small note that some options are temporarily unavailable.
- If purchase fails after a tap: show a clear inline message without alarm language.
- If the user cancels purchase: show no error.

Never frame StoreKit failures as core app breakage.

## Privacy, Data, And Exports

No backend server.
No analytics.
No tracking.
No custom receipt validation server.
No silent network behavior beyond Apple purchase handling.

Support state is app/account-level and must not travel in team data.

Rules:

- `.rollcall` team exports must not include support state.
- App backups/restores must not include support transaction/cache state, or must explicitly exclude it during restore.
- Restoring someone else's backup must never make the app claim the current user supported Roll Call.
- Support state should be rebuilt from StoreKit and local verified cache.

## App Review Notes

App Review-facing explanation should be plain:

- Roll Call is fully functional without payment.
- One-time products are optional repeatable support contributions.
- Monthly subscriptions are optional support for ongoing maintenance, iOS compatibility, bug fixes, and free improvements for all users.
- Support does not unlock features, limits, storage, teams, imports, exports, playback, Game Day behavior, reliability, or priority treatment.
- The app includes clear recurring-billing language and a way to manage subscriptions.

## Implementation Scope

This plan is intended for a separate implementation worktree.

Expected implementation areas:

- StoreKit 2 support model/service.
- Support screen UI.
- Settings/About navigation rows.
- Rating prompt footer link.
- Minimal supporter-state persistence outside team export/backup data.
- StoreKit configuration/testing fixtures if useful.
- Focused tests for supporter state, export/backup exclusion, and rating-prompt routing.

Avoid broad roadmap rewrites in the implementation pass unless intentionally replanning after support work lands.

## Open Implementation Checks

- Confirm final App Store Connect product prices before release.
- Confirm exact App Store Connect subscription group setup.
- Confirm the manage-subscriptions API/path used by the app.
- Confirm whether current app backup implementation needs an explicit support-state exclusion or naturally excludes it.
- Confirm StoreKit sandbox test coverage for purchase, cancel, restore, unavailable products, and subscription expiration.
- Update `docs/DECISIONS.md` when implementation is approved or started in the new lane.
- Update `docs/working-changelog.md` if support ships in a user-facing release.
