import 'package:equatable/equatable.dart';

/// A single seller (publisher) review left by a buyer.
///
/// The `reviews` table has no reviewer display-name column (we deliberately do
/// NOT join `profiles`), so [reviewerName] is always null here — the UI shows a
/// localized anonymous label instead.
class Review extends Equatable {
  const Review({
    required this.id,
    this.reviewerName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  final String id;

  /// Always null in this MVP (no profile join) — kept on the entity so a future
  /// phase can surface a real name without a signature change.
  final String? reviewerName;

  /// 1..5 star rating.
  final int rating;

  /// Optional free-text comment.
  final String? comment;

  final DateTime createdAt;

  @override
  List<Object?> get props => [id, reviewerName, rating, comment, createdAt];
}
