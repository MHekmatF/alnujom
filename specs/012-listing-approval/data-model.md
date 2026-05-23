# Phase 1 Data Model — Phase 12: Listing Approval Workflow

**Date**: 2026-05-23
**Branch**: `012-listing-approval`
**Spec**: [spec.md](spec.md)
**Plan**: [plan.md](plan.md)
**Research**: [research.md](research.md)

> **Scope**: Phase 12 introduces ZERO new tables, ZERO new columns, ZERO new RLS policies. All Phase 12 backend artifacts are FUNCTION amendments via `CREATE OR REPLACE FUNCTION` in one migration + two new Edge Functions + a Dart entity / DTO / use case surface. This data model documents the FUNCTION amendment bodies in full + the Dart-side type contracts.

## 1. Backend: SQL migration `20260523120004_amend_phase10_phase4_triggers_for_session_var.sql`

### 1.1 Session-variable setter functions (R-43)

```sql
-- Setter for the admin's UID. Called by the approve_listing AND reject_listing
-- Edge Functions immediately BEFORE the privileged UPDATE so the amended
-- trigger functions can source `changed_by` AND `actor_user_id` via the
-- session variable instead of the service-role client's auth.uid() (which is NULL).
--
-- The session variable is scoped to the current transaction (third arg `true`),
-- so it leaks neither to subsequent requests nor to other concurrent transactions.
CREATE OR REPLACE FUNCTION public.set_app_user_id_for_session(user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.current_user_id', user_id::text, true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_app_user_id_for_session(UUID) TO service_role;
-- NOTE: Intentionally NOT granted to authenticated or anon. The only caller is
-- the Edge Function's service-role-bound client.

-- Setter for the rejection-reason JSON-encoded TEXT payload (Q4=A storage rep).
-- Called by the reject_listing Edge Function immediately BEFORE the UPDATE so
-- the amended status-transition trigger can source the `reason` column from
-- the session variable instead of the hardcoded NULL from Phase 10's original
-- trigger body.
CREATE OR REPLACE FUNCTION public.set_app_rejection_reason_for_session(reason_json TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.current_rejection_reason', reason_json, true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_app_rejection_reason_for_session(TEXT) TO service_role;
```

### 1.2 Amended `public.listing_status_transition_trigger_fn()` (R-43 + R-49)

```sql
-- Phase 10's status-transition trigger function, amended in Phase 12 to source
-- `changed_by` AND `reason` via session variables when set (Q7=A + Q4=A).
-- Phase 10's original migration file 20260519120006_create_listing_status_history.sql
-- remains UNEDITED per Phase 11 R-35 immutability.
--
-- Amendment diff vs Phase 10 original:
--   Phase 10: VALUES (NEW.id, NULL, NEW.status, auth.uid(), NULL);
--   Phase 12: VALUES (
--               NEW.id,
--               NULL,
--               NEW.status,
--               coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
--               nullif(current_setting('app.current_rejection_reason', true), '')
--             );
--   (And the analogous change in the UPDATE branch.)
CREATE OR REPLACE FUNCTION public.listing_status_transition_trigger_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason)
    VALUES (
      NEW.id,
      NULL,
      NEW.status,
      coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
      nullif(current_setting('app.current_rejection_reason', true), '')
    );
  ELSIF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason)
    VALUES (
      NEW.id,
      OLD.status,
      NEW.status,
      coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
      nullif(current_setting('app.current_rejection_reason', true), '')
    );
  END IF;
  RETURN NEW;
END;
$$;
```

**Behavior matrix**:

