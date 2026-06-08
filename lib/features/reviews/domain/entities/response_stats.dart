import 'package:equatable/equatable.dart';

/// Inquiry-response responsiveness for a publisher/seller, sourced from the
/// `publisher_response_stats(p_user_id)` RPC.
///
/// [responseRate] is a 0..1 fraction (nullable when there's nothing to divide
/// by) and [avgResponseHours] is the mean hours-to-first-response (nullable).
/// [total] is the total inquiries the seller has received — the meaningfulness
/// gate (`total > 0`) for surfacing any of these stats.
class ResponseStats extends Equatable {
  const ResponseStats({
    required this.total,
    this.responseRate,
    this.avgResponseHours,
  });

  /// Total inquiries received by the seller.
  final int total;

  /// Fraction of inquiries the seller responded to (0..1). Null when unknown.
  final double? responseRate;

  /// Mean hours to first response. Null when unknown.
  final double? avgResponseHours;

  /// Whether there's enough signal to surface a responsiveness badge.
  bool get hasSignal => total > 0;

  @override
  List<Object?> get props => [total, responseRate, avgResponseHours];
}
