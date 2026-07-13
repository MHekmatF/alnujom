import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/dc_auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_trust_note.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../auth/domain/entities/auth_failure.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();

  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _nameController.dispose();
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
      RegisterRequested(
        phone: phone,
        password: _passwordController.text,
        fullName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        optionalRealEmail: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim().toLowerCase(),
        deviceLocale: context.read<LocaleCubit>().state,
      ),
    );
  }

  String _localizeFailure(AuthFailure failure, AppLocalizations l10n) {
    return switch (failure) {
      InvalidPhoneOrPassword() => l10n.invalid_phone_or_password,
      AccountAlreadyExists() => l10n.account_already_exists,
      PasswordTooShort() => l10n.password_too_short,
      UnknownAuthError(:final message) => switch (message) {
        'phone_required' => l10n.phone_required,
        'phone_invalid' => l10n.phone_invalid,
        'network_error' => l10n.network_error,
        _ => l10n.unknown_auth_error,
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
          return DcAuthScaffold(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.auth_register_headline,
                    style: styles.headlineMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.auth_register_subtitle,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AuthField(
                        label: l10n.register_phone_label,
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: authFieldDecoration(
                            context,
                            hint: l10n.register_phone_hint,
                          ),
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
                        label: l10n.register_password_label,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: authFieldDecoration(
                            context,
                            hint: l10n.register_password_hint,
                          ),
                          validator: (v) {
                            if (v == null || v.length < 8) {
                              return l10n.password_too_short;
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() => _errorText = null),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AuthField(
                        label: l10n.register_full_name_label,
                        child: TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          decoration: authFieldDecoration(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AuthField(
                        label: l10n.register_real_email_label_optional,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: authFieldDecoration(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
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
                        label: l10n.register_submit,
                        loading: isLoading,
                        expanded: true,
                        onPressed: isLoading ? null : () => _submit(l10n),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colors.primary,
                        ),
                        onPressed: () => context.go(AppRoutes.login),
                        child: Text(l10n.register_have_account),
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
