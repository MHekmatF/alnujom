import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OnboardingCubit>(
      create: (_) => getIt<OnboardingCubit>()..start(),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final _pageController = PageController();

  // Phase 25 — full-bleed hero imagery per slide (Claude Design welcome).
  static const _images = <String>[
    'assets/onboarding/slide1.jpg',
    'assets/onboarding/slide2.jpg',
    'assets/onboarding/slide3.jpg',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return BlocListener<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingDone) {
          context.go(AppRoutes.register);
        } else if (state is OnboardingInProgress) {
          _pageController.animateToPage(
            state.step,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: BlocBuilder<OnboardingCubit, OnboardingState>(
        builder: (context, state) {
          final step = state is OnboardingInProgress ? state.step : 0;
          final total = OnboardingCubit.totalSteps;

          final steps = [
            _StepData(
              title: l10n.onboarding_step_1_title,
              body: l10n.onboarding_step_1_body,
            ),
            _StepData(
              title: l10n.onboarding_step_2_title,
              body: l10n.onboarding_step_2_body,
            ),
            _StepData(
              title: l10n.onboarding_step_3_title,
              body: l10n.onboarding_step_3_body,
            ),
          ];
          final current = steps[step.clamp(0, steps.length - 1)];

          return Scaffold(
            body: Stack(
              children: [
                // Full-bleed slide imagery + scrim.
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _images.length,
                    itemBuilder: (context, index) =>
                        _SlideBackground(image: _images[index]),
                  ),
                ),
                // Foreground content over the scrim.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            BrandMark(
                              withWordmark: true,
                              size: 24,
                              color: colors.onPhoto,
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: colors.onPhoto,
                              ),
                              onPressed: () =>
                                  context.read<OnboardingCubit>().markSeen(),
                              child: Text(l10n.onboarding_skip),
                            ),
                          ],
                        ),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: AppMotion.slow,
                          switchInCurve: AppMotion.curve,
                          switchOutCurve: AppMotion.curve,
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                alignment: AlignmentDirectional.centerStart,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              ),
                          child: Column(
                            key: ValueKey<int>(step),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.title,
                                style: styles.displayMedium.copyWith(
                                  color: colors.onPhoto,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                current.body,
                                style: styles.bodyLarge.copyWith(
                                  color: colors.onPhoto,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Semantics(
                          container: true,
                          label: l10n.stepCounter(step + 1, total),
                          child: ExcludeSemantics(
                            child: Row(
                              children: List.generate(total, (i) {
                                final active = i == step;
                                return AnimatedContainer(
                                  duration: AppMotion.base,
                                  curve: AppMotion.curve,
                                  margin: const EdgeInsetsDirectional.only(
                                    end: AppSpacing.xs,
                                  ),
                                  width: active ? AppSpacing.xl : AppSpacing.sm,
                                  height: AppSpacing.sm,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? colors.primary
                                        : colors.onPhoto.withValues(alpha: 0.5),
                                    borderRadius: appRadius(AppRadii.pill),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton.filledPrimary(
                          label: step >= total - 1
                              ? l10n.onboarding_get_started
                              : l10n.onboarding_next,
                          expanded: true,
                          onPressed: () =>
                              context.read<OnboardingCubit>().nextStep(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A single onboarding slide background: a full-bleed photo with a dark scrim
/// for legibility of the white brand bar (top) and headline/CTA (bottom).
class _SlideBackground extends StatelessWidget {
  const _SlideBackground({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    // The legibility scrim is derived from the dark `scrim` token so the brand
    // bar (top) and headline/CTA (bottom) stay readable over any slide photo.
    final scrim = AppColors.of(context).scrim.withValues(alpha: 1);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          image,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          frameBuilder: (context, child, frame, wasSync) => AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: AppMotion.base,
            curve: AppMotion.curve,
            child: child,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scrim.withValues(alpha: 0.6),
                scrim.withValues(alpha: 0.2),
                scrim.withValues(alpha: 0.88),
              ],
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepData {
  const _StepData({required this.title, required this.body});

  final String title;
  final String body;
}
