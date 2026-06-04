import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/brand_mark.dart';
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    // Branded splash on the primary surface — matches the native splash so the
    // hand-off is seamless (white star mark + coral companion + wordmark).
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, curr) => curr is! Authenticating,
      listener: (context, state) {
        _handled = false;
        _tryNavigate();
      },
      child: Scaffold(
        backgroundColor: colors.primary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(
                size: 88,
                color: colors.onPrimary,
                accentColor: colors.accent,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.appTitle,
                style: styles.displayMedium.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
