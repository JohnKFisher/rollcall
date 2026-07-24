# Support Contribution Design

Status: historical design record; the support path is implemented in the current app.

## Durable product rules

- Roll Call remains fully usable without paying.
- Support is optional, calm, and located in Settings/About-style surfaces.
- Support never unlocks features, changes readiness, affects Game Day reliability, or travels with team exports or backups.
- Onboarding, Game Day, Clips, import, repair, and other task flows should not become donation surfaces.
- One-time contributions may be repeatable; recurring support is managed through the user's Apple ID subscriptions.

## Implemented shape

The app offers localized StoreKit products for one-time and monthly/yearly recurring support. It verifies transactions locally, observes transaction updates from app launch, finishes purchases, shows gratitude after verified support, supports subscription restore/manage actions, and keeps cached gratitude separate from team data.

The support screen is reachable from Settings/About and from the quiet support link in the earned rating flow. Product availability and localized prices come from StoreKit; the app does not treat cached local state as proof of an active subscription.

## Historical cleanup

The former donation plan was a future implementation handoff. Its implementation checklist and older roadmap assumptions are retired. Current support behavior belongs in [Application Overview](../../product/APP_OVERVIEW.md), [Product Scope](../../product/PRODUCT_SCOPE.md), and [UX Rulebook](../../product/UX_RULEBOOK.md).
