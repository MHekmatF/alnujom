// lib/features/auth/presentation/widgets/password_recovery_listener.dart
//
// Spec 005 D-01 — app-level password-recovery deep-link listener.
//
// supabase_flutter owns the `alnujom://auth/reset-password#access_token=…`
// intent: its bundled app_links observer calls `getSessionFromUrl`, which
// establishes a recovery session and emits `AuthChangeEvent.passwordRecovery`.
// AuthRepository re-publishes that as a domain-shaped stream; this widget is
// the single place that turns it into navigation.
//
// Mount it near the top of the tree (app.dart) so it is live app-wide — both
// for a warm resume (onNewIntent, thanks to launchMode="singleTop") and for a
// cold launch straight from the email link, where the repository replays the
// recovery that arrived before this widget existed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../domain/repositories/auth_repository.dart';

class PasswordRecoveryListener extends StatefulWidget {
  const PasswordRecoveryListener({required this.child, super.key});

  final Widget child;

  @override
  State<PasswordRecoveryListener> createState() =>
      _PasswordRecoveryListenerState();
}

class _PasswordRecoveryListenerState extends State<PasswordRecoveryListener> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = getIt<AuthRepository>().passwordRecoveryStream.listen((_) {
      // Defer to the next frame so the navigation runs AFTER the auth-state
      // change that accompanies the recovery session has settled the router's
      // redirect (the recovery session makes AuthBloc emit a new state, which
      // re-evaluates redirects on the CURRENT location).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        getIt<GoRouter>().go(AppRoutes.resetPasswordComplete);
      });
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
