import 'package:equatable/equatable.dart';

import 'listing.dart';
import 'listing_details.dart';
import 'listing_media.dart';
import 'listing_price.dart';
import 'listing_visibility.dart';
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
  ];
}

const Object _sentinel = Object();
