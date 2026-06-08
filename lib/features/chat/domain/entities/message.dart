// lib/features/chat/domain/entities/message.dart
//
// In-app chat — domain entity for one message in a thread.

/// Immutable domain representation of a `public.messages` row.
class Message {
  const Message({
    required this.id,
    required this.body,
    required this.isMine,
    required this.createdAt,
    this.readAt,
  });

  /// UUID primary key.
  final String id;

  final String body;

  /// `true` when the signed-in user is the sender (own bubble, end-aligned).
  final bool isMine;

  final DateTime createdAt;

  /// `null` means the counterpart has not read this (own) message yet.
  final DateTime? readAt;

  @override
  String toString() => 'Message(id: $id, isMine: $isMine)';
}
