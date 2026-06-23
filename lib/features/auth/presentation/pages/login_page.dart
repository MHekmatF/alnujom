import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_trust_note.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../../../../core/routing/app_router.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../auth/domain/entities/auth_failure.dart';

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

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() => _errorText = _localizeFailure(state.failure, l10n));
        } else {
          setState(() => _errorText = null);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is Authenticating;
          return Scaffold(
            backgroundColor: colors.surface,
            appBar: AppBar(
              backgroundColor: colors.surface,
              elevation: 0,
              title: Text(l10n.login_title),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const Center(child: AppLogo()),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        l10n.auth_login_headline,
                        style: styles.headlineLarge.copyWith(
                          color: colors.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.auth_login_subtitle,
                        style: styles.bodyMedium.copyWith(
                          color: colors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
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
                          obscureText: true,
                          decoration: authFieldDecoration(context),
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
                          onPressed: () =>
                              context.push(AppRoutes.resetPassword),
                          child: Text(l10n.login_forgot_password),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_errorText != null) ...[
                        Text(
                          _errorText!,
                          style: styles.bodyMedium.copyWith(
                            color: colors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AppButton.filledPrimary(
                        label: l10n.login_submit,
                        loading: isLoading,
                        expanded: true,
                        onPressed: isLoading ? null : () => _submit(l10n),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colors.primary,
                        ),
                        onPressed: () => context.push(AppRoutes.register),
                        child: Text(l10n.login_no_account),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AuthTrustNote(text: l10n.auth_trust_note),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
