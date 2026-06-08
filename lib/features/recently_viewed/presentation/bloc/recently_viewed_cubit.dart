import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/local/recently_viewed_store.dart';
import '../../domain/entities/recently_viewed_listing.dart';

/// Presentation-state holder for the Home "recently viewed" row.
///
/// State is simply the current list of [RecentlyViewedListing] (most-recent-
/// first); an empty list means the row hides itself. Backed by
/// [RecentlyViewedStore] (flutter_secure_storage). A `@lazySingleton` so the
/// Home row and the listing-details record-on-view path share one instance and
/// stay in sync without a stream subscription.
@lazySingleton
class RecentlyViewedCubit extends Cubit<List<RecentlyViewedListing>> {
  RecentlyViewedCubit(this._store) : super(const <RecentlyViewedListing>[]);

  final RecentlyViewedStore _store;

  /// Loads the persisted list into state. Safe to call repeatedly (e.g. each
  /// time Home opens); read failures surface as an empty list.
  Future<void> load() async {
    final items = await _store.read();
    if (isClosed) return;
    emit(items);
  }

  /// Records [item] as the newest viewed listing (de-duped by id, capped,
  /// most-recent-first) and emits the new list. Best-effort: a persistence
  /// failure leaves the prior state intact.
  Future<void> record(RecentlyViewedListing item) async {
    final items = await _store.record(item);
    if (isClosed) return;
    emit(items);
  }

  /// Resolves a `listing-images` storage path to a public URL (delegated to the
  /// data layer so callers never import Supabase). Returns null on failure.
  String? resolveImageUrl(String? storagePath) =>
      _store.resolveImageUrl(storagePath);
}
