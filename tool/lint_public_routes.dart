// Verifies that every route app_router.dart declares anonymous-accessible is
// actually reachable by a signed-out visitor.
//
// Why this exists: the router and the redirect disagree silently, and users
// find out, not the build. A GoRoute that adds no `redirect:` looks public in
// app_router.dart — but `authRedirect` still runs on every navigation, and
// anything it does not recognise as public goes to /login. Three separate
// batches of screens shipped that way:
//
//   * `/search` and `/map` — a guest tapping the Search or Map tab was ejected
//     to the login screen. (Phases 14/15; the bottom-nav shell arrived later.)
//   * `/agency/:id` — the public agency profile, whose own comment reads "no
//     auth redirect", was bounced too.
//   * `/settings`, `/assistant`, `/reels` — same. `/settings` was the one that
//     bit hardest: a guest's drawer offers exactly two destinations, and
//     tapping Settings threw them out of the app's own navigation.
//
// The intent is written down in every case — a comment above the route saying
// it is anonymous-accessible. Nothing checked it against the redirect. This
// does.
//
// CONVENTION: put `Anonymous-accessible` (or `public …` / `no auth redirect`)
// in the comment block directly above a GoRoute, and this linter will require
// the path to be reachable by a guest.
//
// Exit codes: 0 clean · 1 violations found · 2 script failure.
import 'dart:io';

const _routerPath = 'lib/core/routing/app_router.dart';
const _redirectPath = 'lib/core/routing/auth_redirect.dart';

final _marker = RegExp(
  r'anonymous[- ]accessible|public\s+(listing|search|map|about|agency)|no auth redirect',
  caseSensitive: false,
);

