# -*- coding: utf-8 -*-
"""Publish the in-app update manifest, and refuse to publish a step backwards.

Plan A40 (review 2026-09-05 §2.5): the live `app-release/android/latest.json`
was a June placeholder, and nothing stopped a hand-written file from carrying a
LOWER build than the one people already run — which silently switches the
update prompt off for everyone (memory: the split-per-abi versionCode, not the
pubspec `+N`, is what the phone compares).

    python tool/publish_manifest.py --version 1.1.3 --build 2005 \
        --telegram-url https://t.me/<channel>/<post> \
        [--min-supported 1.1.0] [--notes-ar "..."] [--notes-en "..."] [--force]

Reads SUPABASE_URL from .env.json and the service-role key from
.env.admin.json — both build-machine files, never committed (ADR-0001). The
script GETs the current public manifest first and refuses when the new build
is not higher, unless --force says you mean it. --dry-run prints what it
would upload and stops.
"""
import argparse
import io
import json
import re
import sys
import urllib.error
import urllib.request

BUCKET_PATH = 'app-release/android/latest.json'
SEMVER = re.compile(r'^\d+\.\d+\.\d+$')


def load_json(path):
    with io.open(path, encoding='utf-8') as f:
        return json.load(f)


def version_tuple(v):
    return tuple(int(x) for x in v.split('.'))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--version', required=True, help='latest_version, e.g. 1.1.3 (the pubspec version, no +build)')
    ap.add_argument('--build', required=True, type=int, help='latest_build, e.g. 2005 (the arm64 split versionCode)')
    ap.add_argument('--telegram-url', required=True, help='the Telegram post the Update button opens')
    ap.add_argument('--website-url', default=None)
    ap.add_argument('--min-supported', default=None, help='forced-update floor (plan A31); leave unset for an ordinary release')
    ap.add_argument('--notes-ar', default=None)
    ap.add_argument('--notes-en', default=None)
    ap.add_argument('--force', action='store_true', help='publish even if the build is not higher than the live one')
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    if not SEMVER.match(args.version):
        sys.exit('version must look like 1.2.3, got %r' % args.version)
    if args.min_supported is not None:
        if not SEMVER.match(args.min_supported):
            sys.exit('min-supported must look like 1.2.3, got %r' % args.min_supported)
        if version_tuple(args.min_supported) > version_tuple(args.version):
            sys.exit('min-supported %s is above the version being published (%s); that would lock everyone out'
                     % (args.min_supported, args.version))
    if not args.telegram_url.startswith('https://t.me/'):
        sys.exit('telegram-url must be an https://t.me/... post link, got %r' % args.telegram_url)

    env = load_json('.env.json')
    url = env['SUPABASE_URL'].rstrip('/')
    public_url = '%s/storage/v1/object/public/%s' % (url, BUCKET_PATH)

    # 1. What is live now?
    try:
        with urllib.request.urlopen(public_url, timeout=30) as r:
            live = json.loads(r.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
        live = None
    live_build = int(live.get('latest_build', 0)) if live else 0
    live_version = live.get('latest_version') if live else None
    print('live manifest: version=%s build=%s' % (live_version, live_build))

    if live and args.build <= live_build and not args.force:
        sys.exit('REFUSED: build %d is not higher than the live build %d. A lower or equal build switches the '
                 'update prompt off for everyone. Pass --force only if you really mean it.' % (args.build, live_build))
    if live and live_version and version_tuple(args.version) < version_tuple(live_version) and not args.force:
        sys.exit('REFUSED: version %s is below the live version %s.' % (args.version, live_version))

    manifest = {
        'latest_version': args.version,
        'latest_build': args.build,
        'min_supported_version': args.min_supported,
        'download': {'telegram_url': args.telegram_url, 'website_url': args.website_url},
        'release_notes': {'ar': args.notes_ar, 'en': args.notes_en},
    }
    body = json.dumps(manifest, ensure_ascii=False, indent=2).encode('utf-8')
    print(body.decode('utf-8'))
    if args.dry_run:
        print('dry run: nothing uploaded')
        return

    # 2. Upload with the service-role key (build machine only — ADR-0001).
    admin = load_json('.env.admin.json')
    key = admin.get('SUPABASE_SERVICE_ROLE_KEY') or admin.get('service_role_key') or admin.get('SERVICE_ROLE_KEY')
    if not key:
        sys.exit('.env.admin.json has no service-role key under SUPABASE_SERVICE_ROLE_KEY')
    req = urllib.request.Request(
        '%s/storage/v1/object/%s' % (url, BUCKET_PATH),
        data=body, method='POST',
        headers={'Authorization': 'Bearer ' + key, 'apikey': key,
                 'Content-Type': 'application/json', 'x-upsert': 'true',
                 'Cache-Control': 'max-age=60'})
    with urllib.request.urlopen(req, timeout=60) as r:
        print('upload:', r.status)

    # 3. Read it back the way a phone does.
    with urllib.request.urlopen(public_url, timeout=30) as r:
        back = json.loads(r.read().decode('utf-8'))
    if back.get('latest_build') != args.build:
        sys.exit('read-back mismatch: live build is %s, expected %d' % (back.get('latest_build'), args.build))
    print('published: version=%s build=%d' % (back['latest_version'], back['latest_build']))


if __name__ == '__main__':
    main()
