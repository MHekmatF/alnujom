import 'package:flutter/widgets.dart' show Locale;

import '../../../../core/errors/result.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../entities/auth_failure.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

/// Domain use case: validates registration inputs and delegates to [AuthRepository].
///
/// Domain validation here (phone format, password length) is a second line of
/// defence; the page's form validators are the first.
class Register {
  const Register(this._repository);

  final AuthRepository _repository;

  Future<Result<Session>> call({
    required String rawPhone,
    required String password,
    String? fullName,
    String? optionalRealEmail,
    required Locale deviceLocale,
  }) {
    final PhoneNumber phone;
    try {
      phone = PhoneNumber.parse(rawPhone);
    } on PhoneNumberFormatException catch (e) {
      return Future.value(
        FailureResult(
          e.localizationKey == 'phone_required'
              ? const UnknownAuthError('phone_required')
              : const UnknownAuthError('phone_invalid'),
        ),
      );
    }
    if (password.length < 8) {
      return Future.value(const FailureResult(PasswordTooShort()));
    }
    return _repository.register(
      phone: phone,
      password: password,
      fullName: fullName,
      optionalRealEmail: optionalRealEmail,
      deviceLocale: deviceLocale,
    );
  }
}
