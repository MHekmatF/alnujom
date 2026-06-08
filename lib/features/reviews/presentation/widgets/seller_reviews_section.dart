import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/review.dart';
import '../bloc/seller_trust_cubit.dart';
import '../sheets/write_review_sheet.dart';

/// "Reviews" section for the listing-details page, rendered below the contact
/// block. Reads the page-provided [SellerTrustCubit]: a header (avg rating +
/// count), a short list of recent reviews, and a context-aware "Write a review"
/// affordance.
///
/// The cubit is provided once at the page level (seeded with the seller's id and
/// loaded there) so this widget and the contact card share one source of truth.
class SellerReviewsSection extends StatelessWidget {
  const SellerReviewsSection({
    required this.sellerId,
    required this.listingId,
    super.key,
  });

  /// The seller's user id (`listing.publisherUserId`).
  final String sellerId;

  /// The current listing id, attached to a newly-submitted review.
  final String listingId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SellerTrustCubit, SellerTrustState>(
      listenWhen: (prev, curr) =>
          prev.submitOutcome != curr.submitOutcome &&
          curr.submitOutcome != SubmitOutcome.none,
      listener: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final message = switch (state.submitOutcome) {
          SubmitOutcome.success => l10n.reviews_submit_success,
          SubmitOutcome.alreadyReviewed => l10n.reviews_submit_already_reviewed,
          SubmitOutcome.error => l10n.reviews_submit_error,
          SubmitOutcome.none => null,
        };
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        context.read<SellerTrustCubit>().clearSubmitOutcome();
      },
      builder: (context, state) {
        // Collapse silently while loading / on hard error — never block the page.
        if (state.status == SellerTrustStatus.initial ||
            state.status == SellerTrustStatus.loading ||
            state.status == SellerTrustStatus.error) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);

        final hasReviews = state.reviews.isNotEmpty;
        // Render nothing at all when there's neither a rating nor reviews and the
        // viewer can't write one — but we still want the write affordance, so we
        // only fully collapse when nothing can be shown or done.
        final canWrite = _canWrite(sellerId);

        if (!state.hasRating && !hasReviews && !canWrite) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — title + aggregate when present.
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.reviews_section_title,
                    style: styles.titleLarge.copyWith(color: colors.onSurface),
                  ),
                ),
                if (state.hasRating)
                  RatingStars(
                    value: state.rating!.avgRating,
                    showValue: true,
                  ),
              ],
            ),
            if (state.hasRating) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l10n.reviews_count(state.rating!.reviewCount),
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.md),

            // Recent reviews.
            if (hasReviews)
              ...state.reviews.map(
                (r) => Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.sm,
                  ),
                  child: _ReviewTile(review: r),
                ),
              )
            else
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  l10n.reviews_empty_hint,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ),

            const SizedBox(height: AppSpacing.sm),
            _WriteAffordance(
              sellerId: sellerId,
              listingId: listingId,
            ),
          ],
        );
      },
    );
  }

  /// The viewer may write a review only when signed in (Authenticated) AND not
  /// the seller themselves.
  static bool _canWrite(String sellerId) {
    final authState = getIt<AuthBloc>().state;
    if (authState is! Authenticated) return false;
    return authState.profile.userId != sellerId;
  }
}

// ─── Write affordance (button or sign-in hint) ────────────────────────────────

class _WriteAffordance extends StatelessWidget {
  const _WriteAffordance({required this.sellerId, required this.listingId});

  final String sellerId;
  final String listingId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final authState = getIt<AuthBloc>().state;
    final isAuthenticated = authState is Authenticated;
    final isSelf = isAuthenticated && authState.profile.userId == sellerId;

    // Seller viewing their own listing — no write affordance, no hint.
    if (isSelf) return const SizedBox.shrink();

    // Not signed in — subtle hint instead of the button.
    if (!isAuthenticated) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          l10n.reviews_sign_in_hint,
          style: styles.bodyMedium.copyWith(color: colors.textMuted),
        ),
      );
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: AppButton(
        label: l10n.reviews_write_button,
        variant: AppButtonVariant.tonal,
        icon: Icons.rate_review_outlined,
        onPressed: () => _openSheet(context),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    final cubit = context.read<SellerTrustCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WriteReviewSheet(
        cubit: cubit,
        targetUserId: sellerId,
        listingId: listingId,
      ),
    );
  }
}

// ─── Single review tile ───────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final reviewerLabel =
        (review.reviewerName != null && review.reviewerName!.isNotEmpty)
        ? review.reviewerName!
        : l10n.reviews_anonymous_reviewer;

    return AppSurface(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      radius: AppRadii.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reviewerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.labelLarge.copyWith(color: colors.onSurface),
                ),
              ),
              RatingStars(
                value: review.rating.toDouble(),
                size: AppSpacing.md,
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.comment!.trim(),
              style: styles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            _relativeDate(context, l10n, review.createdAt),
            style: styles.labelMedium.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  String _relativeDate(
    BuildContext context,
    AppLocalizations l10n,
    DateTime createdAt,
  ) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return l10n.reviews_time_just_now;
    if (diff.inMinutes < 60) return l10n.reviews_time_minutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.reviews_time_hours(diff.inHours);
    if (diff.inDays < 30) return l10n.reviews_time_days(diff.inDays);
    // Older than a month — show an absolute, locale-formatted date.
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).format(createdAt);
  }
}
