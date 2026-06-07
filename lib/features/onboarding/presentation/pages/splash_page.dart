import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/repositories/onboarding_repository.dart';

/// Branded splash screen that routes to the correct destination based on
/// auth state + onboarding-seen flag.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryNavigate());
  }

  Future<void> _tryNavigate() async {
    if (_handled || !mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticating) return;
    _handled = true;
    await _navigateFrom(authState);
  }

  Future<void> _navigateFrom(AuthState authState) async {
    if (!mounted) return;
    switch (authState) {
      case Authenticated():
        context.go(AppRoutes.home);
      case PendingApproval():
        context.go(AppRoutes.pending);
      case Rejected():
        context.go(AppRoutes.rejected);
      case Suspended():
        context.go(AppRoutes.suspended);
      case Unauthenticated():
      case AuthError():
        final seen = await getIt<OnboardingRepository>().hasSeenOnboarding();
        if (!mounted) return;
        context.go(seen ? AppRoutes.login : AppRoutes.onboarding);
      case Authenticating():
        _handled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phase 26 rebrand — the full logo artwork (emblem + النجوم wordmark +
    // tagline) on white, matching the native splash for a seamless hand-off.
    // No extra text: the wordmark is part of the artwork.
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, curr) => curr is! Authenticating,
      listener: (context, state) {
        _handled = false;
        _tryNavigate();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: StaggeredListItem(
            index: 0,
            child: Image.asset(
              'assets/branding/splash_full.png',
              width: MediaQuery.sizeOf(context).width * 0.78,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
