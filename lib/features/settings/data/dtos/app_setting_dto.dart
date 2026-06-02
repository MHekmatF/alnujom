import 'dart:ui';

import 'package:alnujom/features/listing_form/domain/entities/listing.dart';

import '../../domain/entities/app_setting.dart';
import '../../domain/entities/app_setting_key.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/localized_text.dart';
import '../../domain/entities/maintenance_state.dart';
import '../../domain/entities/support_contact.dart';

/// Data-transfer object for a single `public.app_settings` row returned by
/// Supabase PostgREST.
///
/// [fromJson] parses the raw `Map<String, dynamic>` row.
/// [toDomain] converts to the domain [AppSetting] entity.
/// [toAppSettings] is a static helper that converts a list of DTOs into the
///   typed [AppSettings] aggregate.
class AppSettingDto {
  const AppSettingDto({
    required this.key,
    required this.value,
    required this.isPublic,
    required this.updatedAt,
  });

  factory AppSettingDto.fromJson(Map<String, dynamic> json) {
    return AppSettingDto(
      key: json['key'] as String,
      value: json['value'],
      isPublic: json['is_public'] as bool? ?? true,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String key;

  /// Raw decoded JSONB value (String, bool, Map, int, null, etc.).
  final Object? value;

  final bool isPublic;
  final DateTime updatedAt;

  /// Convert to the domain [AppSetting] entity.
  AppSetting toDomain() {
    return AppSetting(
      key: key,
      value: value ?? const <String, dynamic>{},
      isPublic: isPublic,
      updatedAt: updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Per-key value decoders (used by [toAppSettings]).
  // All are defensive — missing/null values fall back to the safe default.
  // ---------------------------------------------------------------------------

  static Locale _decodeLocale(Object? raw) {
    final code = raw as String?;
    if (code == null || code.isEmpty) return const Locale('ar');
    return Locale(code);
  }

  static String _decodeCurrencyCode(Object? raw) {
    final code = raw as String?;
    if (code == null || code.isEmpty) return 'SYP';
    return code;
  }

  static ContactNameVisibility _decodeContactNameVisibility(Object? raw) {
    final v = raw as String?;
    if (v == null) return ContactNameVisibility.public;
    try {
      return ContactNameVisibilityDb.fromDbValue(v);
    } catch (_) {
      return ContactNameVisibility.public;
    }
  }

  static LocationVisibility _decodeLocationVisibility(Object? raw) {
    final v = raw as String?;
    if (v == null) return LocationVisibility.approximate;
    try {
      return LocationVisibilityDb.fromDbValue(v);
    } catch (_) {
      return LocationVisibility.approximate;
    }
  }

  static MaintenanceState _decodeMaintenanceState(Object? raw) {
    if (raw is! Map) return const MaintenanceState(isOn: false);
    final map = Map<String, dynamic>.from(raw);
    final isOn = map['on'] as bool? ?? false;
    final msgRaw = map['message'];
    LocalizedText? message;
    if (msgRaw is Map) {
      final msgMap = Map<String, dynamic>.from(msgRaw);
      message = LocalizedText(
        ar: msgMap['ar'] as String?,
        en: msgMap['en'] as String?,
      );
    }
    return MaintenanceState(isOn: isOn, message: message);
  }

  static SupportContact _decodeSupportContact(Object? raw) {
    if (raw is! Map) return const SupportContact();
    final map = Map<String, dynamic>.from(raw);
    return SupportContact(
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      email: map['email'] as String?,
    );
  }

  static String? _decodeNullableString(Object? raw) {
    if (raw == null) return null;
    final s = raw as String?;
    if (s == null || s.isEmpty) return null;
    return s;
  }

  // ---------------------------------------------------------------------------
  // Aggregate builder.
  // ---------------------------------------------------------------------------

  /// Build a typed [AppSettings] snapshot from a list of DTOs.
  ///
  /// Keys absent from [dtos] (e.g. because RLS filtered them) fall back to
  /// the same safe defaults used by [AppSettings.safeDefaults].
  static AppSettings toAppSettings(List<AppSettingDto> dtos) {
    final byKey = {for (final dto in dtos) dto.key: dto.value};

    return AppSettings(
      defaultLocale: _decodeLocale(byKey[AppSettingKey.defaultLanguage.key]),
      defaultCurrency: _decodeCurrencyCode(
        byKey[AppSettingKey.defaultCurrency.key],
      ),
      defaultPublisherNameVisibility: _decodeContactNameVisibility(
        byKey[AppSettingKey.defaultPublisherNameVisibility.key],
      ),
      defaultLocationVisibility: _decodeLocationVisibility(
        byKey[AppSettingKey.defaultLocationVisibility.key],
      ),
      maintenance: _decodeMaintenanceState(
        byKey[AppSettingKey.maintenanceMode.key],
      ),
      supportContact: _decodeSupportContact(
        byKey[AppSettingKey.supportContact.key],
      ),
      termsUrl: _decodeNullableString(byKey[AppSettingKey.termsUrl.key]),
      privacyUrl: _decodeNullableString(byKey[AppSettingKey.privacyUrl.key]),
    );
  }
}
