import 'package:decimal/decimal.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_details.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/listing_price.dart';
import '../../domain/entities/listing_visibility.dart';
import '../../domain/entities/submit_failure.dart';
import '../../domain/repositories/listings_repository.dart';
import '../../domain/usecases/delete_draft.dart';
import '../../domain/usecases/derive_area_centroid.dart';
import '../../domain/usecases/load_or_create_draft.dart';
import '../../domain/usecases/save_form_step.dart';
import '../../domain/usecases/submit_listing.dart';
import '../../domain/usecases/validate_submit_payload.dart';
import 'listing_form_event.dart';

@injectable
class ListingFormBloc extends Bloc<ListingFormEvent, ListingFormState> {
  ListingFormBloc(
    this._loadOrCreateDraft,
    this._saveFormStep,
    this._submitListing,
    this._deleteDraft,
    this._deriveAreaCentroid,
    this._validateSubmitPayload,
    this._repository,
  ) : super(
        const ListingFormState(
          mode: ListingFormMode.create,
          currentStep: ListingFormStep.basics,
        ),
      ) {
    on<LoadOrCreateDraftRequested>(_onLoadOrCreateDraftRequested);
    on<FieldChanged>(_onFieldChanged);
    on<AreaCentroidResolved>(_onAreaCentroidResolved);
    on<AreaCentroidLookupFailed>(_onAreaCentroidLookupFailed);
    on<SaveStepAndContinue>(_onSaveStepAndContinue);
    on<SaveStepAndExit>(_onSaveStepAndExit);
    on<JumpToStep>(_onJumpToStep);
    on<SubmitRequested>(_onSubmitRequested);
    on<DeleteDraftRequested>(_onDeleteDraftRequested);
  }

  final LoadOrCreateDraft _loadOrCreateDraft;
  final SaveFormStep _saveFormStep;
  final SubmitListing _submitListing;
  final DeleteDraft _deleteDraft;
  final DeriveAreaCentroid _deriveAreaCentroid;
  final ValidateSubmitPayload _validateSubmitPayload;
  final ListingsRepository _repository;

  /// Set by the caller via `attachContext` before dispatching
  /// `LoadOrCreateDraftRequested`. Holds the signed-in publisher's
  /// `auth.uid()` value so this bloc doesn't need to depend on AuthBloc.
  String? _publisherUserId;
  ListingFormMode _mode = ListingFormMode.create;

  void attachContext({
    required String publisherUserId,
    required ListingFormMode mode,
  }) {
    _publisherUserId = publisherUserId;
    _mode = mode;
  }

