import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/errors/result.dart';
import '../../../../core/validators/video_file_validator.dart';
import '../../../agency/domain/entities/agency.dart';
import '../../../agency/domain/usecases/load_my_active_agencies.dart';
import '../../data/datasources/supabase_listing_media_datasource.dart'
    show MediaDeleteException;
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_details.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/listing_media.dart';
import '../../domain/entities/listing_price.dart';
import '../../domain/entities/listing_visibility.dart';
import '../../domain/entities/submit_failure.dart';
import '../../domain/repositories/listings_repository.dart';
import '../../domain/usecases/delete_draft.dart';
import '../../domain/usecases/delete_media.dart';
import '../../domain/usecases/derive_area_centroid.dart';
import '../../domain/usecases/load_media_for_listing.dart';
import '../../domain/usecases/load_or_create_draft.dart';
import '../../domain/usecases/reorder_media.dart';
import '../../domain/usecases/save_form_step.dart';
import '../../domain/usecases/set_main_image.dart';
import '../../domain/usecases/submit_listing.dart';
import '../../domain/usecases/upload_image.dart';
import '../../domain/usecases/upload_video.dart';
import '../../domain/usecases/validate_submit_payload.dart';
import '../util/image_isolate_worker.dart';
import '../util/watermark_pipeline.dart';
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
    this._uploadImage,
    this._uploadVideo,
    this._reorderMedia,
    this._setMainImage,
    this._deleteMedia,
    this._loadMediaForListing,
    this._loadMyActiveAgencies,
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
    // Phase 11 — five new MediaPicker handlers (R-40).
    on<MediaPicked>(_onMediaPicked);
    on<VideoPicked>(_onVideoPicked);
    on<MediaReordered>(_onMediaReordered);
    on<MediaSetMain>(_onMediaSetMain);
    on<MediaDeleted>(_onMediaDeleted);
    on<MediaUploadDismissed>(_onMediaUploadDismissed);
  }

  final LoadOrCreateDraft _loadOrCreateDraft;
  final SaveFormStep _saveFormStep;
  final SubmitListing _submitListing;
  final DeleteDraft _deleteDraft;
  final DeriveAreaCentroid _deriveAreaCentroid;
  final ValidateSubmitPayload _validateSubmitPayload;
  final ListingsRepository _repository;
  final UploadImage _uploadImage;
  final UploadVideo _uploadVideo;
  final ReorderMedia _reorderMedia;
  final SetMainImage _setMainImage;
  final DeleteMedia _deleteMedia;
  final LoadMediaForListing _loadMediaForListing;
  final LoadMyActiveAgencies _loadMyActiveAgencies;

  // Phase 11 — lazily-instantiated isolate worker per R-25 (one per BLoC
  // lifecycle, processes images sequentially).
  ImageIsolateWorker? _imageWorker;
  Uint8List? _watermarkAssetBytes;

  static const String _watermarkAssetPath =
      'assets/images/watermark/logo_watermark.png';

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

    // Phase 19 (T062) — load the user's active agencies eligible to publish
    // under (status ∈ {pending, approved}). Best-effort: on failure the
    // selector simply hides itself. Does not block draft loading.
    final agencies = await _loadEligibleAgencies();

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
        // Phase 11 — populate `state.media` from listing_media rows so the
        // Q3=A edit-in-place picker surfaces existing thumbnails on resubmit.
        List<ListingMedia> media = const <ListingMedia>[];
        try {
          media = await _loadMediaForListing(listingId: listing.id);
        } catch (_) {
          media = const <ListingMedia>[];
        }
        emit(
          state.copyWith(
            draftListing: listing,
            draftDetails: details,
            draftPrice: price,
            loadInProgress: false,
            media: media,
            uploadInFlight: const <String, MediaUploadProgress>{},
            availableAgencies: agencies,
          ),
        );
      } else {
        final listing = await _loadOrCreateDraft(publisherUserId);
        // Fresh-create path — also load any existing media (empty for new
        // drafts; non-empty when LoadOrCreateDraft returned an existing draft).
        List<ListingMedia> media = const <ListingMedia>[];
        try {
          media = await _loadMediaForListing(listingId: listing.id);
        } catch (_) {
          media = const <ListingMedia>[];
        }
        emit(
          state.copyWith(
            draftListing: listing,
            loadInProgress: false,
            media: media,
            uploadInFlight: const <String, MediaUploadProgress>{},
            availableAgencies: agencies,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(loadInProgress: false, lastSaveError: e.toString()));
    }
  }

  /// Loads the current user's active agencies that permit publishing under
  /// them. Best-effort: returns an empty list on any failure.
  Future<List<Agency>> _loadEligibleAgencies() async {
    final result = await _loadMyActiveAgencies();
    if (result is Success<List<Agency>>) {
      return result.value
          .where((a) => a.status.canPublishUnder)
          .toList();
    }
    return const <Agency>[];
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
      case ListingFormField.agencyId:
        // Phase 19 (T062) — carry the chosen agency (or null = personal) into
        // the draft. The copyWith sentinel lets a null explicitly clear it.
        nextListing = listing.copyWith(agencyId: event.value as String?);
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

  // ---------------------------------------------------------------------------
  // Phase 11 — MediaPicker handlers (R-40) + isolate-worker lifecycle.
  // ---------------------------------------------------------------------------

  /// Lazily spawns the R-25 shared sequential isolate worker on the first
  /// `MediaPicked` event and lazily loads the watermark PNG bytes from
  /// rootBundle. Caller is responsible for `isRtl` resolution (the widget
  /// reads `Directionality.of(context)` and folds it into the event payload).
  Future<void> _ensureImageWorker() async {
    if (_imageWorker == null) {
      final worker = ImageIsolateWorker();
      await worker.start();
      _imageWorker = worker;
    }
    if (_watermarkAssetBytes == null) {
      final data = await rootBundle.load(_watermarkAssetPath);
      _watermarkAssetBytes = data.buffer.asUint8List();
    }
  }

  /// Central error mapper — every PostgrestException, isolate exception, and
  /// timeout surfaces here. Returns the ARB key to render at the widget layer.
  /// Per R-30, parses the cap-trigger DETAIL JSONB to distinguish image-cap
  /// vs video-cap errors. Handles both Map and String shapes for `details`
  /// (depends on supabase_flutter version).
  String _mapMediaErrorToArbKey(Object error) {
    if (error is UnsupportedFormatException) {
      return 'media.error.formatNotSupported';
    }
    if (error is ImageTooLargeException) return 'media.error.imageTooLarge';
    if (error is WatermarkAssetMissingException) {
      return 'media.error.watermarkAssetMissing';
    }
    if (error is TimeoutException) return 'media.error.timeout';
    if (error is MediaDeleteException) return 'media.error.uploadFailed';

    if (error is PostgrestException) {
      if (error.message == 'listing_media.cap_exceeded') {
        try {
          final detail = error.details;
          Map<String, dynamic>? detailMap;
          if (detail is String) {
            detailMap = jsonDecode(detail) as Map<String, dynamic>;
          } else if (detail is Map) {
            detailMap = Map<String, dynamic>.from(detail);
          }
          final kind = detailMap?['kind'] as String?;
          if (kind == 'image') return 'media.cap.images10';
          if (kind == 'video') return 'media.cap.videos2';
        } catch (_) {
          // Fall through to generic upload-failed if DETAIL is unparseable.
        }
        return 'media.error.uploadFailed';
      }
      return 'media.error.uploadFailed';
    }
    return 'media.error.uploadFailed';
  }

  /// Returns the next available ordering slot (1-indexed; max(existing)+1).
  // Note: ordering computation moved server-side via the
  // listing_media_assign_ordering BEFORE INSERT trigger (task #29 fix).
  // The client now always sends ordering=0 and reads the assigned value
  // from the INSERT's RETURNING row.

  Future<void> _onMediaPicked(
    MediaPicked event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null) return;
    final listingId = listing.id;
    if (event.files.isEmpty) return;

    try {
      await _ensureImageWorker();
    } catch (e) {
      // Bundle load failed (watermark asset missing). Surface fail-closed
      // error per FR-014 — refuse to upload an un-watermarked image.
      final localId = _newLocalId();
      emit(
        state.copyWith(
          uploadInFlight: <String, MediaUploadProgress>{
            ...state.uploadInFlight,
            localId: const MediaUploadProgressError(
              'media.error.watermarkAssetMissing',
            ),
          },
        ),
      );
      return;
    }

    for (final file in event.files) {
      final localId = _newLocalId();
      emit(
        state.copyWith(
          uploadInFlight: <String, MediaUploadProgress>{
            ...state.uploadInFlight,
            localId: const MediaUploadProgressProcessing(),
          },
        ),
      );

      try {
        // FR-014 pipeline + upload + INSERT, all wrapped in the Q7=B / R-39
        // 60-second budget. Earlier the timeout wrapped ONLY processImage —
        // discovered during T088 walk that uploads on slow networks could
        // exceed the budget without firing the timeout.
        final inserted = await () async {
          final sourceBytes = await file.readAsBytes();
          final watermarkedJpeg = await _imageWorker!.processImage(
            sourceBytes: sourceBytes,
            watermarkAssetBytes: _watermarkAssetBytes!,
            isRtl: event.isRtl,
          );

          // Mark uploading on the picker (between watermark and bucket commit).
          emit(
            state.copyWith(
              uploadInFlight: <String, MediaUploadProgress>{
                ...state.uploadInFlight,
                localId: const MediaUploadProgressUploading(),
              },
            ),
          );

          // First image auto-main per spec US1 / FR-013 (the partial unique
          // index enforces at-most-one main server-side).
          final hasImage = state.media.any(
            (m) => m.kind == ListingMediaKind.image,
          );
          final isMain = !hasImage;

          return await _uploadImage(
            listingId: listingId,
            watermarkedBytes: watermarkedJpeg,
            ordering: 0, // sentinel — trigger assigns per task #29 fix
            isMain: isMain,
          );
        }().timeout(const Duration(seconds: 60));

        final nextInFlight = <String, MediaUploadProgress>{
          ...state.uploadInFlight,
        }..remove(localId);
        emit(
          state.copyWith(
            media: <ListingMedia>[...state.media, inserted],
            uploadInFlight: nextInFlight,
          ),
        );
      } catch (e) {
        final errorKey = _mapMediaErrorToArbKey(e);
        emit(
          state.copyWith(
            uploadInFlight: <String, MediaUploadProgress>{
              ...state.uploadInFlight,
              localId: MediaUploadProgressError(errorKey),
            },
          ),
        );
        // Continue the batch — one failure does not abort sibling images.
      }
    }
  }

  Future<void> _onVideoPicked(
    VideoPicked event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null) return;
    final listingId = listing.id;

    final sizeBytes = await event.file.length();
    final localId = _newLocalId();
    final validationError = VideoFileValidator.validate(
      event.file,
      sizeBytes: sizeBytes,
    );
    if (validationError != null) {
      emit(
        state.copyWith(
          uploadInFlight: <String, MediaUploadProgress>{
            ...state.uploadInFlight,
            localId: MediaUploadProgressError(validationError),
          },
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        uploadInFlight: <String, MediaUploadProgress>{
          ...state.uploadInFlight,
          localId: const MediaUploadProgressUploading(),
        },
      ),
    );

    try {
      final inserted = await _uploadVideo(
        listingId: listingId,
        filePath: event.file.path,
        ordering: 0, // sentinel — trigger assigns per task #29 fix
      ).timeout(const Duration(seconds: 60));
      final nextInFlight = <String, MediaUploadProgress>{
        ...state.uploadInFlight,
      }..remove(localId);
      emit(
        state.copyWith(
          media: <ListingMedia>[...state.media, inserted],
          uploadInFlight: nextInFlight,
        ),
      );
    } catch (e) {
      final errorKey = _mapMediaErrorToArbKey(e);
      emit(
        state.copyWith(
          uploadInFlight: <String, MediaUploadProgress>{
            ...state.uploadInFlight,
            localId: MediaUploadProgressError(errorKey),
          },
        ),
      );
    }
  }

  Future<void> _onMediaReordered(
    MediaReordered event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null) return;

    // Optimistic update — reorder state.media locally first so the picker
    // grid reflects the new order instantly. The RPC call happens in
    // background; on failure we reload from the server to undo.
    final idToMedia = <String, ListingMedia>{
      for (final m in state.media) m.id: m,
    };
    final reordered = <ListingMedia>[];
    for (var i = 0; i < event.newOrder.length; i++) {
      final m = idToMedia[event.newOrder[i]];
      if (m != null) reordered.add(m.copyWith(ordering: i + 1));
    }
    // Append any media not present in event.newOrder (e.g., videos when
    // only images were reordered) to preserve them.
    for (final m in state.media) {
      if (!event.newOrder.contains(m.id)) reordered.add(m);
    }
    emit(state.copyWith(media: reordered));

    try {
      await _reorderMedia(listingId: listing.id, newOrderIds: event.newOrder);
    } catch (_) {
      // RPC failed — reload from the server to revert the optimistic UI.
      try {
        final reloaded = await _loadMediaForListing(listingId: listing.id);
        emit(state.copyWith(media: reloaded));
      } catch (_) {
        /* nothing more to do */
      }
    }
  }

  Future<void> _onMediaSetMain(
    MediaSetMain event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null) return;
    try {
      await _setMainImage(listingId: listing.id, mediaId: event.mediaId);
      final reloaded = await _loadMediaForListing(listingId: listing.id);
      emit(state.copyWith(media: reloaded));
    } catch (_) {
      // No-op on failure — widget can re-trigger.
    }
  }

  Future<void> _onMediaDeleted(
    MediaDeleted event,
    Emitter<ListingFormState> emit,
  ) async {
    try {
      await _deleteMedia(mediaId: event.mediaId);
      emit(
        state.copyWith(
          media: state.media.where((m) => m.id != event.mediaId).toList(),
        ),
      );
    } catch (_) {
      // Reload from server to reflect the actual state per R-38 semantics
      // (storage gone but row remains, or vice versa).
      final listing = state.draftListing;
      if (listing != null) {
        try {
          final reloaded = await _loadMediaForListing(listingId: listing.id);
          emit(state.copyWith(media: reloaded));
        } catch (_) {
          /* nothing more to do */
        }
      }
    }
  }

  Future<void> _onMediaUploadDismissed(
    MediaUploadDismissed event,
    Emitter<ListingFormState> emit,
  ) async {
    if (!state.uploadInFlight.containsKey(event.localId)) return;
    final nextInFlight = <String, MediaUploadProgress>{...state.uploadInFlight}
      ..remove(event.localId);
    emit(state.copyWith(uploadInFlight: nextInFlight));
  }

  String _newLocalId() {
    // Cheap opaque identifier — does NOT need to be a real UUID, only
    // unique within the uploadInFlight map for the BLoC's lifetime.
    return 'upload_${DateTime.now().microsecondsSinceEpoch}_'
        '${state.uploadInFlight.length}';
  }

  @override
  Future<void> close() {
    _imageWorker?.stop();
    _imageWorker = null;
    return super.close();
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
