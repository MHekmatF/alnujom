// lib/features/chat/domain/usecases/mark_conversation_read.dart
//
// In-app chat — use case: mark the counterpart's messages in a thread read.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/chat_repository.dart';

@injectable
class MarkConversationRead {
  const MarkConversationRead(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call(String conversationId) =>
      _repository.markRead(conversationId);
}
