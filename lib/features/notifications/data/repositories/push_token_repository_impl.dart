// lib/features/notifications/data/repositories/push_token_repository_impl.dart
//
// Phase 22 — Concrete [PushTokenRepository] delegating to
// [SupabasePushTokenDatasource].
//
// Principle IX: MUST NOT import supabase_flutter directly beyond
// [PostgrestException] (typed error-code mapping only).

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/repositories/push_token_repository.dart';
import '../datasources/supabase_push_token_datasource.dart';

@LazySingleton(as: PushTokenRepository)
class PushTokenRepositoryImpl implements PushTokenRepository {
  PushTokenRepositoryImpl(this._datasource);

  final SupabasePushTokenDatasource _datasource;

  @override
  Future<Result<void>> register(
    String token, {
    String platform = 'android',
  }) async {
    try {
      await _datasource.register(token, platform: platform);
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
        UnknownFailure(
          'register push token failed: $e',
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deregister(String token) async {
    try {
      await _datasource.deregister(token);
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
        UnknownFailure(
          'deregister push token failed: $e',
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }
}
