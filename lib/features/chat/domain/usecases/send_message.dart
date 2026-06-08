// lib/features/chat/domain/usecases/send_message.dart
//
// In-app chat — use case: send a message into a conversation.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/chat_repository.dart';

@injectable
class SendMessage {
  const SendMessage(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String conversationId,
    required String body,
  }) => _repository.sendMessage(conversationId: conversationId, body: body);
}
