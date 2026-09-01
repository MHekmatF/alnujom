// request_password_reset — tell the caller what actually happened.
//
// This function used to answer `{ok: true}` for every phone number, so an
// observer could not learn who has an account. That protection was traded away
// deliberately (owner's decision, 2026-09-01): most accounts here are
// phone-only and can never receive a reset mail, so "check your email" was a
// lie for the majority of users, and the screen had no way to tell anyone what
// to do instead. It now reports one of three outcomes and the UI acts on each.
//
// It also used to call `auth.admin.generateLink()`, which GENERATES a recovery
// link and returns it — it does not send anything. Nothing was ever mailed. The
// send now goes through GoTrue's own `/auth/v1/recover` endpoint, which is the
// call that actually dispatches.
//
//   POST /functions/v1/request_password_reset
//   in : { phone: string }
//   out: { status: "sent" | "no_email" | "not_found" }   200
//        { error: "invalid_request" }                    400 (unparseable body)
//        { error: "invalid_request" }                    405 (not POST)
//
// A malformed or unparseable phone answers `not_found` rather than an error —
// there is no account to find, and the screen already says so usefully.
//
// KEEP THIS FILE IN SYNC WITH WHAT IS DEPLOYED. This source drifted from
// production once already: the deployed function was updated and the repo was
// not, so a redeploy from the repo would silently have restored the version
// that mails nothing. The response contract below was re-derived by probing the
// live function on 2026-09-02 — method guard, body guard, unparseable phone,
// empty phone, and unknown phone in +963/local/bare forms all confirmed. The
// three branches that require a real account (`sent`, `no_email`, and a
// send failure) could not be exercised without mailing a real person.
//
// MAIL DELIVERY IS A SEPARATE PROBLEM: on the free plan Supabase's built-in
// SMTP is for development only — heavily rate-limited and not a real sender.
// `sent` means GoTrue accepted the request, NOT that mail reached an inbox.
// Configure a custom SMTP provider under Authentication → Emails before relying
// on this in production. See docs/ops/HANDOVER.md.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

// Where GoTrue sends the browser after it verifies the recovery token. Must
// match the Android intent-filter on MainActivity (scheme `alnujom`, host
// `auth`, path `/reset-password`) AND appear in Supabase Dashboard →
// Authentication → URL Configuration → Redirect URLs. GoTrue rejects an
// unlisted address outright, so an unlisted value means NO mail at all — which
// is why the send below retries without it rather than giving up.
const RESET_REDIRECT_URL = "alnujom://auth/reset-password";

// TS port of lib/shared/domain/value_objects/phone_number.dart. The two
// implementations MUST agree on the canonical form.
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

// Phone numbers and email addresses are never logged.
function log(event: string, extra: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ event, ...extra }));
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/// Asks GoTrue to send the recovery mail. Returns true if it accepted.
async function sendRecoveryMail(
  supabaseUrl: string,
  serviceRoleKey: string,
  email: string,
): Promise<boolean> {
  async function post(withRedirect: boolean): Promise<Response> {
    const url = withRedirect
      ? `${supabaseUrl}/auth/v1/recover?redirect_to=${
        encodeURIComponent(RESET_REDIRECT_URL)
      }`
      : `${supabaseUrl}/auth/v1/recover`;
    return await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({ email }),
    });
  }

  const withLink = await post(true);
  if (withLink.ok) return true;

  // The deep link is not on the allow-list. Send without it rather than sending
  // nothing — the mail still resets the password, it just lands on the Site URL
  // instead of opening the app. This log line is how the operator finds out.
  log("recover_redirect_rejected", { status: withLink.status });
  const plain = await post(false);
  if (plain.ok) {
    log("reset_email_sent_without_deeplink");
    return true;
  }
  log("recover_failed", { status: plain.status });
  return false;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "invalid_request" }, 405);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_request" }, 400);
  }
  if (
    body === null ||
    typeof body !== "object" ||
    !("phone" in body) ||
    typeof (body as { phone: unknown }).phone !== "string"
  ) {
    return json({ error: "invalid_request" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    log("env_missing");
    return json({ error: "internal" }, 500);
  }

  const e164 = normalizeToE164((body as { phone: string }).phone);
  if (e164 === null) {
    log("phone_unparseable");
    return json({ status: "not_found" }, 200);
  }

  // Service-role client; bypasses RLS to read the profile behind the phone.
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await admin
    .from("profiles")
    .select("user_id, email")
    .eq("phone", e164)
    .maybeSingle();

  if (error) {
    log("profile_lookup_error", { code: error.code });
    return json({ status: "not_found" }, 200);
  }
  if (!data) {
    return json({ status: "not_found" }, 200);
  }

  const email = typeof data.email === "string" ? data.email.trim() : "";
  if (email.length === 0) {
    // A real account, but phone-only — there is no mailbox to send to. The
    // screen routes these users to support instead of promising a mail.
    log("no_email_on_file", { user_id: data.user_id });
    return json({ status: "no_email" }, 200);
  }

  const sent = await sendRecoveryMail(supabaseUrl, serviceRoleKey, email);
  if (!sent) {
    // The account exists but we could not get a mail out. From the user's side
    // the next step is identical to having no email on file — contact support —
    // so answer the same way rather than claiming a mail is on its way.
    return json({ status: "no_email" }, 200);
  }

  log("reset_email_sent", { user_id: data.user_id });
  return json({ status: "sent" }, 200);
});
