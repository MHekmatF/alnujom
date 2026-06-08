// lib/features/chat/domain/usecases/list_conversations.dart
//
// In-app chat — use case: load the caller's conversations.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

@injectable
class ListConversations {
  const ListConversations(this._repository);

  final ChatRepository _repository;

  Future<Result<List<Conversation>>> call() => _repository.listConversations();
}
