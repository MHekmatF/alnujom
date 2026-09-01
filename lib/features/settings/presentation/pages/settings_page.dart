import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/settings/lite_mode.dart';
import '../../../../core/settings/notification_prefs.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_toggle.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/segmented_control.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../currencies/presentation/widgets/preferred_currency_toggle.dart';
import '../../data/datasources/notification_prefs_remote.dart';

/// Phase 035 — the unified user Settings screen (Tier-D "Chrome" design).
///
/// One place for the four preference groups that were previously scattered
/// (theme was unsurfaced; currency/data-saver lived on Profile): Appearance
/// (light/dark/auto), General (language, currency, data-saver), Notifications
/// (per-category toggles), and About & Support. Reuses the existing
/// [ThemeCubit] / [LocaleCubit] / [PreferredCurrencyToggle] / [LiteMode] /
/// [NotificationPrefs] plumbing — no state duplication.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _version;

  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=com.alnujom.app';
  static const _remote = NotificationPrefsRemote();

  @override
  void initState() {
    super.initState();
    // Warm the local, secure-storage-backed preference singletons so their
    // toggles reflect the saved state on open.
    LiteMode.load();
    NotificationPrefs.load();
    unawaited(_loadRemotePrefs());
    unawaited(_loadVersion());
  }

  /// Pulls the server-authoritative per-category notification flags (when signed
  /// in) into the local [NotificationPrefs] so the toggles reflect the account's
  /// state across devices. Local-only writes — no server round-trip back.
  Future<void> _loadRemotePrefs() async {
    final server = await _remote.read();
    for (final entry in server.entries) {
      await NotificationPrefs.set(entry.key, entry.value);
    }
  }

  /// Flips a notification category locally (instant UI) AND on the server (the
  /// dispatch_push edge function honors the columns to actually mute pushes).
  void _setNotif(NotificationCategory category, bool value) {
    unawaited(NotificationPrefs.set(category, value));
    unawaited(_remote.write(category, value));
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } on Object {
      // Best-effort — the footer simply omits the version if it can't load.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.settings_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _appearanceGroup(context, l10n),
          _generalGroup(context, l10n),
          _notificationsGroup(context, l10n),
          _aboutGroup(context, l10n),
          _accountGroup(context, l10n),
          _VersionFooter(version: _version),
        ],
      ),
    );
  }

  // ── Group 1 — Appearance ──────────────────────────────────────────────────
  Widget _appearanceGroup(BuildContext context, AppLocalizations l10n) {
    return _SettingsSection(
      title: l10n.settings_appearance_heading,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: BlocBuilder<ThemeCubit, AppThemeMode>(
            builder: (context, mode) => AppSegmentedControl<AppThemeMode>(
              value: mode,
              onChanged: (m) => context.read<ThemeCubit>().setMode(m),
              segments: [
                AppSegmentedSegment(
                  icon: Icons.light_mode_outlined,
                  label: l10n.settings_theme_light,
                  value: AppThemeMode.light,
                ),
                AppSegmentedSegment(
                  icon: Icons.dark_mode_outlined,
                  label: l10n.settings_theme_dark,
                  value: AppThemeMode.dark,
                ),
                AppSegmentedSegment(
                  icon: Icons.brightness_auto_outlined,
                  label: l10n.settings_theme_auto,
                  value: AppThemeMode.auto,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Group 2 — General ─────────────────────────────────────────────────────
  Widget _generalGroup(BuildContext context, AppLocalizations l10n) {
    final isArabic = context.watch<LocaleCubit>().state.languageCode == 'ar';
    return _SettingsSection(
      title: l10n.settings_general_heading,
      children: [
        _SettingsNavRow(
          icon: Icons.language_outlined,
          title: l10n.settings_language_label,
          trailingValue: isArabic
              ? l10n.settings_language_arabic
              : l10n.settings_language_english,
          onTap: () => _pickLanguage(context, l10n),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RowHeader(
                icon: Icons.payments_outlined,
                label: l10n.settings_currency_label,
              ),
              const SizedBox(height: AppSpacing.md),
              const PreferredCurrencyToggle(),
            ],
          ),
        ),
        _SettingsToggleRow(
          icon: Icons.data_saver_on_outlined,
          title: l10n.profile_data_saver_title,
          subtitle: l10n.profile_data_saver_subtitle,
          listenable: LiteMode.notifier,
          onChanged: (v) => unawaited(LiteMode.set(v)),
        ),
      ],
    );
  }

  // ── Group 3 — Notifications ───────────────────────────────────────────────
  Widget _notificationsGroup(BuildContext context, AppLocalizations l10n) {
    return _SettingsSection(
      title: l10n.settings_notifications_heading,
      children: [
        _SettingsToggleRow(
          title: l10n.settings_notif_new_matches,
          listenable: NotificationPrefs.notifier(NotificationCategory.newMatches),
          onChanged: (v) => _setNotif(NotificationCategory.newMatches, v),
        ),
        _SettingsToggleRow(
          title: l10n.settings_notif_messages,
          listenable: NotificationPrefs.notifier(NotificationCategory.messages),
          onChanged: (v) => _setNotif(NotificationCategory.messages, v),
        ),
        _SettingsToggleRow(
          title: l10n.settings_notif_marketing,
          listenable: NotificationPrefs.notifier(NotificationCategory.marketing),
          onChanged: (v) => _setNotif(NotificationCategory.marketing, v),
        ),
      ],
    );
  }

  // ── Group 4 — About & Support ─────────────────────────────────────────────
  Widget _aboutGroup(BuildContext context, AppLocalizations l10n) {
    return _SettingsSection(
      title: l10n.settings_about_heading,
      children: [
        _SettingsNavRow(
          icon: Icons.info_outline,
          title: l10n.settings_about_row,
          onTap: () => context.push(AppRoutes.about),
        ),
        _SettingsNavRow(
          icon: Icons.star_rate_outlined,
          title: l10n.settings_rate_app,
          onTap: _rateApp,
        ),
      ],
    );
  }

  // ── Group 5 — Account ─────────────────────────────────────────────────────
  /// Self-serve account deletion. Google Play requires an in-app deletion path
  /// for any app with account creation, and Settings is where reviewers (and
  /// users) look for it. Styled with the theme's error token so it reads as
  /// destructive without being alarming enough to mis-tap.
  Widget _accountGroup(BuildContext context, AppLocalizations l10n) {
    return _SettingsSection(
      title: l10n.settings_account_heading,
      children: [
        _SettingsDangerRow(
          icon: Icons.delete_forever_outlined,
          title: l10n.accountDeleteEntryTitle,
          subtitle: l10n.accountDeleteEntrySubtitle,
          onTap: () => context.push(AppRoutes.accountDelete),
        ),
      ],
    );
  }

  void _rateApp() {
    final uri = Uri.tryParse(_storeUrl);
    if (uri != null) {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
    }
  }

  Future<void> _pickLanguage(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<LocaleCubit>();
    final current = cubit.state.languageCode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _LanguageSheet(
        title: l10n.settings_language_sheet_title,
        arabicLabel: l10n.settings_language_arabic,
        englishLabel: l10n.settings_language_english,
        current: current,
      ),
    );
    if (selected != null && selected != current) {
      await cubit.setLocale(Locale(selected));
    }
  }
}

/// A titled settings section: a bold muted group header over a card that groups
/// its rows with hairline dividers — the same idiom as the profile / about /
/// nav-drawer sections, so Settings reads consistently.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title,
              style: styles.labelLarge.copyWith(color: colors.textMuted),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: appRadius(AppRadii.lg),
              border: Border.all(color: colors.outline),
            ),
            child: ClipRRect(
              borderRadius: appRadius(AppRadii.lg),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: colors.divider,
                        indent: AppSpacing.lg,
                        endIndent: AppSpacing.lg,
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A leading-icon + label header used above an inline control (e.g. currency).
class _RowHeader extends StatelessWidget {
  const _RowHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Row(
      children: [
        Icon(icon, size: AppSpacing.xl, color: colors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: styles.titleMedium),
      ],
    );
  }
}

/// A tappable navigation row: leading tinted-square icon, title, optional
/// trailing value, and a direction-aware drill-in chevron.
class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingValue,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailingValue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: AppSpacing.xxl + AppSpacing.sm,
                height: AppSpacing.xxl + AppSpacing.sm,
                alignment: AlignmentDirectional.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: appRadius(AppRadii.md),
                ),
                child: Icon(icon, color: colors.primary, size: AppSpacing.xl),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: styles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingValue != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  trailingValue!,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              Icon(
                isRtl ? Icons.chevron_left : Icons.chevron_right,
                size: AppSpacing.lg,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A destructive navigation row: same geometry as [_SettingsNavRow] but tinted
/// with the theme's error token and carrying a supporting line, so an
/// irreversible action never looks like an ordinary preference.
class _SettingsDangerRow extends StatelessWidget {
  const _SettingsDangerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: AppSpacing.xxl + AppSpacing.sm,
                height: AppSpacing.xxl + AppSpacing.sm,
                alignment: AlignmentDirectional.center,
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: appRadius(AppRadii.md),
                ),
                child: Icon(icon, color: colors.error, size: AppSpacing.xl),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: styles.titleMedium.copyWith(color: colors.error),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: styles.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                isRtl ? Icons.chevron_left : Icons.chevron_right,
                size: AppSpacing.lg,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row whose trailing control is an [AppToggle] driven by a
/// [ValueListenable<bool>] (e.g. [LiteMode.notifier] / [NotificationPrefs]).
class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.listenable,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final ValueListenable<bool> listenable;
  final ValueChanged<bool> onChanged;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSpacing.xl, color: colors.textMuted),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: styles.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ValueListenableBuilder<bool>(
            valueListenable: listenable,
            builder: (context, value, _) =>
                AppToggle(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// The centred `النجوم · الإصدار X` version footer.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter({required this.version});

  final String? version;

  @override
  Widget build(BuildContext context) {
    if (version == null) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: Center(
        child: Text(
          l10n.settings_version(version!),
          style: styles.labelSmall.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }
}

/// The language-choice bottom sheet (Arabic / English).
class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({
    required this.title,
    required this.arabicLabel,
    required this.englishLabel,
    required this.current,
  });

  final String title;
  final String arabicLabel;
  final String englishLabel;
  final String current;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text(title, style: styles.titleMedium),
            ),
            _LanguageOption(
              label: arabicLabel,
              code: 'ar',
              selected: current == 'ar',
              accent: colors.primary,
            ),
            _LanguageOption(
              label: englishLabel,
              code: 'en',
              selected: current == 'en',
              accent: colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.code,
    required this.selected,
    required this.accent,
  });

  final String label;
  final String code;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return ListTile(
      title: Text(label, style: styles.titleMedium),
      trailing: selected ? Icon(Icons.check, color: accent) : null,
      onTap: () => Navigator.of(context).pop(code),
    );
  }
}
