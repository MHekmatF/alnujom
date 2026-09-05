import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/publisher_listing.dart';
import '../../domain/usecases/list_my_listings.dart';
import '../../domain/usecases/renew_listing.dart';
import '../../domain/usecases/set_own_listing_status.dart';
import 'my_listings_event.dart';
import 'my_listings_state.dart';

const int _pageSize = 20;

@injectable
class MyListingsBloc extends Bloc<MyListingsEvent, MyListingsState> {
  MyListingsBloc(
    this._listMyListings,
    this._renewListing,
    this._setOwnListingStatus,
  ) : super(const MyListingsState()) {
    on<LoadMyListings>(_onLoad);
    on<ChangeStatusFilter>(_onChangeFilter);
    on<LoadMore>(_onLoadMore);
    on<Refresh>(_onRefresh);
    on<MyListingsRenewRequested>(_onRenewRequested);
    on<MyListingsStatusChangeRequested>(_onStatusChangeRequested);
  }

  final ListMyListings _listMyListings;
  final RenewListing _renewListing;
  final SetOwnListingStatus _setOwnListingStatus;

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
                      viewsCount: pl.viewsCount,
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

  /// Marks a listing sold / rented / paused, re-publishes it, or soft-deletes
  /// it. On success the row is updated in place rather than re-fetched, so the
  /// list does not jump — and it is dropped entirely when it no longer belongs
  /// in the current tab (deleted always; a status filter it no longer matches).
  Future<void> _onStatusChangeRequested(
    MyListingsStatusChangeRequested event,
    Emitter<MyListingsState> emit,
  ) async {
    if (state.statusChangingId != null) return;
    emit(state.copyWith(statusChangingId: event.listingId));

    final result = await _setOwnListingStatus(
      listingId: event.listingId,
      status: event.status,
    );

    switch (result) {
      case Success<void>():
        final leavesTheList =
            event.status == ListingStatus.deleted ||
            (state.statusFilter != null && state.statusFilter != event.status);
        final updated = <PublisherListing>[
          for (final pl in state.listings)
            if (pl.listing.id != event.listingId)
              pl
            else if (!leavesTheList)
              PublisherListing(
                listing: pl.listing.copyWith(status: event.status),
                latestStatusHistoryEntry: pl.latestStatusHistoryEntry,
                primaryPrice: pl.primaryPrice,
                viewsCount: pl.viewsCount,
              ),
        ];
        emit(
          state.copyWith(
            statusChangingId: null,
            listings: updated,
            lastStatusChange: event.status,
            statusChangeSuccessToken: state.statusChangeSuccessToken + 1,
          ),
        );
      case FailureResult<void>():
        emit(
          state.copyWith(
            statusChangingId: null,
            statusChangeErrorToken: state.statusChangeErrorToken + 1,
          ),
        );
    }
  }
}
