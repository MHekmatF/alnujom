// lib/features/favorites/data/repositories/favorites_repository_impl.dart
//
// Phase 17 — concrete [FavoritesRepository] delegating to
// [SupabaseFavoritesDatasource]. Wraps exceptions in typed [Failure] values
// per the Phase 14/15/16 pattern (SearchRepositoryImpl / MapRepositoryImpl /
// InquiryRepositoryImpl).
//
// Per Constitution IX this file MUST NOT import supabase_flutter directly —
// the datasource is the sole importer. The single exception is
// [PostgrestException] which is imported for typed error mapping.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/favorite_listing.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/supabase_favorites_datasource.dart';

@Injectable(as: FavoritesRepository)
class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._datasource);

  final SupabaseFavoritesDatasource _datasource;

  @override
  Future<Result<void>> addFavorite(String listingId) async {
    try {
      await _datasource.addFavorite(listingId);
      return const Success(null);
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure('addFavorite failed: ${e.message}', cause: e, stackTrace: st),
      );
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
      return FailureResult(
        UnknownFailure('addFavorite failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> removeFavorite(String listingId) async {
    try {
      await _datasource.removeFavorite(listingId);
      return const Success(null);
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
      return FailureResult(
        UnknownFailure('removeFavorite failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<String>>> loadFavoriteIds() async {
    try {
      final ids = await _datasource.loadFavoriteIds();
      return Success(ids);
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
      return FailureResult(
        UnknownFailure('loadFavoriteIds failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<FavoriteListing>>> loadFavorites({
    String? cursor,
    int limit = 30,
  }) async {
    try {
      final dtos = await _datasource.loadFavorites(
        cursor: cursor,
        limit: limit,
      );
      return Success(dtos.map((d) => d.toEntity()).toList());
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
      return FailureResult(
        UnknownFailure('loadFavorites failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
