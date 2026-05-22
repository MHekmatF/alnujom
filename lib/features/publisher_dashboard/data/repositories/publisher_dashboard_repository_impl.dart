import 'package:injectable/injectable.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/publisher_listing.dart';
import '../../domain/repositories/publisher_dashboard_repository.dart';
import '../datasources/supabase_publisher_dashboard_datasource.dart';

@LazySingleton(as: PublisherDashboardRepository)
class PublisherDashboardRepositoryImpl implements PublisherDashboardRepository {
  PublisherDashboardRepositoryImpl(this._datasource);

  final SupabasePublisherDashboardDatasource _datasource;

  @override
  Future<List<PublisherListing>> listMyListings({
    ListingStatus? statusFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    final dtos = await _datasource.listMyListings(
      statusFilter: statusFilter?.toDbValue(),
      offset: offset,
      limit: limit,
    );
    return dtos.map((d) => d.toEntity()).toList();
  }
}