| Caller context | `app.current_user_id` set? | `app.current_rejection_reason` set? | `changed_by` source | `reason` source |
|---|---|---|---|---|
| Phase 10 `submit_listing` (direct user JWT) | NO | NO | `auth.uid()` (publisher's UID) | NULL |
| Phase 12 `approve_listing` Edge Function | YES (admin UID) | NO | admin UID via session var | NULL |
| Phase 12 `reject_listing` Edge Function | YES (admin UID) | YES (JSON payload) | admin UID via session var | JSON-encoded reason |
| Future direct-SQL admin action | NO | NO | `auth.uid()` (admin's UID per JWT) | NULL |

### 1.3 Amended `public.listings_audit_trigger_fn()` (R-49)

```sql
-- Phase 10's listings audit-trigger function, amended in Phase 12 to source
-- `actor_user_id` via session variable when set (Q7=A).
-- The function emits the same six action keys it always has — Phase 12 does
-- NOT add new action keys (listing.approved + listing.rejected were already
-- emitted by Phase 10's trigger via the standard listing.updated path with a
-- status-specific verb derivation; verify in Phase 10's original body).
--
-- Amendment diff vs Phase 10 original:
--   Phase 10: VALUES (auth.uid(), v_action, 'listings', NEW.id::text, ...);
--   Phase 12: VALUES (
--               coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
--               v_action, 'listings', NEW.id::text, ...
--             );
--   (Repeated for each INSERT INTO audit_logs in the function body.)
CREATE OR REPLACE FUNCTION public.listings_audit_trigger_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_action      TEXT;
  v_status_verb TEXT;
BEGIN
  -- (Phase 10's logic — copy verbatim from 20260519120006_create_listing_status_history.sql
  -- lines 53–86, replacing every `auth.uid()` in INSERT INTO audit_logs with
  -- `coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid())`.)
  --
  -- Phase 12 implementer: read Phase 10's body via the migration file and
  -- transcribe with the COALESCE substitution. The contract preserves all six
  -- action keys (listing.created, listing.updated, listing.approved,
  -- listing.rejected, listing.paused, listing.deleted) and their JSONB shapes.
  RETURN NEW;
END;
$$;
```

> **NOTE for implementer**: The Phase 10 body is at lines 53–86 of `supabase/migrations/20260519120006_create_listing_status_history.sql`. The amendment is mechanical — find every `auth.uid()` inside an `INSERT INTO audit_logs (actor_user_id, ...) VALUES (auth.uid(), ...)` AND replace with the COALESCE expression. Do NOT replace `auth.uid()` calls elsewhere in the function (e.g., in WHERE clauses that filter by the calling user).

### 1.4 Amended `public.log_audit()` (Phase 4)

```sql
-- Phase 4's reusable audit-trigger function, narrowly amended in Phase 12 to
-- source `actor_user_id` via session variable when set (Q7=A + R-43).
-- Phase 4's original migration file 20260506120004_create_audit_logs.sql
-- remains UNEDITED per Phase 11 R-35 immutability.
--
-- Amendment diff vs Phase 4 original (line 76 of 20260506120004_create_audit_logs.sql):
--   Phase 4: VALUES (auth.uid(), v_action, TG_TABLE_NAME, v_target_id, v_before, v_after);
--   Phase 12: VALUES (
--               coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
--               v_action, TG_TABLE_NAME, v_target_id, v_before, v_after
--             );
--
-- The R-05 byte-identical-reuse invariant is narrowly relaxed from "byte-identical"
-- to "byte-identical except for this single-line COALESCE amendment". Every
-- Phase 5–11 caller (account_approvals audit triggers, roles/permissions audit
-- triggers, locations/currencies audit triggers, listing_media audit triggers,
-- etc.) continues to produce correctly-attributed audit rows because the
-- COALESCE falls back to auth.uid() when the session variable is unset.
CREATE OR REPLACE FUNCTION public.log_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_action     TEXT;
  v_target_id  TEXT;
  v_before     JSONB;
  v_after      JSONB;
BEGIN
  -- (Phase 4's logic verbatim — copy lines 22–74 of 20260506120004_create_audit_logs.sql.)
  -- Phase 12 amendment ONLY affects the final INSERT statement:
  INSERT INTO audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (
      coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid()),
      v_action, TG_TABLE_NAME, v_target_id, v_before, v_after
    );
  RETURN NULL;
END;
$$;
```

### 1.5 Migration apply order

The single migration applies in one step via Supabase MCP:

```
apply_migration(
  name="20260523120004_amend_phase10_phase4_triggers_for_session_var",
  query=<the full body above: 5 CREATE OR REPLACE FUNCTION statements>
)
```

No data backfill. No row touches. No trigger reattachment (the trigger bindings on the listings table from Phase 10 + on the audit-emitting tables from Phases 5–11 remain attached — `CREATE OR REPLACE FUNCTION` rebinds the function body but does NOT detach triggers).

Verification queries post-apply:

```sql
-- Confirm all 5 function bodies are amended.
SELECT proname, pg_get_functiondef(oid) AS body
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN (
    'set_app_user_id_for_session',
    'set_app_rejection_reason_for_session',
    'listing_status_transition_trigger_fn',
    'listings_audit_trigger_fn',
    'log_audit'
  );

-- Confirm the COALESCE expression appears in each amended trigger body.
SELECT proname,
       (position('coalesce(nullif(current_setting(' IN pg_get_functiondef(oid)) > 0) AS has_coalesce
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('listing_status_transition_trigger_fn', 'listings_audit_trigger_fn', 'log_audit');
-- Expected: all 3 rows have has_coalesce = true.
```

## 2. Backend: Edge Function I/O contracts

### 2.1 `approve_listing`

**Endpoint**: `POST {SUPABASE_URL}/functions/v1/approve_listing`

**Request headers**:
- `Authorization: Bearer <user JWT>` (required — extracted to JWT-bound permission check)
- `Content-Type: application/json`

**Request body**:
```json
{
  "listing_id": "<UUID>"
}
```

**Success response** (HTTP 200):
```json
{
  "status": "approved",
  "published_at": "<ISO 8601 timestamp>",
  "expires_at": null
}
```

**Error responses**:
- HTTP 403 — `{"code":"permission_denied"}` (caller lacks `listings.approve`)
- HTTP 404 — `{"code":"listing_not_found"}` (listing UUID does not exist)
- HTTP 409 — `{"code":"invalid_status_transition","current_status":"<current>"}` (listing is in a status other than `pending_review` AND not already `approved`)
- HTTP 409 — `{"code":"already_acted_on","current_status":"approved"}` (concurrent admin already approved)
- HTTP 400 — `{"code":"invalid_listing_id"}` (body parse failure)
- HTTP 500 — `{"code":"internal_error","message":"<text>"}` (last-resort fallback; Supabase Edge Function runtime error)

### 2.2 `reject_listing`

**Endpoint**: `POST {SUPABASE_URL}/functions/v1/reject_listing`

**Request body**:
```json
{
  "listing_id": "<UUID>",
  "reason_preset": "missing_or_low_quality_photos|incorrect_location|unrealistic_price|incomplete_description|duplicate_listing|other",
  "reason_detail": "<string up to 500 chars, optional>"
}
```

**Success response** (HTTP 200):
```json
{
  "status": "rejected",
  "reason_preset": "<the preset key>",
  "reason_detail": "<the detail or null>"
}
```

**Error responses**: Same as `approve_listing` PLUS:
- HTTP 400 — `{"code":"invalid_reason_preset","allowed":["missing_or_low_quality_photos","incorrect_location","unrealistic_price","incomplete_description","duplicate_listing","other"]}`
- HTTP 400 — `{"code":"reason_detail_too_long","max":500}`

### 2.3 Edge Function call sequence (both functions, simplified)

```ts
// 1. Parse body, extract listing_id (+ reason_preset/detail for reject).
const body = await req.json();

// 2. JWT-bound client for permission check.
const authHeader = req.headers.get('Authorization');
const jwtClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  global: { headers: { Authorization: authHeader } }
});

// 3. Permission check via Phase 6 RPC.
const { data: hasPerm, error: permErr } = await jwtClient.rpc(
  'current_user_has_permission',
  { perm_key: 'listings.approve' }  // or 'listings.reject'
);
if (permErr || !hasPerm) {
  return new Response(JSON.stringify({ code: 'permission_denied' }), { status: 403, ... });
}

// 4. Validate reason_preset + reason_detail (reject_listing only).
// (Skip for approve_listing.)

// 5. Service-role client for the privileged UPDATE.
const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// 6. Extract admin UID from the JWT and set the session variable.
const jwtPayload = parseJwt(authHeader);  // helper extracts sub claim
await adminClient.rpc('set_app_user_id_for_session', { user_id: jwtPayload.sub });

// 7. (reject_listing only) Set the rejection-reason session variable.
const reasonJson = JSON.stringify({ preset: reason_preset, detail: reason_detail ?? null });
await adminClient.rpc('set_app_rejection_reason_for_session', { reason_json: reasonJson });

// 8. UPDATE under the status-guard.
const { data, error } = await adminClient
  .from('listings')
  .update({ status: 'approved', published_at: new Date().toISOString() })  // or status: 'rejected' for reject_listing
  .eq('id', body.listing_id)
  .eq('status', 'pending_review')  // status-guard
  .select('id, status, published_at, expires_at')
  .maybeSingle();

// 9. Handle zero-rows path (concurrent-admin race or invalid status).
if (!data) {
  const { data: current } = await adminClient
    .from('listings')
    .select('status')
    .eq('id', body.listing_id)
    .maybeSingle();
  if (!current) {
    return new Response(JSON.stringify({ code: 'listing_not_found' }), { status: 404, ... });
  }
  const code = current.status === 'approved' || current.status === 'rejected'
    ? 'already_acted_on'
    : 'invalid_status_transition';
  return new Response(JSON.stringify({ code, current_status: current.status }), { status: 409, ... });
}

// 10. Success.
return new Response(JSON.stringify({ status: data.status, published_at: data.published_at, expires_at: data.expires_at }), { status: 200, ... });
```

> **NOTE**: The amended `listing_status_transition_trigger_fn` AND `listings_audit_trigger_fn` fire automatically on the UPDATE in step 8 — the session variables set in steps 6 + 7 are scoped to the same transaction so the triggers see them. `set_config(..., true)` + the UPDATE + the trigger emissions all live inside ONE PostgREST request (Supabase wraps each request in an implicit transaction).

## 3. Flutter: Entity, DTO, Use Case, BLoC shapes

### 3.1 Domain entities

#### `lib/core/listing/rejection_reason.dart`

> **Location update (analysis finding C2 — 2026-05-23)**: The enum was originally planned at `lib/features/admin/listing_review/domain/entities/rejection_reason.dart` but RELOCATED to `lib/core/listing/rejection_reason.dart` because BOTH `admin/listing_review` AND `publisher_dashboard` consume it (the moderation history page + the rejection banner both read the preset key). A shared domain primitive belongs in `lib/core/`, not inside one feature's `domain/`, to avoid cross-feature imports.

```dart
/// The six Q3=A preset keys. Locale-independent at the data layer.
enum RejectionReason {
  missingOrLowQualityPhotos('missing_or_low_quality_photos'),
  incorrectLocation('incorrect_location'),
  unrealisticPrice('unrealistic_price'),
  incompleteDescription('incomplete_description'),
  duplicateListing('duplicate_listing'),
  other('other');

  const RejectionReason(this.key);
  final String key;

  static RejectionReason? fromKey(String key) {
    for (final r in values) {
      if (r.key == key) return r;
    }
    return null;
  }
}
```

#### `lib/features/admin/listing_review/domain/entities/pending_listing_summary.dart`

```dart
/// Aggregate carrying the data needed to render one queue card.
class PendingListingSummary {
  final String id;
  final String title;
  final String? mainImageStoragePath;  // null if no main image (defense-in-depth)
  final ListingPurpose purpose;
  final PropertyType propertyType;
  final String governorateName;
  final String cityName;
  final String areaName;
  final Money primaryPrice;
  final String publisherDisplayName;
  final DateTime submittedAt;
  // ...
}
```

#### `lib/features/admin/listing_review/domain/entities/listing_preview.dart`

```dart
/// Aggregate carrying the full preview payload.
class ListingPreview {
  final Listing listing;                       // Phase 10 entity
  final ListingDetails details;                // Phase 10 entity
  final List<ListingPrice> prices;             // Phase 9 entity
  final List<ListingMedia> media;              // Phase 11 entity
  final Governorate governorate;               // Phase 8 entity
  final City city;
  final Area area;
  final Publisher publisher;                   // Phase 5 entity
  // ...
}
```

#### `lib/features/publisher_dashboard/domain/entities/moderation_history_entry.dart`

```dart
class ModerationHistoryEntry {
  final String id;
  final ListingStatus? previousStatus;     // null for the initial draft creation
  final ListingStatus newStatus;
  final DateTime changedAt;
  final RejectionReason? rejectionPreset;  // null unless newStatus = rejected
  final String? rejectionDetail;           // null if rejectionPreset is null OR if detail was empty
}
```

### 3.2 Data DTOs

#### `lib/features/admin/listing_review/data/dtos/pending_listing_summary_dto.dart`

```dart
class PendingListingSummaryDto {
  // Fields mirror the SELECT shape from the queue join query.
  // Maps to PendingListingSummary via a toEntity() method.
}
```

### 3.3 Repository contracts

#### `lib/features/admin/listing_review/domain/repositories/listing_review_repository.dart`

```dart
abstract class ListingReviewRepository {
  Future<Result<List<PendingListingSummary>, Failure>> loadPendingQueue({
    PendingQueueCursor? cursor,
    int limit,
  });
  Future<Result<ListingPreview, Failure>> loadListingPreview(String listingId);
  Future<Result<ApproveResult, Failure>> approveListing(String listingId);
  Future<Result<RejectResult, Failure>> rejectListing(
    String listingId,
    RejectionReason preset,
    String? detail,
  );
}

class PendingQueueCursor {
  final DateTime lastSubmittedAt;
  final String lastId;
  const PendingQueueCursor(this.lastSubmittedAt, this.lastId);
}

class ApproveResult {
  final DateTime publishedAt;
  final DateTime? expiresAt;  // always null per Q2=A
}

class RejectResult {
  final RejectionReason preset;
  final String? detail;
}
```

### 3.4 Use cases

Each use case is a small class with a single `call(...)` method delegating to the repository. Pattern:

```dart
@injectable
class ApproveListingUseCase {
  ApproveListingUseCase(this._repo);
  final ListingReviewRepository _repo;

  Future<Result<ApproveResult, Failure>> call(String listingId) =>
    _repo.approveListing(listingId);
}
```

### 3.5 Failure subtypes

```dart
// lib/core/errors/failure.dart additions

sealed class Failure {
  const Failure();
}

class PermissionDeniedFailure extends Failure { const PermissionDeniedFailure(); }
class InvalidStatusTransitionFailure extends Failure {
  const InvalidStatusTransitionFailure(this.currentStatus);
  final ListingStatus currentStatus;
}
class AlreadyActedOnFailure extends Failure {
  const AlreadyActedOnFailure(this.currentStatus);
  final ListingStatus currentStatus;
}
class InvalidReasonPresetFailure extends Failure { const InvalidReasonPresetFailure(); }
class ReasonDetailTooLongFailure extends Failure {
  const ReasonDetailTooLongFailure(this.max);
  final int max;
}
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(this.message);
  final String message;
}
```

### 3.6 BLoC event/state shapes

```dart
// lib/features/admin/listing_review/presentation/bloc/pending_queue_bloc.dart

sealed class PendingQueueEvent {}
class PendingQueueLoadFirstPage extends PendingQueueEvent {}
class PendingQueueLoadNextPage extends PendingQueueEvent {}
class PendingQueueRefresh extends PendingQueueEvent {}

class PendingQueueState {
  final List<PendingListingSummary> listings;
  final PendingQueueCursor? nextCursor;
  final bool isLoadingFirstPage;
  final bool isLoadingNextPage;
  final Failure? failure;
  final bool isEmpty;
}

// lib/features/admin/listing_review/presentation/bloc/listing_preview_bloc.dart

sealed class ListingPreviewEvent {}
class ListingPreviewLoad extends ListingPreviewEvent {
  final String listingId;
  ListingPreviewLoad(this.listingId);
}
class ListingPreviewApprovePressed extends ListingPreviewEvent {}
class ListingPreviewRejectPressed extends ListingPreviewEvent {
  final RejectionReason preset;
  final String? detail;
  ListingPreviewRejectPressed(this.preset, this.detail);
}

class ListingPreviewState {
  final ListingPreview? preview;
  final bool isLoading;
  final bool isMutatorInFlight;
  final Failure? failure;
  final ApproveSuccessOrReject? lastSuccess;  // emits once on success → page pops
}
```

## 4. ARB key inventory

Approximately 32 new keys. All ship to `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` in the same commit per Phase 3's localization gate.

| Key | English | Arabic |
|---|---|---|
| `admin.tile.pendingReview` | Pending review | قيد المراجعة |
| `admin.queue.title` | Pending review | قيد المراجعة |
| `admin.queue.empty` | No listings pending review | لا توجد إعلانات قيد المراجعة |
| `admin.queue.submittedAt.justNow` | just now | الآن |
| `admin.queue.submittedAt.minutes` | {n} min ago | منذ {n} دقيقة |
| `admin.queue.submittedAt.hours` | {n}h ago | منذ {n} ساعة |
| `admin.queue.submittedAt.days` | {n}d ago | منذ {n} يوم |
| `admin.queue.publisherPrefix` | by | بواسطة |
| `admin.preview.title` | Listing preview | معاينة الإعلان |
| `admin.preview.cta.approve` | Approve | موافقة |
| `admin.preview.cta.reject` | Reject | رفض |
| `admin.approveDialog.title` | Approve this listing? | الموافقة على هذا الإعلان؟ |
| `admin.approveDialog.body` | It will become publicly visible. | سيصبح مرئيًا للجمهور. |
| `admin.approveDialog.confirm` | Approve | موافقة |
| `admin.approveDialog.cancel` | Cancel | إلغاء |
| `admin.rejectDialog.title` | Reject this listing — please tell the publisher why | رفض هذا الإعلان — يُرجى توضيح السبب للناشر |
| `admin.rejectDialog.detailLabel.optional` | Additional details (optional) | تفاصيل إضافية (اختياري) |
| `admin.rejectDialog.detailLabel.required` | Additional details (required) | تفاصيل إضافية (مطلوب) |
| `admin.rejectDialog.detailHint.other` | Please describe the issue so the publisher can fix it | يُرجى وصف المشكلة ليتمكن الناشر من إصلاحها |
| `admin.rejectDialog.counter` | {n}/500 | {n}/500 |
| `admin.rejectDialog.confirm` | Confirm | تأكيد |
| `admin.rejectDialog.cancel` | Cancel | إلغاء |
| `reject_preset_missing_or_low_quality_photos` | Photos missing or low quality | الصور مفقودة أو منخفضة الجودة |
| `reject_preset_incorrect_location` | Location is incorrect or imprecise | الموقع غير صحيح أو غير دقيق |
| `reject_preset_unrealistic_price` | Price appears unrealistic | السعر يبدو غير واقعي |
| `reject_preset_incomplete_description` | Description is incomplete or unclear | الوصف غير مكتمل أو غير واضح |
| `reject_preset_duplicate_listing` | Duplicate of an existing listing | تكرار لإعلان قائم |
| `reject_preset_other` | Other — please provide details | أخرى — يُرجى تقديم التفاصيل |
| `publisher.rejection.attribution` | Reviewed by admin team | تمت المراجعة من قِبَل فريق الإدارة |
| `publisher.rejection.resubmit` | Resubmit | إعادة الإرسال |
| `publisher.rejection.viewHistory` | View moderation history | عرض سجل المراجعة |
| `publisher.history.title` | Moderation history | سجل المراجعة |
| `publisher.history.status.draft` | Draft | مسودة |
| `publisher.history.status.pending_review` | Pending review | قيد المراجعة |
| `publisher.history.status.approved` | Approved | معتمد |
| `publisher.history.status.rejected` | Rejected | مرفوض |
| `publisher.history.status.paused` | Paused | متوقف |
| `publisher.history.status.sold` | Sold | تم البيع |
| `publisher.history.status.rented` | Rented | تم التأجير |
| `publisher.history.status.expired` | Expired | منتهي الصلاحية |
| `publisher.history.status.deleted` | Deleted | محذوف |
| `publisher.history.adminTeam` | Admin team | فريق الإدارة |
| `admin.error.permission_denied` | Insufficient permissions | الصلاحيات غير كافية |
| `admin.error.invalid_status_transition` | Listing is not in pending review | الإعلان ليس قيد المراجعة |
| `admin.error.already_acted_on` | Already acted on by another admin moments ago | تم اتخاذ إجراء بشأنه من قبل مشرف آخر قبل لحظات |
| `admin.error.invalid_reason_preset` | Please select a valid rejection reason | يُرجى اختيار سبب رفض صالح |
| `admin.error.reason_detail_too_long` | Details must be 500 characters or fewer | يجب أن تكون التفاصيل 500 حرفًا أو أقل |
| `admin.toast.approveSuccess` | Listing approved | تمت الموافقة على الإعلان |
| `admin.toast.rejectSuccess` | Listing rejected | تم رفض الإعلان |

**Total**: 32 new keys (some entries combine the {placeholder} variants — the live ARB has more entries due to ICU plural forms).

## 5. Per-FR / per-SC verification map

| Spec item | Verification target | Source artifact |
|---|---|---|
| FR-001 | Edge Function file at `supabase/functions/approve_listing/index.ts` | `supabase/functions/approve_listing/index.ts` |
| FR-002 | Edge Function file at `supabase/functions/reject_listing/index.ts` | `supabase/functions/reject_listing/index.ts` |
| FR-003 | JSON-encoded `listing_status_history.reason` shape verified | quickstart Step 6 SQL query |
| FR-004 | (no-op — R-45 confirms Phase 6 seed already includes `listings.reject`) | research.md R-45 |
| FR-005 | (no-op — Phase 6 already mapped the role-permission for moderator/admin/super_admin) | research.md R-45 |
| FR-006 | Phase 10 public-read RLS verified against approved rows | quickstart Step 8 |
| FR-007 | Phase 11 storage RLS honors parent-status flip | quickstart Step 9 |
| FR-008 | `PermissionChecker.any` gate on routes | code review |
| FR-009 | Queue page renders 20-per-page oldest-first | quickstart Step 4 |
| FR-010 | Queue card composition | code review + visual check |
| FR-011 | Shared display widgets path | `lib/shared/presentation/widgets/listing_display/` directory listing |
| FR-012 | Sticky CTA bar | visual check on Pixel 8 Pro emulator |
| FR-013 | Reject dialog Q5=A gate | quickstart Step 10 |
| FR-014 | Reason persistence | quickstart Step 6 |
| FR-015 | Banner renders on rejected card | quickstart Step 11 |
| FR-016 | Resubmit deep-link opens form pre-populated | quickstart Step 12 |
| FR-017 | Moderation history page | quickstart Step 13 |
| FR-018 | ARB keys present in both ARB files | grep against `lib/l10n/app_*.arb` |
| FR-019 | No notification subsystem | grep against `supabase/migrations/` + `lib/features/admin/listing_review/` |
| FR-020 | Design tokens consumed | grep for inline hex / EdgeInsets.only |
| FR-021 | Audit emission | quickstart Step 7 |
| FR-022 | No Supabase imports in admin presentation | grep |
| FR-023 | Route guard redirects unpermitted | quickstart Step 14 |
| FR-024 | Three functions amended | SC-030 + SC-031 queries |
| SC-001 | 2-min admin journey | manual stopwatch session |
| SC-002 | Anonymous SELECT only `approved` | quickstart Step 8 |
| SC-003 | Approve writes correct rows | quickstart Step 7 |
| SC-004 | Reject writes correct rows | quickstart Step 7 |
| SC-005 | `log_audit()` byte-identical except COALESCE | `git diff` + body inspection |
| SC-006 | Non-admin rejected | quickstart Step 15 |
| SC-007 | Concurrent race produces `already_acted_on` | quickstart Step 16 (R-54) |
| SC-008 | Media inaccessible on status revert | quickstart Step 17 |
| SC-009 | Media accessible on approve | quickstart Step 9 |
| SC-010 | Queue first-page = 20 oldest-first | quickstart Step 4 |
| SC-011 | Preview full-fidelity | quickstart Step 5 |
| SC-012 | Reject dialog renders 6 presets | quickstart Step 10 |
| SC-013 | Banner + Resubmit + history link | quickstart Step 11 |
| SC-014 | History page chronological | quickstart Step 13 |
| SC-015 | Constitution IX-clean | grep |
| SC-016 | Constitution V — no hardcoded strings | grep |
| SC-017 | Constitution VI — design tokens | grep |
| SC-018 | Mutator re-checks permission | tasks.md T097a code-review checkpoint (added per analysis finding C1) |
| SC-019 | Zero new permission keys | confirmed via R-45 |
| SC-020 | Reject-resubmit-reject chain | quickstart Step 18 |
| SC-021 | Approve-revert-approve chain | quickstart Step 19 |
| SC-022 | Two Edge Functions exist | `ls supabase/functions/` |
| SC-023 | `expires_at` NULL on every approval | quickstart Step 7 SQL |
| SC-024 | Preset enum matches | code review |
| SC-025 | No notification subsystem | grep |
| SC-026 | Route gated | quickstart Step 14 |
| SC-027 | JSON-encoded reason shape | quickstart Step 6 |
| SC-028 | "Other" detail required | quickstart Step 10 (UX) + SQL query |
| SC-029 | Edge Function p95 ≤ 2s | Supabase logs `duration_ms` |
| SC-030 | Correct admin UID in changed_by + actor_user_id | quickstart Step 7 |
| SC-031 | Phase 10/4 files unedited | `git diff` |
| SC-032 | 5 shared widget files exist | `ls lib/shared/presentation/widgets/listing_display/` |
