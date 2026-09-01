// Phase 5 (spec/005-auth-profile R-07/R-16) — request_password_reset Edge Function.
// Implements account-enumeration-resistant reset-password flow per FR-017.
//
// Contract (per contracts/request-password-reset-edge-fn.md):
//   POST /functions/v1/request_password_reset
//   Body in: { phone: string }
//   Body out (ALWAYS, for parseable bodies): { ok: true }, status 200
//   Body out (malformed):                    { error: "invalid_request" }, status 400
//
// The function looks up profiles.email by phone via the service-role client (bypassing RLS),
// conditionally calls auth.admin.generateLink({type:'recovery'}) if a real email is on file,
// and returns identical {ok: true} for ALL three scenarios:
//   - phone unknown
//   - phone known with email
//   - phone known without email
// — so a network observer cannot distinguish them from the response body.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

// Spec 005 D-01 — where GoTrue sends the browser after it verifies the recovery
// token. Must match the Android intent-filter on MainActivity
// (scheme `alnujom`, host `auth`, path `/reset-password`) AND be present in
// Supabase Dashboard → Authentication → URL Configuration → Redirect URLs,
// otherwise /auth/v1/verify answers `{"error":"requested path is invalid"}`.
const RESET_REDIRECT_URL = "alnujom://auth/reset-password";

// ─── Phone normalization (TS port of lib/shared/domain/value_objects/phone_number.dart) ───
// The Dart and TS implementations MUST agree on the canonical form.
function normalizeToE164(raw: string): string | null {
  const stripped = raw.replace(/[\s\-()\.]/g, "");
  if (stripped.length === 0) return null;
  if (stripped.startsWith("+")) {
    if (!/^\+\d+$/.test(stripped)) return null;
    if (stripped.length < 8 || stripped.length > 16) return null;
    return stripped;
  }
  if (stripped.startsWith("0")) {
    const rest = stripped.slice(1);
    if (!/^\d{9}$/.test(rest) || !rest.startsWith("9")) return null;
    return "+963" + rest;
  }
  if (/^9\d{8}$/.test(stripped)) {
    return "+963" + stripped;
  }
  return null;
}

// ─── Logging helpers (no PII; phone numbers and emails NEVER logged) ───
function log(event: string, extra: Record<string, unknown> = {}) {
  // Edge Function logs are visible via Supabase MCP get_logs (service: edge-function).
  console.log(JSON.stringify({ event, ...extra }));
}

Deno.serve(async (req: Request) => {
  // 1. Method guard
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "invalid_request" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 2. Parse body
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid_request" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (
    body === null ||
    typeof body !== "object" ||
    !("phone" in body) ||
    typeof (body as { phone: unknown }).phone !== "string"
  ) {
    return new Response(JSON.stringify({ error: "invalid_request" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const rawPhone = (body as { phone: string }).phone;

  // 3. Normalize phone. Failure is treated as "unknown" — uniform 200 response per FR-017.
  const e164 = normalizeToE164(rawPhone);

  // 4. Privileged Supabase client (service-role; bypasses RLS).
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    log("env_missing");
    return new Response(JSON.stringify({ error: "internal" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 5. Lookup. If phone is malformed (e164 === null), skip the DB hit but still return uniform 200.
  if (e164 !== null) {
    const { data, error } = await admin
      .from("profiles")
      .select("user_id, email")
      .eq("phone", e164)
      .maybeSingle();

    if (error) {
      log("profile_lookup_error", { code: error.code });
      // Still return generic success per FR-017.
    } else if (data && typeof data.email === "string" && data.email.trim().length > 0) {
      // 6. Real email on file → trigger reset.
      const { error: linkErr } = await admin.auth.admin.generateLink({
        type: "recovery",
        email: data.email,
        options: { redirectTo: RESET_REDIRECT_URL },
      });
      if (linkErr) {
        log("generate_link_failed", { code: linkErr.status });
        // Still return generic success.
      } else {
        log("reset_email_sent", { user_id: data.user_id });
      }
    } else {
      log("no_email_on_file");
    }
  } else {
    log("phone_unparseable");
  }

  // 7. ALWAYS return uniform 200 + {ok: true} for parseable bodies.
  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
