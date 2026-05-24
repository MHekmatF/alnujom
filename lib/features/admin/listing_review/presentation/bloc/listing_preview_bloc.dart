import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/listing/rejection_reason.dart';
import '../../domain/entities/listing_preview.dart';
import '../../domain/repositories/listing_review_repository.dart';
import '../../domain/usecases/approve_listing.dart';
import '../../domain/usecases/load_listing_preview.dart';
import '../../domain/usecases/reject_listing.dart';

// ─── Events ─────────────────────────────────────────────────────────────

sealed class ListingPreviewEvent extends Equatable {
  const ListingPreviewEvent();
  @override
  List<Object?> get props => const [];
}

class ListingPreviewLoad extends ListingPreviewEvent {
  const ListingPreviewLoad(this.listingId);
  final String listingId;
  @override
  List<Object?> get props => [listingId];
}

class ListingPreviewApprovePressed extends ListingPreviewEvent {
  const ListingPreviewApprovePressed();
}

/// Phase 12 / US2 — dispatched when the admin confirms the reject dialog.
class ListingPreviewRejectPressed extends ListingPreviewEvent {
  const ListingPreviewRejectPressed({required this.preset, this.detail});

  final RejectionReason preset;
  final String? detail;

  @override
  List<Object?> get props => [preset, detail];
}

// ─── Mutator success marker ─────────────────────────────────────────────

sealed class ListingMutatorSuccess extends Equatable {
  const ListingMutatorSuccess();
  @override
  List<Object?> get props => const [];
}

class ApproveSuccess extends ListingMutatorSuccess {
  const ApproveSuccess(this.result);
  final ApproveResult result;
  @override
  List<Object?> get props => [result];
}

class RejectSuccess extends ListingMutatorSuccess {
  const RejectSuccess(this.result);
  final RejectResult result;
  @override
  List<Object?> get props => [result];
}

// ─── State ──────────────────────────────────────────────────────────────

class ListingPreviewState extends Equatable {
  const ListingPreviewState({
    this.preview,
    this.isLoading = false,
    this.isMutatorInFlight = false,
    this.failure,
    this.lastSuccess,
  });

  final ListingPreview? preview;
  final bool isLoading;
  final bool isMutatorInFlight;
  final Failure? failure;
  final ListingMutatorSuccess? lastSuccess;

  ListingPreviewState copyWith({
    ListingPreview? preview,
    bool? isLoading,
    bool? isMutatorInFlight,
    Failure? failure,
    bool clearFailure = false,
    ListingMutatorSuccess? lastSuccess,
    bool clearLastSuccess = false,
  }) {
    return ListingPreviewState(
      preview: preview ?? this.preview,
      isLoading: isLoading ?? this.isLoading,
      isMutatorInFlight: isMutatorInFlight ?? this.isMutatorInFlight,
      failure: clearFailure ? null : (failure ?? this.failure),
      lastSuccess: clearLastSuccess ? null : (lastSuccess ?? this.lastSuccess),
    );
  }

  @override
  List<Object?> get props => [
    preview,
    isLoading,
    isMutatorInFlight,
    failure,
    lastSuccess,
  ];
}

// ─── BLoC ───────────────────────────────────────────────────────────────

@injectable
class ListingPreviewBloc
    extends Bloc<ListingPreviewEvent, ListingPreviewState> {
  ListingPreviewBloc(
    this._loadPreview,
    this._approveListing,
    this._rejectListing,
  ) : super(const ListingPreviewState()) {
    on<ListingPreviewLoad>(_onLoad);
    on<ListingPreviewApprovePressed>(_onApprove);
    on<ListingPreviewRejectPressed>(_onReject);
  }

  final LoadListingPreviewUseCase _loadPreview;
  final ApproveListingUseCase _approveListing;
  final RejectListingUseCase _rejectListing;

  /// The listingId of the currently-loaded preview. Set on `Load`,
  /// consumed by approve/reject mutators.
  String? _currentListingId;

  Future<void> _onLoad(
    ListingPreviewLoad event,
    Emitter<ListingPreviewState> emit,
  ) async {
    _currentListingId = event.listingId;
    emit(const ListingPreviewState(isLoading: true));
    final result = await _loadPreview.call(event.listingId);
    switch (result) {
      case Success<ListingPreview>(:final value):
        emit(ListingPreviewState(preview: value, isLoading: false));
      case FailureResult<ListingPreview>(:final failure):
        emit(ListingPreviewState(isLoading: false, failure: failure));
    }
  }

  Future<void> _onApprove(
    ListingPreviewApprovePressed event,
    Emitter<ListingPreviewState> emit,
  ) async {
    final listingId = _currentListingId;
    if (listingId == null) return;
    emit(state.copyWith(isMutatorInFlight: true, clearFailure: true));
    final result = await _approveListing.call(listingId);
    switch (result) {
      case Success<ApproveResult>(:final value):
        emit(
          state.copyWith(
            isMutatorInFlight: false,
            lastSuccess: ApproveSuccess(value),
          ),
        );
      case FailureResult<ApproveResult>(:final failure):
        emit(state.copyWith(isMutatorInFlight: false, failure: failure));
    }
  }

  Future<void> _onReject(
    ListingPreviewRejectPressed event,
    Emitter<ListingPreviewState> emit,
  ) async {
    final listingId = _currentListingId;
    if (listingId == null) return;
    emit(state.copyWith(isMutatorInFlight: true, clearFailure: true));
    final result = await _rejectListing.call(
      listingId,
      event.preset,
      event.detail,
    );
    switch (result) {
      case Success<RejectResult>(:final value):
        emit(
          state.copyWith(
            isMutatorInFlight: false,
            lastSuccess: RejectSuccess(value),
          ),
        );
      case FailureResult<RejectResult>(:final failure):
        emit(state.copyWith(isMutatorInFlight: false, failure: failure));
    }
  }
}
