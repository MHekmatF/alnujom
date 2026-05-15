import 'package:equatable/equatable.dart';

import '../../../../shared/domain/value_objects/phone_number.dart';

/// Credentials value object (Phase 5 FR-001 / FR-011).
class Credentials extends Equatable {
  const Credentials({required this.phone, required this.password});

  final PhoneNumber phone;
  final String password;

  @override
  List<Object?> get props => [phone, password];
}
