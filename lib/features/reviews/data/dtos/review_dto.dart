import '../../domain/entities/publisher_rating.dart';
import '../../domain/entities/response_stats.dart';
import '../../domain/entities/review.dart';

/// Maps a `reviews` table row → [Review].
///
/// NOTE: the `reviews` table has no reviewer display-name column and we do NOT
/// join `profiles`, so [Review.reviewerName] is left null (UI shows a localized
/// anonymous label).
class ReviewDto {
  const ReviewDto({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory ReviewDto.fromJson(Map<String, dynamic> json) {
    return ReviewDto(
      id: json['id'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Review toEntity() => Review(
    id: id,
    reviewerName: null,
    rating: rating,
    comment: comment,
    createdAt: createdAt,
  );
}

/// Maps a `v_publisher_ratings` row → [PublisherRating].
class PublisherRatingDto {
  const PublisherRatingDto({
    required this.avgRating,
    required this.reviewCount,
  });

  final double avgRating;
  final int reviewCount;

  factory PublisherRatingDto.fromJson(Map<String, dynamic> json) {
    return PublisherRatingDto(
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
    );
  }

  PublisherRating toEntity() =>
      PublisherRating(avgRating: avgRating, reviewCount: reviewCount);
}

/// Maps a `publisher_response_stats(p_user_id)` RPC row → [ResponseStats].
class ResponseStatsDto {
  const ResponseStatsDto({
    required this.total,
    this.responseRate,
    this.avgResponseHours,
  });

  final int total;
  final double? responseRate;
  final double? avgResponseHours;

  factory ResponseStatsDto.fromJson(Map<String, dynamic> json) {
    return ResponseStatsDto(
      total: (json['total_inquiries'] as num?)?.toInt() ?? 0,
      responseRate: (json['response_rate'] as num?)?.toDouble(),
      avgResponseHours: (json['avg_response_hours'] as num?)?.toDouble(),
    );
  }

  ResponseStats toEntity() => ResponseStats(
    total: total,
    responseRate: responseRate,
    avgResponseHours: avgResponseHours,
  );
}
