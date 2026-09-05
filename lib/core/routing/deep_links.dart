// lib/core/routing/deep_links.dart
//
// Review §1 M3 — turning an incoming link into an in-app route.
//
// Sharing a listing is the growth loop for an app distributed through Telegram,
// and until now the link it produced could not open anything: the domain does
// not resolve, and the manifest declared no VIEW intent for a listing (only the
// auth-callback one). This is the parsing half — `deep_link_listener.dart`
// subscribes, `AndroidManifest.xml` declares the intent.
//
// A LINK IS UNTRUSTED INPUT. Anyone can craft one and hand it to the user, so
// this maps only onto a closed set: one route, with an id that must look like a
// UUID. Anything else returns null and the app stays where it is. The worst a
// hostile link can do is open the listing page for an id that does not exist,
// which renders the same not-found state as a deleted listing.

/// The app's private scheme. Registered in `AndroidManifest.xml`; the auth
/// callback (`alnujom://auth/...`) uses the same scheme but is NOT ours to
/// handle — see [resolveDeepLink].
const String kAppLinkScheme = 'alnujom';

/// The path segment the web landing page uses for a listing, kept short because
/// it is what people paste into a chat: `…/l/<id>`. `listings` is accepted too
/// so a link built from the in-app route shape still works.
const Set<String> _kListingMarkers = {'l', 'listings'};

/// Matches the id shape Postgres hands out, so a junk path never becomes a
/// route push.
final RegExp _kUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// The in-app location [uri] should open, or `null` when the app should ignore
/// it entirely.
///
/// Handles, in both forms the app will ever see:
///
/// - `alnujom://listings/{uuid}` — the private scheme, which works with no
///   domain and no verification, and is what the landing page's "Open in app"
///   button fires.
/// - `https://{host}/l/{uuid}` and `https://{host}/listings/{uuid}` — the web
///   landing page, and later the real domain (B16).
///
/// **Returns `null` for `alnujom://auth/...` on purpose.** supabase_flutter's
/// own app_links observer owns the recovery callback: it calls
/// `getSessionFromUrl` and the resulting `passwordRecovery` event is what
/// drives navigation (`PasswordRecoveryListener`). Routing it here as well
/// would land the user on the request-a-reset page instead — the same trap that
/// keeps `flutter_deeplinking_enabled` set to false in the manifest.
String? resolveDeepLink(Uri uri) {
  final scheme = uri.scheme.toLowerCase();

  final List<String> segments;
  if (scheme == kAppLinkScheme) {
    // A custom-scheme URI puts the first segment in `host`:
    // `alnujom://listings/<id>` is host `listings`, path `/<id>`.
    if (uri.host.isEmpty) return null;
    segments = [uri.host.toLowerCase(), ...uri.pathSegments];
  } else if (scheme == 'https' || scheme == 'http') {
    segments = uri.pathSegments;
  } else {
    return null;
  }

  // Find the marker anywhere in the path, so a project-scoped host
  // (`…/alnujom/l/<id>`) works as well as a bare domain (`…/l/<id>`).
  for (var i = 0; i < segments.length; i++) {
    if (!_kListingMarkers.contains(segments[i].toLowerCase())) continue;

    if (i + 1 < segments.length) {
      final id = segments[i + 1];
      return _kUuid.hasMatch(id) ? '/listings/$id' : null;
    }
    // `…/l/?id=<uuid>` — the form GitHub Pages can actually serve, since a
    // static host has no rewrite and `…/l/<uuid>` would 404 on a directory
    // that does not exist. The real domain (B16) can use the path form above;
    // both resolve here so the switch is one constant in the app.
    final queryId = uri.queryParameters['id'];
    if (queryId != null && _kUuid.hasMatch(queryId)) {
      return '/listings/$queryId';
    }
    return null;
  }
  return null;
}
