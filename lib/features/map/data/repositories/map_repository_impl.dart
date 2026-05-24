// lib/features/map/data/repositories/map_repository_impl.dart
//
// Phase 15 — concrete [MapRepository] delegating to [SupabaseMapDatasource].
// Wraps any transport / RPC exception in a typed [Failure] per Phase 14's
// [SearchRepositoryImpl] pattern.
//
// Per Constitution IX this file MUST NOT import the supabase_flutter package
// — the datasource is the sole importer.
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../../domain/entities/map_marker.dart';
import '../../domain/repositories/map_repository.dart';
import '../datasources/supabase_map_datasource.dart';

@Injectable(as: MapRepository)
class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl(this._datasource);

  final SupabaseMapDatasource _datasource;

  @override
  Future<Result<List<MapMarker>>> loadMarkers({FilterState? filter}) async {
    try {
      final markers = filter == null
          ? await _datasource.loadAll()
          : await _datasource.loadFiltered(filter);
      return Success(markers);
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('Map markers load failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
