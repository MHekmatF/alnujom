// lib/features/inquiries/presentation/bloc/inquiries_unread_state.dart
part of 'inquiries_unread_cubit.dart';

/// State for the shared unread-count cubit.
final class InquiriesUnreadState extends Equatable {
  const InquiriesUnreadState({
    required this.count,
    required this.canShowEntry,
  });

  /// Number of status='new' inquiries on the signed-in publisher's listings.
  final int count;

  /// Whether to render the inbox entry point (AppBar action / nav badge).
  /// True when count > 0 per T072 design decision.
  final bool canShowEntry;

  @override
  List<Object?> get props => [count, canShowEntry];
}
