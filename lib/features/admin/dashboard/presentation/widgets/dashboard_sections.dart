// Phase 20 (spec/020-admin-dashboard) — T008
// Canonical section list for the admin dashboard grid.
// Each section's gating PermissionKeys.* and destination AppRoutes.* are per
// contracts/phase20-dashboard-ui-and-entry-points.md.
// No hardcoded role branches (FR-015).
//
// Phase 25 uplift v2 — each section now declares a [DashboardSectionGroup] so
// the admin hub renders as grouped sections (Moderation / Configuration /
// Insights / Super Admin) with localized group headers, plus an optional
// [subtitleKey] for a one-line tile description.
import 'package:flutter/material.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/security/permission_keys.dart';
import '../../domain/entities/dashboard_section.dart';

/// The canonical ordered section list for the admin dashboard grid.
/// Rendered grouped by [DashboardSection.group]; each section is wrapped by its
/// PermissionChecker gate.
const List<DashboardSection> kDashboardSections = [
  // ── Moderation ──────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'admin_tile_account_approvals',
    permissionKeys: [PermissionKeys.usersView, PermissionKeys.usersApprove],
    route: AppRoutes.adminApprovals,
    counterKey: 'pendingUsers',
    subtitleKey: 'adminSectionSubtitleApprovals',
    group: DashboardSectionGroup.moderation,
    icon: Icons.how_to_reg_outlined,
  ),
  DashboardSection(
    labelKey: 'adminTilePendingReview',
    permissionKeys: [
      PermissionKeys.listingsViewAll,
      PermissionKeys.listingsApprove,
      PermissionKeys.listingsReject,
      PermissionKeys.listingsEditAny,
    ],
    route: AppRoutes.adminListingReviewPending,
    counterKey: 'pendingListings',
    secondaryCounterKey: 'activeListings',
    subtitleKey: 'adminSectionSubtitleListingReview',
    group: DashboardSectionGroup.moderation,
    icon: Icons.fact_check_outlined,
  ),
  DashboardSection(
    labelKey: 'admin_tile_reports',
    permissionKeys: [PermissionKeys.reportsManage],
    route: AppRoutes.adminReports,
    counterKey: 'openReports',
    subtitleKey: 'adminSectionSubtitleReports',
    group: DashboardSectionGroup.moderation,
    icon: Icons.flag_outlined,
  ),
  DashboardSection(
    labelKey: 'admin_tile_agencies',
    permissionKeys: [
      PermissionKeys.agenciesView,
      PermissionKeys.agenciesApprove,
      PermissionKeys.agenciesSuspend,
    ],
    route: AppRoutes.adminAgencies,
    subtitleKey: 'adminSectionSubtitleAgencies',
    group: DashboardSectionGroup.moderation,
    icon: Icons.business_outlined,
  ),
  DashboardSection(
    labelKey: 'dashboardTileInquiries',
    permissionKeys: [PermissionKeys.inquiriesViewAll],
    route: AppRoutes.adminInquiries,
    counterKey: 'newInquiries24h',
    subtitleKey: 'adminSectionSubtitleInquiries',
    group: DashboardSectionGroup.moderation,
    icon: Icons.forum_outlined,
  ),
  // ── Configuration ───────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'locationsTileTitle',
    permissionKeys: [PermissionKeys.locationsManage],
    route: AppRoutes.locationsAdmin,
    subtitleKey: 'adminSectionSubtitleLocations',
    group: DashboardSectionGroup.configuration,
    icon: Icons.location_on_outlined,
  ),
  DashboardSection(
    labelKey: 'adminHomeCurrenciesTile',
    permissionKeys: [PermissionKeys.currenciesManage],
    route: AppRoutes.currenciesAdmin,
    subtitleKey: 'adminSectionSubtitleCurrencies',
    group: DashboardSectionGroup.configuration,
    icon: Icons.currency_exchange,
  ),
  DashboardSection(
    labelKey: 'dashboardTileAds',
    permissionKeys: [PermissionKeys.adsManage],
    route: AppRoutes.adminAds,
    subtitleKey: 'adminSectionSubtitleAds',
    group: DashboardSectionGroup.configuration,
    icon: Icons.campaign_outlined,
  ),
  DashboardSection(
    labelKey: 'dashboardTileSettings',
    permissionKeys: [PermissionKeys.settingsManage],
    route: AppRoutes.adminSettings,
    subtitleKey: 'adminSectionSubtitleSettings',
    group: DashboardSectionGroup.configuration,
    icon: Icons.settings_outlined,
  ),
  // ── Insights ────────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'dashboardTileAuditLogs',
    permissionKeys: [PermissionKeys.auditLogsView],
    route: AppRoutes.adminAuditLogs,
    subtitleKey: 'adminSectionSubtitleAuditLogs',
    group: DashboardSectionGroup.insights,
    icon: Icons.history_outlined,
  ),
  // ── Super Admin ─────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'adminTileSuperAdmin',
    permissionKeys: [
      PermissionKeys.rolesView,
      PermissionKeys.rolesCreate,
      PermissionKeys.rolesUpdate,
      PermissionKeys.rolesDelete,
      PermissionKeys.permissionsManage,
    ],
    route: AppRoutes.superAdminRoles,
    subtitleKey: 'adminSectionSubtitleSuperAdmin',
    group: DashboardSectionGroup.superAdmin,
    icon: Icons.shield_outlined,
  ),
];
