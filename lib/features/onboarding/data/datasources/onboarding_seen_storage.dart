import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/logging/app_logger.dart';

/// Secure-storage wrapper for the onboarding-seen flag (Phase 5 R-10).
@LazySingleton()
class OnboardingSeenStorage {
  OnboardingSeenStorage(this._logger) : _storage = const FlutterSecureStorage();

  static const _tag = 'OnboardingSeenStorage';
  static const _key = 'com.alnujom.onboarding.seen_v1';

  final AppLogger _logger;
  final FlutterSecureStorage _storage;

  Future<bool> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return raw == 'true';
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to read onboarding-seen flag (treating as not seen).',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return false;
    }
  }

  Future<void> write(bool seen) async {
    try {
      await _storage.write(key: _key, value: seen ? 'true' : 'false');
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to write onboarding-seen flag.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }
}
