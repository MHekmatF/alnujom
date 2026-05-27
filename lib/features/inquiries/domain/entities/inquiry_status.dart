/// FR-013, FR-021a, Q2=B, Q3=B
enum InquiryStatus {
  /// Newly submitted; no publisher action yet.
  new_,

  /// Publisher has opened it (auto-transition on detail-page read).
  seen,

  /// Publisher has called/WhatsApp'd or otherwise replied out-of-band.
  responded,

  /// Publisher has marked it done; soft-terminal (can reopen per Q2=B).
  closed,

  /// Admin-flagged (Phase 16 has no publisher-side write path per Q3=B).
  spam;

  /// Per Q2=B + Q3=B: forward + closed-reopen + any-to-spam.
  static const Map<InquiryStatus, Set<InquiryStatus>> _allowed = {
    InquiryStatus.new_: {InquiryStatus.seen, InquiryStatus.spam},
    InquiryStatus.seen: {
      InquiryStatus.responded,
      InquiryStatus.closed,
      InquiryStatus.spam,
    },
    InquiryStatus.responded: {
      InquiryStatus.closed,
      InquiryStatus.seen,
      InquiryStatus.spam,
    },
    InquiryStatus.closed: {
      InquiryStatus.seen,
      InquiryStatus.responded,
      InquiryStatus.spam,
    },
    InquiryStatus.spam: <InquiryStatus>{}, // terminal — no publisher-side path out
  };

  /// Returns the set of statuses this status can transition to.
  Set<InquiryStatus> get allowedTransitions => _allowed[this]!;

  /// Wire-format mapping used by DTO serialization.
  String get wireValue => switch (this) {
    InquiryStatus.new_ => 'new',
    InquiryStatus.seen => 'seen',
    InquiryStatus.responded => 'responded',
    InquiryStatus.closed => 'closed',
    InquiryStatus.spam => 'spam',
  };

  static InquiryStatus fromWire(String s) => switch (s) {
    'new' => InquiryStatus.new_,
    'seen' => InquiryStatus.seen,
    'responded' => InquiryStatus.responded,
    'closed' => InquiryStatus.closed,
    'spam' => InquiryStatus.spam,
    _ => throw ArgumentError('Unknown inquiry status: $s'),
  };
}
