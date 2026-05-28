# Contract — `enforce_inquiry_transition` BEFORE UPDATE trigger

**Owner**: Sub-Phase B (`supabase/migrations/20260527120005_create_enforce_inquiry_transition_trigger.sql`).

**Consumers**: every UPDATE on `public.inquiries.status` regardless of caller.

## Signature

- Function: `public.enforce_inquiry_transition() RETURNS trigger`
- Language: PL/pgSQL
- Security: SECURITY DEFINER
- search_path: `pg_catalog, public`
- Trigger: `trg_inquiries_enforce_transition BEFORE UPDATE OF status ON public.inquiries FOR EACH ROW EXECUTE FUNCTION public.enforce_inquiry_transition()`

## Allowed transitions (the allowlist)

Per FR-021a + Q2=B + Q3=B:

- `new → seen`
- `seen → responded`
- `seen → closed`
- `responded → closed`
- `responded → seen`
- `closed → seen`
- `closed → responded`
- `* → spam` (for any current status except `spam` itself — supports future admin moderation; Phase 16 ships no publisher write path)

A no-op (OLD.status = NEW.status) is permitted (returns NEW unchanged).

## Forbidden transitions

Everything else, notably:

- `closed → new` (Q2=B explicitly forbids this; the `new` "never opened" semantic is preserved)
- `responded → new`, `seen → new`, `* → new` from non-fresh state
- `responded → seen` (forward-only on the way out per Q2=B; only `closed → seen` reopens)
- `spam → *` (spam is a terminal-ish side branch; no path out in Phase 16)

## Failure mode

Invalid transitions raise:

```sql
RAISE EXCEPTION 'invalid_inquiry_transition: <OLD> -> <NEW>' USING ERRCODE = '23514';
```

The Flutter client surfaces this as a `Failure.transitionInvalid` and renders a localized error.

## Pre-conditions

- `public.inquiries` table exists (Sub-Phase B).

## Post-conditions

- An UPDATE attempting any transition outside the allowlist is rejected; the row remains unchanged.
- An UPDATE within the allowlist completes; the `updated_at` column is refreshed by the `set_updated_at` trigger.

## Stability surface

**Frozen**: the allowed-transition pairs (changing them is a semantic regression for the publisher workflow).

**Allowed**: adding more allowed pairs in a future phase (e.g., a `spam → seen` un-flag path for Phase 18 moderation review). MUST NOT remove existing allowed pairs.
