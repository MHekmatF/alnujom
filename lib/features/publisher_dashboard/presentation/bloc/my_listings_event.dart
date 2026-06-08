import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart';

sealed class MyListingsEvent extends Equatable {
  const MyListingsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LoadMyListings extends MyListingsEvent {
  const LoadMyListings();
}

class ChangeStatusFilter extends MyListingsEvent {
  const ChangeStatusFilter(this.statusFilter);

  final ListingStatus? statusFilter;

  @override
  List<Object?> get props => [statusFilter];
}

class LoadMore extends MyListingsEvent {
  const LoadMore();
}

class Refresh extends MyListingsEvent {
  const Refresh();
}

/// Renews the listing identified by [listingId] for [days] days. On success the
/// bloc updates that listing's `expiresAt` in place and emits a one-shot
/// success signal so the page can show a confirmation snackbar.
class MyListingsRenewRequested extends MyListingsEvent {
  const MyListingsRenewRequested(this.listingId, {this.days = 30});

  final String listingId;
  final int days;

  @override
  List<Object?> get props => [listingId, days];
}
