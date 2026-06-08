// lib/features/chat/domain/usecases/watch_messages.dart
//
// In-app chat — use case: subscribe to a thread's live message stream.

import 'package:injectable/injectable.dart';

import '../entities/message.dart';
import '../repositories/chat_repository.dart';

@injectable
class WatchMessages {
  const WatchMessages(this._repository);

  final ChatRepository _repository;

  Stream<List<Message>> call(String conversationId) =>
      _repository.watchMessages(conversationId);
}
