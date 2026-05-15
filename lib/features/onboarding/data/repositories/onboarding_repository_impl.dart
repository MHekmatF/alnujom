import 'package:injectable/injectable.dart';

import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_seen_storage.dart';

@LazySingleton(as: OnboardingRepository)
class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._storage);

  final OnboardingSeenStorage _storage;

  @override
  Future<bool> hasSeenOnboarding() => _storage.read();

  @override
  Future<void> markSeen() => _storage.write(true);
}
