import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../di/injection.dart';
import '../logging/app_logger.dart';

final class AppStrings {
  AppStrings._({required AppLocalizations active, required AppLogger logger})
    : _loc = !kDebugMode
          ? active
          : _DebugAppLocalizations(
              active: active,
              enBaseline: AppLocalizationsEn(),
              logger: logger,
            );

  final AppLocalizations _loc;

  static AppStrings of(BuildContext context) {
    final active = AppLocalizations.of(context);
    if (active == null) {
      throw StateError(
        'AppStrings.of(context) called before localization delegates are available.',
      );
    }

    return AppStrings._(active: active, logger: getIt<AppLogger>());
  }

  AppLocalizations get loc => _loc;
}

final class _DebugAppLocalizations extends AppLocalizations {
  _DebugAppLocalizations({
    required AppLocalizations active,
    required AppLocalizations enBaseline,
    required AppLogger logger,
  }) : _active = active,
       _enBaseline = enBaseline,
       _logger = logger,
       super(active.localeName);

  final AppLocalizations _active;
  final AppLocalizations _enBaseline;
  final AppLogger _logger;

  static const _tag = 'AppStrings';
  static const _intentionallyIdenticalKeys = <String>{'appTitle'};

  bool get _isArabicLocale => _active.localeName.startsWith('ar');

  String _resolve(
    String key,
    String Function(AppLocalizations localizations) reader,
  ) {
    final resolved = reader(_active);
    if (!_isArabicLocale) {
      return resolved;
    }
    if (_intentionallyIdenticalKeys.contains(key)) {
      return resolved;
    }

    final englishBaseline = reader(_enBaseline);
    if (resolved != englishBaseline) {
      return resolved;
    }

    _logger.warning('Missing ar translation for key: $key', tag: _tag);
    final prefix = _active.missingTranslationMarkerPrefix;
    final suffix = _active.missingTranslationMarkerSuffix;
    return '$prefix$key$suffix';
  }

  @override
  String get appTitle => _resolve('appTitle', (loc) => loc.appTitle);

  @override
  String get themeToggleLabel =>
      _resolve('themeToggleLabel', (loc) => loc.themeToggleLabel);

  @override
  String get localeToggleLabel =>
      _resolve('localeToggleLabel', (loc) => loc.localeToggleLabel);

  @override
  String get currentTheme => _resolve('currentTheme', (loc) => loc.currentTheme);

  @override
  String get currentLocale =>
      _resolve('currentLocale', (loc) => loc.currentLocale);

  @override
  String get backendConfigMissingWarning => _resolve(
    'backendConfigMissingWarning',
    (loc) => loc.backendConfigMissingWarning,
  );

  @override
  String get themeGalleryTitle =>
      _resolve('themeGalleryTitle', (loc) => loc.themeGalleryTitle);

  @override
  String get themeGalleryPaletteSectionHeader => _resolve(
    'themeGalleryPaletteSectionHeader',
    (loc) => loc.themeGalleryPaletteSectionHeader,
  );

  @override
  String get themeGalleryThemeSectionHeader => _resolve(
    'themeGalleryThemeSectionHeader',
    (loc) => loc.themeGalleryThemeSectionHeader,
  );

  @override
  String get themeGalleryLocaleSectionHeader => _resolve(
    'themeGalleryLocaleSectionHeader',
    (loc) => loc.themeGalleryLocaleSectionHeader,
  );

  @override
  String get themeGalleryComponentsSectionHeader => _resolve(
    'themeGalleryComponentsSectionHeader',
    (loc) => loc.themeGalleryComponentsSectionHeader,
  );

  @override
  String get errorOffline => _resolve('errorOffline', (loc) => loc.errorOffline);

  @override
  String get errorGeneric => _resolve('errorGeneric', (loc) => loc.errorGeneric);

  @override
  String get errorMissingBackendConfig => _resolve(
    'errorMissingBackendConfig',
    (loc) => loc.errorMissingBackendConfig,
  );

  @override
  String get errorRetryAction =>
      _resolve('errorRetryAction', (loc) => loc.errorRetryAction);

  @override
  String get missingTranslationMarkerPrefix =>
      _active.missingTranslationMarkerPrefix;

  @override
  String get missingTranslationMarkerSuffix =>
      _active.missingTranslationMarkerSuffix;
}
