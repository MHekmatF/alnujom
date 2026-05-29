// Phase 18 (spec/018-reports-moderation) — ReportStatus domain enum.
// Mirrors the `status` CHECK constraint in public.reports (data-model §2.2).
// Zero Supabase imports (Constitution IX).
enum ReportStatus {
  newReport('new'),
  reviewing('reviewing'),
  resolved('resolved'),
  dismissed('dismissed');

  const ReportStatus(this.wireValue);
  final String wireValue;

  bool get isOpen =>
      this == ReportStatus.newReport || this == ReportStatus.reviewing;

  static ReportStatus fromWire(String v) =>
      ReportStatus.values.firstWhere((e) => e.wireValue == v);
}
