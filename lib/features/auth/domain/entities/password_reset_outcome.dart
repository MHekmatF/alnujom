/// What the server could do with a password-reset request.
///
/// The reset request used to answer the same way for every phone number, so an
/// observer could not learn who has an account. That protection was traded away
/// deliberately (owner's decision, 2026-09-01): in an app where the large
/// majority of accounts are phone-only and can never receive a reset mail,
/// "check your email" was false for almost everyone, and the screen had no way
/// to tell a user what to actually do.
enum PasswordResetOutcome {
  /// The account exists and has a real email; a reset mail was dispatched.
  sent,

  /// The account exists but is phone-only — there is no mailbox to send to, so
  /// the user has to go through support.
  noEmail,

  /// No account is registered with that phone number.
  notFound;

  static PasswordResetOutcome fromStatus(String status) => switch (status) {
    'sent' => PasswordResetOutcome.sent,
    'no_email' => PasswordResetOutcome.noEmail,
    _ => PasswordResetOutcome.notFound,
  };
}
