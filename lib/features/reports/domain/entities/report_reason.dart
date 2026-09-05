// Phase 18 (spec/018-reports-moderation) — ReportReason domain enum.
// Mirrors the `reason` CHECK constraint in public.reports (data-model §2.1).
// Zero Supabase imports (Constitution IX).
enum ReportReason {
  fakeListing('fake_listing'),
  wrongPrice('wrong_price'),
  alreadySoldOrRented('already_sold_or_rented'),
  duplicate('duplicate'),
  spam('spam'),
  wrongLocation('wrong_location'),
  inappropriateContent('inappropriate_content'),
  other('other'),
  // Plan A29 — reasons that only make sense about a PERSON.
  harassment('harassment'),
  scam('scam'),
  impersonation('impersonation');

  const ReportReason(this.wireValue);
  final String wireValue;

  static ReportReason fromWire(String v) =>
      ReportReason.values.firstWhere((e) => e.wireValue == v);

  /// What the sheet offers when reporting a listing (the original eight).
  static const List<ReportReason> listingReasons = [
    fakeListing,
    wrongPrice,
    alreadySoldOrRented,
    duplicate,
    spam,
    wrongLocation,
    inappropriateContent,
    other,
  ];

  /// What the sheet offers when reporting a person (plan A29). Mirrors the
  /// list `submit_user_report` accepts.
  static const List<ReportReason> userReasons = [
    harassment,
    scam,
    spam,
    impersonation,
    inappropriateContent,
    other,
  ];
}
