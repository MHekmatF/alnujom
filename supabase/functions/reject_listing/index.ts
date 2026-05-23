// Phase 12 (spec/012-listing-approval) — reject_listing Edge Function.
//
// Contract: specs/012-listing-approval/contracts/phase12-reject-listing-edge-function.md
// Call sequence: 12 steps per the contract.
//
// POST /functions/v1/reject_listing
//   Headers: Authorization: Bearer <user JWT>, Content-Type: application/json
//   Body in:  { listing_id: "<UUID>",
//               reason_preset: "<one of six Q3=A keys>",
//               reason_detail?: "<string up to 500 chars>" }
//   Body out (200): { status: "rejected",
//                     reason_preset: "<the preset key>",
//                     reason_detail: "<the detail or null>" }
//   Error envelopes (Content-Type: application/json):
//     400 { code: "invalid_listing_id" | "invalid_request" }
//     400 { code: "invalid_reason_preset", allowed: [<6 keys>] }
//     400 { code: "reason_detail_too_long", max: 500 }
//     403 { code: "permission_denied" }
//     404 { code: "listing_not_found" }
//     409 { code: "invalid_status_transition", current_status: "<status>" }
//     409 { code: "already_acted_on", current_status: "rejected" }
//     500 { code: "internal_error", message: "<text>" }
//
// SC-018 + T097a — the JWT-bound permission check via current_user_has_permission
// MUST appear BEFORE the service-role client is constructed AND BEFORE any UPDATE.
//
// Q4=A — rejection reason is stored as JSON-encoded TEXT in
// listing_status_history.reason via the FR-024 session-variable handoff:
//   set_app_rejection_reason_for_session(JSON.stringify({preset, detail}))
// The amended listing_status_transition_trigger_fn() reads
// current_setting('app.current_rejection_reason') AND writes it as-is.
//
// FR-002(g) clarified: the server is permissive on empty reason_detail when
// preset='other'. The UX layer (FR-013(d)) enforces non-empty detail for Other.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const ALLOWED_PRESETS = [
  "missing_or_low_quality_photos",
  "incorrect_location",
  "unrealistic_price",
  "incomplete_description",
  "duplicate_listing",
  "other",
] as const;

const MAX_DETAIL_LENGTH = 500;

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

  // 2. Validate reason_preset against the hard-coded 6-key allowlist.
  const presetRaw = (body as { reason_preset?: unknown }).reason_preset;
  if (
    typeof presetRaw !== "string" ||
    !(ALLOWED_PRESETS as readonly string[]).includes(presetRaw)
  ) {
    return json(
      { code: "invalid_reason_preset", allowed: ALLOWED_PRESETS },
      400,
    );
  }
  const reasonPreset = presetRaw;

  // 3. Validate reason_detail (optional; length ≤ 500 if present).
  //    Per FR-002(g), the server is permissive on empty-detail-when-other;
  //    UX gate at FR-013(d) handles the dialog enable rule.
  const detailRaw = (body as { reason_detail?: unknown }).reason_detail;
  let reasonDetail: string | null;
  if (detailRaw === undefined || detailRaw === null) {
    reasonDetail = null;
  } else if (typeof detailRaw === "string") {
    if (detailRaw.length > MAX_DETAIL_LENGTH) {
      return json(
        { code: "reason_detail_too_long", max: MAX_DETAIL_LENGTH },
        400,
      );
    }
    reasonDetail = detailRaw;
  } else {
    return json({ code: "invalid_request" }, 400);
  }

  // 4. Extract Authorization header → JWT.sub.
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

  // 5. JWT-bound Supabase client (RLS still applies; used only for the
  //    permission check, NOT for the UPDATE).
  const jwtClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader! } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Permission check via Phase 6 RPC — MUST run before service-role client.
  const { data: hasPerm, error: permErr } = await jwtClient.rpc(
    "current_user_has_permission",
    { perm_key: "listings.reject" },
  );
  if (permErr) {
    log("perm_check_error", { code: permErr.code, msg: permErr.message });
    return json({ code: "permission_denied" }, 403);
  }
  if (hasPerm !== true) {
    return json({ code: "permission_denied" }, 403);
  }

  // 6. Service-role client (bypasses RLS) — created ONLY after perm check.
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 7. Set the FR-024 user-id session variable so the amended triggers
  //    source changed_by + actor_user_id from the admin's UID.
  const { error: setUserErr } = await adminClient.rpc(
    "set_app_user_id_for_session",
    { user_id: jwtSub },
  );
  if (setUserErr) {
    log("set_user_var_error", {
      code: setUserErr.code,
      msg: setUserErr.message,
    });
    return json(
      { code: "internal_error", message: "session_var_setup_failed" },
      500,
    );
  }

  // 8. Build Q4=A JSON-encoded reason payload AND set the rejection-reason
  //    session variable. The amended listing_status_transition_trigger_fn
  //    reads current_setting('app.current_rejection_reason', true) and
  //    writes that value verbatim into listing_status_history.reason.
  const reasonJson = JSON.stringify({
    preset: reasonPreset,
    detail: reasonDetail,
  });
  const { error: setReasonErr } = await adminClient.rpc(
    "set_app_rejection_reason_for_session",
    { reason_json: reasonJson },
  );
  if (setReasonErr) {
    log("set_reason_var_error", {
      code: setReasonErr.code,
      msg: setReasonErr.message,
    });
    return json(
      { code: "internal_error", message: "session_var_setup_failed" },
      500,
    );
  }

  // 9. Privileged UPDATE under the status-guard (status='pending_review').
  //    The amended triggers fire automatically inside this transaction.
  const { data, error: updateErr } = await adminClient
    .from("listings")
    .update({ status: "rejected" })
    .eq("id", listingId)
    .eq("status", "pending_review")
    .select("id, status")
    .maybeSingle();

  if (updateErr) {
    log("update_error", { code: updateErr.code, msg: updateErr.message });
    return json(
      { code: "internal_error", message: updateErr.message },
      500,
    );
  }

  // 10. Zero-rows path — either the listing doesn't exist (404) or it is
  //     in a non-pending_review status (already_acted_on / invalid).
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

  // 11. The amended listing_status_transition_trigger_fn fired and wrote a
  //     listing_status_history row with changed_by=admin_uid AND
  //     reason=reasonJson. The amended listings_audit_trigger_fn wrote an
  //     audit_logs row with action='listing.rejected'.
  // 12. Success.
  log("reject_success", {
    listing_id: listingId,
    preset: reasonPreset,
  });
  return json(
    {
      status: "rejected",
      reason_preset: reasonPreset,
      reason_detail: reasonDetail,
    },
    200,
  );
});
