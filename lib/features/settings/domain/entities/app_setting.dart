/// A single catalog row from `public.app_settings`.
///
/// [key] — the primary key (wire string).
/// [value] — decoded JSON value (String, bool, Map, etc.).
/// [isPublic] — whether this key is visible to non-`settings.manage` users.
/// [updatedAt] — last-modified timestamp.
class AppSetting {
  const AppSetting({
    required this.key,
    required this.value,
    required this.isPublic,
    required this.updatedAt,
  });

  final String key;
  final Object value;
  final bool isPublic;
  final DateTime updatedAt;

  @override
  String toString() =>
      'AppSetting(key: $key, isPublic: $isPublic, updatedAt: $updatedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSetting &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          isPublic == other.isPublic &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      key.hashCode ^ value.hashCode ^ isPublic.hashCode ^ updatedAt.hashCode;
}
