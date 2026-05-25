// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:ui' as _i264;

import 'package:get_it/get_it.dart' as _i174;
import 'package:go_router/go_router.dart' as _i583;
import 'package:injectable/injectable.dart' as _i526;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

import '../../features/admin/account_approvals/data/datasources/supabase_account_approvals_datasource.dart'
    as _i394;
import '../../features/admin/account_approvals/data/repositories/account_approvals_repository_impl.dart'
    as _i278;
import '../../features/admin/account_approvals/domain/repositories/account_approvals_repository.dart'
    as _i120;
import '../../features/admin/account_approvals/domain/usecases/approve_account.dart'
    as _i858;
import '../../features/admin/account_approvals/domain/usecases/load_pending_queue.dart'
    as _i138;
import '../../features/admin/account_approvals/domain/usecases/reject_account.dart'
    as _i431;
import '../../features/admin/account_approvals/presentation/cubit/account_approvals_cubit.dart'
    as _i295;
import '../../features/admin/listing_review/data/datasources/supabase_listing_review_datasource.dart'
    as _i530;
import '../../features/admin/listing_review/data/repositories/listing_review_repository_impl.dart'
    as _i1072;
import '../../features/admin/listing_review/domain/repositories/listing_review_repository.dart'
    as _i155;
import '../../features/admin/listing_review/domain/usecases/approve_listing.dart'
    as _i404;
import '../../features/admin/listing_review/domain/usecases/load_listing_preview.dart'
    as _i96;
import '../../features/admin/listing_review/domain/usecases/load_pending_queue.dart'
    as _i207;
import '../../features/admin/listing_review/domain/usecases/reject_listing.dart'
    as _i880;
import '../../features/admin/listing_review/presentation/bloc/listing_preview_bloc.dart'
    as _i778;
import '../../features/admin/listing_review/presentation/bloc/pending_queue_bloc.dart'
    as _i554;
import '../../features/auth/data/datasources/supabase_auth_datasource.dart'
    as _i76;
import '../../features/auth/data/repositories/auth_repository_impl.dart'
    as _i153;
import '../../features/auth/domain/repositories/auth_repository.dart' as _i787;
import '../../features/auth/presentation/bloc/auth_bloc.dart' as _i797;
import '../../features/currencies/data/datasources/supabase_currencies_datasource.dart'
    as _i311;
import '../../features/currencies/data/repositories/currencies_repository_impl.dart'
    as _i148;
import '../../features/currencies/domain/repositories/currencies_repository.dart'
    as _i505;
import '../../features/currencies/domain/usecases/count_dependent_exchange_rates.dart'
    as _i905;
import '../../features/currencies/domain/usecases/create_currency.dart'
    as _i1003;
import '../../features/currencies/domain/usecases/delete_currency.dart' as _i43;
import '../../features/currencies/domain/usecases/list_currencies.dart'
    as _i996;
import '../../features/currencies/domain/usecases/list_exchange_rate_history.dart'
    as _i776;
import '../../features/currencies/domain/usecases/load_currency_detail.dart'
    as _i510;
import '../../features/currencies/domain/usecases/load_latest_rates_for_base.dart'
    as _i957;
import '../../features/currencies/domain/usecases/set_exchange_rate.dart'
    as _i488;
import '../../features/currencies/domain/usecases/update_currency.dart'
    as _i540;
import '../../features/currencies/presentation/bloc/currencies_list_bloc.dart'
    as _i176;
import '../../features/currencies/presentation/bloc/currency_form_bloc.dart'
    as _i657;
import '../../features/currencies/presentation/bloc/exchange_rate_history_bloc.dart'
    as _i949;
import '../../features/currencies/presentation/bloc/set_exchange_rate_bloc.dart'
    as _i293;
import '../../features/home/data/datasources/supabase_home_feed_datasource.dart'
    as _i732;
import '../../features/home/data/repositories/home_feed_repository_impl.dart'
    as _i857;
import '../../features/home/domain/repositories/home_feed_repository.dart'
    as _i433;
import '../../features/home/domain/usecases/load_home_feed.dart' as _i321;
import '../../features/home/presentation/bloc/home_bloc.dart' as _i202;
import '../../features/listing_details/data/datasources/supabase_listing_details_datasource.dart'
    as _i1006;
