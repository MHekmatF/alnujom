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
  other('other');

  const ReportReason(this.wireValue);
  final String wireValue;

  static ReportReason fromWire(String v) =>
      ReportReason.values.firstWhere((e) => e.wireValue == v);
}
