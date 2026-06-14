import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../listing_form/domain/entities/pending_revision.dart';
import '../../domain/usecases/load_pending_revisions.dart';

/// Phase 031 (WS-B) — drives the "Edits awaiting approval" section on the admin
/// pending-review queue. A small cubit (single-shot list load + refresh) since
/// the revisions list is short and unpaginated.
class PendingRevisionsState extends Equatable {
  const PendingRevisionsState({
    this.revisions = const <PendingRevision>[],
    this.isLoading = false,
    this.failure,
  });

  final List<PendingRevision> revisions;
  final bool isLoading;
  final Failure? failure;

  bool get isEmpty => revisions.isEmpty && !isLoading && failure == null;

  PendingRevisionsState copyWith({
    List<PendingRevision>? revisions,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return PendingRevisionsState(
      revisions: revisions ?? this.revisions,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [revisions, isLoading, failure];
}

@injectable
class PendingRevisionsCubit extends Cubit<PendingRevisionsState> {
  PendingRevisionsCubit(this._loadPendingRevisions)
    : super(const PendingRevisionsState());

  final LoadPendingRevisions _loadPendingRevisions;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _loadPendingRevisions.call();
    switch (result) {
      case Success<List<PendingRevision>>(:final value):
        emit(PendingRevisionsState(revisions: value, isLoading: false));
      case FailureResult<List<PendingRevision>>(:final failure):
        emit(PendingRevisionsState(isLoading: false, failure: failure));
    }
  }
}
