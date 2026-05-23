// Phase 12 (spec/012-listing-approval) — approve_listing Edge Function.
//
// Contract: specs/012-listing-approval/contracts/phase12-approve-listing-edge-function.md
// Call sequence: specs/012-listing-approval/data-model.md §2.3
//
// POST /functions/v1/approve_listing
//   Headers: Authorization: Bearer <user JWT>, Content-Type: application/json
//   Body in:  { listing_id: "<UUID>" }
//   Body out (200): { status: "approved", published_at: "<ISO>", expires_at: null }
//
// SC-018 + T097a — JWT-bound permission check via current_user_has_permission
// runs BEFORE the service-role client is constructed AND BEFORE any UPDATE.
//
// FR-024 bugfix (migration 20260523120005): the set-then-update split was
// broken by PostgREST's per-request-transaction boundary; now uses one
// atomic RPC `approve_listing_internal(p_listing_id, p_actor_user_id)`.

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

  const jwtClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader! } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

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

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: rows, error: rpcErr } = await adminClient.rpc(
    "approve_listing_internal",
    { p_listing_id: listingId, p_actor_user_id: jwtSub },
  );
  if (rpcErr) {
    log("approve_rpc_error", { code: rpcErr.code, msg: rpcErr.message });
    return json(
      { code: "internal_error", message: rpcErr.message },
      500,
    );
  }
  const data = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;

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
