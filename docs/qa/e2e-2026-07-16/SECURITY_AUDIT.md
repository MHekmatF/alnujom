# Security audit — AlNujom (2026-07-17)

> **Correction, 2026-09-04.** Two statements below were re-tested during the
> full review ([`docs/ops/REVIEW_2026-09-04.md`](../../ops/REVIEW_2026-09-04.md))
> and are not accurate as written:
>
> - *"file storage … only serves approved public content"* — `listing-images` is
>   a **public bucket**, and a public bucket's CDN path is served with no auth
>   and no RLS. A rejected listing's photo returned `HTTP 200` to an unauthenticated
>   `curl`; only the `listing_media` *row* is hidden. The SELECT policy gates the
>   API listing of objects, not the files. Owner decision B14.
> - *"a user only sees their own private data"* holds for reads, but two UPDATE
>   policies had no `WITH CHECK` and no column restriction: either party in a chat
>   could rewrite the other's message text and sender, and a viewing requester
>   could confirm their own viewing. Both **proven** and queued as A14.
>
> Everything else in this document was re-confirmed unchanged.

A focused security review of the whole app: how login tokens are stored, whether
debug builds leak anything, whether the API endpoints are locked down, and
whether any secret is exposed. Run with three parallel code audits (auth/session,
logging, secrets/build) plus a full backend audit over Supabase (RLS, storage,
edge functions, RPCs, security advisors).

---

## Plain-English summary

**Your app is in strong security shape, and I fixed the one real weakness I found.**

- The **most important fix**: your login session (the token that keeps someone
  signed in) was being saved on the phone in **plain, unencrypted** form. I moved
  it into the phone's **encrypted keystore**. Now, even someone with deep access
  to the device can't lift a token and use it to sign in as that person.
- **Debug leaks:** the shipped app already prints **nothing** — no passwords,
  tokens, phone numbers. I added an extra scrubber so even developer/debug builds
  hide sensitive text.
- **API endpoints:** every database table has row-level security, every file
  bucket is locked down, the contact form encrypts the sender's phone number, and
  I trimmed a few internal functions that didn't need to be reachable.
- **Secrets:** none are exposed. Your admin/master key never ships in the app,
  and nothing sensitive is committed to the code repository.

