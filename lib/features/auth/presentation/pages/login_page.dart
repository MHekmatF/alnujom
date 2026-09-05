import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/dc_auth_scaffold.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_trust_note.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/network/connectivity_cubit.dart';
import '../../../../core/widgets/app_toast.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../auth/domain/entities/auth_failure.dart';
import '../widgets/dismiss_when_signed_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _errorText;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Plan A30 — say WHY the user is looking at this screen when the app put
    // them here: the session lapsed, or the phone is offline and the session
    // could not be confirmed. Nothing is shown for a plain sign-out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthBloc>().state;
      if (auth is! Unauthenticated || auth.reason == SignedOutReason.none) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final online = context.read<ConnectivityCubit>().state;
      AppToast.info(
        context,
        online ? l10n.authSessionExpiredNotice : l10n.authOfflineNotice,
      );
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    setState(() => _errorText = null);
    if (!_formKey.currentState!.validate()) return;

    final PhoneNumber phone;
    try {
      phone = PhoneNumber.parse(_phoneController.text.trim());
    } on PhoneNumberFormatException catch (e) {
      setState(() {
        _errorText = e.localizationKey == 'phone_required'
            ? l10n.phone_required
            : l10n.phone_invalid;
      });
      return;
    }

    context.read<AuthBloc>().add(
      LoginRequested(phone: phone, password: _passwordController.text),
    );
  }

  String _localizeFailure(AuthFailure failure, AppLocalizations l10n) {
    return switch (failure) {
      InvalidPhoneOrPassword() => l10n.invalid_phone_or_password,
      AccountAlreadyExists() => l10n.invalid_phone_or_password,
      PasswordTooShort() => l10n.invalid_phone_or_password,
      UnknownAuthError(:final message) => switch (message) {
        'phone_required' => l10n.phone_required,
        'phone_invalid' => l10n.phone_invalid,
        'network_error' => l10n.network_error,
        _ => l10n.invalid_phone_or_password,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    // Subtle first-impression entrance on the brand/header cluster only
    // (input fields untouched); skipped entirely under "reduce motion".
    Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.auth_login_headline,
          style: styles.headlineMedium.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.auth_login_subtitle,
          style: styles.bodyMedium.copyWith(color: colors.textMuted),
        ),
      ],
    );
    if (!reduceMotion(context)) {
      header = header
          .animate()
          .fadeIn(duration: AppMotion.slow)
          .slideY(
            begin: 0.06,
            end: 0,
            duration: AppMotion.slow,
            curve: AppMotion.curve,
          );
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() => _errorText = _localizeFailure(state.failure, l10n));
        } else {
          setState(() => _errorText = null);
        }
        // Reached by `context.push` from the guest sheet, the drawer, the
        // favourite heart and the listing contact block — so on success this
        // page is left sitting on top of an already-correct stack. See
        // [dismissWhenSignedIn]; a no-op when /login is the stack root.
        dismissWhenSignedIn(context, state);
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is Authenticating;
          return DcAuthScaffold(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: AppSpacing.xl),
                  AuthField(
                    label: l10n.login_phone_label,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: authFieldDecoration(context),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l10n.phone_required;
                        }
                        if (PhoneNumber.tryParse(v.trim()) == null) {
                          return l10n.phone_invalid;
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _errorText = null),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AuthField(
                    label: l10n.login_password_label,
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: authFieldDecoration(
                        context,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? LucideIcons.eye : LucideIcons.eye_off,
                          ),
                          tooltip: _obscure
                              ? l10n.password_show
                              : l10n.password_hide,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l10n.password_too_short;
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _errorText = null),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                      ),
                      // Disabled mid-login: navigating away while the
                      // AuthBloc is Authenticating strands the request and
                      // lands the user on a screen the redirect will move
                      // again the moment it resolves.
                      onPressed: isLoading
                          ? null
                          : () => context.push(AppRoutes.resetPassword),
                      child: Text(l10n.login_forgot_password),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_errorText != null) ...[
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
                              _errorText!,
                              style: styles.bodyMedium.copyWith(
                                color: colors.error,
                              ),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  AppButton.filledPrimary(
                    label: l10n.login_submit,
                    loading: isLoading,
                    expanded: true,
                    onPressed: isLoading ? null : () => _submit(l10n),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Phase 035 — browse the app without an account (Home +
                  // listings are anonymous-readable). Design "الدخول كزائر".
                  // Promoted to a clear secondary (outlined) action so the
                  // marketplace's key anonymous path reads as a real CTA.
                  AppButton(
                    label: l10n.auth_continue_as_guest,
                    variant: AppButtonVariant.outlined,
                    expanded: true,
                    icon: LucideIcons.store,
                    onPressed: isLoading
                        ? null
                        : () => context.go(AppRoutes.home),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                    ),
                    onPressed: isLoading
                        ? null
                        : () => context.push(AppRoutes.register),
                    child: Text(l10n.login_no_account),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AuthTrustNote(text: l10n.auth_trust_note),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
