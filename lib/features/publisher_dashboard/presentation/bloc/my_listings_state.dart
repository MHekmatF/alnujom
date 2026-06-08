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
  ];
}

const Object _sentinel = Object();
