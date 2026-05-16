import 'package:equatable/equatable.dart';

class PermissionCatalogEntry extends Equatable {
  const PermissionCatalogEntry({
    required this.key,
    required this.category,
    required this.description,
  });

  final String key;
  final String category;
  final String? description;

  @override
  List<Object?> get props => [key, category, description];
}
