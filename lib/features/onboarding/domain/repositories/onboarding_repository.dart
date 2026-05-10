/// Onboarding-seen flag repository (Phase 5 FR-013, R-10).
abstract class OnboardingRepository {
  Future<bool> hasSeenOnboarding();
  Future<void> markSeen();
}
