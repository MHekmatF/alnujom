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
