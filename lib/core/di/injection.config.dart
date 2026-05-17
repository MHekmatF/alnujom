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
import '../../features/auth/data/datasources/supabase_auth_datasource.dart'
    as _i76;
import '../../features/auth/data/repositories/auth_repository_impl.dart'
    as _i153;
import '../../features/auth/domain/repositories/auth_repository.dart' as _i787;
import '../../features/auth/presentation/bloc/auth_bloc.dart' as _i797;
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
  final routerModule = _$RouterModule();
  gh.factory<_i665.SupabaseLocationsDatasource>(
    () => _i665.SupabaseLocationsDatasource(),
  );
  gh.singleton<_i373.EnvConfig>(() => const _i373.EnvConfig());
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
  gh.lazySingleton<_i650.PermissionChecker>(
    () => _i650.PermissionChecker(gh<_i1015.PermissionCatalogRepository>()),
  );
  gh.lazySingleton<_i354.AppLogger>(() => _i1026.ConsoleLogger());
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
  gh.lazySingleton<_i797.AuthBloc>(
    () => _i797.AuthBloc(
      gh<_i787.AuthRepository>(),
      gh<_i894.ProfileRepository>(),
      gh<_i650.PermissionChecker>(),
    ),
    dispose: (i) => i.dispose(),
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
  gh.factory<_i292.LoadAreaDetail>(
    () => _i292.LoadAreaDetail(gh<_i704.LocationsRepository>()),
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
  gh.lazySingleton<_i583.GoRouter>(
    () => routerModule.router(gh<_i354.AppLogger>(), gh<_i797.AuthBloc>()),
  );
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
  gh.factory<_i669.LocationsListBloc>(
    () => _i669.LocationsListBloc(gh<_i533.ListGovernorates>()),
  );
  return getIt;
}

class _$RouterModule extends _i464.RouterModule {}
