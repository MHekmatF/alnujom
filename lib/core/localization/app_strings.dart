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
  String get settingsEditorSaveButton =>
      _resolve('settingsEditorSaveButton', (loc) => loc.settingsEditorSaveButton);

  @override
  String get settingsEditorSavedSnackbar => _resolve(
    'settingsEditorSavedSnackbar',
    (loc) => loc.settingsEditorSavedSnackbar,
  );

  @override
  String get settingsEditorLoadError => _resolve(
    'settingsEditorLoadError',
    (loc) => loc.settingsEditorLoadError,
  );

  @override
  String get settingsEditorSaveError => _resolve(
    'settingsEditorSaveError',
    (loc) => loc.settingsEditorSaveError,
  );

  @override
  String get settingsEditorRetry =>
      _resolve('settingsEditorRetry', (loc) => loc.settingsEditorRetry);

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
}
