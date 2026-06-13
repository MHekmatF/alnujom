import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:ui' show Locale;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/reel.dart';
import '../../domain/repositories/reels_repository.dart';
import '../datasources/supabase_reels_datasource.dart';

/// Phase 029 (Reels W4) — concrete [ReelsRepository] delegating to
/// [SupabaseReelsDatasource] and mapping DTOs → entities. Transport-level
/// failures are wrapped in [NetworkFailure] (mirrors the Phase-13 home-feed
/// repository); this file never imports `package:supabase_flutter` (FR-030).
@LazySingleton(as: ReelsRepository)
class ReelsRepositoryImpl implements ReelsRepository {
  ReelsRepositoryImpl(this._datasource);

  final SupabaseReelsDatasource _datasource;

  @override
  Future<Result<List<Reel>>> fetchPage({
    int limit = 10,
    ReelCursor? before,
    required Locale locale,
  }) async {
    try {
      final dtos = await _datasource.fetchPage(limit: limit, before: before);
      final entities = dtos
          .map((dto) => dto.toEntity(locale: locale))
          // Defensive: drop any row whose video URL failed to resolve — the
          // player would have nothing to play.
          .where((reel) => reel.videoUrl.isNotEmpty)
          .toList();
      return Success(entities);
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      // PostgrestException + other Supabase transport errors fall through here;
      // we treat any unknown round-trip exception as a NetworkFailure (the rail
      // hides itself on failure). No supabase_flutter import per FR-030.
      return FailureResult(
        NetworkFailure(e.toString(), cause: e, stackTrace: st),
      );
    }
  }
}
