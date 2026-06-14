import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/listing/rejection_reason.dart';
import '../../domain/entities/revision_diff.dart';
import '../../domain/usecases/apply_revision.dart';
import '../../domain/usecases/load_revision_diff.dart';
import '../../domain/usecases/reject_revision.dart';

// ─── Events ─────────────────────────────────────────────────────────────

sealed class RevisionReviewEvent extends Equatable {
  const RevisionReviewEvent();
  @override
  List<Object?> get props => const [];
}

class RevisionReviewLoad extends RevisionReviewEvent {
  const RevisionReviewLoad({required this.revisionId, required this.listingId});

  final String revisionId;
  final String listingId;

  @override
  List<Object?> get props => [revisionId, listingId];
}

class RevisionReviewApprovePressed extends RevisionReviewEvent {
  const RevisionReviewApprovePressed();
}

class RevisionReviewRejectPressed extends RevisionReviewEvent {
  const RevisionReviewRejectPressed({required this.preset, this.detail});

  final RejectionReason preset;
  final String? detail;

  @override
  List<Object?> get props => [preset, detail];
}

// ─── Success marker ─────────────────────────────────────────────────────

enum RevisionMutatorOutcome { applied, rejected }

// ─── State ──────────────────────────────────────────────────────────────

class RevisionReviewState extends Equatable {
  const RevisionReviewState({
    this.diff,
    this.isLoading = false,
    this.isMutatorInFlight = false,
    this.failure,
    this.outcome,
  });

  final RevisionDiff? diff;
  final bool isLoading;
  final bool isMutatorInFlight;
  final Failure? failure;
  final RevisionMutatorOutcome? outcome;

  RevisionReviewState copyWith({
    RevisionDiff? diff,
    bool? isLoading,
    bool? isMutatorInFlight,
    Failure? failure,
    bool clearFailure = false,
    RevisionMutatorOutcome? outcome,
  }) {
    return RevisionReviewState(
      diff: diff ?? this.diff,
      isLoading: isLoading ?? this.isLoading,
      isMutatorInFlight: isMutatorInFlight ?? this.isMutatorInFlight,
      failure: clearFailure ? null : (failure ?? this.failure),
      outcome: outcome ?? this.outcome,
    );
  }

  @override
  List<Object?> get props => [
    diff,
    isLoading,
    isMutatorInFlight,
    failure,
    outcome,
  ];
}

// ─── BLoC ───────────────────────────────────────────────────────────────

@injectable
class RevisionReviewBloc extends Bloc<RevisionReviewEvent, RevisionReviewState> {
  RevisionReviewBloc(
    this._loadDiff,
    this._applyRevision,
    this._rejectRevision,
  ) : super(const RevisionReviewState()) {
    on<RevisionReviewLoad>(_onLoad);
    on<RevisionReviewApprovePressed>(_onApprove);
    on<RevisionReviewRejectPressed>(_onReject);
  }

  final LoadRevisionDiff _loadDiff;
  final ApplyRevision _applyRevision;
  final RejectRevision _rejectRevision;

  String? _revisionId;

  Future<void> _onLoad(
    RevisionReviewLoad event,
    Emitter<RevisionReviewState> emit,
  ) async {
    _revisionId = event.revisionId;
    emit(const RevisionReviewState(isLoading: true));
    final result = await _loadDiff.call(
      revisionId: event.revisionId,
      listingId: event.listingId,
    );
    switch (result) {
      case Success<RevisionDiff>(:final value):
        emit(RevisionReviewState(diff: value, isLoading: false));
      case FailureResult<RevisionDiff>(:final failure):
        emit(RevisionReviewState(isLoading: false, failure: failure));
    }
  }

  Future<void> _onApprove(
    RevisionReviewApprovePressed event,
    Emitter<RevisionReviewState> emit,
  ) async {
    final id = _revisionId;
    if (id == null) return;
    emit(state.copyWith(isMutatorInFlight: true, clearFailure: true));
    final result = await _applyRevision.call(id);
    switch (result) {
      case Success<void>():
        emit(
          state.copyWith(
            isMutatorInFlight: false,
            outcome: RevisionMutatorOutcome.applied,
          ),
        );
      case FailureResult<void>(:final failure):
        emit(state.copyWith(isMutatorInFlight: false, failure: failure));
    }
  }

  Future<void> _onReject(
    RevisionReviewRejectPressed event,
    Emitter<RevisionReviewState> emit,
  ) async {
    final id = _revisionId;
    if (id == null) return;
    emit(state.copyWith(isMutatorInFlight: true, clearFailure: true));
    final result = await _rejectRevision.call(
      revisionId: id,
      preset: event.preset,
      detail: event.detail,
    );
    switch (result) {
      case Success<void>():
        emit(
          state.copyWith(
            isMutatorInFlight: false,
            outcome: RevisionMutatorOutcome.rejected,
          ),
        );
      case FailureResult<void>(:final failure):
        emit(state.copyWith(isMutatorInFlight: false, failure: failure));
    }
  }
}
