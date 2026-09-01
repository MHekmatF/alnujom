import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/dc_auth_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/set_new_password_cubit.dart';
import '../widgets/auth_status_message.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_trust_note.dart';

/// Spec 005 D-01 — password-reset COMPLETION screen.
///
/// Reached after the `alnujom://auth/reset-password` recovery deep link is
/// exchanged for a session (supabase_flutter emits `passwordRecovery`, and
/// [PasswordRecoveryListener] routes here). Collects + confirms a new password
/// and writes it through [SetNewPasswordCubit] → UpdatePassword → AuthRepository.
///
/// Reachable in EVERY auth state (see the bypass in `authRedirect`): a recovery
/// session is a real session, so without it a pending/suspended user would be
/// bounced to their gate screen mid-reset.
class ResetPasswordCompletePage extends StatelessWidget {
  const ResetPasswordCompletePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SetNewPasswordCubit>(
      create: (_) => getIt<SetNewPasswordCubit>(),
      child: const _ResetPasswordCompleteView(),
    );
  }
}

class _ResetPasswordCompleteView extends StatefulWidget {
  const _ResetPasswordCompleteView();

  @override
  State<_ResetPasswordCompleteView> createState() =>
      _ResetPasswordCompleteViewState();
}

class _ResetPasswordCompleteViewState
    extends State<_ResetPasswordCompleteView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SetNewPasswordCubit>().submit(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<SetNewPasswordCubit, SetNewPasswordState>(
      builder: (context, state) {
        return DcAuthScaffold(
          child: switch (state) {
            SetNewPasswordState(isSuccess: true) => _SuccessView(l10n: l10n),
            SetNewPasswordState(error: SetNewPasswordError.sessionMissing) =>
              _LinkExpiredView(l10n: l10n),
            _ => _buildForm(context, l10n, state),
          },
        );
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    SetNewPasswordState state,
  ) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final isLoading = state.isSubmitting;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.reset_password_new_title,
            style: styles.headlineMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.reset_password_new_subtitle,
            style: styles.bodyMedium.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          AuthField(
            label: l10n.reset_password_new_label,
            child: TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: authFieldDecoration(
                context,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? LucideIcons.eye : LucideIcons.eye_off,
                  ),
                  tooltip: _obscurePassword
                      ? l10n.password_show
                      : l10n.password_hide,
                ),
              ),
              // Same rule the register form enforces (min 8 characters).
              validator: (v) {
                if (v == null || v.length < 8) return l10n.password_too_short;
                return null;
              },
              onChanged: (_) =>
                  context.read<SetNewPasswordCubit>().clearError(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthField(
            label: l10n.reset_password_confirm_label,
            child: TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: authFieldDecoration(
                context,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? LucideIcons.eye : LucideIcons.eye_off,
                  ),
                  tooltip: _obscureConfirm
                      ? l10n.password_show
                      : l10n.password_hide,
                ),
              ),
              validator: (v) {
                if (v != _passwordController.text) {
                  return l10n.reset_password_mismatch;
                }
                return null;
              },
              onChanged: (_) =>
                  context.read<SetNewPasswordCubit>().clearError(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (state.error != null) ...[
            Semantics(
              liveRegion: true,
              container: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.circle_alert,
                    size: AppSpacing.lg,
                    color: colors.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      switch (state.error!) {
                        SetNewPasswordError.weakPassword =>
                          l10n.password_too_short,
                        // Handled by _LinkExpiredView; listed for exhaustiveness.
                        SetNewPasswordError.sessionMissing =>
                          l10n.reset_password_link_expired_body,
                        SetNewPasswordError.unknown => l10n.network_error,
                      },
                      style: styles.bodyMedium.copyWith(color: colors.error),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton.filledPrimary(
            label: l10n.reset_password_save,
            loading: isLoading,
            expanded: true,
            onPressed: isLoading ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthTrustNote(text: l10n.auth_trust_note),
        ],
      ),
    );
  }
}

/// Terminal success state — the password is saved and the recovery session is
/// a normal signed-in session, so "continue" just drops the user on Home (the
/// router still applies the account-status gates from there).
class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AuthStatusMessage(
      icon: LucideIcons.circle_check,
      title: l10n.reset_password_success_title,
      message: l10n.reset_password_success_body,
      action: AppButton.filledPrimary(
        label: l10n.reset_password_continue,
        expanded: true,
        onPressed: () => context.go(AppRoutes.home),
      ),
    );
  }
}

/// The link expired, was already consumed, or the screen was opened without a
/// recovery session. Offers the request-a-new-link page rather than dead-ending.
class _LinkExpiredView extends StatelessWidget {
  const _LinkExpiredView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AuthStatusMessage(
      icon: LucideIcons.link_2_off,
      tone: AuthStatusTone.warning,
      title: l10n.reset_password_link_expired_title,
      message: l10n.reset_password_link_expired_body,
      action: AppButton.filledPrimary(
        label: l10n.reset_password_request_new_link,
        expanded: true,
        onPressed: () => context.go(AppRoutes.resetPassword),
      ),
    );
  }
}
