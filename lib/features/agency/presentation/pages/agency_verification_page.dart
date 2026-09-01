// lib/features/agency/presentation/pages/agency_verification_page.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T058) + follow-up D-2/D-3.
// ID-document + commercial-registration number fields (Vault-stored server
// side) + an optional document photo upload (D-2) + a status banner. A rejected
// agency surfaces the rejection REASON (D-3); an approved agency shows the
// approved banner and disables resubmission. Phase 2 tokens; strings via l10n.
//
// Phase 28 (premium-worth pass) — purely visual retrofit: AppTextField,
// AppButton, AppToast, AppSpinner. Behavior unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../domain/entities/agency.dart';
import '../../domain/entities/agency_status.dart';
import '../../domain/entities/agency_verification_request.dart';
import '../../domain/repositories/agency_repository.dart';
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

    return DcCrownScaffold(
      title: l10n.agency_verify_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: BlocConsumer<AgencyVerificationCubit, AgencyVerificationState>(
        listenWhen: (prev, curr) =>
            curr is AgencyVerificationReady && curr.submitted,
        listener: (context, state) {
          if (state is AgencyVerificationReady && state.submitted) {
            AppToast.success(context, l10n.agency_verify_submitted);
          }
        },
        builder: (context, state) {
          return switch (state) {
            AgencyVerificationLoading() => const AppSpinner.page(),
            // Batch-2: a bare centred Text was the only thing shown on a load
            // failure — no way out. Now the shared ErrorState with a Retry that
            // re-calls the very same load(agencyId).
            AgencyVerificationError() => ErrorState(
              title: l10n.agency_generic_error,
              onRetry: () =>
                  context.read<AgencyVerificationCubit>().load(agencyId),
            ),
            AgencyVerificationReady() => _VerificationForm(
              agencyId: agencyId,
              agency: state.agency,
              request: state.request,
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
    required this.request,
    required this.submitting,
    required this.errorCode,
  });

  final String agencyId;
  final Agency agency;
  final AgencyVerificationRequest? request;
  final bool submitting;
  final String? errorCode;

  @override
  State<_VerificationForm> createState() => _VerificationFormState();
}

class _VerificationFormState extends State<_VerificationForm> {
  final _idController = TextEditingController();
  final _registrationController = TextEditingController();
  final List<String> _evidenceUrls = <String>[];
  bool _uploadingDoc = false;

  @override
  void dispose() {
    _idController.dispose();
    _registrationController.dispose();
    super.dispose();
  }

  String _docContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickDocument() async {
    final l10n = AppLocalizations.of(context)!;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _uploadingDoc = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final filename = 'doc_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final result = await getIt<AgencyRepository>().uploadVerificationDocument(
        agencyId: widget.agencyId,
        filename: filename,
        bytes: bytes,
        contentType: _docContentType(ext),
      );
      if (!mounted) return;
      switch (result) {
        case Success(:final value):
          setState(() {
            _evidenceUrls.add(value);
            _uploadingDoc = false;
          });
        case FailureResult():
          setState(() => _uploadingDoc = false);
          AppToast.error(context, l10n.agency_action_failed);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingDoc = false);
      AppToast.error(context, l10n.agency_action_failed);
    }
  }

  void _submit() {
    final id = _idController.text.trim();
    final registration = _registrationController.text.trim();
    if (id.isEmpty || registration.isEmpty) return;
    context.read<AgencyVerificationCubit>().submit(
      agencyId: widget.agencyId,
      idDocumentNumber: id,
      registrationNumber: registration,
      evidenceUrls: _evidenceUrls.isEmpty ? null : List.of(_evidenceUrls),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final isApproved = widget.agency.status == AgencyStatus.approved;
    final isRejected = widget.agency.status == AgencyStatus.rejected;
    final canSubmit = !widget.submitting && !_uploadingDoc && !isApproved;
    final rejectionReason = widget.request?.decisionReason;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner.
          Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: appRadius(AppRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [AgencyStatusChip(widget.agency.status)]),
                // D-3: surface the rejection reason to the owner.
                if (isRejected) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.agency_reject_reason_with_value(
                      rejectionReason ?? l10n.agency_status_rejected,
                    ),
                    style: styles.bodyMedium.copyWith(color: colors.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _idController,
            enabled: canSubmit,
            label: l10n.agency_verify_id_number_label,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _registrationController,
            enabled: canSubmit,
            label: l10n.agency_verify_registration_label,
          ),
          const SizedBox(height: AppSpacing.md),
          // D-2: optional supporting-document photo upload.
          AppButton(
            label: _evidenceUrls.isEmpty
                ? l10n.agency_verify_documents_label
                : '${l10n.agency_verify_documents_label} '
                      '(${formatLocalizedNumber(_evidenceUrls.length, Localizations.localeOf(context))})',
            variant: AppButtonVariant.outlined,
            icon: LucideIcons.paperclip,
            loading: _uploadingDoc,
            onPressed: canSubmit ? _pickDocument : null,
          ),
          if (widget.errorCode != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.agency_action_failed,
              style: styles.labelMedium.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton.filledPrimary(
            label: l10n.agency_verify_submit_button,
            expanded: true,
            loading: widget.submitting,
            onPressed: canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}
