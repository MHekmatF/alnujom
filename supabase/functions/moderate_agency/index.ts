// Phase 19 (spec/019-agencies) — moderate_agency Edge Function (T028).
//
// Contract: specs/019-agencies/contracts/phase19-moderate-agency-edge-function.md
// Call sequence mirrors Phase 12 approve_listing/index.ts + reject_listing/index.ts.
//
// POST /functions/v1/moderate_agency
//   Headers: Authorization: Bearer <user JWT>, Content-Type: application/json
//   Body in:  { agency_id: "<UUID>",
//               action: "approve"|"reject"|"suspend"|"reinstate",
//               reason?: { preset: "<string>", detail?: "<string ≤ 500>" } }
//             reject REQUIRES a reason.
//   Body out (200): { agency_id, status }
//   Error envelopes (Content-Type: application/json):
//     400 { code: "invalid_agency_id" | "invalid_request" }
//     400 { code: "invalid_action" }
//     400 { code: "rejection_reason_required" }
//     400 { code: "reason_detail_too_long", max: 500 }
//     403 { code: "permission_denied" }
//     404 { code: "agency_not_found" }
//     409 { code: "invalid_transition" | "name_taken" | "no_pending_verification" }
//     500 { code: "internal_error", message: "<text>" }
//
// Dual-layer authorization (FR-008 / FR-039 / SC-011):
//   1. JWT-bound current_user_has_permission(<per-action perm>) runs BEFORE the
//      service-role client is constructed → 403 on false.
//      approve/reject → 'agencies.approve'; suspend/reinstate → 'agencies.suspend'.
//   2. moderate_agency_internal is service_role-only (GRANT in 20260531120010) —
//      it cannot be reached by a client even if layer 1 is bypassed.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const ACTIONS = ["approve", "reject", "suspend", "reinstate"] as const;
type Action = (typeof ACTIONS)[number];

const MAX_DETAIL_LENGTH = 500;

// Per-action permission key (FR-008/FR-039): approve/reject gate on agencies.approve;
// suspend/reinstate gate on agencies.suspend.
const PERM_BY_ACTION: Record<Action, string> = {
  approve: "agencies.approve",
  reject: "agencies.approve",
  suspend: "agencies.suspend",
  reinstate: "agencies.suspend",
};

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

  // 1. Parse body and validate agency_id is a UUID.
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ code: "invalid_agency_id" }, 400);
  }
  if (
    body === null ||
    typeof body !== "object" ||
    !("agency_id" in body) ||
    typeof (body as { agency_id: unknown }).agency_id !== "string" ||
    !UUID_RE.test((body as { agency_id: string }).agency_id)
  ) {
    return json({ code: "invalid_agency_id" }, 400);
  }
  const agencyId = (body as { agency_id: string }).agency_id;

  // 2. Validate action against the 4-key allowlist.
  const actionRaw = (body as { action?: unknown }).action;
  if (
    typeof actionRaw !== "string" ||
    !(ACTIONS as readonly string[]).includes(actionRaw)
  ) {
    return json({ code: "invalid_action" }, 400);
  }
  const action = actionRaw as Action;

  // 3. Validate reason: required (with a non-empty preset/detail) for reject,
  //    optional otherwise. detail ≤ 500 chars when present.
  const reasonRaw = (body as { reason?: unknown }).reason;
  let reasonJson: string | null = null;
  if (reasonRaw !== undefined && reasonRaw !== null) {
    if (typeof reasonRaw !== "object") {
      return json({ code: "invalid_request" }, 400);
    }
    const presetRaw = (reasonRaw as { preset?: unknown }).preset;
    const detailRaw = (reasonRaw as { detail?: unknown }).detail;
    const preset =
      typeof presetRaw === "string" && presetRaw.length > 0 ? presetRaw : null;
    let detail: string | null;
    if (detailRaw === undefined || detailRaw === null) {
      detail = null;
    } else if (typeof detailRaw === "string") {
      if (detailRaw.length > MAX_DETAIL_LENGTH) {
        return json(
          { code: "reason_detail_too_long", max: MAX_DETAIL_LENGTH },
          400,
        );
      }
      detail = detailRaw.length > 0 ? detailRaw : null;
    } else {
      return json({ code: "invalid_request" }, 400);
    }
    if (preset !== null || detail !== null) {
      reasonJson = JSON.stringify({ preset, detail });
    }
  }

  if (action === "reject" && reasonJson === null) {
    return json({ code: "rejection_reason_required" }, 400);
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

  // ── Layer 1: JWT-bound per-action permission gate (BEFORE the service-role client). ──
  const jwtClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader! } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: hasPerm, error: permErr } = await jwtClient.rpc(
    "current_user_has_permission",
    { perm_key: PERM_BY_ACTION[action] },
  );
  if (permErr) {
    log("perm_check_error", { code: permErr.code, msg: permErr.message });
    return json({ code: "permission_denied" }, 403);
  }
  if (hasPerm !== true) {
    return json({ code: "permission_denied" }, 403);
  }

  // ── Layer 2: service-role-only atomic moderation RPC. ──
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: rows, error: rpcErr } = await adminClient.rpc(
    "moderate_agency_internal",
    {
      p_agency_id: agencyId,
      p_actor_user_id: jwtSub,
      p_action: action,
      p_reason_json: reasonJson,
    },
  );
  if (rpcErr) {
    log("moderate_rpc_error", { code: rpcErr.code, msg: rpcErr.message });
    const msg = rpcErr.message ?? "";
    // 23503 = agency_not_found → 404.
    if (rpcErr.code === "23503" || msg.includes("agency_not_found")) {
      return json({ code: "agency_not_found" }, 404);
    }
    // 22023 = invalid_action / rejection_reason_required → 400.
    if (msg.includes("rejection_reason_required")) {
      return json({ code: "rejection_reason_required" }, 400);
    }
    if (msg.includes("invalid_action")) {
      return json({ code: "invalid_action" }, 400);
    }
    // 23514 = invalid_transition; 23505 = name_taken; P0002 = no_pending_verification → 409.
    if (rpcErr.code === "23514" || msg.includes("invalid_transition")) {
      return json({ code: "invalid_transition" }, 409);
    }
    if (rpcErr.code === "23505" || msg.includes("name_taken")) {
      return json({ code: "name_taken" }, 409);
    }
    if (rpcErr.code === "P0002" || msg.includes("no_pending_verification")) {
      return json({ code: "no_pending_verification" }, 409);
    }
    return json({ code: "internal_error", message: rpcErr.message }, 500);
  }

  const data = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
  if (data === null) {
    return json({ code: "agency_not_found" }, 404);
  }

  log("moderate_success", { agency_id: agencyId, action });
  return json(
    {
      agency_id: data.agency_id,
      status: data.status,
    },
    200,
  );
});
