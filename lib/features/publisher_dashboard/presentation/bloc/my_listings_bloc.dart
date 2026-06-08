import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/publisher_listing.dart';
import '../../domain/usecases/list_my_listings.dart';
import '../../domain/usecases/renew_listing.dart';
import 'my_listings_event.dart';
import 'my_listings_state.dart';

const int _pageSize = 20;

@injectable
class MyListingsBloc extends Bloc<MyListingsEvent, MyListingsState> {
  MyListingsBloc(this._listMyListings, this._renewListing)
    : super(const MyListingsState()) {
    on<LoadMyListings>(_onLoad);
    on<ChangeStatusFilter>(_onChangeFilter);
    on<LoadMore>(_onLoadMore);
    on<Refresh>(_onRefresh);
    on<MyListingsRenewRequested>(_onRenewRequested);
  }

  final ListMyListings _listMyListings;
  final RenewListing _renewListing;

  Future<void> _onLoad(
    LoadMyListings event,
    Emitter<MyListingsState> emit,
  ) async {
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      final rows = await _listMyListings(
        statusFilter: state.statusFilter,
        offset: 0,
        limit: _pageSize,
      );
      emit(
        state.copyWith(
          loading: false,
          listings: rows,
          endReached: rows.length < _pageSize,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onChangeFilter(
    ChangeStatusFilter event,
    Emitter<MyListingsState> emit,
  ) async {
    emit(
      state.copyWith(
        statusFilter: event.statusFilter,
        loading: true,
        listings: const [],
        endReached: false,
        errorMessage: null,
      ),
    );
    try {
      final rows = await _listMyListings(
        statusFilter: event.statusFilter,
        offset: 0,
        limit: _pageSize,
      );
      emit(
        state.copyWith(
          loading: false,
          listings: rows,
          endReached: rows.length < _pageSize,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMore(
    LoadMore event,
    Emitter<MyListingsState> emit,
  ) async {
    if (state.loadingMore || state.endReached || state.loading) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final rows = await _listMyListings(
        statusFilter: state.statusFilter,
        offset: state.listings.length,
        limit: _pageSize,
      );
      emit(
        state.copyWith(
          loadingMore: false,
          listings: [...state.listings, ...rows],
          endReached: rows.length < _pageSize,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingMore: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRefresh(Refresh event, Emitter<MyListingsState> emit) async {
    emit(state.copyWith(refreshing: true, errorMessage: null));
    try {
      final rows = await _listMyListings(
        statusFilter: state.statusFilter,
        offset: 0,
        limit: _pageSize,
      );
      emit(
        state.copyWith(
          refreshing: false,
          listings: rows,
          endReached: rows.length < _pageSize,
        ),
      );
    } catch (e) {
      emit(state.copyWith(refreshing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRenewRequested(
    MyListingsRenewRequested event,
    Emitter<MyListingsState> emit,
  ) async {
    if (state.renewingId != null) return;
    emit(state.copyWith(renewingId: event.listingId));
    final result = await _renewListing(
      listingId: event.listingId,
      days: event.days,
    );
    switch (result) {
      case Success<DateTime?>(value: final newExpiresAt):
        // Update the renewed listing's expiresAt in place so the expiry
        // indicator + Renew button recompute without a full reload.
        final updated = state.listings
            .map(
              (pl) => pl.listing.id == event.listingId
                  ? PublisherListing(
                      listing: pl.listing.copyWith(expiresAt: newExpiresAt),
                      latestStatusHistoryEntry: pl.latestStatusHistoryEntry,
                      primaryPrice: pl.primaryPrice,
                    )
                  : pl,
            )
            .toList(growable: false);
        emit(
          state.copyWith(
            renewingId: null,
            listings: updated,
            renewSuccessToken: state.renewSuccessToken + 1,
          ),
        );
      case FailureResult<DateTime?>():
        emit(
          state.copyWith(
            renewingId: null,
            renewErrorToken: state.renewErrorToken + 1,
          ),
        );
    }
  }
}
