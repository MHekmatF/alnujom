// Phase 21 (spec/021-ads-banners) — T023
// AdsAdminCubit: drives the admin ads CRUD surface.
// States: loading / list / saving / error.
// Calls CreateAd / UpdateAd / SetAdActive / ArchiveAd / LoadAds / UploadAdImage
// from the PD domain layer via getIt. Mirrors AgencyModerationCubit shape.
// Constitution IX: zero supabase_flutter imports.
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../domain/entities/ad.dart';
import '../../../domain/usecases/archive_ad.dart';
import '../../../domain/usecases/create_ad.dart';
import '../../../domain/usecases/load_ads.dart';
import '../../../domain/usecases/set_ad_active.dart';
import '../../../domain/usecases/update_ad.dart';
import '../../../domain/usecases/upload_ad_image.dart';

// ─── States ──────────────────────────────────────────────────────────────────

sealed class AdsAdminState extends Equatable {
  const AdsAdminState();
  @override
  List<Object?> get props => const [];
}

/// Initial / loading state — waiting for the first LoadAds call to complete.
class AdsAdminLoading extends AdsAdminState {
  const AdsAdminLoading();
}

/// Ads list loaded successfully.
class AdsAdminList extends AdsAdminState {
  const AdsAdminList({required this.ads, this.includeArchived = false});
  final List<Ad> ads;
  final bool includeArchived;
  @override
  List<Object?> get props => [ads, includeArchived];
}

/// An async operation (create/update/activate/archive/upload) is in flight.
class AdsAdminSaving extends AdsAdminState {
  const AdsAdminSaving();
}

/// An operation completed successfully (create/update/activate/archive).
/// The cubit auto-reloads the list immediately after.
class AdsAdminSaveSuccess extends AdsAdminState {
  const AdsAdminSaveSuccess();
}

/// Image upload completed — returns the storage path for the caller to store.
class AdsAdminImageUploaded extends AdsAdminState {
  const AdsAdminImageUploaded(this.imagePath);
  final String imagePath;
  @override
  List<Object?> get props => [imagePath];
}

/// A domain or network failure.
class AdsAdminError extends AdsAdminState {
  const AdsAdminError(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

@injectable
class AdsAdminCubit extends Cubit<AdsAdminState> {
  AdsAdminCubit(
    this._loadAds,
    this._createAd,
    this._updateAd,
    this._setAdActive,
    this._archiveAd,
    this._uploadAdImage,
  ) : super(const AdsAdminLoading());

  final LoadAds _loadAds;
  final CreateAd _createAd;
  final UpdateAd _updateAd;
  final SetAdActive _setAdActive;
  final ArchiveAd _archiveAd;
  final UploadAdImage _uploadAdImage;

  // ── Load ─────────────────────────────────────────────────────────────────

  /// Loads all ads. Pass [includeArchived] = true to show soft-deleted ads.
  Future<void> loadAds({bool includeArchived = false}) async {
    emit(const AdsAdminLoading());
    final result = await _loadAds(includeArchived: includeArchived);
    _emitListResult(result, includeArchived: includeArchived);
  }

  // ── Create ───────────────────────────────────────────────────────────────

  /// Creates a new ad then reloads the list.
  Future<void> createAd({
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
    emit(const AdsAdminSaving());
    final result = await _createAd(
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
    switch (result) {
      case Success():
        emit(const AdsAdminSaveSuccess());
        await loadAds();
      case FailureResult(:final failure):
        emit(AdsAdminError(failure));
    }
  }

  // ── Update ───────────────────────────────────────────────────────────────

  /// Updates an existing ad then reloads the list.
  Future<void> updateAd({
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
    emit(const AdsAdminSaving());
    final result = await _updateAd(
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
    switch (result) {
      case Success():
        emit(const AdsAdminSaveSuccess());
        await loadAds();
      case FailureResult(:final failure):
        emit(AdsAdminError(failure));
    }
  }

  // ── Activate / Deactivate ────────────────────────────────────────────────

  /// Toggles [isActive] for a single ad, then reloads the list.
  Future<void> setAdActive(String adId, {required bool isActive}) async {
    emit(const AdsAdminSaving());
    final result = await _setAdActive(adId: adId, isActive: isActive);
    switch (result) {
      case Success():
        emit(const AdsAdminSaveSuccess());
        await loadAds();
      case FailureResult(:final failure):
        emit(AdsAdminError(failure));
    }
  }

  // ── Archive ──────────────────────────────────────────────────────────────

  /// Soft-deletes the ad (sets archived_at), then reloads the list.
  Future<void> archiveAd(String adId) async {
    emit(const AdsAdminSaving());
    final result = await _archiveAd(adId);
    switch (result) {
      case Success():
        emit(const AdsAdminSaveSuccess());
        await loadAds();
      case FailureResult(:final failure):
        emit(AdsAdminError(failure));
    }
  }

  // ── Image upload ─────────────────────────────────────────────────────────

  /// Uploads [bytes] to the `ads` bucket and emits [AdsAdminImageUploaded]
  /// with the returned storage path. The caller passes that path to
  /// [createAd] / [updateAd].
  Future<void> uploadImage({
    required Uint8List bytes,
    required String contentType,
  }) async {
    emit(const AdsAdminSaving());
    final result = await _uploadAdImage(bytes: bytes, contentType: contentType);
    switch (result) {
      case Success(:final value):
        emit(AdsAdminImageUploaded(value));
      case FailureResult(:final failure):
        emit(AdsAdminError(failure));
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _emitListResult(
    Result<List<Ad>> result, {
    required bool includeArchived,
  }) {
    switch (result) {
      case Success(:final value):
        emit(AdsAdminList(ads: value, includeArchived: includeArchived));
      case FailureResult(:final failure):
        emit(AdsAdminError(failure));
    }
  }
}
