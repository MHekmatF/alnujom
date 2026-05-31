// lib/features/agency/presentation/pages/agency_verification_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T058).
// ID-document + commercial-registration number fields (Vault-stored server
// side) + a status banner driven by the agency's status + submit. A rejected
// agency surfaces the rejection banner; an approved agency shows the approved
// banner and disables resubmission. Phase 2 tokens only; all strings via
// AppLocalizations.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/agency.dart';
import '../../domain/entities/agency_status.dart';
import '../bloc/agency_verification_cubit.dart';
import '../widgets/agency_status_chip.dart';

class AgencyVerificationPage extends StatelessWidget {
  const AgencyVerificationPage({super.key, required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgencyVerificationCubit>(
      create: (_) => getIt<AgencyVerificationCubit>()..load(agencyId),
      child: _AgencyVerificationView(agencyId: agencyId),
    );
  }
}

class _AgencyVerificationView extends StatelessWidget {
  const _AgencyVerificationView({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        title: Text(l10n.agency_verify_title),
      ),
      body: BlocConsumer<AgencyVerificationCubit, AgencyVerificationState>(
        listenWhen: (prev, curr) =>
            curr is AgencyVerificationReady && curr.submitted,
        listener: (context, state) {
          if (state is AgencyVerificationReady && state.submitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.agency_verify_submitted)),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            AgencyVerificationLoading() =>
              const Center(child: CircularProgressIndicator()),
            AgencyVerificationError() =>
              Center(child: Text(l10n.agency_generic_error)),
            AgencyVerificationReady() => _VerificationForm(
                agencyId: agencyId,
                agency: state.agency,
                submitting: state.submitting,
                errorCode: state.errorCode,
              ),
          };
        },
      ),
    );
  }
}

class _VerificationForm extends StatefulWidget {
  const _VerificationForm({
    required this.agencyId,
    required this.agency,
    required this.submitting,
    required this.errorCode,
  });

  final String agencyId;
  final Agency agency;
  final bool submitting;
  final String? errorCode;

  @override
  State<_VerificationForm> createState() => _VerificationFormState();
}

class _VerificationFormState extends State<_VerificationForm> {
  final _idController = TextEditingController();
  final _registrationController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _registrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isApproved = widget.agency.status == AgencyStatus.approved;
    final canSubmit = !widget.submitting && !isApproved;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              children: [
                AgencyStatusChip(widget.agency.status),
                if (widget.agency.status == AgencyStatus.rejected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.agency_status_rejected,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _idController,
            enabled: canSubmit,
            decoration: InputDecoration(
              labelText: l10n.agency_verify_id_number_label,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _registrationController,
            enabled: canSubmit,
            decoration: InputDecoration(
              labelText: l10n.agency_verify_registration_label,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.errorCode != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.errorCode == 'verification_already_open'
                  ? l10n.agency_action_failed
                  : l10n.agency_action_failed,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            child: widget.submitting
                ? const SizedBox(
                    width: AppSpacing.lg,
                    height: AppSpacing.lg,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.agency_verify_submit_button),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final id = _idController.text.trim();
    final registration = _registrationController.text.trim();
    if (id.isEmpty || registration.isEmpty) return;
    context.read<AgencyVerificationCubit>().submit(
          agencyId: widget.agencyId,
          idDocumentNumber: id,
          registrationNumber: registration,
        );
  }
}
