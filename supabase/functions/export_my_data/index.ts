// export_my_data — a copy of everything the app holds about the person asking.
//
//   POST /functions/v1/export_my_data
//   Headers: Authorization: Bearer <the caller's own access token>
//   Out    : 200 application/json — one document, sections listed below
//            401 { code: "auth_required" }   (no token, a stale one, or a guest)
//            405 { code: "invalid_request" }
//
// WHY THIS EXISTS (plan A38, review 2026-09-05 §4 G13)
//   Google Play's data-safety form and the published privacy policy both say a
//   person can get a copy of their data. Until now the only way was to ask the
//   founder to run queries by hand. This composes the copy on the server, with
//   the service-role key that never reaches a phone, and the app hands the
//   result to the share sheet as a JSON file.
//
// WHAT IS INCLUDED, AND WHAT IS NOT
//   Everything keyed on the caller's id: profile, preferences, listings (with
//   details, prices and media paths), favorites, saved searches, viewings,
//   conversations and the caller's own messages, inquiries sent and received,
//   reviews written and received, reports filed, CRM leads/notes/reminders,
//   lead events, listing views, notifications, feedback, agencies, approval
//   requests, blocks, ad clicks, roles.
//   Left out on purpose: other people's messages (they belong to them), the
//   encrypted inquirer phone columns (the app never decrypts them either),
//   moderators' internal notes on reports, push tokens (device credentials,
//   not personal data), and audit-log rows (kept for the operator, not the
//   subject).
//
// AUTH
//   The gateway verifies the JWT signature; this function then asks GoTrue who
//   the token belongs to (`auth.getUser`) rather than trusting the `sub` claim
//   alone, so a token that was revoked or belongs to a deleted account is
//   refused. The service-role client is constructed only after that check.
//
// FAILURE SHAPE
//   A section that fails to load becomes `null` and is named in
//   `incomplete_sections`, so a person always gets what could be gathered and
//   can see what could not.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function log(event: string, extra: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ event, ...extra }));
}

type SectionResult = { data: unknown; error: { message: string } | null };

