# Deferred work — spec/005-auth-profile

Items intentionally not completed in Phase 5+6+7 but that future phases (or a follow-up spec) need to close. Each entry records what works today, what's missing, and where the gap matters.

---

## D-01 — Password-reset completion via deep link (Path B from US3 verification)

**Status:** Deferred to a follow-up spec or Phase 8 (decision pending).

**What works today (verified 2026-05-14):**
- Reset request flow end-to-end: phone → Edge Function (`request_password_reset`) → `auth.users.email` looked up correctly via the Option B sync trigger → `auth.admin.generateLink({type: 'recovery', email})` returns 200 → Supabase dispatches the email → user receives it at the real address (`recovery_sent_at` populated; delivery latency ~10 min on the free-tier shared sender).
- Account-enumeration resistance (FR-017) holds: identical generic UI response for "phone unknown" / "phone known, no real email" / "phone known with real email"; no observable network difference at the request boundary.

**What's missing — clicking the link in the email fails with `{"error":"requested path is invalid"}`:**
The Edge Function calls `generateLink` without an explicit `options.redirectTo`, so Supabase uses the project's default Site URL. The Site URL / Redirect URLs allowlist is not configured (T004 was marked done in tasks.md but the dashboard side was never wired up). When the user clicks the email link, Supabase verifies the token successfully and then errors out because the redirect target is empty/invalid.

**Why it's deferred:** completing this needs deep-link integration into the Flutter app, which is a self-contained workstream:
1. `android/app/src/main/AndroidManifest.xml` — intent filter for `alnujom://reset-password` (or a universal link if a domain is registered)
2. A new `lib/features/auth/presentation/pages/reset_password_complete_page.dart` (the form rendered after the link is clicked: shows a new-password input + confirm + submit)
3. Deep-link handler at app boot — likely via the `app_links` package (confirm pubspec, may need to add)
4. Wire the deep-link stream into the AuthBloc (new event `RecoveryLinkOpened(token)`) — the bloc calls `supabase.auth.verifyOtp({type: 'recovery', token})` or sets session from URL fragment
5. Supabase Dashboard → Authentication → URL Configuration:
   - Site URL: `alnujom://reset-password`
   - Redirect URLs: same
6. `supabase/functions/request_password_reset/index.ts`: pass `options: { redirectTo: 'alnujom://reset-password' }` in the `generateLink` call

**Where the gap matters:** End users on the released app who forget their password can request a reset email and the email arrives, but they cannot complete the reset themselves — they need an admin to reset their password via Supabase Studio. For pre-MVP this is acceptable; for production it's not.

**Spec interpretation:** US3's literal goal ("can request a password reset and receive a Supabase reset email at the real address") is met. The implied click-to-reset UX is not covered by any FR in the spec; treating it as out-of-scope for Phase 5 is defensible.

---

## D-02 — Step 14 SQL/pg_dump verification (US5 Vault PII security proof)

**Status:** UI verified 2026-05-14; SQL/pg_dump checks deferred to Phase 8's T090.

**What works today:** ProfilePrivatePage stores legal_name + national_id + contact methods via the Vault PII helpers; values reload correctly on revisit. The Vault round-trip is functioning at the app layer.

**What's missing:** The security-property proofs from `quickstart.md` Step 14:
- cross-user read as non-admin returns NULL silently
- cross-user read as admin returns decrypted value
- `pg_dump` plaintext grep finds no matches outside `vault.secrets` ciphertext (SC-008)

These are SQL/CLI checks against the remote project. They're naturally bundled into Phase 8's T090 (the full quickstart end-to-end walk), so deferring them there is consistent with the task plan.

**Where the gap matters:** Until T090 lands, we've only proven the user-facing flow, not the encryption-at-rest guarantee. The cryptographic property is what makes ADR-0001 meaningful.

---

## D-03 — T019b (US3 privileged-path sanity log inspection)

**Status:** Implicitly verified during the Option B fix walk-through 2026-05-14.

**What was done:** During the Option B troubleshooting, I invoked `request_password_reset` with the registered phone `+9639992345678`. Logs showed:
- `profiles` email lookup succeeded
- `auth.admin.generateLink` returned 200 (after the fix; previously 404)
- `recovery_sent_at` populated on `auth.users`
- Generic `{ok: true}` returned to the client per FR-017

This satisfies T019b's intent ("once US1 ships and at least one user is registered with a real email on file, sanity-check the Edge Function's privileged path"). Marking T019b complete in tasks.md.

---

## Follow-up trigger

Before any final "Phase 5 fully shipped" commit (squash-merge of the 005-auth-profile branch), review this file. Each entry must be either:
- Closed (work done, entry deleted, spec updated)
- Re-scoped to a new spec with a link to that spec
- Explicitly acknowledged as "shipping with this gap" in the squash commit message and the project runbook
