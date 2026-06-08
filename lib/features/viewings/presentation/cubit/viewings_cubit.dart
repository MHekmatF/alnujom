// lib/features/viewings/presentation/cubit/viewings_cubit.dart
//
// Viewing scheduler — ViewingsCubit: drives the viewings-list page.
// States: loading / list (possibly empty) / error.
//
// Beyond loading, it exposes:
//   - request()      → submit a new viewing request (used by the sheet)
//   - updateStatus() → confirm/decline/cancel, then reload the list

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/viewing.dart';
import '../../domain/usecases/load_my_viewings.dart';
import '../../domain/usecases/request_viewing.dart';
import '../../domain/usecases/update_viewing_status.dart';

part 'viewings_state.dart';

@injectable
class ViewingsCubit extends Cubit<ViewingsState> {
  ViewingsCubit(
    this._loadMyViewings,
    this._requestViewing,
    this._updateViewingStatus,
  ) : super(const ViewingsState.initial());

  final LoadMyViewings _loadMyViewings;
  final RequestViewing _requestViewing;
  final UpdateViewingStatus _updateViewingStatus;

  /// Initial (and retry) load — replaces any prior state.
  Future<void> load() async {
    emit(const ViewingsState.loading());
    final result = await _loadMyViewings();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(ViewingsState.list(value));
      case FailureResult():
        emit(const ViewingsState.error());
    }
  }

  /// Submits a viewing request. Returns true on success so the caller (the
  /// request sheet) can pop + show the confirmation snackbar.
  Future<bool> request({
    required String listingId,
    required DateTime scheduledAtUtc,
    String? note,
  }) async {
    final result = await _requestViewing(
      listingId: listingId,
      scheduledAtUtc: scheduledAtUtc,
      note: note,
    );
    return result is Success;
  }

  /// Transitions a viewing then reloads the list (so the new status + the
  /// available actions re-render). Returns true on success.
  Future<bool> updateStatus({
    required String viewingId,
    required ViewingStatus status,
  }) async {
    final result = await _updateViewingStatus(
      viewingId: viewingId,
      status: status,
    );
    if (isClosed) return result is Success;
    if (result is Success) {
      await load();
      return true;
    }
    return false;
  }
}
