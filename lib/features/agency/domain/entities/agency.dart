import 'package:equatable/equatable.dart';

import 'agency_status.dart';

class Agency extends Equatable {
  const Agency({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.description,
    this.phone,
    this.whatsapp,
    this.address,
    this.logoPath,
    this.coverPath,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final AgencyStatus status;
  final DateTime createdAt;
  final String? description;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? logoPath;
  final String? coverPath;

  @override
  List<Object?> get props => [id, ownerUserId, name, status];
}
