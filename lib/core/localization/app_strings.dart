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
}
