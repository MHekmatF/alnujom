// lib/features/profile/presentation/pages/account_deletion_page.dart
//
// Self-serve account deletion — the in-app deletion surface Google Play requires
// of every app that offers account creation.
//
// The flow is deliberately high-friction. Deleting is irreversible, so it takes
// three separate, conscious acts: read the page, tick the acknowledgement, then
// confirm again in a destructive dialog. Nothing here fires on a single tap.
//
// Token-only (AppColors.of / AppTextStyles.of / AppSpacing / appRadius) and
// RTL-safe (EdgeInsetsDirectional, start/end). The destructive styling comes
// from the theme's error/errorContainer tokens — never a hardcoded red.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_checkbox.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../domain/repositories/profile_repository.dart';
import '../cubit/account_deletion_cubit.dart';
import '../cubit/account_deletion_state.dart';

class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountDeletionCubit>(
      create: (_) => getIt<AccountDeletionCubit>(),
      child: const _AccountDeletionView(),
    );
  }
}

class _AccountDeletionView extends StatefulWidget {
  const _AccountDeletionView();

  @override
  State<_AccountDeletionView> createState() => _AccountDeletionViewState();
}

class _AccountDeletionViewState extends State<_AccountDeletionView> {
  /// Friction gate #1 — the confirm button stays disabled until the user has
  /// explicitly ticked the "I understand this is permanent" acknowledgement.
  bool _acknowledged = false;

  /// Friction gate #2 — a destructive confirmation dialog. Only its action
  /// button reaches the cubit.
  Future<void> _confirm(AppLocalizations l10n) async {
    final cubit = context.read<AccountDeletionCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: Icons.delete_forever_outlined,
        variant: AppDialogVariant.destructive,
        title: l10n.accountDeleteDialogTitle,
        message: l10n.accountDeleteDialogMessage,
        cancelLabel: l10n.accountDeleteCancelButton,
        actionLabel: l10n.accountDeleteDialogConfirm,
        onAction: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed ?? false) {
      await cubit.submit();
    }
  }

  void _onDeleted(AppLocalizations l10n) {
    AppToast.success(context, l10n.accountDeleteSuccessToast);
    // Mirrors the Sign-out path on ProfilePage: drop the session first so the
    // AuthBloc is Unauthenticated, then leave the pushed route explicitly —
    // go_router's redirect re-evaluation runs against the underlying (public)
    // route, not this one.
    context.read<AuthBloc>().add(const LogoutRequested());
    context.go(AppRoutes.home);
  }

  String _failureMessage(ProfileFailure? failure, AppLocalizations l10n) {
    return switch (failure) {
      NotAuthenticated() => l10n.accountDeleteErrorNotSignedIn,
      _ => l10n.accountDeleteErrorGeneric,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<AccountDeletionCubit, AccountDeletionState>(
      listener: (context, state) {
        switch (state.status) {
          case AccountDeletionStatus.success:
            _onDeleted(l10n);
          case AccountDeletionStatus.failure:
            AppToast.error(context, _failureMessage(state.failure, l10n));
          case AccountDeletionStatus.idle:
          case AccountDeletionStatus.submitting:
            break;
        }
      },
      builder: (context, state) {
        return DcCrownScaffold(
          title: l10n.accountDeletePageTitle,
          dense: true,
          leading: DcCrownIconButton(
            icon: Icons.arrow_forward,
            onTap: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.profile),
          ),
          body: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              const _WarningHero(),
              const SizedBox(height: AppSpacing.xl),
              _DeletedItemsSection(),
              const SizedBox(height: AppSpacing.xl),
              const _RetainedNote(),
              const SizedBox(height: AppSpacing.xl),
              _AcknowledgeRow(
                value: _acknowledged,
                enabled: !state.isSubmitting,
                onChanged: (value) => setState(() => _acknowledged = value),
              ),
              if (state.status == AccountDeletionStatus.failure) ...[
                const SizedBox(height: AppSpacing.lg),
                _InlineError(message: _failureMessage(state.failure, l10n)),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                variant: AppButtonVariant.destructive,
                expanded: true,
                icon: Icons.delete_forever_outlined,
                label: l10n.accountDeleteConfirmButton,
                loading: state.isSubmitting,
                onPressed: (_acknowledged && !state.isSubmitting)
                    ? () => _confirm(l10n)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                variant: AppButtonVariant.text,
                expanded: true,
                label: l10n.accountDeleteCancelButton,
                onPressed: state.isSubmitting
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Warning hero ─────────────────────────────────────────────────────────────

/// The page's opening statement: an error-tinted card that says plainly that
/// this is permanent, before any control is offered.
class _WarningHero extends StatelessWidget {
  const _WarningHero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.error.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: colors.error,
                size: AppSpacing.xl,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.accountDeleteWarningTitle,
                  style: styles.titleMedium.copyWith(color: colors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.accountDeleteHeadline,
            style: styles.titleLarge.copyWith(color: colors.onErrorContainer),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.accountDeleteIntro,
            style: styles.bodyMedium.copyWith(color: colors.onErrorContainer),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.accountDeleteWarningBody,
            style: styles.bodyMedium.copyWith(color: colors.onErrorContainer),
          ),
        ],
      ),
    );
  }
}

// ── "What gets deleted" ──────────────────────────────────────────────────────

/// The plain-language inventory of what disappears, so consent is informed.
class _DeletedItemsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final items = <(IconData, String)>[
      (Icons.person_outline, l10n.accountDeleteItemProfile),
      (Icons.home_work_outlined, l10n.accountDeleteItemListings),
      (Icons.forum_outlined, l10n.accountDeleteItemMessages),
      (Icons.groups_outlined, l10n.accountDeleteItemCrm),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            l10n.accountDeleteWhatGoesTitle,
            style: styles.labelLarge.copyWith(color: colors.textMuted),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: appRadius(AppRadii.lg),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.divider,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        items[i].$1,
                        size: AppSpacing.xl,
                        color: colors.error,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          items[i].$2,
                          style: styles.bodyMedium.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── "What stays" ─────────────────────────────────────────────────────────────

/// Honest disclosure of the two things that survive: the de-identified inquiry
/// records other publishers keep, and the administrative deletion log.
class _RetainedNote extends StatelessWidget {
  const _RetainedNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: AppSpacing.xl,
            color: colors.textMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accountDeleteKeepsTitle,
                  style: styles.titleMedium.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.accountDeleteKeepsBody,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Acknowledgement ──────────────────────────────────────────────────────────

/// The explicit consent gate. The whole row is tappable so the checkbox never
/// needs a precise hit, but it still takes a deliberate action to arm delete.
class _AcknowledgeRow extends StatelessWidget {
  const _AcknowledgeRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: appRadius(AppRadii.lg),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppCheckbox(
                value: value,
                enabled: enabled,
                onChanged: (next) => onChanged(next ?? false),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.accountDeleteAcknowledge,
                  style: styles.bodyMedium.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inline failure ───────────────────────────────────────────────────────────

/// A persistent error surface, so a dismissed toast does not leave the user
/// wondering whether the deletion went through. It did not — the account is
/// untouched and they are still signed in.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: appRadius(AppRadii.md),
        border: Border.all(color: colors.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: AppSpacing.lg, color: colors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: styles.bodyMedium.copyWith(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }
}
