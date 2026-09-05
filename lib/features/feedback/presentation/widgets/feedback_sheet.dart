// Plan A34 — a problem, an idea or a question, sent from the About screen.
// Modal bottom sheet: category dropdown + message + send/cancel. Same shape
// as the report sheet; tokens only.

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
import '../../domain/entities/feedback_category.dart';
import '../cubit/feedback_submission_cubit.dart';

/// Provide a fresh [FeedbackSubmissionCubit] from DI so each sheet instance
/// has isolated form state.
class FeedbackSheet extends StatelessWidget {
  const FeedbackSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FeedbackSubmissionCubit>(
      create: (_) => getIt<FeedbackSubmissionCubit>(),
      child: const _FeedbackSheetBody(),
    );
  }
}

class _FeedbackSheetBody extends StatefulWidget {
  const _FeedbackSheetBody();

  @override
  State<_FeedbackSheetBody> createState() => _FeedbackSheetBodyState();
}

class _FeedbackSheetBodyState extends State<_FeedbackSheetBody> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);

    return BlocListener<FeedbackSubmissionCubit, FeedbackSubmissionState>(
      listenWhen: (prev, curr) => curr.result != null && prev.result == null,
      listener: (context, state) {
        switch (state.result!) {
          case FeedbackSubmitResult.success:
            Navigator.of(context).pop();
            AppToast.success(context, l10n.feedback_sent);
          case FeedbackSubmitResult.rateLimited:
            AppToast.warning(context, l10n.feedback_rate_limited);
          case FeedbackSubmitResult.signedOut:
            Navigator.of(context).pop();
            AppToast.warning(context, l10n.feedback_sign_in_prompt);
          case FeedbackSubmitResult.failure:
            AppToast.error(context, l10n.feedback_failed);
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
                Text(l10n.feedback_sheet_title, style: styles.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.feedback_sheet_subtitle,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                BlocBuilder<FeedbackSubmissionCubit, FeedbackSubmissionState>(
                  buildWhen: (prev, curr) => prev.category != curr.category,
                  builder: (context, state) {
                    return AppDropdown<FeedbackCategory>(
                      label: l10n.feedback_category_label,
                      value: state.category,
                      items: FeedbackCategory.values.map((category) {
                        return DropdownMenuItem<FeedbackCategory>(
                          value: category,
                          child: Text(_categoryLabel(l10n, category)),
                        );
                      }).toList(),
                      onChanged: (category) => context
                          .read<FeedbackSubmissionCubit>()
                          .categoryChanged(category),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // The 2000-char cap is enforced by the cubit's messageChanged().
                AppTextField(
                  controller: _messageController,
                  label: l10n.feedback_message_hint,
                  maxLines: 5,
                  onChanged: (message) => context
                      .read<FeedbackSubmissionCubit>()
                      .messageChanged(message),
                ),
                const SizedBox(height: AppSpacing.lg),
                BlocBuilder<FeedbackSubmissionCubit, FeedbackSubmissionState>(
                  buildWhen: (prev, curr) =>
                      prev.canSubmit != curr.canSubmit ||
                      prev.isSubmitting != curr.isSubmitting,
                  builder: (context, state) {
                    return Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: l10n.actionCancel,
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
                            label: l10n.feedback_send,
                            expanded: true,
                            loading: state.isSubmitting,
                            onPressed: state.canSubmit
                                ? () => context
                                      .read<FeedbackSubmissionCubit>()
                                      .submit()
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

  String _categoryLabel(AppLocalizations l10n, FeedbackCategory category) {
    return switch (category) {
      FeedbackCategory.bug => l10n.feedback_category_bug,
      FeedbackCategory.idea => l10n.feedback_category_idea,
      FeedbackCategory.question => l10n.feedback_category_question,
      FeedbackCategory.other => l10n.feedback_category_other,
    };
  }
}
