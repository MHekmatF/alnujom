// Plan A29 — who the OTHER person in a conversation is, so the thread can
// offer "report" and "block" on them. The list page knows this already; the
// thread is also reached straight from a listing, where it does not, so the
// cubit asks here on open.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/chat_repository.dart';

@injectable
class LoadConversationCounterpart {
  const LoadConversationCounterpart(this._repository);

  final ChatRepository _repository;

  /// The counterpart's user id, or null when the conversation is not visible
  /// to the caller.
  Future<Result<String?>> call(String conversationId) =>
      _repository.loadCounterpartUserId(conversationId);
}
