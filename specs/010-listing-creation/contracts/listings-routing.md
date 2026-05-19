# Contract: Listings Routing (`lib/app.dart` + `lib/core/routing/auth_redirect.dart`)

**Owner**: Phase 10.
**Consumers**: every listing-creation entry point on the device.

## Obligations

Phase 10 adds three new `go_router` routes:

| Route | Page | Guard |
|---|---|---|
| `/publisher/listings/create` | `ListingFormPage` (loads or creates a draft) | requires `publisher_status='approved' AND account_status='approved'` |
| `/publisher/listings/:id/edit` | `ListingFormPage` (loads the existing draft/rejected listing) | requires owner OR admin + same approved-pair gate for owner path |
| `/publisher/dashboard/my-listings` | `MyListingsPage` | requires `publisher_status='approved' AND account_status='approved'` |

Plus one new entry tile on the existing Phase 5 publisher-dashboard surface (likely `lib/features/profile/presentation/pages/publisher_dashboard_page.dart` — exact filename verified at implement time): the "Create listing" tile + the "My listings" entry tile, both gated by the approved-pair check via `PermissionChecker.userIsApprovedPublisher()`.

The route guard logic lives in `lib/core/routing/auth_redirect.dart`, extending the existing Phase 5 guard. Three new redirect rules:

1. If unauthenticated → redirect to `/auth/login`.
2. If authenticated but `account_status<>'approved'` → redirect to the Phase 5 `pending_approval` / `rejected` / `suspended` screen as appropriate.
3. If authenticated + `account_status='approved'` but `publisher_status<>'approved'` → redirect to a localized "publisher approval pending" screen (NEW — Phase 10 adds this surface; Phase 5 already covers the account-status side).

The new "publisher approval pending" screen is a thin localized message page; Phase 10 does NOT add additional publisher-onboarding flow (Phase 5's approval workflow remains the canonical path).

## `PermissionChecker.userIsApprovedPublisher()` helper

Per R-19, the cached profile is consulted:

```dart
bool userIsApprovedPublisher() =>
    currentProfile?.publisherStatus == PublisherStatus.approved &&
    currentProfile?.accountStatus  == AccountStatus.approved;
```

This single helper is consumed by:
1. The UX tile-render predicate on the publisher dashboard.
2. The route guard at `auth_redirect.dart`.
3. (Implicitly) the RLS write policies — which read the same `profiles` columns server-side.

## Verification

```
On the device:
1. Sign in as a publisher_status='pending' user.
   Verify: no "Create listing" tile on the dashboard.
   Verify: hand-typing /publisher/listings/create redirects to the publisher-approval-pending screen.
2. Sign in as a publisher_status='approved' user.
   Verify: "Create listing" tile visible.
   Verify: deep-link to /publisher/listings/create opens the form.
   Verify: deep-link to /publisher/dashboard/my-listings opens MyListingsPage.
3. Sign in as an account_status='suspended' user.
   Verify: redirected to the Phase 5 suspended screen regardless of publisher_status.
4. Have an admin flip a publisher_status from 'pending' to 'approved' mid-session.
   Verify: the "Create listing" tile appears on the next lifecycle observation point (foreground resume) without sign-out.
```

## Forbidden

- Adding a `/admin/listings/*` route in Phase 10 (Phase 12 owns the admin queue).
- Reading `profiles` columns directly from a widget for the gate (the helper is the single source of truth).
- Skipping the account_status check (both publisher_status AND account_status must be `approved`).
