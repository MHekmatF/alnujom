import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../currencies/domain/usecases/list_currencies.dart';
import '../../domain/entities/similar_listing_card.dart';
import '../../domain/usecases/load_similar_listings.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum SimilarListingsStatus { initial, loading, loaded, empty, error }

/// Premium uplift v2 — state for the "similar listings" carousel.
///
/// [currenciesByCode] is loaded alongside the cards so the compact card can
/// format the primary price without a page-level FutureBuilder.
class SimilarListingsState extends Equatable {
  const SimilarListingsState({
    this.status = SimilarListingsStatus.initial,
    this.cards = const [],
    this.currenciesByCode = const {},
  });

  final SimilarListingsStatus status;
  final List<SimilarListingCard> cards;
  final Map<String, Currency> currenciesByCode;

  SimilarListingsState copyWith({
    SimilarListingsStatus? status,
    List<SimilarListingCard>? cards,
    Map<String, Currency>? currenciesByCode,
  }) {
    return SimilarListingsState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      currenciesByCode: currenciesByCode ?? this.currenciesByCode,
    );
  }

  @override
  List<Object?> get props => [status, cards, currenciesByCode];
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

/// Premium uplift v2 — drives the listing-detail "similar listings" carousel.
///
/// Factory-scoped (one per detail page); [load] is called once the detail
/// aggregate is available (it needs the source's property type + governorate).
@injectable
class SimilarListingsCubit extends Cubit<SimilarListingsState> {
  SimilarListingsCubit(this._loadSimilarListings, this._listCurrencies)
    : super(const SimilarListingsState());

  final LoadSimilarListings _loadSimilarListings;
  final ListCurrencies _listCurrencies;

  Future<void> load({
    required String listingId,
    required String propertyType,
    String? governorateId,
    required Locale locale,
  }) async {
    if (state.status == SimilarListingsStatus.loading) return;
    emit(state.copyWith(status: SimilarListingsStatus.loading));

    // Resolve the currency catalog in parallel with the cards (best-effort; an
    // empty catalog just falls back to a code-suffixed amount in the card).
    final currenciesFuture = _listCurrencies(activeOnly: false);
    final result = await _loadSimilarListings(
      listingId: listingId,
      propertyType: propertyType,
      governorateId: governorateId,
      locale: locale,
    );

    var currenciesByCode = <String, Currency>{};
    try {
      final currencies = await currenciesFuture;
      currenciesByCode = {for (final c in currencies) c.code: c};
    } on Object {
      currenciesByCode = const {};
    }

    switch (result) {
      case Success<List<SimilarListingCard>>():
        final cards = result.value;
        emit(
          state.copyWith(
            status: cards.isEmpty
                ? SimilarListingsStatus.empty
                : SimilarListingsStatus.loaded,
            cards: cards,
            currenciesByCode: currenciesByCode,
          ),
        );
      case FailureResult<List<SimilarListingCard>>():
        emit(state.copyWith(status: SimilarListingsStatus.error));
    }
  }
}
