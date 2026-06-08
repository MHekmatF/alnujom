// lib/features/chat/data/dtos/message_dto.dart
//
// In-app chat — DTO mirroring a row from `public.messages`.
//
// Column layout (messages):
//   id               uuid (PK)
//   conversation_id  uuid
//   sender_user_id   uuid (DB-defaulted to auth.uid() on insert — never set it)
//   body             text (1..2000)
//   created_at       timestamptz
//   read_at          timestamptz? (null = unread)

import '../../domain/entities/message.dart';

/// DTO for a `public.messages` row.
class MessageDto {
  const MessageDto({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    return MessageDto(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderUserId: json['sender_user_id'] as String,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
    );
  }

  /// Maps to the domain entity. [currentUserId] decides `isMine`.
  Message toEntity(String currentUserId) {
    return Message(
      id: id,
      body: body,
      isMine: senderUserId == currentUserId,
      createdAt: createdAt,
      readAt: readAt,
    );
  }
}
