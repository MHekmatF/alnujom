# Data Model: Listing Creation & Submit-for-Review

**Owner**: Phase 10 (`specs/010-listing-creation/`).
**Created**: 2026-05-18
**Status**: Locked. All shapes below are normative inputs to the implementation; deviations require a spec/research/data-model PR update.

## Tables

### `public.listings` (NEW — migration `20260519120002_create_listings.sql`)

```sql
CREATE TABLE IF NOT EXISTS public.listings (
  id                       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  publisher_user_id        UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  agency_id                UUID         NULL,                                  -- R-17: no FK in Phase 10; Phase 19 adds it
  purpose                  TEXT         NOT NULL CHECK (purpose IN ('sale','rent','daily_rent','investment')),
  property_type            TEXT         NOT NULL CHECK (property_type IN ('apartment','villa','land','shop','office','farm','warehouse','other')),
  status                   TEXT         NOT NULL DEFAULT 'draft'
                             CHECK (status IN ('draft','pending_review','approved','rejected','paused','sold','rented','expired','deleted')),
  title                    TEXT         NOT NULL CHECK (length(trim(title)) > 0),
  governorate_id           UUID         REFERENCES public.governorates(id) ON DELETE RESTRICT,
  city_id                  UUID         REFERENCES public.cities(id)        ON DELETE RESTRICT,
  area_id                  UUID         REFERENCES public.areas(id)         ON DELETE RESTRICT,
  address_text             TEXT,
  latitude                 NUMERIC(9,6),
  longitude                NUMERIC(9,6),
  location_visibility      TEXT         NOT NULL DEFAULT 'approximate'
                             CHECK (location_visibility IN ('hidden','approximate','exact','admin_only')),
  phone                    TEXT,
  whatsapp                 TEXT,
  contact_name_visibility  TEXT         NOT NULL DEFAULT 'public'
                             CHECK (contact_name_visibility IN ('public','admin_only')),
  area_size                NUMERIC(10,2) CHECK (area_size IS NULL OR area_size > 0),
  rooms                    SMALLINT      CHECK (rooms IS NULL OR rooms >= 0),
  bathrooms                SMALLINT      CHECK (bathrooms IS NULL OR bathrooms >= 0),
  floor                    SMALLINT,
  created_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
  published_at             TIMESTAMPTZ,
  expires_at               TIMESTAMPTZ
);

ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_listings_set_updated_at
  BEFORE UPDATE ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX idx_listings_publisher_status ON public.listings (publisher_user_id, status);
CREATE INDEX idx_listings_status_created   ON public.listings (status, created_at DESC) WHERE status = 'approved';
CREATE INDEX idx_listings_governorate      ON public.listings (governorate_id) WHERE status = 'approved';
```

**Verification (post-migration)**:

```sql
SELECT relname, relrowsecurity FROM pg_class WHERE relname='listings' AND relnamespace=(SELECT oid FROM pg_namespace WHERE nspname='public');
-- Expected: relname=listings, relrowsecurity=t

SELECT column_name FROM information_schema.columns
WHERE table_schema='public' AND table_name='listings' ORDER BY ordinal_position;
-- Expected: 25 columns matching the CREATE TABLE body
```

### `public.listing_details` (NEW — migration `20260519120003_create_listing_details.sql`)

```sql
CREATE TABLE IF NOT EXISTS public.listing_details (
  listing_id    UUID         PRIMARY KEY REFERENCES public.listings(id) ON DELETE CASCADE,
  description   TEXT,
  amenities     JSONB        NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(amenities) = 'array'),
  year_built    SMALLINT     CHECK (year_built IS NULL OR (year_built BETWEEN 1850 AND extract(year from now())::int + 2)),
  furnished     BOOLEAN,
  parking       BOOLEAN,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE public.listing_details ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_listing_details_set_updated_at
  BEFORE UPDATE ON public.listing_details
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

### `public.listing_prices` (NEW — migration `20260519120004_create_listing_prices.sql`)

```sql
CREATE TABLE IF NOT EXISTS public.listing_prices (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id    UUID          NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  currency_code TEXT          NOT NULL REFERENCES public.currencies(code) ON DELETE RESTRICT,
  amount        NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  is_primary    BOOLEAN       NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  UNIQUE (listing_id, currency_code)              -- Phase 9 forward-stated (Q4)
);