import '../../features/listing_details/data/repositories/listing_details_repository_impl.dart'
    as _i677;
import '../../features/listing_details/domain/repositories/listing_details_repository.dart'
    as _i895;
import '../../features/listing_details/domain/usecases/load_listing_details.dart'
    as _i281;
import '../../features/listing_details/presentation/bloc/listing_details_bloc.dart'
    as _i935;
import '../../features/listing_form/data/datasources/supabase_listing_media_datasource.dart'
    as _i214;
import '../../features/listing_form/data/datasources/supabase_listings_datasource.dart'
    as _i207;
import '../../features/listing_form/data/repositories/listings_repository_impl.dart'
    as _i946;
import '../../features/listing_form/domain/repositories/listings_repository.dart'
    as _i340;
import '../../features/listing_form/domain/usecases/delete_draft.dart' as _i814;
import '../../features/listing_form/domain/usecases/delete_media.dart' as _i732;
import '../../features/listing_form/domain/usecases/derive_area_centroid.dart'
    as _i906;
import '../../features/listing_form/domain/usecases/load_media_for_listing.dart'
    as _i406;
import '../../features/listing_form/domain/usecases/load_or_create_draft.dart'
    as _i802;
import '../../features/listing_form/domain/usecases/reorder_media.dart'
    as _i1022;
import '../../features/listing_form/domain/usecases/save_form_step.dart'
    as _i874;
import '../../features/listing_form/domain/usecases/set_main_image.dart'
    as _i629;
import '../../features/listing_form/domain/usecases/submit_listing.dart'
    as _i829;
import '../../features/listing_form/domain/usecases/upload_image.dart'
    as _i1062;
import '../../features/listing_form/domain/usecases/upload_video.dart' as _i490;
import '../../features/listing_form/domain/usecases/validate_submit_payload.dart'
    as _i396;
import '../../features/listing_form/presentation/bloc/listing_form_bloc.dart'
    as _i315;
import '../../features/locations/data/datasources/supabase_locations_datasource.dart'
    as _i665;
import '../../features/locations/data/repositories/locations_repository_impl.dart'
    as _i178;
import '../../features/locations/domain/repositories/locations_repository.dart'
    as _i704;
import '../../features/locations/domain/usecases/count_city_dependents.dart'
    as _i655;
import '../../features/locations/domain/usecases/count_governorate_dependents.dart'
    as _i58;
import '../../features/locations/domain/usecases/create_area.dart' as _i880;
import '../../features/locations/domain/usecases/create_city.dart' as _i206;
import '../../features/locations/domain/usecases/create_governorate.dart'
    as _i1027;
import '../../features/locations/domain/usecases/delete_area.dart' as _i662;
import '../../features/locations/domain/usecases/delete_city.dart' as _i239;
import '../../features/locations/domain/usecases/delete_governorate.dart'
    as _i937;
import '../../features/locations/domain/usecases/list_areas_for_city.dart'
    as _i358;
import '../../features/locations/domain/usecases/list_cities_for_governorate.dart'
    as _i53;
import '../../features/locations/domain/usecases/list_governorates.dart'
    as _i533;
import '../../features/locations/domain/usecases/load_area_detail.dart'
    as _i292;
import '../../features/locations/domain/usecases/load_city_detail.dart'
    as _i645;
import '../../features/locations/domain/usecases/load_governorate_detail.dart'
    as _i441;
import '../../features/locations/domain/usecases/update_area.dart' as _i188;
import '../../features/locations/domain/usecases/update_city.dart' as _i1058;
import '../../features/locations/domain/usecases/update_governorate.dart'
    as _i1054;
import '../../features/locations/presentation/bloc/city_detail_bloc.dart'
    as _i1073;
import '../../features/locations/presentation/bloc/governorate_detail_bloc.dart'
    as _i796;
import '../../features/locations/presentation/bloc/location_form_bloc.dart'
    as _i419;
import '../../features/locations/presentation/bloc/location_picker_bloc.dart'
    as _i610;
import '../../features/locations/presentation/bloc/locations_list_bloc.dart'
    as _i669;
import '../../features/map/data/datasources/supabase_map_datasource.dart'
    as _i245;
