// lib/features/notifications/data/dtos/app_notification_dto.dart
//
// Phase 22 — DTO mirroring a row from `public.notifications`.
//
// Column layout:
//   id                uuid (PK)
//   recipient_user_id uuid (FK → auth.users — not projected; scoped by RLS)
//   type              text (6-value CHECK)
//   params            jsonb (UUIDs only — no PII free-text, FR-004)
//   read_at           timestamptz? (null = unread)
//   created_at        timestamptz

import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_type.dart';

/// DTO for a `public.notifications` row.
class AppNotificationDto {
  const AppNotificationDto({
    required this.id,
    required this.type,
    required this.params,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final Map<String, dynamic> params;
  final DateTime? readAt;
  final DateTime createdAt;

  factory AppNotificationDto.fromJson(Map<String, dynamic> json) {
    return AppNotificationDto(
      id: json['id'] as String,
      type: json['type'] as String,
      params: (json['params'] as Map<String, dynamic>?) ?? const {},
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts this DTO to the domain entity.
  ///
  /// Unknown [type] values default to [NotificationType.accountApproved] with
  /// a graceful fallback to prevent a crash on future server-side additions
  /// (forward-compat — the app degrades to showing an untappable tile).
  AppNotification toEntity() {
    return AppNotification(
      id: id,
      type: NotificationType.fromKey(type) ?? NotificationType.accountApproved,
      params: params,
      readAt: readAt,
      createdAt: createdAt,
    );
  }
}
