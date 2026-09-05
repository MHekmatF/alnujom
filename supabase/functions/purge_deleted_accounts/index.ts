// purge_deleted_accounts — finish what "Delete my account" starts.
//
//   POST /functions/v1/purge_deleted_accounts
//   Headers: Authorization: Bearer <admin user JWT holding users.suspend>
//            — or —       Authorization: Bearer <Vault housekeeping_token>   (pg_cron, plan A32)
//   Body   : { "grace_days": 30 }        (optional, 0–365, default 30)
//            { "dry_run": true }         (optional — report, change nothing)
//   Out    : 200 { scanned, purged, skipped, results: [...] }
//            403 { code: "permission_denied" }
//
// WHY THIS EXISTS
//   `request_account_deletion()` soft-deletes and anonymises: it neutralises the
//   sign-in identifier, blanks the profile, and flips every listing to
//   `status='deleted'`. It deliberately does NOT remove the `auth.users` row or
//   the account's uploaded files — that is left to a privileged sweep, and
//   `public.account_deletion_requests` is the work queue it left behind. The
//   published privacy policy promises the deletion is real, so the sweep has to
//   exist.
//
// WHAT IT CAN FIND, AND WHY (checked 2026-09-03)
//   A first reading suggested the files were unrecoverable — that listings were
//   deleted outright, taking the only link between a user and their storage
//   paths with them. **That is wrong.** `request_account_deletion` runs
//   `UPDATE public.listings SET status='deleted'`; the row survives,
//   `publisher_user_id` is never nulled, and `listing_media` is not touched at
//   all. So every object still has an exact `storage_path` reachable by a join,
//   and nothing is lost by waiting. There is also no `pg_cron` in this project
//   and no migration that hard-deletes from `public.listings`, so no background
//   job can quietly break that chain either.
//
// THE GRACE PERIOD IS THE POINT
//   Nothing is purged until the request is older than `grace_days` (30 by
//   default). Deletion by mistake is common and this is the only window in which
//   it can be undone. Do not lower it without a reason.
//
// WHO RUNS THIS (changed 2026-09-05, plan A32)
//   Daily, by pg_cron, through pg_net, presenting the Vault secret
//   `housekeeping_token` as its bearer — compared inside the database by
//   `housekeeping_token_matches`, never logged. The service-role key stays in
//   Supabase's own runtime, so ADR-0001 holds. A person holding `users.suspend`
//   can still call it with their JWT, dry_run first. verify_jwt is OFF at the
//   gateway because the housekeeping token is not a JWT; every path below
//   still ends in a 403 unless one of the two callers checks out.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

