<!-- SPECKIT START -->
Current phase: **delivery preparation** — not a feature spec. The app is
feature-complete at `1.1.0+2`; what remains is getting it into users' hands.

**Read first:** [`docs/ops/PENDING_MIGRATIONS.md`](docs/ops/PENDING_MIGRATIONS.md)
and [`docs/ops/HANDOVER.md`](docs/ops/HANDOVER.md).

## The state of things

- **The Supabase project is paused** (free tier, auto-pauses after ~7 days idle).
  It must be restored from the dashboard by the owner — it is not under the
  MCP-connected account, so no MCP admin call can list or restore it. Until it is
  back, nothing can be verified against live data and the app degrades to error
  states everywhere. A keep-alive workflow
  (`.github/workflows/supabase-keepalive.yml`) prevents a repeat, once its two
  repository secrets exist.
- **Four migrations are written but never applied.** Their order matters and one
  of them must not be applied until users have a new build. See
  `PENDING_MIGRATIONS.md` — do not apply them ad hoc.
- **Distribution is Telegram**, with Google Play intended later. Play is gated on
  whether a Play Console account can be opened from Syria at all; see
  `docs/release/google-play-readiness.md`. A Play build must be an AAB and must
  pass `--dart-define=IN_APP_UPDATE_PROMPT=false`, or the sideload update prompt
  violates Play policy.

## Hard constraints

- **Toolchain:** Flutter 3.44.8. The pubspec no longer pins an exact version, but
  `pub get` is sensitive to the analyzer/test constraint chain — if you change a
  dev dependency, re-resolve before assuming anything builds.
- **Arabic-first, RTL, light + dark.** Every user-visible string is a key in BOTH
  `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`, plus a matching `@override` in
  `_DebugAppLocalizations` (`lib/core/localization/app_strings.dart`) or analysis
  fails. Use `EdgeInsetsDirectional` and `start`/`end`, never `left`/`right`.
- **Design tokens only** — `lib/core/theme/*`. No raw colours, spacing or text
  styles. See `DESIGN.md`.
- **Constitution IX:** no `package:supabase_flutter` import under any `domain/`
  folder.
- **No new automated tests** until the MVP ships (owner's standing instruction).
  228 pass and 13 fail today; the failures are a known pre-existing cluster
  (`flutter_animate` pending timers, goldens, theme gallery) and are not a gate.
- **Builds need the dart-defines:** every `flutter run` / `build` takes
  `--dart-define-from-file=.env.json`, or Supabase never initialises.
  `android/app/google-services.json` is gitignored and build-machine-only — a
  release build without it ships with no push at all, and now warns loudly.

## Verify suite — all four must pass before any commit

```
flutter analyze
dart run tool/lint_design_tokens.dart
dart run tool/lint_l10n_parity.dart
dart run tool/lint_l10n_literals.dart
```

CI is paused, so this local run is the only gate.

## Where the history lives

`specs/` holds phases 001–035 with a `DEFERRED.md` per spec recording what was
intentionally left. `docs/qa/e2e-2026-07-16/` is the July security and QA pass —
`SECURITY_AUDIT.md` there is still the authority on the app's security posture.
`REVIEW.md` is the Phase-35 redesign's open-questions list. `docs/release/` holds
the release record and the Play checklist.
<!-- SPECKIT END -->
