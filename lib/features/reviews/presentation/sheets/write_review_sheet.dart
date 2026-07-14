import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/seller_trust_cubit.dart';

/// Bottom sheet for leaving a seller review: an interactive star selector plus
/// a multiline comment field. Submits via the page-provided [SellerTrustCubit]
/// (passed in by `.value` so the cubit reloads the section on success).
///
/// The sheet pops itself once a submit resolves; the caller (the reviews
/// section) shows the resulting snackbar from the cubit's [SubmitOutcome].
class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({
    required this.cubit,
    required this.targetUserId,
    this.listingId,
    super.key,
  });

  final SellerTrustCubit cubit;
  final String targetUserId;
  final String? listingId;

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  int _rating = 0;
  late final TextEditingController _commentCtrl;

  static const int _maxComment = 1000;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    widget.cubit.submit(
      targetUserId: widget.targetUserId,
      listingId: widget.listingId,
      rating: _rating,
      comment: _commentCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return BlocProvider<SellerTrustCubit>.value(
      value: widget.cubit,
      child: BlocListener<SellerTrustCubit, SellerTrustState>(
        listenWhen: (prev, curr) =>
            prev.submitOutcome != curr.submitOutcome &&
            curr.submitOutcome != SubmitOutcome.none,
        listener: (context, state) {
          // Pop on any resolved outcome — the section host (still mounted under
          // the page) shows the snackbar from the same outcome flag.
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Material(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xl),
            ),
            child: BlocBuilder<SellerTrustCubit, SellerTrustState>(
              builder: (context, state) {
                final submitting = state.submitting;
                return SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle.
                      Center(
                        child: Container(
                          width: AppSpacing.xxl,
                          height: AppSpacing.xs,
                          margin: const EdgeInsetsDirectional.only(
                            bottom: AppSpacing.lg,
                          ),
                          decoration: BoxDecoration(
                            color: colors.outline,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                      Text(
                        l10n.reviews_write_sheet_title,
                        style: styles.titleLarge.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.reviews_write_rating_label,
                        style: styles.labelLarge.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: RatingStars.input(
                          value: _rating.toDouble(),
                          onChanged: submitting
                              ? (_) {}
                              : (v) => setState(() => _rating = v),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _commentCtrl,
                        enabled: !submitting,
                        maxLines: 4,
                        maxLength: _maxComment,
                        decoration: InputDecoration(
                          labelText: l10n.reviews_write_comment_label,
                          hintText: l10n.reviews_write_comment_hint,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: l10n.reviews_write_submit,
                        variant: AppButtonVariant.filledPrimary,
                        icon: Icons.rate_review_outlined,
                        expanded: true,
                        loading: submitting,
                        onPressed: (_rating < 1 || submitting) ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
