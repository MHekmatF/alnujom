// Phase 22 (spec/022-notifications-realtime) — dispatch_push Edge Function.
//
// Contract: specs/022-notifications-realtime/contracts/phase22-dispatch-push-edge-function.md
// Runtime mirrors supabase/functions/approve_listing/index.ts (createClient service-role,
// defensive JSON envelope, no secret logging).
//
// Invoked by the notify_push_dispatch() trigger (pg_net) AFTER INSERT on notifications:
//   POST <push_dispatch_url>
//   Authorization: Bearer <push_dispatch_token>
//   { notification_id, recipient_user_id, type, params }
//
// Behavior (all skip/degrade paths return 200 — NEVER throw back into the trigger):
//   1. Verify the dispatch token (Bearer == Vault push_dispatch_token) else 401.
//   2. Read fcm_service_account via Vault; null → 200 {skipped:'no_provider'} (FR-013).
//   3. Read recipient user_preferences.notifications_enabled; false → 200 {skipped:'muted'} (FR-021).
//   4. Resolve recipient locale (default 'ar' — Arabic-first, FR-004).
//   5. Render GENERIC bilingual title/body by type — NO moderator free-text / reason (FR-004).
//   6. Select active notification_tokens; none → 200 {skipped:'no_tokens'}.
//   7. Mint an OAuth token from the service account; POST FCM HTTP v1 per device with
//      notification:{title,body} + data:{type, ...params} (data drives the on-tap deep link — FR-012).
//      Prune tokens FCM reports UNREGISTERED. 200 {sent:N, pruned:M}.
//
// The fcm_service_account secret is read ONLY here, via Vault — never committed, never shipped
// to the client (FR-018 / SC-007 / ADR-0001). No PII/free-text in the payload — UUIDs + generic copy.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URI_DEFAULT = "https://oauth2.googleapis.com/token";

type NotificationType =
  | "account_approved"
  | "account_rejected"
  | "listing_approved"
  | "listing_rejected"
  | "inquiry_received"
  | "agency_invitation"
  | "saved_search_match";

