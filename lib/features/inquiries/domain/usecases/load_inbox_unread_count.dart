import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/inquiry_repository.dart';

@injectable
class LoadInboxUnreadCount {
  const LoadInboxUnreadCount(this._repository);

  final InquiryRepository _repository;

  /// Returns the count of `status='new'` inquiries on the current user's listings.
  Future<Result<int>> call() => _repository.loadUnreadCount();
}
