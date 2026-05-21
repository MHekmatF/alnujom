import 'package:equatable/equatable.dart';

import 'listing.dart';
import 'listing_details.dart';
import 'listing_price.dart';
import 'listing_visibility.dart';
import 'submit_failure.dart';

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
  ];
}

const Object _sentinel = Object();
