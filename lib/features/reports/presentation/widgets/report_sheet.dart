// lib/features/reports/presentation/widgets/report_sheet.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T042).
// Modal bottom sheet: reason dropdown + optional note + submit/cancel.
// Phase 2 tokens only; no inline hex/font-size/padding.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/report_reason.dart';
import '../cubit/report_submission_cubit.dart';

/// Modal bottom sheet for submitting a report against [listingId] — or, with
/// [userId] set instead (plan A29), against a person.
///
/// Provide a fresh [ReportSubmissionCubit] from DI so each sheet instance has
/// isolated form state.
class ReportSheet extends StatelessWidget {
  const ReportSheet({super.key, this.listingId, this.userId})
    : assert(listingId != null || userId != null, 'one target is required');

  final String? listingId;

  /// Plan A29 — when set, the sheet reports a person, not a listing.
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReportSubmissionCubit>(
      create: (_) => getIt<ReportSubmissionCubit>(),
      child: _ReportSheetBody(listingId: listingId, userId: userId),
    );
  }
}

class _ReportSheetBody extends StatefulWidget {
  const _ReportSheetBody({this.listingId, this.userId});

  final String? listingId;
  final String? userId;

  @override
  State<_ReportSheetBody> createState() => _ReportSheetBodyState();
}

class _ReportSheetBodyState extends State<_ReportSheetBody> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);

    return BlocListener<ReportSubmissionCubit, ReportSubmissionState>(
      listenWhen: (prev, curr) => curr.result != null && prev.result == null,
      listener: (context, state) {
        switch (state.result!) {
          case SubmitResult.success:
            Navigator.of(context).pop();
            AppToast.success(context, l10n.report_submitted_success);
          case SubmitResult.alreadyReported:
            Navigator.of(context).pop();
            AppToast.info(context, l10n.report_already_reported);
          case SubmitResult.failure:
            Navigator.of(context).pop();
            AppToast.error(context, l10n.report_submit_failed);
        }
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  widget.userId != null
                      ? l10n.report_user_sheet_title
                      : l10n.report_sheet_title,
                  style: styles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.userId != null
                      ? l10n.report_user_sheet_subtitle
                      : l10n.report_sheet_subtitle,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
              // Reason dropdown
              BlocBuilder<ReportSubmissionCubit, ReportSubmissionState>(
                buildWhen: (prev, curr) => prev.reason != curr.reason,
                builder: (context, state) {
                  return AppDropdown<ReportReason>(
                    label: l10n.report_reason_field_label,
                    value: state.reason,
                    items: (widget.userId != null
                            ? ReportReason.userReasons
                            : ReportReason.listingReasons)
                        .map((reason) {
                      return DropdownMenuItem<ReportReason>(
                        value: reason,
                        child: Text(_reasonLabel(l10n, reason)),
                      );
                    }).toList(),
                    onChanged: (reason) => context
                        .read<ReportSubmissionCubit>()
                        .reasonChanged(reason),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              // Optional note — DS field. The 1000-char cap is enforced by the
              // cubit's noteChanged().
              AppTextField(
                controller: _noteController,
                label: l10n.report_note_field_hint,
                maxLines: 3,
                onChanged: (note) =>
                    context.read<ReportSubmissionCubit>().noteChanged(note),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Submit + Cancel
              BlocBuilder<ReportSubmissionCubit, ReportSubmissionState>(
                buildWhen: (prev, curr) =>
                    prev.canSubmit != curr.canSubmit ||
                    prev.isSubmitting != curr.isSubmitting,
                builder: (context, state) {
                  return Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: l10n.report_cancel_button,
                          variant: AppButtonVariant.outlined,
                          expanded: true,
                          onPressed: state.isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton.filledPrimary(
                          label: l10n.report_submit_button,
                          expanded: true,
                          loading: state.isSubmitting,
                          onPressed: state.canSubmit
                              ? () => context
                                    .read<ReportSubmissionCubit>()
                                    .submitFor(
                                      listingId: widget.listingId,
                                      userId: widget.userId,
                                    )
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _reasonLabel(AppLocalizations l10n, ReportReason reason) {
    return switch (reason) {
      ReportReason.fakeListing => l10n.report_reason_fake_listing,
      ReportReason.wrongPrice => l10n.report_reason_wrong_price,
      ReportReason.alreadySoldOrRented =>
        l10n.report_reason_already_sold_or_rented,
      ReportReason.duplicate => l10n.report_reason_duplicate,
      ReportReason.spam => l10n.report_reason_spam,
      ReportReason.wrongLocation => l10n.report_reason_wrong_location,
      ReportReason.inappropriateContent =>
        l10n.report_reason_inappropriate_content,
      ReportReason.other => l10n.report_reason_other,
      ReportReason.harassment => l10n.report_reason_harassment,
      ReportReason.scam => l10n.report_reason_scam,
      ReportReason.impersonation => l10n.report_reason_impersonation,
    };
  }
}
