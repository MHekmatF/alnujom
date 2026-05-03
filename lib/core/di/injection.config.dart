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

import '../config/env_config.dart' as _i373;
import '../localization/locale_cubit.dart' as _i960;
import '../logging/app_logger.dart' as _i354;
import '../logging/console_logger.dart' as _i1026;
import '../network/supabase_client_wrapper.dart' as _i752;
import '../network/supabase_client_wrapper_impl.dart' as _i748;
import '../storage/preferences_store.dart' as _i753;
import '../storage/secure_preferences_store.dart' as _i190;
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
  gh.lazySingleton<_i354.AppLogger>(() => _i1026.ConsoleLogger());
  gh.lazySingleton<_i753.PreferencesStore>(
    () => _i190.SecurePreferencesStore(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i752.SupabaseClientWrapper>(
    () => _i748.SupabaseClientWrapperImpl(gh<_i354.AppLogger>()),
  );
  gh.singleton<_i583.GoRouter>(
    () => routerModule.router(gh<_i354.AppLogger>()),
  );
  gh.factoryParam<_i960.LocaleCubit, _i264.Locale?, dynamic>(
    (initialLocale, _) => _i960.LocaleCubit(
      gh<_i753.PreferencesStore>(),
      gh<_i354.AppLogger>(),
      initialLocale,
    ),
  );
  gh.factory<_i611.ThemeCubit>(
    () => _i611.ThemeCubit(
      gh<_i753.PreferencesStore>(),
      gh<_i354.AppLogger>(),
    ),
  );
  return getIt;
}

class _$RouterModule extends _i464.RouterModule {}
