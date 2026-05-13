import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../shared/domain/entities/profile.dart';
import '../repositories/profile_repository.dart';

/// Domain-layer validation per data-model.md §6 (R-17).
@injectable
class UpdateProfile {
  const UpdateProfile(this._repository);

  final ProfileRepository _repository;

  static final _usernameRe = RegExp(r'^[a-z0-9_]{3,30}$');
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<Result<Profile>> call({
    String? fullName,
    String? username,
    String? email,
    String? avatarUrl,
  }) {
    if (fullName != null) {
      final t = fullName.trim();
      if (t.isEmpty || t.length > 100) {
        return Future.value(const FailureResult(InvalidFullName()));
      }
      fullName = t;
    }

    if (username != null) {
      final t = username.toLowerCase().trim();
      if (!_usernameRe.hasMatch(t)) {
        return Future.value(const FailureResult(InvalidUsername()));
      }
      username = t;
    }

    if (email != null && email.isNotEmpty) {
      final t = email.trim();
      if (!_emailRe.hasMatch(t)) {
        return Future.value(const FailureResult(InvalidEmail()));
      }
      email = t;
    }

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (!avatarUrl.trim().startsWith('https://')) {
        return Future.value(const FailureResult(InvalidAvatarUrl()));
      }
    }

    return _repository.updateProfile(
      fullName: fullName,
      username: username,
      email: (email?.isEmpty ?? false) ? null : email,
      avatarUrl: (avatarUrl?.isEmpty ?? false) ? null : avatarUrl,
    );
  }
}
