import 'package:equatable/equatable.dart';

import '../../../agency/domain/entities/agency.dart';
import 'listing.dart';
import 'listing_details.dart';
import 'listing_media.dart';
import 'listing_price.dart';
import 'listing_visibility.dart';
import 'revision_manifest_item.dart';
import 'submit_failure.dart';

/// Phase 11 — per-thumbnail upload progress state surfaced on the picker grid.
///
/// Sealed type with five variants covering the FR-014 pipeline + upload
/// lifecycle: idle → processing → uploading → completed (or error).
sealed class MediaUploadProgress {
  const MediaUploadProgress();
}

class MediaUploadProgressIdle extends MediaUploadProgress {
  const MediaUploadProgressIdle();
}

class MediaUploadProgressProcessing extends MediaUploadProgress {
  const MediaUploadProgressProcessing();
}

/// Phase 030 (W1) — a picked video is being transcoded to 720p before upload.
///
/// [percent] is the 0..100 progress emitted by the `video_compress` plugin, or
/// null before the first tick (rendered as an indeterminate spinner until the
/// first progress event arrives). Surfaced on the picker ghost tile with a
/// "compressing" label so the publisher knows the wait is the transcode, not a
/// stalled upload.
class MediaUploadProgressCompressing extends MediaUploadProgress {
  const MediaUploadProgressCompressing([this.percent]);

  final double? percent;
}

class MediaUploadProgressUploading extends MediaUploadProgress {
  const MediaUploadProgressUploading();
}

class MediaUploadProgressError extends MediaUploadProgress {
  const MediaUploadProgressError(this.errorKey);

  /// ARB key (e.g. `media.error.uploadFailed`) — resolved at render time.
  final String errorKey;
}

class MediaUploadProgressCompleted extends MediaUploadProgress {
  const MediaUploadProgressCompleted();
}

/// Seven-step form progression per `contracts/listing-form-pages.md`.
enum ListingFormStep {
  basics,
  location,
  details,
  prices,
  visibility,
  media,
  review,
}

extension ListingFormStepIndex on ListingFormStep {
  int get index0 => ListingFormStep.values.indexOf(this);

  ListingFormStep? get next {
    final i = index0 + 1;
    return i < ListingFormStep.values.length ? ListingFormStep.values[i] : null;
  }

  ListingFormStep? get previous {
    final i = index0 - 1;
    return i >= 0 ? ListingFormStep.values[i] : null;
  }
}

/// Listing-form mode passed from the router to ListingFormPage.
/// Absorbed from the T038 stub at T055.
enum ListingFormMode { create, edit }

class ListingFormState extends Equatable {
  const ListingFormState({
    required this.mode,
    required this.currentStep,
    this.draftListing,
    this.draftDetails,
    this.draftPrice,
    this.draftVisibility,
    this.stepValidationErrors = const <String, String?>{},
    this.loadInProgress = false,
    this.saveInProgress = false,
    this.submitInProgress = false,
    this.lastSubmitFailure,
    this.lastSaveError,
    this.submitSucceeded = false,
    this.savedAndExited = false,
    this.media = const <ListingMedia>[],
    this.uploadInFlight = const <String, MediaUploadProgress>{},
    this.availableAgencies = const <Agency>[],
    this.isRevision = false,
    this.revisionId,
    this.revisionManifest = const <RevisionManifestItem>[],
  });

  final ListingFormMode mode;
  final ListingFormStep currentStep;
  final Listing? draftListing;
  final ListingDetails? draftDetails;
  final ListingPrice? draftPrice;
  final ListingVisibilityEntity? draftVisibility;
  final Map<String, String?> stepValidationErrors;
  final bool loadInProgress;
  final bool saveInProgress;
  final bool submitInProgress;
  final SubmitFailure? lastSubmitFailure;
  final String? lastSaveError;
  final bool submitSucceeded;
  final bool savedAndExited;

  /// Phase 11 — committed `listing_media` rows for the current draft (R-40).
  final List<ListingMedia> media;

