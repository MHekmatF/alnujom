// Phase 12 (spec/012-listing-approval) — approve_listing Edge Function.
//
// Contract: specs/012-listing-approval/contracts/phase12-approve-listing-edge-function.md
// Call sequence: specs/012-listing-approval/data-model.md §2.3
//
// POST /functions/v1/approve_listing
//   Headers: Authorization: Bearer <user JWT>, Content-Type: application/json
//   Body in:  { listing_id: "<UUID>" }
//   Body out (200): { status: "approved", published_at: "<ISO>", expires_at: null }
//   Error envelopes (Content-Type: application/json):
//     400 { code: "invalid_listing_id" | "invalid_request" }
//     403 { code: "permission_denied" }
//     404 { code: "listing_not_found" }
//     409 { code: "invalid_status_transition", current_status: "<status>" }
//     409 { code: "already_acted_on", current_status: "approved" }
//     500 { code: "internal_error", message: "<text>" }
//
// SC-018 + T097a — the JWT-bound permission check via current_user_has_permission
// MUST appear BEFORE the service-role client is constructed AND BEFORE any UPDATE.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function log(event: string, extra: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ event, ...extra }));
}

function parseJwtSub(authHeader: string | null): string | null {
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.slice("Bearer ".length).trim();
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    // base64url decode the payload
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload + "=".repeat((4 - (payload.length % 4)) % 4);
    const decoded = atob(padded);
    const parsed = JSON.parse(decoded) as { sub?: unknown };
    return typeof parsed.sub === "string" && parsed.sub.length > 0
      ? parsed.sub
      : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ code: "invalid_request" }, 405);
  }

  // 1. Parse body and validate listing_id is a UUID.
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ code: "invalid_listing_id" }, 400);
  }
  if (
    body === null ||
    typeof body !== "object" ||
    !("listing_id" in body) ||
    typeof (body as { listing_id: unknown }).listing_id !== "string" ||
    !UUID_RE.test((body as { listing_id: string }).listing_id)
  ) {
    return json({ code: "invalid_listing_id" }, 400);
  }
  const listingId = (body as { listing_id: string }).listing_id;

  // 2. Extract Authorization header → JWT.sub.
  const authHeader = req.headers.get("Authorization");
  const jwtSub = parseJwtSub(authHeader);
  if (jwtSub === null) {
    return json({ code: "permission_denied" }, 403);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    log("env_missing");
    return json({ code: "internal_error", message: "env_missing" }, 500);
  }

  // 3. JWT-bound Supabase client (RLS still applies; used only for the
  //    permission check, NOT for the UPDATE).
  const jwtClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader! } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 4. Permission check via Phase 6 RPC — MUST run before service-role client.
  const { data: hasPerm, error: permErr } = await jwtClient.rpc(
    "current_user_has_permission",
    { perm_key: "listings.approve" },
  );
  if (permErr) {
    log("perm_check_error", { code: permErr.code, msg: permErr.message });
    return json({ code: "permission_denied" }, 403);
  }
  if (hasPerm !== true) {
    return json({ code: "permission_denied" }, 403);
  }

  // 5. Service-role client (bypasses RLS) — created ONLY after permission check.
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 6. Set the FR-024 session variable so the amended triggers source
  //    changed_by + actor_user_id from the admin's UID instead of NULL.
  const { error: setVarErr } = await adminClient.rpc(
    "set_app_user_id_for_session",
    { user_id: jwtSub },
  );
  if (setVarErr) {
    log("set_session_var_error", {
      code: setVarErr.code,
      msg: setVarErr.message,
    });
    return json(
      { code: "internal_error", message: "session_var_setup_failed" },
      500,
    );
  }

  // 7. Privileged UPDATE under the status-guard (status='pending_review').
  const { data, error: updateErr } = await adminClient
    .from("listings")
    .update({
      status: "approved",
      published_at: new Date().toISOString(),
    })
    .eq("id", listingId)
    .eq("status", "pending_review")
    .select("id, status, published_at, expires_at")
    .maybeSingle();

  if (updateErr) {
    log("update_error", { code: updateErr.code, msg: updateErr.message });
    return json(
      { code: "internal_error", message: updateErr.message },
      500,
    );
  }

  // 8. Zero-rows path — either the listing doesn't exist (404) or it is
  //    in a non-pending_review status (already_acted_on / invalid_status_transition).
  if (data === null) {
    const { data: current, error: lookupErr } = await adminClient
      .from("listings")
      .select("status")
      .eq("id", listingId)
      .maybeSingle();
    if (lookupErr) {
      log("status_lookup_error", {
        code: lookupErr.code,
        msg: lookupErr.message,
      });
      return json(
        { code: "internal_error", message: lookupErr.message },
        500,
      );
    }
    if (current === null) {
      return json({ code: "listing_not_found" }, 404);
    }
    const currentStatus = current.status as string;
    const code = currentStatus === "approved" || currentStatus === "rejected"
      ? "already_acted_on"
      : "invalid_status_transition";
    return json({ code, current_status: currentStatus }, 409);
  }

  // 9. Success. The amended triggers fired automatically inside the UPDATE's
  //    transaction; listing_status_history + audit_logs rows now exist with
  //    changed_by / actor_user_id = admin's UID.
  log("approve_success", { listing_id: listingId });
  return json(
    {
      status: data.status,
      published_at: data.published_at,
      expires_at: data.expires_at,
    },
    200,
  );
});
