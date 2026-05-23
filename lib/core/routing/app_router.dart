import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../debug/theme_gallery_page.dart';
import '../../features/admin/account_approvals/presentation/pages/account_approvals_page.dart';
import '../../features/admin/listing_review/presentation/pages/listing_preview_page.dart';
import '../../features/admin/listing_review/presentation/pages/pending_queue_page.dart';
import '../../features/admin/presentation/pages/admin_home_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
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
import '../../features/listing_form/domain/entities/listing_form_state.dart';
import '../../features/listing_form/presentation/pages/listing_form_page.dart';
import '../../features/publisher_dashboard/presentation/pages/listing_moderation_history_page.dart';
import '../../features/publisher_dashboard/presentation/pages/my_listings_page.dart';
import '../../features/super_admin/presentation/pages/assign_role_page.dart';
import '../../features/super_admin/presentation/pages/create_role_page.dart';
import '../../features/super_admin/presentation/pages/role_editor_page.dart';
import '../../features/super_admin/presentation/pages/roles_list_page.dart';
import '../../shell/shell_home_page.dart';
import '../flags/app_flags.dart';
import '../logging/app_logger.dart';
import 'auth_redirect.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const pending = '/pending';
  static const rejected = '/rejected';
  static const suspended = '/suspended';
  static const home = '/home';
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
  static const shellHome = '/';
  static const themeGallery = '/_debug/theme-gallery';
  static const debugMoneyFormatter = '/debug/money-formatter';
}

abstract final class AppRouteNames {
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const register = 'register';
  static const pending = 'pending';
  static const rejected = 'rejected';
  static const suspended = 'suspended';
  static const home = 'home';
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
  static const shellHome = 'shell-home';
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
            builder: (context, state) => ListingPreviewPage(
              listingId: state.pathParameters['id']!,
            ),
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

      // ─── Phase 1–4 legacy routes (kept for design tools) ───
      GoRoute(
        path: AppRoutes.shellHome,
        name: AppRouteNames.shellHome,
        builder: (context, state) => const ShellHomePage(),
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