CREATE UNIQUE INDEX listing_prices_one_primary_idx
  ON public.listing_prices (listing_id)
  WHERE is_primary = true;                        -- R-12: exactly one primary per listing

ALTER TABLE public.listing_prices ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_listing_prices_listing_id ON public.listing_prices (listing_id);
```

### `public.listing_visibility` (NEW — migration `20260519120005_create_listing_visibility.sql`)

```sql
CREATE TABLE IF NOT EXISTS public.listing_visibility (
  listing_id           UUID         PRIMARY KEY REFERENCES public.listings(id) ON DELETE CASCADE,
  location_visibility  TEXT         NOT NULL CHECK (location_visibility IN ('hidden','approximate','exact','admin_only')),
  contact_visibility   TEXT         NOT NULL DEFAULT 'public' CHECK (contact_visibility IN ('public','admin_only')),
  hide_until           TIMESTAMPTZ,
  last_updated_by      UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE public.listing_visibility ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_listing_visibility_set_updated_at
  BEFORE UPDATE ON public.listing_visibility
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

### `public.listing_status_history` (NEW — migration `20260519120006_create_listing_status_history.sql`)

```sql
CREATE TABLE IF NOT EXISTS public.listing_status_history (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id      UUID         NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  previous_status TEXT,
  new_status      TEXT         NOT NULL,
  changed_by      UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  reason          TEXT
);

ALTER TABLE public.listing_status_history ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_listing_status_history_listing ON public.listing_status_history (listing_id, changed_at DESC);
```

## Altered Phase 8 table

### `public.areas` (ALTER — migration `20260519120001_alter_areas_add_centroids.sql`)

Per R-07, Phase 10 adds centroid columns to Phase 8's `public.areas` table and seeds them from manually-researched OpenStreetMap centroids.

```sql
ALTER TABLE public.areas
  ADD COLUMN IF NOT EXISTS centroid_lat NUMERIC(9, 6),
  ADD COLUMN IF NOT EXISTS centroid_lng NUMERIC(9, 6);

-- Seed centroids for every existing area row. The migration body inlines the VALUES.
-- Example (truncated — full inventory in the actual migration file covers ~50–100 areas):
UPDATE public.areas SET centroid_lat = 33.5102, centroid_lng = 36.2913 WHERE name_en = 'Al-Maliki';   -- Damascus
UPDATE public.areas SET centroid_lat = 33.5093, centroid_lng = 36.2825 WHERE name_en = 'Al-Mazraa';   -- Damascus
UPDATE public.areas SET centroid_lat = 36.2024, centroid_lng = 37.1602 WHERE name_en = 'Al-Aziziyeh'; -- Aleppo
-- ... 50–100 total rows ...

-- Verify every row has centroids before enforcing NOT NULL:
DO $$
DECLARE missing_count INT;
BEGIN
  SELECT COUNT(*) INTO missing_count FROM public.areas WHERE centroid_lat IS NULL OR centroid_lng IS NULL;
  IF missing_count > 0 THEN
    RAISE EXCEPTION 'Cannot enforce NOT NULL: % areas missing centroid', missing_count;
  END IF;
END $$;

ALTER TABLE public.areas
  ALTER COLUMN centroid_lat SET NOT NULL,
  ALTER COLUMN centroid_lng SET NOT NULL,
  ADD CONSTRAINT areas_centroid_syria_bounds
    CHECK (centroid_lat BETWEEN 32 AND 37 AND centroid_lng BETWEEN 35 AND 43);
```

**Future-area requirement**: Once this migration runs, all new INSERTs into `public.areas` (e.g., Phase 8 admin UI add-area flow) MUST provide centroid_lat + centroid_lng. The Phase 8 admin form is NOT modified by Phase 10; that extension is deferred to either a Phase 8 follow-up patch or a future spec.

## Triggers

### `listing_status_transition_trigger` (R-09 operational record)

Migration 6 creates this trigger; it fires on every INSERT and every status-changing UPDATE of `public.listings` and appends one row to `public.listing_status_history`.

```sql
CREATE OR REPLACE FUNCTION public.listing_status_transition_trigger_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason)
    VALUES (NEW.id, NULL, NEW.status, auth.uid(), NULL);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason)
    VALUES (NEW.id, OLD.status, NEW.status, auth.uid(), NULL);
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER listing_status_transition_trigger
  AFTER INSERT OR UPDATE OF status ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.listing_status_transition_trigger_fn();
```

**Note**: The `reason` column on history rows is NULL by default. Phase 12's `approve_listing` / `reject_listing` RPCs will set `reason` by directly INSERTing additional rows or by passing the reason through a side-channel — exact mechanism is Phase 12's design choice. Phase 10's `submit_listing` RPC does NOT populate `reason` (submission has no reason text).

### `listing_visibility_sync_trigger` (R-11)

```sql
CREATE OR REPLACE FUNCTION public.listing_visibility_sync_trigger_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.listing_visibility (listing_id, location_visibility, contact_visibility, last_updated_by)
  VALUES (NEW.id, NEW.location_visibility, NEW.contact_name_visibility, auth.uid())
  ON CONFLICT (listing_id) DO UPDATE
    SET location_visibility = EXCLUDED.location_visibility,
        contact_visibility  = EXCLUDED.contact_visibility,
        last_updated_by     = EXCLUDED.last_updated_by,
        updated_at          = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER listing_visibility_sync_trigger
  AFTER INSERT OR UPDATE OF location_visibility, contact_name_visibility ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.listing_visibility_sync_trigger_fn();
```

### Audit trigger group on `public.listings` (R-05 / R-09)

Uses Phase 4's `log_audit()` unchanged. A wrapper function computes the status-delta verb and emits an additional audit row when status changed.

```sql
CREATE OR REPLACE FUNCTION public.listings_audit_trigger_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  status_verb TEXT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.log_audit('listing.created', 'listings', NEW.id::text, NULL, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM public.log_audit('listing.updated', 'listings', NEW.id::text, to_jsonb(OLD), to_jsonb(NEW));
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      status_verb := CASE NEW.status
        WHEN 'pending_review' THEN 'listing.submitted'
        WHEN 'approved'       THEN 'listing.approved'
        WHEN 'rejected'       THEN 'listing.rejected'
        WHEN 'paused'         THEN 'listing.paused'
        WHEN 'expired'        THEN 'listing.expired'
        WHEN 'sold'           THEN 'listing.sold'
        WHEN 'rented'         THEN 'listing.rented'
        WHEN 'deleted'        THEN 'listing.deleted'
        ELSE NULL
      END;
      IF status_verb IS NOT NULL THEN
        PERFORM public.log_audit(status_verb, 'listings', NEW.id::text, to_jsonb(OLD), to_jsonb(NEW));
      END IF;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM public.log_audit('listing.deleted', 'listings', OLD.id::text, to_jsonb(OLD), NULL);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER listings_audit_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.listings_audit_trigger_fn();
```

## RLS Policies

### `public.listings`

```sql
-- Public + authenticated SELECT only on approved + publish-window-open listings:
CREATE POLICY listings_select_public ON public.listings
  FOR SELECT TO anon, authenticated
  USING (
    status = 'approved'
    AND (published_at IS NULL OR published_at <= now())
    AND (expires_at  IS NULL OR expires_at  >  now())
  );

-- Owner SELECT on own listings (any status):
CREATE POLICY listings_select_owner ON public.listings
  FOR SELECT TO authenticated
  USING (auth.uid() = publisher_user_id);

-- Admin SELECT via listings.view_all:
CREATE POLICY listings_select_admin ON public.listings
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('listings.view_all'));

-- Owner INSERT: requires the approved-pair gate (R-19).
CREATE POLICY listings_insert_owner ON public.listings
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = publisher_user_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.publisher_status = 'approved'
        AND p.account_status   = 'approved'
    )
  );

-- Owner UPDATE: only on editable statuses (draft, rejected); same approved-pair gate.
CREATE POLICY listings_update_owner ON public.listings
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = publisher_user_id
    AND status IN ('draft', 'rejected')
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.publisher_status = 'approved'
        AND p.account_status   = 'approved'
    )
  )
  WITH CHECK (
    auth.uid() = publisher_user_id
    AND status IN ('draft', 'pending_review')   -- owner UPDATE may flip draft→pending_review via submit_listing; cannot flip to anything else
  );

-- Admin UPDATE: any listing, any status (Phase 12 will use this for approve/reject).
CREATE POLICY listings_update_admin ON public.listings
  FOR UPDATE TO authenticated
  USING (public.current_user_has_permission('listings.edit_any'));

-- Admin DELETE (super-admin only via listings.delete_any).
CREATE POLICY listings_delete_admin ON public.listings
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('listings.delete_any'));
```

### Child tables (`listing_details`, `listing_prices`, `listing_visibility`)

All three follow the same pattern: SELECT/INSERT/UPDATE/DELETE derive ownership through the parent `listings` row. Example for `listing_prices`:

```sql
CREATE POLICY listing_prices_select_inherited ON public.listing_prices
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l WHERE l.id = listing_prices.listing_id
    AND (
      (l.status = 'approved'
        AND (l.published_at IS NULL OR l.published_at <= now())
        AND (l.expires_at  IS NULL OR l.expires_at  >  now()))
      OR (auth.uid() = l.publisher_user_id)
      OR public.current_user_has_permission('listings.view_all')
    )
  ));

CREATE POLICY listing_prices_write_owner ON public.listing_prices
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_prices.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_prices.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
  ));

CREATE POLICY listing_prices_admin ON public.listing_prices
  FOR ALL TO authenticated
  USING (public.current_user_has_permission('listings.edit_any'))
  WITH CHECK (public.current_user_has_permission('listings.edit_any'));
```

`listing_details` and `listing_visibility` follow the same shape.

### `public.listing_status_history` (append-only)

```sql
-- INSERT only from within a trigger context (R-09):
CREATE POLICY listing_status_history_insert_trigger_only ON public.listing_status_history
  FOR INSERT
  WITH CHECK (pg_trigger_depth() > 0);

-- SELECT: owner of the parent listing + admin via listings.view_all.
CREATE POLICY listing_status_history_select_owner ON public.listing_status_history
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.listings l WHERE l.id = listing_status_history.listing_id AND l.publisher_user_id = auth.uid())
    OR public.current_user_has_permission('listings.view_all')
  );

-- NO UPDATE policy. NO DELETE policy.  (FR-007)
```

## View: `public.v_publisher_listings` (NEW — migration `20260519120008_create_v_publisher_listings.sql`)

Phase 10's `MyListingsPage` needs to render, per listing, the parent row + the most-recent `listing_status_history` entry (for the rejection-reason rendering on Rejected cards) + the `is_primary=true` `listing_prices` row (for the formatted primary-price subline). Postgrest does not natively express "most-recent per group" joins, so Phase 10 ships a small SQL view that does the join server-side and is then queried as a single table by the Flutter datasource.

```sql
CREATE OR REPLACE VIEW public.v_publisher_listings AS
SELECT
  l.id                       AS listing_id,
  l.publisher_user_id,
  l.agency_id,
  l.purpose,
  l.property_type,
  l.status,
  l.title,
  l.governorate_id,
  l.city_id,
  l.area_id,
  l.address_text,
  l.latitude,
  l.longitude,
  l.location_visibility,
  l.phone,
  l.whatsapp,
  l.contact_name_visibility,
  l.area_size,
  l.rooms,
  l.bathrooms,
  l.floor,
  l.created_at,
  l.updated_at,
  l.published_at,
  l.expires_at,
  -- Latest status-history row for this listing (the one with the largest changed_at)
  h.id                       AS latest_history_id,
  h.previous_status          AS latest_history_previous_status,
  h.new_status               AS latest_history_new_status,
  h.changed_by               AS latest_history_changed_by,
  h.changed_at               AS latest_history_changed_at,
  h.reason                   AS latest_history_reason,
  -- Primary price row (is_primary=true; exactly one per listing per the partial unique index)
  p.id                       AS primary_price_id,
  p.currency_code            AS primary_price_currency_code,
  p.amount                   AS primary_price_amount
FROM public.listings l
LEFT JOIN LATERAL (
  SELECT * FROM public.listing_status_history
  WHERE listing_id = l.id
  ORDER BY changed_at DESC
  LIMIT 1
) h ON true
LEFT JOIN public.listing_prices p
  ON p.listing_id = l.id AND p.is_primary = true
WHERE l.status <> 'deleted';

-- The view respects underlying RLS: a publisher querying it sees only their own rows
-- (per the listings_select_owner policy + the parent-derived child policies); admins
-- with listings.view_all see everyone's. No additional RLS is attached to the view.

GRANT SELECT ON public.v_publisher_listings TO authenticated;
```

The view's underlying RLS is inherited from the joined tables — the view is a query helper, not a security boundary. Postgrest exposes the view as a read-only relation via `GET /rest/v1/v_publisher_listings`.

## RPC: `public.submit_listing(p_listing_id UUID) RETURNS JSONB`

```sql
CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id UUID)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_listing       public.listings;
  v_profile_ok    BOOLEAN;
  v_price_count   INT;
  v_missing       TEXT[] := ARRAY[]::TEXT[];
  v_residential   BOOLEAN;
BEGIN
  -- (a) Load
  SELECT * INTO v_listing FROM public.listings WHERE id = p_listing_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'listing not found';
  END IF;

  -- (b) Ownership
  IF v_listing.publisher_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'not the owner';
  END IF;

  -- (c) Approved-pair
  SELECT (publisher_status = 'approved' AND account_status = 'approved') INTO v_profile_ok
    FROM public.profiles WHERE user_id = auth.uid();
  IF NOT COALESCE(v_profile_ok, false) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'publisher not approved';
  END IF;

  -- (d) Editable status
  IF v_listing.status NOT IN ('draft', 'rejected') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'listing not in editable status';
  END IF;

  -- (e) Q1 Full required-field validation
  IF length(trim(coalesce(v_listing.title, ''))) = 0          THEN v_missing := v_missing || 'listings.title';            END IF;
  IF v_listing.purpose IS NULL                                 THEN v_missing := v_missing || 'listings.purpose';          END IF;
  IF v_listing.property_type IS NULL                           THEN v_missing := v_missing || 'listings.property_type';    END IF;
  IF v_listing.governorate_id IS NULL                          THEN v_missing := v_missing || 'listings.governorate_id';   END IF;
  IF v_listing.city_id IS NULL                                 THEN v_missing := v_missing || 'listings.city_id';          END IF;
  IF v_listing.area_id IS NULL                                 THEN v_missing := v_missing || 'listings.area_id';          END IF;
  IF length(trim(coalesce(v_listing.address_text, ''))) = 0    THEN v_missing := v_missing || 'listings.address_text';     END IF;
  IF v_listing.area_size IS NULL OR v_listing.area_size <= 0   THEN v_missing := v_missing || 'listings.area_size';        END IF;
  IF length(trim(coalesce(v_listing.phone, '')))   = 0
     AND length(trim(coalesce(v_listing.whatsapp,'')))= 0      THEN v_missing := v_missing || 'listings.phone_or_whatsapp';END IF;
  v_residential := v_listing.property_type IN ('apartment', 'villa');
  IF v_residential THEN
    IF v_listing.rooms     IS NULL OR v_listing.rooms     < 0  THEN v_missing := v_missing || 'listings.rooms';            END IF;
    IF v_listing.bathrooms IS NULL OR v_listing.bathrooms < 0  THEN v_missing := v_missing || 'listings.bathrooms';        END IF;
  END IF;
  SELECT count(*) INTO v_price_count
    FROM public.listing_prices WHERE listing_id = p_listing_id AND is_primary = true AND amount > 0;
  IF v_price_count <> 1 THEN
    v_missing := v_missing || 'listing_prices.primary';
  END IF;

  IF array_length(v_missing, 1) IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'missing required fields',
      DETAIL  = jsonb_build_object('missing_fields', to_jsonb(v_missing))::text;
  END IF;

  -- (f) Flip status (triggers fire automatically)
  UPDATE public.listings SET status = 'pending_review' WHERE id = p_listing_id;

  -- (g) Return success
  RETURN jsonb_build_object(
    'listing_id',  p_listing_id,
    'status',      'pending_review',
    'submitted_at', now()
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_listing(UUID) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.submit_listing(UUID) TO authenticated;
```

## Seed inventory

Phase 10 seeds **zero listing rows**. The IMPLEMENTATION_PLAN's verification list does not call for fixture data. The trigger-before-seed invariant (R-08) is preserved defensively for any future spec that may add sample listings.

Phase 10 **does** seed `public.areas` centroids (~50–100 rows) as part of migration 1; see the altered-table block above.

## Flutter entity shapes

### `lib/features/listing_form/domain/entities/`

```dart
// listing.dart
class Listing extends Equatable {
  final String id;
  final String publisherUserId;
  final String? agencyId;
  final ListingPurpose purpose;           // enum: sale | rent | dailyRent | investment
  final PropertyType propertyType;        // enum: apartment | villa | land | shop | office | farm | warehouse | other
  final ListingStatus status;             // enum: draft | pendingReview | approved | rejected | paused | sold | rented | expired | deleted
  final String title;
  final String? governorateId;
  final String? cityId;
  final String? areaId;
  final String? addressText;
  final double? latitude;
  final double? longitude;
  final LocationVisibility locationVisibility;
  final String? phone;
  final String? whatsapp;
  final ContactNameVisibility contactNameVisibility;
  final double? areaSize;
  final int? rooms;
  final int? bathrooms;
  final int? floor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  // Equatable props ...
}

// listing_details.dart
class ListingDetails extends Equatable {
  final String listingId;
  final String? description;
  final List<String> amenities;
  final int? yearBuilt;
  final bool? furnished;
  final bool? parking;
  // Equatable props ...
}

// listing_price.dart
class ListingPrice extends Equatable {
  final String id;
  final String listingId;
  final String currencyCode;
  final Decimal amount;     // from package:decimal — Phase 9
  final bool isPrimary;
  final DateTime createdAt;
}

// listing_visibility.dart
class ListingVisibility extends Equatable {
  final String listingId;
  final LocationVisibility locationVisibility;
  final ContactNameVisibility contactVisibility;
  final DateTime? hideUntil;
  final String? lastUpdatedBy;
  final DateTime updatedAt;
}

// listing_status_history_entry.dart
class ListingStatusHistoryEntry extends Equatable {
  final String id;
  final String listingId;
  final ListingStatus? previousStatus;
  final ListingStatus newStatus;
  final String? changedBy;
  final DateTime changedAt;
  final String? reason;
}

// submit_listing_result.dart
class SubmitListingResult extends Equatable {
  final String listingId;
  final ListingStatus status;             // expected: pendingReview
  final DateTime submittedAt;
}

// listing_form_state.dart
class ListingFormState extends Equatable {
  final ListingFormStep currentStep;      // enum: basics | location | details | prices | visibility | media | review
  final Listing draftListing;
  final ListingDetails? draftDetails;
  final ListingPrice? draftPrice;         // single per Q3
  final ListingVisibility? draftVisibility;
  final Map<String, String?> stepValidationErrors;
  final bool submitInProgress;
  final SubmitFailure? lastSubmitFailure;
}

// submit_failure.dart
class SubmitFailure extends Equatable {
  final List<String> missingFields;       // dot-notated paths from the RPC's DETAIL payload
  final String? rawSqlState;
  final String? userFacingMessage;
}
```

### `lib/features/publisher_dashboard/domain/entities/`

```dart
// publisher_listing.dart
class PublisherListing extends Equatable {
  final Listing listing;
  final ListingStatusHistoryEntry latestStatusHistoryEntry;
  final ListingPrice? primaryPrice;     // null when no price exists yet (draft pre-prices-step)
  final bool isEditable;                // computed: status in (draft, rejected)
  final bool hasRejectionReason;        // computed: status == rejected AND latestStatusHistoryEntry.reason != null
}
```

### `lib/features/listing_form/domain/usecases/`

| Use case | Signature | Notes |
|---|---|---|
| `LoadOrCreateDraft` | `Future<Listing> call(String publisherUserId)` | If publisher has a draft, load it; else INSERT new with `status='draft'` |
| `SaveFormStep` | `Future<void> call(ListingFormState state, ListingFormStep step)` | UPSERTs parent + child rows for the given step |
| `SubmitListing` | `Future<SubmitListingResult> call(String listingId)` | Calls `submit_listing` RPC |
| `DeleteDraft` | `Future<void> call(String listingId)` | DELETE on the listing row (cascade deletes children) — only for `draft` status |
| `DeriveAreaCentroid` | `Future<({double lat, double lng})> call(String areaId)` | Reads `public.areas.centroid_lat`/`centroid_lng` |
| `ValidateSubmitPayload` | `({bool ok, List<String> missingFields}) call(ListingFormState state)` | Client-side Q1 mirror of the server RPC validation |

### `lib/features/publisher_dashboard/domain/usecases/`

| Use case | Signature | Notes |
|---|---|---|
| `ListMyListings` | `Future<List<PublisherListing>> call({ListingStatus? statusFilter, int offset, int limit})` | Paginated read with optional filter |

### `lib/core/validators/`

| Validator | API | Notes |
|---|---|---|
| `AreaSizeValidator` | `static String? validate(num? value, AppLocalizations l10n)` | Returns null on pass, localized error string on fail. Warning above 5000 |
| `PriceValidator` | `static String? validate(Decimal? value, Currency currency, AppLocalizations l10n)` | Positive, ≤NUMERIC(14,2), decimal-count gated by `currency.displayDecimals` |
| `PhoneValidator` | `static String? validateAndNormalize(String? value, AppLocalizations l10n) ⇒ ({String? error, String? normalized})` | Accepts Syrian local `09xxxxxxxx`, normalizes to `+963...` |

## ARB key inventory

Approximately **48 new keys** in `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb`:

**Form chrome (15 keys)**:
- `listingFormCreateButton`, `listingFormBackButton`, `listingFormContinueButton`, `listingFormSubmitButton`, `listingFormSaveAndExitButton`
- `listingFormStepBasicsTitle`, `listingFormStepLocationTitle`, `listingFormStepDetailsTitle`, `listingFormStepPricesTitle`, `listingFormStepVisibilityTitle`, `listingFormStepMediaTitle`, `listingFormStepReviewTitle`
- `listingFormStepProgress`, `listingFormMediaPlaceholderBanner`
- `listingFormJumpToStepButton`

**Field labels (16 keys)**:
- `fieldLabelTitle`, `fieldLabelPurpose`, `fieldLabelPropertyType`, `fieldLabelGovernorate`, `fieldLabelCity`, `fieldLabelArea`, `fieldLabelAddressText`, `fieldLabelAreaSize`, `fieldLabelRooms`, `fieldLabelBathrooms`, `fieldLabelFloor`, `fieldLabelDescription`, `fieldLabelPhone`, `fieldLabelWhatsapp`, `fieldLabelHideUntil`, `fieldLabelAmenities`

**Amenities catalog labels (10 keys)** — one per `kAmenitiesCatalog` entry (T069 list):
- `amenityElevator`, `amenityBalcony`, `amenitySwimmingPool`, `amenityGarden`, `amenitySecurity`, `amenityGenerator`, `amenitySolarPanels`, `amenityCentralHeating`, `amenityAirConditioning`, `amenityFurnishedKitchen`

**Validator errors (7 keys)**:
- `validatorAreaSizePositive`, `validatorAreaSizeTooLarge`, `validatorAreaSizeSoftWarning`, `validatorPricePositive`, `validatorPriceTooPrecise`, `validatorPhoneInvalid`, `validatorPhoneTooShort`
- `validatorAreaMissingCentroid` — FR-013a defensive block when an admin-added area row lacks centroid_lat/centroid_lng (should never trigger post-seed).

**Status badges (9 keys)**:
- `statusBadgeDraft`, `statusBadgePendingReview`, `statusBadgeApproved`, `statusBadgeRejected`, `statusBadgePaused`, `statusBadgeSold`, `statusBadgeRented`, `statusBadgeExpired`, `statusBadgeDeleted`

**Rejection / resubmit / failures (6 keys)**:
- `rejectionReasonHeader`, `resubmitCtaButton`, `submitFailureTitle`, `submitFailureMissingFieldsHeader`, `submitFailureRetryButton`, `approvedNotEditableMessage`

**Missing-field labels (10 keys)** — one per Q1 required-field path the RPC may emit in `missing_fields[]`:
- `missingFieldListingsTitle`, `missingFieldListingsPurpose`, `missingFieldListingsPropertyType`, `missingFieldListingsGovernorateId`, `missingFieldListingsCityId`, `missingFieldListingsAreaId`, `missingFieldListingsAddressText`, `missingFieldListingsAreaSize`, `missingFieldListingsPhoneOrWhatsapp`, `missingFieldListingsRooms`, `missingFieldListingsBathrooms`, `missingFieldListingPricesPrimary`

**Submit_listing structured errors (3 keys)**:
- `submitErrorPublisherNotApproved`, `submitErrorListingNotEditable`, `submitErrorUnknown`

**Publisher-dashboard tiles + pending-approval screen (5 keys)**:
- `tileCreateListing`, `tileMyListings`, `tileCreateListingComingNext`
- `publisherApprovalPendingTitle`, `publisherApprovalPendingMessage` — for the new screen at route `/publisher/pending-approval`

Bilingual data labels (governorate / city / area names; currency names; currency symbols) come from the respective tables' bilingual columns — NOT from ARB.

## Per-FR verification map

| FR | Verification |
|---|---|
| FR-001 | `SELECT relrowsecurity FROM pg_class WHERE relname IN ('listings','listing_details','listing_prices','listing_visibility','listing_status_history')` returns 5 rows, all `t`. |
| FR-002 | Column inventory matches the CREATE TABLE body above. Verified via `information_schema.columns`. |
| FR-003 | Same for child tables. |
| FR-004 | After a manual create → submit sequence, `listing_status_history` carries 2 rows (NULL→draft, draft→pending_review). |
| FR-004a | After the same sequence, `audit_logs` carries 3 rows (`listing.created`, `listing.updated`, `listing.submitted`). |
| FR-005 | Direct INSERT attempted by a non-approved publisher's JWT returns 0 rows affected (RLS deny). |
| FR-006 | Anonymous SELECT on a `draft` listing's row returns 0 rows; SELECT on an `approved` row within publish window returns 1 row. |
| FR-007 | `UPDATE public.listing_status_history SET ...` and `DELETE FROM public.listing_status_history ...` both return 0 rows from any caller. |
| FR-008 | `SELECT count(*) FROM public.permissions WHERE created_at > '2026-05-18'` returns 0 (no new keys). |
| FR-009 | After admin sets `publisher_status='approved'`, the user's next `PermissionChecker.userIsApprovedPublisher()` call returns true without sign-out. |
| FR-010 | `submit_listing` RPC behaves per the body above. |
| FR-010a | The missing_fields payload matches the Q1 Full set when fields are empty. |
| FR-011 | The "Create listing" tile is hidden for non-approved publishers (UX inspection). |
| FR-012 | Deep-link to `/publisher/listings/create` refused for non-approved publishers (router guard inspection). |
| FR-013 | Seven-step form renders all seven steps in order. |
| FR-013a | Picking an area auto-populates `listings.latitude`/`longitude` from `public.areas.centroid_lat`/`centroid_lng`. |
| FR-014 | Per-step auto-save commits the draft row on every step transition. |
| FR-015 | `MyListingsPage` renders the publisher's listings with status filter chips. |
| FR-016 | Prices step shows exactly ONE currency picker + ONE amount field. |
| FR-017 | No exchange-rate conversion applied at any save / render / submit point. |
| FR-018 | The three validators reject invalid inputs with localized error strings. |
| FR-019 | All chrome strings render via `AppLocalizations`. |
| FR-020 | Design tokens are consumed by every new widget (grep audit). |
| FR-021 | Every mutation emits the correct audit-log row count (SQL verification). |

## Per-SC verification map

| SC | Verification |
|---|---|
| SC-001 | Stopwatch on the reference device during the full create→submit journey: under 4 minutes. |
| SC-002 | Three-layer denial verified per FR-005 / FR-011 / FR-012 verifications above. |
| SC-003 | `listing_status_history` row counts match status transitions (FR-004 verification). |
| SC-004 | Append-only verified per FR-007 verification. |
| SC-005 | Anonymous read deny verified per FR-006 verification. |
| SC-006 | Full chain test in `quickstart.md` step 10. |
| SC-007 | `pg_class.relrowsecurity` query (FR-001 verification). |
| SC-008 | `information_schema.referential_constraints` + `table_constraints` queries on `listing_prices`. |
| SC-009 | `SELECT listing_id, COUNT(*) FROM public.listing_prices WHERE is_primary=true GROUP BY listing_id HAVING COUNT(*)<>1` returns zero rows. |
| SC-010 | RPC error response inspection during a missing-field submit. |
| SC-011 | RPC error response inspection during a non-approved-publisher submit. |
| SC-012 | Manual locale-toggle inspection on the form. |
| SC-013 | Design-token grep audit. |
| SC-014 | Localization lint guard at PR review. |
| SC-015 | Manual filter-chip inspection on `MyListingsPage`. |
| SC-016 | `git diff` against Phase 4 migration showing zero edits to `log_audit` body. |
| SC-017 | `information_schema.referential_constraints WHERE constraint_name LIKE '%agency_id%'` returns 0 rows after Phase 10, ≥1 row after Phase 19. |
| SC-018 | Constitution-IX grep (Phase 10 verification: zero `package:supabase_flutter` imports under domain folders). |
| SC-019 | Full transition walk verification (`quickstart.md` step 11). |
| SC-020 | Cache-refresh test (publisher_status flip mid-session). |
| SC-021 | Grep audit for the LocationPicker reuse. |
| SC-022 | Single-row invariant verification (Phase 10 listings each have exactly one `listing_prices` row). |
| SC-023 | Non-null lat/lng verification for non-draft listings. |
| SC-024 | UI source-code audit (no multi-row entry widget in the prices step). |
