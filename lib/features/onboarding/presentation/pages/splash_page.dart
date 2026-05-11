import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, curr) => curr is! Authenticating,
      listener: (context, state) {
        _handled = false;
        _tryNavigate();
      },
      child: Scaffold(
        body: Center(
          child: Text(l10n.appTitle, style: theme.textTheme.displayLarge),
        ),
      ),
    );
  }
}
