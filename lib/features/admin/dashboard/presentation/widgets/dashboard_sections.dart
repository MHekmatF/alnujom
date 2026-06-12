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
import 'package:flutter_lucide/flutter_lucide.dart';

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
    icon: LucideIcons.user_check,
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
    icon: LucideIcons.clipboard_check,
  ),
  DashboardSection(
    labelKey: 'admin_tile_reports',
    permissionKeys: [PermissionKeys.reportsManage],
    route: AppRoutes.adminReports,
    counterKey: 'openReports',
    subtitleKey: 'adminSectionSubtitleReports',
    group: DashboardSectionGroup.moderation,
    icon: LucideIcons.flag,
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
    icon: LucideIcons.building_2,
  ),
  DashboardSection(
    labelKey: 'dashboardTileInquiries',
    permissionKeys: [PermissionKeys.inquiriesViewAll],
    route: AppRoutes.adminInquiries,
    counterKey: 'newInquiries24h',
    subtitleKey: 'adminSectionSubtitleInquiries',
    group: DashboardSectionGroup.moderation,
    icon: LucideIcons.message_square,
  ),
  // ── Configuration ───────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'locationsTileTitle',
    permissionKeys: [PermissionKeys.locationsManage],
    route: AppRoutes.locationsAdmin,
    subtitleKey: 'adminSectionSubtitleLocations',
    group: DashboardSectionGroup.configuration,
    icon: LucideIcons.map_pin,
  ),
  DashboardSection(
    labelKey: 'adminHomeCurrenciesTile',
    permissionKeys: [PermissionKeys.currenciesManage],
    route: AppRoutes.currenciesAdmin,
    subtitleKey: 'adminSectionSubtitleCurrencies',
    group: DashboardSectionGroup.configuration,
    icon: LucideIcons.coins,
  ),
  DashboardSection(
    labelKey: 'dashboardTileAds',
    permissionKeys: [PermissionKeys.adsManage],
    route: AppRoutes.adminAds,
    subtitleKey: 'adminSectionSubtitleAds',
    group: DashboardSectionGroup.configuration,
    icon: LucideIcons.megaphone,
  ),
  DashboardSection(
    labelKey: 'dashboardTileSettings',
    permissionKeys: [PermissionKeys.settingsManage],
    route: AppRoutes.adminSettings,
    subtitleKey: 'adminSectionSubtitleSettings',
    group: DashboardSectionGroup.configuration,
    icon: LucideIcons.settings,
  ),
  // ── Insights ────────────────────────────────────────────────────────────
  DashboardSection(
    labelKey: 'dashboardTileAuditLogs',
    permissionKeys: [PermissionKeys.auditLogsView],
    route: AppRoutes.adminAuditLogs,
    subtitleKey: 'adminSectionSubtitleAuditLogs',
    group: DashboardSectionGroup.insights,
    icon: LucideIcons.history,
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
    icon: LucideIcons.shield,
  ),
];
