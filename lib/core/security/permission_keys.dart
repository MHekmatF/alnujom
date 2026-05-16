/// Mirror of the 24 seeded permissions.key values from §9.1.
/// Hand-maintained (R-19) — when a future spec adds or removes a permission key
/// via migration, this file MUST be updated in the same PR.
abstract class PermissionKeys {
  PermissionKeys._();

  // Users category
  static const String usersView = 'users.view';
  static const String usersApprove = 'users.approve';
  static const String usersReject = 'users.reject';
  static const String usersSuspend = 'users.suspend';

  // Listings category
  static const String listingsViewAll = 'listings.view_all';
  static const String listingsApprove = 'listings.approve';
  static const String listingsReject = 'listings.reject';
  static const String listingsEditAny = 'listings.edit_any';
  static const String listingsDeleteAny = 'listings.delete_any';

  // Roles category
  static const String rolesView = 'roles.view';
  static const String rolesCreate = 'roles.create';
  static const String rolesUpdate = 'roles.update';
  static const String rolesDelete = 'roles.delete';
  static const String permissionsManage = 'permissions.manage';

  // Locations / Currencies / Ads / Reports
  static const String locationsManage = 'locations.manage';
  static const String currenciesManage = 'currencies.manage';
  static const String adsManage = 'ads.manage';
  static const String reportsManage = 'reports.manage';

  // Agencies category
  static const String agenciesView = 'agencies.view';
  static const String agenciesApprove = 'agencies.approve';
  static const String agenciesSuspend = 'agencies.suspend';

  // Settings / Audit / Inquiries
  static const String settingsManage = 'settings.manage';
  static const String auditLogsView = 'audit_logs.view';
  static const String inquiriesViewAll = 'inquiries.view_all';

  /// Every admin-category permission key.
  /// Used by the main-navigation admin-tile visibility check:
  ///   `PermissionChecker.any(PermissionKeys.adminCategoryKeys)`
  static const Set<String> adminCategoryKeys = <String>{
    usersView,
    usersApprove,
    usersReject,
    usersSuspend,
    listingsViewAll,
    listingsApprove,
    listingsReject,
    listingsEditAny,
    listingsDeleteAny,
    rolesView,
    rolesCreate,
    rolesUpdate,
    rolesDelete,
    permissionsManage,
    locationsManage,
    currenciesManage,
    adsManage,
    reportsManage,
    agenciesView,
    agenciesApprove,
    agenciesSuspend,
    settingsManage,
    auditLogsView,
    inquiriesViewAll,
  };

  /// Phase 7: keys that gate the super-admin tile on AdminHomePage.
  /// Currently { rolesView, rolesCreate, rolesUpdate, rolesDelete, permissionsManage }.
  static const Set<String> superAdminCategoryKeys = <String>{
    rolesView,
    rolesCreate,
    rolesUpdate,
    rolesDelete,
    permissionsManage,
  };
}
