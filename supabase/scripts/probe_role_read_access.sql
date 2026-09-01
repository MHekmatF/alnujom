-- Reads every table and view in `public` AS anon and AS an authenticated user,
-- and reports anything that errors.
--
-- WHY: two guest-facing outages this project shipped were invisible to every
-- other check. Both came from a security pass revoking something a public read
-- path quietly depended on, and both looked fine in the policy listings:
--
--   * `20260717120007` revoked latitude/longitude on `listings` from anon, but
--     `v_listings_map_public` is a security_invoker view reading those columns —
--     so the guest map failed with 42501. (Fixed: 20260901120001.)
--   * `anon` held no EXECUTE on `current_user_has_permission()`, but the
--     SECURITY DEFINER view `v_agencies` calls it in its predicate, and function
--     EXECUTE is checked against the CALLING role — so the guest agencies
--     directory failed with 42501. (Fixed: 20260902120001.)
--
-- Reading the grants and policies did not reveal either one. Actually reading
-- the relations as the role did, immediately. Run this after ANY migration that
-- touches grants, policies, views or the boolean RLS helpers.
--
-- Safe: read-only, counts rows only, and every probe is wrapped so one failure
-- does not stop the sweep.

BEGIN;

CREATE TEMPORARY TABLE _role_probe(
  role_name TEXT,
  relation  TEXT,
  result    TEXT
) ON COMMIT DROP;

DO $$
DECLARE
  names    TEXT[];
  nm       TEXT;
  n        BIGINT;
  test_uid TEXT;
BEGIN
  -- Materialise the relation list BEFORE switching roles: a lazily-fetched
  -- cursor would be read as the impersonated role and fail on the catalog.
  SELECT array_agg(c.relname ORDER BY c.relname) INTO names
  FROM pg_class c
  JOIN pg_namespace ns ON ns.oid = c.relnamespace
  WHERE ns.nspname = 'public'
    AND c.relkind IN ('r', 'v', 'm')
    AND has_table_privilege('anon', c.oid, 'SELECT');

  FOREACH nm IN ARRAY COALESCE(names, '{}'::TEXT[]) LOOP
    BEGIN
      SET LOCAL ROLE anon;
      EXECUTE format('SELECT count(*) FROM public.%I', nm) INTO n;
      RESET ROLE;
      INSERT INTO _role_probe VALUES ('anon', nm, 'OK (' || n || ' rows)');
    EXCEPTION WHEN OTHERS THEN
      RESET ROLE;
      INSERT INTO _role_probe VALUES ('anon', nm, 'FAIL ' || SQLSTATE || ' ' || SQLERRM);
    END;
  END LOOP;

  SELECT array_agg(c.relname ORDER BY c.relname) INTO names
  FROM pg_class c
  JOIN pg_namespace ns ON ns.oid = c.relnamespace
  WHERE ns.nspname = 'public'
    AND c.relkind IN ('r', 'v', 'm')
    AND has_table_privilege('authenticated', c.oid, 'SELECT');

  SELECT user_id::TEXT INTO test_uid
  FROM public.profiles
  WHERE account_status = 'approved'
  LIMIT 1;

  FOREACH nm IN ARRAY COALESCE(names, '{}'::TEXT[]) LOOP
    BEGIN
      PERFORM set_config(
        'request.jwt.claims',
        json_build_object('sub', test_uid, 'role', 'authenticated')::TEXT,
        true
      );
      SET LOCAL ROLE authenticated;
      EXECUTE format('SELECT count(*) FROM public.%I', nm) INTO n;
      RESET ROLE;
      INSERT INTO _role_probe VALUES ('authenticated', nm, 'OK (' || n || ' rows)');
    EXCEPTION WHEN OTHERS THEN
      RESET ROLE;
      INSERT INTO _role_probe VALUES ('authenticated', nm, 'FAIL ' || SQLSTATE || ' ' || SQLERRM);
    END;
  END LOOP;
END $$;

-- Summary: both numbers in the `failing` column must be 0.
SELECT role_name,
       count(*)                                    AS probed,
       count(*) FILTER (WHERE result LIKE 'FAIL%') AS failing
FROM _role_probe
GROUP BY role_name
ORDER BY role_name;

-- Detail for anything that broke.
SELECT role_name, relation, result
FROM _role_probe
WHERE result LIKE 'FAIL%'
ORDER BY role_name, relation;

COMMIT;
