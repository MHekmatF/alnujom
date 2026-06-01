# Contract: Ads Tables (`ads`, `ad_placements`, `ad_impressions`)

**Phase 21** · migrations `20260601120006`/`…007`/`…008` · see `data-model.md` for full DDL.

## `public.ads`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | `gen_random_uuid()` |
| title | TEXT NOT NULL | internal label, 1–200 chars |
| image_path | TEXT NOT NULL | `ads` bucket path |
| caption_ar / caption_en | TEXT NULL | both-or-neither CHECK (R-172) |
| link_kind | TEXT NOT NULL | CHECK ∈ (external,listing,search,category,agency) |
| link_value | TEXT NOT NULL | URL or id/key/token |
| start_at / end_at | TIMESTAMPTZ NULL | window CHECK `start<end` |
| is_active | BOOLEAN NOT NULL DEFAULT true | |
| archived_at | TIMESTAMPTZ NULL | soft-delete marker (R-170) |
| created_by | UUID NULL | FK `auth.users` ON DELETE SET NULL |
| created_at / updated_at | TIMESTAMPTZ | `set_updated_at` trigger |

## `public.ad_placements`
PK `(ad_id, placement_key)` · `ad_id` FK `ads(id) ON DELETE CASCADE` · `placement_key` CHECK (5 keys) · `priority` INT DEFAULT 0.

## `public.ad_impressions` (clicks only)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| ad_id | UUID NOT NULL | FK `ads(id) ON DELETE CASCADE` |
| placement_key | TEXT NOT NULL | CHECK (5 keys) |
| user_id | UUID NULL | FK `auth.users` ON DELETE SET NULL (anon = null) |
| kind | TEXT NOT NULL DEFAULT 'click' | **CHECK ∈ ('click')** — clicks only (R-168) |
| metadata | JSONB | `{ip, user_agent}` |
| occurred_at | TIMESTAMPTZ NOT NULL | |

## RLS posture (Principle III · §6.4)
| Table | Read | Write |
|-------|------|-------|
| `ads` | admin `ads.manage` (direct); public via `v_ads_serving` | **REVOKED** — RPC-only |
| `ad_placements` | admin `ads.manage`; public via view | **REVOKED** — RPC-only |
| `ad_impressions` | admin `ads.manage` only | **REVOKED** — `record_ad_event` only |

No anon SELECT policy on any base table → anonymous direct reads denied; anon reaches ads only through `v_ads_serving`.

## Invariants
- An ad with no `ad_placements` row is never served (appears in no placement).
- Soft-delete only: `archived_at` is set; rows are never hard-deleted by the product, so `ad_impressions` (CASCADE) are retained for the ad's lifetime (FR-006).
- `kind` is locked to `'click'`; widening to `'impression'` is a future migration.
