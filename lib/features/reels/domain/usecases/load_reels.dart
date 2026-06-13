import 'dart:ui' show Locale;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/reel.dart';
import '../repositories/reels_repository.dart';

/// Phase 029 (Reels W4) — use case wrapping [ReelsRepository.fetchPage]. Shared
/// by [ReelsRailCubit] (first page) and [ReelsFeedCubit] (keyset pagination).
@injectable
class LoadReels {
  const LoadReels(this._repository);

  final ReelsRepository _repository;

  Future<Result<List<Reel>>> call({
    int limit = 10,
    ReelCursor? before,
    required Locale locale,
  }) {
    return _repository.fetchPage(limit: limit, before: before, locale: locale);
  }
}
