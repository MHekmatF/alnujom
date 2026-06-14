import 'package:injectable/injectable.dart';

import '../entities/area.dart';
import '../repositories/locations_repository.dart';

/// Lists EVERY active area (neighborhood) across all cities in one flat call.
///
/// Phase 031 (WS-D) — companion to [ListAllCities] for the smart-search
/// assistant's neighborhood matching. Each [Area] carries its `cityId`; the
/// brain maps that back to the owning city (and thus governorate) from the
/// cities list it already holds, so a matched area pins city + governorate too.
/// Mirrors [ListGovernorates] in shape (a single cached read); not scoped to
/// one city like [ListAreasForCity].
@injectable
class ListAllAreas {
  const ListAllAreas(this.repository);

  final LocationsRepository repository;

  Future<List<Area>> call({bool includeInactive = false}) =>
      repository.listAllAreas(includeInactive: includeInactive);
}
