import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:ui' show Locale;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/cursor.dart';
import '../../domain/entities/home_listing_card.dart';
import '../../domain/repositories/home_feed_repository.dart';
import '../datasources/supabase_home_feed_datasource.dart';

/// Phase 13 — concrete repository delegating to
/// [SupabaseHomeFeedDatasource] and mapping DTOs → entities. Transport-level
/// failures (`SocketException`, `TimeoutException`, and PostgREST-shaped
/// exceptions surfaced through the datasource) are wrapped in
/// [NetworkFailure] per the Phase 1 pattern.
///
/// Per FR-030 + SC-013, this file MUST NOT import `package:supabase_flutter`.
/// We catch the concrete supabase exception by its runtime type name from
/// the generic `catch` arm instead of importing the package.
@LazySingleton(as: HomeFeedRepository)
class HomeFeedRepositoryImpl implements HomeFeedRepository {
  HomeFeedRepositoryImpl(this._datasource);

  final SupabaseHomeFeedDatasource _datasource;

  @override
  Future<Result<List<HomeListingCard>>> fetchPage({
    Cursor? cursor,
    required Locale locale,
  }) async {
    try {
      final dtos = await _datasource.fetchPage(cursor: cursor);
      final entities = dtos.map((dto) => dto.toEntity(locale: locale)).toList();
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
      // PostgrestException + other Supabase transport errors fall through
      // here. We treat any unknown exception during a Supabase round-trip
      // as a NetworkFailure so the UI surfaces the FR-014 retry affordance.
      // We deliberately do not import `package:supabase_flutter` per FR-030.
      final message = e is Error ? e.toString() : e.toString();
      return FailureResult(NetworkFailure(message, cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<HomeListingCard>>> fetchFeatured({
    int limit = 10,
    required Locale locale,
  }) async {
    try {
      final dtos = await _datasource.fetchFeatured(limit: limit);
      final entities = dtos.map((dto) => dto.toEntity(locale: locale)).toList();
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
      // Same transport-error handling as fetchPage — any unknown exception
      // during the Supabase round-trip is a NetworkFailure (the featured
      // carousel hides itself on failure). We deliberately do not import
      // `package:supabase_flutter` per FR-030.
      final message = e is Error ? e.toString() : e.toString();
      return FailureResult(NetworkFailure(message, cause: e, stackTrace: st));
    }
  }
}