  /// Phase 11 — keyed by an opaque transient localId per upload attempt
  /// (NOT the `listing_media.id`, which only exists after the row INSERT
  /// commits). Surfaces processing / uploading / error states on the
  /// picker grid before the row lands in [media].
  final Map<String, MediaUploadProgress> uploadInFlight;

  /// Phase 19 (T062) — the user's active agencies whose status permits
  /// publishing under them ({pending, approved}); empty when the user belongs
  /// to no eligible agency (the publish-under-agency selector hides itself).
  final List<Agency> availableAgencies;

  /// Phase 031 (WS-B) — true when this EDIT session is a stay-live REVISION of
  /// an APPROVED listing. All field/media edits are STAGED onto the revision
  /// ([revisionId]) and the live listing is left untouched until an admin
  /// applies it. Draft/rejected edits leave this false (today's in-place flow).
  final bool isRevision;

  /// The open `listing_revisions.id` this session edits (only when [isRevision]).
  final String? revisionId;

  /// Phase 031 (WS-B) — the staged media manifest for the revision. In revision
  /// mode this is the source of truth for media; [media] is derived from it for
  /// the picker. Empty/ignored outside revision mode.
  final List<RevisionManifestItem> revisionManifest;

  bool get isReady => draftListing != null && !loadInProgress;

  ListingFormState copyWith({
    ListingFormMode? mode,
    ListingFormStep? currentStep,
    Listing? draftListing,
    Object? draftDetails = _sentinel,
    Object? draftPrice = _sentinel,
    Object? draftVisibility = _sentinel,
    Map<String, String?>? stepValidationErrors,
    bool? loadInProgress,
    bool? saveInProgress,
    bool? submitInProgress,
    Object? lastSubmitFailure = _sentinel,
    Object? lastSaveError = _sentinel,
    bool? submitSucceeded,
    bool? savedAndExited,
    List<ListingMedia>? media,
    Map<String, MediaUploadProgress>? uploadInFlight,
    List<Agency>? availableAgencies,
    bool? isRevision,
    Object? revisionId = _sentinel,
    List<RevisionManifestItem>? revisionManifest,
  }) {
    return ListingFormState(
      mode: mode ?? this.mode,
      currentStep: currentStep ?? this.currentStep,
      draftListing: draftListing ?? this.draftListing,
      draftDetails: identical(draftDetails, _sentinel)
          ? this.draftDetails
          : draftDetails as ListingDetails?,
      draftPrice: identical(draftPrice, _sentinel)
          ? this.draftPrice
          : draftPrice as ListingPrice?,
      draftVisibility: identical(draftVisibility, _sentinel)
          ? this.draftVisibility
          : draftVisibility as ListingVisibilityEntity?,
      stepValidationErrors: stepValidationErrors ?? this.stepValidationErrors,
      loadInProgress: loadInProgress ?? this.loadInProgress,
      saveInProgress: saveInProgress ?? this.saveInProgress,
      submitInProgress: submitInProgress ?? this.submitInProgress,
      lastSubmitFailure: identical(lastSubmitFailure, _sentinel)
          ? this.lastSubmitFailure
          : lastSubmitFailure as SubmitFailure?,
      lastSaveError: identical(lastSaveError, _sentinel)
          ? this.lastSaveError
          : lastSaveError as String?,
      submitSucceeded: submitSucceeded ?? this.submitSucceeded,
      savedAndExited: savedAndExited ?? this.savedAndExited,
      media: media ?? this.media,
      uploadInFlight: uploadInFlight ?? this.uploadInFlight,
      availableAgencies: availableAgencies ?? this.availableAgencies,
      isRevision: isRevision ?? this.isRevision,
      revisionId: identical(revisionId, _sentinel)
          ? this.revisionId
          : revisionId as String?,
      revisionManifest: revisionManifest ?? this.revisionManifest,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    currentStep,
    draftListing,
    draftDetails,
    draftPrice,
    draftVisibility,
    stepValidationErrors,
    loadInProgress,
    saveInProgress,
    submitInProgress,
    lastSubmitFailure,
    lastSaveError,
    submitSucceeded,
    savedAndExited,
    media,
    uploadInFlight,
    availableAgencies,
    isRevision,
    revisionId,
    revisionManifest,
  ];
}

const Object _sentinel = Object();
