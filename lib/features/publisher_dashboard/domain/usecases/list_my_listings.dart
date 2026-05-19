import 'package:injectable/injectable.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../entities/publisher_listing.dart';
import '../repositories/publisher_dashboard_repository.dart';

@injectable
class ListMyListings {
  const ListMyListings(this._repository);

  final PublisherDashboardRepository _repository;

  Future<List<PublisherListing>> call({
    ListingStatus? statusFilter,
    int offset = 0,
    int limit = 20,
  }) {
    return _repository.listMyListings(
      statusFilter: statusFilter,
      offset: offset,
      limit: limit,
    );
  }
}
