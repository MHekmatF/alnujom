import 'localized_text.dart';

/// Snapshot of the `maintenance_mode` setting.
///
/// [isOn] — whether the global maintenance gate is active.
/// [message] — optional bilingual message shown on the maintenance screen.
///   May be null or carry null variants when the admin has not configured
///   a message; callers fall back to built-in l10n copy.
class MaintenanceState {
  const MaintenanceState({required this.isOn, this.message});

  /// Whether the app is in maintenance mode.
  final bool isOn;

  /// Optional bilingual admin-supplied message.
  final LocalizedText? message;

  @override
  String toString() => 'MaintenanceState(isOn: $isOn, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceState &&
          runtimeType == other.runtimeType &&
          isOn == other.isOn &&
          message == other.message;

  @override
  int get hashCode => isOn.hashCode ^ message.hashCode;
}
