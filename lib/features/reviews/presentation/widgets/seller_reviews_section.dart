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
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
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
          AppToast.show(
            context,
            message,
            variant: switch (state.submitOutcome) {
              SubmitOutcome.success => AppToastVariant.success,
              SubmitOutcome.error => AppToastVariant.error,
              _ => AppToastVariant.info,
            },
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
                    style: styles.titleMedium.copyWith(color: colors.onSurface),
                  ),
                ),
                if (state.hasRating)
                  RatingStars(value: state.rating!.avgRating, showValue: true),
              ],
            ),
            if (state.hasRating) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l10n.reviews_count(state.rating!.reviewCount),
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
              ),
              _RatingDistribution(distribution: state.ratingDistribution),
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
            _WriteAffordance(sellerId: sellerId, listingId: listingId),
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

// ─── Rating distribution bars ─────────────────────────────────────────────────

/// A 5-row star-rating breakdown (5★ → 1★): each row is a star-count label, a
/// proportional bar, and the count. Full-history counts from
/// `publisher_rating_distribution`. Collapses when there are no reviews.
class _RatingDistribution extends StatelessWidget {
  const _RatingDistribution({required this.distribution});

  final Map<int, int> distribution;

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) return const SizedBox.shrink();
    final maxCount = distribution.values.fold<int>(0, (m, v) => v > m ? v : m);

    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (final star in const [5, 4, 3, 2, 1]) ...[
            if (star != 5) const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatLocalizedNumber(star, locale),
                        style: styles.labelMedium.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Icon(Icons.star, size: AppSpacing.md, color: colors.warning),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ClipRRect(
                    borderRadius: appRadius(AppRadii.pill),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(color: colors.surfaceVariant),
                          ),
                          FractionallySizedBox(
                            widthFactor: maxCount == 0
                                ? 0
                                : (distribution[star] ?? 0) / maxCount,
                            child: ColoredBox(color: colors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 28,
                  child: Text(
                    formatLocalizedNumber(distribution[star] ?? 0, locale),
                    textAlign: TextAlign.end,
                    style: styles.labelMedium.copyWith(color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
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
    final initial = reviewerLabel.trim().isEmpty
        ? '؟'
        : reviewerLabel.trim().substring(0, 1);

    // DC review card: flat surface + hairline (no shadow), a tonal avatar-initial,
    // name + stars, a trailing time, and the comment beneath.
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: styles.labelLarge.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reviewerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.labelLarge.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    RatingStars(
                      value: review.rating.toDouble(),
                      size: AppSpacing.md,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _relativeDate(context, l10n, review.createdAt),
                style: styles.labelMedium.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.comment!.trim(),
              style: styles.bodyMedium.copyWith(color: colors.onSurface),
            ),
          ],
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