// `external_link` is deliberately absent: the schema's XOR check guarantees it
// has no storage_path, so there is nothing to remove. A panorama is an
// equirectangular JPEG in the images bucket — supabase_listing_media_datasource
// says so in as many words.
const BUCKETS_BY_KIND: Record<string, string> = {
  image: "listing-images",
  panorama: "listing-images",
  video: "listing-videos",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function log(event: string, extra: Record<string, unknown> = {}): void {
  console.log(JSON.stringify({ fn: "purge_deleted_accounts", event, ...extra }));
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ code: "invalid_request" }, 405);

  let grace = 30;
  let dryRun = false;
  try {
    const raw = await req.text();
    if (raw.trim().length > 0) {
      const body = JSON.parse(raw) as { grace_days?: unknown; dry_run?: unknown };
      if (typeof body.grace_days === "number") {
        if (!Number.isInteger(body.grace_days) || body.grace_days < 0 || body.grace_days > 365) {
          return json({ code: "invalid_request", message: "grace_days must be an integer 0–365" }, 400);
        }
        grace = body.grace_days;
      }
      dryRun = body.dry_run === true;
    }
  } catch {
    return json({ code: "invalid_request" }, 400);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ code: "permission_denied" }, 403);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    log("env_missing");
    return json({ code: "internal_error", message: "env_missing" }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Caller 1 (plan A32): the scheduler's shared bearer, compared inside the
  // database against the Vault secret. Never logged.
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice("Bearer ".length).trim() : "";
  let caller = "";
  const { data: isJob, error: jobErr } = await admin.rpc("housekeeping_token_matches", {
    p_token: bearer,
  });
  if (!jobErr && isJob === true) {
    caller = "scheduler";
  } else {
    // Caller 2: gate on a real permission, checked as the CALLER — same shape
    // as approve_listing. `users.suspend` is the strongest account-lifecycle
    // right that exists — the four are view / approve / reject / suspend, there
    // is no `users.manage` — so whoever may put an account out of use may
    // finish erasing one that asked to go.
    const jwtClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: hasPerm, error: permErr } = await jwtClient.rpc(
      "current_user_has_permission",
      { perm_key: "users.suspend" },
    );
    if (permErr || hasPerm !== true) {
      log("permission_denied", { err: permErr?.code });
      return json({ code: "permission_denied" }, 403);
    }
    caller = "admin";
  }

  const cutoff = new Date(Date.now() - grace * 86_400_000).toISOString();
  const { data: queue, error: queueErr } = await admin
    .from("account_deletion_requests")
    .select("id, user_id, requested_at")
    .eq("purge_status", "pending_auth_purge")
    .lte("requested_at", cutoff)
    .order("requested_at", { ascending: true })
    .limit(50);

  if (queueErr) {
    log("queue_read_error", { code: queueErr.code, msg: queueErr.message });
    return json({ code: "internal_error", message: queueErr.message }, 500);
  }

  const results: Array<Record<string, unknown>> = [];
  let purged = 0;
  let skipped = 0;

  for (const row of queue ?? []) {
    const uid = row.user_id as string;
    const outcome: Record<string, unknown> = { user_id: uid, request_id: row.id };

    // 1. The files. listing_media survives the soft-delete, so a join still
    //    yields the exact object paths. Grouped per bucket because `image` and
    //    `video` live in different ones.
    const { data: media, error: mediaErr } = await admin
      .from("listing_media")
      .select("storage_path, kind, listings!inner(publisher_user_id)")
      .eq("listings.publisher_user_id", uid);

    if (mediaErr) {
      outcome.error = `media_lookup: ${mediaErr.message}`;
      results.push(outcome);
      skipped++;
      continue;
    }

    const byBucket = new Map<string, string[]>();
    for (const m of media ?? []) {
      const bucket = BUCKETS_BY_KIND[(m as { kind: string }).kind];
      const path = (m as { storage_path: string }).storage_path;
      if (!bucket || !path) continue;
      byBucket.set(bucket, [...(byBucket.get(bucket) ?? []), path]);
    }

    let filesRemoved = 0;
    let fileErrors = 0;
    if (!dryRun) {
      for (const [bucket, paths] of byBucket) {
        // remove() takes at most 1000 keys per call.
        for (let i = 0; i < paths.length; i += 500) {
          const slice = paths.slice(i, i + 500);
          const { error } = await admin.storage.from(bucket).remove(slice);
          if (error) {
            fileErrors += slice.length;
            log("storage_remove_error", { bucket, msg: error.message });
          } else {
            filesRemoved += slice.length;
          }
        }
      }
    }
    outcome.files = dryRun
      ? [...byBucket.values()].reduce((n, p) => n + p.length, 0)
      : filesRemoved;
    if (fileErrors > 0) outcome.file_errors = fileErrors;

    // 2. The auth row. Left until after the files: if this fails the queue row
    //    stays pending and the next run retries, whereas deleting the user
    //    first and failing here would strand the objects with no owner to find
    //    them by.
    if (!dryRun) {
      const { error: delErr } = await admin.auth.admin.deleteUser(uid);
      // "not found" means a previous run already removed it — that is success,
      // not a failure, and the queue row should still close.
      if (delErr && !/not.?found/i.test(delErr.message)) {
        outcome.error = `auth_delete: ${delErr.message}`;
        results.push(outcome);
        skipped++;
        continue;
      }
      outcome.auth_deleted = true;

      const { error: markErr } = await admin
        .from("account_deletion_requests")
        .update({ purge_status: "purged", purged_at: new Date().toISOString() })
        .eq("id", row.id);
      if (markErr) {
        outcome.error = `mark_purged: ${markErr.message}`;
        results.push(outcome);
        skipped++;
        continue;
      }
    }

    purged++;
    results.push(outcome);
  }

  log("done", { caller, scanned: queue?.length ?? 0, purged, skipped, grace, dryRun });
  return json({
    caller,
    scanned: queue?.length ?? 0,
    purged,
    skipped,
    grace_days: grace,
    dry_run: dryRun,
    results,
  });
});
