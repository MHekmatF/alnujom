import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/lead_event_type.dart';
import '../repositories/lead_event_repository.dart';

@injectable
class RecordLeadEvent {
  const RecordLeadEvent(this._repository);

  final LeadEventRepository _repository;

  /// Records a phone-reveal or WhatsApp-click lead event.
  /// Returns the new lead event UUID on success.
  Future<Result<String>> call({
    required String listingId,
    required LeadEventType eventType,
  }) => _repository.recordEvent(listingId: listingId, eventType: eventType);
}
