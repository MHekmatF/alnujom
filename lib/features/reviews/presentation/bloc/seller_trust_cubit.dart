import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/publisher_rating.dart';
import '../../domain/entities/response_stats.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_failure.dart';
import '../../domain/usecases/load_seller_trust.dart';
import '../../domain/usecases/submit_review.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum SellerTrustStatus { initial, loading, loaded, error }

/// Outcome of a one-shot submit, surfaced to the page so it can show a snackbar
/// and (on success) refresh. Cleared back to [none] after the page consumes it.
enum SubmitOutcome { none, success, alreadyReviewed, error }

/// Drives the seller-trust layer: aggregate rating, responsiveness stats, and a
/// short list of recent reviews for one seller, plus a submit path.
class SellerTrustState extends Equatable {
  const SellerTrustState({
    this.status = SellerTrustStatus.initial,
    this.rating,
    this.stats,
    this.reviews = const [],
    this.ratingDistribution = const {},
    this.submitting = false,
    this.submitOutcome = SubmitOutcome.none,
  });

  final SellerTrustStatus status;
  final PublisherRating? rating;
  final ResponseStats? stats;
  final List<Review> reviews;

  /// Full-history rating distribution (star 1..5 → count); empty when no reviews.
  final Map<int, int> ratingDistribution;
  final bool submitting;
  final SubmitOutcome submitOutcome;

  /// True when there's enough responsiveness signal to render a badge.
  bool get hasResponseSignal => stats != null && stats!.hasSignal;

  /// True when the seller has at least one review backing an aggregate rating.
  bool get hasRating => rating != null && rating!.reviewCount > 0;

  SellerTrustState copyWith({
    SellerTrustStatus? status,
    PublisherRating? rating,
    ResponseStats? stats,
    List<Review>? reviews,
    Map<int, int>? ratingDistribution,
    bool? submitting,
    SubmitOutcome? submitOutcome,
  }) {
    return SellerTrustState(
      status: status ?? this.status,
      rating: rating ?? this.rating,
      stats: stats ?? this.stats,
      reviews: reviews ?? this.reviews,
      ratingDistribution: ratingDistribution ?? this.ratingDistribution,
      submitting: submitting ?? this.submitting,
      submitOutcome: submitOutcome ?? this.submitOutcome,
    );
  }

  @override
  List<Object?> get props => [
    status,
    rating,
    stats,
    reviews,
    ratingDistribution,
    submitting,
    submitOutcome,
  ];
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

/// Factory-scoped (one per detail page). Seeded with the seller's user id; call
/// [load] once and [submit] to leave a review (which reloads on success).
@injectable
class SellerTrustCubit extends Cubit<SellerTrustState> {
  SellerTrustCubit(this._loadSellerTrust, this._submitReview)
    : super(const SellerTrustState());

  final LoadSellerTrust _loadSellerTrust;
  final SubmitReview _submitReview;

  Future<void> load(String targetUserId) async {
    if (state.status == SellerTrustStatus.loading) return;
    emit(state.copyWith(status: SellerTrustStatus.loading));

    final bundle = await _loadSellerTrust(targetUserId);

    // Reviews drive the section; their failure is the only hard error. Rating +
    // stats degrade gracefully to null (chrome omitted) on a partial failure.
    final reviewsResult = bundle.reviews;
    if (reviewsResult is FailureResult<List<Review>>) {
      emit(state.copyWith(status: SellerTrustStatus.error));
      return;
    }

    final reviews = (reviewsResult as Success<List<Review>>).value;
    final rating = switch (bundle.rating) {
      Success<PublisherRating?>(:final value) => value,
      FailureResult<PublisherRating?>() => null,
    };
    final stats = switch (bundle.stats) {
      Success<ResponseStats?>(:final value) => value,
      FailureResult<ResponseStats?>() => null,
    };
    final distribution = switch (bundle.distribution) {
      Success<Map<int, int>>(:final value) => value,
      FailureResult<Map<int, int>>() => const <int, int>{},
    };

    emit(
      SellerTrustState(
        status: SellerTrustStatus.loaded,
        rating: rating,
        stats: stats,
        reviews: reviews,
        ratingDistribution: distribution,
      ),
    );
  }

  /// Inserts a review then reloads the section. Surfaces a [SubmitOutcome] for
  /// the page to show a snackbar; the page should call [clearSubmitOutcome]
  /// after consuming it.
  Future<void> submit({
    required String targetUserId,
    String? listingId,
    required int rating,
    String? comment,
  }) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, submitOutcome: SubmitOutcome.none));

    final result = await _submitReview(
      targetUserId: targetUserId,
      listingId: listingId,
      rating: rating,
      comment: comment,
    );

    switch (result) {
      case Success<void>():
        // Reload, then flag success (load() emits a fresh state, so set the
        // outcome afterwards on the reloaded state).
        await load(targetUserId);
        emit(
          state.copyWith(
            submitting: false,
            submitOutcome: SubmitOutcome.success,
          ),
        );
      case FailureResult<void>(:final failure):
        emit(
          state.copyWith(
            submitting: false,
            submitOutcome: failure is AlreadyReviewedFailure
                ? SubmitOutcome.alreadyReviewed
                : SubmitOutcome.error,
          ),
        );
    }
  }

  /// Resets the one-shot submit outcome after the page has shown its snackbar.
  void clearSubmitOutcome() {
    if (state.submitOutcome == SubmitOutcome.none) return;
    emit(state.copyWith(submitOutcome: SubmitOutcome.none));
  }
}
