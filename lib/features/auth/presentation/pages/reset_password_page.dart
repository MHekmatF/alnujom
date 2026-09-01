import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/dc_auth_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../../../settings/presentation/bloc/app_settings_cubit.dart';
import '../../../settings/presentation/widgets/support_contact_row.dart';
import '../../domain/entities/password_reset_outcome.dart';
import '../bloc/password_reset_cubit.dart';
import '../widgets/auth_status_message.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_trust_note.dart';

/// "Forgot password" — asks for the phone number and then tells the user what
/// can actually be done for that number.
///
/// This used to answer identically for every input so an observer could not
/// learn which numbers are registered. That was traded away deliberately
/// (owner's decision, 2026-09-01): the large majority of accounts here are
/// phone-only and can never receive a reset mail, so "check your email" was
/// false for almost everyone and the screen could not tell them what to do
/// instead. See [PasswordResetOutcome].
class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PasswordResetCubit>(
      create: (_) => getIt<PasswordResetCubit>(),
      child: const _ResetPasswordView(),
    );
  }
}

class _ResetPasswordView extends StatefulWidget {
  const _ResetPasswordView();

  @override
  State<_ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<_ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

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
    context.read<PasswordResetCubit>().submit(phone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return BlocBuilder<PasswordResetCubit, PasswordResetState>(
      builder: (context, state) {
        return DcAuthScaffold(
          child: state.isDone
              ? _Outcome(outcome: state.outcome!)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.reset_password_title,
                        style: styles.headlineMedium.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AuthField(
                        label: l10n.reset_password_phone_label,
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
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
                          onChanged: (_) =>
                              context.read<PasswordResetCubit>().reset(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton.filledPrimary(
                        label: l10n.reset_password_submit,
                        loading: state.isSubmitting,
                        expanded: true,
                        onPressed: state.isSubmitting ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (state.isFailure)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.sm,
                          ),
                          child: Text(
                            l10n.network_error,
                            style: styles.bodyMedium.copyWith(
                              color: colors.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      AuthTrustNote(text: l10n.auth_trust_note),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// One panel per outcome — each ends somewhere the user can actually go.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.outcome});

  final PasswordResetOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (outcome) {
      PasswordResetOutcome.sent => AuthStatusMessage(
        icon: LucideIcons.mail_check,
        message: l10n.reset_password_sent_message,
      ),
      PasswordResetOutcome.notFound => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStatusMessage(
            icon: LucideIcons.user_x,
            message: l10n.reset_password_not_found_message,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.filledPrimary(
            label: l10n.reset_password_create_account,
            expanded: true,
            onPressed: () => context.read<PasswordResetCubit>().reset(),
          ),
        ],
      ),
      PasswordResetOutcome.noEmail => const _NoEmailPanel(),
    };
  }
}

/// The common case: a phone-only account. There is no mailbox to send to, so
/// the only honest next step is a human — the support contact the admin
/// configured in app settings.
class _NoEmailPanel extends StatelessWidget {
  const _NoEmailPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, settingsState) {
        final contact = settingsState.settings.supportContact;
        final whatsapp = contact.whatsapp;
        final phone = contact.phone;
        final hasChannel =
            (whatsapp != null && whatsapp.isNotEmpty) ||
            (phone != null && phone.isNotEmpty);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthStatusMessage(
              icon: LucideIcons.life_buoy,
              message: hasChannel
                  ? l10n.reset_password_no_email_message
                  : l10n.reset_password_no_email_no_contact,
            ),
            if (whatsapp != null && whatsapp.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              SupportContactRow.whatsapp(
                label: l10n.support_channel_whatsapp,
                whatsapp: whatsapp,
              ),
            ],
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SupportContactRow.phone(
                label: l10n.support_channel_phone,
                phone: phone,
              ),
            ],
          ],
        );
      },
    );
  }
}
