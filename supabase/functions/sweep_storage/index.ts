// sweep_storage — storage hygiene: remove the files nobody owns, and finish
// what a listing delete started. Plan A25 (review 2026-09-05 §2.1).
//
//   POST /functions/v1/sweep_storage
//   Headers: Authorization: Bearer <admin user JWT holding users.suspend>
//            — or —       Authorization: Bearer <Vault housekeeping_token>   (pg_cron, plan A32)
//   Body   : { "dry_run": true }                     (optional — report, change nothing)
//            { "orphan_grace_days": 7 }              (optional, 1–365; default 7)
//            { "deleted_listing_grace_days": 30 }    (optional, 1–365; default 30)
//   Out    : 200 { dry_run, orphans: {found, bytes, removed, errors},
//                  deleted_listings: {listings, files, removed, rows_deleted, errors},
//                  sample: [...] }
//            403 { code: "permission_denied" }
//
// WHY THIS EXISTS
//   On 2026-09-05 the two listing buckets held 22 MB, and 12.5 MB of it matched
//   no `listing_media` row: photos of listings hard-deleted before A15, the
//   originals of replaced photos, one video whose upload never reached its
//   row. And since A15 made publisher delete a soft delete, a deleted listing on
//   a living account keeps its photos forever — `purge_deleted_accounts` only
//   looks at accounts that asked to leave. Storage is the first Free-plan wall.
//
// WHAT IT REMOVES, AND WHAT IT LEAVES
//   1. Orphans: objects in listing-images / listing-videos that no media row
//      references (original or thumbnail) and that are older than the grace —
//      an upload still in flight is not an orphan yet.
//   2. Soft-deleted listings past the grace: their files, then their media
//      rows. Listings whose owner has a PENDING account purge are left alone —
//      that job needs the rows to find the files, and it runs on its own clock.
//   The listing row itself is never touched; `status = 'deleted'` stays as the
//   audit trail. Files go first, rows second, so a failure leaves a row that
//   the next run will list again rather than a file nothing can find.
//
// AUTH
//   Two callers, checked in this order: the scheduler's shared bearer (compared
//   in the database against the Vault secret, never logged), else a real user
//   whose JWT holds `users.suspend` — the same right that gates the account
//   purge. Anything else is 403. verify_jwt is OFF at the gateway for exactly
//   this reason: the housekeeping token is not a JWT.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const REMOVE_BATCH = 500; // storage remove() takes at most 1000 keys per call

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function log(event: string, extra: Record<string, unknown> = {}): void {
  console.log(JSON.stringify({ fn: "sweep_storage", event, ...extra }));
}

function readDays(raw: unknown, fallback: number): number | null {
  if (raw === undefined) return fallback;
  if (typeof raw !== "number" || !Number.isInteger(raw) || raw < 1 || raw > 365) return null;
  return raw;
}

