import 'package:injectable/injectable.dart';

import '../../../../core/storage/install_id.dart';
import '../repositories/listing_details_repository.dart';

/// Plan A35 — tell the server this listing was opened.
///
/// Fire-and-forget from [ListingDetailsBloc] once the aggregate loads. The
/// server keeps one row per viewer per listing per day, ignores the publisher
/// opening their own listing, and ignores anything not approved; the app
/// just sends the install id so a guest counts as one viewer.
@injectable
class RecordListingView {
  const RecordListingView(this._repository, this._installId);

  final ListingDetailsRepository _repository;
  final InstallId _installId;

  Future<void> call(String listingId) async {
    final key = await _installId.get();
    await _repository.recordView(listingId, viewerKey: key);
  }
}
