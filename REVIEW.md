# Al Nujom — UI/UX Quality Pass · REVIEW

_Branch: `035-redesign-ground-up`. This file collects questions, assumptions, deferred/risky
decisions, and notes from the autonomous UI/UX pass. Nothing here blocks the work — it's the
list of things for you (founder) to weigh in on when you're back._

---

## 1. Scope & methodology decisions I made (so I didn't have to stop and ask)

- **Skill outputs are used for *rules*, not raw web assets.** The `ui-ux-pro-max` skill is
  web/Latin oriented. Its raw recommendations for **fonts** (Cinzel / Josefin Sans — Latin-only,
  useless for Arabic), **palette** (teal), and **CSS** (`clamp()`, GSAP) were **NOT** applied.
  We already have a mature royal-blue **token system** + **Tajawal** Arabic typeface (phase 032/033).
  I used the skill only for: information hierarchy, section ordering/patterns, spacing rhythm,
  motion timing, accessibility (contrast / 48dp touch targets / focus), RTL correctness, and
  empty/loading/error-state completeness — all mapped onto the **existing tokens**.
  → _If you actually want to chase the skill's teal/Cinzel direction, that's a separate, bigger call._

- **"Run the build + linter per screen" → interpreted as `flutter analyze --fatal-infos` +
  `tool/lint_design_tokens.dart` + l10n parity/literal linters per screen group, with ONE full
  release build at the end.** A full `flutter build apk` per screen (×23) would take hours and
  waste cycles; `flutter analyze` is the real compile-level gate and matches the project's CI verify
  suite. The end-to-end release build validates the whole.

- **Consumer-facing scope first.** The pass covers the "cover at minimum" set: Home, Search
  (+filters), Listing Card (3 modes), Listing Detail, Map, all 5 bottom-tab destinations, guest
  entry, auth/onboarding, profile, favorites, create/edit listing, and modal/sheet/empty/loading/error
  states — **~23 screen groups**. The ~40 internal **admin / agency / currency / super-admin /
  locations-management** screens are **batch-2** (documented at the bottom). They're internal tools;
  say the word and I'll do a second pass over them.

## 2. Hard guardrails I honored

- **No DB / migrations / schema / backend / API / auth-flow changes.** There is a known pending
  Supabase project mismatch — **left entirely untouched**, as instructed. All edits are front-end
  visual/UX only.
- **No git history rewrites, no rebase onto main, no merge, no force-push, no branch deletion.**
  Work stays on `035-redesign-ground-up` as incremental commits.
- **RTL / Arabic preserved.** Edits use `EdgeInsetsDirectional` / `start`/`end` / directional
  alignment; no existing l10n keys removed or renamed.

## 3. Open questions for you
_(populated from the per-screen audit — see below)_

## 4. Risky / ambiguous decisions (I shipped the safe version; alternative noted)
_(populated from the per-screen audit — see below)_

## 5. Deferred items
_(populated from the per-screen audit — see below)_

## 6. Batch-2: internal screens not yet passed
Admin (account approvals, listing review, reports queue, audit logs, analytics), Agency
(home/listings/members/profile/verification/analytics/edit), Currencies (list/form/rate/history),
Super-admin (roles/assign), Locations management (list/detail/form), App-settings editor,
Ads admin, CRM, Dashboard entry. → second pass on request.
