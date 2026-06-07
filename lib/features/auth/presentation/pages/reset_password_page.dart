import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../widgets/auth_trust_note.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Password-reset request page (US3, FR-017 account-enumeration resistance).
///
/// Always shows the same generic localized response after submit, regardless
/// of whether the phone has an account or a real email on file.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _submitted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final PhoneNumber phone;
    try {
      phone = PhoneNumber.parse(_phoneController.text.trim());
    } on PhoneNumberFormatException {
      return;
    }

    setState(() => _submitting = true);
    context.read<AuthBloc>().add(ResetPasswordRequested(phone: phone));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!_submitting || state is Authenticating) return;
        // Bloc finished processing our submission.
        if (state is AuthError) {
          // Transport failure — keep form visible, show retry inline.
          setState(() => _submitting = false);
        } else {
          // Any other outcome is a successful request → generic response.
          setState(() {
            _submitting = false;
            _submitted = true;
          });
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = _submitting || state is Authenticating;

          return Scaffold(
            appBar: AppBar(title: Text(l10n.reset_password_title)),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: _submitted
                  ? _GenericResponse(
                      message: l10n.reset_password_generic_response,
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          const Center(child: AppLogo()),
                          const SizedBox(height: AppSpacing.xl),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: l10n.reset_password_phone_label,
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
                            onChanged: (_) =>
                                setState(() => _submitted = false),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AppButton.filledPrimary(
                            label: l10n.reset_password_submit,
                            loading: isLoading,
                            onPressed: isLoading ? null : _submit,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (state is AuthError)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Text(
                                l10n.network_error,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                          AuthTrustNote(text: l10n.auth_trust_note),
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

class _GenericResponse extends StatelessWidget {
  const _GenericResponse({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        Container(
          width: AppSpacing.xxxl + AppSpacing.lg,
          height: AppSpacing.xxxl + AppSpacing.lg,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            size: AppSpacing.xxl,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          message,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
