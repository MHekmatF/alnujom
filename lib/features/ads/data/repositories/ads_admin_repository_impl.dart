// Phase 21 (spec/021-ads-banners) — AdsAdminRepositoryImpl.
//
// Concrete [AdsAdminRepository] delegating to [SupabaseAdsAdminDatasource].
// Wraps exceptions in typed [Failure] values — mirroring AgencyRepositoryImpl
// (Phase 19 / lib/features/agency/data/repositories/agency_repository_impl.dart).
//
// Per Constitution IX: this file MAY import [PostgrestException] for error-
// code mapping; it MUST NOT import any other supabase_flutter symbol.
//
// RPC error-code → Failure mapping:
//   42501  permission_denied  → PermissionDeniedFailure
//   23503  ad_not_found       → ValidationFailure('ad_not_found')
//   23514  ad_not_eligible    → ValidationFailure('ad_not_eligible')
//   23514  constraint/check   → ValidationFailure('constraint_violation')
//   23505  uniqueness          → ValidationFailure('uniqueness_violation')
//   Other  PostgrestException  → UnknownFailure
//   SocketException            → NetworkFailure
//   TimeoutException           → NetworkFailure

import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, StorageException;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/ad.dart';
import '../../domain/repositories/ads_admin_repository.dart';
import '../datasources/supabase_ads_admin_datasource.dart';

@LazySingleton(as: AdsAdminRepository)
class AdsAdminRepositoryImpl implements AdsAdminRepository {
  AdsAdminRepositoryImpl(this._datasource);

  final SupabaseAdsAdminDatasource _datasource;

  @override
  Future<Result<String>> uploadAdImage({
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final path = await _datasource.uploadAdImage(
        bytes: bytes,
        contentType: contentType,
      );
      return Success(path);
    } on StorageException catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'uploadAdImage failed: ${e.message}',
          cause: e,
          stackTrace: st,
        ),
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
        UnknownFailure('uploadAdImage failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<String>> createAd({
    required String title,
    required String imagePath,
    String? captionAr,
    String? captionEn,
    required String linkKind,
    required String linkValue,
    DateTime? startAt,
    DateTime? endAt,
    required bool isActive,
    required List<Map<String, dynamic>> placements,
  }) async {
    try {
      final id = await _datasource.createAd(
        title: title,
        imagePath: imagePath,
        captionAr: captionAr,
        captionEn: captionEn,
        linkKind: linkKind,
        linkValue: linkValue,
        startAt: startAt,
        endAt: endAt,
        isActive: isActive,
        placements: placements,
      );
      return Success(id);
    } on PostgrestException catch (e, st) {
      // Orphan cleanup: if the ad image was already uploaded and the RPC fails,
      // attempt to remove the orphaned storage object (best-effort).
      _tryDeleteOrphan(imagePath);
      return FailureResult(_mapRpcError(e, st, 'createAd'));
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
        UnknownFailure('createAd failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> updateAd({
    required String adId,
    required String title,
    required String imagePath,
    String? captionAr,
    String? captionEn,
    required String linkKind,
    required String linkValue,
    DateTime? startAt,
    DateTime? endAt,
    required bool isActive,
    required List<Map<String, dynamic>> placements,
  }) async {
    try {
      await _datasource.updateAd(
        adId: adId,
        title: title,
        imagePath: imagePath,
        captionAr: captionAr,
        captionEn: captionEn,
        linkKind: linkKind,
        linkValue: linkValue,
        startAt: startAt,
        endAt: endAt,
        isActive: isActive,
        placements: placements,
      );
      return const Success(null);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'updateAd'));
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
        UnknownFailure('updateAd failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> setAdActive({
    required String adId,
    required bool isActive,
  }) async {
    try {
      await _datasource.setAdActive(adId: adId, isActive: isActive);
      return const Success(null);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'setAdActive'));
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
        UnknownFailure('setAdActive failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> archiveAd(String adId) async {
    try {
      await _datasource.archiveAd(adId);
      return const Success(null);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'archiveAd'));
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
        UnknownFailure('archiveAd failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<Ad>>> loadAds({bool includeArchived = false}) async {
    try {
      final dtos = await _datasource.loadAds(includeArchived: includeArchived);
      return Success(dtos.map((d) => d.toEntity()).toList());
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'loadAds failed: ${e.message}',
          cause: e,
          stackTrace: st,
        ),
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
        UnknownFailure('loadAds failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Maps ads RPC error codes to typed [Failure] subtypes.
  Failure _mapRpcError(PostgrestException e, StackTrace st, String context) {
    final msg = e.message;
    final code = e.code ?? '';

    if (msg.contains('permission_denied') || code == '42501') {
      return const PermissionDeniedFailure();
    }
    if (msg.contains('ad_not_found') || code == '23503') {
      return const ValidationFailure('ad_not_found');
    }
    if (msg.contains('ad_not_eligible') || code == '23514') {
      return const ValidationFailure('ad_not_eligible');
    }
    if (code == '23514') {
      return const ValidationFailure('constraint_violation');
    }
    if (code == '23505') {
      return const ValidationFailure('uniqueness_violation');
    }
    return UnknownFailure(
      '$context failed: ${e.message}',
      cause: e,
      stackTrace: st,
    );
  }

  /// Best-effort orphan cleanup: delete an uploaded storage object when the
  /// subsequent RPC (createAd) fails. Swallows all errors — the primary
  /// failure is already propagated to the caller.
  void _tryDeleteOrphan(String path) {
    _datasource.deleteAdImage(path).ignore();
  }
}
