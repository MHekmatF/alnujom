// lib/features/agency/presentation/bloc/agency_listings_bloc.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T049).
// Paginated BLoC for AgencyListingsPage / the public AgencyProfilePage feed.
// Events: Opened / MoreLoaded / Refresh. Cursor on published_at DESC, limit 30.
// Mirrors MyReportsBloc / FavoritesPageBloc (keyset cursor on an ISO timestamp).
// Zero Supabase imports (Constitution IX).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/usecases/load_agency_listings.dart';

part 'agency_listings_state.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

sealed class AgencyListingsEvent {
  const AgencyListingsEvent();
}

final class AgencyListingsOpened extends AgencyListingsEvent {
  const AgencyListingsOpened(this.agencyId);
  final String agencyId;
}

final class AgencyListingsRefreshRequested extends AgencyListingsEvent {
  const AgencyListingsRefreshRequested(this.agencyId);
  final String agencyId;
}

final class AgencyListingsMoreLoaded extends AgencyListingsEvent {
  const AgencyListingsMoreLoaded(this.agencyId);
  final String agencyId;
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------

@injectable
class AgencyListingsBloc extends Bloc<AgencyListingsEvent, AgencyListingsState> {
  AgencyListingsBloc(this._loadAgencyListings)
      : super(const AgencyListingsLoading()) {
    on<AgencyListingsOpened>(_onOpened);
    on<AgencyListingsRefreshRequested>(_onRefresh);
    on<AgencyListingsMoreLoaded>(_onMoreLoaded);
  }

  final LoadAgencyListings _loadAgencyListings;

  static const int _pageSize = 30;

  Future<void> _onOpened(
    AgencyListingsOpened event,
    Emitter<AgencyListingsState> emit,
  ) async {
    emit(const AgencyListingsLoading());
    await _fetchFirstPage(event.agencyId, emit);
  }

  Future<void> _onRefresh(
    AgencyListingsRefreshRequested event,
    Emitter<AgencyListingsState> emit,
  ) async {
    emit(const AgencyListingsLoading());
    await _fetchFirstPage(event.agencyId, emit);
  }

  Future<void> _onMoreLoaded(
    AgencyListingsMoreLoaded event,
    Emitter<AgencyListingsState> emit,
  ) async {
    final current = state;
    if (current is! AgencyListingsLoaded || !current.hasMore) return;

    final cursor = current.items.isNotEmpty
        ? current.items.last['published_at'] as String?
        : null;

    final result = await _loadAgencyListings(
      agencyId: event.agencyId,
      cursor: cursor,
      limit: _pageSize,
    );
    if (result is Success<List<Map<String, dynamic>>>) {
      final newItems = result.value;
      emit(
        AgencyListingsLoaded(
          items: [...current.items, ...newItems],
          hasMore: newItems.length == _pageSize,
        ),
      );
    }
    // On pagination error: silently keep the current page.
  }

  Future<void> _fetchFirstPage(
    String agencyId,
    Emitter<AgencyListingsState> emit,
  ) async {
    final result = await _loadAgencyListings(
      agencyId: agencyId,
      cursor: null,
      limit: _pageSize,
    );
    switch (result) {
      case Success<List<Map<String, dynamic>>>(:final value):
        emit(
          AgencyListingsLoaded(
            items: value,
            hasMore: value.length == _pageSize,
          ),
        );
      case FailureResult<List<Map<String, dynamic>>>():
        emit(const AgencyListingsError());
    }
  }
}
