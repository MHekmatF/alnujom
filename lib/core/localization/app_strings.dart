// ignore_for_file: non_constant_identifier_names
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

    // GetIt may not be bootstrapped in widget-test environments. Fall back to
    // a silent logger so AppStrings stays safe to mount in tests.
    final logger = getIt.isRegistered<AppLogger>()
        ? getIt<AppLogger>()
        : const _SilentAppLogger();
    return AppStrings._(active: active, logger: logger);
  }

  AppLocalizations get loc => _loc;
}

final class _SilentAppLogger implements AppLogger {
  const _SilentAppLogger();

  @override
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}

  @override
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}

  @override
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}
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
  static const _intentionallyIdenticalKeys = <String>{
    'appTitle',
    'currencyUsdSymbol',
    'currencySypSymbol',
  };

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
  String get currentTheme =>
      _resolve('currentTheme', (loc) => loc.currentTheme);

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
  String get errorOffline =>
      _resolve('errorOffline', (loc) => loc.errorOffline);

  @override
  String get errorGeneric =>
      _resolve('errorGeneric', (loc) => loc.errorGeneric);

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

  @override
  String get currencyUsdName =>
      _resolve('currencyUsdName', (loc) => loc.currencyUsdName);

  @override
  String get currencySypName =>
      _resolve('currencySypName', (loc) => loc.currencySypName);

  @override
  String get currencyUsdSymbol =>
      _resolve('currencyUsdSymbol', (loc) => loc.currencyUsdSymbol);

  @override
  String get currencySypSymbol =>
      _resolve('currencySypSymbol', (loc) => loc.currencySypSymbol);

  @override
  String paginationCounter(int current, int total) =>
      _active.paginationCounter(current, total);

  @override
  String stepCounter(int current, int total) =>
      _active.stepCounter(current, total);

  @override
  String priceWithCurrency(String amount, String currency) =>
      _active.priceWithCurrency(amount, currency);

  // ── Phase 5 Auth / Profile / Admin / Onboarding ──────────────────────────

  @override
  String get register_title =>
      _resolve('register_title', (loc) => loc.register_title);

  @override
  String get register_phone_label =>
      _resolve('register_phone_label', (loc) => loc.register_phone_label);

  @override
  String get register_phone_hint =>
      _resolve('register_phone_hint', (loc) => loc.register_phone_hint);

  @override
  String get register_password_label =>
      _resolve('register_password_label', (loc) => loc.register_password_label);

  @override
  String get register_password_hint =>
      _resolve('register_password_hint', (loc) => loc.register_password_hint);

  @override
  String get register_real_email_label_optional => _resolve(
    'register_real_email_label_optional',
    (loc) => loc.register_real_email_label_optional,
  );

  @override
  String get register_full_name_label => _resolve(
    'register_full_name_label',
    (loc) => loc.register_full_name_label,
  );

  @override
  String get register_submit =>
      _resolve('register_submit', (loc) => loc.register_submit);

  @override
  String get login_title => _resolve('login_title', (loc) => loc.login_title);

  @override
  String get login_phone_label =>
      _resolve('login_phone_label', (loc) => loc.login_phone_label);

  @override
  String get login_password_label =>
      _resolve('login_password_label', (loc) => loc.login_password_label);

  @override
  String get login_submit =>
      _resolve('login_submit', (loc) => loc.login_submit);

  @override
  String get login_forgot_password =>
      _resolve('login_forgot_password', (loc) => loc.login_forgot_password);

  @override
  String get login_no_account =>
      _resolve('login_no_account', (loc) => loc.login_no_account);

  @override
  String get register_have_account =>
      _resolve('register_have_account', (loc) => loc.register_have_account);

  @override
  String get pending_approval_title =>
      _resolve('pending_approval_title', (loc) => loc.pending_approval_title);

  @override
  String get pending_approval_body =>
      _resolve('pending_approval_body', (loc) => loc.pending_approval_body);

  @override
  String get rejected_title =>
      _resolve('rejected_title', (loc) => loc.rejected_title);

  @override
  String rejected_body_with_reason(String reason) => _resolve(
    'rejected_body_with_reason',
    (loc) => loc.rejected_body_with_reason(reason),
  );

  @override
  String get suspended_title =>
      _resolve('suspended_title', (loc) => loc.suspended_title);

  @override
  String get suspended_body =>
      _resolve('suspended_body', (loc) => loc.suspended_body);

  @override
  String get reset_password_title =>
      _resolve('reset_password_title', (loc) => loc.reset_password_title);

  @override
  String get reset_password_phone_label => _resolve(
    'reset_password_phone_label',
    (loc) => loc.reset_password_phone_label,
  );

  @override
  String get reset_password_submit =>
      _resolve('reset_password_submit', (loc) => loc.reset_password_submit);

  @override
  String get reset_password_generic_response => _resolve(
    'reset_password_generic_response',
    (loc) => loc.reset_password_generic_response,
  );

  @override
  String get phone_required =>
      _resolve('phone_required', (loc) => loc.phone_required);

  @override
  String get phone_invalid =>
      _resolve('phone_invalid', (loc) => loc.phone_invalid);

  @override
  String get password_too_short =>
      _resolve('password_too_short', (loc) => loc.password_too_short);

  @override
  String get account_already_exists =>
      _resolve('account_already_exists', (loc) => loc.account_already_exists);

  @override
  String get invalid_phone_or_password => _resolve(
    'invalid_phone_or_password',
    (loc) => loc.invalid_phone_or_password,
  );

  @override
  String get network_error =>
      _resolve('network_error', (loc) => loc.network_error);

  @override
  String get unknown_auth_error =>
      _resolve('unknown_auth_error', (loc) => loc.unknown_auth_error);

  @override
  String get sign_out => _resolve('sign_out', (loc) => loc.sign_out);

  @override
  String get profile_title =>
      _resolve('profile_title', (loc) => loc.profile_title);

  @override
  String get profile_full_name_label =>
      _resolve('profile_full_name_label', (loc) => loc.profile_full_name_label);

  @override
  String get profile_username_label =>
      _resolve('profile_username_label', (loc) => loc.profile_username_label);

  @override
  String get profile_phone_label =>
      _resolve('profile_phone_label', (loc) => loc.profile_phone_label);

  @override
  String get profile_email_label =>
      _resolve('profile_email_label', (loc) => loc.profile_email_label);

  @override
  String get profile_avatar_label =>
      _resolve('profile_avatar_label', (loc) => loc.profile_avatar_label);

  @override
  String get profile_edit_button =>
      _resolve('profile_edit_button', (loc) => loc.profile_edit_button);

  @override
  String get profile_save_button =>
      _resolve('profile_save_button', (loc) => loc.profile_save_button);

  @override
  String get profile_cancel_button =>
      _resolve('profile_cancel_button', (loc) => loc.profile_cancel_button);

  @override
  String get profile_account_status_badge_pending => _resolve(
    'profile_account_status_badge_pending',
    (loc) => loc.profile_account_status_badge_pending,
  );

  @override
  String get profile_account_status_badge_approved => _resolve(
    'profile_account_status_badge_approved',
    (loc) => loc.profile_account_status_badge_approved,
  );

  @override
  String get profile_account_status_badge_rejected => _resolve(
    'profile_account_status_badge_rejected',
    (loc) => loc.profile_account_status_badge_rejected,
  );

  @override
  String get profile_account_status_badge_suspended => _resolve(
    'profile_account_status_badge_suspended',
    (loc) => loc.profile_account_status_badge_suspended,
  );

  @override
  String get username_taken =>
      _resolve('username_taken', (loc) => loc.username_taken);

  @override
  String get invalid_full_name =>
      _resolve('invalid_full_name', (loc) => loc.invalid_full_name);

  @override
  String get invalid_username =>
      _resolve('invalid_username', (loc) => loc.invalid_username);

  @override
  String get invalid_email =>
      _resolve('invalid_email', (loc) => loc.invalid_email);

  @override
  String get invalid_avatar_url =>
      _resolve('invalid_avatar_url', (loc) => loc.invalid_avatar_url);

  @override
  String get profile_private_section_title => _resolve(
    'profile_private_section_title',
    (loc) => loc.profile_private_section_title,
  );

  @override
  String get profile_private_legal_name => _resolve(
    'profile_private_legal_name',
    (loc) => loc.profile_private_legal_name,
  );

  @override
  String get profile_private_national_id => _resolve(
    'profile_private_national_id',
    (loc) => loc.profile_private_national_id,
  );

  @override
  String get profile_private_contact_methods_title => _resolve(
    'profile_private_contact_methods_title',
    (loc) => loc.profile_private_contact_methods_title,
  );

  @override
  String get profile_private_contact_methods_whatsapp => _resolve(
    'profile_private_contact_methods_whatsapp',
    (loc) => loc.profile_private_contact_methods_whatsapp,
  );

  @override
  String get profile_private_contact_methods_telegram => _resolve(
    'profile_private_contact_methods_telegram',
    (loc) => loc.profile_private_contact_methods_telegram,
  );

  @override
  String get profile_private_contact_methods_signal => _resolve(
    'profile_private_contact_methods_signal',
    (loc) => loc.profile_private_contact_methods_signal,
  );

  @override
  String get profile_private_contact_methods_private_email => _resolve(
    'profile_private_contact_methods_private_email',
    (loc) => loc.profile_private_contact_methods_private_email,
  );

  @override
  String get profile_private_contact_methods_secondary_phone => _resolve(
    'profile_private_contact_methods_secondary_phone',
    (loc) => loc.profile_private_contact_methods_secondary_phone,
  );

  @override
  String get profile_private_unknown_channel => _resolve(
    'profile_private_unknown_channel',
    (loc) => loc.profile_private_unknown_channel,
  );

  @override
  String get admin_tile_account_approvals => _resolve(
    'admin_tile_account_approvals',
    (loc) => loc.admin_tile_account_approvals,
  );

  @override
  String get admin_queue_title =>
      _resolve('admin_queue_title', (loc) => loc.admin_queue_title);

  @override
  String get admin_queue_empty =>
      _resolve('admin_queue_empty', (loc) => loc.admin_queue_empty);

  @override
  String get admin_queue_pull_to_refresh => _resolve(
    'admin_queue_pull_to_refresh',
    (loc) => loc.admin_queue_pull_to_refresh,
  );

  @override
  String get admin_queue_phone_label =>
      _resolve('admin_queue_phone_label', (loc) => loc.admin_queue_phone_label);

  @override
  String get admin_queue_email_label =>
      _resolve('admin_queue_email_label', (loc) => loc.admin_queue_email_label);

  @override
  String get admin_queue_full_name_label => _resolve(
    'admin_queue_full_name_label',
    (loc) => loc.admin_queue_full_name_label,
  );

  @override
  String get admin_queue_created_at_label => _resolve(
    'admin_queue_created_at_label',
    (loc) => loc.admin_queue_created_at_label,
  );

  @override
  String get admin_action_approve =>
      _resolve('admin_action_approve', (loc) => loc.admin_action_approve);

  @override
  String get admin_action_reject =>
      _resolve('admin_action_reject', (loc) => loc.admin_action_reject);

  @override
  String get admin_action_reject_reason_title => _resolve(
    'admin_action_reject_reason_title',
    (loc) => loc.admin_action_reject_reason_title,
  );

  @override
  String get admin_action_reject_reason_label => _resolve(
    'admin_action_reject_reason_label',
    (loc) => loc.admin_action_reject_reason_label,
  );

  @override
  String get admin_action_reject_reason_required => _resolve(
    'admin_action_reject_reason_required',
    (loc) => loc.admin_action_reject_reason_required,
  );

  @override
  String get admin_action_confirm =>
      _resolve('admin_action_confirm', (loc) => loc.admin_action_confirm);

  @override
  String get admin_action_cancel =>
      _resolve('admin_action_cancel', (loc) => loc.admin_action_cancel);

  @override
  String get admin_request_already_resolved => _resolve(
    'admin_request_already_resolved',
    (loc) => loc.admin_request_already_resolved,
  );

  @override
  String get onboarding_step_1_title =>
      _resolve('onboarding_step_1_title', (loc) => loc.onboarding_step_1_title);

  @override
  String get onboarding_step_1_body =>
      _resolve('onboarding_step_1_body', (loc) => loc.onboarding_step_1_body);

  @override
  String get onboarding_step_2_title =>
      _resolve('onboarding_step_2_title', (loc) => loc.onboarding_step_2_title);

  @override
  String get onboarding_step_2_body =>
      _resolve('onboarding_step_2_body', (loc) => loc.onboarding_step_2_body);

  @override
  String get onboarding_step_3_title =>
      _resolve('onboarding_step_3_title', (loc) => loc.onboarding_step_3_title);

  @override
  String get onboarding_step_3_body =>
      _resolve('onboarding_step_3_body', (loc) => loc.onboarding_step_3_body);

  @override
  String get onboarding_get_started =>
      _resolve('onboarding_get_started', (loc) => loc.onboarding_get_started);

  @override
  String get onboarding_skip =>
      _resolve('onboarding_skip', (loc) => loc.onboarding_skip);

  @override
  String get onboarding_locale_picker_label => _resolve(
    'onboarding_locale_picker_label',
    (loc) => loc.onboarding_locale_picker_label,
  );

  @override
  String get home_title => _resolve('home_title', (loc) => loc.home_title);

  @override
  String home_signed_in_as(String name) =>
      _resolve('home_signed_in_as', (loc) => loc.home_signed_in_as(name));

  @override
  String get home_tile_profile =>
      _resolve('home_tile_profile', (loc) => loc.home_tile_profile);
}
