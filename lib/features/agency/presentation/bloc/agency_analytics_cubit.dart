// lib/features/agency/presentation/bloc/agency_analytics_cubit.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T049).
// Loads the bounded analytics counters (member count + listing-by-status) for
// an agency. Zero Supabase imports (Constitution IX).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/usecases/load_agency_analytics.dart';

sealed class AgencyAnalyticsState {
  const AgencyAnalyticsState();
}

final class AgencyAnalyticsLoading extends AgencyAnalyticsState {
  const AgencyAnalyticsLoading();
}

final class AgencyAnalyticsLoaded extends AgencyAnalyticsState {
  const AgencyAnalyticsLoaded(this.analytics);
  final AgencyAnalytics analytics;
}

final class AgencyAnalyticsErrorState extends AgencyAnalyticsState {
  const AgencyAnalyticsErrorState();
}

@injectable
class AgencyAnalyticsCubit extends Cubit<AgencyAnalyticsState> {
  AgencyAnalyticsCubit(this._loadAnalytics)
      : super(const AgencyAnalyticsLoading());

  final LoadAgencyAnalytics _loadAnalytics;

  Future<void> load(String agencyId) async {
    emit(const AgencyAnalyticsLoading());
    final result = await _loadAnalytics(agencyId);
    if (isClosed) return;
    switch (result) {
      case Success<AgencyAnalytics>(:final value):
        emit(AgencyAnalyticsLoaded(value));
      case FailureResult<AgencyAnalytics>():
        emit(const AgencyAnalyticsErrorState());
    }
  }
}
