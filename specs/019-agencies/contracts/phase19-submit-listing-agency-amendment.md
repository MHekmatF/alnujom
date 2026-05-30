# Contract — `submit_listing` agency-membership amendment (R-143 integration check)

**File**: `supabase/migrations/20260531120009_amend_submit_listing_agency_check.sql` (Sub-Phase E). Full guidance in `data-model.md §1.9`. **This is the ONLY existing Phase 10/11 RPC Phase 19 touches.**

## Discipline

- `CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id uuid)` re-basing the **latest** body (`20260522120004_amend_submit_listing_rpc_for_media_minimum.sql`). Sub-Phase E's FIRST task is to read that file and re-base so NO existing validation is dropped (profile approval, ≥1 price, ≥1 image, residential rules, the `pending_review` UPDATE, the JSONB return shape).
- Add ONLY the agency-membership branch, immediately BEFORE the `UPDATE … status='pending_review'`:

```sql
IF v_listing.agency_id IS NOT NULL THEN
  IF NOT EXISTS (
    SELECT 1 FROM public.agency_members m
    JOIN public.agencies a ON a.id = m.agency_id
    WHERE m.agency_id = v_listing.agency_id
      AND m.user_id   = auth.uid()
      AND m.status    = 'active'
      AND a.status IN ('pending','approved')      -- not rejected/suspended (R-149)
  ) THEN
    RAISE EXCEPTION 'not_an_agency_member' USING ERRCODE = '42501';
  END IF;
END IF;
```

## Invariants

- The existing per-user publish RLS (`listings_insert_owner` / `listings_update_owner`, `20260519120002:66-94`) is UNTOUCHED — agency approval is NOT a second publish gate (Q1=A soft gate, R-143).
- A member may publish under a `pending` agency (the badge stays gated on `approved`); a `rejected`/`suspended` agency blocks NEW publishing under it (R-149).
- Grants unchanged (`authenticated`).

## Smoke tests (SC-007)

1. An `active` member of an approved agency submits a listing with that `agency_id` → success (`pending_review`).
2. A publisher who is NOT a member of `agency_id` (or a crafted call) → `not_an_agency_member` (42501).
3. A publisher with no agency and `agency_id=NULL` → success (the branch is skipped).
4. Submitting under a `suspended` agency → `not_an_agency_member`.
