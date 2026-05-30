// lib/features/agency/presentation/bloc/agency_listings_state.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T049).
part of 'agency_listings_bloc.dart';

sealed class AgencyListingsState {
  const AgencyListingsState();
}

final class AgencyListingsLoading extends AgencyListingsState {
  const AgencyListingsLoading();
}

final class AgencyListingsLoaded extends AgencyListingsState {
  const AgencyListingsLoaded({required this.items, required this.hasMore});

  /// Raw `v_listings_public` rows (id, title, primary_amount, primary_currency,
  /// main_image_path, published_at, agency_name, agency_logo_path, ...).
  final List<Map<String, dynamic>> items;
  final bool hasMore;
}

final class AgencyListingsError extends AgencyListingsState {
  const AgencyListingsError();
}
