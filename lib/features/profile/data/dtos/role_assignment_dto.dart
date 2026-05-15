import '../../domain/entities/assigned_role.dart';

/// Supabase-shape DTO for a `user_roles → roles(key, display_name, is_system)` row.
///
/// Supabase returns the nested join as:
/// `{ 'role': { 'key': '...', 'display_name': {...}, 'is_system': true } }`.
class RoleAssignmentDto {
  const RoleAssignmentDto({
    required this.roleKey,
    required this.displayNameJson,
    required this.isSystem,
  });

  final String roleKey;
  final Map<String, dynamic> displayNameJson;
  final bool isSystem;

  factory RoleAssignmentDto.fromRow(Map<String, dynamic> row) {
    final role = (row['role'] as Map<String, dynamic>?) ?? const {};
    final key = (role['key'] as String?) ?? '';
    final displayName =
        (role['display_name'] as Map<String, dynamic>?) ?? const {};
    final isSystem = (role['is_system'] as bool?) ?? true;
    return RoleAssignmentDto(
      roleKey: key,
      displayNameJson: displayName,
      isSystem: isSystem,
    );
  }

  /// Resolves the display name with locale fallback per FR-017:
  /// active-locale value → any other-locale value → [roleKey].
  AssignedRole toAssignedRole(String localeCode) {
    final primary = displayNameJson[localeCode] as String?;
    final fallback = displayNameJson.values.whereType<String>().firstOrNull;
    return AssignedRole(
      roleKey: roleKey,
      displayName: primary ?? fallback ?? roleKey,
      isSystem: isSystem,
    );
  }
}
