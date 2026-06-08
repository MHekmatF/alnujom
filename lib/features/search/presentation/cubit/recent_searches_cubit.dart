// lib/features/search/presentation/cubit/recent_searches_cubit.dart
//
// Phase 25 premium uplift — drives the "Recent searches" surface shown when
// the search bar is focused + empty. Backed by [RecentSearchesStorage]
// (flutter_secure_storage). State is a plain immutable list of query strings
// (newest-first); the page reads it via a BlocBuilder.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/datasources/recent_searches_storage.dart';

class RecentSearchesState extends Equatable {
  const RecentSearchesState({this.queries = const [], this.loaded = false});

  /// Recent free-text queries, newest-first.
  final List<String> queries;

  /// False until the first [RecentSearchesCubit.load] completes — lets the UI
  /// avoid flashing an empty state before storage is read.
  final bool loaded;

  RecentSearchesState copyWith({List<String>? queries, bool? loaded}) =>
      RecentSearchesState(
        queries: queries ?? this.queries,
        loaded: loaded ?? this.loaded,
      );

  @override
  List<Object?> get props => [queries, loaded];
}

@injectable
class RecentSearchesCubit extends Cubit<RecentSearchesState> {
  RecentSearchesCubit(this._storage) : super(const RecentSearchesState());

  final RecentSearchesStorage _storage;

  Future<void> load() async {
    final queries = await _storage.read();
    if (isClosed) return;
    emit(RecentSearchesState(queries: queries, loaded: true));
  }

  /// Records a committed query (called when the user submits a search).
  Future<void> record(String query) async {
    final queries = await _storage.add(query);
    if (isClosed) return;
    emit(RecentSearchesState(queries: queries, loaded: true));
  }

  Future<void> clear() async {
    await _storage.clear();
    if (isClosed) return;
    emit(const RecentSearchesState(queries: [], loaded: true));
  }
}
