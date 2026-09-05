// Plan A34 — FeedbackRepositoryImpl.
//
// Concrete [FeedbackRepository] delegating to [SupabaseFeedbackDatasource];
// wraps exceptions in typed [Failure] values the same way the reports
// repository does. Imports supabase_flutter only for PostgrestException
// (typed error-code mapping), per Constitution IX.
//
// RPC error-code → Failure mapping (submit_feedback SQLSTATE codes):
//   42501  authentication required → PermissionDeniedFailure
//   22023  invalid_category        → ValidationFailure('invalid_category')
//   23514  invalid_message_length  → ValidationFailure('invalid_message_length')
//   23514  rate_limited            → ValidationFailure('rate_limited')
//   Other PostgrestException       → UnknownFailure

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/feedback_category.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../datasources/supabase_feedback_datasource.dart';

@Injectable(as: FeedbackRepository)
class FeedbackRepositoryImpl implements FeedbackRepository {
  const FeedbackRepositoryImpl(this._datasource);

  final SupabaseFeedbackDatasource _datasource;

  static const _knownCodes = [
    'rate_limited',
    'invalid_message_length',
    'invalid_category',
  ];

  @override
  Future<Result<String>> submit({
    required FeedbackCategory category,
    required String message,
    String? appBuild,
    String? platform,
  }) async {
    try {
      final id = await _datasource.submit(
        category: category.wireValue,
        message: message,
        appBuild: appBuild,
        platform: platform,
      );
      return Success(id);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st));
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
        UnknownFailure('submitFeedback failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  Failure _mapRpcError(PostgrestException e, StackTrace st) {
    final msg = e.message;
    if (e.code == '42501' || msg.contains('authentication required')) {
      return const PermissionDeniedFailure();
    }
    for (final code in _knownCodes) {
      if (msg.contains(code)) return ValidationFailure(code);
    }
    if (e.code == '23514' || e.code == '22023') {
      return ValidationFailure(msg);
    }
    return UnknownFailure(
      'submitFeedback failed: ${e.message}',
      cause: e,
      stackTrace: st,
    );
  }
}
