import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../debug/theme_gallery_page.dart';
import '../../features/admin/account_approvals/presentation/pages/account_approvals_page.dart';
import '../../features/admin/listing_review/presentation/pages/listing_preview_page.dart';
import '../../features/admin/listing_review/presentation/pages/pending_queue_page.dart';
import '../../features/admin/presentation/pages/admin_home_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/pending_approval_page.dart';
import '../../features/auth/presentation/pages/publisher_approval_pending_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/rejected_page.dart';
import '../../features/auth/presentation/pages/reset_password_complete_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/suspended_page.dart';
import '../../features/chat/presentation/bloc/conversations_cubit.dart';
import '../../features/chat/presentation/pages/conversations_list_page.dart';
import '../../features/currencies/presentation/pages/currencies_list_page.dart';
import '../../features/currencies/presentation/pages/currency_form_page.dart';
import '../../features/currencies/presentation/pages/exchange_rate_history_page.dart';
import '../../features/currencies/presentation/pages/set_exchange_rate_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/listing_details/presentation/pages/listing_details_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/profile/presentation/pages/account_deletion_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_private_page.dart';
import '../../features/currencies/presentation/pages/money_formatter_showcase_page.dart';
import '../../features/locations/presentation/pages/city_detail_page.dart';
import '../../features/locations/presentation/pages/governorate_detail_page.dart';
import '../../features/locations/presentation/pages/location_form_page.dart';
import '../../features/locations/presentation/pages/location_picker_smoke_test_page.dart';
import '../../features/locations/presentation/pages/locations_list_page.dart';
import '../../features/listing_form/domain/entities/listing.dart';
import '../../features/listing_form/domain/entities/listing_form_state.dart';
import '../../features/listing_form/presentation/pages/listing_form_page.dart';
import '../../features/listing_form/presentation/pages/revision_status_page.dart';
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/reports/presentation/pages/my_reports_page.dart';
import '../../features/admin/reports/presentation/pages/reports_queue_page.dart';
import '../../features/agency/presentation/pages/agency_home_page.dart';
import '../../features/agency/presentation/pages/agency_invitations_page.dart';
import '../../features/agency/presentation/pages/agency_profile_page.dart';
import '../../features/agency/presentation/pages/agency_members_page.dart';
import '../../features/agency/presentation/pages/agency_listings_page.dart';
import '../../features/agency/presentation/pages/agency_analytics_page.dart';
import '../../features/agency/presentation/pages/agency_verification_page.dart';
import '../../features/agency/presentation/pages/agency_edit_profile_page.dart';
import '../../features/agency/domain/entities/agency.dart';
import '../../features/admin/agencies/presentation/pages/agency_queue_page.dart';
import '../../features/notifications/presentation/pages/notification_center_page.dart';
import '../../features/admin/audit_logs/presentation/pages/audit_logs_viewer_page.dart';
import '../../features/ads/admin/presentation/pages/ads_list_page.dart';
import '../../features/settings/admin/presentation/pages/app_settings_editor_page.dart';
import '../../features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart';
import '../../features/inquiries/presentation/pages/inquiry_detail_page.dart';
import '../../features/inquiries/presentation/pages/inquiry_inbox_page.dart';
import '../../features/map/domain/entities/map_entry_context.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/assistant/presentation/pages/assistant_page.dart';
import '../../features/reels/presentation/pages/reels_tab_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/viewings/presentation/cubit/viewings_cubit.dart';
import '../../features/viewings/presentation/pages/viewings_list_page.dart';
import '../../features/search/presentation/pages/saved_searches_page.dart';
import '../../features/search/domain/entities/filter_state.dart';
import '../../features/publisher_dashboard/presentation/pages/publisher_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_entry_page.dart';
import '../../features/settings/presentation/bloc/app_settings_cubit.dart';
import '../../features/settings/presentation/pages/about_support_page.dart';
import '../../features/settings/presentation/pages/maintenance_screen.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/widgets/maintenance_gate.dart';
import '../../features/publisher_dashboard/presentation/pages/listing_moderation_history_page.dart';
import '../../features/publisher_dashboard/presentation/pages/my_listings_page.dart';
import '../../features/super_admin/presentation/pages/assign_role_page.dart';
import '../../features/super_admin/presentation/pages/create_role_page.dart';
import '../../features/super_admin/presentation/pages/role_editor_page.dart';
import '../../features/super_admin/presentation/pages/roles_list_page.dart';
import '../di/injection.dart';
import '../flags/app_flags.dart';
import '../logging/app_logger.dart';
import '../security/permission_checker.dart';
import 'auth_redirect.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const pending = '/pending';
  static const rejected = '/rejected';
  static const suspended = '/suspended';
  // Phase 13 FR-008: '/' is the public home feed (was '/home' in Phase 5 era).
  static const home = '/';
  // Interim back-compat alias per R-69 — remove after all consumers migrate.
  static const shellHome = home;
  static const admin = '/admin';
  static const adminApprovals = '/admin/approvals';
  static const superAdminRoles = '/admin/super-admin/roles';
  static const superAdminRoleCreate = '/admin/super-admin/roles/create';
  static const superAdminAssign = '/admin/super-admin/assign';
  static const adminListingReviewPending = '/admin/listing-review/pending';
  static const adminListingReviewPreview = '/admin/listing-review/preview/:id';
  static const locationsAdmin = '/admin/locations';
  static const locationsAdminForm = '/admin/locations/form';
  static const currenciesAdmin = '/admin/currencies';
  static const currenciesAdminSetRate = '/admin/currencies/set-rate';
  static const currenciesAdminForm = '/admin/currencies/form';
  static const resetPassword = '/reset-password';
  // Spec 005 D-01 — password-reset COMPLETION screen. Deliberately mirrors the
  // `alnujom://auth/reset-password` recovery deep link (scheme `alnujom`, host
  // `auth`, path `/reset-password`) so the two never drift apart.
  static const resetPasswordComplete = '/auth/reset-password';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const profilePrivate = '/profile/private';
  // Self-serve account deletion (Google Play in-app deletion requirement).
  static const accountDelete = '/profile/delete-account';
  static const publisherListingsCreate = '/publisher/listings/create';
  static const publisherListingsEdit = '/publisher/listings/:id/edit';
  static const publisherListingsRevisionStatus =
      '/publisher/listings/:id/revision';
  static const publisherMyListings = '/publisher/dashboard/my-listings';
  static const publisherApprovalPending = '/publisher/pending-approval';
  static const publisherListingsModerationHistory =
      '/publisher/listings/:id/moderation-history';
  // Phase 13 FR-010: listing details deep-link route.
  static const listingDetails = '/listings/:id';
  // Phase 14 FR-001 / FR-010: public search & filters route.
  static const search = '/search';
  // Phase 28 — smart search assistant (anonymous-accessible, mirrors /search).
  static const assistant = '/assistant';
  // Phase 030 (W4) — Reels bottom-nav tab (replaced /search as a tab;
  // anonymous-accessible, mirrors /search — no redirect).
  static const reels = '/reels';
  // Phase 15 FR-007: public map view route.
  static const map = '/map';
  // Phase 16 FR-001: publisher inquiry inbox route.
  static const inquiries = '/inquiries';
  // Phase 16 FR-001: per-inquiry detail route (path template).
  static const inquiryDetail = '/inquiries/:id';
  // Phase 16 US7: admin inquiry oversight route.
  static const adminInquiries = '/admin/inquiries';
  // Phase 17 FR-020: authenticated favorites page route.
  static const favorites = '/favorites';
  // Phase 035: authenticated Messages (chat) tab route.
  static const chat = '/chat';
  // Plan A16 — the viewings list. It had no route at all: the drawer pushed
  // the page directly, which meant a `viewing_requested` notification had
  // nowhere to navigate to. Auth-gated exactly like /chat.
  static const viewings = '/viewings';
  // Phase 18 FR-022: authenticated My-Reports page route.
  static const reports = '/reports';
  // Phase 18 FR-019: admin moderation queue route.
  static const adminReports = '/admin/reports';
  // Phase 19: agency self-service routes (auth-required).
  static const agency = '/agency';
  static const agencyMembers = '/agency/members';
  static const agencyListings = '/agency/listings';
  static const agencyAnalytics = '/agency/analytics';
  static const agencyVerify = '/agency/verify';
  static const agencyEdit = '/agency/edit';
  // Spec 019 B-4 / 022 §6 — the `agency_invitation` deep-link target. A
  // dedicated screen so an invitee can never be dropped on the hub's default
  // "create an agency" form (see agency_invitations_page.dart).
  static const agencyInvitations = '/agency/invitations';
  // Phase 19: public agency profile deep-link (no auth redirect).
  static const agencyProfile = '/agency/:id';
  // Phase 19: admin agency verification queue route.
  static const adminAgencies = '/admin/agencies';
  // Phase 20: admin read-only audit-log viewer route.
  static const adminAuditLogs = '/admin/audit-logs';
  // Phase 21: admin ads CRUD surface route.
  static const adminAds = '/admin/ads';
  // Phase 22: notification center route (authenticated).
  static const notifications = '/notifications';
  // Phase 23: admin settings editor route.
  static const adminSettings = '/admin/settings';
  // Phase 23 FC — full-screen maintenance gate target (settings.manage bypass).
  static const maintenance = maintenanceRoute;
  // Phase 23 FC — public about/support surface (FR-013).
  static const about = '/about';
  // Phase 035: unified user settings screen.
  static const settings = '/settings';
  static const themeGallery = '/_debug/theme-gallery';
  static const debugMoneyFormatter = '/debug/money-formatter';
  // Phase 25 uplift v2 — saved searches + role-aware dashboard.
  static const savedSearches = '/saved-searches';
  static const publisherDashboard = '/publisher/dashboard';
  static const dashboard = '/dashboard';

  /// Phase 13 FR-010 helper — resolves Wave 2 F1 finding (no more literal
  /// string interpolation in [HomeListingCardTile]).
  static String listingDetailsFor(String id) => '/listings/$id';

  /// Phase 16 FR-001 helper — resolves per-inquiry detail path.
  static String inquiryDetailFor(String id) => '/inquiries/$id';
}

