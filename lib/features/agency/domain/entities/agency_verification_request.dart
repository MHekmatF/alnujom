import 'package:equatable/equatable.dart';

enum VerificationDecision {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const VerificationDecision(this.wireValue);
  final String wireValue;
  static VerificationDecision fromWire(String v) =>
      VerificationDecision.values.firstWhere((e) => e.wireValue == v);
}

class AgencyVerificationRequest extends Equatable {
  const AgencyVerificationRequest({
    required this.id,
    required this.agencyId,
    required this.decision,
    required this.submittedAt,
    this.decisionReason,
    this.evidenceUrls,
    this.reviewedAt,
  });

  final String id;
  final String agencyId;
  final VerificationDecision decision;
  final DateTime submittedAt;
  final String? decisionReason;
  final List<String>? evidenceUrls;
  final DateTime? reviewedAt;

  @override
  List<Object?> get props => [id, agencyId, decision, decisionReason];
}
