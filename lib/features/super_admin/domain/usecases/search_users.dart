import 'package:injectable/injectable.dart';

import '../entities/user_search_result.dart';
import '../repositories/user_search_repository.dart';

@injectable
class SearchUsers {
  const SearchUsers(this._repo);

  final UserSearchRepository _repo;

  Future<List<UserSearchResult>> call(String query) => _repo.searchUsers(query);
}
