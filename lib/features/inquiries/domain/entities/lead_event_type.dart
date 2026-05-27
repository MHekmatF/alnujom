/// FR-014; favoriteAdded reserved for Phase 17.
enum LeadEventType {
  phoneRevealed,
  whatsappClicked,
  inquirySent,

  /// Reserved for Phase 17. Phase 16 has no write path to this event.
  favoriteAdded;

  String get wireValue => switch (this) {
    LeadEventType.phoneRevealed => 'phone_revealed',
    LeadEventType.whatsappClicked => 'whatsapp_clicked',
    LeadEventType.inquirySent => 'inquiry_sent',
    LeadEventType.favoriteAdded => 'favorite_added',
  };

  static LeadEventType fromWire(String s) => switch (s) {
    'phone_revealed' => LeadEventType.phoneRevealed,
    'whatsapp_clicked' => LeadEventType.whatsappClicked,
    'inquiry_sent' => LeadEventType.inquirySent,
    'favorite_added' => LeadEventType.favoriteAdded,
    _ => throw ArgumentError('Unknown lead event type: $s'),
  };
}
