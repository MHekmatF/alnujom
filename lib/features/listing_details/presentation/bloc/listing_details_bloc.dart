import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/listing_details_aggregate.dart';
import '../../domain/usecases/load_listing_details.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class ListingDetailsEvent extends Equatable {
  const ListingDetailsEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load (and reload after retry) — triggers the datasource fetch.
class ListingDetailsLoadRequested extends ListingDetailsEvent {
  const ListingDetailsLoadRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Auth state change propagated from [AuthBloc] subscription.
/// Used to refresh auth-dependent UI (e.g., contact-name visibility).
/// Per FR-022 + Phase 5 cross-phase dep.
class ListingDetailsAuthStateChanged extends ListingDetailsEvent {
  const ListingDetailsAuthStateChanged(this.authState);

  final AuthState authState;

  @override
  List<Object?> get props => [authState];
}

/// User pressed the Retry button on the error state.
class ListingDetailsRetryRequested extends ListingDetailsEvent {
  const ListingDetailsRetryRequested();
}

// ─── State ────────────────────────────────────────────────────────────────────

enum ListingDetailsStatus { initial, loading, success, notFound, error }

class ListingDetailsState extends Equatable {
  const ListingDetailsState({
    this.aggregate,
    this.status = ListingDetailsStatus.initial,
    this.failure,
    this.authState,
    this.currentId,
  });

  final ListingDetailsAggregate? aggregate;
  final ListingDetailsStatus status;
  final Failure? failure;
  final AuthState? authState;
  final String? currentId;

  ListingDetailsState copyWith({
    ListingDetailsAggregate? aggregate,
    ListingDetailsStatus? status,
    Failure? failure,
    AuthState? authState,
    String? currentId,
    bool clearFailure = false,
    bool clearAggregate = false,
  }) {
    return ListingDetailsState(
      aggregate: clearAggregate ? null : aggregate ?? this.aggregate,
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      authState: authState ?? this.authState,
      currentId: currentId ?? this.currentId,
    );
  }

  @override
  List<Object?> get props => [aggregate, status, failure, authState, currentId];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

/// Phase 13 (spec/013-home-and-details) — BLoC for the listing details page.
///
/// INDEPENDENT of Phase 12's [ListingPreviewBloc] per R-70. No shared imports,
/// no shared base class, no cross-phase BLoC dependency.
///
/// Events:
///   [ListingDetailsLoadRequested]  — fetch listing by id via [LoadListingDetails].
///   [ListingDetailsAuthStateChanged] — subscribe to Phase 5's [AuthBloc].
///   [ListingDetailsRetryRequested]  — retry last failed fetch.
///
/// State machine:
///   initial → loading → success | notFound | error
///   error → loading (on retry)
@injectable
class ListingDetailsBloc
    extends Bloc<ListingDetailsEvent, ListingDetailsState> {
  ListingDetailsBloc(this._loadListingDetails, this._authBloc)
    : super(const ListingDetailsState()) {
    on<ListingDetailsLoadRequested>(_onLoadRequested);
    on<ListingDetailsAuthStateChanged>(_onAuthStateChanged);
    on<ListingDetailsRetryRequested>(_onRetryRequested);

    // Subscribe to Phase 5's AuthBloc to receive auth state changes.
    _authSub = _authBloc.stream.listen(
      (authState) => add(ListingDetailsAuthStateChanged(authState)),
    );
  }

  final LoadListingDetails _loadListingDetails;
  final AuthBloc _authBloc;
  late final StreamSubscription<AuthState> _authSub;

  Future<void> _onLoadRequested(
    ListingDetailsLoadRequested event,
    Emitter<ListingDetailsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ListingDetailsStatus.loading,
        currentId: event.id,
        clearFailure: true,
      ),
    );
    await _fetchAndEmit(event.id, emit);
  }

  Future<void> _onRetryRequested(
    ListingDetailsRetryRequested event,
    Emitter<ListingDetailsState> emit,
  ) async {
    final id = state.currentId;
    if (id == null) return;
    emit(
      state.copyWith(
        status: ListingDetailsStatus.loading,
        clearFailure: true,
      ),
    );
    await _fetchAndEmit(id, emit);
  }

  void _onAuthStateChanged(
    ListingDetailsAuthStateChanged event,
    Emitter<ListingDetailsState> emit,
  ) {
    emit(state.copyWith(authState: event.authState));
  }

  Future<void> _fetchAndEmit(
    String id,
    Emitter<ListingDetailsState> emit,
  ) async {
    final result = await _loadListingDetails(id);
    switch (result) {
      case Success<ListingDetailsAggregate>():
        emit(
          state.copyWith(
            status: ListingDetailsStatus.success,
            aggregate: result.value,
          ),
        );
      case FailureResult<ListingDetailsAggregate>():
        if (result.failure is ListingNotFoundFailure) {
          emit(
            state.copyWith(
              status: ListingDetailsStatus.notFound,
              failure: result.failure,
              clearAggregate: true,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: ListingDetailsStatus.error,
              failure: result.failure,
              clearAggregate: true,
            ),
          );
        }
    }
  }

  @override
  Future<void> close() {
    _authSub.cancel();
    return super.close();
  }
}
