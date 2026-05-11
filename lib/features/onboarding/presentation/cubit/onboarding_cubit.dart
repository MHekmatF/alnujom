import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/onboarding_repository.dart';
import 'onboarding_state.dart';

@injectable
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._repository) : super(const OnboardingInitial());

  static const totalSteps = 3;

  final OnboardingRepository _repository;

  void start() {
    emit(const OnboardingInProgress(step: 0, totalSteps: totalSteps));
  }

  void nextStep() {
    if (state case OnboardingInProgress(:final step, :final selectedLocale)) {
      if (step + 1 >= totalSteps) {
        markSeen();
      } else {
        emit(OnboardingInProgress(
          step: step + 1,
          totalSteps: totalSteps,
          selectedLocale: selectedLocale,
        ));
      }
    }
  }

  void previousStep() {
    if (state case OnboardingInProgress(:final step, :final selectedLocale)) {
      if (step > 0) {
        emit(OnboardingInProgress(
          step: step - 1,
          totalSteps: totalSteps,
          selectedLocale: selectedLocale,
        ));
      }
    }
  }

  void selectLocale(Locale locale) {
    if (state case OnboardingInProgress(:final step, :final totalSteps)) {
      emit(OnboardingInProgress(
        step: step,
        totalSteps: totalSteps,
        selectedLocale: locale,
      ));
    }
  }

  Future<void> markSeen() async {
    await _repository.markSeen();
    emit(const OnboardingDone());
  }
}