  Future<void> _onLoadOrCreateDraftRequested(
    LoadOrCreateDraftRequested event,
    Emitter<ListingFormState> emit,
  ) async {
    final publisherUserId = _publisherUserId;
    if (publisherUserId == null) {
      emit(
        state.copyWith(
          lastSaveError: 'publisherUserId not attached',
          loadInProgress: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(mode: _mode, loadInProgress: true, lastSaveError: null),
    );
    try {
      // Edit mode (Resubmit CTA from MyListingsPage, or deep-link to a
      // specific draft/rejected listing): load by id + child rows. Otherwise
      // fall back to LoadOrCreateDraft which finds the publisher's most-
      // recent draft or inserts a new blank.
      if (event.listingId != null) {
        final listing = await _repository.loadListing(event.listingId!);
        if (listing == null) {
          emit(
            state.copyWith(
              loadInProgress: false,
              lastSaveError: 'Listing not found or not accessible',
            ),
          );
          return;
        }
        final details = await _repository.loadDetails(listing.id);
        final price = await _repository.loadPrimaryPrice(listing.id);
        emit(
          state.copyWith(
            draftListing: listing,
            draftDetails: details,
            draftPrice: price,
            loadInProgress: false,
          ),
        );
      } else {
        final listing = await _loadOrCreateDraft(publisherUserId);
        emit(state.copyWith(draftListing: listing, loadInProgress: false));
      }
    } catch (e) {
      emit(state.copyWith(loadInProgress: false, lastSaveError: e.toString()));
    }
  }

  Future<void> _onFieldChanged(
    FieldChanged event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null) return;
    Listing nextListing = listing;
    ListingDetails? nextDetails = state.draftDetails;
    ListingPrice? nextPrice = state.draftPrice;
    ListingVisibilityEntity? nextVisibility = state.draftVisibility;

    switch (event.field) {
      case ListingFormField.title:
        nextListing = listing.copyWith(title: event.value as String? ?? '');
      case ListingFormField.purpose:
        nextListing = listing.copyWith(purpose: event.value as ListingPurpose);
      case ListingFormField.propertyType:
        nextListing = listing.copyWith(
          propertyType: event.value as PropertyType,
        );
      case ListingFormField.governorateId:
        nextListing = listing.copyWith(governorateId: event.value as String?);
      case ListingFormField.cityId:
        nextListing = listing.copyWith(cityId: event.value as String?);
      case ListingFormField.areaId:
        nextListing = listing.copyWith(areaId: event.value as String?);
      case ListingFormField.addressText:
        nextListing = listing.copyWith(addressText: event.value as String?);
      case ListingFormField.areaSize:
        nextListing = listing.copyWith(areaSize: event.value as double?);
      case ListingFormField.rooms:
        nextListing = listing.copyWith(rooms: event.value as int?);
      case ListingFormField.bathrooms:
        nextListing = listing.copyWith(bathrooms: event.value as int?);
      case ListingFormField.floor:
        nextListing = listing.copyWith(floor: event.value as int?);
      case ListingFormField.description:
        nextDetails = _ensureDetails(
          nextDetails,
          listing.id,
        ).copyWith(description: event.value as String?);
      case ListingFormField.amenities:
        nextDetails = _ensureDetails(nextDetails, listing.id).copyWith(
          amenities: (event.value as List<String>?) ?? const <String>[],
        );
      case ListingFormField.yearBuilt:
        nextDetails = _ensureDetails(
          nextDetails,
          listing.id,
        ).copyWith(yearBuilt: event.value as int?);
      case ListingFormField.furnished:
        nextDetails = _ensureDetails(
          nextDetails,
          listing.id,
        ).copyWith(furnished: event.value as bool?);
      case ListingFormField.parking:
        nextDetails = _ensureDetails(
          nextDetails,
          listing.id,
        ).copyWith(parking: event.value as bool?);
      case ListingFormField.priceCurrencyCode:
        final code = event.value as String?;
        if (code == null || code.isEmpty) {
          nextPrice = null;
        } else {
          nextPrice = ListingPrice(
            id: nextPrice?.id ?? '',
            listingId: listing.id,
            currencyCode: code,
            amount: nextPrice?.amount ?? Decimal.zero,
            isPrimary: true,
            createdAt: nextPrice?.createdAt ?? DateTime.now(),
          );
        }
      case ListingFormField.priceAmount:
        if (nextPrice == null) {
          // Amount change without a chosen currency yet — ignore until
          // currency is picked.
          break;
        }
        nextPrice = nextPrice.copyWith(amount: event.value as Decimal);
      case ListingFormField.locationVisibility:
        nextListing = listing.copyWith(
          locationVisibility: event.value as LocationVisibility,
        );
      case ListingFormField.contactNameVisibility:
        nextListing = listing.copyWith(
          contactNameVisibility: event.value as ContactNameVisibility,
        );
      case ListingFormField.phone:
        nextListing = listing.copyWith(phone: event.value as String?);
      case ListingFormField.whatsapp:
        nextListing = listing.copyWith(whatsapp: event.value as String?);
      case ListingFormField.hideUntil:
        final hideUntil = event.value as DateTime?;
        nextVisibility = ListingVisibilityEntity(
          listingId: listing.id,
          locationVisibility: listing.locationVisibility,
          contactVisibility: listing.contactNameVisibility,
          hideUntil: hideUntil,
          lastUpdatedBy: nextVisibility?.lastUpdatedBy,
          updatedAt: DateTime.now(),
        );
    }

    emit(
      state.copyWith(
        draftListing: nextListing,
        draftDetails: nextDetails,
        draftPrice: nextPrice,
        draftVisibility: nextVisibility,
        lastSubmitFailure: null,
      ),
    );

    // After an area pick on the location step, kick off the centroid lookup.
    if (event.field == ListingFormField.areaId &&
        event.value is String &&
        (event.value as String).isNotEmpty) {
      try {
        final centroid = await _deriveAreaCentroid(event.value as String);
        add(
          AreaCentroidResolved(
            latitude: centroid.latitude,
            longitude: centroid.longitude,
          ),
        );
      } catch (_) {
        add(const AreaCentroidLookupFailed());
      }
    }
  }

  void _onAreaCentroidResolved(
    AreaCentroidResolved event,
    Emitter<ListingFormState> emit,
  ) {
    final listing = state.draftListing;
    if (listing == null) return;
    emit(
      state.copyWith(
        draftListing: listing.copyWith(
          latitude: event.latitude,
          longitude: event.longitude,
        ),
        stepValidationErrors: <String, String?>{
          ...state.stepValidationErrors,
          'location.centroid': null,
        },
      ),
    );
  }

  void _onAreaCentroidLookupFailed(
    AreaCentroidLookupFailed event,
    Emitter<ListingFormState> emit,
  ) {
    emit(
      state.copyWith(
        stepValidationErrors: <String, String?>{
          ...state.stepValidationErrors,
          'location.centroid': 'centroid_missing',
        },
      ),
    );
  }

  Future<void> _onSaveStepAndContinue(
    SaveStepAndContinue event,
    Emitter<ListingFormState> emit,
  ) async {
    if (state.saveInProgress) return;
    emit(state.copyWith(saveInProgress: true, lastSaveError: null));
    try {
      await _saveFormStep(state, state.currentStep);
      final next = state.currentStep.next ?? state.currentStep;
      emit(state.copyWith(saveInProgress: false, currentStep: next));
    } catch (e) {
      emit(state.copyWith(saveInProgress: false, lastSaveError: e.toString()));
    }
  }

  Future<void> _onSaveStepAndExit(
    SaveStepAndExit event,
    Emitter<ListingFormState> emit,
  ) async {
    if (state.saveInProgress) return;
    emit(state.copyWith(saveInProgress: true, lastSaveError: null));
    try {
      await _saveFormStep(state, state.currentStep);
      emit(state.copyWith(saveInProgress: false, savedAndExited: true));
    } catch (e) {
      emit(state.copyWith(saveInProgress: false, lastSaveError: e.toString()));
    }
  }

  void _onJumpToStep(JumpToStep event, Emitter<ListingFormState> emit) {
    emit(state.copyWith(currentStep: event.step));
  }

  Future<void> _onSubmitRequested(
    SubmitRequested event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null || state.submitInProgress) return;
    final validation = _validateSubmitPayload(state);
    if (!validation.ok) {
      emit(
        state.copyWith(
          lastSubmitFailure: SubmitFailure(
            missingFields: validation.missingFields,
            rawSqlState: null,
            userFacingMessage: null,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        submitInProgress: true,
        lastSubmitFailure: null,
        submitSucceeded: false,
      ),
    );
    try {
      final result = await _submitListing(listing.id);
      emit(
        state.copyWith(
          submitInProgress: false,
          draftListing: listing.copyWith(status: result.status),
          submitSucceeded: true,
        ),
      );
    } on SubmitListingFailureException catch (e) {
      emit(
        state.copyWith(
          submitInProgress: false,
          lastSubmitFailure: SubmitFailure(
            missingFields: e.missingFields,
            rawSqlState: e.sqlState,
            userFacingMessage: e.message,
          ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          submitInProgress: false,
          lastSubmitFailure: SubmitFailure(
            missingFields: const <String>[],
            rawSqlState: null,
            userFacingMessage: e.toString(),
          ),
        ),
      );
    }
  }

  Future<void> _onDeleteDraftRequested(
    DeleteDraftRequested event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null) return;
    try {
      await _deleteDraft(listing.id);
      emit(
        const ListingFormState(
          mode: ListingFormMode.create,
          currentStep: ListingFormStep.basics,
        ),
      );
    } catch (e) {
      emit(state.copyWith(lastSaveError: e.toString()));
    }
  }

  static ListingDetails _ensureDetails(
    ListingDetails? existing,
    String listingId,
  ) {
    if (existing != null) return existing;
    final now = DateTime.now();
    return ListingDetails(
      listingId: listingId,
      amenities: const <String>[],
      createdAt: now,
      updatedAt: now,
    );
  }
}
