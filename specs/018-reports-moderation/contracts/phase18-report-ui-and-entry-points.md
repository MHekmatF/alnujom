# Contract — Report UI & entry points (reporter + admin surfaces)

**Sub-Phases**: A (routes/redirect/stubs), H (reporter UI + Report CTA + banner + Profile tile), I (admin queue + resolve + admin tile), J (l10n).

## Routes (Sub-Phase A — `lib/core/routing/app_router.dart`)

| Constant | Path | Guard | Page |
|----------|------|-------|------|
| `AppRoutes.reports` / `AppRouteNames.reports` | `/reports` | `authBloc.state is Unauthenticated ? AppRoutes.login : null` (mirrors `/favorites`) | `MyReportsPage` |
| `AppRoutes.adminReports` / `AppRouteNames.adminReports` | `/admin/reports` (child of `/admin`) | `requireReportsManageRedirect` (new, in `auth_redirect.dart`) | `ReportsQueuePage` |

`requireReportsManageRedirect` returns `'/admin?denied=reports'` when `!getIt<PermissionChecker>().has(PermissionKeys.reportsManage)` — mirrors `requireListingReviewRedirect`.

## Report CTA rewire (Sub-Phase H1 — `per_listing_action_block.dart`)

- The Report `_ActionButton` (`Icons.flag_outlined`, `l10n.cta_report`) `onPressed` changes from `_showComingSoon(context, l10n.action_report_coming_soon)` to `_onReportTap(context)`.
- `_onReportTap`: if `getIt<AuthBloc>().state is! Authenticated` → snackbar `l10n.report_sign_in_prompt` + `context.push(AppRoutes.login)` (FR-006/FR-007); else `showModalBottomSheet(builder: (_) => ReportSheet(listingId: listingId))`.
- **Untouched**: the Favorite CTA (Phase 17 `BlocSelector`/`_onFavoriteTap`), the Share CTA stub, the row layout (FR-034). No constructor change (`listingId` already required).

## Report sheet (H — `report_sheet.dart`)

`DropdownButtonFormField<ReportReason>` (8 reasons, labels from J) + optional multiline note (`≤1000` chars) + submit/cancel; on submit calls `ReportSubmissionCubit.submit()` → `SubmitReport`; success/`already_reported`/failure → localized snackbars; closes on success.

## Reporter banner (H — `reporter_status_banner.dart`)

On `listing_details_page.dart`, `ListingReportStatusCubit.load(listingId)` calls `LoadMyReportForListing`; if a `Report` exists, render `l10n.report_banner_status` + `ReportStatusChip`. Renders nothing for non-reporters / anon (self-scoped by RLS, FR-023).

## My Reports (H — `my_reports_page.dart`)

`AppBar(l10n.reports_my_title)` + `RefreshIndicator` over a paginated `ListView` of cards (listing image/title + reason + `ReportStatusChip`); empty-state via `MyReportsEmptyState`; tap → `AppRoutes.listingDetailsFor(listingId)`. Reached from a Profile `ListTile` (`l10n.profile_reports_tile`) inserted after the "My Favorites" tile (FR-022).

## Admin queue + resolve (I)

- `admin_home_page.dart`: `if (checker.has(PermissionKeys.reportsManage)) ListTile(… l10n.admin_tile_reports … onTap: push(AppRoutes.adminReports))` (FR-019).
- `reports_queue_page.dart`: `ReportFilterBar` (status + reason) + paginated queue of `ReportQueueCard`s (FR-020); tap → `report_detail_page.dart`.
- `report_detail_page.dart`: report + listing context, "Start review" (`StartReportReview`, soft lock), and the four actions via `resolve_action_dialog.dart` (destructive ones require confirmation, FR-017) → `ResolveReport`.

## Smoke tests

1. Anon on details → Report CTA visible; tap → prompt + `/login`; no row (SC-011).
2. Signed-in → sheet → submit → confirmation + row (SC-001).
3. `reports.manage` → admin home shows Reports tile → queue; non-admin → no tile, `/admin/reports` redirects (SC-003).
4. Reporter → Profile "My Reports" → own reports only + empty-state (SC-007); details banner reflects status (SC-008).
5. 4-combination theme×locale render of sheet/queue/resolve/My-Reports/banner (SC-012).
