<!-- SPECKIT START -->
Current phase: **delivery preparation** — not a feature spec. The app is
feature-complete at `1.1.0+2`; what remains is getting it into users' hands.

**Read first:** [`docs/ops/PENDING_MIGRATIONS.md`](docs/ops/PENDING_MIGRATIONS.md)
and [`docs/ops/HANDOVER.md`](docs/ops/HANDOVER.md).

## The state of things

- **The Supabase project is live.** It briefly looked paused during the
  2026-09-01 session, but that was a DNS failure on the build machine — `nslookup`
  there still fails while `curl` and the MCP tools work. Verify from a second
  network before ever concluding the project is down. Note the project is **not**
  under the MCP-connected account, so account-level actions (pause/restore/list)
  are owner-only dashboard operations. A keep-alive workflow
  (`.github/workflows/supabase-keepalive.yml`) guards against a real free-tier
  pause, once its two repository secrets exist.
- **Two migrations are applied, two are held back on purpose.** See
  `PENDING_MIGRATIONS.md` before touching the database — one of the held-back
  ones must not land until users have a new build, and the other has a trade-off
  the owner has to weigh.
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

## Verify suite — all six must pass before any commit

```
flutter analyze
dart run tool/lint_design_tokens.dart
dart run tool/lint_l10n_parity.dart
dart run tool/lint_l10n_literals.dart
dart run tool/lint_di_graph.dart
dart run tool/lint_public_routes.dart
```

The last two exist because the same failure keeps happening: something is wrong
in a way nothing reports, and a user finds it instead of the build.

`lint_di_graph` — `injectable` does **not** check that everything the generated
injector resolves is also registered. A class asking for a collaborator that was
never annotated `@injectable` builds green and throws at runtime. In a release
build that is a blank screen and nothing in the log, since the crash reporter is
inert without a DSN.

`lint_public_routes` — `app_router.dart` and `auth_redirect.dart` disagree
silently. A `GoRoute` with no `redirect:` reads as public, but the global
`authRedirect` still runs on every navigation and bounces anything it does not
recognise to `/login`. Three separate batches of screens shipped that way
(`/search` + `/map`, then `/agency/:id`, then `/settings` + `/assistant` +
`/reels`). Mark a guest-reachable route `Anonymous-accessible` in the comment
above it and this linter will hold the redirect to it.

CI is paused, so this local run is the only gate.

## Where the history lives

`specs/` holds phases 001–035 with a `DEFERRED.md` per spec recording what was
intentionally left. `docs/qa/e2e-2026-07-16/` is the July security and QA pass —
`SECURITY_AUDIT.md` there is still the authority on the app's security posture.
`REVIEW.md` is the Phase-35 redesign's open-questions list. `docs/release/` holds
the release record and the Play checklist.
<!-- SPECKIT END -->
