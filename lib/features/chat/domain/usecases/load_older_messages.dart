// lib/features/chat/domain/usecases/load_older_messages.dart
//
// In-app chat — use case: fetch one page of history older than a cursor.
//
// Plan A19. The live stream only carries the newest page; this is how the
// thread reaches back past it.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/message.dart';
import '../repositories/chat_repository.dart';

@injectable
class LoadOlderMessages {
  const LoadOlderMessages(this._repository);

  final ChatRepository _repository;

  /// Messages strictly older than [before], newest-first. A page shorter than
  /// the page size means the caller has reached the start of the thread.
  Future<Result<List<Message>>> call({
    required String conversationId,
    required DateTime before,
  }) => _repository.loadOlderMessages(
    conversationId: conversationId,
    before: before,
  );
}
