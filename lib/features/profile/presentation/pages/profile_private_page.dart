import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../../domain/entities/private_contact_methods.dart';
import '../../domain/repositories/profile_repository.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

/// Private identity page — Vault-stored PII fields (US5, FR-005/FR-006).
class ProfilePrivatePage extends StatelessWidget {
  const ProfilePrivatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => getIt<ProfileCubit>()..load()..loadPii(),
      child: const _PrivateView(),
    );
  }
}

class _PrivateView extends StatefulWidget {
  const _PrivateView();

  @override
  State<_PrivateView> createState() => _PrivateViewState();
}

class _PrivateViewState extends State<_PrivateView> {
  final _legalNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _telegramController = TextEditingController();
  final _signalController = TextEditingController();
  final _privateEmailController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();

  bool _piiInitialized = false;
  String? _piiError;

  @override
  void dispose() {
    _legalNameController.dispose();
    _nationalIdController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    _signalController.dispose();
    _privateEmailController.dispose();
    _secondaryPhoneController.dispose();
    super.dispose();
  }

  void _initFromPii(PiiBundle pii) {
    if (_piiInitialized) return;
    _piiInitialized = true;
    _legalNameController.text = pii.legalName ?? '';
    _nationalIdController.text = pii.nationalId ?? '';
    final methods = pii.privateContactMethods?.channels ?? {};
    _whatsappController.text = methods[ContactChannel.whatsapp] ?? '';
    _telegramController.text = methods[ContactChannel.telegram] ?? '';
    _signalController.text = methods[ContactChannel.signal] ?? '';
    _privateEmailController.text = methods[ContactChannel.privateEmail] ?? '';
    _secondaryPhoneController.text = methods[ContactChannel.secondaryPhone] ?? '';
  }

  Future<void> _saveAll(AppLocalizations l10n) async {
    setState(() => _piiError = null);
    final cubit = context.read<ProfileCubit>();

    final legalName = _legalNameController.text.trim();
    final nationalId = _nationalIdController.text.trim();

    if (legalName.isNotEmpty) {
      await cubit.saveLegalName(legalName);
      if (cubit.state.piiStatus == PiiStatus.saveFailure) return;
    }

    if (nationalId.isNotEmpty) {
      await cubit.saveNationalId(nationalId);
      if (cubit.state.piiStatus == PiiStatus.saveFailure) return;
    }

    final channels = <ContactChannel, String>{};
    final wa = _whatsappController.text.trim();
    final tg = _telegramController.text.trim();
    final sig = _signalController.text.trim();
    final pe = _privateEmailController.text.trim();
    final sp = _secondaryPhoneController.text.trim();

    if (wa.isNotEmpty) channels[ContactChannel.whatsapp] = wa;
    if (tg.isNotEmpty) channels[ContactChannel.telegram] = tg;
    if (sig.isNotEmpty) channels[ContactChannel.signal] = sig;
    if (pe.isNotEmpty) channels[ContactChannel.privateEmail] = pe;
    if (sp.isNotEmpty) {
      try {
        PhoneNumber.parse(sp);
        channels[ContactChannel.secondaryPhone] = sp;
      } on PhoneNumberFormatException {
        setState(() => _piiError = l10n.phone_invalid);
        return;
      }
    }

    if (channels.isNotEmpty || wa.isEmpty && tg.isEmpty && sig.isEmpty && pe.isEmpty && sp.isEmpty) {
      await cubit.saveContactMethods(PrivateContactMethods(channels));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.piiStatus == PiiStatus.loaded && !_piiInitialized) {
          _initFromPii(state.pii!);
        }
        if (state.piiStatus == PiiStatus.saveFailure) {
          setState(() => _piiError = _localizeFailure(state.piiFailure!, l10n));
        } else if (state.piiStatus == PiiStatus.loaded && _piiInitialized) {
          setState(() => _piiError = null);
        }
      },
      builder: (context, state) {
        if (state.piiStatus == PiiStatus.loading ||
            state.piiStatus == PiiStatus.idle) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.profile_private_section_title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final isSaving = state.piiStatus == PiiStatus.saving;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.profile_private_section_title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.profile_private_legal_name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _legalNameController,
                  decoration: InputDecoration(
                    labelText: l10n.profile_private_legal_name,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.profile_private_national_id,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nationalIdController,
                  decoration: InputDecoration(
                    labelText: l10n.profile_private_national_id,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.profile_private_contact_methods_title,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _ContactField(
                  controller: _whatsappController,
                  label: l10n.profile_private_contact_methods_whatsapp,
                ),
                _ContactField(
                  controller: _telegramController,
                  label: l10n.profile_private_contact_methods_telegram,
                ),
                _ContactField(
                  controller: _signalController,
                  label: l10n.profile_private_contact_methods_signal,
                ),
                _ContactField(
                  controller: _privateEmailController,
                  label: l10n.profile_private_contact_methods_private_email,
                  keyboardType: TextInputType.emailAddress,
                ),
                _ContactField(
                  controller: _secondaryPhoneController,
                  label: l10n.profile_private_contact_methods_secondary_phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                if (_piiError != null) ...[
                  Text(
                    _piiError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: isSaving ? null : () => _saveAll(l10n),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.profile_save_button),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _localizeFailure(ProfileFailure failure, AppLocalizations l10n) {
    return switch (failure) {
      NotAuthenticated() => l10n.unknown_auth_error,
      _ => failure.message,
    };
  }
}

class _ContactField extends StatelessWidget {
  const _ContactField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
