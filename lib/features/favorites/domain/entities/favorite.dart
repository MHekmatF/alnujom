import 'package:equatable/equatable.dart';

/// Phase 17 — the cross-layer primitive representing a single saved listing.
///
/// [listingId] is the UUID of the saved listing.
/// [createdAt] is when the row was inserted in `public.favorites` (UTC).
class Favorite extends Equatable {
  const Favorite({required this.listingId, required this.createdAt});

  final String listingId;
  final DateTime createdAt;

  @override
  List<Object?> get props => [listingId, createdAt];
}
