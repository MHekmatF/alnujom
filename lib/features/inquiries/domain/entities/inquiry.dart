import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart' show ListingStatus;
import 'inquiry_status.dart';

class Inquiry extends Equatable {
  const Inquiry({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingStatus,
    required this.senderUserId,
    required this.senderName,
    required this.decryptedPhone,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listingId;
  final String listingTitle;
  final ListingStatus listingStatus;
  final String? senderUserId;
  final String senderName;

  /// Null when the caller is not authorized OR when Vault decrypt failed
  /// (FR-026 — render the "Phone unavailable" placeholder).
  final String? decryptedPhone;
  final String message;
  final InquiryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Inquiry copyWith({InquiryStatus? status}) => Inquiry(
    id: id,
    listingId: listingId,
    listingTitle: listingTitle,
    listingStatus: listingStatus,
    senderUserId: senderUserId,
    senderName: senderName,
    decryptedPhone: decryptedPhone,
    message: message,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    listingId,
    listingTitle,
    listingStatus,
    senderUserId,
    senderName,
    decryptedPhone,
    message,
    status,
    createdAt,
    updatedAt,
  ];
}
