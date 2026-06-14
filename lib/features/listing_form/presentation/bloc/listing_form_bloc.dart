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
import '../../../settings/presentation/bloc/app_settings_cubit.dart';
import '../../data/datasources/supabase_listing_media_datasource.dart'
    show MediaDeleteException;
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_details.dart';
import '../../domain/entities/listing_form_state.dart';
import '../../domain/entities/listing_media.dart';
import '../../domain/entities/listing_price.dart';
import '../../domain/entities/listing_revision.dart';
import '../../domain/entities/listing_visibility.dart';
import '../../domain/entities/revision_manifest_item.dart';
import '../../domain/entities/submit_failure.dart';
import '../../domain/repositories/listings_repository.dart';
import '../../domain/usecases/begin_revision.dart';
import '../../domain/usecases/delete_draft.dart';
import '../../domain/usecases/delete_media.dart';
import '../../domain/usecases/derive_area_centroid.dart';
import '../../domain/usecases/load_media_for_listing.dart';
import '../../domain/usecases/load_revision.dart';
import '../../domain/usecases/reorder_media.dart';
import '../../domain/usecases/save_form_step.dart';
import '../../domain/usecases/save_revision.dart';
import '../../domain/usecases/set_main_image.dart';
import '../../domain/usecases/submit_listing.dart';
import '../../domain/usecases/submit_revision.dart';
import '../../domain/usecases/upload_image.dart';
import '../../domain/usecases/upload_panorama.dart';
import '../../domain/usecases/upload_staged_media.dart';
import '../../domain/usecases/upload_video.dart';
import '../../domain/usecases/validate_submit_payload.dart';
import '../util/image_isolate_worker.dart';
import '../util/panorama_pipeline.dart' show NotEquirectangularException;
import '../util/video_processor.dart';
import '../util/watermark_pipeline.dart';
import 'listing_form_event.dart';

/// Sentinel stored in [ListingFormState.lastSaveError] when a stay-live
/// revision could NOT be started for an approved listing (e.g. the caller is
/// not the owner — an admin reaching a foreign listing via a queue). The page
/// maps this to a localized message; the form is intentionally left unrendered
/// so the live, public listing is never edited in place. See
/// `_onLoadOrCreateDraftRequested`.
const String kListingFormRevisionStartFailed =
    'listing_form.revision_start_failed';

@injectable
class ListingFormBloc extends Bloc<ListingFormEvent, ListingFormState> {
  ListingFormBloc(
    this._saveFormStep,
    this._submitListing,
    this._deleteDraft,
    this._deriveAreaCentroid,
    this._validateSubmitPayload,
    this._repository,
    this._uploadImage,
    this._uploadVideo,
    this._uploadPanorama,
    this._reorderMedia,
    this._setMainImage,
    this._deleteMedia,
    this._loadMediaForListing,
    this._loadMyActiveAgencies,
    this._appSettingsCubit,
    this._videoProcessor,
    this._beginRevision,
    this._loadRevision,
    this._saveRevision,
    this._submitRevision,
    this._uploadStagedImage,
    this._uploadStagedVideo,
    this._uploadStagedPanorama,
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
    // Phase 029 (F5) — 360° panorama upload handler.
    on<PanoramaPicked>(_onPanoramaPicked);
    on<MediaReordered>(_onMediaReordered);
    on<MediaSetMain>(_onMediaSetMain);
    on<MediaSetPanorama>(_onMediaSetPanorama);
    on<MediaDeleted>(_onMediaDeleted);
    on<MediaUploadDismissed>(_onMediaUploadDismissed);
  }

