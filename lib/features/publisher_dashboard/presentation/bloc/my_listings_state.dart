import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/publisher_listing.dart';

class MyListingsState extends Equatable {
  const MyListingsState({
    this.loading = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.statusFilter,
    this.listings = const <PublisherListing>[],
    this.endReached = false,
    this.errorMessage,
    this.renewingId,
    this.renewSuccessToken = 0,
    this.renewErrorToken = 0,
    this.statusChangingId,
    this.statusChangeSuccessToken = 0,
    this.statusChangeErrorToken = 0,
    this.lastStatusChange,
  });

  final bool loading;
  final bool loadingMore;
  final bool refreshing;
  final ListingStatus? statusFilter;
  final List<PublisherListing> listings;
  final bool endReached;
  final String? errorMessage;

  /// The listing id currently being renewed (null when idle). Drives the
  /// per-card Renew button's loading spinner.
  final String? renewingId;

  /// Monotonic one-shot signal: increments on each successful renew so the
  /// page can fire a confirmation snackbar via `BlocListener`.
  final int renewSuccessToken;

  /// Monotonic one-shot signal: increments on each failed renew so the page
  /// can surface an error snackbar.
  final int renewErrorToken;

  /// The listing id whose status is being changed (null when idle). Disables
  /// the card's action menu while the RPC is in flight.
  final String? statusChangingId;

  /// One-shot signals for the status change, mirroring the renew pair.
  final int statusChangeSuccessToken;
  final int statusChangeErrorToken;

  /// The status the last change moved to, so the confirmation can name it —
  /// "marked sold" reads better than "done".
  final ListingStatus? lastStatusChange;

  MyListingsState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? refreshing,
    Object? statusFilter = _sentinel,
    List<PublisherListing>? listings,
    bool? endReached,
    Object? errorMessage = _sentinel,
    Object? renewingId = _sentinel,
    int? renewSuccessToken,
    int? renewErrorToken,
    Object? statusChangingId = _sentinel,
    int? statusChangeSuccessToken,
    int? statusChangeErrorToken,
    Object? lastStatusChange = _sentinel,
  }) {
    return MyListingsState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      refreshing: refreshing ?? this.refreshing,
      statusFilter: identical(statusFilter, _sentinel)
          ? this.statusFilter
          : statusFilter as ListingStatus?,
      listings: listings ?? this.listings,
      endReached: endReached ?? this.endReached,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      renewingId: identical(renewingId, _sentinel)
          ? this.renewingId
          : renewingId as String?,
      renewSuccessToken: renewSuccessToken ?? this.renewSuccessToken,
      renewErrorToken: renewErrorToken ?? this.renewErrorToken,
      statusChangingId: identical(statusChangingId, _sentinel)
          ? this.statusChangingId
          : statusChangingId as String?,
      statusChangeSuccessToken:
          statusChangeSuccessToken ?? this.statusChangeSuccessToken,
      statusChangeErrorToken:
          statusChangeErrorToken ?? this.statusChangeErrorToken,
      lastStatusChange: identical(lastStatusChange, _sentinel)
          ? this.lastStatusChange
          : lastStatusChange as ListingStatus?,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    loadingMore,
    refreshing,
    statusFilter,
    listings,
    endReached,
    errorMessage,
    renewingId,
    renewSuccessToken,
    renewErrorToken,
    statusChangingId,
    statusChangeSuccessToken,
    statusChangeErrorToken,
    lastStatusChange,
  ];
}

const Object _sentinel = Object();
