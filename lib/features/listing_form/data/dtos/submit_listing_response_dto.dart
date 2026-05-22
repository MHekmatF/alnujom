import 'dart:convert';

import '../../domain/entities/listing.dart';
import '../../domain/entities/submit_failure.dart';
import '../../domain/entities/submit_listing_result.dart';

/// Outcome of a `submit_listing` RPC call.
///
/// Success path: the RPC returns a JSONB row containing `listing_id`,
/// `status`, `submitted_at`. Failure path (per FR-010a / R-06): SQLSTATE
/// 22023 with a JSON `missing_fields` payload in the exception details.
sealed class SubmitListingResponseDto {
  const SubmitListingResponseDto();

  /// Parse a successful RPC response (the JSONB row Supabase returned).
  static SubmitListingResponseDto fromSuccessJson(Map<String, dynamic> json) {
    return SubmitListingSuccessDto(
      listingId: json['listing_id'] as String,
      status: json['status'] as String,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }

  /// Parse a Supabase `PostgrestException`'s `details` string into a failure
  /// DTO when SQLSTATE is `22023`. Supabase serializes the PL/pgSQL DETAIL
  /// payload as either a JSON object string (`{"missing_fields":[...]}`) or
  /// a plain string. This factory is defensive on both shapes.
  static SubmitListingFailureDto fromFailureDetails({
    required String sqlState,
    String? details,
    String? message,
  }) {
    final missingFields = _parseMissingFields(details);
    return SubmitListingFailureDto(
      sqlState: sqlState,
      missingFields: missingFields,
      message: message,
    );
  }
}

class SubmitListingSuccessDto extends SubmitListingResponseDto {
  const SubmitListingSuccessDto({
    required this.listingId,
    required this.status,
    required this.submittedAt,
  });

  final String listingId;
  final String status;
  final DateTime submittedAt;

  SubmitListingResult toEntity() {
    return SubmitListingResult(
      listingId: listingId,
      status: ListingStatusDb.fromDbValue(status),
      submittedAt: submittedAt,
    );
  }
}

class SubmitListingFailureDto extends SubmitListingResponseDto {
  const SubmitListingFailureDto({
    required this.sqlState,
    this.missingFields = const <String>[],
    this.message,
  });

  final String sqlState;
  final List<String> missingFields;
  final String? message;

  SubmitFailure toEntity() {
    return SubmitFailure(
      missingFields: missingFields,
      rawSqlState: sqlState,
      userFacingMessage: message,
    );
  }
}

List<String> _parseMissingFields(String? details) {
  if (details == null || details.isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(details);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['missing_fields'];
      if (raw is List) return raw.cast<String>();
    }
  } catch (_) {
    // Fall through to string-scan below.
  }
  // Defensive: if `details` arrives as plain text "missing_fields: [a, b]".
  final match = RegExp(r'missing_fields[^\[]*\[([^\]]+)\]').firstMatch(details);
  if (match != null) {
    return match
        .group(1)!
        .split(',')
        .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
