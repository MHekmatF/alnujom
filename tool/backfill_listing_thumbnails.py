"""Give every existing listing photo the card thumbnail it never had.

WHY
---
From 2026-09-04 the app makes a 480-px thumbnail beside every uploaded photo
(`watermark_pipeline.dart`) and every card view reads
`coalesce(thumbnail_path, storage_path)`. Rows uploaded before that have a null
`thumbnail_path`, so their cards still pull the full ~156 KB file. This walks
those rows once and fills the gap.

The coalesce is what makes this safe to run at any pace: a row without a
thumbnail is not broken, it is merely expensive. Nothing here is required for
the app to work.

WHAT IT DOES, PER ROW
---------------------
  1. downloads the full image from `listing-images`
  2. resizes the long edge to 480 px, re-encodes JPEG quality 75
     (the same numbers as the on-device pipeline, so old and new rows match)
  3. uploads it beside the original as `<same path>_thumb.jpg`
  4. sets `listing_media.thumbnail_path`

The source image is already watermarked and already EXIF-stripped by the
pipeline that produced it, so the thumbnail inherits both — there is no way for
this to emit an un-watermarked copy.

Idempotent: rows that already have a `thumbnail_path` are skipped, and an
existing object is overwritten rather than duplicated. Safe to re-run.

WHY IT IS A LOCAL SCRIPT AND NOT A JOB
--------------------------------------
It needs the service-role key, and ADR-0001 keeps that key on the build machine
— never in CI, never in the app. It is also a one-off: new uploads carry their
own thumbnail.

RUN
---
    python tool/backfill_listing_thumbnails.py            # do it
    python tool/backfill_listing_thumbnails.py --dry-run  # report only

Reads SUPABASE_URL from .env.json and the service-role key from
.env.admin.json (both gitignored, both build-machine-only).
"""

from __future__ import annotations

import argparse
import io
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - developer tooling
    sys.exit("needs Pillow: python -m pip install pillow")

ROOT = Path(__file__).resolve().parent.parent
BUCKET = "listing-images"

# Must match watermark_pipeline.dart — old and new thumbnails should be
# indistinguishable, or a feed will visibly mix two qualities.
THUMB_LONG_EDGE = 480
THUMB_QUALITY = 75


def find_admin_env(override: str | None) -> Path:
    """Locate `.env.admin.json`.

    It is gitignored, so it exists only in the developer's main checkout — a
    git worktree does not get a copy. `--git-common-dir` points at the shared
    `.git` whatever tree we are standing in, and its parent is that checkout.
    """
    candidates: list[Path] = []
    if override:
        candidates.append(Path(override))
    candidates.append(ROOT / ".env.admin.json")
    try:
        import subprocess

        common = subprocess.run(
            ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout.strip()
        if common:
            candidates.append(Path(common).parent / ".env.admin.json")
    except Exception:
        pass

    for c in candidates:
        if c.exists():
            return c
    sys.exit(
        ".env.admin.json not found. It holds the service-role key and lives only "
        "on the build machine (ADR-0001). Looked in:\n  "
        + "\n  ".join(str(c) for c in candidates)
        + "\nPass --admin-env <path> to point at it."
    )


def load_config(admin_env: str | None) -> tuple[str, str]:
    env = json.loads((ROOT / ".env.json").read_text(encoding="utf-8"))
    admin = json.loads(find_admin_env(admin_env).read_text(encoding="utf-8"))
    url = (env.get("SUPABASE_URL") or "").rstrip("/")
    key = (
        admin.get("SUPABASE_SERVICE_ROLE_KEY")
        or admin.get("SERVICE_ROLE_KEY")
        or admin.get("supabase_service_role_key")
        or ""
    )
    if not url or not key:
        sys.exit("SUPABASE_URL or the service-role key is missing.")
    return url, key


def request(url: str, key: str, method: str = "GET", data: bytes | None = None,
            extra_headers: dict[str, str] | None = None) -> bytes:
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
    }
    headers.update(extra_headers or {})
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def rows_needing_a_thumbnail(base: str, key: str) -> list[dict]:
    query = urllib.parse.urlencode(
        {
            "select": "id,listing_id,storage_path",
            "kind": "eq.image",
            "thumbnail_path": "is.null",
            "storage_path": "not.is.null",
        }
    )
    raw = request(f"{base}/rest/v1/listing_media?{query}", key)
    return json.loads(raw.decode("utf-8"))


def make_thumbnail(full: bytes) -> bytes:
    with Image.open(io.BytesIO(full)) as im:
        im = im.convert("RGB")
        long_edge = max(im.size)
        if long_edge > THUMB_LONG_EDGE:
            scale = THUMB_LONG_EDGE / long_edge
            im = im.resize(
                (max(1, round(im.width * scale)), max(1, round(im.height * scale))),
                Image.LANCZOS,
            )
        out = io.BytesIO()
        im.save(out, format="JPEG", quality=THUMB_QUALITY, optimize=True)
        return out.getvalue()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true",
                        help="report what would change, write nothing")
    parser.add_argument("--admin-env",
                        help="path to .env.admin.json (default: found automatically)")
    args = parser.parse_args()

    base, key = load_config(args.admin_env)
    rows = rows_needing_a_thumbnail(base, key)
    print(f"{len(rows)} image row(s) without a thumbnail")
    if not rows:
        return

    done = failed = 0
    saved_before = saved_after = 0

    for row in rows:
        path = row["storage_path"]
        thumb_path = f"{path.rsplit('.', 1)[0]}_thumb.jpg"
        try:
            full = request(f"{base}/storage/v1/object/{BUCKET}/{path}", key)
            thumb = make_thumbnail(full)
            saved_before += len(full)
            saved_after += len(thumb)

            if args.dry_run:
                print(f"  would write {thumb_path}  "
                      f"{len(full) // 1024} KB -> {len(thumb) // 1024} KB")
                done += 1
                continue

            request(
                f"{base}/storage/v1/object/{BUCKET}/{thumb_path}",
                key,
                method="POST",
                data=thumb,
                extra_headers={
                    "Content-Type": "image/jpeg",
                    # Overwrite rather than 409 on a re-run.
                    "x-upsert": "true",
                },
            )
            request(
                f"{base}/rest/v1/listing_media?id=eq.{row['id']}",
                key,
                method="PATCH",
                data=json.dumps({"thumbnail_path": thumb_path}).encode("utf-8"),
                extra_headers={
                    "Content-Type": "application/json",
                    "Prefer": "return=minimal",
                },
            )
            print(f"  {thumb_path}  {len(full) // 1024} KB -> {len(thumb) // 1024} KB")
            done += 1
        except (urllib.error.HTTPError, urllib.error.URLError, OSError) as exc:
            # One bad object must not stop the walk — the coalesce means an
            # un-thumbnailed row still renders.
            print(f"  !! {path}: {exc}")
            failed += 1

    verb = "would shrink" if args.dry_run else "shrank"
    if saved_before:
        pct = 100 - (saved_after * 100 // saved_before)
        print(f"\n{done} done, {failed} failed. Card bytes {verb} "
              f"{saved_before // 1024} KB -> {saved_after // 1024} KB ({pct}% less).")


if __name__ == "__main__":
    main()