abstract final class AppRouteNames {
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const register = 'register';
  static const pending = 'pending';
  static const rejected = 'rejected';
  static const suspended = 'suspended';
  // Phase 13 FR-008: canonical name for the public home feed route.
  static const home = 'home';
  // Interim back-compat alias per R-69 — remove after all consumers migrate.
  static const shellHome = home;
  static const admin = 'admin';
  static const adminApprovals = 'admin-approvals';
  static const superAdminRoles = 'super-admin-roles';
  static const superAdminRoleEditor = 'super-admin-role-editor';
  static const superAdminRoleCreate = 'super-admin-role-create';
  static const superAdminAssign = 'super-admin-assign';
  static const adminListingReviewPending = 'admin-listing-review-pending';
  static const adminListingReviewPreview = 'admin-listing-review-preview';
  static const locationsAdmin = 'locations-admin';
  static const locationsAdminGovernorateDetail =
      'locations-admin-governorate-detail';
  static const locationsAdminCityDetail = 'locations-admin-city-detail';
  static const locationsAdminForm = 'locations-admin-form';
  static const currenciesAdmin = 'currencies-admin';
  static const currenciesAdminSetRate = 'currencies-admin-set-rate';
  static const currenciesAdminHistory = 'currencies-admin-history';
  static const currenciesAdminForm = 'currencies-admin-form';
  static const resetPassword = 'reset-password';
  // Spec 005 D-01 — password-reset completion route name.
  static const resetPasswordComplete = 'reset-password-complete';
  static const profile = 'profile';
  static const profileEdit = 'profile-edit';
  static const profilePrivate = 'profile-private';
  // Self-serve account deletion route name.
  static const accountDelete = 'account-delete';
  static const publisherListingsCreate = 'publisher-listings-create';
  static const publisherListingsEdit = 'publisher-listings-edit';
  static const publisherListingsRevisionStatus =
      'publisher-listings-revision-status';
  static const publisherMyListings = 'publisher-my-listings';
  static const publisherApprovalPending = 'publisher-pending-approval';
  static const publisherListingsModerationHistory =
      'publisher-listings-moderation-history';
  // Phase 13 FR-010: listing details deep-link route name.
  static const listingDetails = 'listing-details';
  // Phase 14 FR-001 / FR-010: public search & filters route name.
  static const search = 'search';
  // Phase 28 — smart search assistant route name.
  static const assistant = 'assistant';
  // Phase 030 (W4) — Reels bottom-nav tab route name.
  static const reels = 'reels';
  // Phase 25 uplift v2 — saved searches + role-aware dashboard route names.
  static const savedSearches = 'saved-searches';
  static const publisherDashboard = 'publisher-dashboard';
  static const dashboard = 'dashboard';
  // Phase 15 FR-007: public map view route name.
  static const map = 'map';
  // Phase 16 FR-001: publisher inquiry inbox route name.
  static const inquiries = 'inquiries';
  // Phase 16 FR-001: per-inquiry detail route name.
  static const inquiryDetail = 'inquiry-detail';
  // Phase 16 US7: admin inquiry oversight route name.
  static const adminInquiries = 'admin-inquiries';
  // Phase 17 FR-020: authenticated favorites page route name.
  static const favorites = 'favorites';
  // Phase 035: authenticated Messages (chat) tab route name.
  static const chat = 'chat';
  // Plan A16 — viewings list route name.
  static const viewings = 'viewings';
  // Phase 18 FR-022: authenticated My-Reports page route name.
  static const reports = 'reports';
  // Phase 18 FR-019: admin moderation queue route name.
  static const adminReports = 'admin-reports';
  // Phase 19: agency self-service route names.
  static const agency = 'agency';
  static const agencyMembers = 'agency-members';
  static const agencyListings = 'agency-listings';
  static const agencyAnalytics = 'agency-analytics';
  static const agencyVerify = 'agency-verify';
  static const agencyEdit = 'agency-edit';
  // Spec 019 B-4 / 022 §6 — agency invitations route name.
  static const agencyInvitations = 'agency-invitations';
  // Phase 19: public agency profile route name.
  static const agencyProfile = 'agency-profile';
  // Phase 19: admin agency verification queue route name.
  static const adminAgencies = 'admin-agencies';
  // Phase 20: admin read-only audit-log viewer route name.
  static const adminAuditLogs = 'admin-audit-logs';
  // Phase 21: admin ads CRUD surface route name.
  static const adminAds = 'admin-ads';
  // Phase 22: notification center route name.
  static const notifications = 'notifications';
  // Phase 23: admin settings editor route name.
  static const adminSettings = 'admin-settings';
  // Phase 23 FC — maintenance gate + about/support route names.
  static const maintenance = 'maintenance';
  static const about = 'about';
  // Phase 035: settings screen route name.
  static const settings = 'settings';
  static const themeGallery = 'theme-gallery';
}

