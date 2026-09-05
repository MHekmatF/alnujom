// Plan A34 — what kind of message a person is sending from the About screen.
// Mirrors the CHECK constraint on public.feedback.category.

enum FeedbackCategory {
  bug('bug'),
  idea('idea'),
  question('question'),
  other('other');

  const FeedbackCategory(this.wireValue);

  /// The value the `submit_feedback` RPC accepts.
  final String wireValue;
}
