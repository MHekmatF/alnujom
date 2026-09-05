import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../feedback/presentation/widgets/feedback_sheet.dart';
import '../../domain/entities/support_contact.dart';
import '../bloc/app_settings_cubit.dart';
import '../widgets/support_contact_row.dart';

/// Phase 23 (FC / T022) — the public about/support surface (FR-013).
///
/// Renders the configured [SupportContact] channels and the `terms_url` /
/// `privacy_url` links, OMITTING any that are unset so the page never shows a
/// broken link or an empty card. Reads the snapshot from [AppSettingsCubit]
/// (already loaded at app-start / resume).
class AboutSupportPage extends StatelessWidget {
  const AboutSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Plan A34 — the feedback sheet needs an account (the RPC refuses
    // guests), so the tile shows only to someone who has one.
    final signedIn = context.watch<AuthBloc>().state is Authenticated;

    return DcCrownScaffold(
      title: l10n.about_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      body: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, state) {
          final settings = state.settings;
          final contact = settings.supportContact;
          // Plan A27 — the terms are bundled, so the legal section always
          // exists and the page is never empty.

          final sections = <Widget>[
            if (contact.hasAny || signedIn)
              _SettingsSection(
                title: l10n.about_support_heading,
                children: [
                  ..._buildContactRows(l10n, contact),
                  // Plan A34 — a problem or an idea, from inside the app.
                  if (signedIn)
                    _PageTile(
                      icon: Icons.chat_bubble_outline,
                      label: l10n.about_feedback,
                      onTap: () => _openFeedback(context),
                    ),
                ],
              ),
            _SettingsSection(
                title: l10n.about_legal_heading,
                children: [
                  // Plan A27 — read in the app; the website copy is the same
                  // document, so no URL is needed.
                  _PageTile(
                    icon: Icons.description_outlined,
                    label: l10n.about_terms,
                    onTap: () => context.push(AppRoutes.terms),
                  ),
                  if (_hasAny(settings.privacyUrl))
                    _LinkTile(
                      icon: Icons.privacy_tip_outlined,
                      label: l10n.about_privacy,
                      url: settings.privacyUrl!,
                    ),
                ],
              ),
          ];

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              for (var i = 0; i < sections.length; i++)
                StaggeredListItem(index: i, child: sections[i]),
            ],
          );
        },
      ),
    );
  }

  static bool _hasAny(String? value) => value != null && value.isNotEmpty;

  void _openFeedback(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FeedbackSheet(),
    );
  }

  List<Widget> _buildContactRows(
    AppLocalizations l10n,
    SupportContact contact,
  ) {
    final rows = <Widget>[];
    final phone = contact.phone;
    final whatsapp = contact.whatsapp;
    final email = contact.email;
    if (_hasAny(phone)) {
      rows.add(
        SupportContactRow.phone(
          label: l10n.support_channel_phone,
          phone: phone!,
        ),
      );
    }
    if (_hasAny(whatsapp)) {
      rows.add(
        SupportContactRow.whatsapp(
          label: l10n.support_channel_whatsapp,
          whatsapp: whatsapp!,
        ),
      );
    }
    if (_hasAny(email)) {
      rows.add(
        SupportContactRow.email(
          label: l10n.support_channel_email,
          email: email!,
        ),
      );
    }
    return rows;
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          final uri = Uri.tryParse(url);
          if (uri != null) {
            unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
          }
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Row(
            children: [
              // Leading icon in a soft brand-tinted square (profile-row idiom).
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
                  label,
                  style: styles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.open_in_new,
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

/// Plan A27 — a row that opens a page inside the app (same look as
/// [_LinkTile], with a chevron instead of the open-in-new glyph).
class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
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
                  label,
                  style: styles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_left,
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

/// A titled settings section: a bold muted group header over a card that
/// visually groups its rows with hairline dividers — the same idiom as the
/// profile + nav-drawer sections, so settings reads consistently.
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