async function removeByBucket(
  admin: ReturnType<typeof createClient>,
  byBucket: Map<string, string[]>,
): Promise<{ removed: number; errors: number }> {
  let removed = 0;
  let errors = 0;
  for (const [bucket, paths] of byBucket) {
    for (let i = 0; i < paths.length; i += REMOVE_BATCH) {
      const slice = paths.slice(i, i + REMOVE_BATCH);
      const { error } = await admin.storage.from(bucket).remove(slice);
      if (error) {
        errors += slice.length;
        log("storage_remove_error", { bucket, count: slice.length, msg: error.message });
      } else {
        removed += slice.length;
      }
    }
  }
  return { removed, errors };
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ code: "invalid_request" }, 405);

  let dryRun = false;
  let orphanGrace = 7;
  let deletedGrace = 30;
  try {
    const raw = await req.text();
    if (raw.trim().length > 0) {
      const body = JSON.parse(raw) as {
        dry_run?: unknown;
        orphan_grace_days?: unknown;
        deleted_listing_grace_days?: unknown;
      };
      dryRun = body.dry_run === true;
      const og = readDays(body.orphan_grace_days, 7);
      const dg = readDays(body.deleted_listing_grace_days, 30);
      if (og === null || dg === null) {
        return json({ code: "invalid_request", message: "grace days must be integers 1–365" }, 400);
      }
      orphanGrace = og;
      deletedGrace = dg;
    }
  } catch {
    return json({ code: "invalid_request" }, 400);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice("Bearer ".length).trim() : "";
  if (bearer.length === 0) return json({ code: "permission_denied" }, 403);

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

  // Caller 1: the scheduler. Compared inside the database; the token itself is
  // never logged and never leaves this request.
  let caller = "";
  const { data: isJob, error: jobErr } = await admin.rpc("housekeeping_token_matches", {
    p_token: bearer,
  });
  if (!jobErr && isJob === true) {
    caller = "scheduler";
  } else {
    // Caller 2: a person with the account-lifecycle right, checked as the CALLER.
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

  const sample: Array<Record<string, unknown>> = [];

  // 1. Orphans.
  const { data: orphans, error: orphanErr } = await admin.rpc("list_orphan_media_objects", {
    p_grace: `${orphanGrace} days`,
  });
  if (orphanErr) {
    log("orphan_list_error", { code: orphanErr.code, msg: orphanErr.message });
    return json({ code: "internal_error", message: orphanErr.message }, 500);
  }
  const orphanRows = (orphans ?? []) as Array<{ bucket_id: string; name: string; size_bytes: number }>;
  const orphanBytes = orphanRows.reduce((n, r) => n + (Number(r.size_bytes) || 0), 0);
  const orphanByBucket = new Map<string, string[]>();
  for (const r of orphanRows) {
    orphanByBucket.set(r.bucket_id, [...(orphanByBucket.get(r.bucket_id) ?? []), r.name]);
    if (sample.length < 20) sample.push({ kind: "orphan", bucket: r.bucket_id, name: r.name, bytes: r.size_bytes });
  }
  let orphanRemoved = 0;
  let orphanErrors = 0;
  if (!dryRun && orphanRows.length > 0) {
    const res = await removeByBucket(admin, orphanByBucket);
    orphanRemoved = res.removed;
    orphanErrors = res.errors;
  }

  // 2. Soft-deleted listings past the grace: files, then rows.
  const { data: purgeable, error: purgeErr } = await admin.rpc("list_purgeable_listing_media", {
    p_grace: `${deletedGrace} days`,
  });
  if (purgeErr) {
    log("purgeable_list_error", { code: purgeErr.code, msg: purgeErr.message });
    return json({ code: "internal_error", message: purgeErr.message }, 500);
  }
  const purgeRows = (purgeable ?? []) as Array<{ media_id: string; listing_id: string; bucket_id: string; name: string }>;
  const purgeByBucket = new Map<string, string[]>();
  const mediaIds = new Set<string>();
  const listingIds = new Set<string>();
  for (const r of purgeRows) {
    purgeByBucket.set(r.bucket_id, [...(purgeByBucket.get(r.bucket_id) ?? []), r.name]);
    mediaIds.add(r.media_id);
    listingIds.add(r.listing_id);
    if (sample.length < 40) sample.push({ kind: "deleted_listing", listing_id: r.listing_id, bucket: r.bucket_id, name: r.name });
  }
  let purgeRemoved = 0;
  let purgeErrors = 0;
  let rowsDeleted = 0;
  if (!dryRun && purgeRows.length > 0) {
    const res = await removeByBucket(admin, purgeByBucket);
    purgeRemoved = res.removed;
    purgeErrors = res.errors;
    // Rows only after the files, and only when every file went: a row that
    // outlives a failed remove is re-listed next run; a file that outlives its
    // row is an orphan the first pass will catch after the grace anyway — but
    // there is no reason to make one on purpose.
    if (res.errors === 0) {
      const ids = [...mediaIds];
      for (let i = 0; i < ids.length; i += REMOVE_BATCH) {
        const slice = ids.slice(i, i + REMOVE_BATCH);
        const { error: delErr, count } = await admin
          .from("listing_media")
          .delete({ count: "exact" })
          .in("id", slice);
        if (delErr) {
          log("media_rows_delete_error", { code: delErr.code, msg: delErr.message });
        } else {
          rowsDeleted += count ?? slice.length;
        }
      }
    }
  }

  log("done", {
    caller,
    dryRun,
    orphans: orphanRows.length,
    orphanBytes,
    orphanRemoved,
    deletedListings: listingIds.size,
    purgeFiles: purgeRows.length,
    purgeRemoved,
    rowsDeleted,
  });
  return json({
    dry_run: dryRun,
    caller,
    orphan_grace_days: orphanGrace,
    deleted_listing_grace_days: deletedGrace,
    orphans: { found: orphanRows.length, bytes: orphanBytes, removed: orphanRemoved, errors: orphanErrors },
    deleted_listings: {
      listings: listingIds.size,
      files: purgeRows.length,
      removed: purgeRemoved,
      rows_deleted: rowsDeleted,
      errors: purgeErrors,
    },
    sample,
  });
});
