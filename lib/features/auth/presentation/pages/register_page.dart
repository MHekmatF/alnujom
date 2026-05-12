import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/routing/app_router.dart';
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
            appBar: AppBar(title: Text(l10n.register_title)),
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
                        labelText: l10n.register_phone_label,
                        hintText: l10n.register_phone_hint,
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
                        labelText: l10n.register_password_label,
                        hintText: l10n.register_password_hint,
                      ),
                      validator: (v) {
                        if (v == null || v.length < 8) {
                          return l10n.password_too_short;
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _errorText = null),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        labelText: l10n.register_full_name_label,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.register_real_email_label_optional,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                          : Text(l10n.register_submit),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: Text(l10n.register_have_account),
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
