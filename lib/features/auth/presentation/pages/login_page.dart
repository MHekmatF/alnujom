import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
    final theme = Theme.of(context);

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
            appBar: AppBar(title: Text(l10n.login_title)),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: l10n.login_phone_label,
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.login_password_label,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l10n.password_too_short;
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _errorText = null),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => context.push(AppRoutes.resetPassword),
                        child: Text(l10n.login_forgot_password),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_errorText != null) ...[
                      Text(
                        _errorText!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: isLoading ? null : () => _submit(l10n),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.login_submit),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.register),
                      child: Text(l10n.login_no_account),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