interface DispatchBody {
  notification_id?: unknown;
  recipient_user_id?: unknown;
  type?: unknown;
  params?: unknown;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function log(event: string, extra: Record<string, unknown> = {}) {
  // NEVER log secret material — only ids/counts.
  console.log(JSON.stringify({ event, ...extra }));
}

// ─── Generic, locale-correct tray copy (NO reason text — FR-004) ───────────
const COPY: Record<NotificationType, { ar: [string, string]; en: [string, string] }> = {
  account_approved: {
    ar: ["تم اعتماد الحساب", "تمت الموافقة على حسابك"],
    en: ["Account approved", "Your account has been approved"],
  },
  account_rejected: {
    ar: ["تحديث على الحساب", "تمت مراجعة حسابك — اضغط للتفاصيل"],
    en: ["Account update", "Your account was reviewed — tap for details"],
  },
  listing_approved: {
    ar: ["تم اعتماد الإعلان", "تمت الموافقة على إعلانك"],
    en: ["Listing approved", "Your listing has been approved"],
  },
  listing_rejected: {
    ar: ["تحديث على الإعلان", "تمت مراجعة إعلانك — اضغط للتفاصيل"],
    en: ["Listing reviewed", "Your listing was reviewed — tap for details"],
  },
  inquiry_received: {
    ar: ["استفسار جديد", "لديك استفسار جديد على إعلانك"],
    en: ["New inquiry", "You have a new inquiry on your listing"],
  },
  agency_invitation: {
    ar: ["دعوة إلى مكتب", "تمت دعوتك للانضمام إلى مكتب"],
    en: ["Agency invitation", "You have been invited to join an agency"],
  },
  // Phase 035 — enable OS pushes for saved-search matches (previously not in
  // COPY, so they were dropped as bad_request). Gated by notif_new_matches.
  saved_search_match: {
    ar: ["عقار جديد مطابق", "نزل عقار جديد يطابق بحثك المحفوظ"],
    en: ["New matching listing", "A new listing matches your saved search"],
  },
};

function renderCopy(type: NotificationType, locale: string): { title: string; body: string } {
  const lang = locale === "en" ? "en" : "ar"; // Arabic-first default (FR-004)
  const entry = COPY[type];
  const [title, body] = entry[lang];
  return { title, body };
}

// ─── OAuth: mint an access token from the service account (JWT RS256 → token endpoint) ──
function base64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlFromString(s: string): string {
  return base64url(new TextEncoder().encode(s));
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

async function mintAccessToken(sa: ServiceAccount): Promise<string> {
  const tokenUri = sa.token_uri || TOKEN_URI_DEFAULT;
  const now = Math.floor(Date.now() / 1000);
  const header = base64urlFromString(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64urlFromString(
    JSON.stringify({
      iss: sa.client_email,
      scope: FCM_SCOPE,
      aud: tokenUri,
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signingInput)),
  );
  const jwt = `${signingInput}.${base64url(sig)}`;

  const resp = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!resp.ok) {
    throw new Error(`oauth_token_failed_${resp.status}`);
  }
  const data = (await resp.json()) as { access_token?: string };
  if (!data.access_token) throw new Error("oauth_token_missing");
  return data.access_token;
}

// Map the notification params (UUIDs only) to FCM data strings (FCM data values must be strings).
function toDataMap(type: string, params: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = { type };
  for (const [k, v] of Object.entries(params ?? {})) {
    if (v != null) out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return out;
}

Deno.serve(async (req: Request) => {
  // Top-level guard: every path returns a 2xx/4xx envelope; we NEVER throw back into the trigger.
  try {
    if (req.method !== "POST") {
      return json({ skipped: "method_not_allowed" }, 200);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      log("env_missing");
      return json({ skipped: "env_missing" }, 200);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 1. Dispatch-token auth (shared bearer set by the trigger from Vault push_dispatch_token).
    const authHeader = req.headers.get("Authorization") ?? "";
    const presented = authHeader.startsWith("Bearer ")
      ? authHeader.slice("Bearer ".length).trim()
      : "";
    const { data: expectedToken, error: tokErr } = await adminClient.rpc("app_vault_secret", {
      p_name: "push_dispatch_token",
    });
    if (tokErr) {
      log("dispatch_token_read_error", { code: tokErr.code });
      return json({ skipped: "token_unreadable" }, 200);
    }
    if (!expectedToken || presented.length === 0 || presented !== expectedToken) {
      return json({ code: "unauthorized" }, 401);
    }

    // Parse the trigger payload.
    let body: DispatchBody;
    try {
      body = (await req.json()) as DispatchBody;
    } catch {
      return json({ skipped: "bad_request" }, 200);
    }
    const recipientId = typeof body.recipient_user_id === "string" ? body.recipient_user_id : null;
    const type = typeof body.type === "string" ? (body.type as NotificationType) : null;
    const notificationId = typeof body.notification_id === "string" ? body.notification_id : null;
    const params = (body.params && typeof body.params === "object")
      ? (body.params as Record<string, unknown>)
      : {};
    if (!recipientId || !type || !(type in COPY)) {
      return json({ skipped: "bad_request" }, 200);
    }

    // 2. Provider check — FCM service-account JSON from Vault. Absent → degraded (FR-013/SC-003).
    const { data: saJsonRaw, error: saErr } = await adminClient.rpc("app_vault_secret", {
      p_name: "fcm_service_account",
    });
    if (saErr) {
      log("fcm_secret_read_error", { code: saErr.code });
      return json({ skipped: "no_provider" }, 200);
    }
    if (!saJsonRaw) {
      return json({ skipped: "no_provider" }, 200);
    }
    let sa: ServiceAccount;
    try {
      sa = JSON.parse(saJsonRaw as string) as ServiceAccount;
    } catch {
      log("fcm_secret_parse_error");
      return json({ skipped: "no_provider" }, 200);
    }
    if (!sa.client_email || !sa.private_key || !sa.project_id) {
      return json({ skipped: "no_provider" }, 200);
    }

    // 3 + 4. Recipient preference (global mute + per-category) + locale.
    const { data: pref } = await adminClient
      .from("user_preferences")
      .select(
        "notifications_enabled, locale, notif_new_matches, notif_messages, notif_marketing",
      )
      .eq("user_id", recipientId)
      .maybeSingle();
    if (pref && pref.notifications_enabled === false) {
      return json({ skipped: "muted" }, 200); // history already written (FR-021)
    }
    // Phase 035 — per-category mute. Transactional types (account/listing
    // approval + rejection) are ALWAYS delivered; only the user-muteable
    // categories gate here. History rows are written by the trigger regardless.
    const categoryColumn = type === "saved_search_match"
      ? "notif_new_matches"
      : (type === "inquiry_received" || type === "agency_invitation")
      ? "notif_messages"
      : null;
    if (
      categoryColumn && pref &&
      (pref as Record<string, unknown>)[categoryColumn] === false
    ) {
      return json({ skipped: "category_muted" }, 200);
    }
    const locale = (pref?.locale as string) ?? "ar";

    // 5. Generic, locale-correct copy (no reason text — FR-004).
    const { title, body: copyBody } = renderCopy(type, locale);

    // 6. Active device tokens for the recipient.
    const { data: tokenRows, error: tokenSelErr } = await adminClient
      .from("notification_tokens")
      .select("token")
      .eq("user_id", recipientId)
      .eq("is_active", true);
    if (tokenSelErr) {
      log("token_select_error", { code: tokenSelErr.code });
      return json({ skipped: "no_tokens" }, 200);
    }
    const tokens = (tokenRows ?? [])
      .map((r) => (r as { token: string }).token)
      .filter((t) => typeof t === "string" && t.length > 0);
    if (tokens.length === 0) {
      return json({ skipped: "no_tokens" }, 200);
    }

    // 7. Mint OAuth + send FCM HTTP v1 per device.
    let accessToken: string;
    try {
      accessToken = await mintAccessToken(sa);
    } catch (e) {
      log("oauth_mint_error", { msg: String(e) });
      return json({ skipped: "no_provider" }, 200);
    }

    const dataMap = toDataMap(type, params);
    // Carry the notification row id so the app's deep-link resolver can mark
    // exactly this row read on tap (SC-002 / FR-012).
    if (notificationId) dataMap.notification_id = notificationId;
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    let sent = 0;
    const stale: string[] = [];

    for (const token of tokens) {
      try {
        const resp = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body: copyBody },
              data: dataMap,
              android: { priority: "high" },
            },
          }),
        });
        if (resp.ok) {
          sent++;
        } else {
          let errText = "";
          try {
            errText = await resp.text();
          } catch { /* ignore */ }
          // FCM reports a dead token as 404 NOT_FOUND / UNREGISTERED (or 400 invalid) → prune.
          if (resp.status === 404 || /UNREGISTERED|InvalidRegistration|NotRegistered/.test(errText)) {
            stale.push(token);
          } else {
            log("fcm_send_error", { status: resp.status });
          }
        }
      } catch (e) {
        log("fcm_fetch_error", { msg: String(e) });
        // transient — leave the token, do not prune.
      }
    }

    // Prune tokens FCM reports as UNREGISTERED (service-role bypasses RLS).
    let pruned = 0;
    if (stale.length > 0) {
      const { error: pruneErr } = await adminClient
        .from("notification_tokens")
        .delete()
        .eq("user_id", recipientId)
        .in("token", stale);
      if (pruneErr) {
        log("token_prune_error", { code: pruneErr.code });
      } else {
        pruned = stale.length;
      }
    }

    log("dispatch_done", { sent, pruned, tokens: tokens.length });
    return json({ sent, pruned }, 200);
  } catch (e) {
    // Absolute backstop — never propagate an exception back to the trigger path.
    log("dispatch_unhandled", { msg: String(e) });
    return json({ skipped: "error" }, 200);
  }
});
