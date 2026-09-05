import '../../domain/entities/permission_catalog_entry.dart';

class PermissionDto {
  const PermissionDto({
    required this.id,
    required this.key,
    required this.category,
    required this.description,
    this.descriptionAr,
  });

  factory PermissionDto.fromJson(Map<String, dynamic> json) {
    return PermissionDto(
      id: json['id'] as String,
      key: json['key'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
    );
  }

  final String id;
  final String key;
  final String category;
  final String? description;
  final String? descriptionAr;

  PermissionCatalogEntry toEntity() {
    return PermissionCatalogEntry(
      key: key,
      category: category,
      description: description,
      descriptionAr: descriptionAr,
    );
  }
}
