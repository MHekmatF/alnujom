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
    as _i547;
import '../../features/profile/domain/usecases/load_pii.dart' as _i363;
import '../../features/profile/domain/usecases/load_profile.dart' as _i1052;
import '../../features/profile/domain/usecases/update_pii.dart' as _i281;
import '../../features/profile/domain/usecases/update_profile.dart' as _i78;
import '../../features/profile/presentation/cubit/profile_cubit.dart' as _i36;
import '../config/env_config.dart' as _i373;
import '../localization/locale_cubit.dart' as _i960;
import '../logging/app_logger.dart' as _i354;
import '../logging/console_logger.dart' as _i1026;
import '../network/supabase_client_wrapper.dart' as _i752;
import '../network/supabase_client_wrapper_impl.dart' as _i748;
import '../security/permission_catalog_repository.dart' as _i1015;
import '../security/permission_catalog_repository_impl.dart' as _i753;
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
  gh.singleton<_i373.EnvConfig>(() => const _i373.EnvConfig());
  gh.lazySingleton<_i394.SupabaseAccountApprovalsDatasource>(
    () => _i394.SupabaseAccountApprovalsDatasource(),
  );
  gh.lazySingleton<_i825.SupabaseProfileDataSource>(
    () => _i825.SupabaseProfileDataSource(),
  );
  gh.lazySingleton<_i1015.PermissionCatalogRepository>(
    () => _i753.PermissionCatalogRepositoryImpl(),
  );
  gh.lazySingleton<_i650.PermissionChecker>(
    () => _i650.PermissionChecker(gh<_i1015.PermissionCatalogRepository>()),
  );
  gh.lazySingleton<_i354.AppLogger>(() => _i1026.ConsoleLogger());
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
  gh.factory<_i547.LoadAssignedRoles>(
    () => _i547.LoadAssignedRoles(gh<_i894.ProfileRepository>()),
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
  gh.lazySingleton<_i787.AuthRepository>(
    () => _i153.AuthRepositoryImpl(
      gh<_i76.SupabaseAuthDataSource>(),
      gh<_i894.ProfileRepository>(),
      gh<_i354.AppLogger>(),
    ),
    dispose: (i) => i.dispose(),
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
  gh.factory<_i36.ProfileCubit>(
    () => _i36.ProfileCubit(
      gh<_i1052.LoadProfile>(),
      gh<_i78.UpdateProfile>(),
      gh<_i363.LoadPii>(),
      gh<_i281.UpdatePii>(),
      gh<_i547.LoadAssignedRoles>(),
    ),
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
  gh.factory<_i807.OnboardingCubit>(
    () => _i807.OnboardingCubit(gh<_i430.OnboardingRepository>()),
  );
  gh.lazySingleton<_i797.AuthBloc>(
    () => _i797.AuthBloc(
      gh<_i787.AuthRepository>(),
      gh<_i894.ProfileRepository>(),
      gh<_i650.PermissionChecker>(),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.lazySingleton<_i583.GoRouter>(
    () => routerModule.router(gh<_i354.AppLogger>(), gh<_i797.AuthBloc>()),
  );
  return getIt;
}

class _$RouterModule extends _i464.RouterModule {}