  final SaveFormStep _saveFormStep;
  final SubmitListing _submitListing;
  final DeleteDraft _deleteDraft;
  final DeriveAreaCentroid _deriveAreaCentroid;
  final ValidateSubmitPayload _validateSubmitPayload;
  final ListingsRepository _repository;
  final UploadImage _uploadImage;
  final UploadVideo _uploadVideo;
  final UploadPanorama _uploadPanorama;
  final ReorderMedia _reorderMedia;
  final SetMainImage _setMainImage;
  final DeleteMedia _deleteMedia;
  final LoadMediaForListing _loadMediaForListing;
  final LoadMyActiveAgencies _loadMyActiveAgencies;
  // Phase 23 (FC / T027) — source of the admin-tuned new-listing visibility
  // defaults (default_publisher_name_visibility / default_location_visibility).
  // Holds the already-loaded snapshot (app-start/resume); safe defaults on the
  // fail-open path. Read-only here.
  final AppSettingsCubit _appSettingsCubit;

  // Phase 030 (W1) — best-effort 720p transcode + poster-thumbnail helper for
  // picked videos. Wraps the video_compress singleton; never blocks publishing.
  final VideoProcessor _videoProcessor;

  // Phase 031 (WS-B) — stay-live edit-revision usecases. Engaged ONLY when an
  // EDIT session loads an APPROVED listing (state.isRevision); draft/rejected
  // edits keep today's in-place behavior.
  final BeginRevision _beginRevision;
  final LoadRevision _loadRevision;
  final SaveRevision _saveRevision;
  final SubmitRevision _submitRevision;
  final UploadStagedImage _uploadStagedImage;
  final UploadStagedVideo _uploadStagedVideo;
  final UploadStagedPanorama _uploadStagedPanorama;

  // Phase 11 — lazily-instantiated isolate worker per R-25 (one per BLoC
  // lifecycle, processes images sequentially).
  ImageIsolateWorker? _imageWorker;
  Uint8List? _watermarkAssetBytes;

  static const String _watermarkAssetPath =
      'assets/images/watermark/logo_watermark.png';

  // Phase 030 (W1) — 30 MB cap (30 * 1024 * 1024), boundary inclusive. Mirrors
  // VideoFileValidator; used as a backstop on the post-transcode result.
  static const int _videoSizeCapBytes = 31457280;

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

