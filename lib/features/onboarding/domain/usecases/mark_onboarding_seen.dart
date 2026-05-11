import '../repositories/onboarding_repository.dart';

class MarkOnboardingSeen {
  const MarkOnboardingSeen(this._repository);

  final OnboardingRepository _repository;

  Future<void> call() => _repository.markSeen();
}
