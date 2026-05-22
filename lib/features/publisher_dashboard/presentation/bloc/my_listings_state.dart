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
  });

  final bool loading;
  final bool loadingMore;
  final bool refreshing;
  final ListingStatus? statusFilter;
  final List<PublisherListing> listings;
  final bool endReached;
  final String? errorMessage;

  MyListingsState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? refreshing,
    Object? statusFilter = _sentinel,
    List<PublisherListing>? listings,
    bool? endReached,
    Object? errorMessage = _sentinel,
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
  ];
}

const Object _sentinel = Object();
