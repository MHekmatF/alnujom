# Contract: Currencies Admin Routing

**Owner**: Phase 9 (`lib/app.dart` + `lib/core/routing/auth_redirect.dart` updates).
**Consumers**: `currencies.manage` permission holders.

## Obligations

### Admin home tile

`lib/features/admin/presentation/pages/admin_home_page.dart` gains one new tile "Currencies" gated by `PermissionChecker.has(PermissionKeys.currenciesManage)`. The tile:

- Is **hidden**, not dimmed, for non-permission-holders.
- Navigates to `/admin/currencies` on tap.
- Sits in the admin-home tile grid alongside the Phase 5 account-approvals tile, the Phase 7 super-admin tile, and the Phase 8 Locations tile.
- The tile's label flows through `AppLocalizations` per the `adminHomeCurrenciesTile` ARB key.

### Three new `go_router` routes

| Route | Page | Guard predicate |
|---|---|---|
| `/admin/currencies` | `CurrenciesListPage` | `PermissionChecker.has('currencies.manage')` |
| `/admin/currencies/set-rate` | `SetExchangeRatePage` | same |
| `/admin/currencies/:code/history` | `ExchangeRateHistoryPage` | same |
| `/admin/currencies/form` *(modal)* | `CurrencyFormPage` | same |

The four routes (three top-level + one modal/dialog route for the currency form) are registered in `lib/app.dart`'s `GoRouter` configuration. The route-redirect helper at `lib/core/routing/auth_redirect.dart` extends the existing per-route guard with the four new entries. The pattern matches Phase 6's `/admin/*`, Phase 7's `/admin/super-admin/*`, and Phase 8's `/admin/locations/*` route guards.

### Guard behavior

When a non-permission-holder navigates (via deep link or programmatic) to any of the four routes, the redirect helper:

1. Reads `PermissionChecker.has('currencies.manage')`.
2. If false, redirects to the established admin-route-unauthorized destination (likely the `/` home or a localized "not authorized" page — exact destination defined by the existing helper per Phase 5/6 pattern, not redefined here).
3. If true, allows the route to render.

### Mid-session permission revocation

Per FR-011 and Phase 6 FR-015, when an admin is revoked `currencies.manage` mid-session:

- The Currencies tile on `AdminHomePage` disappears on the next lifecycle observation point (foreground resume or token refresh) without a sign-out.
- If the user is currently on one of the four currencies routes when revoked, the redirect guard re-evaluates on the next navigation and refuses subsequent in-route navigation. (The currently-rendered page does not auto-dismiss in Phase 9; that is Phase 22's push + Realtime concern per `project_phase22_perm_cache_revisit.md`.)

## Verification

```bash
# Admin sees the tile
# Sign in as Phase 5 admin → confirm "Currencies" tile renders on AdminHomePage

# Moderator does NOT see the tile
# Sign in as moderator → confirm no "Currencies" tile renders

# Deep-link refused for non-permission-holder
# Type /admin/currencies in deep-link → expect redirect to unauthorized destination

# All four routes navigate successfully for permission-holder
# Admin: tap "Currencies" → confirm CurrenciesListPage opens
# Admin: tap "Set new rate" → confirm SetExchangeRatePage opens
# Admin: tap a currency → "View history" → confirm ExchangeRateHistoryPage opens
# Admin: tap "Add currency" → confirm CurrencyFormPage opens as a modal
```

## Forbidden

- Showing the "Currencies" tile when `PermissionChecker.has('currencies.manage')` is false (FR-013). Dimming the tile is not acceptable — it must be hidden entirely.
- Permitting any of the four routes to render without the permission check. The route guard is the second of three layers (UI hide + route guard + RLS).
- Hardcoded role-identity checks anywhere in the route guard (Constitution VII). The guard MUST resolve to the `currencies.manage` permission key, never to a role string like `'admin'`.
