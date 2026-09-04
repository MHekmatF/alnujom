// lib/features/chat/domain/repositories/chat_repository.dart
//
// In-app chat — abstract contract for conversation + message access.
// Implemented by ChatRepositoryImpl (data layer).

import '../../../../core/errors/result.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';

/// Repository for the `conversations` + `messages` tables.
///
/// All reads/writes are RLS-scoped to conversation participants. The current
/// user id (used to compute `isMine` / `otherIsPublisher`) is sourced from the
/// authenticated Supabase session inside the data layer.
abstract interface class ChatRepository {
  /// The signed-in user id, or `null` when signed out. Exposed so presentation
  /// can compare without reaching into the data layer's Supabase client.
  String? get currentUserId;

  /// Loads the caller's conversations, newest-activity-first.
  Future<Result<List<Conversation>>> listConversations();

  /// A live stream of a thread's newest messages, **newest-first** and capped
  /// at one page (Plan A19). The stream itself is not wrapped in [Result] —
  /// subscription errors surface via the cubit's `onError`.
  Stream<List<Message>> watchMessages(String conversationId);

  /// One page of history strictly older than [before], newest-first. An empty
  /// or short page means the thread has been read to its beginning.
  Future<Result<List<Message>>> loadOlderMessages({
    required String conversationId,
    required DateTime before,
  });

  /// Sends a message into [conversationId].
  Future<Result<void>> sendMessage({
    required String conversationId,
    required String body,
  });

  /// Opens (or creates) the conversation for [listingId]; returns its id.
  Future<Result<String>> getOrCreateConversation(String listingId);

  /// Marks the counterpart's unread messages in [conversationId] as read.
  Future<Result<void>> markRead(String conversationId);
}
