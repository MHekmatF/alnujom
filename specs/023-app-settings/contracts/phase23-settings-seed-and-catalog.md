# Contract: settings seed + catalog value shapes

**Phase 23 · migration `20260602120016_seed_app_settings.sql`**

The closed v1 catalog. Seed is idempotent (`ON CONFLICT (key) DO NOTHING`). All keys `is_public = true`. **No `supported_currencies` key** (Phase 9 `currencies.is_active` owns supported currencies — R-198).

| key | `value` shape | seed default | domain / validation |
|---|---|---|---|
| `default_language` | string | `"ar"` | one of supported locales `ar` \| `en` |
| `default_currency` | string | `"SYP"` | an **active** `currencies.code` (Phase 9) |
| `default_publisher_name_visibility` | string | `"public"` | `public` \| `admin_only` (Phase 10 enum) |
| `default_location_visibility` | string | `"approximate"` | `hidden` \| `approximate` \| `exact` \| `admin_only` (Phase 10 enum) |
| `maintenance_mode` | object | `{"on": false, "message": {"ar": null, "en": null}}` | `on`: bool; `message.ar`/`message.en`: string\|null |
| `support_contact` | object | `{"phone": null, "whatsapp": null, "email": null}` | each channel: string\|null (phone/whatsapp E.164-ish; email shape) |
| `terms_url` | string\|null | `null` | URL shape when set |
| `privacy_url` | string\|null | `null` | URL shape when set |

## Validation ownership

- **Editor (FA)** validates each control to the domain above **before** calling `set_app_setting` (an invalid value is never sent).
- **DB** stores whatever JSONB the definer RPC receives (the editor is the validation gate); the seed guarantees a sensible starting value for each key.

## Invariants

- `SELECT key FROM app_settings ORDER BY key` returns exactly these 8 keys after seeding — no more, no fewer.
- Re-running the seed migration is a no-op (idempotent).
- `default_currency` always references a currency that exists in Phase 9; the editor's picker is constrained to `ListCurrencies(activeOnly: true)`.
