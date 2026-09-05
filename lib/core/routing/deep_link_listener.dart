// lib/core/routing/deep_link_listener.dart
//
// Review §1 M3 — app-level listener for a shared listing link.
//
// Mirrors `PasswordRecoveryListener`: mounted near the top of the tree in
// `app.dart` so it is live app-wide, for a warm resume (onNewIntent, thanks to
// `launchMode="singleTop"`) and for a cold launch straight from the link.
//
// WHY app_links AND NOT FLUTTER'S OWN DEEP LINKING
// ------------------------------------------------
// `flutter_deeplinking_enabled` is deliberately **false** in the manifest: with
// it on, Flutter feeds the incoming URI to the router as the initial route, and
// `alnujom://auth/reset-password#access_token=…` resolves to the EXISTING
// request-a-reset page — dropping the user on the wrong screen mid-recovery
// (spec 005 D-01). Reading the intent ourselves keeps that off while still
// letting a listing link route, and `resolveDeepLink` returns null for the auth
// callback so supabase_flutter keeps sole ownership of it.
//
// app_links is already in the tree as supabase_flutter's own dependency; it is
// declared directly in `pubspec.yaml` because this file imports it.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../logging/app_logger.dart';
import 'deep_links.dart';

class DeepLinkListener extends StatefulWidget {
  const DeepLinkListener({required this.child, super.key});

  final Widget child;

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  static const _tag = 'DeepLinkListener';

  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    // `uriLinkStream` replays the launch URI to a new subscriber, so a cold
    // start from a link is covered without a separate getInitialLink() call —
    // and without the double-navigation that calling both would cause.
    _sub = AppLinks().uriLinkStream.listen(
      _handle,
      onError: (Object error, StackTrace stackTrace) {
        getIt<AppLogger>().warning(
          'Deep-link stream error.',
          error: error,
          stackTrace: stackTrace,
          tag: _tag,
        );
      },
    );
  }

  void _handle(Uri uri) {
    final location = resolveDeepLink(uri);
    if (location == null) return;
    // Defer a frame for the same reason PasswordRecoveryListener does: on a
    // cold launch this can fire before the router has settled its first
    // redirect, and a go() into that window is dropped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      getIt<GoRouter>().go(location);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
