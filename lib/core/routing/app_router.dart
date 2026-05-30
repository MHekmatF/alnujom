import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/suspended_page.dart';
import '../../features/currencies/presentation/pages/currencies_list_page.dart';
import '../../features/currencies/presentation/pages/currency_form_page.dart';
import '../../features/currencies/presentation/pages/exchange_rate_history_page.dart';
import '../../features/currencies/presentation/pages/set_exchange_rate_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/listing_details/presentation/pages/listing_details_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
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
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/reports/presentation/pages/my_reports_page.dart';
import '../../features/admin/reports/presentation/pages/reports_queue_page.dart';
import '../../features/agency/presentation/pages/agency_home_page.dart';
import '../../features/admin/agencies/presentation/pages/agency_queue_page.dart';
import '../../features/inquiries/presentation/pages/admin_inquiry_oversight_page.dart';
import '../../features/inquiries/presentation/pages/inquiry_detail_page.dart';
import '../../features/inquiries/presentation/pages/inquiry_inbox_page.dart';
import '../../features/map/domain/entities/map_entry_context.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
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
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const profilePrivate = '/profile/private';
  static const publisherListingsCreate = '/publisher/listings/create';
  static const publisherListingsEdit = '/publisher/listings/:id/edit';
  static const publisherMyListings = '/publisher/dashboard/my-listings';
  static const publisherApprovalPending = '/publisher/pending-approval';
  static const publisherListingsModerationHistory =
      '/publisher/listings/:id/moderation-history';
  // Phase 13 FR-010: listing details deep-link route.
  static const listingDetails = '/listings/:id';
  // Phase 14 FR-001 / FR-010: public search & filters route.
  static const search = '/search';
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
  // Phase 19: public agency profile deep-link (no auth redirect).
  static const agencyProfile = '/agency/:id';
  // Phase 19: admin agency verification queue route.
  static const adminAgencies = '/admin/agencies';
  static const themeGallery = '/_debug/theme-gallery';
  static const debugMoneyFormatter = '/debug/money-formatter';

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
  static const profile = 'profile';
  static const profileEdit = 'profile-edit';
  static const profilePrivate = 'profile-private';
  static const publisherListingsCreate = 'publisher-listings-create';
  static const publisherListingsEdit = 'publisher-listings-edit';
  static const publisherMyListings = 'publisher-my-listings';
  static const publisherApprovalPending = 'publisher-pending-approval';
  static const publisherListingsModerationHistory =
      'publisher-listings-moderation-history';
  // Phase 13 FR-010: listing details deep-link route name.
  static const listingDetails = 'listing-details';
  // Phase 14 FR-001 / FR-010: public search & filters route name.
  static const search = 'search';
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
  // Phase 19: public agency profile route name.
  static const agencyProfile = 'agency-profile';
  // Phase 19: admin agency verification queue route name.
  static const adminAgencies = 'admin-agencies';
  static const themeGallery = 'theme-gallery';
}

GoRouter buildAppRouter({
  required AppLogger logger,
  required AuthBloc authBloc,
}) {
  final refreshListenable = AuthBlocListenable(authBloc);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshListenable,
    redirect: (context, state) => authRedirect(authBloc, context, state),
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
        ],
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: AppRouteNames.resetPassword,
        builder: (context, state) => const ResetPasswordPage(),
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
        builder: (context, state) =>
            SearchPage(initialPropertyType: state.extra as PropertyType?),
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
      // Phase 8/9: register agencyProfile/members/listings/analytics/verify GoRoutes
      // when their pages land (those pages do not exist until Phase 8/9).

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