Deno.serve(async (req: Request) => {
  if (req.method !== "POST" && req.method !== "GET") {
    return json({ code: "invalid_request" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return json({ code: "auth_required" }, 401);
  }
  const token = authHeader.slice("Bearer ".length).trim();

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    log("env_missing");
    return json({ code: "internal_error", message: "env_missing" }, 500);
  }

  // ── Who is asking? GoTrue answers, not the token's own claims. ──
  const jwtClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await jwtClient.auth.getUser(
    token,
  );
  const user = userData?.user;
  if (userError || !user || user.is_anonymous) {
    log("auth_refused", { message: userError?.message ?? "no_user" });
    return json({ code: "auth_required" }, 401);
  }
  const uid = user.id;

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const sections: Record<string, unknown> = {};
  const incomplete: string[] = [];

  async function take(name: string, run: () => PromiseLike<SectionResult>) {
    try {
      const { data, error } = await run();
      if (error) {
        incomplete.push(name);
        sections[name] = null;
        log("section_failed", { name, message: error.message });
        return;
      }
      sections[name] = data ?? [];
    } catch (e) {
      incomplete.push(name);
      sections[name] = null;
      log("section_threw", { name, message: String(e) });
    }
  }

  const either = (a: string, b: string) => `${a}.eq.${uid},${b}.eq.${uid}`;

  await take("profile", () =>
    admin
      .from("profiles")
      .select(
        "user_id, full_name, username, phone, email, avatar_url, account_status, publisher_status, terms_version, terms_accepted_at, created_at, updated_at",
      )
      .eq("user_id", uid)
      .maybeSingle());
  await take("preferences", () =>
    admin.from("user_preferences").select("*").eq("user_id", uid).maybeSingle());
  await take("roles", () =>
    admin.from("user_roles").select("*").eq("user_id", uid));
  await take("listings", () =>
    admin
      .from("listings")
      .select(
        "*, listing_details(*), listing_prices(*), listing_media(id, kind, storage_path, thumbnail_path, external_url, ordering, is_main, watermarked, created_at)",
      )
      .eq("publisher_user_id", uid)
      .order("created_at", { ascending: false }));
  await take("listing_revisions", () =>
    admin.from("listing_revisions").select("*").eq("publisher_user_id", uid));
  await take("favorites", () =>
    admin.from("favorites").select("listing_id, created_at").eq("user_id", uid));
  await take("saved_searches", () =>
    admin.from("saved_searches").select("*").eq("user_id", uid));
  await take("viewings", () =>
    admin
      .from("viewings")
      .select("*")
      .or(either("requester_user_id", "publisher_user_id")));
  await take("conversations", () =>
    admin
      .from("conversations")
      .select("id, listing_id, buyer_user_id, publisher_user_id, created_at, last_message_at")
      .or(either("buyer_user_id", "publisher_user_id")));
  await take("messages_sent", () =>
    admin
      .from("messages")
      .select("id, conversation_id, body, created_at, read_at")
      .eq("sender_user_id", uid)
      .order("created_at", { ascending: true }));
  await take("inquiries_sent", () =>
    admin
      .from("inquiries")
      .select("id, listing_id, sender_name, message, status, created_at, updated_at")
      .eq("sender_user_id", uid));
  await take("inquiries_received", () =>
    admin
      .from("inquiries")
      .select("id, listing_id, sender_name, message, status, created_at, updated_at")
      .eq("publisher_user_id", uid));
  await take("reviews_written", () =>
    admin.from("reviews").select("*").eq("reviewer_user_id", uid));
  await take("reviews_received", () =>
    admin
      .from("reviews")
      .select("id, listing_id, rating, comment, created_at")
      .eq("target_user_id", uid));
  await take("reports_filed", () =>
    admin
      .from("reports")
      .select("id, listing_id, target_user_id, reason, note, status, created_at")
      .eq("reporter_user_id", uid));
  await take("crm_leads", () =>
    admin.from("crm_leads").select("*").eq("publisher_user_id", uid));
  await take("crm_notes", () =>
    admin.from("crm_notes").select("*").eq("publisher_user_id", uid));
  await take("crm_reminders", () =>
    admin.from("crm_reminders").select("*").eq("publisher_user_id", uid));
  await take("lead_events", () =>
    admin.from("lead_events").select("*").eq("user_id", uid));
  await take("listing_views", () =>
    admin
      .from("listing_views")
      .select("listing_id, viewed_on")
      .eq("viewer_key", uid));
  await take("notifications", () =>
    admin
      .from("notifications")
      .select("id, type, params, read_at, created_at")
      .eq("recipient_user_id", uid));
  await take("feedback", () =>
    admin
      .from("feedback")
      .select("id, category, message, app_build, platform, status, created_at")
      .eq("user_id", uid));
  await take("agencies_owned", () =>
    admin.from("agencies").select("*").eq("owner_user_id", uid));
  await take("agency_memberships", () =>
    admin.from("agency_members").select("*").eq("user_id", uid));
  await take("account_approval_requests", () =>
    admin
      .from("account_approval_requests")
      .select("id, status, rejection_reason, created_at, reviewed_at")
      .eq("user_id", uid));
  await take("blocked_users", () =>
    admin
      .from("user_blocks")
      .select("blocked_user_id, created_at")
      .eq("blocker_user_id", uid));
  await take("ad_clicks", () =>
    admin.from("ad_impressions").select("*").eq("user_id", uid));

  const exportedAt = new Date().toISOString();
  const body = {
    format: "alnujom-data-export/1",
    exported_at: exportedAt,
    account: {
      id: uid,
      email: user.email ?? null,
      phone: user.phone ?? null,
      created_at: user.created_at,
      last_sign_in_at: user.last_sign_in_at ?? null,
    },
    incomplete_sections: incomplete,
    ...sections,
  };

  log("exported", {
    uid,
    sections: Object.keys(sections).length,
    incomplete: incomplete.length,
  });

  return new Response(JSON.stringify(body, null, 2), {
    status: 200,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Content-Disposition":
        `attachment; filename="alnujom-data-${exportedAt.slice(0, 10)}.json"`,
    },
  });
});
