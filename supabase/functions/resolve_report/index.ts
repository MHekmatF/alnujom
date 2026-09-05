// Phase 18 (spec/018-reports-moderation) — resolve_report Edge Function (T020).
//
// Contract: specs/018-reports-moderation/contracts/phase18-resolve-report-edge-function.md
// Call sequence mirrors Phase 12 approve_listing/index.ts.
//
// POST /functions/v1/resolve_report
//   Headers: Authorization: Bearer <user JWT>, Content-Type: application/json
//   Body in:  { report_id: "<UUID>", action: "dismiss"|"hide"|"mark_duplicate"|"delete"|"suspend_user", note?: "<string>" }
//   Body out (200): { report_status, listing_id, listing_status }
//
// Dual-layer authorization (FR-012 / FR-033 / SC-010):
//   1. JWT-bound current_user_has_permission('reports.manage') runs BEFORE the
//      service-role client is constructed → 403 on false.
//   2. resolve_report_internal is service_role-only (GRANT in 20260530120007) —
//      it cannot be reached by a client even if layer 1 is bypassed.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Plan A29 — suspend_user: the reported person, or a listing's publisher.
const ACTIONS = ["dismiss", "hide", "mark_duplicate", "delete", "suspend_user"] as const;

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
    return json({ code: "invalid_request" }, 400);
  }
  if (
    body === null ||
    typeof body !== "object" ||
    !("report_id" in body) ||
    typeof (body as { report_id: unknown }).report_id !== "string" ||
    !UUID_RE.test((body as { report_id: string }).report_id)
  ) {
    return json({ code: "invalid_report_id" }, 400);
  }
  const reportId = (body as { report_id: string }).report_id;

  const action = (body as { action?: unknown }).action;
  if (
    typeof action !== "string" ||
    !ACTIONS.includes(action as (typeof ACTIONS)[number])
  ) {
    return json({ code: "invalid_action" }, 400);
  }

  const rawNote = (body as { note?: unknown }).note;
  if (rawNote !== undefined && rawNote !== null && typeof rawNote !== "string") {
    return json({ code: "invalid_request" }, 400);
  }
  const note: string | null =
    typeof rawNote === "string" && rawNote.length > 0 ? rawNote : null;

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

  // ── Layer 1: JWT-bound permission gate (BEFORE the service-role client). ──
  const jwtClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader! } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: hasPerm, error: permErr } = await jwtClient.rpc(
    "current_user_has_permission",
    { perm_key: "reports.manage" },
  );
  if (permErr) {
    log("perm_check_error", { code: permErr.code, msg: permErr.message });
    return json({ code: "permission_denied" }, 403);
  }
  if (hasPerm !== true) {
    return json({ code: "permission_denied" }, 403);
  }

  // ── Layer 2: service-role-only atomic resolve RPC. ──
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: rows, error: rpcErr } = await adminClient.rpc(
    "resolve_report_internal",
    {
      p_report_id: reportId,
      p_actor_user_id: jwtSub,
      p_action: action,
      p_note: note,
    },
  );
  if (rpcErr) {
    log("resolve_rpc_error", { code: rpcErr.code, msg: rpcErr.message });
    // ERRCODE 23514 = already_resolved (open-status guard, SC-015).
    if (rpcErr.code === "23514" || rpcErr.message?.includes("already_resolved")) {
      return json({ code: "already_resolved" }, 409);
    }
    // ERRCODE 23503 = report_not_found.
    if (rpcErr.code === "23503" || rpcErr.message?.includes("report_not_found")) {
      return json({ code: "report_not_found" }, 404);
    }
    return json({ code: "internal_error", message: rpcErr.message }, 500);
  }

  const data = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
  if (data === null) {
    return json({ code: "report_not_found" }, 404);
  }

  log("resolve_success", { report_id: reportId, action });
  return json(
    {
      report_status: data.report_status,
      listing_id: data.listing_id,
      listing_status: data.listing_status,
    },
    200,
  );
});
