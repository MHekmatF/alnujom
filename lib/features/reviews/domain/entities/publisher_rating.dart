import 'package:equatable/equatable.dart';

/// Aggregate rating for a publisher/seller, sourced from the
/// `v_publisher_ratings` view (avg_rating + review_count).
class PublisherRating extends Equatable {
  const PublisherRating({
    required this.avgRating,
    required this.reviewCount,
  });

  /// Mean of all ratings for the seller (1..5).
  final double avgRating;

  /// Number of reviews backing [avgRating].
  final int reviewCount;

  @override
  List<Object?> get props => [avgRating, reviewCount];
}
