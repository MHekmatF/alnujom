import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/market_trend_point.dart';
import '../../domain/repositories/market_insights_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum MarketInsightsStatus { initial, loading, loaded, empty, error }

/// Spec 028 — state for the listing-details "Market insights" section.
///
/// [points] hold ONLY the monthly buckets in the listing's own primary
/// currency, month-ascending. The section requires at least 3 such buckets to
/// be worth a chart — fewer collapses to [MarketInsightsStatus.empty].
class MarketInsightsState extends Equatable {
  const MarketInsightsState({
    this.status = MarketInsightsStatus.initial,
    this.points = const [],
  });

  final MarketInsightsStatus status;
  final List<MarketTrendPoint> points;

  MarketInsightsState copyWith({
    MarketInsightsStatus? status,
    List<MarketTrendPoint>? points,
  }) {
    return MarketInsightsState(
      status: status ?? this.status,
      points: points ?? this.points,
    );
  }

  @override
  List<Object?> get props => [status, points];
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

/// Spec 028 — drives the listing-details "Market insights" trend chart.
///
/// Factory-scoped (one per detail page); a simple load-once cubit fired by the
/// section widget with the listing's governorate / city / type / purpose and
/// its primary currency. The minimum-sample gate (>= 3 monthly points in the
/// primary currency) lives here so the widget only ever renders `loaded`.
@injectable
class MarketInsightsCubit extends Cubit<MarketInsightsState> {
  MarketInsightsCubit(this._repository) : super(const MarketInsightsState());

  /// Minimum monthly buckets (in the listing's primary currency) for the
  /// trend to be meaningful; fewer → [MarketInsightsStatus.empty].
  static const int _minMonthlyPoints = 3;

  final MarketInsightsRepository _repository;

  Future<void> load({
    required String governorateId,
    required String propertyType,
    required String currencyCode,
    String? cityId,
    String? purpose,
  }) async {
    if (state.status == MarketInsightsStatus.loading) return;
    emit(state.copyWith(status: MarketInsightsStatus.loading));

    final result = await _repository.fetchPriceTrend(
      governorateId: governorateId,
      propertyType: propertyType,
      cityId: cityId,
      purpose: purpose,
    );

    switch (result) {
      case Success<List<MarketTrendPoint>>():
        // Keep only the listing's own currency — mixing currencies on one
        // bar scale would be meaningless. The RPC orders month ASC.
        final points = result.value
            .where((p) => p.currencyCode == currencyCode)
            .toList(growable: false);
        emit(
          state.copyWith(
            status: points.length < _minMonthlyPoints
                ? MarketInsightsStatus.empty
                : MarketInsightsStatus.loaded,
            points: points,
          ),
        );
      case FailureResult<List<MarketTrendPoint>>():
        emit(state.copyWith(status: MarketInsightsStatus.error));
    }
  }
}
