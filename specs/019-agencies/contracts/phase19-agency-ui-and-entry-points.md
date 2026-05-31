# Contract — Agency UI, routes & entry points

**Files**: `lib/features/agency/**` (CREATE), `lib/features/admin/agencies/**` (CREATE), and the 8 existing-file patches. Sub-Phases A/F/G/H/I/J.

## Routes (Sub-Phase A — `app_router.dart` + `auth_redirect.dart`)

| Route | Name | Guard | Builder |
|-------|------|-------|---------|
| `/agency` | `agency` | `Unauthenticated → /login` (the `/favorites` pattern, `app_router.dart:480-487`) | `AgencyHomePage` (create OR manage) |
| `/agency/members` | `agencyMembers` | auth | `AgencyMembersPage` |
| `/agency/listings` | `agencyListings` | auth | `AgencyListingsPage` |
| `/agency/analytics` | `agencyAnalytics` | auth | `AgencyAnalyticsPage` |
| `/agency/verify` | `agencyVerify` | auth | `AgencyVerificationPage` |
| `/agency/:id` | `agencyProfile` | none (public, approved-only) | `AgencyProfilePage` |
| `/admin/agencies` | `adminAgencies` | `requireAgenciesManageRedirect` (child of `/admin`, mirrors `reports` at `:354-359`) | `AgencyQueuePage` |

`requireAgenciesManageRedirect` returns `'/admin?denied=agencies'` when `!getIt<PermissionChecker>().any([agenciesView, agenciesApprove, agenciesSuspend])` (mirrors `requireListingReviewRedirect`, `auth_redirect.dart:112-124`).

## Entry-point patches

- **Profile tile** (`profile_page.dart`): a `ListTile(Icons.business_outlined, l10n.profile_agency_tile → AppRoutes.agency)` between "My Favorites" (`:139-145`) and "My Reports" (`:147-153`).
- **Admin-home tile** (`admin_home_page.dart`): `if (checker.has(PermissionKeys.agenciesView)) ListTile(…, → AppRoutes.adminAgencies)` (mirrors the reports tile `:69-75`).
- **Listing card badge** (`lib/core/widgets/property_card.dart:17-134`): an OPTIONAL `agencyName`/`agencyLogoPath` (or `Widget? agencyBadge`) param, rendered only when non-null — no layout change when null (FR-023). Card sites pass the `agency_name`/`agency_logo_path` from `v_listings_public`.
- **Details badge** (`listing_details_page.dart:28-100`): mount `AgencyBadge(...)` only when the loaded listing's agency is `approved`.
- **Publish under agency** (`step_basics.dart` + `listing_form_bloc.dart`): `PublishUnderAgencyField` (selector over "personal" + the user's active agencies in {pending,approved}); `attachContext` (`listing_form_bloc.dart:106-112`) loads the memberships; the chosen `agencyId` flows into `draftListing` via `copyWith(agencyId:…)` (`listing.dart:268-301`).

## Self-service pages (Sub-Phase H)

`AgencyHomePage` (none → "Create agency"; owner/member → management surface), `AgencyProfilePage` (public), `AgencyMembersPage` (roster + invite sheet + pending-invitations + role/remove), `AgencyListingsPage` (paginated, the agency's listings), `AgencyAnalyticsPage` (member count + listing-by-status counters), `AgencyVerificationPage` (doc upload + ID/registration fields + status banner + rejection reason).

## Admin pages (Sub-Phase I)

`AgencyQueuePage` (paginated pending-verification queue + status filter), `AgencyDetailPage` (profile + decrypted ID/registration + evidence docs + the four-action decision flow), `AgencyDecisionDialog` (approve/reject with reason / suspend with destructive confirm / reinstate).

## Localization (Sub-Phase J)

~40 bilingual keys in `app_ar.arb` + `app_en.arb` (create/profile/members/invite/verify/analytics/badge/admin-queue/decisions/tiles) — see plan.md Sub-Phase J for the key list.

## Smoke tests

1. `/agency` while signed-out → redirects to `/login`; signed-in with no agency → "Create agency"; owner → management surface.
2. `/admin/agencies` for a non-`agencies.*` user → redirected to `/admin?denied=agencies`; for an `agencies.view` holder → queue.
3. A listing under an approved agency shows the badge on card + details; under a pending/suspended agency → no badge, no reflow (SC-008).
4. All surfaces render in light/dark × ar-RTL/en-LTR (SC-013); a grep finds no `package:supabase_flutter` import under `domain/`/`presentation/` and no hardcoded role-string branch (SC-014).
