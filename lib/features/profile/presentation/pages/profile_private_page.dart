import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
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
      create: (_) => getIt<ProfileCubit>()..loadPii(),
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
    _secondaryPhoneController.text =
        methods[ContactChannel.secondaryPhone] ?? '';
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

    await cubit.saveContactMethods(PrivateContactMethods(channels));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

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
          return DcCrownScaffold(
            title: l10n.profile_private_section_title,
            dense: true,
            leading: DcCrownIconButton(
              icon: Icons.arrow_forward,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            body: const AppSpinner.page(),
          );
        }

        final isSaving = state.piiStatus == PiiStatus.saving;

        return DcCrownScaffold(
          title: l10n.profile_private_section_title,
          dense: true,
          leading: DcCrownIconButton(
            icon: Icons.arrow_forward,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Identity (Vault-stored legal name + national ID) ────────
                _PrivateSection(
                  title: l10n.profile_private_section_title,
                  subtitle: l10n.profilePrivateSecurityNote,
                  children: [
                    _ContactField(
                      controller: _legalNameController,
                      label: l10n.profile_private_legal_name,
                    ),
                    _ContactField(
                      controller: _nationalIdController,
                      label: l10n.profile_private_national_id,
                    ),
                  ],
                ),

                // ── Private contact methods ─────────────────────────────────
                _PrivateSection(
                  title: l10n.profile_private_contact_methods_title,
                  children: [
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
                      label:
                          l10n.profile_private_contact_methods_private_email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _ContactField(
                      controller: _secondaryPhoneController,
                      label:
                          l10n.profile_private_contact_methods_secondary_phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),

                if (_piiError != null) ...[
                  Text(
                    _piiError!,
                    style: styles.bodyMedium.copyWith(color: colors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppButton.filledPrimary(
                  label: l10n.profile_save_button,
                  loading: isSaving,
                  expanded: true,
                  onPressed: isSaving ? null : () => _saveAll(l10n),
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
    return AppTextField(
      label: label,
      controller: controller,
      keyboardType: keyboardType,
    );
  }
}

/// A titled section card grouping a set of input fields — the same idiom as the
/// profile + nav-drawer sections (bold muted header over a 1px-outlined card),
/// so the private page reads consistently with the rest of the profile area.
class _PrivateSection extends StatelessWidget {
  const _PrivateSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title,
              style: styles.labelLarge.copyWith(color: colors.textMuted),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                subtitle!,
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: appRadius(AppRadii.lg),
              border: Border.all(color: colors.outline),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
