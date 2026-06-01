// Phase 20 (spec/020-admin-dashboard) — T008
// Canonical section list for the admin dashboard grid.
// Each section's gating PermissionKeys.* and destination AppRoutes.* are per
// contracts/phase20-dashboard-ui-and-entry-points.md.
// No hardcoded role branches (FR-015).
import 'package:flutter/material.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/security/permission_keys.dart';
import '../../domain/entities/dashboard_section.dart';

/// The canonical ordered section list for the admin dashboard grid.
/// Rendered in order; each section is wrapped by its PermissionChecker gate.
const List<DashboardSection> kDashboardSections = [
  // ── Users ──────────────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'admin_tile_account_approvals',
    permissionKeys: [PermissionKeys.usersView, PermissionKeys.usersApprove],
    route: AppRoutes.adminApprovals,
    counterKey: 'pendingUsers',
    icon: Icons.how_to_reg_outlined,
  ),
  // ── Listings ───────────────────────────────────────────────────────────────
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
    icon: Icons.fact_check_outlined,
  ),
  // ── Reports ────────────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'admin_tile_reports',
    permissionKeys: [PermissionKeys.reportsManage],
    route: AppRoutes.adminReports,
    counterKey: 'openReports',
    icon: Icons.flag_outlined,
  ),
  // ── Agencies ───────────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'admin_tile_agencies',
    permissionKeys: [
      PermissionKeys.agenciesView,
      PermissionKeys.agenciesApprove,
      PermissionKeys.agenciesSuspend,
    ],
    route: AppRoutes.adminAgencies,
    icon: Icons.business_outlined,
  ),
  // ── Inquiries ──────────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'dashboardTileInquiries',
    permissionKeys: [PermissionKeys.inquiriesViewAll],
    route: AppRoutes.adminInquiries,
    counterKey: 'newInquiries24h',
    icon: Icons.forum_outlined,
  ),
  // ── Locations ──────────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'locationsTileTitle',
    permissionKeys: [PermissionKeys.locationsManage],
    route: AppRoutes.locationsAdmin,
    icon: Icons.location_on_outlined,
  ),
  // ── Currencies ─────────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'adminHomeCurrenciesTile',
    permissionKeys: [PermissionKeys.currenciesManage],
    route: AppRoutes.currenciesAdmin,
    icon: Icons.currency_exchange,
  ),
  // ── Roles & Permissions (combined super-admin tile) ─────────────────────
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
    icon: Icons.shield_outlined,
  ),
  // ── Audit logs ─────────────────────────────────────────────────────────────
  // AppRoutes.adminAuditLogs was added in P2 (T020).
  DashboardSection(
    labelKey: 'dashboardTileAuditLogs',
    permissionKeys: [PermissionKeys.auditLogsView],
    route: AppRoutes.adminAuditLogs,
    icon: Icons.history_outlined,
  ),
  // ── Ads (coming soon) ──────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'dashboardTileAds',
    permissionKeys: [PermissionKeys.adsManage],
    state: DashboardSectionState.comingSoon,
    icon: Icons.campaign_outlined,
  ),
  // ── Settings (coming soon) ─────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'dashboardTileSettings',
    permissionKeys: [PermissionKeys.settingsManage],
    state: DashboardSectionState.comingSoon,
    icon: Icons.settings_outlined,
  ),
];