/// Root navigator key for the app's [GoRouter].
///
/// Needed to show app-wide dialogs/overlays from a context that sits ABOVE the
/// route Navigator — e.g. the Phase 24 update prompt, which is triggered from
/// the `MaterialApp.router` `builder` (whose context has no Navigator below it).
/// `rootNavigatorKey.currentContext` resolves to the GoRouter root Navigator,
/// so `showDialog` can attach correctly.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigator',
);

GoRouter buildAppRouter({
  required AppLogger logger,
  required AuthBloc authBloc,
}) {
  // Phase 23 (FC) — re-evaluate redirects on BOTH auth changes AND settings
  // changes, so the maintenance gate reacts when maintenance flips on/off.
  final refreshListenable = Listenable.merge([
    AuthBlocListenable(authBloc),
    StreamRefreshListenable(getIt<AppSettingsCubit>().stream),
  ]);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshListenable,
    // Phase 23 (FC / T024) — maintenance gate runs FIRST. When maintenance is
    // active it sends everyone to MaintenanceScreen EXCEPT `settings.manage`
    // holders (the only bypass — INVARIANT 1). Reads the cached AppSettings
    // snapshot synchronously (no fetch here). On a settings fetch failure the
    // cubit serves safe defaults (maintenance OFF), so this returns null —
    // fail-open (INVARIANT 2). Auth redirects run only when the gate allows.
    redirect: (context, state) {
      final gated = maintenanceRedirect(state.uri.path);
      if (gated != null) return gated;
      return authRedirect(authBloc, context, state);
    },
    routes: [
      // ─── Phase 5 auth routes ───
      GoRoute(
        path: AppRoutes.splash,
        name: AppRouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRouteNames.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRouteNames.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.pending,
        name: AppRouteNames.pending,
        builder: (context, state) => const PendingApprovalPage(),
      ),
      GoRoute(
        path: AppRoutes.rejected,
        name: AppRouteNames.rejected,
        builder: (context, state) => const RejectedPage(),
      ),
      GoRoute(
        path: AppRoutes.suspended,
        name: AppRouteNames.suspended,
        builder: (context, state) => const SuspendedPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRouteNames.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        name: AppRouteNames.admin,
        builder: (context, state) => const AdminHomePage(),
        routes: [
          GoRoute(
            path: 'approvals',
            name: AppRouteNames.adminApprovals,
            builder: (context, state) => const AccountApprovalsPage(),
          ),
          GoRoute(
            path: 'listing-review/pending',
            name: AppRouteNames.adminListingReviewPending,
            redirect: requireListingReviewRedirect,
            builder: (context, state) => const PendingQueuePage(),
          ),
          GoRoute(
            path: 'listing-review/preview/:id',
            name: AppRouteNames.adminListingReviewPreview,
            redirect: requireListingReviewRedirect,
            builder: (context, state) =>
                ListingPreviewPage(listingId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'super-admin/roles',
            name: AppRouteNames.superAdminRoles,
            redirect: requireSuperAdminRedirect,
            builder: (context, state) => const RolesListPage(),
            routes: [
              GoRoute(
                path: 'create',
                name: AppRouteNames.superAdminRoleCreate,
                redirect: requireSuperAdminRedirect,
                builder: (context, state) => const CreateRolePage(),
              ),
              GoRoute(
                path: ':roleId',
                name: AppRouteNames.superAdminRoleEditor,
                redirect: requireSuperAdminRedirect,
                builder: (context, state) =>
                    RoleEditorPage(roleId: state.pathParameters['roleId']!),
              ),
            ],
          ),
          GoRoute(
            path: 'super-admin/assign',
            name: AppRouteNames.superAdminAssign,
            redirect: requireSuperAdminRedirect,
            builder: (context, state) => const AssignRolePage(),
          ),
          GoRoute(
            path: 'locations',
            name: AppRouteNames.locationsAdmin,
            redirect: requireLocationsManageRedirect,
            builder: (context, state) => const LocationsListPage(),
            routes: [
              GoRoute(
                path: 'form',
                name: AppRouteNames.locationsAdminForm,
                redirect: requireLocationsManageRedirect,
                builder: (context, state) => const LocationFormPage(),
              ),
              GoRoute(
                path: ':governorateId',
                name: AppRouteNames.locationsAdminGovernorateDetail,
                redirect: requireLocationsManageRedirect,
                builder: (context, state) => GovernorateDetailPage(
                  governorateId: state.pathParameters['governorateId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'cities/:cityId',
                    name: AppRouteNames.locationsAdminCityDetail,
                    redirect: requireLocationsManageRedirect,
                    builder: (context, state) => CityDetailPage(
                      governorateId: state.pathParameters['governorateId']!,
                      cityId: state.pathParameters['cityId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'currencies',
            name: AppRouteNames.currenciesAdmin,
            redirect: requireCurrenciesManageRedirect,
            builder: (context, state) => const CurrenciesListPage(),
            routes: [
              GoRoute(
                path: 'set-rate',
                name: AppRouteNames.currenciesAdminSetRate,
                redirect: requireCurrenciesManageRedirect,
                builder: (context, state) => SetExchangeRatePage(
                  initialBaseCurrencyCode: state.uri.queryParameters['base'],
                ),
              ),
              GoRoute(
                path: ':code/history',
                name: AppRouteNames.currenciesAdminHistory,
                redirect: requireCurrenciesManageRedirect,
                builder: (context, state) => ExchangeRateHistoryPage(
                  baseCurrencyCode: state.pathParameters['code']!,
                ),
              ),
              GoRoute(
                path: 'form',
                name: AppRouteNames.currenciesAdminForm,
                redirect: requireCurrenciesManageRedirect,
                builder: (context, state) => CurrencyFormPage(
                  mode: state.uri.queryParameters['mode'] ?? 'create',
                  code: state.uri.queryParameters['code'],
                ),
              ),
            ],
          ),
          // ─── Phase 18 — admin moderation queue ───
          // Gated by `reports.manage` permission (FR-019).
          GoRoute(
            path: 'reports',
            name: AppRouteNames.adminReports,
            redirect: requireReportsManageRedirect,
            builder: (context, state) => const ReportsQueuePage(),
          ),
          // ─── Phase 19 — admin agency verification queue ───
          // Gated by agencies.view / agencies.approve / agencies.suspend (FR-006).
          GoRoute(
            path: 'agencies',
            name: AppRouteNames.adminAgencies,
            redirect: requireAgenciesManageRedirect,
            builder: (context, state) => const AgencyQueuePage(),
          ),
          // ─── Phase 20 — admin read-only audit-log viewer ───
          // Gated by `audit_logs.view` permission (FR-021); the swapped
          // audit_logs RLS policy (20260601120004) re-checks at the wire.
          GoRoute(
            path: 'audit-logs',
            name: AppRouteNames.adminAuditLogs,
            redirect: requireAuditLogsViewRedirect,
            builder: (context, state) => const AuditLogsViewerPage(),
          ),
          // ─── Phase 21 — admin ads CRUD surface ───
          // Gated by `ads.manage` permission (FR-022).
          GoRoute(
            path: 'ads',
            name: AppRouteNames.adminAds,
            redirect: requireAdsManageRedirect,
            builder: (context, state) => const AdsListPage(),
          ),
          // ─── Phase 23 — admin settings editor ───
          // Gated by `settings.manage` permission (FR-001).
          GoRoute(
            path: 'settings',
            name: AppRouteNames.adminSettings,
            redirect: requireSettingsManageRedirect,
            builder: (context, state) => const AppSettingsEditorPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: AppRouteNames.resetPassword,
        builder: (context, state) => const ResetPasswordPage(),
      ),
      // ─── Spec 005 D-01 — password-reset completion ───
      // Entered programmatically by [PasswordRecoveryListener] once the
      // recovery deep link produced a session. `authRedirect` lets this path
      // through in EVERY auth state (see the bypass there): the recovery
      // session is a real session, so the account-status gates would otherwise
      // bounce a pending/suspended user off the screen mid-reset.
      GoRoute(
        path: AppRoutes.resetPasswordComplete,
        name: AppRouteNames.resetPasswordComplete,
        builder: (context, state) => const ResetPasswordCompletePage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: AppRouteNames.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        name: AppRouteNames.profileEdit,
        builder: (context, state) => const ProfileEditPage(),
      ),
      GoRoute(
        path: AppRoutes.profilePrivate,
        name: AppRouteNames.profilePrivate,
        builder: (context, state) => const ProfilePrivatePage(),
      ),
      GoRoute(
        // Self-serve account deletion. Not in `_publicPaths`, so the auth
        // redirect already bounces signed-out visitors to /login.
        path: AppRoutes.accountDelete,
        name: AppRouteNames.accountDelete,
        builder: (context, state) => const AccountDeletionPage(),
      ),
      GoRoute(
        path: AppRoutes.publisherListingsCreate,
        name: AppRouteNames.publisherListingsCreate,
        redirect: requirePublisherStatusRedirect,
        builder: (context, state) =>
            const ListingFormPage(mode: ListingFormMode.create),
      ),
      GoRoute(
        path: AppRoutes.publisherListingsEdit,
        name: AppRouteNames.publisherListingsEdit,
        redirect: requirePublisherStatusRedirect,
        builder: (context, state) => ListingFormPage(
          mode: ListingFormMode.edit,
          listingId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.publisherListingsRevisionStatus,
        name: AppRouteNames.publisherListingsRevisionStatus,
        redirect: requirePublisherStatusRedirect,
        builder: (context, state) =>
            RevisionStatusPage(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.publisherMyListings,
        name: AppRouteNames.publisherMyListings,
        redirect: requirePublisherStatusRedirect,
        builder: (context, state) => const MyListingsPage(),
      ),
      GoRoute(
        path: AppRoutes.publisherApprovalPending,
        name: AppRouteNames.publisherApprovalPending,
        builder: (context, state) => const PublisherApprovalPendingPage(),
      ),
      // Phase 12 / US6 — publisher moderation history page.
      // Owner-only access enforced server-side by Phase 10's RLS on
      // listing_status_history (publisher_user_id = auth.uid()).
      GoRoute(
        path: AppRoutes.publisherListingsModerationHistory,
        name: AppRouteNames.publisherListingsModerationHistory,
        redirect: requirePublisherLoginRedirect,
        builder: (context, state) => ListingModerationHistoryPage(
          listingId: state.pathParameters['id']!,
        ),
      ),

      // ─── Phase 13 — public listing details ───
      GoRoute(
        path: AppRoutes.listingDetails,
        name: AppRouteNames.listingDetails,
        builder: (context, state) =>
            ListingDetailsPage(id: state.pathParameters['id']!),
      ),

      // ─── Phase 14 — public search & filters ───
      // Anonymous-accessible per FR-015. `state.extra` carries a
      // PropertyType when the user enters via a Home property-type chip
      // (R-80); null when entered via the hero search bar.
      GoRoute(
        path: AppRoutes.search,
        name: AppRouteNames.search,
        builder: (context, state) {
          // `extra` may be a PropertyType (Home chip), a FilterState (re-applied
          // saved search), or null (hero search bar).
          final extra = state.extra;
          return SearchPage(
            initialPropertyType: extra is PropertyType ? extra : null,
            initialFilters: extra is FilterState ? extra : null,
            // Phase 25: only the Home hero search pill requests keyboard focus
            // (via `?focus=1`); tab/filter/ad/chip entries browse without it.
            autofocus: state.uri.queryParameters['focus'] == '1',
          );
        },
      ),
      // ─── Phase 28 — smart search assistant ───
      // Anonymous-accessible (mirrors /search): pure on-device parsing; the
      // optional market-stats RPC is anon-granted server-side.
      GoRoute(
        path: AppRoutes.assistant,
        name: AppRouteNames.assistant,
        builder: (context, state) => const AssistantPage(),
      ),
      // ─── Phase 030 (W4) — Reels bottom-nav tab ───
      // Anonymous-accessible (mirrors /search): no redirect. Renders the
      // persistent Reels tab (its own ReelsFeedCubit + the bottom nav).
      GoRoute(
        path: AppRoutes.reels,
        name: AppRouteNames.reels,
        builder: (context, state) => const ReelsTabPage(),
      ),
      // ─── Phase 25 uplift v2 — saved searches ───
      GoRoute(
        path: AppRoutes.savedSearches,
        name: AppRouteNames.savedSearches,
        builder: (context, state) => const SavedSearchesPage(),
      ),
      // ─── Phase 25 uplift v2 — role-aware dashboard ───
      // No in-app caller, deliberately kept. `/dashboard` below is the entry
      // point everything actually taps — it is role-aware and renders THIS
      // page for an approved publisher. This route stays because it is the
      // canonical publisher-dashboard URL, it is documented as such in
      // specs/035 and specs/010, and it is the path prefix of
      // `/publisher/dashboard/my-listings`, which is used. Removing it would
      // break any deep link to it for no gain. (Noted during the route sweep
      // of 2026-09-02.)
      GoRoute(
        path: AppRoutes.publisherDashboard,
        name: AppRouteNames.publisherDashboard,
        redirect: requirePublisherStatusRedirect,
        builder: (context, state) => const PublisherDashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: AppRouteNames.dashboard,
        redirect: (context, state) =>
            authBloc.state is Unauthenticated ? AppRoutes.login : null,
        builder: (context, state) => const DashboardEntryPage(),
      ),

      // ─── Phase 15 — public map view ───
      // Anonymous-accessible per FR-006. `state.extra` carries a
      // MapEntryContext (FromHome / FromListing / FromSearch); null when
      // navigated to directly (e.g., deep-link cold-launch).
      GoRoute(
        path: AppRoutes.map,
        name: AppRouteNames.map,
        builder: (context, state) =>
            MapPage(entryContext: state.extra as MapEntryContext?),
      ),

      // ─── Phase 16 — publisher inquiry inbox ───
      // Authenticated publishers; the BLoC (Sub-Phase E) enforces RLS.
      GoRoute(
        path: AppRoutes.inquiries,
        name: AppRouteNames.inquiries,
        builder: (context, state) => const InquiryInboxPage(),
      ),

      // ─── Phase 16 — per-inquiry detail ───
      GoRoute(
        path: AppRoutes.inquiryDetail,
        name: AppRouteNames.inquiryDetail,
        builder: (context, state) =>
            InquiryDetailPage(id: state.pathParameters['id']!),
      ),

      // ─── Phase 16 — admin inquiry oversight ───
      // Gated by 'inquiries.view_all' permission; redirects to home otherwise.
      GoRoute(
        path: AppRoutes.adminInquiries,
        name: AppRouteNames.adminInquiries,
        redirect: (context, state) =>
            getIt<PermissionChecker>().has('inquiries.view_all')
            ? null
            : AppRoutes.home,
        builder: (context, state) => const AdminInquiryOversightPage(),
      ),

      // ─── Phase 17 — authenticated favorites page ───
      // Requires sign-in (R-115); anonymous deep-links redirect to /login.
      GoRoute(
        path: AppRoutes.favorites,
        name: AppRouteNames.favorites,
        redirect: (context, state) =>
            authBloc.state is Unauthenticated ? AppRoutes.login : null,
        builder: (context, state) => const FavoritesPage(),
      ),

      // ─── Phase 035 — authenticated Messages (chat) tab ───
      // Requires sign-in; anonymous deep-links redirect to /login (mirrors
      // favorites). Provides the ConversationsCubit above the list page.
      GoRoute(
        path: AppRoutes.chat,
        name: AppRouteNames.chat,
        redirect: (context, state) =>
            authBloc.state is Unauthenticated ? AppRoutes.login : null,
        builder: (context, state) => BlocProvider<ConversationsCubit>(
          create: (_) => getIt<ConversationsCubit>(),
          child: const ConversationsListPage(),
        ),
      ),

      // ─── Plan A16 — authenticated viewings list ───
      // Requires sign-in; anonymous deep-links redirect to /login (mirrors
      // /chat). Exists so the viewing notifications have somewhere to land —
      // before this the page was only reachable by pushing it from the drawer.
      GoRoute(
        path: AppRoutes.viewings,
        name: AppRouteNames.viewings,
        redirect: (context, state) =>
            authBloc.state is Unauthenticated ? AppRoutes.login : null,
        builder: (context, state) => BlocProvider<ViewingsCubit>(
          create: (_) => getIt<ViewingsCubit>(),
          child: const ViewingsListPage(),
        ),
      ),

      // ─── Phase 18 — authenticated My-Reports page ───
      // Requires sign-in (FR-022); anonymous deep-links redirect to /login.
      GoRoute(
        path: AppRoutes.reports,
        name: AppRouteNames.reports,
        redirect: (context, state) =>
            authBloc.state is Unauthenticated ? AppRoutes.login : null,
        builder: (context, state) => const MyReportsPage(),
      ),

      // ─── Phase 19 — agency self-service hub ───
      // Requires sign-in; anonymous deep-links redirect to /login (mirrors Phase 17/18).
      GoRoute(
        path: AppRoutes.agency,
        name: AppRouteNames.agency,
        redirect: (context, state) =>
            authBloc.state is Unauthenticated ? AppRoutes.login : null,
        builder: (context, state) => const AgencyHomePage(),
      ),
      // Phase 19 (T056/T057/T058) — agency self-service management pages.
      // Declared BEFORE the public `/agency/:id` so the literal segments
      // (members/listings/analytics/verify) win over the `:id` wildcard.
      // `state.extra` carries the Agency (members) or its id (others).
      GoRoute(
        path: AppRoutes.agencyMembers,
        name: AppRouteNames.agencyMembers,
        // B-5: `extra` is not part of the URI, so it is null after process
        // recreation (e.g. a low-RAM device returning from an external
        // activity). Bounce to the hub instead of red-screening on the
        // `state.extra as Agency` cast in the builder.
        redirect: (context, state) => authBloc.state is Unauthenticated
            ? AppRoutes.login
            : (state.extra == null ? AppRoutes.agency : null),
        builder: (context, state) =>
            AgencyMembersPage(agency: state.extra as Agency),
      ),
      GoRoute(
        path: AppRoutes.agencyListings,
        name: AppRouteNames.agencyListings,
        redirect: (context, state) =>
            authBloc.state
                is Unauthenticated // B-5
            ? AppRoutes.login
            : (state.extra == null ? AppRoutes.agency : null),
        builder: (context, state) =>
            AgencyListingsPage(agencyId: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.agencyAnalytics,
        name: AppRouteNames.agencyAnalytics,
        redirect: (context, state) =>
            authBloc.state
                is Unauthenticated // B-5
            ? AppRoutes.login
            : (state.extra == null ? AppRoutes.agency : null),
        builder: (context, state) =>
            AgencyAnalyticsPage(agencyId: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.agencyVerify,
        name: AppRouteNames.agencyVerify,
        redirect: (context, state) =>
            authBloc.state
                is Unauthenticated // B-5
            ? AppRoutes.login
            : (state.extra == null ? AppRoutes.agency : null),
        builder: (context, state) =>
            AgencyVerificationPage(agencyId: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.agencyEdit,
        name: AppRouteNames.agencyEdit,
        redirect: (context, state) =>
            authBloc.state is Unauthenticated ? AppRoutes.login : null,
        builder: (context, state) => const AgencyEditProfilePage(),
      ),
      // Spec 019 B-4 / 022 §6 — pending agency invitations (accept / decline).
      // The `agency_invitation` notification routes HERE instead of the
      // `/agency` hub, whose default branch is the "create an agency" form:
      // an invitee whose reads came back empty (typically the cold-start race
      // between the push tap and the Supabase session restore) was left on the
      // create form with no path to Accept. Carries no `extra`, so it survives
      // process recreation. Declared BEFORE `/agency/:id` so the literal
      // segment wins over the wildcard.
      GoRoute(
        path: AppRoutes.agencyInvitations,
        name: AppRouteNames.agencyInvitations,
        redirect: (context, state) =>
            authBloc.state is Unauthenticated ? AppRoutes.login : null,
        builder: (context, state) => const AgencyInvitationsPage(),
      ),
      // Public agency profile (no auth redirect; approved-only enforced by the
      // page + v_agencies). Declared LAST so the literal routes above win.
      GoRoute(
        path: AppRoutes.agencyProfile,
        name: AppRouteNames.agencyProfile,
        builder: (context, state) =>
            AgencyProfilePage(agencyId: state.pathParameters['id']!),
      ),

      // ─── Phase 22 — notification center ───
      // Requires sign-in; anonymous deep-links redirect to /login (FR-006).
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRouteNames.notifications,
        redirect: (context, state) =>
            authBloc.state is Unauthenticated ? AppRoutes.login : null,
        builder: (context, state) => const NotificationCenterPage(),
      ),

      // ─── Phase 23 — maintenance gate target ───
      // Anonymous-accessible; the global redirect routes non-`settings.manage`
      // users here while maintenance is active (FR-009/FR-011).
      GoRoute(
        path: AppRoutes.maintenance,
        name: AppRouteNames.maintenance,
        builder: (context, state) => const MaintenanceScreen(),
      ),

      // ─── Phase 23 — public about/support surface ───
      // Anonymous-accessible (FR-013); renders only configured channels/links.
      GoRoute(
        path: AppRoutes.about,
        name: AppRouteNames.about,
        builder: (context, state) => const AboutSupportPage(),
      ),

      // ─── Phase 035 — unified user settings (anonymous-accessible, pushed) ──
      GoRoute(
        path: AppRoutes.settings,
        name: AppRouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),

      if (kDesignToolsEnabled)
        GoRoute(
          path: AppRoutes.themeGallery,
          name: AppRouteNames.themeGallery,
          builder: (context, state) => const ThemeGalleryPage(),
        ),
      ...(kDebugMode
          ? [
              GoRoute(
                path: '/dev/locations-picker',
                builder: (_, __) => const LocationPickerSmokeTestPage(),
              ),
              GoRoute(
                path: '/debug/money-formatter',
                builder: (_, __) => const MoneyFormatterShowcasePage(),
              ),
            ]
          : <RouteBase>[]),
    ],
    errorBuilder: (context, state) {
      logger.warning(
        'Unknown route: ${state.uri}',
        error: state.error,
        tag: 'AppRouter',
      );
      return Scaffold(
        body: Center(child: Text(state.error?.toString() ?? 'Unknown route')),
      );
    },
  );
}
