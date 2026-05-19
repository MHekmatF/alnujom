import '../../../listing_form/domain/entities/listing.dart';
import '../entities/publisher_listing.dart';

abstract class PublisherDashboardRepository {
  Future<List<PublisherListing>> listMyListings({
    ListingStatus? statusFilter,
    int offset = 0,
    int limit = 20,
  });
}
