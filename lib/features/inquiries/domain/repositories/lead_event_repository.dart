import '../../../../core/errors/result.dart';
import '../entities/lead_event.dart';
import '../entities/lead_event_type.dart';

abstract class LeadEventRepository {
  /// Records a phone-reveal or WhatsApp-click lead event.
  /// Returns the new lead event id on success.
  Future<Result<String>> recordEvent({
    required String listingId,
    required LeadEventType eventType,
  });

  /// Loads lead events for a listing. The datasource chooses the view tier
  /// based on the caller's role (publisher → v_lead_events_publisher,
  /// admin → v_lead_events_admin per RLS).
  ///
  /// [since] filters to events created after the given timestamp.
  Future<Result<List<LeadEvent>>> loadByListing(
    String listingId, {
    DateTime? since,
  });
}
