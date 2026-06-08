// lib/features/chat/domain/usecases/get_or_create_conversation.dart
//
// In-app chat — use case: open (or create) the conversation for a listing.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/chat_repository.dart';

@injectable
class GetOrCreateConversation {
  const GetOrCreateConversation(this._repository);

  final ChatRepository _repository;

  Future<Result<String>> call(String listingId) =>
      _repository.getOrCreateConversation(listingId);
}