import '../../features/map/data/repositories/map_repository_impl.dart' as _i457;
import '../../features/map/domain/repositories/map_repository.dart' as _i973;
import '../../features/map/domain/usecases/load_map_markers.dart' as _i842;
import '../../features/map/presentation/bloc/map_bloc.dart' as _i437;
import '../../features/onboarding/data/datasources/onboarding_seen_storage.dart'
    as _i144;
import '../../features/onboarding/data/repositories/onboarding_repository_impl.dart'
    as _i452;
import '../../features/onboarding/domain/repositories/onboarding_repository.dart'
    as _i430;
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart'
    as _i807;
import '../../features/profile/data/datasources/supabase_profile_datasource.dart'
    as _i825;
import '../../features/profile/data/repositories/profile_repository_impl.dart'
    as _i334;
import '../../features/profile/domain/repositories/profile_repository.dart'
    as _i894;
import '../../features/profile/domain/usecases/load_assigned_roles.dart'
    as _i941;
import '../../features/profile/domain/usecases/load_pii.dart' as _i363;
import '../../features/profile/domain/usecases/load_profile.dart' as _i1052;
import '../../features/profile/domain/usecases/update_pii.dart' as _i281;
import '../../features/profile/domain/usecases/update_profile.dart' as _i78;
import '../../features/profile/presentation/cubit/profile_cubit.dart' as _i36;
import '../../features/publisher_dashboard/data/datasources/supabase_publisher_dashboard_datasource.dart'
    as _i333;
import '../../features/publisher_dashboard/data/repositories/publisher_dashboard_repository_impl.dart'
    as _i240;
import '../../features/publisher_dashboard/domain/repositories/publisher_dashboard_repository.dart'
    as _i754;
import '../../features/publisher_dashboard/domain/usecases/list_my_listings.dart'
    as _i891;
import '../../features/publisher_dashboard/domain/usecases/load_moderation_history.dart'
    as _i919;
import '../../features/publisher_dashboard/domain/usecases/load_most_recent_rejection.dart'
    as _i564;
import '../../features/publisher_dashboard/presentation/bloc/moderation_history_cubit.dart'
    as _i711;
import '../../features/publisher_dashboard/presentation/bloc/my_listings_bloc.dart'
    as _i417;
import '../../features/search/data/datasources/supabase_search_datasource.dart'
    as _i713;
import '../../features/search/data/repositories/search_repository_impl.dart'
    as _i1017;
import '../../features/search/domain/repositories/search_repository.dart'
    as _i357;
import '../../features/search/domain/usecases/search_listings_usecase.dart'
    as _i190;
import '../../features/search/presentation/bloc/search_bloc.dart' as _i552;
import '../../features/super_admin/data/datasources/supabase_role_catalog_datasource.dart'
    as _i1064;
import '../../features/super_admin/data/datasources/supabase_user_search_datasource.dart'
    as _i24;
import '../../features/super_admin/data/repositories/role_catalog_repository_impl.dart'
    as _i564;
import '../../features/super_admin/data/repositories/user_search_repository_impl.dart'
    as _i884;
import '../../features/super_admin/domain/repositories/role_catalog_repository.dart'
    as _i681;
import '../../features/super_admin/domain/repositories/user_search_repository.dart'
    as _i765;
import '../../features/super_admin/domain/usecases/assign_role_to_user.dart'
    as _i650;
import '../../features/super_admin/domain/usecases/delete_role.dart' as _i1036;
import '../../features/super_admin/domain/usecases/list_roles.dart' as _i1018;
import '../../features/super_admin/domain/usecases/load_affected_user_count.dart'
    as _i702;
import '../../features/super_admin/domain/usecases/load_permission_catalog.dart'
    as _i518;
import '../../features/super_admin/domain/usecases/load_role_detail.dart'
    as _i176;
import '../../features/super_admin/domain/usecases/load_role_user_ids.dart'
    as _i144;
import '../../features/super_admin/domain/usecases/load_user_assignments.dart'
    as _i646;
import '../../features/super_admin/domain/usecases/mutate_role.dart' as _i315;
import '../../features/super_admin/domain/usecases/revoke_role_from_user.dart'
    as _i950;
import '../../features/super_admin/domain/usecases/search_users.dart' as _i143;
import '../../features/super_admin/presentation/bloc/assign_role_bloc.dart'
    as _i669;