        // Phase 031 (WS-B) — STAY-LIVE REVISION. An APPROVED listing must stay
        // public on its old content while the publisher edits a staged copy.
        // Begin (or resume) the open revision and load its proposed+manifest
        // into the form instead of the live listing's own values. Draft/
        // rejected listings fall through to today's in-place edit flow.
        if (listing.status == ListingStatus.approved) {
          final loaded = await _loadRevisionForEditing(listing, agencies, emit);
          if (loaded) return;
          // Revision setup failed (e.g. the caller is not the owner — an admin
          // reaching a foreign listing via the review queue). Do NOT fall back
          // to an in-place read: editing an APPROVED listing in place would
          // mutate the LIVE, public content directly, bypassing the stay-live
          // review. Surface an error and leave the form unrendered instead.
          emit(
            state.copyWith(
              loadInProgress: false,
              lastSaveError: kListingFormRevisionStartFailed,
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
        // Phase 23 (FC / T027) — distinguish a freshly-inserted draft from an
        // existing one so the admin-tuned visibility defaults are applied ONLY
        // to brand-new listings (FR-008, forward-only). An existing draft keeps
        // its persisted visibility untouched.
        var listing = await _repository.findDraftForPublisher(publisherUserId);
        if (listing == null) {
          final fresh = await _repository.insertDraft(publisherUserId);
          listing = _applyNewListingVisibilityDefaults(fresh);
        }
        // Fresh-create path — also load any existing media (empty for new
        // drafts; non-empty when an existing draft was returned).
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
      return result.value.where((a) => a.status.canPublishUnder).toList();
    }
    return const <Agency>[];
  }

  /// Phase 031 (WS-B) — opens (or resumes) the stay-live revision for an
  /// APPROVED [liveListing], folds its `proposed` snapshot onto the in-memory
  /// draft entities and its `media_manifest` onto the picker, and emits the
  /// loaded revision-mode state. Returns true on success; false (with no emit)
  /// to let the caller fall back to the live-listing in-place read.
  Future<bool> _loadRevisionForEditing(
    Listing liveListing,
    List<Agency> agencies,
    Emitter<ListingFormState> emit,
  ) async {
    try {
      final revisionId = await _beginRevision(liveListing.id);
      final revision = await _loadRevision(revisionId);
      if (revision == null) return false;

      final draftListing = _applyProposedToListing(liveListing, revision);
      final draftDetails = _proposedToDetails(liveListing.id, revision.proposed);
      final draftPrice = _proposedToPrice(liveListing.id, revision.proposed);
      final manifest = revision.manifest;
      final media = _manifestToMedia(liveListing.id, manifest);

      emit(
        state.copyWith(
          draftListing: draftListing,
          draftDetails: draftDetails,
          draftPrice: draftPrice,
          loadInProgress: false,
          media: media,
          uploadInFlight: const <String, MediaUploadProgress>{},
          availableAgencies: agencies,
          isRevision: true,
          revisionId: revisionId,
          revisionManifest: manifest,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Folds a revision's `proposed` scalar keys onto the live [listing]. The
  /// status stays `approved` (the live listing is untouched) so the rest of the
  /// form treats this as the editable subject; revision-mode handlers ensure no
  /// live write happens.
  Listing _applyProposedToListing(Listing listing, ListingRevision revision) {
    final p = revision.proposed;
    return listing.copyWith(
      title: (p['title'] as String?) ?? listing.title,
      purpose: _purposeOr(p['purpose'], listing.purpose),
      propertyType: _propertyTypeOr(p['property_type'], listing.propertyType),
      governorateId: p['governorate_id'] as String?,
      cityId: p['city_id'] as String?,
      areaId: p['area_id'] as String?,
      addressText: p['address_text'] as String?,
      latitude: _numOrNull(p['latitude'])?.toDouble(),
      longitude: _numOrNull(p['longitude'])?.toDouble(),
      locationVisibility: _locVisOr(
        p['location_visibility'],
        listing.locationVisibility,
      ),
      contactNameVisibility: _contactVisOr(
        p['contact_name_visibility'],
        listing.contactNameVisibility,
      ),
      phone: p['phone'] as String?,
      whatsapp: p['whatsapp'] as String?,
      areaSize: _numOrNull(p['area_size'])?.toDouble(),
      rooms: _intOrNull(p['rooms']),
      bathrooms: _intOrNull(p['bathrooms']),
      floor: _intOrNull(p['floor']),
    );
  }

  ListingDetails? _proposedToDetails(
    String listingId,
    Map<String, dynamic> p,
  ) {
    final description = p['description'] as String?;
    final amenitiesRaw = p['amenities'];
    final amenities = amenitiesRaw is List
        ? amenitiesRaw.map((e) => e.toString()).toList()
        : const <String>[];
    final yearBuilt = _intOrNull(p['year_built']);
    final furnished = p['furnished'] as bool?;
    final parking = p['parking'] as bool?;
    if (description == null &&
        amenities.isEmpty &&
        yearBuilt == null &&
        furnished == null &&
        parking == null) {
      return null;
    }
    final now = DateTime.now();
    return ListingDetails(
      listingId: listingId,
      description: description,
      amenities: amenities,
      yearBuilt: yearBuilt,
      furnished: furnished,
      parking: parking,
      createdAt: now,
      updatedAt: now,
    );
  }

  ListingPrice? _proposedToPrice(String listingId, Map<String, dynamic> p) {
    final code = p['price_currency_code'] as String?;
    final amountRaw = p['price_amount'];
    if (code == null || code.isEmpty || amountRaw == null) return null;
    Decimal amount;
    try {
      amount = Decimal.parse(amountRaw.toString());
    } catch (_) {
      return null;
    }
    return ListingPrice(
      id: '',
      listingId: listingId,
      currencyCode: code,
      amount: amount,
      isPrimary: true,
      createdAt: DateTime.now(),
    );
  }

  List<ListingMedia> _manifestToMedia(
    String listingId,
    List<RevisionManifestItem> manifest,
  ) {
    final sorted = [...manifest]
      ..sort((a, b) => a.ordering.compareTo(b.ordering));
    return sorted.map((m) => m.toMedia(listingId)).toList();
  }

  /// Builds the `proposed` JSON object (exact RPC keys) from the current draft.
  /// Mirrors the snapshot shape `begin_listing_revision` produces.
  Map<String, dynamic> _buildProposed() {
    final listing = state.draftListing!;
    final details = state.draftDetails;
    final price = state.draftPrice;
    return <String, dynamic>{
      'title': listing.title,
      'purpose': listing.purpose.toDbValue(),
      'property_type': listing.propertyType.toDbValue(),
      'governorate_id': listing.governorateId,
      'city_id': listing.cityId,
      'area_id': listing.areaId,
      'address_text': listing.addressText,
      'latitude': listing.latitude,
      'longitude': listing.longitude,
      'location_visibility': listing.locationVisibility.toDbValue(),
      'contact_name_visibility': listing.contactNameVisibility.toDbValue(),
      'phone': listing.phone,
      'whatsapp': listing.whatsapp,
      'area_size': listing.areaSize,
      'rooms': listing.rooms,
      'bathrooms': listing.bathrooms,
      'floor': listing.floor,
      'description': details?.description,
      'amenities': details?.amenities ?? const <String>[],
      'year_built': details?.yearBuilt,
      'furnished': details?.furnished,
      'parking': details?.parking,
      'price_currency_code': price?.currencyCode,
      'price_amount': price?.amount.toString(),
    };
  }

  /// Persists the current draft + manifest onto the open revision via
  /// `save_listing_revision`. No-op outside revision mode.
  Future<void> _persistRevision() async {
    final revisionId = state.revisionId;
    if (!state.isRevision || revisionId == null) return;
    await _saveRevision(
      revisionId: revisionId,
      proposed: _buildProposed(),
      manifest: state.revisionManifest,
    );
  }

  /// Phase 031 (WS-B) — re-normalizes a staged manifest (1-based `ordering` by
  /// list position) and emits both the manifest and its derived [media] view.
  /// Best-effort persists the manifest onto the revision (the in-memory state is
  /// already the source of truth; a failed save retries on the next step save).
  Future<void> _emitManifest(
    List<RevisionManifestItem> next,
    Emitter<ListingFormState> emit,
  ) async {
    final renumbered = <RevisionManifestItem>[];
    for (var i = 0; i < next.length; i++) {
      renumbered.add(next[i].copyWith(ordering: i + 1));
    }
    final listingId = state.draftListing?.id ?? '';
    emit(
      state.copyWith(
        revisionManifest: renumbered,
        media: _manifestToMedia(listingId, renumbered),
      ),
    );
    try {
      await _persistRevision();
    } catch (_) {
      // Swallowed — the manifest lives in state and re-saves on the next
      // step save / submit.
    }
  }

  /// Appends a freshly-uploaded staged media item to the manifest. New images
  /// auto-become main when no image is present yet (mirrors the live path);
  /// videos/panoramas never become main.
  Future<void> _appendManifestItem({
    required String storagePath,
    required String kind,
    String? thumbnailPath,
    required Emitter<ListingFormState> emit,
  }) async {
    final hasImage = state.revisionManifest.any((m) => m.kind == 'image');
    final isMain = kind == 'image' && !hasImage;
    final next = [
      ...state.revisionManifest,
      RevisionManifestItem(
        storagePath: storagePath,
        kind: kind,
        isMain: isMain,
        ordering: state.revisionManifest.length + 1,
        thumbnailPath: thumbnailPath,
      ),
    ];
    await _emitManifest(next, emit);
  }

  static ListingPurpose _purposeOr(Object? raw, ListingPurpose fallback) {
    if (raw is! String) return fallback;
    try {
      return ListingPurposeDb.fromDbValue(raw);
    } catch (_) {
      return fallback;
    }
  }

  static PropertyType _propertyTypeOr(Object? raw, PropertyType fallback) {
    if (raw is! String) return fallback;
    try {
      return PropertyTypeDb.fromDbValue(raw);
    } catch (_) {
      return fallback;
    }
  }

  static LocationVisibility _locVisOr(
    Object? raw,
    LocationVisibility fallback,
  ) {
    if (raw is! String) return fallback;
    try {
      return LocationVisibilityDb.fromDbValue(raw);
    } catch (_) {
      return fallback;
    }
  }

  static ContactNameVisibility _contactVisOr(
    Object? raw,
    ContactNameVisibility fallback,
  ) {
    if (raw is! String) return fallback;
    try {
      return ContactNameVisibilityDb.fromDbValue(raw);
    } catch (_) {
      return fallback;
    }
  }

  static num? _numOrNull(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw;
    return num.tryParse(raw.toString());
  }

  static int? _intOrNull(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
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
      // Phase 031 (WS-B) — in revision mode the step's edits are STAGED onto the
      // open revision (no live listing write). Otherwise today's in-place save.
      if (state.isRevision) {
        await _persistRevision();
      } else {
        await _saveFormStep(state, state.currentStep);
      }
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
      // Phase 031 (WS-B) — stage onto the revision in revision mode.
      if (state.isRevision) {
        await _persistRevision();
      } else {
        await _saveFormStep(state, state.currentStep);
      }
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
      // Phase 031 (WS-B) — revision mode: persist the staged edits then move the
      // revision to pending_review. The LIVE listing stays approved + public on
      // its old content until an admin applies the revision (NOT submit_listing).
      if (state.isRevision) {
        final revisionId = state.revisionId;
        if (revisionId == null) {
          throw StateError('revision id missing');
        }
        await _persistRevision();
        await _submitRevision(revisionId);
        emit(state.copyWith(submitInProgress: false, submitSucceeded: true));
        return;
      }
      // Phase 031 follow-up — the single-scroll detail-style CREATE form
      // (ListingDetailFormPage) mutates only in-memory state via FieldChanged;
      // unlike the stepper it has no per-step "Continue"/"Save & exit" that
      // would call SaveFormStep, so nothing reaches the DB. Flush the whole
      // draft once here before the server validates it, otherwise the
      // submit_listing RPC sees an empty row and rejects every field. This is
      // idempotent for the stepper, which already saved each step in place.
      for (final step in const <ListingFormStep>[
        ListingFormStep.basics,
        ListingFormStep.location,
        ListingFormStep.details,
        ListingFormStep.prices,
        ListingFormStep.visibility,
      ]) {
        await _saveFormStep(state, step);
      }
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
    // Phase 029 (F5) — picked image is not a 2:1 equirectangular panorama.
    if (error is NotEquirectangularException) {
      return 'media.error.notEquirectangular';
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
          // Phase 029 (F5) — panorama cap (2 per listing).
          if (kind == 'panorama') return 'media.cap.panoramas2';
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
        //
        // Phase 031 (WS-B) — in REVISION mode the watermarked bytes are uploaded
        // to the SAME {listingId}/ bucket path but NO live listing_media row is
        // inserted; instead a manifest entry is staged. The admin's
        // apply_listing_revision later reconciles the live rows.
        if (state.isRevision) {
          final stagedPath = await () async {
            final sourceBytes = await file.readAsBytes();
            final watermarkedJpeg = await _imageWorker!.processImage(
              sourceBytes: sourceBytes,
              watermarkAssetBytes: _watermarkAssetBytes!,
              isRtl: event.isRtl,
            );
            emit(
              state.copyWith(
                uploadInFlight: <String, MediaUploadProgress>{
                  ...state.uploadInFlight,
                  localId: const MediaUploadProgressUploading(),
                },
              ),
            );
            return await _uploadStagedImage(
              listingId: listingId,
              watermarkedBytes: watermarkedJpeg,
            );
          }().timeout(const Duration(seconds: 60));

          final nextInFlight = <String, MediaUploadProgress>{
            ...state.uploadInFlight,
          }..remove(localId);
          emit(state.copyWith(uploadInFlight: nextInFlight));
          await _appendManifestItem(
            storagePath: stagedPath,
            kind: 'image',
            emit: emit,
          );
          continue;
        }

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

    try {
      // Phase 030 (W1) — best-effort 720p transcode. Surface a determinate
      // "compressing" ghost; the helper falls back to the original file on any
      // failure / no-gain, so this NEVER blocks publishing.
      emit(
        state.copyWith(
          uploadInFlight: <String, MediaUploadProgress>{
            ...state.uploadInFlight,
            localId: const MediaUploadProgressCompressing(),
          },
        ),
      );

      final compressed = await _videoProcessor.compress(
        event.file.path,
        onProgress: (percent) {
          // Emit directly from the progress callback — we are still inside this
          // handler's async body (the emitter is live across the await), so the
          // ghost updates live. Dispatching a separate event would NOT work:
          // bloc processes events sequentially, so a queued event can't run
          // until this handler returns. Guard against a dismissed entry / a
          // closed bloc.
          if (isClosed) return;
          final current = state.uploadInFlight[localId];
          if (current is! MediaUploadProgressCompressing) return;
          emit(
            state.copyWith(
              uploadInFlight: <String, MediaUploadProgress>{
                ...state.uploadInFlight,
                localId: MediaUploadProgressCompressing(percent),
              },
            ),
          );
        },
      );
      final uploadPath = compressed.path;

      // Backstop re-validation of the compressed result against the ≤30 MB cap
      // (a no-gain fallback keeps the original, which already passed above; a
      // genuine transcode should be smaller, but guard anyway).
      int compressedSize = sizeBytes;
      try {
        compressedSize = await compressed.length();
      } catch (_) {
        compressedSize = sizeBytes;
      }
      if (compressedSize > _videoSizeCapBytes) {
        emit(
          state.copyWith(
            uploadInFlight: <String, MediaUploadProgress>{
              ...state.uploadInFlight,
              localId: const MediaUploadProgressError(
                'media.error.videoSizeExceeded',
              ),
            },
          ),
        );
        return;
      }

      // Best-effort poster frame (null = upload proceeds without a poster).
      final thumbnailFile = await _videoProcessor.thumbnail(uploadPath);

      // Flip to the upload phase before the bucket commit.
      emit(
        state.copyWith(
          uploadInFlight: <String, MediaUploadProgress>{
            ...state.uploadInFlight,
            localId: const MediaUploadProgressUploading(),
          },
        ),
      );

      // Phase 031 (WS-B) — staged (manifest) upload in revision mode: no live
      // listing_media row is inserted; a manifest entry is appended instead.
      if (state.isRevision) {
        final staged = await _uploadStagedVideo(
          listingId: listingId,
          filePath: uploadPath,
          thumbnailJpegPath: thumbnailFile?.path,
        ).timeout(const Duration(seconds: 60));
        final nextInFlight = <String, MediaUploadProgress>{
          ...state.uploadInFlight,
        }..remove(localId);
        emit(state.copyWith(uploadInFlight: nextInFlight));
        await _appendManifestItem(
          storagePath: staged.storagePath,
          kind: 'video',
          thumbnailPath: staged.thumbnailPath,
          emit: emit,
        );
        return;
      }

      final inserted = await _uploadVideo(
        listingId: listingId,
        filePath: uploadPath,
        ordering: 0, // sentinel — trigger assigns per task #29 fix
        thumbnailJpegPath: thumbnailFile?.path,
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

  /// Phase 029 (F5) — runs a picked equirectangular image through the panorama
  /// pipeline on the shared isolate worker (no watermark, 4096px cap, 2:1
  /// aspect gate), then uploads it as a `kind='panorama'` row. Reuses the same
  /// upload-ghost / progress machinery as [_onMediaPicked] / [_onVideoPicked].
  Future<void> _onPanoramaPicked(
    PanoramaPicked event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null) return;
    final listingId = listing.id;

    try {
      // The panorama pipeline does not need the watermark asset, but the worker
      // lifecycle is shared with images; starting it here is idempotent.
      await _ensureImageWorker();
    } catch (_) {
      // Worker / asset load failed — surface a generic upload error tile.
      final localId = _newLocalId();
      emit(
        state.copyWith(
          uploadInFlight: <String, MediaUploadProgress>{
            ...state.uploadInFlight,
            localId: const MediaUploadProgressError('media.error.uploadFailed'),
          },
        ),
      );
      return;
    }

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
      // Phase 031 (WS-B) — staged panorama upload in revision mode.
      if (state.isRevision) {
        final stagedPath = await () async {
          final sourceBytes = await event.file.readAsBytes();
          final processedJpeg = await _imageWorker!.processPanorama(
            sourceBytes: sourceBytes,
          );
          emit(
            state.copyWith(
              uploadInFlight: <String, MediaUploadProgress>{
                ...state.uploadInFlight,
                localId: const MediaUploadProgressUploading(),
              },
            ),
          );
          return await _uploadStagedPanorama(
            listingId: listingId,
            panoramaBytes: processedJpeg,
          );
        }().timeout(const Duration(seconds: 60));

        final nextInFlight = <String, MediaUploadProgress>{
          ...state.uploadInFlight,
        }..remove(localId);
        emit(state.copyWith(uploadInFlight: nextInFlight));
        await _appendManifestItem(
          storagePath: stagedPath,
          kind: kListingMediaKindPanorama,
          emit: emit,
        );
        return;
      }

      final inserted = await () async {
        final sourceBytes = await event.file.readAsBytes();
        final processedJpeg = await _imageWorker!.processPanorama(
          sourceBytes: sourceBytes,
        );

        emit(
          state.copyWith(
            uploadInFlight: <String, MediaUploadProgress>{
              ...state.uploadInFlight,
              localId: const MediaUploadProgressUploading(),
            },
          ),
        );

        return await _uploadPanorama(
          listingId: listingId,
          panoramaBytes: processedJpeg,
          ordering: 0, // sentinel — trigger assigns
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
    }
  }

  Future<void> _onMediaReordered(
    MediaReordered event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null) return;

    // Phase 031 (WS-B) — in revision mode media ids are the staged
    // storage_path; reorder the manifest in place and re-persist (no RPC).
    if (state.isRevision) {
      final byPath = <String, RevisionManifestItem>{
        for (final m in state.revisionManifest) m.storagePath: m,
      };
      final reordered = <RevisionManifestItem>[];
      for (final id in event.newOrder) {
        final m = byPath[id];
        if (m != null) reordered.add(m);
      }
      for (final m in state.revisionManifest) {
        if (!event.newOrder.contains(m.storagePath)) reordered.add(m);
      }
      await _emitManifest(reordered, emit);
      return;
    }

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

    // Phase 031 (WS-B) — revision mode: flip is_main in the manifest (the
    // event.mediaId is the staged storage_path). Only image rows can be main.
    if (state.isRevision) {
      final next = state.revisionManifest.map((m) {
        if (m.storagePath == event.mediaId) {
          return m.copyWith(isMain: m.kind == 'image');
        }
        return m.copyWith(isMain: false);
      }).toList();
      await _emitManifest(next, emit);
      return;
    }

    try {
      await _setMainImage(listingId: listing.id, mediaId: event.mediaId);
      final reloaded = await _loadMediaForListing(listingId: listing.id);
      emit(state.copyWith(media: reloaded));
    } catch (_) {
      // No-op on failure — widget can re-trigger.
    }
  }

  Future<void> _onMediaSetPanorama(
    MediaSetPanorama event,
    Emitter<ListingFormState> emit,
  ) async {
    final listing = state.draftListing;
    if (listing == null) return;
    // A panorama is an equirectangular image with the free-text `kind` flipped
    // to 'panorama' (and back to 'image' to unmark). Optimistically reflect the
    // new rawKind locally, then persist; reload from the server on failure.
    final targetKind = event.makePanorama
        ? kListingMediaKindPanorama
        : ListingMediaKind.image.toDbValue();

    // Phase 031 (WS-B) — revision mode: flip the manifest entry's kind (id is
    // the staged storage_path). A panorama can never be main.
    if (state.isRevision) {
      final next = state.revisionManifest.map((m) {
        if (m.storagePath != event.mediaId) return m;
        return m.copyWith(
          kind: targetKind,
          isMain: event.makePanorama ? false : m.isMain,
        );
      }).toList();
      await _emitManifest(next, emit);
      return;
    }
    final optimistic = state.media
        .map(
          (m) => m.id == event.mediaId ? m.copyWith(rawKind: targetKind) : m,
        )
        .toList();
    emit(state.copyWith(media: optimistic));
    try {
      await _repository.setMediaKind(
        mediaId: event.mediaId,
        kind: targetKind,
      );
      final reloaded = await _loadMediaForListing(listingId: listing.id);
      emit(state.copyWith(media: reloaded));
    } catch (_) {
      // Revert the optimistic update from the server's authoritative state.
      try {
        final reloaded = await _loadMediaForListing(listingId: listing.id);
        emit(state.copyWith(media: reloaded));
      } catch (_) {
        /* nothing more to do */
      }
    }
  }

  Future<void> _onMediaDeleted(
    MediaDeleted event,
    Emitter<ListingFormState> emit,
  ) async {
    // Phase 031 (WS-B) — revision mode: removal updates the manifest ONLY (the
    // staged bucket object is left for apply-time / out-of-band reconciliation,
    // mirroring the apply RPC's orphan-storage note). id is the storage_path.
    if (state.isRevision) {
      final removed = state.revisionManifest.firstWhere(
        (m) => m.storagePath == event.mediaId,
        orElse: () => const RevisionManifestItem(
          storagePath: '',
          kind: 'image',
          isMain: false,
          ordering: 0,
        ),
      );
      var next = state.revisionManifest
          .where((m) => m.storagePath != event.mediaId)
          .toList();
      // If the removed item was the main image, promote the first remaining
      // image to main so the listing keeps a cover.
      if (removed.isMain) {
        var promoted = false;
        next = next.map((m) {
          if (!promoted && m.kind == 'image') {
            promoted = true;
            return m.copyWith(isMain: true);
          }
          return m;
        }).toList();
      }
      await _emitManifest(next, emit);
      return;
    }

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

  /// Phase 23 (FC / T027) — pre-selects a brand-new listing's visibility from
  /// the admin-tuned `app_settings` defaults (FR-008). Applied ONLY to a
  /// freshly-inserted draft; existing drafts/listings are never touched
  /// (forward-only). Reads the already-loaded snapshot (safe defaults on the
  /// fail-open path).
  Listing _applyNewListingVisibilityDefaults(Listing fresh) {
    final settings = _appSettingsCubit.current;
    return fresh.copyWith(
      locationVisibility: settings.defaultLocationVisibility,
      contactNameVisibility: settings.defaultPublisherNameVisibility,
    );
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
