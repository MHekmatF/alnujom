import 'package:equatable/equatable.dart';

/// A single role assigned to the current user (read-only, FR-017).
///
/// Constitution IX: no Supabase imports.
class AssignedRole extends Equatable {
  const AssignedRole({
    required this.roleKey,
    required this.displayName,
    required this.isSystem,
  });

  final String roleKey;
  final String displayName;
  final bool isSystem;

  @override
  List<Object?> get props => [roleKey, displayName, isSystem];
}
