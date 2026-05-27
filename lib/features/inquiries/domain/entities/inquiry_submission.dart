import 'package:equatable/equatable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';

class InquirySubmission extends Equatable {
  const InquirySubmission._({
    required this.listingId,
    required this.senderName,
    required this.phone,
    required this.message,
  });

  final String listingId;
  final String senderName;

  /// E.164 validated phone number.
  final String phone;
  final String message;

  /// Validates the submission inputs and returns a [Success] wrapping an
  /// [InquirySubmission] or a [FailureResult] wrapping a [ValidationFailure].
  ///
  /// Validation order:
  ///   1. senderName trimmed length in 1..100
  ///   2. phone parseable as E.164 via [PhoneNumber.tryParse]
  ///   3. message trimmed length in 1..2000
  static Result<InquirySubmission> validate({
    required String listingId,
    required String senderName,
    required String phone,
    required String message,
  }) {
    final trimmedName = senderName.trim();
    if (trimmedName.isEmpty || trimmedName.length > 100) {
      return const FailureResult(ValidationFailure('invalid_sender_name'));
    }
    final phoneE164 = PhoneNumber.tryParse(phone);
    if (phoneE164 == null) {
      return const FailureResult(ValidationFailure('invalid_phone'));
    }
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty || trimmedMessage.length > 2000) {
      return const FailureResult(ValidationFailure('invalid_message_length'));
    }
    return Success(
      InquirySubmission._(
        listingId: listingId,
        senderName: trimmedName,
        phone: phoneE164.e164,
        message: trimmedMessage,
      ),
    );
  }

  @override
  List<Object?> get props => [listingId, senderName, phone, message];
}
