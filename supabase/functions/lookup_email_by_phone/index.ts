// spec/005-auth-profile — lookup_email_by_phone Edge Function (Option B fix).
//
// Given a phone (E.164 or normalizable to E.164), returns the auth.users.email
// for the matching profile. If no profile matches the phone, returns the
// synthetic email constructed from that phone (`<phone>@alnujom.local`) so the
// caller's subsequent signInWithPassword fails with `invalid_credentials` for
// the same reason as a wrong password — preserving account-enumeration
// resistance at sign-in.
//
// Contract:
//   POST /functions/v1/lookup_email_by_phone
//   Body in:  { phone: string }
//   Body out: { email: string }  (always 200 for parseable input)
//   Body out (malformed): { error: "invalid_request" }  status 400
//
// Service-role privileges are loaded from Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
// and used only to call the SECURITY DEFINER RPC `app_lookup_auth_email_by_phone`.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

// TS port of lib/shared/domain/value_objects/phone_number.dart (kept in sync with
// the request_password_reset Edge Function).
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

function log(event: string, extra: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ event, ...extra }));
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "invalid_request" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

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

  // Malformed phone → return a synthetic-looking email so signInWithPassword
  // fails identically to a wrong-password attempt against an unknown phone.
  const e164 = normalizeToE164(rawPhone);
  if (e164 === null) {
    return new Response(
      JSON.stringify({ email: `${rawPhone}@alnujom.local` }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }

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

  const { data, error } = await admin.rpc("app_lookup_auth_email_by_phone", {
    p_phone: e164,
  });

  if (error) {
    log("rpc_error", { code: error.code });
    // Fall through to synthetic so signIn fails with invalid_credentials.
  }

  const email: string =
    typeof data === "string" && data.length > 0 ? data : `${e164}@alnujom.local`;

  return new Response(JSON.stringify({ email }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