void main() {
  final router = File(_routerPath);
  final redirect = File(_redirectPath);
  if (!router.existsSync() || !redirect.existsSync()) {
    stderr.writeln('lint_public_routes: routing sources not found.');
    exit(2);
  }

  final routerLines = router.readAsLinesSync();

  // AppRoutes.foo -> '/foo'. Read ONLY from the AppRoutes class: AppRouteNames
  // reuses the same member names for go_router's route names ('maintenance'),
  // and picking one of those up would compare the wrong string.
  final constants = <String, String>{};
  final aliases = <String, String>{}; // foo -> someOtherConst
  final constPattern = RegExp(
    r"static const ([A-Za-z0-9_]+)\s*=\s*'([^']+)'",
  );
  // `static const maintenance = maintenanceRoute;` — one level of indirection.
  final aliasPattern = RegExp(
    r'static const ([A-Za-z0-9_]+)\s*=\s*([A-Za-z0-9_]+)\s*;',
  );
  var inAppRoutes = false;
  for (final line in routerLines) {
    if (line.contains('class AppRoutes')) {
      inAppRoutes = true;
      continue;
    }
    if (line.contains('class AppRouteNames')) inAppRoutes = false;
    if (!inAppRoutes) continue;
    final m = constPattern.firstMatch(line);
    if (m != null) {
      constants[m.group(1)!] = m.group(2)!;
      continue;
    }
    final a = aliasPattern.firstMatch(line);
    if (a != null) aliases[a.group(1)!] = a.group(2)!;
  }
  // Resolve aliases against any '/...' literal declared anywhere in lib/.
  if (aliases.isNotEmpty) {
    final literals = <String, String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in RegExp(
        r"const ([A-Za-z0-9_]+)\s*=\s*('/[^']*')",
      ).allMatches(f.readAsStringSync())) {
        literals[m.group(1)!] = m.group(2)!.replaceAll("'", '');
      }
    }
    aliases.forEach((name, target) {
      final resolved = literals[target] ?? constants[target];
      if (resolved != null) constants[name] = resolved;
    });
  }

  // Routes whose preceding comment block declares them anonymous-accessible.
  final declaredPublic = <String, String>{}; // path -> constant name
  final pathPattern = RegExp(r'path:\s*AppRoutes\.([A-Za-z0-9_]+)\s*,');
  for (var i = 0; i < routerLines.length; i++) {
    final m = pathPattern.firstMatch(routerLines[i]);
    if (m == null) continue;
    // Walk back over the contiguous comment block above this GoRoute.
    final buffer = StringBuffer();
    for (var j = i - 1; j >= 0 && i - j <= 10; j--) {
      final trimmed = routerLines[j].trim();
      if (trimmed.startsWith('//')) {
        buffer.writeln(trimmed);
      } else if (trimmed.isEmpty ||
          trimmed.startsWith('GoRoute(') ||
          trimmed.startsWith('name:')) {
        continue;
      } else {
        break;
      }
    }
    if (!_marker.hasMatch(buffer.toString())) continue;
    final name = m.group(1)!;
    final path = constants[name];
    if (path != null) declaredPublic[path] = name;
  }

  // What authRedirect actually lets through when signed out. Comments are
  // stripped first — an apostrophe in prose ("visitor's drawer") would
  // otherwise be read as the start of a string literal.
  final redirectSrc = redirect
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join(String.fromCharCode(10));
  final allowed = <String>{};
  final setBlock = RegExp(
    r'const _(?:public|authOnly)Paths\s*=\s*\{(.*?)\};',
    dotAll: true,
  );
  for (final block in setBlock.allMatches(redirectSrc)) {
    for (final lit in RegExp(r"'([^']+)'").allMatches(block.group(1)!)) {
      allowed.add(lit.group(1)!);
    }
  }
  final prefixes = RegExp(r"path\.startsWith\('([^']+)'\)")
      .allMatches(redirectSrc)
      .map((m) => m.group(1)!)
      .toList();

  // Anchored raw-string patterns, e.g. the RegExp that matches
  // `/agency/<uuid>` but deliberately NOT `/agency/members`.
  //
  // A pattern only counts if the redirect actually CONSULTS it: the variable it
  // is assigned to has to appear in a `hasMatch(path)` call. Collecting every
  // pattern in the file would let a rule keep passing after the `if` that used
  // it was deleted — which is exactly the regression this linter exists to
  // catch.
  final consulted = RegExp(r'(\w+)\.hasMatch\(path\)')
      .allMatches(redirectSrc)
      .map((m) => m.group(1)!)
      .toSet();
  final anchoredPatterns = <String>[];
  for (final m in RegExp(
    r"(?:final|static final|var)\s+(\w+)\s*=\s*RegExp\(([^;]*)\);",
  ).allMatches(redirectSrc)) {
    if (!consulted.contains(m.group(1))) continue;
    // Adjacent raw literals are concatenated in Dart; the anchor lives in the
    // first one, which is all this check needs.
    for (final lit in RegExp(r"r'\^([^']+)'").allMatches(m.group(2)!)) {
      anchoredPatterns.add(lit.group(1)!);
    }
  }

  /// The part of a route path before its first parameter — `/agency/:id`
  /// becomes `/agency/`. That is what a prefix or an anchored pattern has to
  /// cover for the route to be reachable.
  String staticPrefix(String path) {
    final i = path.indexOf(':');
    return i == -1 ? path : path.substring(0, i);
  }

  bool reachable(String path) {
    if (allowed.contains(path)) return true;
    final stem = staticPrefix(path);
    if (prefixes.any(stem.startsWith)) return true;
    return anchoredPatterns.any((p) => p.startsWith(stem));
  }

  final missing = declaredPublic.entries
      .where((e) => !reachable(e.key))
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  if (missing.isEmpty) {
    stdout.writeln(
      'Public-route check passed '
      '(${declaredPublic.length} anonymous-accessible routes, all reachable).',
    );
    exit(0);
  }

  stderr.writeln(
    'Public-route check FAILED — declared anonymous-accessible in '
    '$_routerPath, but a signed-out visitor is redirected to /login:',
  );
  for (final e in missing) {
    stderr.writeln('  ${e.key}  (AppRoutes.${e.value})');
  }
  stderr.writeln(
    '\nAdd the path to _publicPaths in $_redirectPath, or a startsWith prefix '
    'if it takes a parameter. A guest tapping into one of these lands on the '
    'login screen with no way back to what they were looking at.',
  );
  exit(1);
}
