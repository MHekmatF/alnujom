const bool kDesignToolsEnabled = bool.fromEnvironment(
  'DESIGN_TOOLS',
  defaultValue: false,
);

/// Whether the app may offer its own update, by checking the release manifest
/// and prompting the user to download a new build.
///
/// Defaults to `true`, which is correct for the Telegram distribution the app
/// ships through today.
///
/// It MUST be turned off for any build submitted to Google Play. Play forbids an
/// app from prompting the user to install an APK from outside the store, and
/// doing so is a common cause of removal. Build a Play release with:
///
///     flutter build appbundle --release \
///       --dart-define-from-file=.env.json \
///       --dart-define=IN_APP_UPDATE_PROMPT=false
///
/// See docs/release/google-play-readiness.md.
const bool kInAppUpdatePromptEnabled = bool.fromEnvironment(
  'IN_APP_UPDATE_PROMPT',
  defaultValue: true,
);