There is **one medium item left** (a signed-up user could, with a hand-crafted
request, read a property's exact map pin) and **two small dashboard toggles only
you can flip**. Details below.

---

## Your questions, answered

**"No one can get a token to log in to an account that isn't theirs."**
✅ **Fixed.** Login tokens are now stored in the Android encrypted keystore /
iOS Keychain instead of plaintext. Tokens are also never written to logs, never
put in a URL, and never leave the device except to Supabase. Sign-in itself can't
be tricked into another account (no token is ever accepted from a link or
deep-link — verified there's no such entry point in the app).

**"No print, so no one can open the app in debug mode and see things."**
✅ **Already true, now hardened.** The released app has **zero** `print()`
statements (a build rule blocks them), and all logging is switched completely off
in release builds. Crash reports are scrubbed of tokens, emails, and phone
numbers before they're sent. I added a scrubber so even debug builds redact
sensitive text.

**"API endpoints secure."**
✅ **Verified solid.** Every table enforces row-level security (a user only sees
their own private data); file storage only lets people upload to their own
folders and only serves approved public content; the three public endpoints that
work without login are deliberately built to resist abuse and don't leak who's
registered; admin actions require a verified admin token server-side.

**"Everything secure."**
✅ Secrets are clean, the app is signed properly, the manifest is hardened, and
network traffic is now pinned to HTTPS-only. The full checklist is below.

---

## What I fixed in this pass

| Fix | What it does | Where |
|---|---|---|
| 🔴→✅ **Encrypted session storage** *(verified on emulator)* | Login/refresh token now in the OS secure keystore, not plaintext SharedPreferences. Existing sessions are migrated in and the old plaintext copy is wiped (no forced logout). **Proven on-device:** after login → app restart, the session persists; on disk it's AES-encrypted ciphertext (Tink AES-SIV), and the plaintext prefs file is empty. | `lib/core/network/secure_session_storage.dart`, `supabase_client_wrapper_impl.dart` |
| ✅ **No-cleartext network config** | Pins the app to HTTPS-only and rejects user-installed CAs (anti-MITM), independent of the Android version default. | `android/app/src/main/res/xml/network_security_config.xml`, `AndroidManifest.xml` |
| ✅ **Debug-log scrubber** | A shared redactor strips JWTs/bearer tokens/emails/phones from every log line, in debug and release. De-duplicates the crash-reporter's scrubber. | `lib/core/logging/log_redaction.dart`, `console_logger.dart`, `sentry_crash_reporter.dart` |
| ✅ **Trimmed API surface** | Revoked needless direct-call grants on 4 internal trigger functions + the inbox-count function (they were never meant to be callable over the API). | `supabase/migrations/20260717120010_revoke_direct_execute_internal_fns.sql` |

---

## What was verified already-secure (no change needed)

**Auth / sessions**
- Sign-in and password-reset are **enumeration-resistant** — they return an
  identical response whether or not a phone is registered, so no one can probe
  which numbers have accounts.
- No token/session is ever logged, put in a URL, or accepted from a deep link.
  The app has **no deep-link attack surface** (only the standard launcher intent).
- Passwords are bcrypt-hashed with an 8-char minimum, enforced server-side.
- The publish gate ("only approved publishers can post") is enforced **in the
  database**, not just the UI — a hacked client can't bypass it.

**API / backend**
- **Every** public table has row-level security enabled (0 tables without it).
- **6 gated views** each carry a correct per-caller filter (approved-only,
  owner-only, or admin-permission) — verified line by line.
- **Storage:** uploads are ownership/permission-gated with UUID-path enforcement;
  the private `agency-documents` bucket is the only non-public one (correct); the
  APK bucket is read-only to the public (only the server can publish builds).
- **Edge functions:** the 4 admin functions require a verified admin JWT; the 3
  public ones enforce their own protections (a shared-secret bearer for push
  dispatch; enumeration-resistant phone/reset lookups).
- **Contact form** validates every field and **encrypts the inquirer's phone
  number** (pgsodium AEAD via a Vault key) — no plaintext PII at rest.
- The database RLS speed tune-up from the prior pass is intact (0 `auth_rls_initplan` warnings).

**Secrets / build**
- The **service-role (master) key never ships** in the app — it lives only in
  `.env.admin.json` (gitignored) and is used only server-side.
- **No hardcoded secrets** anywhere in the code; all secret files are gitignored
  and untracked; only empty templates are committed.
- Release builds are **fail-closed signed** (no debug-signing fallback);
  `allowBackup=false`; exported components are minimal and hardened
  (`taskAffinity=""` anti-task-hijack); no over-shared content providers.

---

## What's left (deferred — none block launch)

| Item | Severity | Why deferred | The fix |
|---|---|---|---|
| **Authenticated coordinate read** (SEC-I1 residual) | 🟠 Medium | A signed-up user could hand-craft a raw API call to read a listing's exact map pin, defeating the "approximate location" privacy. It's **property** coordinates only (personal PII like phone is separately encrypted), and the app's own screens never expose it. Closing it means routing owner/admin coordinate reads through a new gated function **before** revoking the column — a change to the publish/edit + moderation flows that needs login-gated on-device testing. Not safe to rush pre-launch. | Add `get_listing_coordinates(listing_id)` SECURITY DEFINER RPC (owner-or-admin check); convert the ~2 read sites (edit-form snapshot in `supabase_listing_revision_datasource.dart`, admin preview); then `REVOKE SELECT (latitude, longitude) ON listings FROM authenticated`; test edit + moderation + map. |
| **Faster search at scale** | 🟢 Low (perf) | The obvious fix regresses **Arabic** search (loses substring matching of the definite article "الـ"). Needs `pg_trgm` + trigram index + a query restructure and a search-quality decision. Zero benefit at the current listing count. | `pg_trgm` GIN + UNION restructure of `search_listings`/`search_map` with real-data `EXPLAIN`. |
| **Duplicate-policy merge** | 🟢 Low (perf) | 27 tables have two overlapping RLS policies; merging them shaves a little per-query cost at large scale, but a merge error could subtly change access. High-tedium, low-value, not worth the risk now. | Combine same-command policies with `OR`, table by table, re-checking the advisor after each. |

---

## What only you can do (2 dashboard toggles + 1 build flag)

1. **Turn on "leaked-password protection"** — Supabase Dashboard → Authentication
   → Passwords → enable "Check against HaveIBeenPwned". ~30 seconds. Blocks
   sign-ups/changes to passwords known from public breaches.
2. **Restrict the Firebase/FCM Android key** — Google Cloud Console → the app's
   `AIza…` key → restrict to Android apps (package `com.alnujom.app` + your
   release signing SHA) and to only the Firebase/FCM APIs. (The key is low-risk
   and designed to ship, but restricting it prevents misuse.)
3. **Build the release for distribution with:**
   `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define-from-file=.env.json`
   — `--split-per-abi` halves the download (~38 MB arm64); `--obfuscate` makes the
   app harder to reverse-engineer. Keep `build/symbols` out of git.

---

## Accepted product constraints (by design, documented)

- **Phone numbers aren't verified with an SMS one-time code** — there's no
  reliable SMS gateway for the target region (a known constraint). This means
  someone can register a number they don't own. If/when an SMS or WhatsApp OTP
  becomes available, gate first-publish behind it, or verify numbers manually in
  admin. (Auth findings M3/M4.)
- **Password reset needs a real email on file** — most accounts use phone-only,
  so in-app reset is limited today (a known spec-005 deferral; availability, not
  a security hole). (Auth finding L6.)
- **A live session can change its own password without re-entering the old one**
  — normal for logged-in UX; the encrypted-session fix above removes the way an
  attacker would have gotten that session in the first place. (Auth finding L7.)

---

## Technical finding index

Auth/session: H1 (session plaintext → **fixed**), M2 (phone→email lookup reveals
real email for 3 non-synthetic accounts → documented; fix = normalize all auth
emails to synthetic), M3/M4 (no phone OTP / signup enumeration → accepted), L5
(client authz is UX-only, **server RLS confirmed backing it**), L6/L7 (reset
availability / password-change → documented).

Logging: zero `print`; single logger, no-op in release; crash reporter PII-scrubbed
(`sendDefaultPii=false`, `tracesSampleRate=0`, fail-closed `beforeSend`). Debug
redaction **added**.

Secrets/build: no service-role key in client; git hygiene clean; manifest hardened;
fail-closed signing. L1 (cleartext config → **added**), L2 (obfuscation → build flag
above), I1–I5 (anon key/DSN/FCM key by design).

Backend advisors: 0 tables without RLS; storage locked; 4 internal grants trimmed;
remaining anon functions are genuine public features or leak-free RLS predicates;
6 definer views verified-filtered; `pg_net`-in-public + APK-bucket-listing are low
and documented; leaked-password toggle is the dashboard action above.