import '../../features/super_admin/presentation/bloc/role_editor_bloc.dart'
    as _i885;
import '../../features/super_admin/presentation/bloc/roles_list_bloc.dart'
    as _i329;
import '../config/env_config.dart' as _i373;
import '../data/repositories/permission_catalog_repository_impl.dart' as _i739;
import '../localization/locale_cubit.dart' as _i960;
import '../logging/app_logger.dart' as _i354;
import '../logging/console_logger.dart' as _i1026;
import '../network/supabase_client_wrapper.dart' as _i752;
import '../network/supabase_client_wrapper_impl.dart' as _i748;
import '../security/permission_catalog_repository.dart' as _i1015;
import '../security/permission_checker.dart' as _i650;
import '../storage/preferences_store.dart' as _i753;
import '../storage/secure_preferences_store.dart' as _i190;
import '../theme/palette_cubit.dart' as _i394;
import '../theme/theme_cubit.dart' as _i611;
import 'injection.dart' as _i464;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt $initGetIt(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final supabaseModule = _$SupabaseModule();
  final routerModule = _$RouterModule();
  gh.factory<_i207.SupabaseListingsDatasource>(
    () => _i207.SupabaseListingsDatasource(),
  );
  gh.factory<_i214.SupabaseListingMediaDatasource>(
    () => _i214.SupabaseListingMediaDatasource(),
  );
  gh.factory<_i396.ValidateSubmitPayload>(
    () => const _i396.ValidateSubmitPayload(),
  );
  gh.factory<_i665.SupabaseLocationsDatasource>(
    () => _i665.SupabaseLocationsDatasource(),
  );
  gh.singleton<_i373.EnvConfig>(() => const _i373.EnvConfig());
  gh.lazySingleton<_i454.SupabaseClient>(() => supabaseModule.supabaseClient());
  gh.lazySingleton<_i394.SupabaseAccountApprovalsDatasource>(
    () => _i394.SupabaseAccountApprovalsDatasource(),
  );
  gh.lazySingleton<_i825.SupabaseProfileDataSource>(
    () => _i825.SupabaseProfileDataSource(),
  );
  gh.lazySingleton<_i1064.SupabaseRoleCatalogDataSource>(
    () => _i1064.SupabaseRoleCatalogDataSource(),
  );
  gh.lazySingleton<_i24.SupabaseUserSearchDataSource>(
    () => _i24.SupabaseUserSearchDataSource(),
  );
  gh.lazySingleton<_i1015.PermissionCatalogRepository>(
    () => _i739.PermissionCatalogRepositoryImpl(),
  );
  gh.lazySingleton<_i340.ListingsRepository>(
    () => _i946.ListingsRepositoryImpl(
      gh<_i207.SupabaseListingsDatasource>(),
      gh<_i214.SupabaseListingMediaDatasource>(),
    ),
  );
  gh.lazySingleton<_i650.PermissionChecker>(
    () => _i650.PermissionChecker(gh<_i1015.PermissionCatalogRepository>()),
  );
  gh.lazySingleton<_i354.AppLogger>(() => _i1026.ConsoleLogger());
  gh.factory<_i530.SupabaseListingReviewDatasource>(
    () => _i530.SupabaseListingReviewDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i311.SupabaseCurrenciesDatasource>(
    () => _i311.SupabaseCurrenciesDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i732.SupabaseHomeFeedDatasource>(
    () => _i732.SupabaseHomeFeedDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i1006.SupabaseListingDetailsDatasource>(
    () => _i1006.SupabaseListingDetailsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i333.SupabasePublisherDashboardDatasource>(
    () =>
        _i333.SupabasePublisherDashboardDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i713.SupabaseSearchDatasource>(
    () => _i713.SupabaseSearchDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i245.SupabaseMapDatasource>(
    () => _i245.SupabaseMapDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i973.MapRepository>(
    () => _i457.MapRepositoryImpl(gh<_i245.SupabaseMapDatasource>()),
  );
  gh.lazySingleton<_i155.ListingReviewRepository>(
    () => _i1072.ListingReviewRepositoryImpl(
      gh<_i530.SupabaseListingReviewDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i814.DeleteDraft>(
    () => _i814.DeleteDraft(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i732.DeleteMedia>(
    () => _i732.DeleteMedia(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i406.LoadMediaForListing>(
    () => _i406.LoadMediaForListing(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i802.LoadOrCreateDraft>(
    () => _i802.LoadOrCreateDraft(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i1022.ReorderMedia>(
    () => _i1022.ReorderMedia(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i874.SaveFormStep>(
    () => _i874.SaveFormStep(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i629.SetMainImage>(
    () => _i629.SetMainImage(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i829.SubmitListing>(
    () => _i829.SubmitListing(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i1062.UploadImage>(
    () => _i1062.UploadImage(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i490.UploadVideo>(
    () => _i490.UploadVideo(gh<_i340.ListingsRepository>()),
  );
  gh.lazySingleton<_i681.RoleCatalogRepository>(
    () => _i564.RoleCatalogRepositoryImpl(
      gh<_i1064.SupabaseRoleCatalogDataSource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i120.AccountApprovalsRepository>(
    () => _i278.AccountApprovalsRepositoryImpl(
      gh<_i394.SupabaseAccountApprovalsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i357.SearchRepository>(
    () => _i1017.SearchRepositoryImpl(gh<_i713.SupabaseSearchDatasource>()),
  );
  gh.lazySingleton<_i753.PreferencesStore>(
    () => _i190.SecurePreferencesStore(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i894.ProfileRepository>(
    () => _i334.ProfileRepositoryImpl(
      gh<_i825.SupabaseProfileDataSource>(),
      gh<_i354.AppLogger>(),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.lazySingleton<_i704.LocationsRepository>(
    () => _i178.LocationsRepositoryImpl(
      gh<_i665.SupabaseLocationsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i76.SupabaseAuthDataSource>(
    () => _i76.SupabaseAuthDataSource(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i144.OnboardingSeenStorage>(
    () => _i144.OnboardingSeenStorage(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i752.SupabaseClientWrapper>(
    () => _i748.SupabaseClientWrapperImpl(gh<_i354.AppLogger>()),
  );
  gh.factory<_i190.SearchListingsUseCase>(
    () => _i190.SearchListingsUseCase(gh<_i357.SearchRepository>()),
  );
  gh.factory<_i842.LoadMapMarkers>(
    () => _i842.LoadMapMarkers(gh<_i973.MapRepository>()),
  );
  gh.lazySingleton<_i430.OnboardingRepository>(
    () => _i452.OnboardingRepositoryImpl(gh<_i144.OnboardingSeenStorage>()),
  );
  gh.factory<_i941.LoadAssignedRoles>(
    () => _i941.LoadAssignedRoles(gh<_i894.ProfileRepository>()),
  );
  gh.factory<_i363.LoadPii>(() => _i363.LoadPii(gh<_i894.ProfileRepository>()));
  gh.factory<_i1052.LoadProfile>(
    () => _i1052.LoadProfile(gh<_i894.ProfileRepository>()),
  );
  gh.factory<_i281.UpdatePii>(
    () => _i281.UpdatePii(gh<_i894.ProfileRepository>()),
  );
  gh.factory<_i78.UpdateProfile>(
    () => _i78.UpdateProfile(gh<_i894.ProfileRepository>()),
  );
  gh.lazySingleton<_i505.CurrenciesRepository>(
    () => _i148.CurrenciesRepositoryImpl(
      gh<_i311.SupabaseCurrenciesDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i765.UserSearchRepository>(
    () => _i884.UserSearchRepositoryImpl(
      gh<_i24.SupabaseUserSearchDataSource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i787.AuthRepository>(
    () => _i153.AuthRepositoryImpl(
      gh<_i76.SupabaseAuthDataSource>(),
      gh<_i894.ProfileRepository>(),
      gh<_i354.AppLogger>(),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.factory<_i404.ApproveListingUseCase>(
    () => _i404.ApproveListingUseCase(gh<_i155.ListingReviewRepository>()),
  );
  gh.factory<_i96.LoadListingPreviewUseCase>(
    () => _i96.LoadListingPreviewUseCase(gh<_i155.ListingReviewRepository>()),
  );
  gh.factory<_i207.LoadPendingQueueUseCase>(
    () => _i207.LoadPendingQueueUseCase(gh<_i155.ListingReviewRepository>()),
  );
  gh.factory<_i880.RejectListingUseCase>(
    () => _i880.RejectListingUseCase(gh<_i155.ListingReviewRepository>()),
  );
  gh.lazySingleton<_i754.PublisherDashboardRepository>(
    () => _i240.PublisherDashboardRepositoryImpl(
      gh<_i333.SupabasePublisherDashboardDatasource>(),
    ),
  );
  gh.lazySingleton<_i797.AuthBloc>(
    () => _i797.AuthBloc(
      gh<_i787.AuthRepository>(),
      gh<_i894.ProfileRepository>(),
      gh<_i650.PermissionChecker>(),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.lazySingleton<_i433.HomeFeedRepository>(
    () => _i857.HomeFeedRepositoryImpl(gh<_i732.SupabaseHomeFeedDatasource>()),
  );
  gh.lazySingleton<_i895.ListingDetailsRepository>(
    () => _i677.ListingDetailsRepositoryImpl(
      gh<_i1006.SupabaseListingDetailsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i891.ListMyListings>(
    () => _i891.ListMyListings(gh<_i754.PublisherDashboardRepository>()),
  );
  gh.factory<_i919.LoadModerationHistoryUseCase>(
    () => _i919.LoadModerationHistoryUseCase(
      gh<_i754.PublisherDashboardRepository>(),
    ),
  );
  gh.factory<_i564.LoadMostRecentRejectionUseCase>(
    () => _i564.LoadMostRecentRejectionUseCase(
      gh<_i754.PublisherDashboardRepository>(),
    ),
  );
  gh.factory<_i1036.DeleteRole>(
    () => _i1036.DeleteRole(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i1018.ListRoles>(
    () => _i1018.ListRoles(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i702.LoadAffectedUserCount>(
    () => _i702.LoadAffectedUserCount(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i518.LoadPermissionCatalog>(
    () => _i518.LoadPermissionCatalog(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i176.LoadRoleDetail>(
    () => _i176.LoadRoleDetail(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i144.LoadRoleUserIds>(
    () => _i144.LoadRoleUserIds(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i315.MutateRole>(
    () => _i315.MutateRole(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i655.CountCityDependents>(
    () => _i655.CountCityDependents(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i58.CountGovernorateDependents>(
    () => _i58.CountGovernorateDependents(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i880.CreateArea>(
    () => _i880.CreateArea(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i206.CreateCity>(
    () => _i206.CreateCity(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i1027.CreateGovernorate>(
    () => _i1027.CreateGovernorate(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i662.DeleteArea>(
    () => _i662.DeleteArea(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i239.DeleteCity>(
    () => _i239.DeleteCity(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i937.DeleteGovernorate>(
    () => _i937.DeleteGovernorate(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i358.ListAreasForCity>(
    () => _i358.ListAreasForCity(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i53.ListCitiesForGovernorate>(
    () => _i53.ListCitiesForGovernorate(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i533.ListGovernorates>(
    () => _i533.ListGovernorates(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i292.LoadAreaDetail>(
    () => _i292.LoadAreaDetail(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i645.LoadCityDetail>(
    () => _i645.LoadCityDetail(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i441.LoadGovernorateDetail>(
    () => _i441.LoadGovernorateDetail(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i188.UpdateArea>(
    () => _i188.UpdateArea(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i1058.UpdateCity>(
    () => _i1058.UpdateCity(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i1054.UpdateGovernorate>(
    () => _i1054.UpdateGovernorate(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i711.ModerationHistoryCubit>(
    () =>
        _i711.ModerationHistoryCubit(gh<_i919.LoadModerationHistoryUseCase>()),
  );
  gh.factory<_i905.CountDependentExchangeRates>(
    () => _i905.CountDependentExchangeRates(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i1003.CreateCurrency>(
    () => _i1003.CreateCurrency(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i43.DeleteCurrency>(
    () => _i43.DeleteCurrency(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i996.ListCurrencies>(
    () => _i996.ListCurrencies(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i776.ListExchangeRateHistory>(
    () => _i776.ListExchangeRateHistory(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i510.LoadCurrencyDetail>(
    () => _i510.LoadCurrencyDetail(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i488.SetExchangeRate>(
    () => _i488.SetExchangeRate(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i540.UpdateCurrency>(
    () => _i540.UpdateCurrency(gh<_i505.CurrenciesRepository>()),
  );
  gh.lazySingleton<_i957.LoadLatestRatesForBase>(
    () => _i957.LoadLatestRatesForBase(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i858.ApproveAccount>(
    () => _i858.ApproveAccount(gh<_i120.AccountApprovalsRepository>()),
  );
  gh.factory<_i138.LoadPendingQueue>(
    () => _i138.LoadPendingQueue(gh<_i120.AccountApprovalsRepository>()),
  );
  gh.factory<_i431.RejectAccount>(
    () => _i431.RejectAccount(gh<_i120.AccountApprovalsRepository>()),
  );
  gh.factory<_i650.AssignRoleToUser>(
    () => _i650.AssignRoleToUser(gh<_i765.UserSearchRepository>()),
  );
  gh.factory<_i646.LoadUserAssignments>(
    () => _i646.LoadUserAssignments(gh<_i765.UserSearchRepository>()),
  );
  gh.factory<_i950.RevokeRoleFromUser>(
    () => _i950.RevokeRoleFromUser(gh<_i765.UserSearchRepository>()),
  );
  gh.factory<_i143.SearchUsers>(
    () => _i143.SearchUsers(gh<_i765.UserSearchRepository>()),
  );
  gh.factoryParam<_i960.LocaleCubit, _i264.Locale?, dynamic>(
    (initialLocale, _) => _i960.LocaleCubit(
      gh<_i753.PreferencesStore>(),
      gh<_i354.AppLogger>(),
      initialLocale,
    ),
  );
  gh.factory<_i552.SearchBloc>(
    () => _i552.SearchBloc(gh<_i190.SearchListingsUseCase>()),
  );
  gh.factory<_i778.ListingPreviewBloc>(
    () => _i778.ListingPreviewBloc(
      gh<_i96.LoadListingPreviewUseCase>(),
      gh<_i404.ApproveListingUseCase>(),
      gh<_i880.RejectListingUseCase>(),
    ),
  );
  gh.factory<_i394.PaletteCubit>(
    () =>
        _i394.PaletteCubit(gh<_i753.PreferencesStore>(), gh<_i354.AppLogger>()),
  );
  gh.factory<_i611.ThemeCubit>(
    () => _i611.ThemeCubit(gh<_i753.PreferencesStore>(), gh<_i354.AppLogger>()),
  );
  gh.factory<_i295.AccountApprovalsCubit>(
    () => _i295.AccountApprovalsCubit(
      gh<_i138.LoadPendingQueue>(),
      gh<_i858.ApproveAccount>(),
      gh<_i431.RejectAccount>(),
    ),
  );
  gh.factory<_i906.DeriveAreaCentroid>(
    () => _i906.DeriveAreaCentroid(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i36.ProfileCubit>(
    () => _i36.ProfileCubit(
      gh<_i1052.LoadProfile>(),
      gh<_i78.UpdateProfile>(),
      gh<_i363.LoadPii>(),
      gh<_i281.UpdatePii>(),
      gh<_i941.LoadAssignedRoles>(),
    ),
  );
  gh.factory<_i1073.CityDetailBloc>(
    () => _i1073.CityDetailBloc(
      gh<_i645.LoadCityDetail>(),
      gh<_i441.LoadGovernorateDetail>(),
      gh<_i358.ListAreasForCity>(),
    ),
  );
  gh.factory<_i669.AssignRoleBloc>(
    () => _i669.AssignRoleBloc(
      gh<_i143.SearchUsers>(),
      gh<_i646.LoadUserAssignments>(),
      gh<_i650.AssignRoleToUser>(),
      gh<_i950.RevokeRoleFromUser>(),
      gh<_i1018.ListRoles>(),
    ),
  );
  gh.factory<_i419.LocationFormBloc>(
    () => _i419.LocationFormBloc(
      gh<_i441.LoadGovernorateDetail>(),
      gh<_i645.LoadCityDetail>(),
      gh<_i292.LoadAreaDetail>(),
      gh<_i1027.CreateGovernorate>(),
      gh<_i1054.UpdateGovernorate>(),
      gh<_i206.CreateCity>(),
      gh<_i1058.UpdateCity>(),
      gh<_i880.CreateArea>(),
      gh<_i188.UpdateArea>(),
    ),
  );
  gh.factory<_i807.OnboardingCubit>(
    () => _i807.OnboardingCubit(gh<_i430.OnboardingRepository>()),
  );
  gh.factory<_i554.PendingQueueBloc>(
    () => _i554.PendingQueueBloc(gh<_i207.LoadPendingQueueUseCase>()),
  );
  gh.factory<_i176.CurrenciesListBloc>(
    () => _i176.CurrenciesListBloc(
      gh<_i996.ListCurrencies>(),
      gh<_i957.LoadLatestRatesForBase>(),
    ),
  );
  gh.lazySingleton<_i583.GoRouter>(
    () => routerModule.router(gh<_i354.AppLogger>(), gh<_i797.AuthBloc>()),
  );
  gh.factory<_i293.SetExchangeRateBloc>(
    () => _i293.SetExchangeRateBloc(gh<_i488.SetExchangeRate>()),
  );
  gh.factory<_i437.MapBloc>(() => _i437.MapBloc(gh<_i842.LoadMapMarkers>()));
  gh.factory<_i885.RoleEditorBloc>(
    () => _i885.RoleEditorBloc(
      gh<_i176.LoadRoleDetail>(),
      gh<_i518.LoadPermissionCatalog>(),
      gh<_i315.MutateRole>(),
    ),
  );
  gh.factory<_i329.RolesListBloc>(
    () => _i329.RolesListBloc(gh<_i1018.ListRoles>()),
  );
  gh.factory<_i417.MyListingsBloc>(
    () => _i417.MyListingsBloc(gh<_i891.ListMyListings>()),
  );
  gh.factory<_i321.LoadHomeFeed>(
    () => _i321.LoadHomeFeed(gh<_i433.HomeFeedRepository>()),
  );
  gh.factory<_i949.ExchangeRateHistoryBloc>(
    () => _i949.ExchangeRateHistoryBloc(gh<_i776.ListExchangeRateHistory>()),
  );
  gh.factory<_i796.GovernorateDetailBloc>(
    () => _i796.GovernorateDetailBloc(
      gh<_i441.LoadGovernorateDetail>(),
      gh<_i53.ListCitiesForGovernorate>(),
    ),
  );
  gh.factory<_i610.LocationPickerBloc>(
    () => _i610.LocationPickerBloc(
      gh<_i533.ListGovernorates>(),
      gh<_i53.ListCitiesForGovernorate>(),
      gh<_i358.ListAreasForCity>(),
    ),
  );
  gh.factory<_i281.LoadListingDetails>(
    () => _i281.LoadListingDetails(gh<_i895.ListingDetailsRepository>()),
  );
  gh.factory<_i669.LocationsListBloc>(
    () => _i669.LocationsListBloc(gh<_i533.ListGovernorates>()),
  );
  gh.factory<_i657.CurrencyFormBloc>(
    () => _i657.CurrencyFormBloc(
      gh<_i1003.CreateCurrency>(),
      gh<_i540.UpdateCurrency>(),
      gh<_i510.LoadCurrencyDetail>(),
    ),
  );
  gh.factory<_i315.ListingFormBloc>(
    () => _i315.ListingFormBloc(
      gh<_i802.LoadOrCreateDraft>(),
      gh<_i874.SaveFormStep>(),
      gh<_i829.SubmitListing>(),
      gh<_i814.DeleteDraft>(),
      gh<_i906.DeriveAreaCentroid>(),
      gh<_i396.ValidateSubmitPayload>(),
      gh<_i340.ListingsRepository>(),
      gh<_i1062.UploadImage>(),
      gh<_i490.UploadVideo>(),
      gh<_i1022.ReorderMedia>(),
      gh<_i629.SetMainImage>(),
      gh<_i732.DeleteMedia>(),
      gh<_i406.LoadMediaForListing>(),
    ),
  );
  gh.factory<_i935.ListingDetailsBloc>(
    () => _i935.ListingDetailsBloc(
      gh<_i281.LoadListingDetails>(),
      gh<_i797.AuthBloc>(),
    ),
  );
  gh.factory<_i202.HomeBloc>(() => _i202.HomeBloc(gh<_i321.LoadHomeFeed>()));
  return getIt;
}

class _$SupabaseModule extends _i464.SupabaseModule {}

class _$RouterModule extends _i464.RouterModule {}
