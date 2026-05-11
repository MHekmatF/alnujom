import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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

          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: TextButton(
                      onPressed: () =>
                          context.read<OnboardingCubit>().markSeen(),
                      child: Text(l10n.onboarding_skip),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: steps.length,
                      itemBuilder: (context, index) {
                        final s = steps[index];
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                s.title,
                                style: theme.textTheme.headlineMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                s.body,
                                style: theme.textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Step indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(total, (i) {
                      return Container(
                        margin: const EdgeInsets.all(4),
                        width: i == step ? 16 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == step
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: FilledButton(
                      onPressed: () =>
                          context.read<OnboardingCubit>().nextStep(),
                      child: Text(
                        step + 1 >= total
                            ? l10n.onboarding_get_started
                            : l10n.onboarding_get_started,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepData {
  const _StepData({required this.title, required this.body});

  final String title;
  final String body;
}
