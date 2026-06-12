-- Spec 028 (premium-worth pass) — market insights aggregates for the listing
-- details page.
--
-- Two read-only SECURITY DEFINER aggregate functions:
--   1. market_price_trend  — monthly average asking price per currency for a
--      governorate + property type (optionally narrowed by city / purpose),
--      over public.listings JOIN the primary listing_prices row. Includes
--      terminal statuses (sold / rented / expired) alongside approved so the
--      trend reflects the historical market, not just live inventory. Those
--      terminal rows are NOT publicly visible through RLS — which is exactly
--      why this is SECURITY DEFINER and why it returns AGGREGATES ONLY.
--   2. market_area_stats   — live-inventory price stats per currency over
--      public.v_listings_public (already public data; approved + in-window).
--
-- K-ANONYMITY RATIONALE: market_price_trend reads rows the caller cannot see
-- (sold/rented/expired listings are hidden by RLS). Every monthly bucket is
-- therefore gated with HAVING count(*) >= 2 so no single non-public listing's
-- exact price can be reverse-engineered from a bucket of one. Only grouped
-- averages/counts are ever returned — never row-level data.
--
-- GRANTS: EXECUTE is deliberately granted to anon AND authenticated — listing
-- details is an anonymous-browsing surface and the functions only ever return
-- k-anonymous aggregates. ALL is first revoked from PUBLIC so the default
-- PostgreSQL function grant never applies.
--
-- Schema sources (verified):
--   - 20260519120002_create_listings.sql        (listings: status check set,
--     governorate_id/city_id uuid, property_type/purpose text, published_at)
--   - 20260519120004_create_listing_prices.sql  (listing_prices: amount,
--     currency_code, is_primary, one-primary partial unique index)
--   - 20260525120002_create_v_listings_public.sql (v_listings_public:
--     primary_amount, primary_currency, governorate_id, city_id,
--     property_type, purpose)

-- ─── 1. Monthly price trend (historical, k-anonymous) ────────────────────────

CREATE OR REPLACE FUNCTION public.market_price_trend(
  p_governorate_id uuid,
  p_property_type  text,
  p_city_id        uuid    DEFAULT NULL,
  p_purpose        text    DEFAULT NULL,
  p_months         integer DEFAULT 6
)
RETURNS TABLE(
  month         date,
  currency_code text,
  avg_price     numeric,
  listing_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- All columns are table-qualified (aliases l / lp) so the RETURNS TABLE OUT
  -- parameters (month, currency_code, ...) can never shadow them.
  SELECT
    date_trunc('month', l.published_at)::date AS month,
    lp.currency_code                          AS currency_code,
    round(avg(lp.amount), 2)                  AS avg_price,
    count(*)                                  AS listing_count
  FROM public.listings l
  JOIN public.listing_prices lp
    ON lp.listing_id = l.id
   AND lp.is_primary = true
  WHERE l.governorate_id = p_governorate_id
    AND l.property_type  = p_property_type
    AND (p_city_id IS NULL OR l.city_id = p_city_id)
    AND (p_purpose IS NULL OR l.purpose = p_purpose)
    AND l.published_at IS NOT NULL
    -- Statuses from the listings CHECK constraint (20260519120002): keep the
    -- once-published market (approved + sold + rented + expired); exclude
    -- draft / pending_review / rejected / paused / deleted.
    AND l.status IN ('approved', 'sold', 'rented', 'expired')
    -- Trailing window: the current calendar month plus the (p_months - 1)
    -- preceding months, clamped to a sane 1..24 range.
    AND l.published_at >= date_trunc('month', now())
                          - make_interval(months => least(greatest(p_months, 1), 24) - 1)
  GROUP BY 1, 2
  -- K-anonymity: a monthly bucket of one would expose that single (possibly
  -- RLS-hidden) listing's exact price as the "average". Require >= 2.
  HAVING count(*) >= 2
  ORDER BY 1, 2;
$$;

COMMENT ON FUNCTION public.market_price_trend(uuid, text, uuid, text, integer) IS
  'Spec 028: monthly avg asking price per currency for a governorate + property type. '
  'SECURITY DEFINER over RLS-hidden terminal rows; aggregates only, k-anonymous (HAVING count >= 2).';

REVOKE ALL ON FUNCTION public.market_price_trend(uuid, text, uuid, text, integer) FROM PUBLIC;
-- Deliberate anon grant: anonymous browsing surfaces; aggregates only.
GRANT EXECUTE ON FUNCTION public.market_price_trend(uuid, text, uuid, text, integer)
  TO anon, authenticated;

-- ─── 2. Live-inventory area stats ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.market_area_stats(
  p_governorate_id uuid,
  p_property_type  text DEFAULT NULL,
  p_city_id        uuid DEFAULT NULL,
  p_purpose        text DEFAULT NULL
)
RETURNS TABLE(
  currency_code text,
  listing_count bigint,
  avg_price     numeric,
  min_price     numeric,
  max_price     numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- Live inventory only: v_listings_public already enforces approved +
  -- publish-window, and every row in it (including its price) is public data,
  -- so min/max here reveal nothing that listing browse doesn't.
  SELECT
    v.primary_currency              AS currency_code,
    count(*)                        AS listing_count,
    round(avg(v.primary_amount), 2) AS avg_price,
    min(v.primary_amount)           AS min_price,
    max(v.primary_amount)           AS max_price
  FROM public.v_listings_public v
  WHERE v.governorate_id = p_governorate_id
    AND (p_property_type IS NULL OR v.property_type = p_property_type)
    AND (p_city_id       IS NULL OR v.city_id       = p_city_id)
    AND (p_purpose       IS NULL OR v.purpose       = p_purpose)
    AND v.primary_amount   IS NOT NULL
    AND v.primary_currency IS NOT NULL
  GROUP BY v.primary_currency
  ORDER BY count(*) DESC, v.primary_currency;
$$;

COMMENT ON FUNCTION public.market_area_stats(uuid, text, uuid, text) IS
  'Spec 028: live-inventory price stats per currency over v_listings_public (public data only).';

REVOKE ALL ON FUNCTION public.market_area_stats(uuid, text, uuid, text) FROM PUBLIC;
-- Deliberate anon grant: anonymous browsing surfaces; aggregates only.
GRANT EXECUTE ON FUNCTION public.market_area_stats(uuid, text, uuid, text)
  TO anon, authenticated;
