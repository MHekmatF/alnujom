import 'package:equatable/equatable.dart';

import '../value_objects/account_status.dart';
import '../value_objects/publisher_status.dart';

class Profile extends Equatable {
  const Profile({
    required this.userId,
    this.fullName,
    this.username,
    this.phone,
    this.email,
    this.avatarUrl,
    required this.accountStatus,
    required this.publisherStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String? fullName;
  final String? username;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final AccountStatus accountStatus;
  final PublisherStatus publisherStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile copyWith({
    String? userId,
    String? fullName,
    String? username,
    String? phone,
    String? email,
    String? avatarUrl,
    AccountStatus? accountStatus,
    PublisherStatus? publisherStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Profile(
    userId: userId ?? this.userId,
    fullName: fullName ?? this.fullName,
    username: username ?? this.username,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    accountStatus: accountStatus ?? this.accountStatus,
    publisherStatus: publisherStatus ?? this.publisherStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    userId,
    fullName,
    username,
    phone,
    email,
    avatarUrl,
    accountStatus,
    publisherStatus,
    createdAt,
    updatedAt,
  ];
}
