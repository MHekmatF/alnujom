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
  String get reset_password_sent_message =>
      _resolve('reset_password_sent_message', (loc) => loc.reset_password_sent_message);

  @override
  String get reset_password_not_found_message =>
      _resolve('reset_password_not_found_message', (loc) => loc.reset_password_not_found_message);

  @override
  String get reset_password_create_account =>
      _resolve('reset_password_create_account', (loc) => loc.reset_password_create_account);

  @override
  String get reset_password_no_email_message =>
      _resolve('reset_password_no_email_message', (loc) => loc.reset_password_no_email_message);

  @override
  String get reset_password_no_email_no_contact =>
      _resolve('reset_password_no_email_no_contact', (loc) => loc.reset_password_no_email_no_contact);

  @override
  String get reset_password_new_title => _resolve(
    'reset_password_new_title',
    (loc) => loc.reset_password_new_title,
  );

  @override
  String get reset_password_new_subtitle => _resolve(
    'reset_password_new_subtitle',
    (loc) => loc.reset_password_new_subtitle,
  );

  @override
  String get reset_password_new_label => _resolve(
    'reset_password_new_label',
    (loc) => loc.reset_password_new_label,
  );

  @override
  String get reset_password_confirm_label => _resolve(
    'reset_password_confirm_label',
    (loc) => loc.reset_password_confirm_label,
  );

  @override
  String get reset_password_mismatch =>
      _resolve('reset_password_mismatch', (loc) => loc.reset_password_mismatch);

  @override
  String get reset_password_save =>
      _resolve('reset_password_save', (loc) => loc.reset_password_save);

  @override
  String get reset_password_success_title => _resolve(
    'reset_password_success_title',
    (loc) => loc.reset_password_success_title,
  );

  @override
  String get reset_password_success_body => _resolve(
    'reset_password_success_body',
    (loc) => loc.reset_password_success_body,
  );

  @override
  String get reset_password_continue =>
      _resolve('reset_password_continue', (loc) => loc.reset_password_continue);

  @override
  String get reset_password_link_expired_title => _resolve(
    'reset_password_link_expired_title',
    (loc) => loc.reset_password_link_expired_title,
  );

  @override
  String get reset_password_link_expired_body => _resolve(
    'reset_password_link_expired_body',
    (loc) => loc.reset_password_link_expired_body,
  );

  @override
  String get reset_password_request_new_link => _resolve(
    'reset_password_request_new_link',
    (loc) => loc.reset_password_request_new_link,
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
  String get admin_queue_user_id_label => _resolve(
    'admin_queue_user_id_label',
    (loc) => loc.admin_queue_user_id_label,
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

  // ── Phase 6 Admin home / Profile roles ───────────────────────────────────

  @override
  String get admin_home_title =>
      _resolve('admin_home_title', (loc) => loc.admin_home_title);

  @override
  String get admin_home_empty_title =>
      _resolve('admin_home_empty_title', (loc) => loc.admin_home_empty_title);

  @override
  String get admin_home_empty_body =>
      _resolve('admin_home_empty_body', (loc) => loc.admin_home_empty_body);

  @override
  String get adminTileSuperAdmin =>
      _resolve('adminTileSuperAdmin', (loc) => loc.adminTileSuperAdmin);

  @override
  String get superAdminRolesListTitle => _resolve(
    'superAdminRolesListTitle',
    (loc) => loc.superAdminRolesListTitle,
  );

  @override
  String get roleBadgeSystem =>
      _resolve('roleBadgeSystem', (loc) => loc.roleBadgeSystem);

  @override
  String rolePermissionsCount(int count) => _resolve(
    'rolePermissionsCount',
    (loc) => loc.rolePermissionsCount(count),
  );

  @override
  String get permissionCategoryUsers =>
      _resolve('permissionCategoryUsers', (loc) => loc.permissionCategoryUsers);

  @override
  String get permissionCategoryListings => _resolve(
    'permissionCategoryListings',
    (loc) => loc.permissionCategoryListings,
  );

  @override
  String get permissionCategoryRoles =>
      _resolve('permissionCategoryRoles', (loc) => loc.permissionCategoryRoles);

  @override
  String get permissionCategoryLocations => _resolve(
    'permissionCategoryLocations',
    (loc) => loc.permissionCategoryLocations,
  );

  @override
  String get permissionCategoryCurrencies => _resolve(
    'permissionCategoryCurrencies',
    (loc) => loc.permissionCategoryCurrencies,
  );

  @override
  String get permissionCategoryAds =>
      _resolve('permissionCategoryAds', (loc) => loc.permissionCategoryAds);

  @override
  String get permissionCategoryReports => _resolve(
    'permissionCategoryReports',
    (loc) => loc.permissionCategoryReports,
  );

  @override
  String get permissionCategoryAgencies => _resolve(
    'permissionCategoryAgencies',
    (loc) => loc.permissionCategoryAgencies,
  );

  @override
  String get permissionCategorySettings => _resolve(
    'permissionCategorySettings',
    (loc) => loc.permissionCategorySettings,
  );

  @override
  String get permissionCategoryAudit =>
      _resolve('permissionCategoryAudit', (loc) => loc.permissionCategoryAudit);

  @override
  String get permissionCategoryInquiries => _resolve(
    'permissionCategoryInquiries',
    (loc) => loc.permissionCategoryInquiries,
  );

  @override
  String get permissionCategoryPermissions => _resolve(
    'permissionCategoryPermissions',
    (loc) => loc.permissionCategoryPermissions,
  );

  @override
  String get superAdminPermissionsLocked => _resolve(
    'superAdminPermissionsLocked',
    (loc) => loc.superAdminPermissionsLocked,
  );

  @override
  String get superAdminRoleEditorTitle => _resolve(
    'superAdminRoleEditorTitle',
    (loc) => loc.superAdminRoleEditorTitle,
  );

  @override
  String get superAdminCreateRoleTitle => _resolve(
    'superAdminCreateRoleTitle',
    (loc) => loc.superAdminCreateRoleTitle,
  );

  @override
  String get superAdminAssignRoleTitle => _resolve(
    'superAdminAssignRoleTitle',
    (loc) => loc.superAdminAssignRoleTitle,
  );

  @override
  String get roleKeyLabel =>
      _resolve('roleKeyLabel', (loc) => loc.roleKeyLabel);

  @override
  String get roleDisplayNameLabelAr =>
      _resolve('roleDisplayNameLabelAr', (loc) => loc.roleDisplayNameLabelAr);

  @override
  String get roleDisplayNameLabelEn =>
      _resolve('roleDisplayNameLabelEn', (loc) => loc.roleDisplayNameLabelEn);

  @override
  String get roleDescriptionLabel =>
      _resolve('roleDescriptionLabel', (loc) => loc.roleDescriptionLabel);

  @override
  String get actionCreate =>
      _resolve('actionCreate', (loc) => loc.actionCreate);

  @override
  String get actionDelete =>
      _resolve('actionDelete', (loc) => loc.actionDelete);

  @override
  String get actionCancel =>
      _resolve('actionCancel', (loc) => loc.actionCancel);

  @override
  String get actionReload =>
      _resolve('actionReload', (loc) => loc.actionReload);

  @override
  String get actionGrant => _resolve('actionGrant', (loc) => loc.actionGrant);

  @override
  String get actionRevoke =>
      _resolve('actionRevoke', (loc) => loc.actionRevoke);

  @override
  String get confirmDeleteRoleTitle =>
      _resolve('confirmDeleteRoleTitle', (loc) => loc.confirmDeleteRoleTitle);

  @override
  String get confirmDeleteRoleBody =>
      _resolve('confirmDeleteRoleBody', (loc) => loc.confirmDeleteRoleBody);

  @override
  String confirmDeleteRoleBodyWithUsers(int count) => _resolve(
    'confirmDeleteRoleBodyWithUsers',
    (loc) => loc.confirmDeleteRoleBodyWithUsers(count),
  );

  @override
  String get confirmGrantRoleTitle =>
      _resolve('confirmGrantRoleTitle', (loc) => loc.confirmGrantRoleTitle);

  @override
  String get confirmGrantRoleBody =>
      _resolve('confirmGrantRoleBody', (loc) => loc.confirmGrantRoleBody);

  @override
  String get confirmRevokeRoleTitle =>
      _resolve('confirmRevokeRoleTitle', (loc) => loc.confirmRevokeRoleTitle);

  @override
  String get confirmRevokeRoleBody =>
      _resolve('confirmRevokeRoleBody', (loc) => loc.confirmRevokeRoleBody);

  @override
  String get confirmSuperAdminGrantTitle => _resolve(
    'confirmSuperAdminGrantTitle',
    (loc) => loc.confirmSuperAdminGrantTitle,
  );

  @override
  String get confirmSuperAdminGrantBody => _resolve(
    'confirmSuperAdminGrantBody',
    (loc) => loc.confirmSuperAdminGrantBody,
  );

  @override
  String get confirmSuperAdminGrantAckButton => _resolve(
    'confirmSuperAdminGrantAckButton',
    (loc) => loc.confirmSuperAdminGrantAckButton,
  );

  @override
  String get confirmSuperAdminGrantTypedMatchLabel => _resolve(
    'confirmSuperAdminGrantTypedMatchLabel',
    (loc) => loc.confirmSuperAdminGrantTypedMatchLabel,
  );

  @override
  String get confirmSuperAdminGrantConfirmButton => _resolve(
    'confirmSuperAdminGrantConfirmButton',
    (loc) => loc.confirmSuperAdminGrantConfirmButton,
  );

  @override
  String get userSearchPlaceholder =>
      _resolve('userSearchPlaceholder', (loc) => loc.userSearchPlaceholder);

  @override
  String get userSearchEmptyResults =>
      _resolve('userSearchEmptyResults', (loc) => loc.userSearchEmptyResults);

  @override
  String get errorRoleEditConflict =>
      _resolve('errorRoleEditConflict', (loc) => loc.errorRoleEditConflict);

  @override
  String get errorSuperAdminPermissionsImmutable => _resolve(
    'errorSuperAdminPermissionsImmutable',
    (loc) => loc.errorSuperAdminPermissionsImmutable,
  );

  @override
  String get errorSystemRoleImmutable => _resolve(
    'errorSystemRoleImmutable',
    (loc) => loc.errorSystemRoleImmutable,
  );

  @override
  String get errorRolePermissionDenied => _resolve(
    'errorRolePermissionDenied',
    (loc) => loc.errorRolePermissionDenied,
  );

  @override
  String get errorGenericBackend =>
      _resolve('errorGenericBackend', (loc) => loc.errorGenericBackend);

  @override
  String get errorRoleKeyDuplicate =>
      _resolve('errorRoleKeyDuplicate', (loc) => loc.errorRoleKeyDuplicate);

  @override
  String get errorRoleKeyInvalid =>
      _resolve('errorRoleKeyInvalid', (loc) => loc.errorRoleKeyInvalid);

  @override
  String get errorRoleDisplayNameRequired => _resolve(
    'errorRoleDisplayNameRequired',
    (loc) => loc.errorRoleDisplayNameRequired,
  );

  @override
  String errorRoleHasUsers(int count) =>
      _resolve('errorRoleHasUsers', (loc) => loc.errorRoleHasUsers(count));

  @override
  String get errorSuperAdminGrantConfirmationFailed => _resolve(
    'errorSuperAdminGrantConfirmationFailed',
    (loc) => loc.errorSuperAdminGrantConfirmationFailed,
  );

  @override
  String get errorAssignPermissionDenied => _resolve(
    'errorAssignPermissionDenied',
    (loc) => loc.errorAssignPermissionDenied,
  );

  @override
  String get errorRevokePermissionDenied => _resolve(
    'errorRevokePermissionDenied',
    (loc) => loc.errorRevokePermissionDenied,
  );

  @override
  String get errorSuperAdminSelfRevokeForbidden => _resolve(
    'errorSuperAdminSelfRevokeForbidden',
    (loc) => loc.errorSuperAdminSelfRevokeForbidden,
  );

  @override
  String get errorUserAlreadyHoldsRole => _resolve(
    'errorUserAlreadyHoldsRole',
    (loc) => loc.errorUserAlreadyHoldsRole,
  );

  @override
  String get errorUserDoesNotHoldRole => _resolve(
    'errorUserDoesNotHoldRole',
    (loc) => loc.errorUserDoesNotHoldRole,
  );

  @override
  String errorRoleSaveFailed(String reason) =>
      _resolve('errorRoleSaveFailed', (loc) => loc.errorRoleSaveFailed(reason));

  @override
  String get assignRoleSucceeded =>
      _resolve('assignRoleSucceeded', (loc) => loc.assignRoleSucceeded);

  @override
  String get revokeRoleSucceeded =>
      _resolve('revokeRoleSucceeded', (loc) => loc.revokeRoleSucceeded);

  @override
  String get profile_section_roles =>
      _resolve('profile_section_roles', (loc) => loc.profile_section_roles);

  @override
  String get adminHomeCurrenciesTile =>
      _resolve('adminHomeCurrenciesTile', (loc) => loc.adminHomeCurrenciesTile);

  @override
  String get currenciesPageTitle =>
      _resolve('currenciesPageTitle', (loc) => loc.currenciesPageTitle);

  @override
  String get setExchangeRatePageTitle => _resolve(
    'setExchangeRatePageTitle',
    (loc) => loc.setExchangeRatePageTitle,
  );

  @override
  String get exchangeRateHistoryPageTitle => _resolve(
    'exchangeRateHistoryPageTitle',
    (loc) => loc.exchangeRateHistoryPageTitle,
  );

  @override
  String get currencyFormPageTitle =>
      _resolve('currencyFormPageTitle', (loc) => loc.currencyFormPageTitle);

  @override
  String get setNewRateButton =>
      _resolve('setNewRateButton', (loc) => loc.setNewRateButton);

  @override
  String get viewHistoryButton =>
      _resolve('viewHistoryButton', (loc) => loc.viewHistoryButton);

  @override
  String get addCurrencyButton =>
      _resolve('addCurrencyButton', (loc) => loc.addCurrencyButton);

  @override
  String get systemCurrencyBadge =>
      _resolve('systemCurrencyBadge', (loc) => loc.systemCurrencyBadge);

  @override
  String latestRateLineTemplate(String base, String amount) => _resolve(
    'latestRateLineTemplate',
    (loc) => loc.latestRateLineTemplate(base, amount),
  );

  @override
  String get rateNotSetHint =>
      _resolve('rateNotSetHint', (loc) => loc.rateNotSetHint);

  @override
  String deleteCurrencyConfirmTitle(String code) => _resolve(
    'deleteCurrencyConfirmTitle',
    (loc) => loc.deleteCurrencyConfirmTitle(code),
  );

  @override
  String deleteCurrencyConfirmBody(
    int exchangeRatesCount,
    int listingPricesCount,
  ) => _resolve(
    'deleteCurrencyConfirmBody',
    (loc) =>
        loc.deleteCurrencyConfirmBody(exchangeRatesCount, listingPricesCount),
  );

  @override
  String get deleteButton =>
      _resolve('deleteButton', (loc) => loc.deleteButton);

  @override
  String get cancelButton =>
      _resolve('cancelButton', (loc) => loc.cancelButton);

  @override
  String get unusualTimingFutureTitle => _resolve(
    'unusualTimingFutureTitle',
    (loc) => loc.unusualTimingFutureTitle,
  );

  @override
  String get unusualTimingBackdateTitle => _resolve(
    'unusualTimingBackdateTitle',
    (loc) => loc.unusualTimingBackdateTitle,
  );

  @override
  String unusualTimingFutureBody(String magnitude) => _resolve(
    'unusualTimingFutureBody',
    (loc) => loc.unusualTimingFutureBody(magnitude),
  );

  @override
  String unusualTimingBackdateBody(String magnitude) => _resolve(
    'unusualTimingBackdateBody',
    (loc) => loc.unusualTimingBackdateBody(magnitude),
  );

  @override
  String unusualTimingFutureMagnitudeHours(int hours) => _resolve(
    'unusualTimingFutureMagnitudeHours',
    (loc) => loc.unusualTimingFutureMagnitudeHours(hours),
  );

  @override
  String unusualTimingBackdateMagnitudeHours(int hours) => _resolve(
    'unusualTimingBackdateMagnitudeHours',
    (loc) => loc.unusualTimingBackdateMagnitudeHours(hours),
  );

  @override
  String unusualTimingFutureMagnitudeDays(int days) => _resolve(
    'unusualTimingFutureMagnitudeDays',
    (loc) => loc.unusualTimingFutureMagnitudeDays(days),
  );

  @override
  String unusualTimingBackdateMagnitudeDays(int days) => _resolve(
    'unusualTimingBackdateMagnitudeDays',
    (loc) => loc.unusualTimingBackdateMagnitudeDays(days),
  );

  @override
  String get currencyCodeLabel =>
      _resolve('currencyCodeLabel', (loc) => loc.currencyCodeLabel);

  @override
  String get currencyNameArLabel =>
      _resolve('currencyNameArLabel', (loc) => loc.currencyNameArLabel);

  @override
  String get currencyNameEnLabel =>
      _resolve('currencyNameEnLabel', (loc) => loc.currencyNameEnLabel);

  @override
  String get currencySymbolLabel =>
      _resolve('currencySymbolLabel', (loc) => loc.currencySymbolLabel);

  @override
  String get currencySortOrderLabel =>
      _resolve('currencySortOrderLabel', (loc) => loc.currencySortOrderLabel);

  @override
  String get currencyDisplayDecimalsLabel => _resolve(
    'currencyDisplayDecimalsLabel',
    (loc) => loc.currencyDisplayDecimalsLabel,
  );

  @override
  String get currencyIsActiveLabel =>
      _resolve('currencyIsActiveLabel', (loc) => loc.currencyIsActiveLabel);

  @override
  String get currencyCodeFormatError =>
      _resolve('currencyCodeFormatError', (loc) => loc.currencyCodeFormatError);

  @override
  String get requiredField =>
      _resolve('requiredField', (loc) => loc.requiredField);

  @override
  String get displayDecimalsRangeError => _resolve(
    'displayDecimalsRangeError',
    (loc) => loc.displayDecimalsRangeError,
  );

  @override
  String get rateAmountLabel =>
      _resolve('rateAmountLabel', (loc) => loc.rateAmountLabel);

  @override
  String get effectiveAtLabel =>
      _resolve('effectiveAtLabel', (loc) => loc.effectiveAtLabel);

  @override
  String get sourceLabel => _resolve('sourceLabel', (loc) => loc.sourceLabel);

  @override
  String get rateMustBePositiveError =>
      _resolve('rateMustBePositiveError', (loc) => loc.rateMustBePositiveError);

  @override
  String get baseEqualsTargetError =>
      _resolve('baseEqualsTargetError', (loc) => loc.baseEqualsTargetError);

  @override
  String get submitButton =>
      _resolve('submitButton', (loc) => loc.submitButton);

  @override
  String get errorSystemCurrencyImmutable => _resolve(
    'errorSystemCurrencyImmutable',
    (loc) => loc.errorSystemCurrencyImmutable,
  );

  @override
  String get errorDuplicateCode =>
      _resolve('errorDuplicateCode', (loc) => loc.errorDuplicateCode);

  @override
  String get errorPermissionDenied =>
      _resolve('errorPermissionDenied', (loc) => loc.errorPermissionDenied);

  @override
  String get preferredCurrencyLabel =>
      _resolve('preferredCurrencyLabel', (loc) => loc.preferredCurrencyLabel);

  @override
  String get preferredCurrencyHelp =>
      _resolve('preferredCurrencyHelp', (loc) => loc.preferredCurrencyHelp);

  @override
  String get targetCurrencyFilterLabel => _resolve(
    'targetCurrencyFilterLabel',
    (loc) => loc.targetCurrencyFilterLabel,
  );

  @override
  String get targetCurrencyAnyLabel =>
      _resolve('targetCurrencyAnyLabel', (loc) => loc.targetCurrencyAnyLabel);

  @override
  String get derivedBadgeLabel =>
      _resolve('derivedBadgeLabel', (loc) => loc.derivedBadgeLabel);

  @override
  String get setByLabel => _resolve('setByLabel', (loc) => loc.setByLabel);

  @override
  String get noRatesYet => _resolve('noRatesYet', (loc) => loc.noRatesYet);

  @override
  String get systemActorLabel =>
      _resolve('systemActorLabel', (loc) => loc.systemActorLabel);

  @override
  String get unknownActorLabel =>
      _resolve('unknownActorLabel', (loc) => loc.unknownActorLabel);

  @override
  String exchangeRateHistoryPageTitleFor(String code) => _resolve(
    'exchangeRateHistoryPageTitleFor',
    (loc) => loc.exchangeRateHistoryPageTitleFor(code),
  );

  @override
  String setByLineFormat(String value) =>
      _resolve('setByLineFormat', (loc) => loc.setByLineFormat(value));

  @override
  String sourceLineFormat(String value) =>
      _resolve('sourceLineFormat', (loc) => loc.sourceLineFormat(value));

  @override
  String currencyOptionLabel(String code, String name) => _resolve(
    'currencyOptionLabel',
    (loc) => loc.currencyOptionLabel(code, name),
  );

  @override
  String exchangeRatePairLabel(String base, String target) => _resolve(
    'exchangeRatePairLabel',
    (loc) => loc.exchangeRatePairLabel(base, target),
  );

  @override
  String get retryButton => _resolve('retryButton', (loc) => loc.retryButton);

  @override
  String get errorCurrencyHasReferences => _resolve(
    'errorCurrencyHasReferences',
    (loc) => loc.errorCurrencyHasReferences,
  );

  @override
  String get errorCurrencyUnknown =>
      _resolve('errorCurrencyUnknown', (loc) => loc.errorCurrencyUnknown);

  @override
  String get errorValidationFailed =>
      _resolve('errorValidationFailed', (loc) => loc.errorValidationFailed);

  @override
  String get baseCurrencyLabel =>
      _resolve('baseCurrencyLabel', (loc) => loc.baseCurrencyLabel);

  @override
  String get targetCurrencyLabel =>
      _resolve('targetCurrencyLabel', (loc) => loc.targetCurrencyLabel);

  @override
  String get loadingHint => _resolve('loadingHint', (loc) => loc.loadingHint);

  @override
  String get locationsTileTitle =>
      _resolve('locationsTileTitle', (loc) => loc.locationsTileTitle);

  @override
  String get locationsListPageTitle =>
      _resolve('locationsListPageTitle', (loc) => loc.locationsListPageTitle);

  @override
  String get governorateDetailPageTitle => _resolve(
    'governorateDetailPageTitle',
    (loc) => loc.governorateDetailPageTitle,
  );

  @override
  String get cityDetailPageTitle =>
      _resolve('cityDetailPageTitle', (loc) => loc.cityDetailPageTitle);

  @override
  String get addGovernorateButton =>
      _resolve('addGovernorateButton', (loc) => loc.addGovernorateButton);

  @override
  String get addCityButton =>
      _resolve('addCityButton', (loc) => loc.addCityButton);

  @override
  String get addAreaButton =>
      _resolve('addAreaButton', (loc) => loc.addAreaButton);

  @override
  String get editAffordance =>
      _resolve('editAffordance', (loc) => loc.editAffordance);

  @override
  String get deleteAffordance =>
      _resolve('deleteAffordance', (loc) => loc.deleteAffordance);

  @override
  String get keyFieldLabel =>
      _resolve('keyFieldLabel', (loc) => loc.keyFieldLabel);

  @override
  String get displayNameArabicLabel =>
      _resolve('displayNameArabicLabel', (loc) => loc.displayNameArabicLabel);

  @override
  String get displayNameEnglishLabel =>
      _resolve('displayNameEnglishLabel', (loc) => loc.displayNameEnglishLabel);

  @override
  String get descriptionLabel =>
      _resolve('descriptionLabel', (loc) => loc.descriptionLabel);

  @override
  String get positionLabel =>
      _resolve('positionLabel', (loc) => loc.positionLabel);

  @override
  String get isActiveToggleLabel =>
      _resolve('isActiveToggleLabel', (loc) => loc.isActiveToggleLabel);

  @override
  String get hiddenBadge => _resolve('hiddenBadge', (loc) => loc.hiddenBadge);

  @override
  String get systemBadge => _resolve('systemBadge', (loc) => loc.systemBadge);

  @override
  String get arabicNameRequired =>
      _resolve('arabicNameRequired', (loc) => loc.arabicNameRequired);

  @override
  String get keyRequired => _resolve('keyRequired', (loc) => loc.keyRequired);

  @override
  String get keyAlreadyUsed =>
      _resolve('keyAlreadyUsed', (loc) => loc.keyAlreadyUsed);

  @override
  String get deleteConfirmTitle =>
      _resolve('deleteConfirmTitle', (loc) => loc.deleteConfirmTitle);

  @override
  String deleteConfirmGovernorateWithDeps(int cityCount, int areaCount) =>
      _resolve(
        'deleteConfirmGovernorateWithDeps',
        (loc) => loc.deleteConfirmGovernorateWithDeps(cityCount, areaCount),
      );

  @override
  String deleteConfirmCityWithDeps(int areaCount) => _resolve(
    'deleteConfirmCityWithDeps',
    (loc) => loc.deleteConfirmCityWithDeps(areaCount),
  );

  @override
  String get cannotDeleteSystemRow =>
      _resolve('cannotDeleteSystemRow', (loc) => loc.cannotDeleteSystemRow);

  @override
  String get locationPickerSelectGovernorate => _resolve(
    'locationPickerSelectGovernorate',
    (loc) => loc.locationPickerSelectGovernorate,
  );

  @override
  String get locationPickerSelectCity => _resolve(
    'locationPickerSelectCity',
    (loc) => loc.locationPickerSelectCity,
  );

  @override
  String get locationPickerSelectArea => _resolve(
    'locationPickerSelectArea',
    (loc) => loc.locationPickerSelectArea,
  );

  @override
  String get locationPickerSelectAreaRequired => _resolve(
    'locationPickerSelectAreaRequired',
    (loc) => loc.locationPickerSelectAreaRequired,
  );

  @override
  String get locationPickerNoAreasYet => _resolve(
    'locationPickerNoAreasYet',
    (loc) => loc.locationPickerNoAreasYet,
  );

  @override
  String get locationsLoadFailed =>
      _resolve('locationsLoadFailed', (loc) => loc.locationsLoadFailed);

  @override
  String get locationSaveFailed =>
      _resolve('locationSaveFailed', (loc) => loc.locationSaveFailed);

  @override
  String subtitleCityCount(int cityCount) =>
      _resolve('subtitleCityCount', (loc) => loc.subtitleCityCount(cityCount));

  @override
  String subtitleAreaCount(int areaCount) =>
      _resolve('subtitleAreaCount', (loc) => loc.subtitleAreaCount(areaCount));

  @override
  String cityDetailBreadcrumb(String governorateName, String cityName) =>
      _resolve(
        'cityDetailBreadcrumb',
        (loc) => loc.cityDetailBreadcrumb(governorateName, cityName),
      );

  @override
  String get actionActivate =>
      _resolve('actionActivate', (loc) => loc.actionActivate);

  @override
  String get actionDeactivate =>
      _resolve('actionDeactivate', (loc) => loc.actionDeactivate);

  @override
  String get validatorAreaSizePositive => _resolve(
    'validatorAreaSizePositive',
    (loc) => loc.validatorAreaSizePositive,
  );

  @override
  String get validatorAreaSizeTooLarge => _resolve(
    'validatorAreaSizeTooLarge',
    (loc) => loc.validatorAreaSizeTooLarge,
  );

  @override
  String get validatorPricePositive =>
      _resolve('validatorPricePositive', (loc) => loc.validatorPricePositive);

  @override
  String get validatorPriceTooPrecise => _resolve(
    'validatorPriceTooPrecise',
    (loc) => loc.validatorPriceTooPrecise,
  );

  @override
  String get validatorPhoneInvalid =>
      _resolve('validatorPhoneInvalid', (loc) => loc.validatorPhoneInvalid);

  @override
  String get validatorPhoneTooShort =>
      _resolve('validatorPhoneTooShort', (loc) => loc.validatorPhoneTooShort);

  @override
  String get publisherApprovalPendingTitle => _resolve(
    'publisherApprovalPendingTitle',
    (loc) => loc.publisherApprovalPendingTitle,
  );

  @override
  String get publisherApprovalPendingMessage => _resolve(
    'publisherApprovalPendingMessage',
    (loc) => loc.publisherApprovalPendingMessage,
  );

  @override
  String get tileCreateListing =>
      _resolve('tileCreateListing', (loc) => loc.tileCreateListing);

  @override
  String get tileMyListings =>
      _resolve('tileMyListings', (loc) => loc.tileMyListings);

  @override
  String get listingFormStepBasicsTitle => _resolve(
    'listingFormStepBasicsTitle',
    (loc) => loc.listingFormStepBasicsTitle,
  );

  @override
  String get listingFormStepLocationTitle => _resolve(
    'listingFormStepLocationTitle',
    (loc) => loc.listingFormStepLocationTitle,
  );

  @override
  String get listingFormStepDetailsTitle => _resolve(
    'listingFormStepDetailsTitle',
    (loc) => loc.listingFormStepDetailsTitle,
  );

  @override
  String get listingFormStepPricesTitle => _resolve(
    'listingFormStepPricesTitle',
    (loc) => loc.listingFormStepPricesTitle,
  );

  @override
  String get listingFormStepVisibilityTitle => _resolve(
    'listingFormStepVisibilityTitle',
    (loc) => loc.listingFormStepVisibilityTitle,
  );

  @override
  String get listingFormStepMediaTitle => _resolve(
    'listingFormStepMediaTitle',
    (loc) => loc.listingFormStepMediaTitle,
  );

  @override
  String get listingFormStepReviewTitle => _resolve(
    'listingFormStepReviewTitle',
    (loc) => loc.listingFormStepReviewTitle,
  );

  @override
  String get listingFormBackButton =>
      _resolve('listingFormBackButton', (loc) => loc.listingFormBackButton);

  @override
  String get listingFormContinueButton => _resolve(
    'listingFormContinueButton',
    (loc) => loc.listingFormContinueButton,
  );

  @override
  String get listingFormSubmitButton =>
      _resolve('listingFormSubmitButton', (loc) => loc.listingFormSubmitButton);

  @override
  String get listingFormJumpToStepButton => _resolve(
    'listingFormJumpToStepButton',
    (loc) => loc.listingFormJumpToStepButton,
  );

  @override
  String get listingFormSaveAndExitButton => _resolve(
    'listingFormSaveAndExitButton',
    (loc) => loc.listingFormSaveAndExitButton,
  );

  @override
  String get listingFormMediaPlaceholderBanner => _resolve(
    'listingFormMediaPlaceholderBanner',
    (loc) => loc.listingFormMediaPlaceholderBanner,
  );

  @override
  String get listingFormSubmitSuccess => _resolve(
    'listingFormSubmitSuccess',
    (loc) => loc.listingFormSubmitSuccess,
  );

  @override
  String get listingFormUnderReviewChip => _resolve(
    'listingFormUnderReviewChip',
    (loc) => loc.listingFormUnderReviewChip,
  );

  @override
  String get listingFormAddAnother =>
      _resolve('listingFormAddAnother', (loc) => loc.listingFormAddAnother);

  @override
  String get listingFormLoadingMessage => _resolve(
    'listingFormLoadingMessage',
    (loc) => loc.listingFormLoadingMessage,
  );

  @override
  String get fieldLabelTitle =>
      _resolve('fieldLabelTitle', (loc) => loc.fieldLabelTitle);

  @override
  String get fieldLabelPurpose =>
      _resolve('fieldLabelPurpose', (loc) => loc.fieldLabelPurpose);

  @override
  String get fieldLabelPropertyType =>
      _resolve('fieldLabelPropertyType', (loc) => loc.fieldLabelPropertyType);

  @override
  String get fieldLabelGovernorate =>
      _resolve('fieldLabelGovernorate', (loc) => loc.fieldLabelGovernorate);

  @override
  String get fieldLabelCity =>
      _resolve('fieldLabelCity', (loc) => loc.fieldLabelCity);

  @override
  String get fieldLabelArea =>
      _resolve('fieldLabelArea', (loc) => loc.fieldLabelArea);

  @override
  String get fieldLabelAddressText =>
      _resolve('fieldLabelAddressText', (loc) => loc.fieldLabelAddressText);

  @override
  String get fieldLabelAreaSize =>
      _resolve('fieldLabelAreaSize', (loc) => loc.fieldLabelAreaSize);

  @override
  String get fieldLabelRooms =>
      _resolve('fieldLabelRooms', (loc) => loc.fieldLabelRooms);

  @override
  String get fieldLabelBathrooms =>
      _resolve('fieldLabelBathrooms', (loc) => loc.fieldLabelBathrooms);

  @override
  String get fieldLabelFloor =>
      _resolve('fieldLabelFloor', (loc) => loc.fieldLabelFloor);

  @override
  String get fieldLabelYearBuilt =>
      _resolve('fieldLabelYearBuilt', (loc) => loc.fieldLabelYearBuilt);

  @override
  String get fieldLabelDescription =>
      _resolve('fieldLabelDescription', (loc) => loc.fieldLabelDescription);

  @override
  String get fieldLabelFurnished =>
      _resolve('fieldLabelFurnished', (loc) => loc.fieldLabelFurnished);

  @override
  String get fieldLabelParking =>
      _resolve('fieldLabelParking', (loc) => loc.fieldLabelParking);

  @override
  String get fieldLabelAmenities =>
      _resolve('fieldLabelAmenities', (loc) => loc.fieldLabelAmenities);

  @override
  String get fieldLabelPhone =>
      _resolve('fieldLabelPhone', (loc) => loc.fieldLabelPhone);

  @override
  String get fieldLabelWhatsapp =>
      _resolve('fieldLabelWhatsapp', (loc) => loc.fieldLabelWhatsapp);

  @override
  String get fieldLabelPhoneOrWhatsappHint => _resolve(
    'fieldLabelPhoneOrWhatsappHint',
    (loc) => loc.fieldLabelPhoneOrWhatsappHint,
  );

  @override
  String get fieldLabelHideUntil =>
      _resolve('fieldLabelHideUntil', (loc) => loc.fieldLabelHideUntil);

  @override
  String get fieldLabelHideUntilPick =>
      _resolve('fieldLabelHideUntilPick', (loc) => loc.fieldLabelHideUntilPick);

  @override
  String get fieldLabelLocationVisibility => _resolve(
    'fieldLabelLocationVisibility',
    (loc) => loc.fieldLabelLocationVisibility,
  );

  @override
  String get fieldLabelContactNameVisibility => _resolve(
    'fieldLabelContactNameVisibility',
    (loc) => loc.fieldLabelContactNameVisibility,
  );

  @override
  String get fieldLabelCurrency =>
      _resolve('fieldLabelCurrency', (loc) => loc.fieldLabelCurrency);

  @override
  String get fieldLabelPrice =>
      _resolve('fieldLabelPrice', (loc) => loc.fieldLabelPrice);

  @override
  String get listingPurposeSale =>
      _resolve('listingPurposeSale', (loc) => loc.listingPurposeSale);

  @override
  String get listingPurposeRent =>
      _resolve('listingPurposeRent', (loc) => loc.listingPurposeRent);

  @override
  String get listingPurposeDailyRent =>
      _resolve('listingPurposeDailyRent', (loc) => loc.listingPurposeDailyRent);

  @override
  String get listingPurposeInvestment => _resolve(
    'listingPurposeInvestment',
    (loc) => loc.listingPurposeInvestment,
  );

  @override
  String get propertyTypeApartment =>
      _resolve('propertyTypeApartment', (loc) => loc.propertyTypeApartment);

  @override
  String get propertyTypeVilla =>
      _resolve('propertyTypeVilla', (loc) => loc.propertyTypeVilla);

  @override
  String get propertyTypeLand =>
      _resolve('propertyTypeLand', (loc) => loc.propertyTypeLand);

  @override
  String get propertyTypeShop =>
      _resolve('propertyTypeShop', (loc) => loc.propertyTypeShop);

  @override
  String get propertyTypeOffice =>
      _resolve('propertyTypeOffice', (loc) => loc.propertyTypeOffice);

  @override
  String get propertyTypeFarm =>
      _resolve('propertyTypeFarm', (loc) => loc.propertyTypeFarm);

  @override
  String get propertyTypeWarehouse =>
      _resolve('propertyTypeWarehouse', (loc) => loc.propertyTypeWarehouse);

  @override
  String get propertyTypeOther =>
      _resolve('propertyTypeOther', (loc) => loc.propertyTypeOther);

  @override
  String get locationVisibilityHidden => _resolve(
    'locationVisibilityHidden',
    (loc) => loc.locationVisibilityHidden,
  );

  @override
  String get locationVisibilityApproximate => _resolve(
    'locationVisibilityApproximate',
    (loc) => loc.locationVisibilityApproximate,
  );

  @override
  String get locationVisibilityExact =>
      _resolve('locationVisibilityExact', (loc) => loc.locationVisibilityExact);

  @override
  String get locationVisibilityAdminOnly => _resolve(
    'locationVisibilityAdminOnly',
    (loc) => loc.locationVisibilityAdminOnly,
  );

  @override
  String get contactNameVisibilityPublic => _resolve(
    'contactNameVisibilityPublic',
    (loc) => loc.contactNameVisibilityPublic,
  );

  @override
  String get contactNameVisibilityAdminOnly => _resolve(
    'contactNameVisibilityAdminOnly',
    (loc) => loc.contactNameVisibilityAdminOnly,
  );

  @override
  String get amenityElevator =>
      _resolve('amenityElevator', (loc) => loc.amenityElevator);

  @override
  String get amenityBalcony =>
      _resolve('amenityBalcony', (loc) => loc.amenityBalcony);

  @override
  String get amenitySwimmingPool =>
      _resolve('amenitySwimmingPool', (loc) => loc.amenitySwimmingPool);

  @override
  String get amenityGarden =>
      _resolve('amenityGarden', (loc) => loc.amenityGarden);

  @override
  String get amenitySecurity =>
      _resolve('amenitySecurity', (loc) => loc.amenitySecurity);

  @override
  String get amenityGenerator =>
      _resolve('amenityGenerator', (loc) => loc.amenityGenerator);

  @override
  String get amenitySolarPanels =>
      _resolve('amenitySolarPanels', (loc) => loc.amenitySolarPanels);

  @override
  String get amenityCentralHeating =>
      _resolve('amenityCentralHeating', (loc) => loc.amenityCentralHeating);

  @override
  String get amenityAirConditioning =>
      _resolve('amenityAirConditioning', (loc) => loc.amenityAirConditioning);

  @override
  String get amenityFurnishedKitchen =>
      _resolve('amenityFurnishedKitchen', (loc) => loc.amenityFurnishedKitchen);

  @override
  String get requiredFieldChipLabel =>
      _resolve('requiredFieldChipLabel', (loc) => loc.requiredFieldChipLabel);

  @override
  String get pricePreviewLabel =>
      _resolve('pricePreviewLabel', (loc) => loc.pricePreviewLabel);

  @override
  String currencyDropdownOption(String code, String symbol) => _resolve(
    'currencyDropdownOption',
    (loc) => loc.currencyDropdownOption(code, symbol),
  );

  @override
  String get validatorAreaMissingCentroid => _resolve(
    'validatorAreaMissingCentroid',
    (loc) => loc.validatorAreaMissingCentroid,
  );

  @override
  String get submitFailureTitle =>
      _resolve('submitFailureTitle', (loc) => loc.submitFailureTitle);

  @override
  String get submitFailureMissingFieldsHeader => _resolve(
    'submitFailureMissingFieldsHeader',
    (loc) => loc.submitFailureMissingFieldsHeader,
  );

  @override
  String get submitErrorUnknown =>
      _resolve('submitErrorUnknown', (loc) => loc.submitErrorUnknown);

  @override
  String get actionDismiss =>
      _resolve('actionDismiss', (loc) => loc.actionDismiss);

  @override
  String get missingFieldListingsTitle => _resolve(
    'missingFieldListingsTitle',
    (loc) => loc.missingFieldListingsTitle,
  );

  @override
  String get missingFieldListingsPurpose => _resolve(
    'missingFieldListingsPurpose',
    (loc) => loc.missingFieldListingsPurpose,
  );

  @override
  String get missingFieldListingsPropertyType => _resolve(
    'missingFieldListingsPropertyType',
    (loc) => loc.missingFieldListingsPropertyType,
  );

  @override
  String get missingFieldListingsGovernorateId => _resolve(
    'missingFieldListingsGovernorateId',
    (loc) => loc.missingFieldListingsGovernorateId,
  );

  @override
  String get missingFieldListingsCityId => _resolve(
    'missingFieldListingsCityId',
    (loc) => loc.missingFieldListingsCityId,
  );

  @override
  String get missingFieldListingsAreaId => _resolve(
    'missingFieldListingsAreaId',
    (loc) => loc.missingFieldListingsAreaId,
  );

  @override
  String get missingFieldListingsAddressText => _resolve(
    'missingFieldListingsAddressText',
    (loc) => loc.missingFieldListingsAddressText,
  );

  @override
  String get missingFieldListingsAreaSize => _resolve(
    'missingFieldListingsAreaSize',
    (loc) => loc.missingFieldListingsAreaSize,
  );

  @override
  String get missingFieldListingsRooms => _resolve(
    'missingFieldListingsRooms',
    (loc) => loc.missingFieldListingsRooms,
  );

  @override
  String get missingFieldListingsBathrooms => _resolve(
    'missingFieldListingsBathrooms',
    (loc) => loc.missingFieldListingsBathrooms,
  );

  @override
  String get missingFieldListingsPhoneOrWhatsapp => _resolve(
    'missingFieldListingsPhoneOrWhatsapp',
    (loc) => loc.missingFieldListingsPhoneOrWhatsapp,
  );

  @override
  String get missingFieldListingPricesPrimary => _resolve(
    'missingFieldListingPricesPrimary',
    (loc) => loc.missingFieldListingPricesPrimary,
  );

  @override
  String get myListingsPageTitle =>
      _resolve('myListingsPageTitle', (loc) => loc.myListingsPageTitle);

  @override
  String get myListingsEmptyTitle =>
      _resolve('myListingsEmptyTitle', (loc) => loc.myListingsEmptyTitle);

  @override
  String get myListingsEmptyCtaCreateFirst => _resolve(
    'myListingsEmptyCtaCreateFirst',
    (loc) => loc.myListingsEmptyCtaCreateFirst,
  );

  @override
  String get myListingsErrorPrefix =>
      _resolve('myListingsErrorPrefix', (loc) => loc.myListingsErrorPrefix);

  @override
  String get filterChipAll =>
      _resolve('filterChipAll', (loc) => loc.filterChipAll);

  @override
  String get statusBadgeDraft =>
      _resolve('statusBadgeDraft', (loc) => loc.statusBadgeDraft);

  @override
  String get statusBadgePendingReview => _resolve(
    'statusBadgePendingReview',
    (loc) => loc.statusBadgePendingReview,
  );

  @override
  String get statusBadgeApproved =>
      _resolve('statusBadgeApproved', (loc) => loc.statusBadgeApproved);

  @override
  String get statusBadgeRejected =>
      _resolve('statusBadgeRejected', (loc) => loc.statusBadgeRejected);

  @override
  String get statusBadgePaused =>
      _resolve('statusBadgePaused', (loc) => loc.statusBadgePaused);

  @override
  String get statusBadgeSold =>
      _resolve('statusBadgeSold', (loc) => loc.statusBadgeSold);

  @override
  String get statusBadgeRented =>
      _resolve('statusBadgeRented', (loc) => loc.statusBadgeRented);

  @override
  String get statusBadgeExpired =>
      _resolve('statusBadgeExpired', (loc) => loc.statusBadgeExpired);

  @override
  String get statusBadgeDeleted =>
      _resolve('statusBadgeDeleted', (loc) => loc.statusBadgeDeleted);

  @override
  String get rejectionReasonLabel =>
      _resolve('rejectionReasonLabel', (loc) => loc.rejectionReasonLabel);

  @override
  String get resubmitButton =>
      _resolve('resubmitButton', (loc) => loc.resubmitButton);

  @override
  String get approvedNotEditableMessage => _resolve(
    'approvedNotEditableMessage',
    (loc) => loc.approvedNotEditableMessage,
  );

  @override
  String get readOnlyPreviewTitle =>
      _resolve('readOnlyPreviewTitle', (loc) => loc.readOnlyPreviewTitle);

  // ── Phase 11 MediaPicker strings ─────────────────────────────────────────

  @override
  String get mediaAddImages =>
      _resolve('mediaAddImages', (loc) => loc.mediaAddImages);

  @override
  String get mediaAddVideo =>
      _resolve('mediaAddVideo', (loc) => loc.mediaAddVideo);

  @override
  String get mediaActionSetMain =>
      _resolve('mediaActionSetMain', (loc) => loc.mediaActionSetMain);

  @override
  String get mediaActionDelete =>
      _resolve('mediaActionDelete', (loc) => loc.mediaActionDelete);

  @override
  String get mediaActionReorderHint =>
      _resolve('mediaActionReorderHint', (loc) => loc.mediaActionReorderHint);

  @override
  String get mediaThumbnailMainBadge =>
      _resolve('mediaThumbnailMainBadge', (loc) => loc.mediaThumbnailMainBadge);

  @override
  String get mediaErrorGalleryPermissionDenied => _resolve(
    'mediaErrorGalleryPermissionDenied',
    (loc) => loc.mediaErrorGalleryPermissionDenied,
  );

  @override
  String get mediaActionOpenSettings =>
      _resolve('mediaActionOpenSettings', (loc) => loc.mediaActionOpenSettings);

  @override
  String get mediaErrorUploadFailed =>
      _resolve('mediaErrorUploadFailed', (loc) => loc.mediaErrorUploadFailed);

  @override
  String get mediaReadOnlyPendingOrApproved => _resolve(
    'mediaReadOnlyPendingOrApproved',
    (loc) => loc.mediaReadOnlyPendingOrApproved,
  );

  @override
  String get mediaErrorFormatNotSupported => _resolve(
    'mediaErrorFormatNotSupported',
    (loc) => loc.mediaErrorFormatNotSupported,
  );

  @override
  String get mediaErrorImageTooLarge =>
      _resolve('mediaErrorImageTooLarge', (loc) => loc.mediaErrorImageTooLarge);

  @override
  String get mediaErrorTimeout =>
      _resolve('mediaErrorTimeout', (loc) => loc.mediaErrorTimeout);

  @override
  String get mediaErrorWatermarkAssetMissing => _resolve(
    'mediaErrorWatermarkAssetMissing',
    (loc) => loc.mediaErrorWatermarkAssetMissing,
  );

  @override
  String get mediaErrorVideoFormatMustBeMp4 => _resolve(
    'mediaErrorVideoFormatMustBeMp4',
    (loc) => loc.mediaErrorVideoFormatMustBeMp4,
  );

  @override
  String get mediaErrorVideoSizeExceeded => _resolve(
    'mediaErrorVideoSizeExceeded',
    (loc) => loc.mediaErrorVideoSizeExceeded,
  );

  @override
  String get mediaCapImages10 =>
      _resolve('mediaCapImages10', (loc) => loc.mediaCapImages10);

  @override
  String get mediaCapVideos2 =>
      _resolve('mediaCapVideos2', (loc) => loc.mediaCapVideos2);

  @override
  String get mediaReviewCarouselLabel => _resolve(
    'mediaReviewCarouselLabel',
    (loc) => loc.mediaReviewCarouselLabel,
  );

  @override
  String get submitErrorImagesBelowMinimum => _resolve(
    'submitErrorImagesBelowMinimum',
    (loc) => loc.submitErrorImagesBelowMinimum,
  );

  // ── Phase 12 — Listing Approval Workflow (admin) ──────────────────────────

  @override
  String get adminTilePendingReview =>
      _resolve('adminTilePendingReview', (loc) => loc.adminTilePendingReview);

  @override
  String get adminQueueTitle =>
      _resolve('adminQueueTitle', (loc) => loc.adminQueueTitle);

  @override
  String get adminQueueEmpty =>
      _resolve('adminQueueEmpty', (loc) => loc.adminQueueEmpty);

  @override
  String get adminQueueSubmittedAtJustNow => _resolve(
    'adminQueueSubmittedAtJustNow',
    (loc) => loc.adminQueueSubmittedAtJustNow,
  );

  @override
  String adminQueueSubmittedAtMinutes(int n) =>
      _active.adminQueueSubmittedAtMinutes(n);

  @override
  String adminQueueSubmittedAtHours(int n) =>
      _active.adminQueueSubmittedAtHours(n);

  @override
  String adminQueueSubmittedAtDays(int n) =>
      _active.adminQueueSubmittedAtDays(n);

  @override
  String get adminQueuePublisherPrefix => _resolve(
    'adminQueuePublisherPrefix',
    (loc) => loc.adminQueuePublisherPrefix,
  );

  @override
  String get adminPreviewTitle =>
      _resolve('adminPreviewTitle', (loc) => loc.adminPreviewTitle);

  @override
  String get adminPreviewCtaApprove =>
      _resolve('adminPreviewCtaApprove', (loc) => loc.adminPreviewCtaApprove);

  @override
  String get adminPreviewCtaReject =>
      _resolve('adminPreviewCtaReject', (loc) => loc.adminPreviewCtaReject);

  @override
  String get adminApproveDialogTitle =>
      _resolve('adminApproveDialogTitle', (loc) => loc.adminApproveDialogTitle);

  @override
  String get adminApproveDialogBody =>
      _resolve('adminApproveDialogBody', (loc) => loc.adminApproveDialogBody);

  @override
  String get adminApproveDialogConfirm => _resolve(
    'adminApproveDialogConfirm',
    (loc) => loc.adminApproveDialogConfirm,
  );

  @override
  String get adminApproveDialogCancel => _resolve(
    'adminApproveDialogCancel',
    (loc) => loc.adminApproveDialogCancel,
  );

  @override
  String get adminErrorPermissionDenied => _resolve(
    'adminErrorPermissionDenied',
    (loc) => loc.adminErrorPermissionDenied,
  );

  @override
  String get adminErrorInvalidStatusTransition => _resolve(
    'adminErrorInvalidStatusTransition',
    (loc) => loc.adminErrorInvalidStatusTransition,
  );

  @override
  String get adminErrorAlreadyActedOn => _resolve(
    'adminErrorAlreadyActedOn',
    (loc) => loc.adminErrorAlreadyActedOn,
  );

  @override
  String get adminErrorUnknown =>
      _resolve('adminErrorUnknown', (loc) => loc.adminErrorUnknown);

  @override
  String get adminToastApproveSuccess => _resolve(
    'adminToastApproveSuccess',
    (loc) => loc.adminToastApproveSuccess,
  );

  @override
  String get mediaGalleryEmpty =>
      _resolve('mediaGalleryEmpty', (loc) => loc.mediaGalleryEmpty);

  @override
  String get mediaGalleryVideoPlay =>
      _resolve('mediaGalleryVideoPlay', (loc) => loc.mediaGalleryVideoPlay);

  @override
  String get descriptionReadMore =>
      _resolve('descriptionReadMore', (loc) => loc.descriptionReadMore);

  @override
  String get descriptionReadLess =>
      _resolve('descriptionReadLess', (loc) => loc.descriptionReadLess);

  @override
  String get listingStatusDraft =>
      _resolve('listingStatusDraft', (loc) => loc.listingStatusDraft);

  @override
  String get listingStatusPendingReview =>
      _resolve('listingStatusPendingReview', (loc) => loc.listingStatusPendingReview);

  @override
  String get listingStatusApproved =>
      _resolve('listingStatusApproved', (loc) => loc.listingStatusApproved);

  @override
  String get listingStatusRejected =>
      _resolve('listingStatusRejected', (loc) => loc.listingStatusRejected);

  @override
  String get listingStatusPaused =>
      _resolve('listingStatusPaused', (loc) => loc.listingStatusPaused);

  @override
  String get listingStatusSold =>
      _resolve('listingStatusSold', (loc) => loc.listingStatusSold);

  @override
  String get listingStatusRented =>
      _resolve('listingStatusRented', (loc) => loc.listingStatusRented);

  @override
  String get listingStatusExpired =>
      _resolve('listingStatusExpired', (loc) => loc.listingStatusExpired);

  @override
  String get listingStatusDeleted =>
      _resolve('listingStatusDeleted', (loc) => loc.listingStatusDeleted);

  @override
  String priceOriginallyWas(String price) => _active.priceOriginallyWas(price);

  // ── Phase 12 / US2 — Reject flow + publisher rejection banner ────────────

  @override
  String get rejectDialogTitle =>
      _resolve('rejectDialogTitle', (loc) => loc.rejectDialogTitle);

  @override
  String get rejectDialogDetailLabelOptional => _resolve(
    'rejectDialogDetailLabelOptional',
    (loc) => loc.rejectDialogDetailLabelOptional,
  );

  @override
  String get rejectDialogDetailLabelRequired => _resolve(
    'rejectDialogDetailLabelRequired',
    (loc) => loc.rejectDialogDetailLabelRequired,
  );

  @override
  String get rejectDialogDetailHintOther => _resolve(
    'rejectDialogDetailHintOther',
    (loc) => loc.rejectDialogDetailHintOther,
  );

  @override
  String rejectDialogCounter(int count) => _active.rejectDialogCounter(count);

  @override
  String get rejectDialogConfirm =>
      _resolve('rejectDialogConfirm', (loc) => loc.rejectDialogConfirm);

  @override
  String get rejectDialogCancel =>
      _resolve('rejectDialogCancel', (loc) => loc.rejectDialogCancel);

  @override
  String get rejectPresetMissingOrLowQualityPhotos => _resolve(
    'rejectPresetMissingOrLowQualityPhotos',
    (loc) => loc.rejectPresetMissingOrLowQualityPhotos,
  );

  @override
  String get rejectPresetIncorrectLocation => _resolve(
    'rejectPresetIncorrectLocation',
    (loc) => loc.rejectPresetIncorrectLocation,
  );

  @override
  String get rejectPresetUnrealisticPrice => _resolve(
    'rejectPresetUnrealisticPrice',
    (loc) => loc.rejectPresetUnrealisticPrice,
  );

  @override
  String get rejectPresetIncompleteDescription => _resolve(
    'rejectPresetIncompleteDescription',
    (loc) => loc.rejectPresetIncompleteDescription,
  );

  @override
  String get rejectPresetDuplicateListing => _resolve(
    'rejectPresetDuplicateListing',
    (loc) => loc.rejectPresetDuplicateListing,
  );

  @override
  String get rejectPresetOther =>
      _resolve('rejectPresetOther', (loc) => loc.rejectPresetOther);

  @override
  String publisherRejectionAttribution(String timeAgo) =>
      _active.publisherRejectionAttribution(timeAgo);

  @override
  String get publisherRejectionResubmit => _resolve(
    'publisherRejectionResubmit',
    (loc) => loc.publisherRejectionResubmit,
  );

  @override
  String get publisherRejectionViewHistory => _resolve(
    'publisherRejectionViewHistory',
    (loc) => loc.publisherRejectionViewHistory,
  );

  @override
  String get adminErrorInvalidReasonPreset => _resolve(
    'adminErrorInvalidReasonPreset',
    (loc) => loc.adminErrorInvalidReasonPreset,
  );

  @override
  String get adminErrorReasonDetailTooLong => _resolve(
    'adminErrorReasonDetailTooLong',
    (loc) => loc.adminErrorReasonDetailTooLong,
  );

  @override
  String get adminToastRejectSuccess =>
      _resolve('adminToastRejectSuccess', (loc) => loc.adminToastRejectSuccess);

  // ── Phase 12 / US6 — Publisher moderation history page ───────────────────

  @override
  String get publisherHistoryTitle =>
      _resolve('publisherHistoryTitle', (loc) => loc.publisherHistoryTitle);

  @override
  String get publisherHistoryAdminTeam => _resolve(
    'publisherHistoryAdminTeam',
    (loc) => loc.publisherHistoryAdminTeam,
  );

  @override
  String get publisherHistoryFirstEntry => _resolve(
    'publisherHistoryFirstEntry',
    (loc) => loc.publisherHistoryFirstEntry,
  );

  @override
  String get publisherHistoryEmpty =>
      _resolve('publisherHistoryEmpty', (loc) => loc.publisherHistoryEmpty);

  @override
  String get publisherHistoryStatusDraft => _resolve(
    'publisherHistoryStatusDraft',
    (loc) => loc.publisherHistoryStatusDraft,
  );

  @override
  String get publisherHistoryStatusPendingReview => _resolve(
    'publisherHistoryStatusPendingReview',
    (loc) => loc.publisherHistoryStatusPendingReview,
  );

  @override
  String get publisherHistoryStatusApproved => _resolve(
    'publisherHistoryStatusApproved',
    (loc) => loc.publisherHistoryStatusApproved,
  );

  @override
  String get publisherHistoryStatusRejected => _resolve(
    'publisherHistoryStatusRejected',
    (loc) => loc.publisherHistoryStatusRejected,
  );

  @override
  String get publisherHistoryStatusPaused => _resolve(
    'publisherHistoryStatusPaused',
    (loc) => loc.publisherHistoryStatusPaused,
  );

  @override
  String get publisherHistoryStatusSold => _resolve(
    'publisherHistoryStatusSold',
    (loc) => loc.publisherHistoryStatusSold,
  );

  @override
  String get publisherHistoryStatusRented => _resolve(
    'publisherHistoryStatusRented',
    (loc) => loc.publisherHistoryStatusRented,
  );

  @override
  String get publisherHistoryStatusExpired => _resolve(
    'publisherHistoryStatusExpired',
    (loc) => loc.publisherHistoryStatusExpired,
  );

  @override
  String get publisherHistoryStatusDeleted => _resolve(
    'publisherHistoryStatusDeleted',
    (loc) => loc.publisherHistoryStatusDeleted,
  );

  // ── Phase 13 — Public Home & Listing Details ──────────────────────────────

  // §5.1 HomePage chrome
  @override
  String get home_app_bar_title =>
      _resolve('home_app_bar_title', (loc) => loc.home_app_bar_title);

  @override
  String get home_sign_in_icon_tooltip => _resolve(
    'home_sign_in_icon_tooltip',
    (loc) => loc.home_sign_in_icon_tooltip,
  );

  @override
  String get home_search_bar_placeholder => _resolve(
    'home_search_bar_placeholder',
    (loc) => loc.home_search_bar_placeholder,
  );

  @override
  String get home_crown_location =>
      _resolve('home_crown_location', (loc) => loc.home_crown_location);

  @override
  String get home_latest_listings_header => _resolve(
    'home_latest_listings_header',
    (loc) => loc.home_latest_listings_header,
  );

  @override
  String get home_no_listings_yet =>
      _resolve('home_no_listings_yet', (loc) => loc.home_no_listings_yet);

  @override
  String get home_no_more_listings =>
      _resolve('home_no_more_listings', (loc) => loc.home_no_more_listings);

  // §5.2 Q1=A snackbar keys
  @override
  String get home_search_coming_soon =>
      _resolve('home_search_coming_soon', (loc) => loc.home_search_coming_soon);

  @override
  String home_property_shortcut_coming_soon(String type) => _resolve(
    'home_property_shortcut_coming_soon',
    (loc) => loc.home_property_shortcut_coming_soon(type),
  );

  // §5.3 Q2=A snackbar keys
  @override
  String get contact_call_coming_soon => _resolve(
    'contact_call_coming_soon',
    (loc) => loc.contact_call_coming_soon,
  );

  @override
  String get contact_whatsapp_coming_soon => _resolve(
    'contact_whatsapp_coming_soon',
    (loc) => loc.contact_whatsapp_coming_soon,
  );

  @override
  String get contact_inquiry_coming_soon => _resolve(
    'contact_inquiry_coming_soon',
    (loc) => loc.contact_inquiry_coming_soon,
  );

  @override
  String get action_favorite_coming_soon => _resolve(
    'action_favorite_coming_soon',
    (loc) => loc.action_favorite_coming_soon,
  );

  @override
  String get action_share_coming_soon => _resolve(
    'action_share_coming_soon',
    (loc) => loc.action_share_coming_soon,
  );

  @override
  String get action_report_coming_soon => _resolve(
    'action_report_coming_soon',
    (loc) => loc.action_report_coming_soon,
  );

  // §5.4 Q3=A reserved forward-state keys
  @override
  String get auth_required_please_sign_in => _resolve(
    'auth_required_please_sign_in',
    (loc) => loc.auth_required_please_sign_in,
  );

  @override
  String get auth_required_sign_in_action => _resolve(
    'auth_required_sign_in_action',
    (loc) => loc.auth_required_sign_in_action,
  );

  // §5.5 ListingDetailsPage chrome
  @override
  String get listing_details_not_found_title => _resolve(
    'listing_details_not_found_title',
    (loc) => loc.listing_details_not_found_title,
  );

  @override
  String get listing_details_not_found_return_home => _resolve(
    'listing_details_not_found_return_home',
    (loc) => loc.listing_details_not_found_return_home,
  );

  @override
  String listing_details_publisher_label(String name) => _resolve(
    'listing_details_publisher_label',
    (loc) => loc.listing_details_publisher_label(name),
  );

  // §5.6 CTA labels
  @override
  String get contact_section_title =>
      _resolve('contact_section_title', (loc) => loc.contact_section_title);

  @override
  String get cta_call => _resolve('cta_call', (loc) => loc.cta_call);

  @override
  String get cta_whatsapp =>
      _resolve('cta_whatsapp', (loc) => loc.cta_whatsapp);

  @override
  String get cta_send_inquiry =>
      _resolve('cta_send_inquiry', (loc) => loc.cta_send_inquiry);

  @override
  String get cta_favorite =>
      _resolve('cta_favorite', (loc) => loc.cta_favorite);

  @override
  String get cta_share => _resolve('cta_share', (loc) => loc.cta_share);

  @override
  String get cta_report => _resolve('cta_report', (loc) => loc.cta_report);

  // §5.7 Error states
  @override
  String get error_could_not_load_listings => _resolve(
    'error_could_not_load_listings',
    (loc) => loc.error_could_not_load_listings,
  );

  @override
  String get error_could_not_load_listing => _resolve(
    'error_could_not_load_listing',
    (loc) => loc.error_could_not_load_listing,
  );

  @override
  String get action_retry =>
      _resolve('action_retry', (loc) => loc.action_retry);

  @override
  String get image_unavailable =>
      _resolve('image_unavailable', (loc) => loc.image_unavailable);

  // §5.8 Empty-state CTAs
  @override
  String get home_empty_publish_first_listing => _resolve(
    'home_empty_publish_first_listing',
    (loc) => loc.home_empty_publish_first_listing,
  );

  @override
  String get home_empty_sign_in_to_publish => _resolve(
    'home_empty_sign_in_to_publish',
    (loc) => loc.home_empty_sign_in_to_publish,
  );

  // ── Phase 14 — Search & Filters ──────────────────────────────────────────

  // §3.1 Search Page Chrome
  @override
  String get search_placeholder =>
      _resolve('search_placeholder', (loc) => loc.search_placeholder);

  @override
  String get search_filters_button =>
      _resolve('search_filters_button', (loc) => loc.search_filters_button);

  @override
  String get search_sort_label =>
      _resolve('search_sort_label', (loc) => loc.search_sort_label);

  @override
  String search_results_count(int count) => _resolve(
    'search_results_count',
    (loc) => loc.search_results_count(count),
  );

  // §3.2 Sort Options
  @override
  String get search_sort_newest =>
      _resolve('search_sort_newest', (loc) => loc.search_sort_newest);

  @override
  String get search_sort_price_asc =>
      _resolve('search_sort_price_asc', (loc) => loc.search_sort_price_asc);

  @override
  String get search_sort_price_desc =>
      _resolve('search_sort_price_desc', (loc) => loc.search_sort_price_desc);

  // §3.3 Filter Sheet Chrome
  @override
  String get search_filter_sheet_title => _resolve(
    'search_filter_sheet_title',
    (loc) => loc.search_filter_sheet_title,
  );

  @override
  String get search_filter_apply =>
      _resolve('search_filter_apply', (loc) => loc.search_filter_apply);

  @override
  String get search_filter_reset =>
      _resolve('search_filter_reset', (loc) => loc.search_filter_reset);

  // §3.4 Filter Dimensions
  @override
  String get search_filter_purpose_label => _resolve(
    'search_filter_purpose_label',
    (loc) => loc.search_filter_purpose_label,
  );

  @override
  String get search_filter_property_type_label => _resolve(
    'search_filter_property_type_label',
    (loc) => loc.search_filter_property_type_label,
  );

  @override
  String get search_filter_location_label => _resolve(
    'search_filter_location_label',
    (loc) => loc.search_filter_location_label,
  );

  @override
  String get search_filter_governorate_hint => _resolve(
    'search_filter_governorate_hint',
    (loc) => loc.search_filter_governorate_hint,
  );

  @override
  String get search_filter_city_hint =>
      _resolve('search_filter_city_hint', (loc) => loc.search_filter_city_hint);

  @override
  String get search_filter_area_hint =>
      _resolve('search_filter_area_hint', (loc) => loc.search_filter_area_hint);

  @override
  String get search_filter_price_range_label => _resolve(
    'search_filter_price_range_label',
    (loc) => loc.search_filter_price_range_label,
  );

  @override
  String get search_filter_price_min_hint => _resolve(
    'search_filter_price_min_hint',
    (loc) => loc.search_filter_price_min_hint,
  );

  @override
  String get search_filter_price_max_hint => _resolve(
    'search_filter_price_max_hint',
    (loc) => loc.search_filter_price_max_hint,
  );

  @override
  String get search_filter_price_currency_label => _resolve(
    'search_filter_price_currency_label',
    (loc) => loc.search_filter_price_currency_label,
  );

  @override
  String get search_filter_price_min_max_error => _resolve(
    'search_filter_price_min_max_error',
    (loc) => loc.search_filter_price_min_max_error,
  );

  @override
  String get search_filter_price_no_exchange_rate => _resolve(
    'search_filter_price_no_exchange_rate',
    (loc) => loc.search_filter_price_no_exchange_rate,
  );

  @override
  String get search_filter_rooms_label => _resolve(
    'search_filter_rooms_label',
    (loc) => loc.search_filter_rooms_label,
  );

  @override
  String get search_filter_rooms_exactly => _resolve(
    'search_filter_rooms_exactly',
    (loc) => loc.search_filter_rooms_exactly,
  );

  @override
  String get search_filter_rooms_at_least => _resolve(
    'search_filter_rooms_at_least',
    (loc) => loc.search_filter_rooms_at_least,
  );

  @override
  String get search_filter_bathrooms_label => _resolve(
    'search_filter_bathrooms_label',
    (loc) => loc.search_filter_bathrooms_label,
  );

  @override
  String get search_filter_area_size_label => _resolve(
    'search_filter_area_size_label',
    (loc) => loc.search_filter_area_size_label,
  );

  // §3.5 Empty / Error States
  @override
  String get search_empty_title =>
      _resolve('search_empty_title', (loc) => loc.search_empty_title);

  @override
  String get search_empty_subtitle =>
      _resolve('search_empty_subtitle', (loc) => loc.search_empty_subtitle);

  @override
  String get search_empty_clear_filters => _resolve(
    'search_empty_clear_filters',
    (loc) => loc.search_empty_clear_filters,
  );

  @override
  String search_arabic_hint(String suggestion) => _resolve(
    'search_arabic_hint',
    (loc) => loc.search_arabic_hint(suggestion),
  );

  @override
  String get search_loading =>
      _resolve('search_loading', (loc) => loc.search_loading);

  @override
  String get search_error_message =>
      _resolve('search_error_message', (loc) => loc.search_error_message);

  @override
  String get search_error_retry =>
      _resolve('search_error_retry', (loc) => loc.search_error_retry);

  // ── Phase 15 Map View ─────────────────────────────────────────────────────

  // §1 Map page chrome
  @override
  String get map_page_title =>
      _resolve('map_page_title', (loc) => loc.map_page_title);

  @override
  String get map_osm_attribution =>
      _resolve('map_osm_attribution', (loc) => loc.map_osm_attribution);

  @override
  String get map_empty_state_no_listings => _resolve(
    'map_empty_state_no_listings',
    (loc) => loc.map_empty_state_no_listings,
  );

  @override
  String get map_error_load_failed =>
      _resolve('map_error_load_failed', (loc) => loc.map_error_load_failed);

  @override
  String get map_error_retry_action =>
      _resolve('map_error_retry_action', (loc) => loc.map_error_retry_action);

  @override
  String get map_tiles_unavailable =>
      _resolve('map_tiles_unavailable', (loc) => loc.map_tiles_unavailable);

  // §2 Marker preview popover
  @override
  String get map_marker_view_details_action => _resolve(
    'map_marker_view_details_action',
    (loc) => loc.map_marker_view_details_action,
  );

  @override
  String get map_marker_approximate_location_label => _resolve(
    'map_marker_approximate_location_label',
    (loc) => loc.map_marker_approximate_location_label,
  );

  @override
  String get map_marker_image_unavailable => _resolve(
    'map_marker_image_unavailable',
    (loc) => loc.map_marker_image_unavailable,
  );

  // §3 Center on my location FAB
  @override
  String get map_fab_center_on_me_tooltip => _resolve(
    'map_fab_center_on_me_tooltip',
    (loc) => loc.map_fab_center_on_me_tooltip,
  );

  @override
  String get map_geolocation_permission_denied_message => _resolve(
    'map_geolocation_permission_denied_message',
    (loc) => loc.map_geolocation_permission_denied_message,
  );

  @override
  String get map_geolocation_permission_permanently_denied_message => _resolve(
    'map_geolocation_permission_permanently_denied_message',
    (loc) => loc.map_geolocation_permission_permanently_denied_message,
  );

  @override
  String get map_geolocation_open_settings_action => _resolve(
    'map_geolocation_open_settings_action',
    (loc) => loc.map_geolocation_open_settings_action,
  );

  @override
  String get map_geolocation_fix_unavailable_message => _resolve(
    'map_geolocation_fix_unavailable_message',
    (loc) => loc.map_geolocation_fix_unavailable_message,
  );

  // §4 Filter-active alert dialog
  @override
  String get map_filter_alert_title =>
      _resolve('map_filter_alert_title', (loc) => loc.map_filter_alert_title);

  @override
  String get map_filter_alert_body_prefix => _resolve(
    'map_filter_alert_body_prefix',
    (loc) => loc.map_filter_alert_body_prefix,
  );

  @override
  String get map_filter_alert_action_reset => _resolve(
    'map_filter_alert_action_reset',
    (loc) => loc.map_filter_alert_action_reset,
  );

  @override
  String get map_filter_alert_action_keep => _resolve(
    'map_filter_alert_action_keep',
    (loc) => loc.map_filter_alert_action_keep,
  );

  // §5 Refresh button + entry-point labels
  @override
  String get map_refresh_button_tooltip => _resolve(
    'map_refresh_button_tooltip',
    (loc) => loc.map_refresh_button_tooltip,
  );

  @override
  String get home_map_tile_title =>
      _resolve('home_map_tile_title', (loc) => loc.home_map_tile_title);

  @override
  String get home_map_tile_subtitle =>
      _resolve('home_map_tile_subtitle', (loc) => loc.home_map_tile_subtitle);

  @override
  String get listing_details_view_on_map_action => _resolve(
    'listing_details_view_on_map_action',
    (loc) => loc.listing_details_view_on_map_action,
  );

  @override
  String get search_results_show_on_map_action => _resolve(
    'search_results_show_on_map_action',
    (loc) => loc.search_results_show_on_map_action,
  );

  // ── Phase 16 — Contact, Inquiries & Lead Events ───────────────────────────

  // §T038 ContactBlock
  @override
  String get contact_call_disabled_tooltip => _resolve(
    'contact_call_disabled_tooltip',
    (loc) => loc.contact_call_disabled_tooltip,
  );

  @override
  String get contact_whatsapp_disabled_tooltip => _resolve(
    'contact_whatsapp_disabled_tooltip',
    (loc) => loc.contact_whatsapp_disabled_tooltip,
  );

  @override
  String get contact_dialer_unavailable => _resolve(
    'contact_dialer_unavailable',
    (loc) => loc.contact_dialer_unavailable,
  );

  @override
  String get contact_whatsapp_app_unavailable => _resolve(
    'contact_whatsapp_app_unavailable',
    (loc) => loc.contact_whatsapp_app_unavailable,
  );

  // §T039 Inquiry form sheet
  @override
  String get inquiry_form_title =>
      _resolve('inquiry_form_title', (loc) => loc.inquiry_form_title);

  @override
  String get inquiry_form_name_label =>
      _resolve('inquiry_form_name_label', (loc) => loc.inquiry_form_name_label);

  @override
  String get inquiry_form_name_placeholder => _resolve(
    'inquiry_form_name_placeholder',
    (loc) => loc.inquiry_form_name_placeholder,
  );

  @override
  String get inquiry_form_phone_label => _resolve(
    'inquiry_form_phone_label',
    (loc) => loc.inquiry_form_phone_label,
  );

  @override
  String get inquiry_form_message_label => _resolve(
    'inquiry_form_message_label',
    (loc) => loc.inquiry_form_message_label,
  );

  @override
  String get inquiry_form_message_placeholder => _resolve(
    'inquiry_form_message_placeholder',
    (loc) => loc.inquiry_form_message_placeholder,
  );

  @override
  String inquiry_form_message_counter(int remaining) => _resolve(
    'inquiry_form_message_counter',
    (loc) => loc.inquiry_form_message_counter(remaining),
  );

  @override
  String get inquiry_form_submit_button => _resolve(
    'inquiry_form_submit_button',
    (loc) => loc.inquiry_form_submit_button,
  );

  @override
  String get inquiry_form_success_snackbar => _resolve(
    'inquiry_form_success_snackbar',
    (loc) => loc.inquiry_form_success_snackbar,
  );

  @override
  String get inquiry_form_validation_name_required => _resolve(
    'inquiry_form_validation_name_required',
    (loc) => loc.inquiry_form_validation_name_required,
  );

  @override
  String get inquiry_form_validation_phone_invalid => _resolve(
    'inquiry_form_validation_phone_invalid',
    (loc) => loc.inquiry_form_validation_phone_invalid,
  );

  @override
  String get inquiry_form_validation_message_required => _resolve(
    'inquiry_form_validation_message_required',
    (loc) => loc.inquiry_form_validation_message_required,
  );

  @override
  String get inquiry_form_validation_message_too_long => _resolve(
    'inquiry_form_validation_message_too_long',
    (loc) => loc.inquiry_form_validation_message_too_long,
  );

  @override
  String get inquiry_form_rate_limited => _resolve(
    'inquiry_form_rate_limited',
    (loc) => loc.inquiry_form_rate_limited,
  );

  @override
  String get inquiry_form_submission_failed => _resolve(
    'inquiry_form_submission_failed',
    (loc) => loc.inquiry_form_submission_failed,
  );

  // §T040 Inbox chrome + status badges
  @override
  String get inquiry_inbox_app_bar_title => _resolve(
    'inquiry_inbox_app_bar_title',
    (loc) => loc.inquiry_inbox_app_bar_title,
  );

  @override
  String get inquiry_inbox_empty_state => _resolve(
    'inquiry_inbox_empty_state',
    (loc) => loc.inquiry_inbox_empty_state,
  );

  @override
  String get inquiry_inbox_filter_status_label => _resolve(
    'inquiry_inbox_filter_status_label',
    (loc) => loc.inquiry_inbox_filter_status_label,
  );

  @override
  String get inquiry_inbox_filter_listing_label => _resolve(
    'inquiry_inbox_filter_listing_label',
    (loc) => loc.inquiry_inbox_filter_listing_label,
  );

  @override
  String get inquiry_inbox_load_more =>
      _resolve('inquiry_inbox_load_more', (loc) => loc.inquiry_inbox_load_more);

  @override
  String get inquiry_inbox_anonymous_sender_label => _resolve(
    'inquiry_inbox_anonymous_sender_label',
    (loc) => loc.inquiry_inbox_anonymous_sender_label,
  );

  @override
  String get inquiry_status_new =>
      _resolve('inquiry_status_new', (loc) => loc.inquiry_status_new);

  @override
  String get inquiry_status_seen =>
      _resolve('inquiry_status_seen', (loc) => loc.inquiry_status_seen);

  @override
  String get inquiry_status_responded => _resolve(
    'inquiry_status_responded',
    (loc) => loc.inquiry_status_responded,
  );

  @override
  String get inquiry_status_closed =>
      _resolve('inquiry_status_closed', (loc) => loc.inquiry_status_closed);

  @override
  String get inquiry_status_spam =>
      _resolve('inquiry_status_spam', (loc) => loc.inquiry_status_spam);

  // §T041 Inquiry detail
  @override
  String get inquiry_detail_app_bar_title => _resolve(
    'inquiry_detail_app_bar_title',
    (loc) => loc.inquiry_detail_app_bar_title,
  );

  @override
  String get inquiry_detail_callback_phone_label => _resolve(
    'inquiry_detail_callback_phone_label',
    (loc) => loc.inquiry_detail_callback_phone_label,
  );

  @override
  String get inquiry_detail_phone_unavailable_placeholder => _resolve(
    'inquiry_detail_phone_unavailable_placeholder',
    (loc) => loc.inquiry_detail_phone_unavailable_placeholder,
  );

  @override
  String get inquiry_detail_tap_to_call_action => _resolve(
    'inquiry_detail_tap_to_call_action',
    (loc) => loc.inquiry_detail_tap_to_call_action,
  );

  @override
  String get inquiry_detail_listing_link_label => _resolve(
    'inquiry_detail_listing_link_label',
    (loc) => loc.inquiry_detail_listing_link_label,
  );

  @override
  String get inquiry_detail_mark_responded_action => _resolve(
    'inquiry_detail_mark_responded_action',
    (loc) => loc.inquiry_detail_mark_responded_action,
  );

  @override
  String get inquiry_detail_mark_closed_action => _resolve(
    'inquiry_detail_mark_closed_action',
    (loc) => loc.inquiry_detail_mark_closed_action,
  );

  @override
  String get inquiry_detail_reopen_to_seen_action => _resolve(
    'inquiry_detail_reopen_to_seen_action',
    (loc) => loc.inquiry_detail_reopen_to_seen_action,
  );

  @override
  String get inquiry_detail_reopen_to_responded_action => _resolve(
    'inquiry_detail_reopen_to_responded_action',
    (loc) => loc.inquiry_detail_reopen_to_responded_action,
  );

  // §T042 Admin oversight + home action
  @override
  String get admin_inquiries_tier_banner => _resolve(
    'admin_inquiries_tier_banner',
    (loc) => loc.admin_inquiries_tier_banner,
  );

  @override
  String get admin_inquiries_app_bar_title => _resolve(
    'admin_inquiries_app_bar_title',
    (loc) => loc.admin_inquiries_app_bar_title,
  );

  @override
  String get admin_inquiries_publisher_filter_label => _resolve(
    'admin_inquiries_publisher_filter_label',
    (loc) => loc.admin_inquiries_publisher_filter_label,
  );

  @override
  String get home_inquiries_action_tooltip => _resolve(
    'home_inquiries_action_tooltip',
    (loc) => loc.home_inquiries_action_tooltip,
  );

  // ── Phase 17 Favorites ────────────────────────────────────────────────────

  @override
  String get favorite_heart_label =>
      _resolve('favorite_heart_label', (loc) => loc.favorite_heart_label);

  @override
  String get favorite_unsave_label =>
      _resolve('favorite_unsave_label', (loc) => loc.favorite_unsave_label);

  @override
  String get favorite_sign_in_prompt =>
      _resolve('favorite_sign_in_prompt', (loc) => loc.favorite_sign_in_prompt);

  @override
  String get favorites_page_title =>
      _resolve('favorites_page_title', (loc) => loc.favorites_page_title);

  @override
  String get favorites_empty_state =>
      _resolve('favorites_empty_state', (loc) => loc.favorites_empty_state);

  @override
  String get favorite_unavailable_indicator => _resolve(
    'favorite_unavailable_indicator',
    (loc) => loc.favorite_unavailable_indicator,
  );

  @override
  String get profile_favorites_tile =>
      _resolve('profile_favorites_tile', (loc) => loc.profile_favorites_tile);

  @override
  String get favorite_toggle_failed =>
      _resolve('favorite_toggle_failed', (loc) => loc.favorite_toggle_failed);

  @override
  String get favorite_removed_snackbar => _resolve(
    'favorite_removed_snackbar',
    (loc) => loc.favorite_removed_snackbar,
  );

  @override
  String get action_undo => _resolve('action_undo', (loc) => loc.action_undo);

  // ── Phase 18 Reports & Moderation ────────────────────────────────────────

  @override
  String get report_reason_fake_listing => _resolve(
    'report_reason_fake_listing',
    (loc) => loc.report_reason_fake_listing,
  );

  @override
  String get report_reason_wrong_price => _resolve(
    'report_reason_wrong_price',
    (loc) => loc.report_reason_wrong_price,
  );

  @override
  String get report_reason_already_sold_or_rented => _resolve(
    'report_reason_already_sold_or_rented',
    (loc) => loc.report_reason_already_sold_or_rented,
  );

  @override
  String get report_reason_duplicate =>
      _resolve('report_reason_duplicate', (loc) => loc.report_reason_duplicate);

  @override
  String get report_reason_spam =>
      _resolve('report_reason_spam', (loc) => loc.report_reason_spam);

  @override
  String get report_reason_wrong_location => _resolve(
    'report_reason_wrong_location',
    (loc) => loc.report_reason_wrong_location,
  );

  @override
  String get report_reason_inappropriate_content => _resolve(
    'report_reason_inappropriate_content',
    (loc) => loc.report_reason_inappropriate_content,
  );

  @override
  String get report_reason_other =>
      _resolve('report_reason_other', (loc) => loc.report_reason_other);

  @override
  String get report_sheet_title =>
      _resolve('report_sheet_title', (loc) => loc.report_sheet_title);

  @override
  String get report_reason_field_label => _resolve(
    'report_reason_field_label',
    (loc) => loc.report_reason_field_label,
  );

  @override
  String get report_note_field_hint =>
      _resolve('report_note_field_hint', (loc) => loc.report_note_field_hint);

  @override
  String get report_submit_button =>
      _resolve('report_submit_button', (loc) => loc.report_submit_button);

  @override
  String get report_cancel_button =>
      _resolve('report_cancel_button', (loc) => loc.report_cancel_button);

  @override
  String get report_submitted_success => _resolve(
    'report_submitted_success',
    (loc) => loc.report_submitted_success,
  );

  @override
  String get report_already_reported =>
      _resolve('report_already_reported', (loc) => loc.report_already_reported);

  @override
  String get report_sign_in_prompt =>
      _resolve('report_sign_in_prompt', (loc) => loc.report_sign_in_prompt);

  @override
  String get report_submit_failed =>
      _resolve('report_submit_failed', (loc) => loc.report_submit_failed);

  @override
  String get reports_my_title =>
      _resolve('reports_my_title', (loc) => loc.reports_my_title);

  @override
  String get reports_my_empty_state =>
      _resolve('reports_my_empty_state', (loc) => loc.reports_my_empty_state);

  @override
  String get profile_reports_tile =>
      _resolve('profile_reports_tile', (loc) => loc.profile_reports_tile);

  @override
  String report_banner_status(String status) => _resolve(
    'report_banner_status',
    (loc) => loc.report_banner_status(status),
  );

  @override
  String get report_status_new =>
      _resolve('report_status_new', (loc) => loc.report_status_new);

  @override
  String get report_status_reviewing =>
      _resolve('report_status_reviewing', (loc) => loc.report_status_reviewing);

  @override
  String get report_status_resolved =>
      _resolve('report_status_resolved', (loc) => loc.report_status_resolved);

  @override
  String get report_status_dismissed =>
      _resolve('report_status_dismissed', (loc) => loc.report_status_dismissed);

  @override
  String get admin_tile_reports =>
      _resolve('admin_tile_reports', (loc) => loc.admin_tile_reports);

  @override
  String get reports_queue_title =>
      _resolve('reports_queue_title', (loc) => loc.reports_queue_title);

  @override
  String get reports_queue_empty =>
      _resolve('reports_queue_empty', (loc) => loc.reports_queue_empty);

  @override
  String get report_filter_status_label => _resolve(
    'report_filter_status_label',
    (loc) => loc.report_filter_status_label,
  );

  @override
  String get report_filter_reason_label => _resolve(
    'report_filter_reason_label',
    (loc) => loc.report_filter_reason_label,
  );

  @override
  String get report_start_review_button => _resolve(
    'report_start_review_button',
    (loc) => loc.report_start_review_button,
  );

  @override
  String report_being_reviewed_by(String name) => _resolve(
    'report_being_reviewed_by',
    (loc) => loc.report_being_reviewed_by(name),
  );

  @override
  String get resolve_action_dismiss =>
      _resolve('resolve_action_dismiss', (loc) => loc.resolve_action_dismiss);

  @override
  String get resolve_action_hide =>
      _resolve('resolve_action_hide', (loc) => loc.resolve_action_hide);

  @override
  String get resolve_action_mark_duplicate => _resolve(
    'resolve_action_mark_duplicate',
    (loc) => loc.resolve_action_mark_duplicate,
  );

  @override
  String get resolve_action_delete =>
      _resolve('resolve_action_delete', (loc) => loc.resolve_action_delete);

  @override
  String get resolve_confirm_title =>
      _resolve('resolve_confirm_title', (loc) => loc.resolve_confirm_title);

  @override
  String get resolve_confirm_body =>
      _resolve('resolve_confirm_body', (loc) => loc.resolve_confirm_body);

  @override
  String get report_resolved_success =>
      _resolve('report_resolved_success', (loc) => loc.report_resolved_success);

  @override
  String get report_resolve_button =>
      _resolve('report_resolve_button', (loc) => loc.report_resolve_button);

  @override
  String get report_resolve_dialog_title => _resolve(
    'report_resolve_dialog_title',
    (loc) => loc.report_resolve_dialog_title,
  );

  // ── Phase 19 Agencies ────────────────────────────────────────────────────

  @override
  String get profile_agency_tile =>
      _resolve('profile_agency_tile', (loc) => loc.profile_agency_tile);

  @override
  String get admin_tile_agencies =>
      _resolve('admin_tile_agencies', (loc) => loc.admin_tile_agencies);

  @override
  String get agency_create_title =>
      _resolve('agency_create_title', (loc) => loc.agency_create_title);

  @override
  String get agency_name_label =>
      _resolve('agency_name_label', (loc) => loc.agency_name_label);

  @override
  String get agency_description_label => _resolve(
    'agency_description_label',
    (loc) => loc.agency_description_label,
  );

  @override
  String get agency_phone_label =>
      _resolve('agency_phone_label', (loc) => loc.agency_phone_label);

  @override
  String get agency_whatsapp_label =>
      _resolve('agency_whatsapp_label', (loc) => loc.agency_whatsapp_label);

  @override
  String get agency_address_label =>
      _resolve('agency_address_label', (loc) => loc.agency_address_label);

  @override
  String get agency_logo_label =>
      _resolve('agency_logo_label', (loc) => loc.agency_logo_label);

  @override
  String get agency_cover_label =>
      _resolve('agency_cover_label', (loc) => loc.agency_cover_label);

  @override
  String get agency_create_button =>
      _resolve('agency_create_button', (loc) => loc.agency_create_button);

  @override
  String get agency_create_not_publisher => _resolve(
    'agency_create_not_publisher',
    (loc) => loc.agency_create_not_publisher,
  );

  @override
  String get agency_already_owns =>
      _resolve('agency_already_owns', (loc) => loc.agency_already_owns);

  @override
  String get agency_profile_title =>
      _resolve('agency_profile_title', (loc) => loc.agency_profile_title);

  @override
  String get agency_edit_button =>
      _resolve('agency_edit_button', (loc) => loc.agency_edit_button);

  @override
  String get agency_status_pending =>
      _resolve('agency_status_pending', (loc) => loc.agency_status_pending);

  @override
  String get agency_status_approved =>
      _resolve('agency_status_approved', (loc) => loc.agency_status_approved);

  @override
  String get agency_status_rejected =>
      _resolve('agency_status_rejected', (loc) => loc.agency_status_rejected);

  @override
  String get agency_status_suspended =>
      _resolve('agency_status_suspended', (loc) => loc.agency_status_suspended);

  @override
  String get agency_members_title =>
      _resolve('agency_members_title', (loc) => loc.agency_members_title);

  @override
  String get agency_invite_button =>
      _resolve('agency_invite_button', (loc) => loc.agency_invite_button);

  @override
  String get agency_invite_phone_label => _resolve(
    'agency_invite_phone_label',
    (loc) => loc.agency_invite_phone_label,
  );

  @override
  String get agency_invite_role_label => _resolve(
    'agency_invite_role_label',
    (loc) => loc.agency_invite_role_label,
  );

  @override
  String get agency_role_admin =>
      _resolve('agency_role_admin', (loc) => loc.agency_role_admin);

  @override
  String get agency_role_agent =>
      _resolve('agency_role_agent', (loc) => loc.agency_role_agent);

  @override
  String get agency_member_remove =>
      _resolve('agency_member_remove', (loc) => loc.agency_member_remove);

  @override
  String get agency_invite_user_not_found => _resolve(
    'agency_invite_user_not_found',
    (loc) => loc.agency_invite_user_not_found,
  );

  @override
  String get agency_invite_already_member => _resolve(
    'agency_invite_already_member',
    (loc) => loc.agency_invite_already_member,
  );

  @override
  String get agency_invitations_title => _resolve(
    'agency_invitations_title',
    (loc) => loc.agency_invitations_title,
  );

  @override
  String get agency_invitation_accept => _resolve(
    'agency_invitation_accept',
    (loc) => loc.agency_invitation_accept,
  );

  @override
  String get agency_invitation_decline => _resolve(
    'agency_invitation_decline',
    (loc) => loc.agency_invitation_decline,
  );

  @override
  String agency_invitation_pending_from(String agencyName) => _resolve(
    'agency_invitation_pending_from',
    (loc) => loc.agency_invitation_pending_from(agencyName),
  );

  @override
  String get agency_invitation_unnamed_agency => _resolve(
    'agency_invitation_unnamed_agency',
    (loc) => loc.agency_invitation_unnamed_agency,
  );

  @override
  String get agency_invitations_page_intro => _resolve(
    'agency_invitations_page_intro',
    (loc) => loc.agency_invitations_page_intro,
  );

  @override
  String get agency_verify_title =>
      _resolve('agency_verify_title', (loc) => loc.agency_verify_title);

  @override
  String get agency_verify_id_number_label => _resolve(
    'agency_verify_id_number_label',
    (loc) => loc.agency_verify_id_number_label,
  );

  @override
  String get agency_verify_registration_label => _resolve(
    'agency_verify_registration_label',
    (loc) => loc.agency_verify_registration_label,
  );

  @override
  String get agency_verify_documents_label => _resolve(
    'agency_verify_documents_label',
    (loc) => loc.agency_verify_documents_label,
  );

  @override
  String get agency_verify_submit_button => _resolve(
    'agency_verify_submit_button',
    (loc) => loc.agency_verify_submit_button,
  );

  @override
  String get agency_verify_submitted =>
      _resolve('agency_verify_submitted', (loc) => loc.agency_verify_submitted);

  @override
  String agency_verify_rejected_reason(String reason) => _resolve(
    'agency_verify_rejected_reason',
    (loc) => loc.agency_verify_rejected_reason(reason),
  );

  @override
  String get listing_publish_under_agency_label => _resolve(
    'listing_publish_under_agency_label',
    (loc) => loc.listing_publish_under_agency_label,
  );

  @override
  String get listing_publish_personal_option => _resolve(
    'listing_publish_personal_option',
    (loc) => loc.listing_publish_personal_option,
  );

  @override
  String get agency_verified_badge =>
      _resolve('agency_verified_badge', (loc) => loc.agency_verified_badge);

  @override
  String get agency_analytics_title =>
      _resolve('agency_analytics_title', (loc) => loc.agency_analytics_title);

  @override
  String agency_analytics_members(int count) => _resolve(
    'agency_analytics_members',
    (loc) => loc.agency_analytics_members(count),
  );

  @override
  String agency_analytics_listings(int count) => _resolve(
    'agency_analytics_listings',
    (loc) => loc.agency_analytics_listings(count),
  );

  @override
  String get agencies_queue_title =>
      _resolve('agencies_queue_title', (loc) => loc.agencies_queue_title);

  @override
  String get agency_filter_status_label => _resolve(
    'agency_filter_status_label',
    (loc) => loc.agency_filter_status_label,
  );

  @override
  String get agency_action_approve =>
      _resolve('agency_action_approve', (loc) => loc.agency_action_approve);

  @override
  String get agency_action_reject =>
      _resolve('agency_action_reject', (loc) => loc.agency_action_reject);

  @override
  String get agency_action_suspend =>
      _resolve('agency_action_suspend', (loc) => loc.agency_action_suspend);

  @override
  String get agency_action_reinstate =>
      _resolve('agency_action_reinstate', (loc) => loc.agency_action_reinstate);

  @override
  String get agency_reject_reason_label => _resolve(
    'agency_reject_reason_label',
    (loc) => loc.agency_reject_reason_label,
  );

  @override
  String get agency_suspend_confirm_title => _resolve(
    'agency_suspend_confirm_title',
    (loc) => loc.agency_suspend_confirm_title,
  );

  @override
  String get agency_suspend_confirm_body => _resolve(
    'agency_suspend_confirm_body',
    (loc) => loc.agency_suspend_confirm_body,
  );

  @override
  String get agency_decision_success =>
      _resolve('agency_decision_success', (loc) => loc.agency_decision_success);

  @override
  String get agencies_queue_empty =>
      _resolve('agencies_queue_empty', (loc) => loc.agencies_queue_empty);
  @override
  String get agency_create_description_hint => _resolve(
    'agency_create_description_hint',
    (loc) => loc.agency_create_description_hint,
  );

  @override
  String get agency_save_button =>
      _resolve('agency_save_button', (loc) => loc.agency_save_button);

  @override
  String get agency_manage_members =>
      _resolve('agency_manage_members', (loc) => loc.agency_manage_members);

  @override
  String get agency_manage_listings =>
      _resolve('agency_manage_listings', (loc) => loc.agency_manage_listings);

  @override
  String get agency_manage_analytics =>
      _resolve('agency_manage_analytics', (loc) => loc.agency_manage_analytics);

  @override
  String get agency_manage_verify =>
      _resolve('agency_manage_verify', (loc) => loc.agency_manage_verify);

  @override
  String get agency_listings_title =>
      _resolve('agency_listings_title', (loc) => loc.agency_listings_title);

  @override
  String get agency_listings_empty =>
      _resolve('agency_listings_empty', (loc) => loc.agency_listings_empty);

  @override
  String get agency_members_empty =>
      _resolve('agency_members_empty', (loc) => loc.agency_members_empty);

  @override
  String get agency_invitations_empty => _resolve(
    'agency_invitations_empty',
    (loc) => loc.agency_invitations_empty,
  );

  @override
  String get agency_generic_error =>
      _resolve('agency_generic_error', (loc) => loc.agency_generic_error);

  @override
  String get agency_no_agency_message => _resolve(
    'agency_no_agency_message',
    (loc) => loc.agency_no_agency_message,
  );

  @override
  String get agency_member_remove_confirm => _resolve(
    'agency_member_remove_confirm',
    (loc) => loc.agency_member_remove_confirm,
  );

  @override
  String get agency_cancel_button =>
      _resolve('agency_cancel_button', (loc) => loc.agency_cancel_button);

  @override
  String get agency_action_failed =>
      _resolve('agency_action_failed', (loc) => loc.agency_action_failed);

  @override
  String get auditLogsTitle =>
      _resolve('auditLogsTitle', (loc) => loc.auditLogsTitle);

  @override
  String get auditLogsEmpty =>
      _resolve('auditLogsEmpty', (loc) => loc.auditLogsEmpty);

  @override
  String get auditLogsActorLabel =>
      _resolve('auditLogsActorLabel', (loc) => loc.auditLogsActorLabel);

  @override
  String get auditLogsActorSystem =>
      _resolve('auditLogsActorSystem', (loc) => loc.auditLogsActorSystem);

  @override
  String get auditLogsActionLabel =>
      _resolve('auditLogsActionLabel', (loc) => loc.auditLogsActionLabel);

  @override
  String get auditLogsTargetLabel =>
      _resolve('auditLogsTargetLabel', (loc) => loc.auditLogsTargetLabel);

  @override
  String get auditLogsTimestampLabel =>
      _resolve('auditLogsTimestampLabel', (loc) => loc.auditLogsTimestampLabel);

  @override
  String get auditLogsBeforeLabel =>
      _resolve('auditLogsBeforeLabel', (loc) => loc.auditLogsBeforeLabel);

  @override
  String get auditLogsAfterLabel =>
      _resolve('auditLogsAfterLabel', (loc) => loc.auditLogsAfterLabel);

  @override
  String get auditLogsNoData =>
      _resolve('auditLogsNoData', (loc) => loc.auditLogsNoData);

  @override
  String get auditLogsAccessDenied =>
      _resolve('auditLogsAccessDenied', (loc) => loc.auditLogsAccessDenied);

  // ── Phase 20 — Dashboard grid + counters (P3) ────────────────────────────

  @override
  String get dashboardTileAuditLogs =>
      _resolve('dashboardTileAuditLogs', (loc) => loc.dashboardTileAuditLogs);

  @override
  String get dashboardTileAds =>
      _resolve('dashboardTileAds', (loc) => loc.dashboardTileAds);

  @override
  String get dashboardTileSettings =>
      _resolve('dashboardTileSettings', (loc) => loc.dashboardTileSettings);

  @override
  String get dashboardTileInquiries =>
      _resolve('dashboardTileInquiries', (loc) => loc.dashboardTileInquiries);

  @override
  String get dashboardComingSoon =>
      _resolve('dashboardComingSoon', (loc) => loc.dashboardComingSoon);

  @override
  String get dashboardCounterPendingUsers => _resolve(
    'dashboardCounterPendingUsers',
    (loc) => loc.dashboardCounterPendingUsers,
  );

  @override
  String get dashboardCounterPendingListings => _resolve(
    'dashboardCounterPendingListings',
    (loc) => loc.dashboardCounterPendingListings,
  );

  @override
  String get dashboardCounterOpenReports => _resolve(
    'dashboardCounterOpenReports',
    (loc) => loc.dashboardCounterOpenReports,
  );

  @override
  String get dashboardCounterNewInquiries24h => _resolve(
    'dashboardCounterNewInquiries24h',
    (loc) => loc.dashboardCounterNewInquiries24h,
  );

  @override
  String get dashboardCounterActiveListings => _resolve(
    'dashboardCounterActiveListings',
    (loc) => loc.dashboardCounterActiveListings,
  );

  @override
  String get dashboardCountersLoading => _resolve(
    'dashboardCountersLoading',
    (loc) => loc.dashboardCountersLoading,
  );

  @override
  String get dashboardCountersError =>
      _resolve('dashboardCountersError', (loc) => loc.dashboardCountersError);

  @override
  String get dashboardCountersRetry =>
      _resolve('dashboardCountersRetry', (loc) => loc.dashboardCountersRetry);

  // ── Phase 21 PA — Ads admin ───────────────────────────────────────────────

  @override
  String get adsAdminListTitle =>
      _resolve('adsAdminListTitle', (loc) => loc.adsAdminListTitle);

  @override
  String get adsAdminCreateTitle =>
      _resolve('adsAdminCreateTitle', (loc) => loc.adsAdminCreateTitle);

  @override
  String get adsAdminEditTitle =>
      _resolve('adsAdminEditTitle', (loc) => loc.adsAdminEditTitle);

  @override
  String get adsAdminEmptyList =>
      _resolve('adsAdminEmptyList', (loc) => loc.adsAdminEmptyList);

  @override
  String get adsAdminArchivedFilterTooltip => _resolve(
    'adsAdminArchivedFilterTooltip',
    (loc) => loc.adsAdminArchivedFilterTooltip,
  );

  @override
  String get adsAdminCreateTooltip =>
      _resolve('adsAdminCreateTooltip', (loc) => loc.adsAdminCreateTooltip);

  @override
  String get adsAdminActivateTooltip =>
      _resolve('adsAdminActivateTooltip', (loc) => loc.adsAdminActivateTooltip);

  @override
  String get adsAdminDeactivateTooltip => _resolve(
    'adsAdminDeactivateTooltip',
    (loc) => loc.adsAdminDeactivateTooltip,
  );

  @override
  String get adsAdminArchiveTooltip =>
      _resolve('adsAdminArchiveTooltip', (loc) => loc.adsAdminArchiveTooltip);

  @override
  String get adsAdminArchiveConfirmTitle => _resolve(
    'adsAdminArchiveConfirmTitle',
    (loc) => loc.adsAdminArchiveConfirmTitle,
  );

  @override
  String adsAdminArchiveConfirmBody(String title) => _resolve(
    'adsAdminArchiveConfirmBody',
    (loc) => loc.adsAdminArchiveConfirmBody(title),
  );

  @override
  String get adsAdminArchiveAction =>
      _resolve('adsAdminArchiveAction', (loc) => loc.adsAdminArchiveAction);

  @override
  String get adsAdminTitleFieldLabel =>
      _resolve('adsAdminTitleFieldLabel', (loc) => loc.adsAdminTitleFieldLabel);

  @override
  String get adsAdminTitleRequired =>
      _resolve('adsAdminTitleRequired', (loc) => loc.adsAdminTitleRequired);

  @override
  String get adsAdminImageLabel =>
      _resolve('adsAdminImageLabel', (loc) => loc.adsAdminImageLabel);

  @override
  String get adsAdminImagePickLabel =>
      _resolve('adsAdminImagePickLabel', (loc) => loc.adsAdminImagePickLabel);

  @override
  String get adsAdminImageReplaceLabel => _resolve(
    'adsAdminImageReplaceLabel',
    (loc) => loc.adsAdminImageReplaceLabel,
  );

  @override
  String get adsAdminImageRequired =>
      _resolve('adsAdminImageRequired', (loc) => loc.adsAdminImageRequired);

  @override
  String get adsAdminCaptionLabel =>
      _resolve('adsAdminCaptionLabel', (loc) => loc.adsAdminCaptionLabel);

  @override
  String get adsAdminCaptionBothOrNeitherHint => _resolve(
    'adsAdminCaptionBothOrNeitherHint',
    (loc) => loc.adsAdminCaptionBothOrNeitherHint,
  );

  @override
  String get adsAdminCaptionArLabel =>
      _resolve('adsAdminCaptionArLabel', (loc) => loc.adsAdminCaptionArLabel);

  @override
  String get adsAdminCaptionEnLabel =>
      _resolve('adsAdminCaptionEnLabel', (loc) => loc.adsAdminCaptionEnLabel);

  @override
  String get adsAdminCaptionBothOrNeither => _resolve(
    'adsAdminCaptionBothOrNeither',
    (loc) => loc.adsAdminCaptionBothOrNeither,
  );

  @override
  String get adsAdminLinkLabel =>
      _resolve('adsAdminLinkLabel', (loc) => loc.adsAdminLinkLabel);

  @override
  String get adsAdminPlacementsLabel =>
      _resolve('adsAdminPlacementsLabel', (loc) => loc.adsAdminPlacementsLabel);

  @override
  String get adsAdminPriorityLabel =>
      _resolve('adsAdminPriorityLabel', (loc) => loc.adsAdminPriorityLabel);

  @override
  String get adsAdminScheduleLabel =>
      _resolve('adsAdminScheduleLabel', (loc) => loc.adsAdminScheduleLabel);

  @override
  String get adsAdminActiveToggleLabel => _resolve(
    'adsAdminActiveToggleLabel',
    (loc) => loc.adsAdminActiveToggleLabel,
  );

  @override
  String get adStatusActive =>
      _resolve('adStatusActive', (loc) => loc.adStatusActive);

  @override
  String get adStatusScheduled =>
      _resolve('adStatusScheduled', (loc) => loc.adStatusScheduled);

  @override
  String get adStatusExpired =>
      _resolve('adStatusExpired', (loc) => loc.adStatusExpired);

  @override
  String get adStatusInactive =>
      _resolve('adStatusInactive', (loc) => loc.adStatusInactive);

  @override
  String get adStatusArchived =>
      _resolve('adStatusArchived', (loc) => loc.adStatusArchived);

  @override
  String get adLinkKindLabel =>
      _resolve('adLinkKindLabel', (loc) => loc.adLinkKindLabel);

  @override
  String get adLinkKindExternal =>
      _resolve('adLinkKindExternal', (loc) => loc.adLinkKindExternal);

  @override
  String get adLinkKindListing =>
      _resolve('adLinkKindListing', (loc) => loc.adLinkKindListing);

  @override
  String get adLinkKindAgency =>
      _resolve('adLinkKindAgency', (loc) => loc.adLinkKindAgency);

  @override
  String get adLinkKindCategory =>
      _resolve('adLinkKindCategory', (loc) => loc.adLinkKindCategory);

  @override
  String get adLinkKindSearch =>
      _resolve('adLinkKindSearch', (loc) => loc.adLinkKindSearch);

  @override
  String get adLinkValueHintUrl =>
      _resolve('adLinkValueHintUrl', (loc) => loc.adLinkValueHintUrl);

  @override
  String get adLinkValueHintUuid =>
      _resolve('adLinkValueHintUuid', (loc) => loc.adLinkValueHintUuid);

  @override
  String get adLinkValueHintCategoryKey => _resolve(
    'adLinkValueHintCategoryKey',
    (loc) => loc.adLinkValueHintCategoryKey,
  );

  @override
  String get adLinkValueHintSearch =>
      _resolve('adLinkValueHintSearch', (loc) => loc.adLinkValueHintSearch);

  @override
  String get adLinkValueRequired =>
      _resolve('adLinkValueRequired', (loc) => loc.adLinkValueRequired);

  @override
  String get adLinkValueInvalidUrl =>
      _resolve('adLinkValueInvalidUrl', (loc) => loc.adLinkValueInvalidUrl);

  @override
  String get adLinkValueInvalidUuid =>
      _resolve('adLinkValueInvalidUuid', (loc) => loc.adLinkValueInvalidUuid);

  @override
  String get adLinkValueInvalidCategoryKey => _resolve(
    'adLinkValueInvalidCategoryKey',
    (loc) => loc.adLinkValueInvalidCategoryKey,
  );

  @override
  String get adPlacementHomeTopBanner => _resolve(
    'adPlacementHomeTopBanner',
    (loc) => loc.adPlacementHomeTopBanner,
  );

  @override
  String get adPlacementHomeMiddleBanner => _resolve(
    'adPlacementHomeMiddleBanner',
    (loc) => loc.adPlacementHomeMiddleBanner,
  );

  @override
  String get adPlacementSearchResultsBanner => _resolve(
    'adPlacementSearchResultsBanner',
    (loc) => loc.adPlacementSearchResultsBanner,
  );

  @override
  String get adPlacementListingDetailsBanner => _resolve(
    'adPlacementListingDetailsBanner',
    (loc) => loc.adPlacementListingDetailsBanner,
  );

  @override
  String get adPlacementCategoryBanner => _resolve(
    'adPlacementCategoryBanner',
    (loc) => loc.adPlacementCategoryBanner,
  );

  @override
  String get adPlacementCategoryBannerNotYetLive => _resolve(
    'adPlacementCategoryBannerNotYetLive',
    (loc) => loc.adPlacementCategoryBannerNotYetLive,
  );

  @override
  String get scheduleStartLabel =>
      _resolve('scheduleStartLabel', (loc) => loc.scheduleStartLabel);

  @override
  String get scheduleEndLabel =>
      _resolve('scheduleEndLabel', (loc) => loc.scheduleEndLabel);

  @override
  String get scheduleNotSet =>
      _resolve('scheduleNotSet', (loc) => loc.scheduleNotSet);

  @override
  String get scheduleClearTooltip =>
      _resolve('scheduleClearTooltip', (loc) => loc.scheduleClearTooltip);

  @override
  String get scheduleStartMustBeforeEnd => _resolve(
    'scheduleStartMustBeforeEnd',
    (loc) => loc.scheduleStartMustBeforeEnd,
  );

  @override
  String get saveLabel => _resolve('saveLabel', (loc) => loc.saveLabel);

  @override
  String get cancelLabel => _resolve('cancelLabel', (loc) => loc.cancelLabel);

  // Phase 21 — AdSlot l10n keys
  @override
  String get adSlotUnavailable =>
      _resolve('adSlotUnavailable', (loc) => loc.adSlotUnavailable);

  @override
  String get adSlotTargetNotFound =>
      _resolve('adSlotTargetNotFound', (loc) => loc.adSlotTargetNotFound);

  // ── Phase 22 — Notification center + bell + push listener ────────────────

  @override
  String get notification_center_title => _resolve(
    'notification_center_title',
    (loc) => loc.notification_center_title,
  );

  @override
  String get notification_bell_tooltip => _resolve(
    'notification_bell_tooltip',
    (loc) => loc.notification_bell_tooltip,
  );

  @override
  String get notification_mark_all_read => _resolve(
    'notification_mark_all_read',
    (loc) => loc.notification_mark_all_read,
  );

  @override
  String get notification_empty_state => _resolve(
    'notification_empty_state',
    (loc) => loc.notification_empty_state,
  );

  @override
  String get notification_load_error =>
      _resolve('notification_load_error', (loc) => loc.notification_load_error);

  @override
  String get notification_retry =>
      _resolve('notification_retry', (loc) => loc.notification_retry);

  @override
  String get notification_time_just_now => _resolve(
    'notification_time_just_now',
    (loc) => loc.notification_time_just_now,
  );

  @override
  String notification_time_minutes(int n) => _resolve(
    'notification_time_minutes',
    (loc) => loc.notification_time_minutes(n),
  );

  @override
  String notification_time_hours(int n) => _resolve(
    'notification_time_hours',
    (loc) => loc.notification_time_hours(n),
  );

  @override
  String notification_time_days(int n) => _resolve(
    'notification_time_days',
    (loc) => loc.notification_time_days(n),
  );

  @override
  String get notification_content_unavailable => _resolve(
    'notification_content_unavailable',
    (loc) => loc.notification_content_unavailable,
  );

  @override
  String get notification_foreground_received => _resolve(
    'notification_foreground_received',
    (loc) => loc.notification_foreground_received,
  );

  @override
  String get notification_foreground_view => _resolve(
    'notification_foreground_view',
    (loc) => loc.notification_foreground_view,
  );

  @override
  String get notification_type_account_approved => _resolve(
    'notification_type_account_approved',
    (loc) => loc.notification_type_account_approved,
  );

  @override
  String get notification_type_account_rejected => _resolve(
    'notification_type_account_rejected',
    (loc) => loc.notification_type_account_rejected,
  );

  @override
  String get notification_type_listing_approved => _resolve(
    'notification_type_listing_approved',
    (loc) => loc.notification_type_listing_approved,
  );

  @override
  String get notification_type_listing_rejected => _resolve(
    'notification_type_listing_rejected',
    (loc) => loc.notification_type_listing_rejected,
  );

  @override
  String get notification_type_inquiry_received => _resolve(
    'notification_type_inquiry_received',
    (loc) => loc.notification_type_inquiry_received,
  );

  @override
  String get notification_type_agency_invitation => _resolve(
    'notification_type_agency_invitation',
    (loc) => loc.notification_type_agency_invitation,
  );

  // ── Phase 23 FA — settings editor ─────────────────────────────────────────

  @override
  String get settingsEditorTitle =>
      _resolve('settingsEditorTitle', (loc) => loc.settingsEditorTitle);

  @override
  String get settingsEditorSaveButton => _resolve(
    'settingsEditorSaveButton',
    (loc) => loc.settingsEditorSaveButton,
  );

  @override
  String get settingsEditorSavedSnackbar => _resolve(
    'settingsEditorSavedSnackbar',
    (loc) => loc.settingsEditorSavedSnackbar,
  );

  @override
  String get settingsEditorLoadError =>
      _resolve('settingsEditorLoadError', (loc) => loc.settingsEditorLoadError);

  @override
  String get settingsEditorSaveError =>
      _resolve('settingsEditorSaveError', (loc) => loc.settingsEditorSaveError);

  @override
  String get settingsEditorRetry =>
      _resolve('settingsEditorRetry', (loc) => loc.settingsEditorRetry);

  @override
  String get settingsValidationLanguage => _resolve(
    'settingsValidationLanguage',
    (loc) => loc.settingsValidationLanguage,
  );

  @override
  String get settingsValidationCurrencyRequired => _resolve(
    'settingsValidationCurrencyRequired',
    (loc) => loc.settingsValidationCurrencyRequired,
  );

  @override
  String get settingsValidationPublisherVisibilityRequired => _resolve(
    'settingsValidationPublisherVisibilityRequired',
    (loc) => loc.settingsValidationPublisherVisibilityRequired,
  );

  @override
  String get settingsValidationLocationVisibilityRequired => _resolve(
    'settingsValidationLocationVisibilityRequired',
    (loc) => loc.settingsValidationLocationVisibilityRequired,
  );

  @override
  String get settingsValidationMaintenanceMap => _resolve(
    'settingsValidationMaintenanceMap',
    (loc) => loc.settingsValidationMaintenanceMap,
  );

  @override
  String get settingsValidationMaintenanceOnBool => _resolve(
    'settingsValidationMaintenanceOnBool',
    (loc) => loc.settingsValidationMaintenanceOnBool,
  );

  @override
  String get settingsValidationSupportMap => _resolve(
    'settingsValidationSupportMap',
    (loc) => loc.settingsValidationSupportMap,
  );

  @override
  String get settingsValidationUrlText => _resolve(
    'settingsValidationUrlText',
    (loc) => loc.settingsValidationUrlText,
  );

  @override
  String get settingsEditorSectionGeneral => _resolve(
    'settingsEditorSectionGeneral',
    (loc) => loc.settingsEditorSectionGeneral,
  );

  @override
  String get settingsEditorSectionListingDefaults => _resolve(
    'settingsEditorSectionListingDefaults',
    (loc) => loc.settingsEditorSectionListingDefaults,
  );

  @override
  String get settingsEditorSectionMaintenance => _resolve(
    'settingsEditorSectionMaintenance',
    (loc) => loc.settingsEditorSectionMaintenance,
  );

  @override
  String get settingsEditorSectionSupport => _resolve(
    'settingsEditorSectionSupport',
    (loc) => loc.settingsEditorSectionSupport,
  );

  @override
  String get settingsEditorSectionLegal => _resolve(
    'settingsEditorSectionLegal',
    (loc) => loc.settingsEditorSectionLegal,
  );

  @override
  String get settingsEditorDefaultLanguageLabel => _resolve(
    'settingsEditorDefaultLanguageLabel',
    (loc) => loc.settingsEditorDefaultLanguageLabel,
  );

  @override
  String get settingsEditorDefaultCurrencyLabel => _resolve(
    'settingsEditorDefaultCurrencyLabel',
    (loc) => loc.settingsEditorDefaultCurrencyLabel,
  );

  @override
  String get settingsEditorDefaultPublisherNameVisibilityLabel => _resolve(
    'settingsEditorDefaultPublisherNameVisibilityLabel',
    (loc) => loc.settingsEditorDefaultPublisherNameVisibilityLabel,
  );

  @override
  String get settingsEditorDefaultLocationVisibilityLabel => _resolve(
    'settingsEditorDefaultLocationVisibilityLabel',
    (loc) => loc.settingsEditorDefaultLocationVisibilityLabel,
  );

  @override
  String get settingsEditorMaintenanceToggle => _resolve(
    'settingsEditorMaintenanceToggle',
    (loc) => loc.settingsEditorMaintenanceToggle,
  );

  @override
  String get settingsEditorMaintenanceMessageArLabel => _resolve(
    'settingsEditorMaintenanceMessageArLabel',
    (loc) => loc.settingsEditorMaintenanceMessageArLabel,
  );

  @override
  String get settingsEditorMaintenanceMessageEnLabel => _resolve(
    'settingsEditorMaintenanceMessageEnLabel',
    (loc) => loc.settingsEditorMaintenanceMessageEnLabel,
  );

  @override
  String get settingsEditorSupportPhoneLabel => _resolve(
    'settingsEditorSupportPhoneLabel',
    (loc) => loc.settingsEditorSupportPhoneLabel,
  );

  @override
  String get settingsEditorSupportWhatsappLabel => _resolve(
    'settingsEditorSupportWhatsappLabel',
    (loc) => loc.settingsEditorSupportWhatsappLabel,
  );

  @override
  String get settingsEditorSupportEmailLabel => _resolve(
    'settingsEditorSupportEmailLabel',
    (loc) => loc.settingsEditorSupportEmailLabel,
  );

  @override
  String get settingsEditorTermsUrlLabel => _resolve(
    'settingsEditorTermsUrlLabel',
    (loc) => loc.settingsEditorTermsUrlLabel,
  );

  @override
  String get settingsEditorPrivacyUrlLabel => _resolve(
    'settingsEditorPrivacyUrlLabel',
    (loc) => loc.settingsEditorPrivacyUrlLabel,
  );

  @override
  String get settingsEditorUrlValidationError => _resolve(
    'settingsEditorUrlValidationError',
    (loc) => loc.settingsEditorUrlValidationError,
  );

  @override
  String get settingsEditorSupportAtLeastOneError => _resolve(
    'settingsEditorSupportAtLeastOneError',
    (loc) => loc.settingsEditorSupportAtLeastOneError,
  );

  @override
  String get settingsEditorLanguageAr => _resolve(
    'settingsEditorLanguageAr',
    (loc) => loc.settingsEditorLanguageAr,
  );

  @override
  String get settingsEditorLanguageEn => _resolve(
    'settingsEditorLanguageEn',
    (loc) => loc.settingsEditorLanguageEn,
  );

  @override
  String get settingsEditorVisibilityPublic => _resolve(
    'settingsEditorVisibilityPublic',
    (loc) => loc.settingsEditorVisibilityPublic,
  );

  @override
  String get settingsEditorVisibilityAdminOnly => _resolve(
    'settingsEditorVisibilityAdminOnly',
    (loc) => loc.settingsEditorVisibilityAdminOnly,
  );

  @override
  String get settingsEditorLocationVisibilityHidden => _resolve(
    'settingsEditorLocationVisibilityHidden',
    (loc) => loc.settingsEditorLocationVisibilityHidden,
  );

  @override
  String get settingsEditorLocationVisibilityApproximate => _resolve(
    'settingsEditorLocationVisibilityApproximate',
    (loc) => loc.settingsEditorLocationVisibilityApproximate,
  );

  @override
  String get settingsEditorLocationVisibilityExact => _resolve(
    'settingsEditorLocationVisibilityExact',
    (loc) => loc.settingsEditorLocationVisibilityExact,
  );
  // ─── Phase 23 FC — maintenance gate + about/support ───
  @override
  String get maintenance_title =>
      _resolve('maintenance_title', (loc) => loc.maintenance_title);

  @override
  String get maintenance_default_message => _resolve(
    'maintenance_default_message',
    (loc) => loc.maintenance_default_message,
  );

  @override
  String get maintenance_retry =>
      _resolve('maintenance_retry', (loc) => loc.maintenance_retry);

  @override
  String get maintenance_support_heading => _resolve(
    'maintenance_support_heading',
    (loc) => loc.maintenance_support_heading,
  );

  @override
  String get support_channel_phone =>
      _resolve('support_channel_phone', (loc) => loc.support_channel_phone);

  @override
  String get support_channel_whatsapp => _resolve(
    'support_channel_whatsapp',
    (loc) => loc.support_channel_whatsapp,
  );

  @override
  String get support_channel_email =>
      _resolve('support_channel_email', (loc) => loc.support_channel_email);

  @override
  String get about_title => _resolve('about_title', (loc) => loc.about_title);

  @override
  String get about_support_heading =>
      _resolve('about_support_heading', (loc) => loc.about_support_heading);

  @override
  String get about_legal_heading =>
      _resolve('about_legal_heading', (loc) => loc.about_legal_heading);

  @override
  String get about_terms => _resolve('about_terms', (loc) => loc.about_terms);

  @override
  String get about_privacy =>
      _resolve('about_privacy', (loc) => loc.about_privacy);

  @override
  String get about_no_info =>
      _resolve('about_no_info', (loc) => loc.about_no_info);

  // ── Phase 24 UP — in-app update prompt ───────────────────────────────────

  @override
  String get updatePromptTitle =>
      _resolve('updatePromptTitle', (loc) => loc.updatePromptTitle);

  @override
  String get updatePromptBody =>
      _resolve('updatePromptBody', (loc) => loc.updatePromptBody);

  @override
  String get updatePromptUpdate =>
      _resolve('updatePromptUpdate', (loc) => loc.updatePromptUpdate);

  @override
  String get updatePromptLater =>
      _resolve('updatePromptLater', (loc) => loc.updatePromptLater);

  @override
  String get updatePromptReleaseNotesLabel => _resolve(
    'updatePromptReleaseNotesLabel',
    (loc) => loc.updatePromptReleaseNotesLabel,
  );

  @override
  String get nav_search => _resolve('nav_search', (loc) => loc.nav_search);

  @override
  String get nav_publish => _resolve('nav_publish', (loc) => loc.nav_publish);

  @override
  String get nav_search_map =>
      _resolve('nav_search_map', (loc) => loc.nav_search_map);

  @override
  String get nav_messages =>
      _resolve('nav_messages', (loc) => loc.nav_messages);

  @override
  String get detail_verified_badge =>
      _resolve('detail_verified_badge', (loc) => loc.detail_verified_badge);

  @override
  String get view_mode_title =>
      _resolve('view_mode_title', (loc) => loc.view_mode_title);

  @override
  String get view_mode_comfortable =>
      _resolve('view_mode_comfortable', (loc) => loc.view_mode_comfortable);

  @override
  String get view_mode_comfortable_desc => _resolve(
    'view_mode_comfortable_desc',
    (loc) => loc.view_mode_comfortable_desc,
  );

  @override
  String get view_mode_balanced =>
      _resolve('view_mode_balanced', (loc) => loc.view_mode_balanced);

  @override
  String get view_mode_balanced_desc =>
      _resolve('view_mode_balanced_desc', (loc) => loc.view_mode_balanced_desc);

  @override
  String get view_mode_compact =>
      _resolve('view_mode_compact', (loc) => loc.view_mode_compact);

  @override
  String get view_mode_compact_desc =>
      _resolve('view_mode_compact_desc', (loc) => loc.view_mode_compact_desc);

  @override
  String get auth_continue_as_guest =>
      _resolve('auth_continue_as_guest', (loc) => loc.auth_continue_as_guest);

  @override
  String get home_trust_headline =>
      _resolve('home_trust_headline', (loc) => loc.home_trust_headline);

  @override
  String get home_trust_sub =>
      _resolve('home_trust_sub', (loc) => loc.home_trust_sub);

  @override
  String get deed_green => _resolve('deed_green', (loc) => loc.deed_green);

  @override
  String get deed_red => _resolve('deed_red', (loc) => loc.deed_red);

  @override
  String get deed_temporary =>
      _resolve('deed_temporary', (loc) => loc.deed_temporary);

  @override
  String get deed_agricultural =>
      _resolve('deed_agricultural', (loc) => loc.deed_agricultural);

  @override
  String get deed_court_ruling =>
      _resolve('deed_court_ruling', (loc) => loc.deed_court_ruling);

  @override
  String get finish_on_bone =>
      _resolve('finish_on_bone', (loc) => loc.finish_on_bone);

  @override
  String get finish_normal =>
      _resolve('finish_normal', (loc) => loc.finish_normal);

  @override
  String get finish_deluxe =>
      _resolve('finish_deluxe', (loc) => loc.finish_deluxe);

  @override
  String get finish_super_deluxe =>
      _resolve('finish_super_deluxe', (loc) => loc.finish_super_deluxe);

  @override
  String get filter_deed_type =>
      _resolve('filter_deed_type', (loc) => loc.filter_deed_type);

  @override
  String get filter_finish_level =>
      _resolve('filter_finish_level', (loc) => loc.filter_finish_level);

  @override
  String get filter_verified_only =>
      _resolve('filter_verified_only', (loc) => loc.filter_verified_only);

  @override
  String get detail_field_verified_title => _resolve(
    'detail_field_verified_title',
    (loc) => loc.detail_field_verified_title,
  );

  @override
  String get detail_field_verified_body => _resolve(
    'detail_field_verified_body',
    (loc) => loc.detail_field_verified_body,
  );

  @override
  String get detail_deed_label =>
      _resolve('detail_deed_label', (loc) => loc.detail_deed_label);

  @override
  String get detail_finish_label =>
      _resolve('detail_finish_label', (loc) => loc.detail_finish_label);

  @override
  String get home_categories_title =>
      _resolve('home_categories_title', (loc) => loc.home_categories_title);

  @override
  String get home_see_all =>
      _resolve('home_see_all', (loc) => loc.home_see_all);

  @override
  String get home_verified_rail_title => _resolve(
    'home_verified_rail_title',
    (loc) => loc.home_verified_rail_title,
  );

  @override
  String get ad_sponsored_label =>
      _resolve('ad_sponsored_label', (loc) => loc.ad_sponsored_label);

  @override
  String get ad_learn_more =>
      _resolve('ad_learn_more', (loc) => loc.ad_learn_more);

  @override
  String get list_dot_separator =>
      _resolve('list_dot_separator', (loc) => loc.list_dot_separator);

  @override
  String get home_popular_searches =>
      _resolve('home_popular_searches', (loc) => loc.home_popular_searches);

  @override
  String get home_greeting_welcome =>
      _resolve('home_greeting_welcome', (loc) => loc.home_greeting_welcome);

  @override
  String home_greeting_named(String name) =>
      _resolve('home_greeting_named', (loc) => loc.home_greeting_named(name));

  @override
  String get home_greeting_subtitle =>
      _resolve('home_greeting_subtitle', (loc) => loc.home_greeting_subtitle);

  @override
  String get auth_login_headline =>
      _resolve('auth_login_headline', (loc) => loc.auth_login_headline);

  @override
  String get auth_login_subtitle =>
      _resolve('auth_login_subtitle', (loc) => loc.auth_login_subtitle);

  @override
  String get auth_register_headline =>
      _resolve('auth_register_headline', (loc) => loc.auth_register_headline);

  @override
  String get auth_register_subtitle =>
      _resolve('auth_register_subtitle', (loc) => loc.auth_register_subtitle);

  @override
  String get auth_trust_note =>
      _resolve('auth_trust_note', (loc) => loc.auth_trust_note);

  @override
  String get spec_rooms_label =>
      _resolve('spec_rooms_label', (loc) => loc.spec_rooms_label);

  @override
  String get spec_baths_label =>
      _resolve('spec_baths_label', (loc) => loc.spec_baths_label);

  @override
  String get spec_area_label =>
      _resolve('spec_area_label', (loc) => loc.spec_area_label);

  @override
  String get spec_floor_label =>
      _resolve('spec_floor_label', (loc) => loc.spec_floor_label);

  @override
  String get spec_area_unit =>
      _resolve('spec_area_unit', (loc) => loc.spec_area_unit);
  @override
  String get listing_details_similar_title => _resolve(
    'listing_details_similar_title',
    (loc) => loc.listing_details_similar_title,
  );

  @override
  String get listing_details_facts_type_label => _resolve(
    'listing_details_facts_type_label',
    (loc) => loc.listing_details_facts_type_label,
  );

  @override
  String listing_details_contact_username(String username) => _resolve(
    'listing_details_contact_username',
    (loc) => loc.listing_details_contact_username(username),
  );

  @override
  String get listing_details_share_subject => _resolve(
    'listing_details_share_subject',
    (loc) => loc.listing_details_share_subject,
  );

  @override
  String get search_display_mode_list => _resolve(
    'search_display_mode_list',
    (loc) => loc.search_display_mode_list,
  );

  @override
  String get search_display_mode_map =>
      _resolve('search_display_mode_map', (loc) => loc.search_display_mode_map);

  @override
  String get search_filter_count_any =>
      _resolve('search_filter_count_any', (loc) => loc.search_filter_count_any);

  @override
  String get search_filter_range_no_max => _resolve(
    'search_filter_range_no_max',
    (loc) => loc.search_filter_range_no_max,
  );

  @override
  String search_filter_area_size_value(String value) => _resolve(
    'search_filter_area_size_value',
    (loc) => loc.search_filter_area_size_value(value),
  );

  @override
  String get search_recent_title =>
      _resolve('search_recent_title', (loc) => loc.search_recent_title);

  @override
  String get search_recent_clear_all =>
      _resolve('search_recent_clear_all', (loc) => loc.search_recent_clear_all);

  @override
  String get search_recent_empty_title => _resolve(
    'search_recent_empty_title',
    (loc) => loc.search_recent_empty_title,
  );

  @override
  String get search_recent_empty_subtitle => _resolve(
    'search_recent_empty_subtitle',
    (loc) => loc.search_recent_empty_subtitle,
  );

  @override
  String get search_save_this_search_action => _resolve(
    'search_save_this_search_action',
    (loc) => loc.search_save_this_search_action,
  );

  @override
  String get search_save_search_dialog_title => _resolve(
    'search_save_search_dialog_title',
    (loc) => loc.search_save_search_dialog_title,
  );

  @override
  String get search_save_search_label_hint => _resolve(
    'search_save_search_label_hint',
    (loc) => loc.search_save_search_label_hint,
  );

  @override
  String get search_save_search_confirm => _resolve(
    'search_save_search_confirm',
    (loc) => loc.search_save_search_confirm,
  );

  @override
  String get search_save_search_cancel => _resolve(
    'search_save_search_cancel',
    (loc) => loc.search_save_search_cancel,
  );

  @override
  String get search_save_search_success => _resolve(
    'search_save_search_success',
    (loc) => loc.search_save_search_success,
  );

  @override
  String get search_save_search_auth_required => _resolve(
    'search_save_search_auth_required',
    (loc) => loc.search_save_search_auth_required,
  );

  @override
  String get search_save_search_error => _resolve(
    'search_save_search_error',
    (loc) => loc.search_save_search_error,
  );

  @override
  String get search_saved_searches_title => _resolve(
    'search_saved_searches_title',
    (loc) => loc.search_saved_searches_title,
  );

  @override
  String get search_saved_searches_empty_title => _resolve(
    'search_saved_searches_empty_title',
    (loc) => loc.search_saved_searches_empty_title,
  );

  @override
  String get search_saved_searches_empty_subtitle => _resolve(
    'search_saved_searches_empty_subtitle',
    (loc) => loc.search_saved_searches_empty_subtitle,
  );

  @override
  String get search_saved_searches_error_title => _resolve(
    'search_saved_searches_error_title',
    (loc) => loc.search_saved_searches_error_title,
  );

  @override
  String get search_saved_searches_all_listings => _resolve(
    'search_saved_searches_all_listings',
    (loc) => loc.search_saved_searches_all_listings,
  );

  @override
  String get search_saved_searches_delete => _resolve(
    'search_saved_searches_delete',
    (loc) => loc.search_saved_searches_delete,
  );

  @override
  String get search_saved_searches_delete_title => _resolve(
    'search_saved_searches_delete_title',
    (loc) => loc.search_saved_searches_delete_title,
  );

  @override
  String get search_saved_searches_delete_body => _resolve(
    'search_saved_searches_delete_body',
    (loc) => loc.search_saved_searches_delete_body,
  );

  @override
  String get search_view_full_map =>
      _resolve('search_view_full_map', (loc) => loc.search_view_full_map);

  @override
  String get favorites_sort_label =>
      _resolve('favorites_sort_label', (loc) => loc.favorites_sort_label);

  @override
  String get favorites_sort_recently_saved => _resolve(
    'favorites_sort_recently_saved',
    (loc) => loc.favorites_sort_recently_saved,
  );

  @override
  String get favorites_sort_price_desc => _resolve(
    'favorites_sort_price_desc',
    (loc) => loc.favorites_sort_price_desc,
  );

  @override
  String get favorites_sort_price_asc => _resolve(
    'favorites_sort_price_asc',
    (loc) => loc.favorites_sort_price_asc,
  );

  @override
  String get publisherDashboardTitle =>
      _resolve('publisherDashboardTitle', (loc) => loc.publisherDashboardTitle);

  @override
  String get publisherDashboardHeaderTitle => _resolve(
    'publisherDashboardHeaderTitle',
    (loc) => loc.publisherDashboardHeaderTitle,
  );

  @override
  String get publisherDashboardHeaderSubtitle => _resolve(
    'publisherDashboardHeaderSubtitle',
    (loc) => loc.publisherDashboardHeaderSubtitle,
  );

  @override
  String get publisherDashboardQuickActions => _resolve(
    'publisherDashboardQuickActions',
    (loc) => loc.publisherDashboardQuickActions,
  );

  @override
  String get publisherDashboardCrownSubtitle => _resolve(
    'publisherDashboardCrownSubtitle',
    (loc) => loc.publisherDashboardCrownSubtitle,
  );

  @override
  String get publisherManageSection =>
      _resolve('publisherManageSection', (loc) => loc.publisherManageSection);

  @override
  String get publisherDashboardInteractionsTitle => _resolve(
    'publisherDashboardInteractionsTitle',
    (loc) => loc.publisherDashboardInteractionsTitle,
  );

  @override
  String get publisherDashboardChartRangeWeek => _resolve(
    'publisherDashboardChartRangeWeek',
    (loc) => loc.publisherDashboardChartRangeWeek,
  );

  @override
  String get publisherDashboardChartTotalLabel => _resolve(
    'publisherDashboardChartTotalLabel',
    (loc) => loc.publisherDashboardChartTotalLabel,
  );

  @override
  String get publisherDashboardSummaryError => _resolve(
    'publisherDashboardSummaryError',
    (loc) => loc.publisherDashboardSummaryError,
  );

  @override
  String get publisherDashboardStatTotalListings => _resolve(
    'publisherDashboardStatTotalListings',
    (loc) => loc.publisherDashboardStatTotalListings,
  );

  @override
  String get publisherDashboardStatActiveListings => _resolve(
    'publisherDashboardStatActiveListings',
    (loc) => loc.publisherDashboardStatActiveListings,
  );

  @override
  String get publisherDashboardStatPendingListings => _resolve(
    'publisherDashboardStatPendingListings',
    (loc) => loc.publisherDashboardStatPendingListings,
  );

  @override
  String get publisherDashboardStatRejectedListings => _resolve(
    'publisherDashboardStatRejectedListings',
    (loc) => loc.publisherDashboardStatRejectedListings,
  );

  @override
  String get publisherDashboardStatTotalInquiries => _resolve(
    'publisherDashboardStatTotalInquiries',
    (loc) => loc.publisherDashboardStatTotalInquiries,
  );

  @override
  String get publisherDashboardStatNewInquiries => _resolve(
    'publisherDashboardStatNewInquiries',
    (loc) => loc.publisherDashboardStatNewInquiries,
  );

  @override
  String get publisherDashboardStatLeadEvents => _resolve(
    'publisherDashboardStatLeadEvents',
    (loc) => loc.publisherDashboardStatLeadEvents,
  );

  @override
  String get publisherDashboardActionMyListingsSubtitle => _resolve(
    'publisherDashboardActionMyListingsSubtitle',
    (loc) => loc.publisherDashboardActionMyListingsSubtitle,
  );

  @override
  String get publisherDashboardActionAddListing => _resolve(
    'publisherDashboardActionAddListing',
    (loc) => loc.publisherDashboardActionAddListing,
  );

  @override
  String get publisherDashboardActionAddListingSubtitle => _resolve(
    'publisherDashboardActionAddListingSubtitle',
    (loc) => loc.publisherDashboardActionAddListingSubtitle,
  );

  @override
  String get publisherDashboardActionSavedSearches => _resolve(
    'publisherDashboardActionSavedSearches',
    (loc) => loc.publisherDashboardActionSavedSearches,
  );

  @override
  String get publisherDashboardActionSavedSearchesSubtitle => _resolve(
    'publisherDashboardActionSavedSearchesSubtitle',
    (loc) => loc.publisherDashboardActionSavedSearchesSubtitle,
  );

  @override
  String get dashboardEntryTitle =>
      _resolve('dashboardEntryTitle', (loc) => loc.dashboardEntryTitle);

  @override
  String get dashboardEntryEmptyTitle => _resolve(
    'dashboardEntryEmptyTitle',
    (loc) => loc.dashboardEntryEmptyTitle,
  );

  @override
  String get dashboardEntryEmptyBody =>
      _resolve('dashboardEntryEmptyBody', (loc) => loc.dashboardEntryEmptyBody);

  @override
  String get adminConsoleHeaderTitle =>
      _resolve('adminConsoleHeaderTitle', (loc) => loc.adminConsoleHeaderTitle);

  @override
  String get adminConsoleHeaderSubtitle => _resolve(
    'adminConsoleHeaderSubtitle',
    (loc) => loc.adminConsoleHeaderSubtitle,
  );

  @override
  String get adminRoleBadgeSuperAdmin => _resolve(
    'adminRoleBadgeSuperAdmin',
    (loc) => loc.adminRoleBadgeSuperAdmin,
  );

  @override
  String get adminRoleBadgeAdministrator => _resolve(
    'adminRoleBadgeAdministrator',
    (loc) => loc.adminRoleBadgeAdministrator,
  );

  @override
  String get adminSectionGroupModeration => _resolve(
    'adminSectionGroupModeration',
    (loc) => loc.adminSectionGroupModeration,
  );

  @override
  String get adminSectionGroupConfiguration => _resolve(
    'adminSectionGroupConfiguration',
    (loc) => loc.adminSectionGroupConfiguration,
  );

  @override
  String get adminSectionGroupInsights => _resolve(
    'adminSectionGroupInsights',
    (loc) => loc.adminSectionGroupInsights,
  );

  @override
  String get adminSectionGroupSuperAdmin => _resolve(
    'adminSectionGroupSuperAdmin',
    (loc) => loc.adminSectionGroupSuperAdmin,
  );

  @override
  String get adminQuickStatPendingUsers => _resolve(
    'adminQuickStatPendingUsers',
    (loc) => loc.adminQuickStatPendingUsers,
  );

  @override
  String get adminQuickStatPendingListings => _resolve(
    'adminQuickStatPendingListings',
    (loc) => loc.adminQuickStatPendingListings,
  );

  @override
  String get adminQuickStatOpenReports => _resolve(
    'adminQuickStatOpenReports',
    (loc) => loc.adminQuickStatOpenReports,
  );

  @override
  String get adminQuickStatNewInquiries => _resolve(
    'adminQuickStatNewInquiries',
    (loc) => loc.adminQuickStatNewInquiries,
  );

  @override
  String get adminQuickStatActiveListings => _resolve(
    'adminQuickStatActiveListings',
    (loc) => loc.adminQuickStatActiveListings,
  );

  @override
  String get adminSectionSubtitleApprovals => _resolve(
    'adminSectionSubtitleApprovals',
    (loc) => loc.adminSectionSubtitleApprovals,
  );

  @override
  String get adminSectionSubtitleListingReview => _resolve(
    'adminSectionSubtitleListingReview',
    (loc) => loc.adminSectionSubtitleListingReview,
  );

  @override
  String get adminSectionSubtitleReports => _resolve(
    'adminSectionSubtitleReports',
    (loc) => loc.adminSectionSubtitleReports,
  );

  @override
  String get adminSectionSubtitleAgencies => _resolve(
    'adminSectionSubtitleAgencies',
    (loc) => loc.adminSectionSubtitleAgencies,
  );

  @override
  String get adminSectionSubtitleInquiries => _resolve(
    'adminSectionSubtitleInquiries',
    (loc) => loc.adminSectionSubtitleInquiries,
  );

  @override
  String get adminSectionSubtitleLocations => _resolve(
    'adminSectionSubtitleLocations',
    (loc) => loc.adminSectionSubtitleLocations,
  );

  @override
  String get adminSectionSubtitleCurrencies => _resolve(
    'adminSectionSubtitleCurrencies',
    (loc) => loc.adminSectionSubtitleCurrencies,
  );

  @override
  String get adminSectionSubtitleAds =>
      _resolve('adminSectionSubtitleAds', (loc) => loc.adminSectionSubtitleAds);

  @override
  String get adminSectionSubtitleSettings => _resolve(
    'adminSectionSubtitleSettings',
    (loc) => loc.adminSectionSubtitleSettings,
  );

  @override
  String get adminSectionSubtitleAuditLogs => _resolve(
    'adminSectionSubtitleAuditLogs',
    (loc) => loc.adminSectionSubtitleAuditLogs,
  );

  @override
  String get adminSectionSubtitleSuperAdmin => _resolve(
    'adminSectionSubtitleSuperAdmin',
    (loc) => loc.adminSectionSubtitleSuperAdmin,
  );

  @override
  String get action_save => _resolve('action_save', (loc) => loc.action_save);

  @override
  String get admin_report_listing_status_label => _resolve(
    'admin_report_listing_status_label',
    (loc) => loc.admin_report_listing_status_label,
  );

  @override
  String get action_browse_listings =>
      _resolve('action_browse_listings', (loc) => loc.action_browse_listings);

  @override
  String get favorites_empty_body =>
      _resolve('favorites_empty_body', (loc) => loc.favorites_empty_body);

  @override
  String get reports_my_empty_body =>
      _resolve('reports_my_empty_body', (loc) => loc.reports_my_empty_body);

  // ── Phase 25 uplift v3 (Wave A) ──────────────────────────────────────────
  @override
  String get listing_details_buyer_safety_note => _resolve(
    'listing_details_buyer_safety_note',
    (loc) => loc.listing_details_buyer_safety_note,
  );

  @override
  String get listing_details_similar_empty_title => _resolve(
    'listing_details_similar_empty_title',
    (loc) => loc.listing_details_similar_empty_title,
  );

  @override
  String get listing_details_similar_empty_action => _resolve(
    'listing_details_similar_empty_action',
    (loc) => loc.listing_details_similar_empty_action,
  );

  @override
  String get listing_details_affordability_title => _resolve(
    'listing_details_affordability_title',
    (loc) => loc.listing_details_affordability_title,
  );

  @override
  String get listing_details_affordability_monthly_label => _resolve(
    'listing_details_affordability_monthly_label',
    (loc) => loc.listing_details_affordability_monthly_label,
  );

  @override
  String get listing_details_affordability_down_label => _resolve(
    'listing_details_affordability_down_label',
    (loc) => loc.listing_details_affordability_down_label,
  );

  @override
  String get listing_details_affordability_term_label => _resolve(
    'listing_details_affordability_term_label',
    (loc) => loc.listing_details_affordability_term_label,
  );

  @override
  String get listing_details_affordability_rate_label => _resolve(
    'listing_details_affordability_rate_label',
    (loc) => loc.listing_details_affordability_rate_label,
  );

  @override
  String get listing_details_affordability_disclaimer => _resolve(
    'listing_details_affordability_disclaimer',
    (loc) => loc.listing_details_affordability_disclaimer,
  );

  @override
  String listing_details_affordability_years(String years) => _resolve(
    'listing_details_affordability_years',
    (loc) => loc.listing_details_affordability_years(years),
  );

  @override
  String listing_details_affordability_percent_value(String value) => _resolve(
    'listing_details_affordability_percent_value',
    (loc) => loc.listing_details_affordability_percent_value(value),
  );

  @override
  String agency_reject_reason_with_value(String reason) => _resolve(
    'agency_reject_reason_with_value',
    (loc) => loc.agency_reject_reason_with_value(reason),
  );

  @override
  String label_colon_prefix(String label) =>
      _resolve('label_colon_prefix', (loc) => loc.label_colon_prefix(label));

  @override
  String get report_filter_any_dash =>
      _resolve('report_filter_any_dash', (loc) => loc.report_filter_any_dash);

  @override
  String admin_report_reporter_with_id(String id) => _resolve(
    'admin_report_reporter_with_id',
    (loc) => loc.admin_report_reporter_with_id(id),
  );

  // ── Phase 25 uplift v3 (Wave B — featured listings) ──────────────────────
  @override
  String get home_featured_badge =>
      _resolve('home_featured_badge', (loc) => loc.home_featured_badge);

  @override
  String get home_featured_section_title => _resolve(
    'home_featured_section_title',
    (loc) => loc.home_featured_section_title,
  );

  @override
  String get adminPreviewActionFeature => _resolve(
    'adminPreviewActionFeature',
    (loc) => loc.adminPreviewActionFeature,
  );

  @override
  String get adminFeatureDialogTitle =>
      _resolve('adminFeatureDialogTitle', (loc) => loc.adminFeatureDialogTitle);

  @override
  String get adminFeatureDialogBody =>
      _resolve('adminFeatureDialogBody', (loc) => loc.adminFeatureDialogBody);

  @override
  String adminFeatureDialogOptionDays(int days) => _resolve(
    'adminFeatureDialogOptionDays',
    (loc) => loc.adminFeatureDialogOptionDays(days),
  );

  @override
  String get adminFeatureDialogRemove => _resolve(
    'adminFeatureDialogRemove',
    (loc) => loc.adminFeatureDialogRemove,
  );

  @override
  String get adminFeatureDialogCancel => _resolve(
    'adminFeatureDialogCancel',
    (loc) => loc.adminFeatureDialogCancel,
  );

  @override
  String adminFeaturedUntil(String date) =>
      _resolve('adminFeaturedUntil', (loc) => loc.adminFeaturedUntil(date));

  @override
  String get adminToastFeatureSuccess => _resolve(
    'adminToastFeatureSuccess',
    (loc) => loc.adminToastFeatureSuccess,
  );

  @override
  String get adminToastUnfeatureSuccess => _resolve(
    'adminToastUnfeatureSuccess',
    (loc) => loc.adminToastUnfeatureSuccess,
  );

  // ── Phase 25 uplift v3 (Wave C — renewal) ────────────────────────────────
  @override
  String myListingsExpiresInDays(int days) => _resolve(
    'myListingsExpiresInDays',
    (loc) => loc.myListingsExpiresInDays(days),
  );

  @override
  String get myListingsActionsTitle =>
      _resolve('myListingsActionsTitle', (loc) => loc.myListingsActionsTitle);

  @override
  String get myListingsActionMarkSold =>
      _resolve('myListingsActionMarkSold', (loc) => loc.myListingsActionMarkSold);

  @override
  String get myListingsActionMarkRented =>
      _resolve('myListingsActionMarkRented', (loc) => loc.myListingsActionMarkRented);

  @override
  String get myListingsActionMarkSoldSubtitle =>
      _resolve('myListingsActionMarkSoldSubtitle', (loc) => loc.myListingsActionMarkSoldSubtitle);

  @override
  String get myListingsActionPause =>
      _resolve('myListingsActionPause', (loc) => loc.myListingsActionPause);

  @override
  String get myListingsActionPauseSubtitle =>
      _resolve('myListingsActionPauseSubtitle', (loc) => loc.myListingsActionPauseSubtitle);

  @override
  String get myListingsActionRepublish =>
      _resolve('myListingsActionRepublish', (loc) => loc.myListingsActionRepublish);

  @override
  String get myListingsActionRepublishSubtitle =>
      _resolve('myListingsActionRepublishSubtitle', (loc) => loc.myListingsActionRepublishSubtitle);

  @override
  String get myListingsActionDelete =>
      _resolve('myListingsActionDelete', (loc) => loc.myListingsActionDelete);

  @override
  String get myListingsActionDeleteSubtitle =>
      _resolve('myListingsActionDeleteSubtitle', (loc) => loc.myListingsActionDeleteSubtitle);

  @override
  String get myListingsDeleteConfirmTitle =>
      _resolve('myListingsDeleteConfirmTitle', (loc) => loc.myListingsDeleteConfirmTitle);

  @override
  String get myListingsDeleteConfirmMessage =>
      _resolve('myListingsDeleteConfirmMessage', (loc) => loc.myListingsDeleteConfirmMessage);

  @override
  String get myListingsStatusChangeFailed =>
      _resolve('myListingsStatusChangeFailed', (loc) => loc.myListingsStatusChangeFailed);

  @override
  String myListingsStatusChangeSuccess(String status) => _resolve(
    'myListingsStatusChangeSuccess',
    (loc) => loc.myListingsStatusChangeSuccess(status),
  );

  @override
  String get myListingsExpiredLabel =>
      _resolve('myListingsExpiredLabel', (loc) => loc.myListingsExpiredLabel);

  @override
  String get myListingsRenewButton =>
      _resolve('myListingsRenewButton', (loc) => loc.myListingsRenewButton);

  @override
  String get myListingsRenewSuccess =>
      _resolve('myListingsRenewSuccess', (loc) => loc.myListingsRenewSuccess);

  @override
  String get myListingsRenewError =>
      _resolve('myListingsRenewError', (loc) => loc.myListingsRenewError);

  // ── Phase 25 uplift v3 (Wave E — lead analytics) ─────────────────────────
  @override
  String get leadAnalyticsTitle =>
      _resolve('leadAnalyticsTitle', (loc) => loc.leadAnalyticsTitle);

  @override
  String get publisherDashboardActionLeadAnalyticsSubtitle => _resolve(
    'publisherDashboardActionLeadAnalyticsSubtitle',
    (loc) => loc.publisherDashboardActionLeadAnalyticsSubtitle,
  );

  @override
  String get leadAnalyticsTotalCaption => _resolve(
    'leadAnalyticsTotalCaption',
    (loc) => loc.leadAnalyticsTotalCaption,
  );

  @override
  String get leadAnalyticsTrendSectionLabel => _resolve(
    'leadAnalyticsTrendSectionLabel',
    (loc) => loc.leadAnalyticsTrendSectionLabel,
  );

  @override
  String get leadAnalyticsByListingSectionLabel => _resolve(
    'leadAnalyticsByListingSectionLabel',
    (loc) => loc.leadAnalyticsByListingSectionLabel,
  );

  @override
  String leadAnalyticsListingTotal(String count) => _resolve(
    'leadAnalyticsListingTotal',
    (loc) => loc.leadAnalyticsListingTotal(count),
  );

  @override
  String get leadAnalyticsSourcePhone => _resolve(
    'leadAnalyticsSourcePhone',
    (loc) => loc.leadAnalyticsSourcePhone,
  );

  @override
  String get leadAnalyticsSourceWhatsapp => _resolve(
    'leadAnalyticsSourceWhatsapp',
    (loc) => loc.leadAnalyticsSourceWhatsapp,
  );

  @override
  String get leadAnalyticsSourceInquiry => _resolve(
    'leadAnalyticsSourceInquiry',
    (loc) => loc.leadAnalyticsSourceInquiry,
  );

  @override
  String get leadAnalyticsSourceFavorite => _resolve(
    'leadAnalyticsSourceFavorite',
    (loc) => loc.leadAnalyticsSourceFavorite,
  );

  @override
  String get leadAnalyticsUntitledListing => _resolve(
    'leadAnalyticsUntitledListing',
    (loc) => loc.leadAnalyticsUntitledListing,
  );

  @override
  String get leadAnalyticsError =>
      _resolve('leadAnalyticsError', (loc) => loc.leadAnalyticsError);

  @override
  String get leadAnalyticsEmptyHeadline => _resolve(
    'leadAnalyticsEmptyHeadline',
    (loc) => loc.leadAnalyticsEmptyHeadline,
  );

  @override
  String get leadAnalyticsEmptyBody =>
      _resolve('leadAnalyticsEmptyBody', (loc) => loc.leadAnalyticsEmptyBody);

  // ── Phase 25 uplift v3 (Wave D — reviews / seller trust) ─────────────────
  @override
  String get reviews_section_title =>
      _resolve('reviews_section_title', (loc) => loc.reviews_section_title);

  @override
  String reviews_count(int count) =>
      _resolve('reviews_count', (loc) => loc.reviews_count(count));

  @override
  String reviews_rating_with_count(double rating, int count) => _resolve(
    'reviews_rating_with_count',
    (loc) => loc.reviews_rating_with_count(rating, count),
  );

  @override
  String reviews_response_rate(int pct) => _resolve(
    'reviews_response_rate',
    (loc) => loc.reviews_response_rate(pct),
  );

  @override
  String reviews_response_hours(int hours) => _resolve(
    'reviews_response_hours',
    (loc) => loc.reviews_response_hours(hours),
  );

  @override
  String get reviews_empty_hint =>
      _resolve('reviews_empty_hint', (loc) => loc.reviews_empty_hint);

  @override
  String get reviews_anonymous_reviewer => _resolve(
    'reviews_anonymous_reviewer',
    (loc) => loc.reviews_anonymous_reviewer,
  );

  @override
  String get reviews_write_button =>
      _resolve('reviews_write_button', (loc) => loc.reviews_write_button);

  @override
  String get reviews_sign_in_hint =>
      _resolve('reviews_sign_in_hint', (loc) => loc.reviews_sign_in_hint);

  @override
  String get reviews_write_sheet_title => _resolve(
    'reviews_write_sheet_title',
    (loc) => loc.reviews_write_sheet_title,
  );

  @override
  String get reviews_write_rating_label => _resolve(
    'reviews_write_rating_label',
    (loc) => loc.reviews_write_rating_label,
  );

  @override
  String get reviews_write_comment_label => _resolve(
    'reviews_write_comment_label',
    (loc) => loc.reviews_write_comment_label,
  );

  @override
  String get reviews_write_comment_hint => _resolve(
    'reviews_write_comment_hint',
    (loc) => loc.reviews_write_comment_hint,
  );

  @override
  String get reviews_write_submit =>
      _resolve('reviews_write_submit', (loc) => loc.reviews_write_submit);

  @override
  String get reviews_submit_success =>
      _resolve('reviews_submit_success', (loc) => loc.reviews_submit_success);

  @override
  String get reviews_submit_already_reviewed => _resolve(
    'reviews_submit_already_reviewed',
    (loc) => loc.reviews_submit_already_reviewed,
  );

  @override
  String get reviews_submit_error =>
      _resolve('reviews_submit_error', (loc) => loc.reviews_submit_error);

  @override
  String get reviews_time_just_now =>
      _resolve('reviews_time_just_now', (loc) => loc.reviews_time_just_now);

  @override
  String reviews_time_minutes(int minutes) => _resolve(
    'reviews_time_minutes',
    (loc) => loc.reviews_time_minutes(minutes),
  );

  @override
  String reviews_time_hours(int hours) =>
      _resolve('reviews_time_hours', (loc) => loc.reviews_time_hours(hours));

  @override
  String reviews_time_days(int days) =>
      _resolve('reviews_time_days', (loc) => loc.reviews_time_days(days));

  // ── Phase 25 uplift v3 (Wave F — comparison + recently viewed) ───────────
  @override
  String get comparisonPageTitle =>
      _resolve('comparisonPageTitle', (loc) => loc.comparisonPageTitle);

  @override
  String get comparisonClearAll =>
      _resolve('comparisonClearAll', (loc) => loc.comparisonClearAll);

  @override
  String get comparisonEmptyHint =>
      _resolve('comparisonEmptyHint', (loc) => loc.comparisonEmptyHint);

  @override
  String get comparisonRowPurpose =>
      _resolve('comparisonRowPurpose', (loc) => loc.comparisonRowPurpose);

  @override
  String get comparisonRowType =>
      _resolve('comparisonRowType', (loc) => loc.comparisonRowType);

  @override
  String get comparisonRowRooms =>
      _resolve('comparisonRowRooms', (loc) => loc.comparisonRowRooms);

  @override
  String get comparisonRowBathrooms =>
      _resolve('comparisonRowBathrooms', (loc) => loc.comparisonRowBathrooms);

  @override
  String get comparisonRowArea =>
      _resolve('comparisonRowArea', (loc) => loc.comparisonRowArea);

  @override
  String get comparisonRowLocation =>
      _resolve('comparisonRowLocation', (loc) => loc.comparisonRowLocation);

  @override
  String get comparisonRemoveColumn =>
      _resolve('comparisonRemoveColumn', (loc) => loc.comparisonRemoveColumn);

  @override
  String get comparisonAddToCompare =>
      _resolve('comparisonAddToCompare', (loc) => loc.comparisonAddToCompare);

  @override
  String get comparisonRemoveFromCompare => _resolve(
    'comparisonRemoveFromCompare',
    (loc) => loc.comparisonRemoveFromCompare,
  );

  @override
  String comparisonCompareCount(int count) => _resolve(
    'comparisonCompareCount',
    (loc) => loc.comparisonCompareCount(count),
  );

  @override
  String get home_recently_viewed_title => _resolve(
    'home_recently_viewed_title',
    (loc) => loc.home_recently_viewed_title,
  );

  @override
  String get comparisonValueNone =>
      _resolve('comparisonValueNone', (loc) => loc.comparisonValueNone);

  // ── Growth (Batch 1 — alerts + data saver) ───────────────────────────────
  @override
  String get notification_type_message_received =>
      _resolve('notification_type_message_received', (loc) => loc.notification_type_message_received);

  @override
  String get notification_type_viewing_requested =>
      _resolve('notification_type_viewing_requested', (loc) => loc.notification_type_viewing_requested);

  @override
  String get notification_type_viewing_confirmed =>
      _resolve('notification_type_viewing_confirmed', (loc) => loc.notification_type_viewing_confirmed);

  @override
  String get notification_type_viewing_declined =>
      _resolve('notification_type_viewing_declined', (loc) => loc.notification_type_viewing_declined);

  @override
  String get notification_type_viewing_cancelled =>
      _resolve('notification_type_viewing_cancelled', (loc) => loc.notification_type_viewing_cancelled);

  @override
  String get notification_type_saved_search_match => _resolve(
    'notification_type_saved_search_match',
    (loc) => loc.notification_type_saved_search_match,
  );

  @override
  String notification_body_saved_search_match(
    String listingTitle,
    String savedSearchLabel,
  ) => _resolve(
    'notification_body_saved_search_match',
    (loc) => loc.notification_body_saved_search_match(
      listingTitle,
      savedSearchLabel,
    ),
  );

  @override
  String get search_saved_searches_alerts_hint => _resolve(
    'search_saved_searches_alerts_hint',
    (loc) => loc.search_saved_searches_alerts_hint,
  );

  @override
  String get profile_data_saver_title => _resolve(
    'profile_data_saver_title',
    (loc) => loc.profile_data_saver_title,
  );

  @override
  String get profile_data_saver_subtitle => _resolve(
    'profile_data_saver_subtitle',
    (loc) => loc.profile_data_saver_subtitle,
  );

  // ── Growth (Wave G1 — in-app chat) ───────────────────────────────────────
  @override
  String get chatConversationsTitle =>
      _resolve('chatConversationsTitle', (loc) => loc.chatConversationsTitle);

  @override
  String get chatConversationsEmptyTitle => _resolve(
    'chatConversationsEmptyTitle',
    (loc) => loc.chatConversationsEmptyTitle,
  );

  @override
  String get chatConversationsEmptyBody => _resolve(
    'chatConversationsEmptyBody',
    (loc) => loc.chatConversationsEmptyBody,
  );

  @override
  String get chatConversationsErrorTitle => _resolve(
    'chatConversationsErrorTitle',
    (loc) => loc.chatConversationsErrorTitle,
  );

  @override
  String get chatThreadTitleFallback =>
      _resolve('chatThreadTitleFallback', (loc) => loc.chatThreadTitleFallback);

  @override
  String get chatThreadEmptyTitle =>
      _resolve('chatThreadEmptyTitle', (loc) => loc.chatThreadEmptyTitle);

  @override
  String get chatThreadEmptyBody =>
      _resolve('chatThreadEmptyBody', (loc) => loc.chatThreadEmptyBody);

  @override
  String get chatThreadErrorTitle =>
      _resolve('chatThreadErrorTitle', (loc) => loc.chatThreadErrorTitle);

  @override
  String get chatComposerHint =>
      _resolve('chatComposerHint', (loc) => loc.chatComposerHint);

  @override
  String get chatComposerSend =>
      _resolve('chatComposerSend', (loc) => loc.chatComposerSend);

  @override
  String get chatContactAction =>
      _resolve('chatContactAction', (loc) => loc.chatContactAction);

  @override
  String get chatSignInPrompt =>
      _resolve('chatSignInPrompt', (loc) => loc.chatSignInPrompt);

  @override
  String get chatOpenError =>
      _resolve('chatOpenError', (loc) => loc.chatOpenError);

  @override
  String get chatMessagesTile =>
      _resolve('chatMessagesTile', (loc) => loc.chatMessagesTile);

  @override
  String get chatRolePublisher =>
      _resolve('chatRolePublisher', (loc) => loc.chatRolePublisher);

  @override
  String get chatRoleBuyer =>
      _resolve('chatRoleBuyer', (loc) => loc.chatRoleBuyer);

  @override
  String get chatListingUnavailable =>
      _resolve('chatListingUnavailable', (loc) => loc.chatListingUnavailable);

  // ── Growth (Wave G3 — viewing scheduler) ─────────────────────────────────
  @override
  String get viewingRequestAction =>
      _resolve('viewingRequestAction', (loc) => loc.viewingRequestAction);
  @override
  String get viewingsTile =>
      _resolve('viewingsTile', (loc) => loc.viewingsTile);
  @override
  String get viewingRequestTitle =>
      _resolve('viewingRequestTitle', (loc) => loc.viewingRequestTitle);
  @override
  String get viewingPickDate =>
      _resolve('viewingPickDate', (loc) => loc.viewingPickDate);
  @override
  String get viewingPickTime =>
      _resolve('viewingPickTime', (loc) => loc.viewingPickTime);
  @override
  String get viewingNoteLabel =>
      _resolve('viewingNoteLabel', (loc) => loc.viewingNoteLabel);
  @override
  String get viewingNotePlaceholder =>
      _resolve('viewingNotePlaceholder', (loc) => loc.viewingNotePlaceholder);
  @override
  String get viewingPastError =>
      _resolve('viewingPastError', (loc) => loc.viewingPastError);
  @override
  String get viewingSubmitButton =>
      _resolve('viewingSubmitButton', (loc) => loc.viewingSubmitButton);
  @override
  String get viewingChooseDayLabel =>
      _resolve('viewingChooseDayLabel', (loc) => loc.viewingChooseDayLabel);
  @override
  String get viewingChoosePeriodLabel => _resolve(
    'viewingChoosePeriodLabel',
    (loc) => loc.viewingChoosePeriodLabel,
  );
  @override
  String get viewingSlotMorning =>
      _resolve('viewingSlotMorning', (loc) => loc.viewingSlotMorning);
  @override
  String get viewingSlotNoon =>
      _resolve('viewingSlotNoon', (loc) => loc.viewingSlotNoon);
  @override
  String get viewingSlotAfternoon =>
      _resolve('viewingSlotAfternoon', (loc) => loc.viewingSlotAfternoon);
  @override
  String get viewingSlotEvening =>
      _resolve('viewingSlotEvening', (loc) => loc.viewingSlotEvening);
  @override
  String get viewingConfirmRequestButton => _resolve(
    'viewingConfirmRequestButton',
    (loc) => loc.viewingConfirmRequestButton,
  );
  @override
  String get viewingBookedTitle =>
      _resolve('viewingBookedTitle', (loc) => loc.viewingBookedTitle);
  @override
  String get viewingBookedBody =>
      _resolve('viewingBookedBody', (loc) => loc.viewingBookedBody);
  @override
  String get viewingEditRequestAction => _resolve(
    'viewingEditRequestAction',
    (loc) => loc.viewingEditRequestAction,
  );
  @override
  String get viewingDoneAction =>
      _resolve('viewingDoneAction', (loc) => loc.viewingDoneAction);
  @override
  String get viewingRequestSuccess =>
      _resolve('viewingRequestSuccess', (loc) => loc.viewingRequestSuccess);
  @override
  String get viewingRequestError =>
      _resolve('viewingRequestError', (loc) => loc.viewingRequestError);
  @override
  String get viewingsListTitle =>
      _resolve('viewingsListTitle', (loc) => loc.viewingsListTitle);
  @override
  String get viewingsListEmptyTitle =>
      _resolve('viewingsListEmptyTitle', (loc) => loc.viewingsListEmptyTitle);
  @override
  String get viewingsListEmptyBody =>
      _resolve('viewingsListEmptyBody', (loc) => loc.viewingsListEmptyBody);
  @override
  String get viewingsListErrorTitle =>
      _resolve('viewingsListErrorTitle', (loc) => loc.viewingsListErrorTitle);
  @override
  String get viewingListingUnavailable => _resolve(
    'viewingListingUnavailable',
    (loc) => loc.viewingListingUnavailable,
  );
  @override
  String get viewingStatusRequested =>
      _resolve('viewingStatusRequested', (loc) => loc.viewingStatusRequested);
  @override
  String get viewingStatusConfirmed =>
      _resolve('viewingStatusConfirmed', (loc) => loc.viewingStatusConfirmed);
  @override
  String get viewingStatusDeclined =>
      _resolve('viewingStatusDeclined', (loc) => loc.viewingStatusDeclined);
  @override
  String get viewingStatusCancelled =>
      _resolve('viewingStatusCancelled', (loc) => loc.viewingStatusCancelled);
  @override
  String get viewingConfirmAction =>
      _resolve('viewingConfirmAction', (loc) => loc.viewingConfirmAction);
  @override
  String get viewingDeclineAction =>
      _resolve('viewingDeclineAction', (loc) => loc.viewingDeclineAction);
  @override
  String get viewingCancelAction =>
      _resolve('viewingCancelAction', (loc) => loc.viewingCancelAction);
  @override
  String get viewingContactPublisher =>
      _resolve('viewingContactPublisher', (loc) => loc.viewingContactPublisher);
  @override
  String get viewingConfirmedSuccess =>
      _resolve('viewingConfirmedSuccess', (loc) => loc.viewingConfirmedSuccess);
  @override
  String get viewingDeclinedSuccess =>
      _resolve('viewingDeclinedSuccess', (loc) => loc.viewingDeclinedSuccess);
  @override
  String get viewingCancelledSuccess =>
      _resolve('viewingCancelledSuccess', (loc) => loc.viewingCancelledSuccess);
  @override
  String get viewingUpdateError =>
      _resolve('viewingUpdateError', (loc) => loc.viewingUpdateError);

  // ── Growth (Wave G6 — owner/agent filter + G7 — 360 tours) ───────────────
  @override
  String get search_filter_lister_type_label => _resolve(
    'search_filter_lister_type_label',
    (loc) => loc.search_filter_lister_type_label,
  );
  @override
  String get search_filter_lister_type_all => _resolve(
    'search_filter_lister_type_all',
    (loc) => loc.search_filter_lister_type_all,
  );
  @override
  String get search_filter_lister_type_owner => _resolve(
    'search_filter_lister_type_owner',
    (loc) => loc.search_filter_lister_type_owner,
  );
  @override
  String get search_filter_lister_type_agency => _resolve(
    'search_filter_lister_type_agency',
    (loc) => loc.search_filter_lister_type_agency,
  );
  @override
  String get search_result_by_owner =>
      _resolve('search_result_by_owner', (loc) => loc.search_result_by_owner);
  @override
  String get panoramaTourTitle =>
      _resolve('panoramaTourTitle', (loc) => loc.panoramaTourTitle);
  @override
  String get panoramaTourClose =>
      _resolve('panoramaTourClose', (loc) => loc.panoramaTourClose);
  @override
  String get panoramaTourBadge =>
      _resolve('panoramaTourBadge', (loc) => loc.panoramaTourBadge);
  @override
  String get panoramaTourOpen =>
      _resolve('panoramaTourOpen', (loc) => loc.panoramaTourOpen);
  @override
  String get mediaActionMarkPanorama =>
      _resolve('mediaActionMarkPanorama', (loc) => loc.mediaActionMarkPanorama);
  @override
  String get mediaActionUnmarkPanorama => _resolve(
    'mediaActionUnmarkPanorama',
    (loc) => loc.mediaActionUnmarkPanorama,
  );
  @override
  String get mediaThumbnailPanoramaBadge => _resolve(
    'mediaThumbnailPanoramaBadge',
    (loc) => loc.mediaThumbnailPanoramaBadge,
  );

  // ── Redesign (profile sections + add-listing flow) ───────────────────────
  @override
  String get profileSectionAccount =>
      _resolve('profileSectionAccount', (loc) => loc.profileSectionAccount);
  @override
  String get profileSectionActivity =>
      _resolve('profileSectionActivity', (loc) => loc.profileSectionActivity);
  @override
  String get profileSectionSelling =>
      _resolve('profileSectionSelling', (loc) => loc.profileSectionSelling);
  @override
  String get profileSectionAdmin =>
      _resolve('profileSectionAdmin', (loc) => loc.profileSectionAdmin);
  @override
  String get profileSectionMore =>
      _resolve('profileSectionMore', (loc) => loc.profileSectionMore);
  @override
  String listingFormStepCounter(int current, int total, String label) =>
      _resolve(
        'listingFormStepCounter',
        (loc) => loc.listingFormStepCounter(current, total, label),
      );
  @override
  String get listingFormStepBasicsSubtitle => _resolve(
    'listingFormStepBasicsSubtitle',
    (loc) => loc.listingFormStepBasicsSubtitle,
  );
  @override
  String get listingFormStepLocationSubtitle => _resolve(
    'listingFormStepLocationSubtitle',
    (loc) => loc.listingFormStepLocationSubtitle,
  );
  @override
  String get listingFormStepDetailsSubtitle => _resolve(
    'listingFormStepDetailsSubtitle',
    (loc) => loc.listingFormStepDetailsSubtitle,
  );
  @override
  String get listingFormDetailsFeaturesSubtitle => _resolve(
    'listingFormDetailsFeaturesSubtitle',
    (loc) => loc.listingFormDetailsFeaturesSubtitle,
  );
  @override
  String get listingFormStepPricesSubtitle => _resolve(
    'listingFormStepPricesSubtitle',
    (loc) => loc.listingFormStepPricesSubtitle,
  );
  @override
  String get listingFormStepVisibilitySubtitle => _resolve(
    'listingFormStepVisibilitySubtitle',
    (loc) => loc.listingFormStepVisibilitySubtitle,
  );
  @override
  String get listingFormContactSectionTitle => _resolve(
    'listingFormContactSectionTitle',
    (loc) => loc.listingFormContactSectionTitle,
  );
  @override
  String get listingFormContactSectionSubtitle => _resolve(
    'listingFormContactSectionSubtitle',
    (loc) => loc.listingFormContactSectionSubtitle,
  );
  @override
  String get listingFormStepMediaSubtitle => _resolve(
    'listingFormStepMediaSubtitle',
    (loc) => loc.listingFormStepMediaSubtitle,
  );
  @override
  String get listingFormSubmitSuccessSubtitle => _resolve(
    'listingFormSubmitSuccessSubtitle',
    (loc) => loc.listingFormSubmitSuccessSubtitle,
  );

  @override
  String profile_username_handle(String username) => _resolve(
    'profile_username_handle',
    (loc) => loc.profile_username_handle(username),
  );

  // ─── Phase 28 — premium worth pass ───
  @override
  String contactWhatsappPrefill(String title, String link) => _resolve(
    'contactWhatsappPrefill',
    (loc) => loc.contactWhatsappPrefill(title, link),
  );
  @override
  String galleryViewerCounter(int current, int total) => _resolve(
    'galleryViewerCounter',
    (loc) => loc.galleryViewerCounter(current, total),
  );
  @override
  String get galleryViewerClose =>
      _resolve('galleryViewerClose', (loc) => loc.galleryViewerClose);
  @override
  String get marketInsightsTitle =>
      _resolve('marketInsightsTitle', (loc) => loc.marketInsightsTitle);
  @override
  String marketInsightsAvgCaption(String price) => _resolve(
    'marketInsightsAvgCaption',
    (loc) => loc.marketInsightsAvgCaption(price),
  );
  @override
  String marketInsightsBasedOn(int count) => _resolve(
    'marketInsightsBasedOn',
    (loc) => loc.marketInsightsBasedOn(count),
  );
  @override
  String get nearbyAmenitiesTitle =>
      _resolve('nearbyAmenitiesTitle', (loc) => loc.nearbyAmenitiesTitle);
  @override
  String get amenitySchool =>
      _resolve('amenitySchool', (loc) => loc.amenitySchool);
  @override
  String get amenityHospital =>
      _resolve('amenityHospital', (loc) => loc.amenityHospital);
  @override
  String get amenityPharmacy =>
      _resolve('amenityPharmacy', (loc) => loc.amenityPharmacy);
  @override
  String get amenityMarket =>
      _resolve('amenityMarket', (loc) => loc.amenityMarket);
  @override
  String get amenityMosque =>
      _resolve('amenityMosque', (loc) => loc.amenityMosque);
  @override
  String amenityDistanceM(int meters) =>
      _resolve('amenityDistanceM', (loc) => loc.amenityDistanceM(meters));
  @override
  String amenityDistanceKm(String km) =>
      _resolve('amenityDistanceKm', (loc) => loc.amenityDistanceKm(km));
  @override
  String get assistantTitle =>
      _resolve('assistantTitle', (loc) => loc.assistantTitle);
  @override
  String get assistantGreeting =>
      _resolve('assistantGreeting', (loc) => loc.assistantGreeting);
  @override
  String get assistantInputHint =>
      _resolve('assistantInputHint', (loc) => loc.assistantInputHint);
  @override
  String get assistantShowResults =>
      _resolve('assistantShowResults', (loc) => loc.assistantShowResults);
  @override
  String assistantShowResultsCount(int count) => _resolve(
    'assistantShowResultsCount',
    (loc) => loc.assistantShowResultsCount(count),
  );
  @override
  String get assistantParsedSummary =>
      _resolve('assistantParsedSummary', (loc) => loc.assistantParsedSummary);
  @override
  String get assistantNoMatch =>
      _resolve('assistantNoMatch', (loc) => loc.assistantNoMatch);
  @override
  String assistantStatsAnswer(String area, String price, int count) => _resolve(
    'assistantStatsAnswer',
    (loc) => loc.assistantStatsAnswer(area, price, count),
  );
  @override
  String get assistantQuickSale =>
      _resolve('assistantQuickSale', (loc) => loc.assistantQuickSale);
  @override
  String get assistantQuickRent =>
      _resolve('assistantQuickRent', (loc) => loc.assistantQuickRent);
  @override
  String get assistantQuickStats =>
      _resolve('assistantQuickStats', (loc) => loc.assistantQuickStats);
  @override
  String get assistantPoweredBy =>
      _resolve('assistantPoweredBy', (loc) => loc.assistantPoweredBy);
  @override
  String get crmPageTitle =>
      _resolve("crmPageTitle", (loc) => loc.crmPageTitle);
  @override
  String get crmLeadDetailTitle =>
      _resolve("crmLeadDetailTitle", (loc) => loc.crmLeadDetailTitle);
  @override
  String get crmAddLeadAction =>
      _resolve("crmAddLeadAction", (loc) => loc.crmAddLeadAction);
  @override
  String get crmAddLeadTitle =>
      _resolve("crmAddLeadTitle", (loc) => loc.crmAddLeadTitle);
  @override
  String get crmLeadNameLabel =>
      _resolve("crmLeadNameLabel", (loc) => loc.crmLeadNameLabel);
  @override
  String get crmLeadCreatedSuccess =>
      _resolve("crmLeadCreatedSuccess", (loc) => loc.crmLeadCreatedSuccess);
  @override
  String get crmLoadErrorTitle =>
      _resolve("crmLoadErrorTitle", (loc) => loc.crmLoadErrorTitle);
  @override
  String get crmEmptyTitle =>
      _resolve("crmEmptyTitle", (loc) => loc.crmEmptyTitle);
  @override
  String get crmEmptyBody =>
      _resolve("crmEmptyBody", (loc) => loc.crmEmptyBody);
  @override
  String get crmFilterAll =>
      _resolve("crmFilterAll", (loc) => loc.crmFilterAll);
  @override
  String get crmStageNew => _resolve("crmStageNew", (loc) => loc.crmStageNew);
  @override
  String get crmStageContacted =>
      _resolve("crmStageContacted", (loc) => loc.crmStageContacted);
  @override
  String get crmStageViewing =>
      _resolve("crmStageViewing", (loc) => loc.crmStageViewing);
  @override
  String get crmStageNegotiation =>
      _resolve("crmStageNegotiation", (loc) => loc.crmStageNegotiation);
  @override
  String get crmStageWon => _resolve("crmStageWon", (loc) => loc.crmStageWon);
  @override
  String get crmStageLost =>
      _resolve("crmStageLost", (loc) => loc.crmStageLost);
  @override
  String get crmStageSectionTitle =>
      _resolve("crmStageSectionTitle", (loc) => loc.crmStageSectionTitle);
  @override
  String crmLeadLastActivity(String when) =>
      _resolve("crmLeadLastActivity", (loc) => loc.crmLeadLastActivity(when));
  @override
  String get crmRelativeToday =>
      _resolve("crmRelativeToday", (loc) => loc.crmRelativeToday);
  @override
  String get crmRelativeYesterday =>
      _resolve("crmRelativeYesterday", (loc) => loc.crmRelativeYesterday);
  @override
  String crmRelativeDaysAgo(int count) =>
      _resolve("crmRelativeDaysAgo", (loc) => loc.crmRelativeDaysAgo(count));
  @override
  String crmDueTodayTitle(int count) =>
      _resolve("crmDueTodayTitle", (loc) => loc.crmDueTodayTitle(count));
  @override
  String get crmRemindersSectionTitle => _resolve(
    "crmRemindersSectionTitle",
    (loc) => loc.crmRemindersSectionTitle,
  );
  @override
  String get crmRemindersEmpty =>
      _resolve("crmRemindersEmpty", (loc) => loc.crmRemindersEmpty);
  @override
  String get crmRemindersPermissionDenied => _resolve(
    "crmRemindersPermissionDenied",
    (loc) => loc.crmRemindersPermissionDenied,
  );
  @override
  String get crmReminderAddAction =>
      _resolve("crmReminderAddAction", (loc) => loc.crmReminderAddAction);
  @override
  String get crmReminderAddTitle =>
      _resolve("crmReminderAddTitle", (loc) => loc.crmReminderAddTitle);
  @override
  String get crmReminderTitleLabel =>
      _resolve("crmReminderTitleLabel", (loc) => loc.crmReminderTitleLabel);
  @override
  String get crmReminderPickTime =>
      _resolve("crmReminderPickTime", (loc) => loc.crmReminderPickTime);
  @override
  String get crmReminderAddedSuccess =>
      _resolve("crmReminderAddedSuccess", (loc) => loc.crmReminderAddedSuccess);
  @override
  String get crmReminderToggleTooltip => _resolve(
    "crmReminderToggleTooltip",
    (loc) => loc.crmReminderToggleTooltip,
  );
  @override
  String get crmReminderDeleteTitle =>
      _resolve("crmReminderDeleteTitle", (loc) => loc.crmReminderDeleteTitle);
  @override
  String get crmReminderDeleteMessage => _resolve(
    "crmReminderDeleteMessage",
    (loc) => loc.crmReminderDeleteMessage,
  );
  @override
  String get crmNotesSectionTitle =>
      _resolve("crmNotesSectionTitle", (loc) => loc.crmNotesSectionTitle);
  @override
  String get crmNoteComposerHint =>
      _resolve("crmNoteComposerHint", (loc) => loc.crmNoteComposerHint);
  @override
  String get crmNoteSendAction =>
      _resolve("crmNoteSendAction", (loc) => loc.crmNoteSendAction);
  @override
  String get crmNoteAddedSuccess =>
      _resolve("crmNoteAddedSuccess", (loc) => loc.crmNoteAddedSuccess);
  @override
  String get crmNoteAddError =>
      _resolve("crmNoteAddError", (loc) => loc.crmNoteAddError);
  @override
  String get crmNoteDeleteTitle =>
      _resolve("crmNoteDeleteTitle", (loc) => loc.crmNoteDeleteTitle);
  @override
  String get crmNoteDeleteMessage =>
      _resolve("crmNoteDeleteMessage", (loc) => loc.crmNoteDeleteMessage);
  @override
  String get crmTimelineSectionTitle =>
      _resolve("crmTimelineSectionTitle", (loc) => loc.crmTimelineSectionTitle);
  @override
  String get crmTimelineEmptyTitle =>
      _resolve("crmTimelineEmptyTitle", (loc) => loc.crmTimelineEmptyTitle);
  @override
  String get crmTimelineInquiry =>
      _resolve("crmTimelineInquiry", (loc) => loc.crmTimelineInquiry);
  @override
  String get crmTimelineMessage =>
      _resolve("crmTimelineMessage", (loc) => loc.crmTimelineMessage);
  @override
  String get crmTimelineViewingRequested => _resolve(
    "crmTimelineViewingRequested",
    (loc) => loc.crmTimelineViewingRequested,
  );
  @override
  String get crmTimelineViewingConfirmed => _resolve(
    "crmTimelineViewingConfirmed",
    (loc) => loc.crmTimelineViewingConfirmed,
  );
  @override
  String get crmTimelineViewingDeclined => _resolve(
    "crmTimelineViewingDeclined",
    (loc) => loc.crmTimelineViewingDeclined,
  );
  @override
  String get crmTimelineViewingCancelled => _resolve(
    "crmTimelineViewingCancelled",
    (loc) => loc.crmTimelineViewingCancelled,
  );
  @override
  String get crmTimelineNote =>
      _resolve("crmTimelineNote", (loc) => loc.crmTimelineNote);
  @override
  String get crmActionChat =>
      _resolve("crmActionChat", (loc) => loc.crmActionChat);
  @override
  String get crmActionCall =>
      _resolve("crmActionCall", (loc) => loc.crmActionCall);
  @override
  String get crmActionWhatsapp =>
      _resolve("crmActionWhatsapp", (loc) => loc.crmActionWhatsapp);
  @override
  String get crmActionLaunchFailed =>
      _resolve("crmActionLaunchFailed", (loc) => loc.crmActionLaunchFailed);
  @override
  String get crmChatUnavailable =>
      _resolve("crmChatUnavailable", (loc) => loc.crmChatUnavailable);
  @override
  String get crmDeleteAction =>
      _resolve("crmDeleteAction", (loc) => loc.crmDeleteAction);
  @override
  String get crmAddToCrmAction =>
      _resolve("crmAddToCrmAction", (loc) => loc.crmAddToCrmAction);
  @override
  String get crmAddedToCrmSuccess =>
      _resolve("crmAddedToCrmSuccess", (loc) => loc.crmAddedToCrmSuccess);
  @override
  String get crmAddToCrmError =>
      _resolve("crmAddToCrmError", (loc) => loc.crmAddToCrmError);
  @override
  String get crmViewAction =>
      _resolve("crmViewAction", (loc) => loc.crmViewAction);
  @override
  String get adminAnalyticsTitle =>
      _resolve("adminAnalyticsTitle", (loc) => loc.adminAnalyticsTitle);
  @override
  String get adminAnalyticsTileTitle =>
      _resolve("adminAnalyticsTileTitle", (loc) => loc.adminAnalyticsTileTitle);
  @override
  String get adminAnalyticsTileSubtitle => _resolve(
    "adminAnalyticsTileSubtitle",
    (loc) => loc.adminAnalyticsTileSubtitle,
  );
  @override
  String get adminAnalyticsListingsByMonthTitle => _resolve(
    "adminAnalyticsListingsByMonthTitle",
    (loc) => loc.adminAnalyticsListingsByMonthTitle,
  );
  @override
  String get adminAnalyticsUsersByMonthTitle => _resolve(
    "adminAnalyticsUsersByMonthTitle",
    (loc) => loc.adminAnalyticsUsersByMonthTitle,
  );
  @override
  String get adminAnalyticsLeadEventsByDayTitle => _resolve(
    "adminAnalyticsLeadEventsByDayTitle",
    (loc) => loc.adminAnalyticsLeadEventsByDayTitle,
  );
  @override
  String get adminAnalyticsListingsByGovernorateTitle => _resolve(
    "adminAnalyticsListingsByGovernorateTitle",
    (loc) => loc.adminAnalyticsListingsByGovernorateTitle,
  );
  @override
  String get adminAnalyticsEmptyHint =>
      _resolve("adminAnalyticsEmptyHint", (loc) => loc.adminAnalyticsEmptyHint);
  @override
  String get adminAnalyticsError =>
      _resolve("adminAnalyticsError", (loc) => loc.adminAnalyticsError);
  @override
  String get adminAnalyticsEvolutionTitle => _resolve(
    "adminAnalyticsEvolutionTitle",
    (loc) => loc.adminAnalyticsEvolutionTitle,
  );
  @override
  String get adminAnalyticsSeriesListings => _resolve(
    "adminAnalyticsSeriesListings",
    (loc) => loc.adminAnalyticsSeriesListings,
  );
  @override
  String get adminAnalyticsSeriesUsers => _resolve(
    "adminAnalyticsSeriesUsers",
    (loc) => loc.adminAnalyticsSeriesUsers,
  );
  @override
  String get adminAnalyticsKpiListingsMonth => _resolve(
    "adminAnalyticsKpiListingsMonth",
    (loc) => loc.adminAnalyticsKpiListingsMonth,
  );
  @override
  String get adminAnalyticsKpiNewUsers => _resolve(
    "adminAnalyticsKpiNewUsers",
    (loc) => loc.adminAnalyticsKpiNewUsers,
  );
  @override
  String get adminAnalyticsKpiLeads30d => _resolve(
    "adminAnalyticsKpiLeads30d",
    (loc) => loc.adminAnalyticsKpiLeads30d,
  );
  @override
  String get adminAnalyticsKpiActiveListings => _resolve(
    "adminAnalyticsKpiActiveListings",
    (loc) => loc.adminAnalyticsKpiActiveListings,
  );
  @override
  String get adminAnalyticsEngineLabel => _resolve(
    "adminAnalyticsEngineLabel",
    (loc) => loc.adminAnalyticsEngineLabel,
  );
  @override
  String get adminAnalyticsEngineNative => _resolve(
    "adminAnalyticsEngineNative",
    (loc) => loc.adminAnalyticsEngineNative,
  );
  @override
  String get adminAnalyticsEngineFlChart => _resolve(
    "adminAnalyticsEngineFlChart",
    (loc) => loc.adminAnalyticsEngineFlChart,
  );
  @override
  String get publisherChartsSectionLabel => _resolve(
    "publisherChartsSectionLabel",
    (loc) => loc.publisherChartsSectionLabel,
  );
  @override
  String get publisherChartsLeadsByDayTitle => _resolve(
    "publisherChartsLeadsByDayTitle",
    (loc) => loc.publisherChartsLeadsByDayTitle,
  );
  @override
  String get publisherChartsInquiriesByDayTitle => _resolve(
    "publisherChartsInquiriesByDayTitle",
    (loc) => loc.publisherChartsInquiriesByDayTitle,
  );
  @override
  String get publisherChartsViewingsByStatusTitle => _resolve(
    "publisherChartsViewingsByStatusTitle",
    (loc) => loc.publisherChartsViewingsByStatusTitle,
  );
  @override
  String get publisherChartsListingsByStatusTitle => _resolve(
    "publisherChartsListingsByStatusTitle",
    (loc) => loc.publisherChartsListingsByStatusTitle,
  );
  @override
  String get publisherChartsEmptyHint => _resolve(
    "publisherChartsEmptyHint",
    (loc) => loc.publisherChartsEmptyHint,
  );
  @override
  String get publisherChartsStatusActive => _resolve(
    "publisherChartsStatusActive",
    (loc) => loc.publisherChartsStatusActive,
  );
  @override
  String get publisherChartsStatusPending => _resolve(
    "publisherChartsStatusPending",
    (loc) => loc.publisherChartsStatusPending,
  );
  @override
  String get publisherChartsStatusRejected => _resolve(
    "publisherChartsStatusRejected",
    (loc) => loc.publisherChartsStatusRejected,
  );
  @override
  String get publisherChartsViewingRequested => _resolve(
    "publisherChartsViewingRequested",
    (loc) => loc.publisherChartsViewingRequested,
  );
  @override
  String get publisherChartsViewingConfirmed => _resolve(
    "publisherChartsViewingConfirmed",
    (loc) => loc.publisherChartsViewingConfirmed,
  );
  @override
  String get publisherChartsViewingDeclined => _resolve(
    "publisherChartsViewingDeclined",
    (loc) => loc.publisherChartsViewingDeclined,
  );
  @override
  String get publisherChartsViewingCancelled => _resolve(
    "publisherChartsViewingCancelled",
    (loc) => loc.publisherChartsViewingCancelled,
  );
  @override
  String get dashCrmTileTitle =>
      _resolve("dashCrmTileTitle", (loc) => loc.dashCrmTileTitle);
  @override
  String get dashCrmTileSubtitle =>
      _resolve("dashCrmTileSubtitle", (loc) => loc.dashCrmTileSubtitle);
  @override
  String get mediaAddPanorama =>
      _resolve("mediaAddPanorama", (loc) => loc.mediaAddPanorama);
  @override
  String mediaTipsPhotoCount(int count) =>
      _resolve("mediaTipsPhotoCount", (loc) => loc.mediaTipsPhotoCount(count));
  @override
  String get mediaTipsLightingHint =>
      _resolve("mediaTipsLightingHint", (loc) => loc.mediaTipsLightingHint);
  @override
  String get mediaActionMarkExistingPanorama => _resolve(
    "mediaActionMarkExistingPanorama",
    (loc) => loc.mediaActionMarkExistingPanorama,
  );
  @override
  String get mediaActionUnmarkExistingPanorama => _resolve(
    "mediaActionUnmarkExistingPanorama",
    (loc) => loc.mediaActionUnmarkExistingPanorama,
  );
  @override
  String get mediaCapPanoramas2 =>
      _resolve("mediaCapPanoramas2", (loc) => loc.mediaCapPanoramas2);
  @override
  String get mediaErrorNotEquirectangular => _resolve(
    "mediaErrorNotEquirectangular",
    (loc) => loc.mediaErrorNotEquirectangular,
  );
  @override
  String get mediaPanoramaHelpTitle =>
      _resolve("mediaPanoramaHelpTitle", (loc) => loc.mediaPanoramaHelpTitle);
  @override
  String get mediaPanoramaHelpIntro =>
      _resolve("mediaPanoramaHelpIntro", (loc) => loc.mediaPanoramaHelpIntro);
  @override
  String get mediaPanoramaHelpStep1 =>
      _resolve("mediaPanoramaHelpStep1", (loc) => loc.mediaPanoramaHelpStep1);
  @override
  String get mediaPanoramaHelpStep2 =>
      _resolve("mediaPanoramaHelpStep2", (loc) => loc.mediaPanoramaHelpStep2);
  @override
  String get mediaPanoramaHelpStep3 =>
      _resolve("mediaPanoramaHelpStep3", (loc) => loc.mediaPanoramaHelpStep3);
  @override
  String get mediaPanoramaHelpGetApp =>
      _resolve("mediaPanoramaHelpGetApp", (loc) => loc.mediaPanoramaHelpGetApp);
  @override
  String get listingFormPreviewHeading => _resolve(
    "listingFormPreviewHeading",
    (loc) => loc.listingFormPreviewHeading,
  );
  @override
  String get listingFormPreviewTitlePlaceholder => _resolve(
    "listingFormPreviewTitlePlaceholder",
    (loc) => loc.listingFormPreviewTitlePlaceholder,
  );
  @override
  String get listingFormPreviewPricePlaceholder => _resolve(
    "listingFormPreviewPricePlaceholder",
    (loc) => loc.listingFormPreviewPricePlaceholder,
  );
  @override
  String get listingFormPreviewLocationPlaceholder => _resolve(
    "listingFormPreviewLocationPlaceholder",
    (loc) => loc.listingFormPreviewLocationPlaceholder,
  );
  @override
  String get listingFormPreviewFeaturedLabel => _resolve(
    "listingFormPreviewFeaturedLabel",
    (loc) => loc.listingFormPreviewFeaturedLabel,
  );
  @override
  String get listingFormChecklistTitle => _resolve(
    "listingFormChecklistTitle",
    (loc) => loc.listingFormChecklistTitle,
  );
  @override
  String get listingFormChecklistAllComplete => _resolve(
    "listingFormChecklistAllComplete",
    (loc) => loc.listingFormChecklistAllComplete,
  );
  @override
  String listingFormChecklistMissingSubtitle(int count) => _resolve(
    "listingFormChecklistMissingSubtitle",
    (loc) => loc.listingFormChecklistMissingSubtitle(count),
  );
  @override
  String get listingFormChecklistPhoneOrWhatsapp => _resolve(
    "listingFormChecklistPhoneOrWhatsapp",
    (loc) => loc.listingFormChecklistPhoneOrWhatsapp,
  );
  @override
  String get listingFormChecklistGenericMissing => _resolve(
    "listingFormChecklistGenericMissing",
    (loc) => loc.listingFormChecklistGenericMissing,
  );
  @override
  String get listingFormChecklistFix =>
      _resolve("listingFormChecklistFix", (loc) => loc.listingFormChecklistFix);
  @override
  String get reels_section_title =>
      _resolve("reels_section_title", (loc) => loc.reels_section_title);
  @override
  String get reels_see_all =>
      _resolve("reels_see_all", (loc) => loc.reels_see_all);
  @override
  String get reels_view_listing =>
      _resolve("reels_view_listing", (loc) => loc.reels_view_listing);
  @override
  String get reels_empty_headline =>
      _resolve("reels_empty_headline", (loc) => loc.reels_empty_headline);
  @override
  String get reels_load_error =>
      _resolve("reels_load_error", (loc) => loc.reels_load_error);
  @override
  String get reels_lite_confirm_title => _resolve(
    "reels_lite_confirm_title",
    (loc) => loc.reels_lite_confirm_title,
  );
  @override
  String get reels_lite_confirm_message => _resolve(
    "reels_lite_confirm_message",
    (loc) => loc.reels_lite_confirm_message,
  );
  @override
  String get reels_lite_confirm_action => _resolve(
    "reels_lite_confirm_action",
    (loc) => loc.reels_lite_confirm_action,
  );
  @override
  String get locationCentroidLabel =>
      _resolve("locationCentroidLabel", (loc) => loc.locationCentroidLabel);
  @override
  String get locationCentroidHelper =>
      _resolve("locationCentroidHelper", (loc) => loc.locationCentroidHelper);
  @override
  String get locationCentroidLatLabel => _resolve(
    "locationCentroidLatLabel",
    (loc) => loc.locationCentroidLatLabel,
  );
  @override
  String get locationCentroidLngLabel => _resolve(
    "locationCentroidLngLabel",
    (loc) => loc.locationCentroidLngLabel,
  );
  @override
  String get locationCentroidRequired => _resolve(
    "locationCentroidRequired",
    (loc) => loc.locationCentroidRequired,
  );
  @override
  String get locationCentroidOutOfBounds => _resolve(
    "locationCentroidOutOfBounds",
    (loc) => loc.locationCentroidOutOfBounds,
  );
  @override
  String get videoCompressing =>
      _resolve("videoCompressing", (loc) => loc.videoCompressing);
  @override
  String get crmViewInCrm =>
      _resolve("crmViewInCrm", (loc) => loc.crmViewInCrm);
  @override
  String get nav_reels => _resolve("nav_reels", (loc) => loc.nav_reels);
  @override
  String get reels_tab_empty_subtitle => _resolve(
    "reels_tab_empty_subtitle",
    (loc) => loc.reels_tab_empty_subtitle,
  );
  @override
  String get navDrawerMenuTooltip =>
      _resolve("navDrawerMenuTooltip", (loc) => loc.navDrawerMenuTooltip);
  @override
  String get navDrawerSignInCta =>
      _resolve("navDrawerSignInCta", (loc) => loc.navDrawerSignInCta);
  @override
  String get navDrawerSignInSubtitle =>
      _resolve("navDrawerSignInSubtitle", (loc) => loc.navDrawerSignInSubtitle);
  @override
  String get navDrawerAbout =>
      _resolve("navDrawerAbout", (loc) => loc.navDrawerAbout);
  @override
  String get createToggleDetailView =>
      _resolve("createToggleDetailView", (loc) => loc.createToggleDetailView);
  @override
  String get createToggleClassicSteps => _resolve(
    "createToggleClassicSteps",
    (loc) => loc.createToggleClassicSteps,
  );
  @override
  String get createToggleExpress =>
      _resolve("createToggleExpress", (loc) => loc.createToggleExpress);
  @override
  String get createExitTitle =>
      _resolve("createExitTitle", (loc) => loc.createExitTitle);
  @override
  String get createExitBody =>
      _resolve("createExitBody", (loc) => loc.createExitBody);
  @override
  String get createExitLeave =>
      _resolve("createExitLeave", (loc) => loc.createExitLeave);
  @override
  String get createExpressHint =>
      _resolve("createExpressHint", (loc) => loc.createExpressHint);
  @override
  String get formDetailPageTitle =>
      _resolve("formDetailPageTitle", (loc) => loc.formDetailPageTitle);
  @override
  String get formDetailPreviewHint =>
      _resolve("formDetailPreviewHint", (loc) => loc.formDetailPreviewHint);
  @override
  String get formDetailSubmitButton =>
      _resolve("formDetailSubmitButton", (loc) => loc.formDetailSubmitButton);
  @override
  String get formDetailTitleSectionTitle => _resolve(
    "formDetailTitleSectionTitle",
    (loc) => loc.formDetailTitleSectionTitle,
  );
  @override
  String get formDetailTitleSectionSubtitle => _resolve(
    "formDetailTitleSectionSubtitle",
    (loc) => loc.formDetailTitleSectionSubtitle,
  );
  @override
  String get formDetailClassificationSectionTitle => _resolve(
    "formDetailClassificationSectionTitle",
    (loc) => loc.formDetailClassificationSectionTitle,
  );
  @override
  String get formDetailClassificationSectionSubtitle => _resolve(
    "formDetailClassificationSectionSubtitle",
    (loc) => loc.formDetailClassificationSectionSubtitle,
  );
  @override
  String get formDetailPriceSectionTitle => _resolve(
    "formDetailPriceSectionTitle",
    (loc) => loc.formDetailPriceSectionTitle,
  );
  @override
  String get formDetailPriceSectionSubtitle => _resolve(
    "formDetailPriceSectionSubtitle",
    (loc) => loc.formDetailPriceSectionSubtitle,
  );
  @override
  String get formDetailLocationSectionTitle => _resolve(
    "formDetailLocationSectionTitle",
    (loc) => loc.formDetailLocationSectionTitle,
  );
  @override
  String get formDetailLocationSectionSubtitle => _resolve(
    "formDetailLocationSectionSubtitle",
    (loc) => loc.formDetailLocationSectionSubtitle,
  );
  @override
  String get formDetailFactsSectionTitle => _resolve(
    "formDetailFactsSectionTitle",
    (loc) => loc.formDetailFactsSectionTitle,
  );
  @override
  String get formDetailFactsSectionSubtitle => _resolve(
    "formDetailFactsSectionSubtitle",
    (loc) => loc.formDetailFactsSectionSubtitle,
  );
  @override
  String get formDetailAmenitiesSectionTitle => _resolve(
    "formDetailAmenitiesSectionTitle",
    (loc) => loc.formDetailAmenitiesSectionTitle,
  );
  @override
  String get formDetailAmenitiesSectionSubtitle => _resolve(
    "formDetailAmenitiesSectionSubtitle",
    (loc) => loc.formDetailAmenitiesSectionSubtitle,
  );
  @override
  String get formDetailDescriptionSectionTitle => _resolve(
    "formDetailDescriptionSectionTitle",
    (loc) => loc.formDetailDescriptionSectionTitle,
  );
  @override
  String get formDetailDescriptionSectionSubtitle => _resolve(
    "formDetailDescriptionSectionSubtitle",
    (loc) => loc.formDetailDescriptionSectionSubtitle,
  );
  @override
  String get formDetailContactSectionTitle => _resolve(
    "formDetailContactSectionTitle",
    (loc) => loc.formDetailContactSectionTitle,
  );
  @override
  String get formDetailContactSectionSubtitle => _resolve(
    "formDetailContactSectionSubtitle",
    (loc) => loc.formDetailContactSectionSubtitle,
  );
  @override
  String get revisionBannerTitle =>
      _resolve("revisionBannerTitle", (loc) => loc.revisionBannerTitle);
  @override
  String get revisionBannerBody =>
      _resolve("revisionBannerBody", (loc) => loc.revisionBannerBody);
  @override
  String get revisionStatusTitle =>
      _resolve("revisionStatusTitle", (loc) => loc.revisionStatusTitle);
  @override
  String get revisionStatusProposedChanges => _resolve(
    "revisionStatusProposedChanges",
    (loc) => loc.revisionStatusProposedChanges,
  );
  @override
  String get revisionStatusAwaitingReview => _resolve(
    "revisionStatusAwaitingReview",
    (loc) => loc.revisionStatusAwaitingReview,
  );
  @override
  String get revisionStatusContinueEditing => _resolve(
    "revisionStatusContinueEditing",
    (loc) => loc.revisionStatusContinueEditing,
  );
  @override
  String get revisionStatusNoChanges =>
      _resolve("revisionStatusNoChanges", (loc) => loc.revisionStatusNoChanges);
  @override
  String get revisionStatusNoFieldChanges => _resolve(
    "revisionStatusNoFieldChanges",
    (loc) => loc.revisionStatusNoFieldChanges,
  );
  @override
  String get revisionStatusError =>
      _resolve("revisionStatusError", (loc) => loc.revisionStatusError);
  @override
  String get revisionStatusWithdraw =>
      _resolve("revisionStatusWithdraw", (loc) => loc.revisionStatusWithdraw);
  @override
  String get revisionStatusWithdrawConfirmTitle => _resolve(
    "revisionStatusWithdrawConfirmTitle",
    (loc) => loc.revisionStatusWithdrawConfirmTitle,
  );
  @override
  String get revisionStatusWithdrawConfirmBody => _resolve(
    "revisionStatusWithdrawConfirmBody",
    (loc) => loc.revisionStatusWithdrawConfirmBody,
  );
  @override
  String get revisionStatusWithdrawConfirmCta => _resolve(
    "revisionStatusWithdrawConfirmCta",
    (loc) => loc.revisionStatusWithdrawConfirmCta,
  );
  @override
  String get revisionStatusWithdrawSuccess => _resolve(
    "revisionStatusWithdrawSuccess",
    (loc) => loc.revisionStatusWithdrawSuccess,
  );
  @override
  String get revisionStatusWithdrawError => _resolve(
    "revisionStatusWithdrawError",
    (loc) => loc.revisionStatusWithdrawError,
  );
  @override
  String get revisionStartFailedMessage => _resolve(
    "revisionStartFailedMessage",
    (loc) => loc.revisionStartFailedMessage,
  );
  @override
  String get myListingsEditNeedsApproval => _resolve(
    "myListingsEditNeedsApproval",
    (loc) => loc.myListingsEditNeedsApproval,
  );
  @override
  String get myListingsEditInReviewBadge => _resolve(
    "myListingsEditInReviewBadge",
    (loc) => loc.myListingsEditInReviewBadge,
  );
  @override
  String get adminRevisionsSectionTitle => _resolve(
    "adminRevisionsSectionTitle",
    (loc) => loc.adminRevisionsSectionTitle,
  );
  @override
  String get adminRevisionPendingSubtitle => _resolve(
    "adminRevisionPendingSubtitle",
    (loc) => loc.adminRevisionPendingSubtitle,
  );
  @override
  String get adminRevisionReviewTitle => _resolve(
    "adminRevisionReviewTitle",
    (loc) => loc.adminRevisionReviewTitle,
  );
  @override
  String get adminRevisionApprovedToast => _resolve(
    "adminRevisionApprovedToast",
    (loc) => loc.adminRevisionApprovedToast,
  );
  @override
  String get adminRevisionRejectedToast => _resolve(
    "adminRevisionRejectedToast",
    (loc) => loc.adminRevisionRejectedToast,
  );
  @override
  String get adminRevisionProposedMediaLabel => _resolve(
    "adminRevisionProposedMediaLabel",
    (loc) => loc.adminRevisionProposedMediaLabel,
  );
  @override
  String get adminRevisionChangesLabel => _resolve(
    "adminRevisionChangesLabel",
    (loc) => loc.adminRevisionChangesLabel,
  );
  @override
  String get adminRevisionNoFieldChanges => _resolve(
    "adminRevisionNoFieldChanges",
    (loc) => loc.adminRevisionNoFieldChanges,
  );
  @override
  String get adminRevisionApproveCta =>
      _resolve("adminRevisionApproveCta", (loc) => loc.adminRevisionApproveCta);
  @override
  String get adminRevisionFieldPrice =>
      _resolve("adminRevisionFieldPrice", (loc) => loc.adminRevisionFieldPrice);
  @override
  String get adminRevisionFieldCurrency => _resolve(
    "adminRevisionFieldCurrency",
    (loc) => loc.adminRevisionFieldCurrency,
  );
  @override
  String get adminRevisionFieldAddress => _resolve(
    "adminRevisionFieldAddress",
    (loc) => loc.adminRevisionFieldAddress,
  );
  @override
  String get adminRevisionFieldAreaSize => _resolve(
    "adminRevisionFieldAreaSize",
    (loc) => loc.adminRevisionFieldAreaSize,
  );
  @override
  String get adminRevisionFieldRooms =>
      _resolve("adminRevisionFieldRooms", (loc) => loc.adminRevisionFieldRooms);
  @override
  String get adminRevisionFieldBathrooms => _resolve(
    "adminRevisionFieldBathrooms",
    (loc) => loc.adminRevisionFieldBathrooms,
  );
  @override
  String get adminRevisionFieldFloor =>
      _resolve("adminRevisionFieldFloor", (loc) => loc.adminRevisionFieldFloor);
  @override
  String get adminRevisionFieldDescription => _resolve(
    "adminRevisionFieldDescription",
    (loc) => loc.adminRevisionFieldDescription,
  );
  @override
  String get adminRevisionFieldAmenities => _resolve(
    "adminRevisionFieldAmenities",
    (loc) => loc.adminRevisionFieldAmenities,
  );
  @override
  String get adminRevisionFieldYearBuilt => _resolve(
    "adminRevisionFieldYearBuilt",
    (loc) => loc.adminRevisionFieldYearBuilt,
  );
  @override
  String get adminRevisionFieldFurnished => _resolve(
    "adminRevisionFieldFurnished",
    (loc) => loc.adminRevisionFieldFurnished,
  );
  @override
  String get adminRevisionFieldParking => _resolve(
    "adminRevisionFieldParking",
    (loc) => loc.adminRevisionFieldParking,
  );
  @override
  String get adminRevisionFieldPhone =>
      _resolve("adminRevisionFieldPhone", (loc) => loc.adminRevisionFieldPhone);
  @override
  String get adminRevisionFieldWhatsapp => _resolve(
    "adminRevisionFieldWhatsapp",
    (loc) => loc.adminRevisionFieldWhatsapp,
  );
  @override
  String get adminRevisionFieldLocation => _resolve(
    "adminRevisionFieldLocation",
    (loc) => loc.adminRevisionFieldLocation,
  );
  @override
  String get adminRevisionFieldLocationVisibility => _resolve(
    "adminRevisionFieldLocationVisibility",
    (loc) => loc.adminRevisionFieldLocationVisibility,
  );
  @override
  String get adminRevisionFieldContactVisibility => _resolve(
    "adminRevisionFieldContactVisibility",
    (loc) => loc.adminRevisionFieldContactVisibility,
  );

  @override
  String get search_error_title =>
      _resolve('search_error_title', (loc) => loc.search_error_title);
  @override
  String get map_marker_semantics_label => _resolve(
    'map_marker_semantics_label',
    (loc) => loc.map_marker_semantics_label,
  );
  @override
  String get map_loading_label =>
      _resolve('map_loading_label', (loc) => loc.map_loading_label);
  @override
  String get chatMessageSent =>
      _resolve('chatMessageSent', (loc) => loc.chatMessageSent);
  @override
  String get chatMessageRead =>
      _resolve('chatMessageRead', (loc) => loc.chatMessageRead);
  @override
  String get profileLoadErrorTitle =>
      _resolve('profileLoadErrorTitle', (loc) => loc.profileLoadErrorTitle);
  @override
  String get profilePrivateSecurityNote => _resolve(
    'profilePrivateSecurityNote',
    (loc) => loc.profilePrivateSecurityNote,
  );
  @override
  String get reels_mute_toggle =>
      _resolve('reels_mute_toggle', (loc) => loc.reels_mute_toggle);
  @override
  String get reels_close => _resolve('reels_close', (loc) => loc.reels_close);
  @override
  String get onboarding_next =>
      _resolve('onboarding_next', (loc) => loc.onboarding_next);
  @override
  String get password_show =>
      _resolve('password_show', (loc) => loc.password_show);
  @override
  String get password_hide =>
      _resolve('password_hide', (loc) => loc.password_hide);
  @override
  String get mediaEmptyStateTitle =>
      _resolve('mediaEmptyStateTitle', (loc) => loc.mediaEmptyStateTitle);
  @override
  String get mediaEmptyStateHint =>
      _resolve('mediaEmptyStateHint', (loc) => loc.mediaEmptyStateHint);
  @override
  String get myListingsEmptyBody =>
      _resolve('myListingsEmptyBody', (loc) => loc.myListingsEmptyBody);
  @override
  String get myListingsFilteredEmptyTitle => _resolve(
    'myListingsFilteredEmptyTitle',
    (loc) => loc.myListingsFilteredEmptyTitle,
  );
  @override
  String get myListingsFilteredEmptyShowAll => _resolve(
    'myListingsFilteredEmptyShowAll',
    (loc) => loc.myListingsFilteredEmptyShowAll,
  );
  @override
  String get myListingsUntitledListing => _resolve(
    'myListingsUntitledListing',
    (loc) => loc.myListingsUntitledListing,
  );
  @override
  String get comparisonEmptyTitle =>
      _resolve('comparisonEmptyTitle', (loc) => loc.comparisonEmptyTitle);
  @override
  String get comparisonMaxReached =>
      _resolve('comparisonMaxReached', (loc) => loc.comparisonMaxReached);
  @override
  String get notification_unread_a11y => _resolve(
    'notification_unread_a11y',
    (loc) => loc.notification_unread_a11y,
  );
  @override
  String notification_unread_count_a11y(int count) => _resolve(
    'notification_unread_count_a11y',
    (loc) => loc.notification_unread_count_a11y(count),
  );
  @override
  String get notification_date_today =>
      _resolve('notification_date_today', (loc) => loc.notification_date_today);
  @override
  String get notification_date_yesterday => _resolve(
    'notification_date_yesterday',
    (loc) => loc.notification_date_yesterday,
  );
  @override
  String get notification_empty_state_body => _resolve(
    'notification_empty_state_body',
    (loc) => loc.notification_empty_state_body,
  );
  @override
  String get assistantTyping =>
      _resolve('assistantTyping', (loc) => loc.assistantTyping);
  @override
  String get assistantTrySuggestions =>
      _resolve('assistantTrySuggestions', (loc) => loc.assistantTrySuggestions);
  @override
  String get about_empty_title =>
      _resolve('about_empty_title', (loc) => loc.about_empty_title);
  @override
  String get report_sheet_subtitle =>
      _resolve('report_sheet_subtitle', (loc) => loc.report_sheet_subtitle);
  @override
  String get report_banner_status_label => _resolve(
    'report_banner_status_label',
    (loc) => loc.report_banner_status_label,
  );
  @override
  String get settings_title =>
      _resolve('settings_title', (loc) => loc.settings_title);
  @override
  String get settings_appearance_heading => _resolve(
    'settings_appearance_heading',
    (loc) => loc.settings_appearance_heading,
  );
  @override
  String get settings_theme_light =>
      _resolve('settings_theme_light', (loc) => loc.settings_theme_light);
  @override
  String get settings_theme_dark =>
      _resolve('settings_theme_dark', (loc) => loc.settings_theme_dark);
  @override
  String get settings_theme_auto =>
      _resolve('settings_theme_auto', (loc) => loc.settings_theme_auto);
  @override
  String get settings_general_heading => _resolve(
    'settings_general_heading',
    (loc) => loc.settings_general_heading,
  );
  @override
  String get settings_language_label =>
      _resolve('settings_language_label', (loc) => loc.settings_language_label);
  @override
  String get settings_language_arabic => _resolve(
    'settings_language_arabic',
    (loc) => loc.settings_language_arabic,
  );
  @override
  String get settings_language_english => _resolve(
    'settings_language_english',
    (loc) => loc.settings_language_english,
  );
  @override
  String get settings_language_sheet_title => _resolve(
    'settings_language_sheet_title',
    (loc) => loc.settings_language_sheet_title,
  );
  @override
  String get settings_currency_label =>
      _resolve('settings_currency_label', (loc) => loc.settings_currency_label);
  @override
  String get settings_notifications_heading => _resolve(
    'settings_notifications_heading',
    (loc) => loc.settings_notifications_heading,
  );
  @override
  String get settings_notif_new_matches => _resolve(
    'settings_notif_new_matches',
    (loc) => loc.settings_notif_new_matches,
  );
  @override
  String get settings_notif_messages =>
      _resolve('settings_notif_messages', (loc) => loc.settings_notif_messages);
  @override
  String get settings_notif_marketing => _resolve(
    'settings_notif_marketing',
    (loc) => loc.settings_notif_marketing,
  );
  @override
  String get settings_about_heading =>
      _resolve('settings_about_heading', (loc) => loc.settings_about_heading);
  @override
  String get settings_about_row =>
      _resolve('settings_about_row', (loc) => loc.settings_about_row);
  @override
  String get settings_rate_app =>
      _resolve('settings_rate_app', (loc) => loc.settings_rate_app);
  @override
  String settings_version(String version) =>
      _resolve('settings_version', (loc) => loc.settings_version(version));
  @override
  String get home_city_picker_title =>
      _resolve('home_city_picker_title', (loc) => loc.home_city_picker_title);
  @override
  String get home_city_picker_error =>
      _resolve('home_city_picker_error', (loc) => loc.home_city_picker_error);
  @override
  String get leadAnalyticsBySourceSectionLabel => _resolve(
    'leadAnalyticsBySourceSectionLabel',
    (loc) => loc.leadAnalyticsBySourceSectionLabel,
  );
  @override
  String get adminAnalyticsByCategoryTitle => _resolve(
    'adminAnalyticsByCategoryTitle',
    (loc) => loc.adminAnalyticsByCategoryTitle,
  );
  @override
  String get adminAnalyticsByCategoryCenterLabel => _resolve(
    'adminAnalyticsByCategoryCenterLabel',
    (loc) => loc.adminAnalyticsByCategoryCenterLabel,
  );
  @override
  String get adminAnalyticsActivityTitle => _resolve(
    'adminAnalyticsActivityTitle',
    (loc) => loc.adminAnalyticsActivityTitle,
  );
  @override
  String get settings_account_heading => _resolve(
    'settings_account_heading',
    (loc) => loc.settings_account_heading,
  );
  @override
  String get accountDeleteEntryTitle =>
      _resolve('accountDeleteEntryTitle', (loc) => loc.accountDeleteEntryTitle);
  @override
  String get accountDeleteEntrySubtitle => _resolve(
    'accountDeleteEntrySubtitle',
    (loc) => loc.accountDeleteEntrySubtitle,
  );
  @override
  String get accountDeletePageTitle =>
      _resolve('accountDeletePageTitle', (loc) => loc.accountDeletePageTitle);
  @override
  String get accountDeleteWarningTitle => _resolve(
    'accountDeleteWarningTitle',
    (loc) => loc.accountDeleteWarningTitle,
  );
  @override
  String get accountDeleteHeadline =>
      _resolve('accountDeleteHeadline', (loc) => loc.accountDeleteHeadline);
  @override
  String get accountDeleteIntro =>
      _resolve('accountDeleteIntro', (loc) => loc.accountDeleteIntro);
  @override
  String get accountDeleteWarningBody => _resolve(
    'accountDeleteWarningBody',
    (loc) => loc.accountDeleteWarningBody,
  );
  @override
  String get accountDeleteWhatGoesTitle => _resolve(
    'accountDeleteWhatGoesTitle',
    (loc) => loc.accountDeleteWhatGoesTitle,
  );
  @override
  String get accountDeleteItemProfile => _resolve(
    'accountDeleteItemProfile',
    (loc) => loc.accountDeleteItemProfile,
  );
  @override
  String get accountDeleteItemListings => _resolve(
    'accountDeleteItemListings',
    (loc) => loc.accountDeleteItemListings,
  );
  @override
  String get accountDeleteItemMessages => _resolve(
    'accountDeleteItemMessages',
    (loc) => loc.accountDeleteItemMessages,
  );
  @override
  String get accountDeleteItemCrm =>
      _resolve('accountDeleteItemCrm', (loc) => loc.accountDeleteItemCrm);
  @override
  String get accountDeleteKeepsTitle =>
      _resolve('accountDeleteKeepsTitle', (loc) => loc.accountDeleteKeepsTitle);
  @override
  String get accountDeleteKeepsBody =>
      _resolve('accountDeleteKeepsBody', (loc) => loc.accountDeleteKeepsBody);
  @override
  String get accountDeleteAcknowledge => _resolve(
    'accountDeleteAcknowledge',
    (loc) => loc.accountDeleteAcknowledge,
  );
  @override
  String get accountDeleteConfirmButton => _resolve(
    'accountDeleteConfirmButton',
    (loc) => loc.accountDeleteConfirmButton,
  );
  @override
  String get accountDeleteCancelButton => _resolve(
    'accountDeleteCancelButton',
    (loc) => loc.accountDeleteCancelButton,
  );
  @override
  String get accountDeleteDialogTitle => _resolve(
    'accountDeleteDialogTitle',
    (loc) => loc.accountDeleteDialogTitle,
  );
  @override
  String get accountDeleteDialogMessage => _resolve(
    'accountDeleteDialogMessage',
    (loc) => loc.accountDeleteDialogMessage,
  );
  @override
  String get accountDeleteDialogConfirm => _resolve(
    'accountDeleteDialogConfirm',
    (loc) => loc.accountDeleteDialogConfirm,
  );
  @override
  String get accountDeleteSuccessToast => _resolve(
    'accountDeleteSuccessToast',
    (loc) => loc.accountDeleteSuccessToast,
  );
  @override
  String get accountDeleteErrorGeneric => _resolve(
    'accountDeleteErrorGeneric',
    (loc) => loc.accountDeleteErrorGeneric,
  );
  @override
  String get accountDeleteErrorNotSignedIn => _resolve(
    'accountDeleteErrorNotSignedIn',
    (loc) => loc.accountDeleteErrorNotSignedIn,
  );
  @override
  String get guest_gate_title => _resolve(
    'guest_gate_title',
    (loc) => loc.guest_gate_title,
  );
  @override
  String get guest_gate_reason_favorites => _resolve(
    'guest_gate_reason_favorites',
    (loc) => loc.guest_gate_reason_favorites,
  );
  @override
  String get guest_gate_reason_messages => _resolve(
    'guest_gate_reason_messages',
    (loc) => loc.guest_gate_reason_messages,
  );
  @override
  String get guest_gate_reason_profile => _resolve(
    'guest_gate_reason_profile',
    (loc) => loc.guest_gate_reason_profile,
  );
  @override
  String get guest_gate_reason_notifications => _resolve(
    'guest_gate_reason_notifications',
    (loc) => loc.guest_gate_reason_notifications,
  );
  @override
  String get guest_gate_reason_publish => _resolve(
    'guest_gate_reason_publish',
    (loc) => loc.guest_gate_reason_publish,
  );
  @override
  String get guest_gate_sign_in => _resolve(
    'guest_gate_sign_in',
    (loc) => loc.guest_gate_sign_in,
  );
  @override
  String get guest_gate_register => _resolve(
    'guest_gate_register',
    (loc) => loc.guest_gate_register,
  );
  @override
  String get guest_gate_keep_browsing => _resolve(
    'guest_gate_keep_browsing',
    (loc) => loc.guest_gate_keep_browsing,
  );
  @override
  String get home_empty_get_approved_to_publish => _resolve(
    'home_empty_get_approved_to_publish',
    (loc) => loc.home_empty_get_approved_to_publish,
  );
}
