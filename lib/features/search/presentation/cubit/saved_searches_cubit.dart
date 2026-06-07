// lib/features/search/presentation/cubit/saved_searches_cubit.dart
//
// Phase 25 premium uplift — drives the saved-searches list page (load /
// delete) AND the "save this search" action invoked from the search page.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/entities/saved_search.dart';
import '../../domain/usecases/delete_saved_search_usecase.dart';
import '../../domain/usecases/list_saved_searches_usecase.dart';
import '../../domain/usecases/save_search_usecase.dart';

enum SavedSearchesStatus { initial, loading, success, failure }

class SavedSearchesState extends Equatable {
  const SavedSearchesState({
    this.status = SavedSearchesStatus.initial,
    this.items = const [],
    this.failure,
  });

  final SavedSearchesStatus status;
  final List<SavedSearch> items;
  final Failure? failure;

  SavedSearchesState copyWith({
    SavedSearchesStatus? status,
    List<SavedSearch>? items,
    Failure? failure,
    bool clearFailure = false,
  }) => SavedSearchesState(
    status: status ?? this.status,
    items: items ?? this.items,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [status, items, failure];
}

/// Outcome of a [SavedSearchesCubit.save] attempt — surfaced to the caller so
/// the search page can show the right snackbar (saved / sign-in-required /
/// error) without subscribing to the list page's state.
enum SaveSearchOutcome { saved, authRequired, error }

@injectable
class SavedSearchesCubit extends Cubit<SavedSearchesState> {
  SavedSearchesCubit(this._list, this._save, this._delete)
    : super(const SavedSearchesState());

  final ListSavedSearchesUseCase _list;
  final SaveSearchUseCase _save;
  final DeleteSavedSearchUseCase _delete;

  Future<void> load() async {
    emit(state.copyWith(status: SavedSearchesStatus.loading, clearFailure: true));
    final result = await _list();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(
          state.copyWith(status: SavedSearchesStatus.success, items: value),
        );
      case FailureResult(:final failure):
        emit(
          state.copyWith(
            status: SavedSearchesStatus.failure,
            failure: failure,
          ),
        );
    }
  }

  /// Saves [filters] under [label]. Returns the outcome for snackbar messaging.
  /// On success, optimistically prepends the new row to [items] (no re-fetch).
  Future<SaveSearchOutcome> save({
    required String label,
    required FilterState filters,
  }) async {
    final result = await _save(label: label, filters: filters);
    if (isClosed) return SaveSearchOutcome.error;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(items: [value, ...state.items]));
        return SaveSearchOutcome.saved;
      case FailureResult(:final failure):
        return failure is PermissionDeniedFailure
            ? SaveSearchOutcome.authRequired
            : SaveSearchOutcome.error;
    }
  }

  Future<void> delete(String id) async {
    // Optimistic removal; restore on failure.
    final previous = state.items;
    emit(
      state.copyWith(
        items: previous.where((s) => s.id != id).toList(),
      ),
    );
    final result = await _delete(id);
    if (isClosed) return;
    if (result is FailureResult) {
      emit(state.copyWith(items: previous, status: SavedSearchesStatus.success));
    }
  }
}
