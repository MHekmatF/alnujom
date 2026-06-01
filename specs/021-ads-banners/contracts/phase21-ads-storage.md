# Contract: `ads` Storage Bucket

**Phase 21** · migration `20260601120010` (R-174). Follows the Phase 19 `agency-assets` public-bucket idiom.

## Bucket
| Field | Value |
|-------|-------|
| id / name | `ads` |
| public | `true` (public read of banner images) |
| file_size_limit | `5242880` (5 MB) |
| allowed_mime_types | `image/jpeg, image/png, image/webp` |

Idempotent: `INSERT … ON CONFLICT (id) DO UPDATE SET public, file_size_limit, allowed_mime_types`.

## Path shape
`{uuid}/{filename}` — the uuid prefix is organizational (client-generated), NOT an FK to `ads.id`. The client uploads the image FIRST, then passes the resulting `image_path` to `create_ad` (avoids a create-then-upload chicken/egg).

## `storage.objects` policies
| Policy | Op | Predicate |
|--------|----|-----------|
| `ads_public_select` | SELECT (anon+auth) | `bucket_id='ads'` |
| `ads_admin_write` | INSERT (auth) | `bucket_id='ads' AND current_user_has_permission('ads.manage') AND name ~ '^[0-9a-f-]{36}/.+$'` |
| `ads_admin_update` | UPDATE (auth) | `bucket_id='ads' AND current_user_has_permission('ads.manage')` |
| `ads_admin_delete` | DELETE (auth) | `bucket_id='ads' AND current_user_has_permission('ads.manage')` |

## Rationale
Banner art is non-sensitive promotional content, so public-read-all is acceptable; **eligibility filtering happens at the data layer** (`v_ads_serving`), so an archived/expired ad's image is simply unreferenced (no listing/serving row points at it) even though the object is technically fetchable by URL. This avoids a costly path→ad eligibility join on every image fetch (FR-021).

## Client upload (PD datasource)
```
final path = '${uuidV4()}/${millis}.jpg';
await supabase.storage.from('ads').uploadBinary(path, bytes,
    fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
final imagePath = path;               // stored on the ad via create_ad/update_ad
// display: supabase.storage.from('ads').getPublicUrl(path) → CachedNetworkImage
```
Image pick/compress reuses Phase 11 discipline (`image_picker` maxWidth + `flutter_image_compress` q≈80–85). On a later `create_ad`/`update_ad` failure the client SHOULD remove the orphan object (defense-in-depth, mirrors `supabase_listing_media_datasource`).
