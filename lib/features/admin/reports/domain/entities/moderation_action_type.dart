// Phase 18 (spec/018-reports-moderation) — T030
// ModerationActionType: the four admin actions available when resolving a
// report. Maps to the `action` CHECK constraint in public.moderation_actions
// (data-model §2.4). Zero Supabase imports (Constitution IX).
enum ModerationActionType {
  dismiss('dismiss'),
  hide('hide'),
  markDuplicate('mark_duplicate'),
  delete('delete');

  const ModerationActionType(this.wireValue);

  /// The snake_case string sent to the `resolve_report` Edge Function body
  /// and stored in `moderation_actions.action`.
  final String wireValue;

  /// True for actions that take the listing off the public surface.
  /// Used to gate the destructive-action confirmation dialog (FR-017)
  /// and the sibling auto-resolve logic (FR-016).
  bool get isListingAffecting => this != ModerationActionType.dismiss;

  static ModerationActionType fromWire(String v) =>
      ModerationActionType.values.firstWhere((e) => e.wireValue == v);
}
