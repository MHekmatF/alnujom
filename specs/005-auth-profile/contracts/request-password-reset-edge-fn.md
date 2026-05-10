# Contract: `request_password_reset` Edge Function

**Owner**: Phase 5 (`supabase/functions/request_password_reset/index.ts`).
**Consumers**: `AuthRepository.requestPasswordReset` (the only client-side caller); `quickstart.md` (manual verification).
**Stability**: Stable across Phase 5 and Phase 6. Phase 7+ may add a small enhancement for super-admin-issued temporary passwords, but the existing endpoint shape (request body + response body) does not change.

---

## Purpose

Implements the account-enumeration-resistant reset-password flow (FR-017). The function takes a phone, looks up `profiles.email` server-side via the service-role key, conditionally invokes Supabase Auth's `admin.resetPasswordForEmail`, and **always** returns a generic `{ok: true}` regardless of whether the phone is known or has an email on file.

This is Phase 5's only Edge Function and represents a deliberate divergence from `docs/IMPLEMENTATION_PLAN.md` (which scheduled the first Edge Function for Phase 7). The justification is in `research.md` R-07 / R-16.

---

## Deployment

```
supabase/functions/request_password_reset/
├── deno.json       # Deno runtime config + import_map
└── index.ts        # The function entry point
```

Deployed via Supabase MCP `deploy_edge_function`. Verified via `get_edge_function` and `list_edge_functions`.

## HTTP shape

- **Method**: POST
- **Path**: `/functions/v1/request_password_reset`
- **Auth**: anonymous — no JWT required. The function uses the project's anon key for authentication of the call boundary; service-role privileges are loaded from `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')` for the privileged DB query.
- **Request body** (JSON): `{ "phone": string }` (required)
- **Response body** (JSON, ALWAYS — see "Account-enumeration resistance" below): `{ "ok": true }`
- **Response status**: 200 OK on parseable input; 400 Bad Request on malformed input (missing `phone`, non-string `phone`, etc.); 500 on internal failure (transport-level only — should not occur in normal operation).

## Request flow

```
client (any user, signed-out)
   │
   │   POST { phone: "+963991234567" } or various unnormalized formats
   ▼
Edge Function runtime (Deno)
   1. Parse JSON body; reject non-object or missing `phone` with 400.
   2. Normalize `phone` to E.164 via the inlined TS port of the Dart PhoneNumber rules.
      - On `PhoneNumberFormatException`-equivalent: STILL return 200 + {ok: true}
        (do NOT distinguish "phone format invalid" from "phone format valid but unknown").
   3. Open a Supabase service-role client:
        const admin = createClient(
          Deno.env.get('SUPABASE_URL')!,
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
          { auth: { persistSession: false } }
        );
   4. SELECT email FROM profiles WHERE phone = $1 LIMIT 1
        (service role bypasses RLS).
   5. If row found AND email IS NOT NULL AND email is non-empty:
        await admin.auth.admin.generateLink({
          type: 'recovery',
          email: <real email>,
          options: { redirectTo: <project-configured redirect> }
        })
      - generateLink with type 'recovery' creates and sends the reset email per Supabase Auth's standard flow.
      - Equivalent: admin.auth.admin.resetPasswordForEmail(email).
      - On any failure here: log to Edge Function logs but DO NOT propagate to the client.
   6. ALWAYS respond 200 with { ok: true }.
```

## Account-enumeration resistance

The function MUST behave identically — observable from the network — across these three input scenarios:

| Scenario | Server behavior | Response |
|---|---|---|
| Phone unknown | Step 4 returns no row; step 5 skipped. | 200 `{ok: true}` |
| Phone known, `email IS NULL` | Step 4 returns a row; step 5 skipped. | 200 `{ok: true}` |
| Phone known, `email` non-empty | Step 4 returns a row; step 5 sends the reset email. | 200 `{ok: true}` |

Phase 5's resistance level: **response-content uniform**. The function does NOT add a fixed-delay sleep — there is a small latency difference between "step 5 fired" and "step 5 skipped" that a sophisticated network observer could detect. Adding fixed-delay padding is deferred to Phase 24's release-polish performance/security pass; if measured to be exploitable, the polish pass adds the padding.

## Failure modes

| Mode | Behavior |
|---|---|
| Malformed JSON / missing `phone` field | 400 with body `{ "error": "invalid_request" }` (this IS distinguishable, but the input is plainly malformed — no information about user existence is leaked). |
| `SUPABASE_SERVICE_ROLE_KEY` env not set | 500 with body `{ "error": "internal" }`; logged. Indicates a deployment misconfiguration. |
| `SELECT` query fails (DB down, etc.) | 500; logged. Should be very rare given the query is one row by indexed column. |
| `generateLink` fails | 200 `{ok: true}` (per the resistance contract); logged. The user-facing UX is "the email did not arrive" — the user can retry. |

## Service-role secret handling

- The service-role key is loaded from `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')` at function-runtime startup.
- The key MUST NOT appear in any response body, log message, or error message.
- The function does not write the key to any Vault secret or `audit_logs` row.
- The Flutter client never receives the key — it invokes the function via the anon key.

## Testing posture

Per the durable no-new-tests rule, no automated tests are added for this function. Verification is manual via `quickstart.md`:

1. Register a user with a real email on file → reset → confirm the email arrives at the real inbox.
2. Register a user without a real email → reset → confirm no email arrives anywhere; the client sees `{ok: true}`.
3. Reset for an unknown phone → confirm `{ok: true}` and Edge Function logs show "no row found, skipping".

## Inlined TypeScript port of the PhoneNumber rules

```ts
// supabase/functions/request_password_reset/index.ts (excerpt)
function normalizeToE164(raw: string): string | null {
  const stripped = raw.replace(/[\s\-\(\)\.]/g, '');
  if (stripped.length === 0) return null;
  if (stripped.startsWith('+')) {
    if (!/^\+\d+$/.test(stripped)) return null;
    if (stripped.length < 8 || stripped.length > 16) return null;
    return stripped;
  }
  if (stripped.startsWith('0')) {
    const rest = stripped.slice(1);
    if (!/^\d{9}$/.test(rest) || !rest.startsWith('9')) return null;
    return '+963' + rest;
  }
  if (/^9\d{8}$/.test(stripped)) {
    return '+963' + stripped;
  }
  return null;
}
```

The Dart and TS implementations agree on the canonical form (the contract's "Examples" table in `phone-number-value-object.md` is the joint test plan — both implementations produce the same outputs).

## Verification

After deploying via Supabase MCP `deploy_edge_function`:

```bash
# 1. Confirm the function is listed.
# Supabase MCP: list_edge_functions → expect request_password_reset

# 2. Invoke with a known phone that has a real email on file.
curl -X POST '<project>/functions/v1/request_password_reset' \
  -H 'Authorization: Bearer <ANON_KEY>' \
  -H 'Content-Type: application/json' \
  -d '{"phone": "+963991234567"}'
# Expected: 200 {"ok": true}; reset email arrives at the real address.

# 3. Invoke with an unknown phone.
curl -X POST '<project>/functions/v1/request_password_reset' \
  -H 'Authorization: Bearer <ANON_KEY>' \
  -H 'Content-Type: application/json' \
  -d '{"phone": "+963990000000"}'
# Expected: 200 {"ok": true}; no email; logs show "no row found".

# 4. Invoke with malformed body.
curl -X POST '<project>/functions/v1/request_password_reset' \
  -H 'Authorization: Bearer <ANON_KEY>' \
  -H 'Content-Type: application/json' \
  -d '{}'
# Expected: 400 {"error": "invalid_request"}.
```
