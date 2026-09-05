import 'package:equatable/equatable.dart';

class PermissionCatalogEntry extends Equatable {
  const PermissionCatalogEntry({
    required this.key,
    required this.category,
    required this.description,
    this.descriptionAr,
  });

  final String key;
  final String category;
  final String? description;

  /// Plan A33 — the Arabic description from the database; null falls back to
  /// [description].
  final String? descriptionAr;

  /// The description for [languageCode], falling back across languages and
  /// finally to the key.
  String labelFor(String languageCode) {
    final ar = descriptionAr?.trim();
    final en = description?.trim();
    if (languageCode == 'ar' && ar != null && ar.isNotEmpty) return ar;
    if (en != null && en.isNotEmpty) return en;
    if (ar != null && ar.isNotEmpty) return ar;
    return key;
  }

  @override
  List<Object?> get props => [key, category, description, descriptionAr];
}
