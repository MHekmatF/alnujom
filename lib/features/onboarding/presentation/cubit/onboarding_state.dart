import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

sealed class OnboardingState extends Equatable {
  const OnboardingState();
}

final class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();

  @override
  List<Object?> get props => [];
}

final class OnboardingInProgress extends OnboardingState {
  const OnboardingInProgress({
    required this.step,
    required this.totalSteps,
    this.selectedLocale,
  });

  final int step;
  final int totalSteps;
  final Locale? selectedLocale;

  @override
  List<Object?> get props => [step, totalSteps, selectedLocale];
}

final class OnboardingDone extends OnboardingState {
  const OnboardingDone();

  @override
  List<Object?> get props => [];
}
