import '../../../listing_form/domain/entities/listing.dart' show ListingStatusDb;
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';

/// DTO mirroring a row from `public.v_inquiries_inbox`.
///
/// Columns projected by the view (11 columns):
///   id, listing_id, listing_title, listing_status,
///   sender_user_id, sender_name, message, status,
///   created_at, updated_at, inquirer_phone_decrypted (nullable).
class InquiryDto {
  const InquiryDto({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingStatus,
    required this.senderUserId,
    required this.senderName,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.inquirerPhoneDecrypted,
  });

  final String id;
  final String listingId;
  final String listingTitle;
  final String listingStatus;
  final String? senderUserId;
  final String senderName;
  final String message;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null when the caller is not authorized or Vault decrypt failed (FR-026).
  final String? inquirerPhoneDecrypted;

  factory InquiryDto.fromJson(Map<String, dynamic> json) {
    return InquiryDto(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      listingTitle: json['listing_title'] as String,
      listingStatus: json['listing_status'] as String,
      senderUserId: json['sender_user_id'] as String?,
      senderName: json['sender_name'] as String,
      message: json['message'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      inquirerPhoneDecrypted: json['inquirer_phone_decrypted'] as String?,
    );
  }

  Inquiry toEntity() {
    return Inquiry(
      id: id,
      listingId: listingId,
      listingTitle: listingTitle,
      listingStatus: ListingStatusDb.fromDbValue(listingStatus),
      senderUserId: senderUserId,
      senderName: senderName,
      decryptedPhone: inquirerPhoneDecrypted,
      message: message,
      status: InquiryStatus.fromWire(status),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
