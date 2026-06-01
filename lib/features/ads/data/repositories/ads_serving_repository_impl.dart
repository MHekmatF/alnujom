// Phase 21 (spec/021-ads-banners) — AdsServingRepositoryImpl.
//
// Concrete [AdsServingRepository] delegating to [SupabaseAdsServingDatasource].
// Wraps exceptions in typed [Failure] values — mirroring the Phase 19 pattern.
//
// Per Constitution IX: this file MAY import [PostgrestException] for error-
// code mapping; it MUST NOT import any other supabase_flutter symbol.
//
// Error mapping:
//   23514  ad_not_eligible  → ValidationFailure('ad_not_eligible')
//   Other  PostgrestException → UnknownFailure
//   SocketException            → NetworkFailure
//   TimeoutException           → NetworkFailure

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/serving_ad.dart';
import '../../domain/repositories/ads_serving_repository.dart';
import '../datasources/supabase_ads_serving_datasource.dart';

@LazySingleton(as: AdsServingRepository)
class AdsServingRepositoryImpl implements AdsServingRepository {
  AdsServingRepositoryImpl(this._datasource);

  final SupabaseAdsServingDatasource _datasource;

  @override
  Future<Result<List<ServingAd>>> loadServingAds(
    AdPlacement placement,
  ) async {
    try {
      final dtos =
          await _datasource.loadServingAds(placement.wireValue);
      return Success(dtos.map((d) => d.toEntity()).toList());
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'loadServingAds failed: ${e.message}',
          cause: e,
          stackTrace: st,
        ),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadServingAds failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> recordClick({
    required String adId,
    required AdPlacement placement,
  }) async {
    try {
      await _datasource.recordAdEvent(
        adId: adId,
        placementKey: placement.wireValue,
      );
      return const Success(null);
    } on PostgrestException catch (e, st) {
      final code = e.code ?? '';
      if (e.message.contains('ad_not_eligible') || code == '23514') {
        return const FailureResult(ValidationFailure('ad_not_eligible'));
      }
      return FailureResult(
        UnknownFailure(
          'recordClick failed: ${e.message}',
          cause: e,
          stackTrace: st,
        ),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('recordClick failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
