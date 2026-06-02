// lib/features/ads/presentation/bloc/ad_slot_cubit.dart
//
// Phase 21 (spec/021-ads-banners) — AdSlotCubit (T031).
//
// Loads eligible [ServingAd]s for a given [AdPlacement] via [LoadServingAds]
// and exposes a typed [AdSlotState] to [AdSlot].
//
// States:
//   AdSlotInitial       — not yet loaded.
//   AdSlotEmpty         — query returned 0 ads → [AdSlot] renders SizedBox.shrink().
//   AdSlotSingle        — exactly 1 ad → static banner, no timer.
//   AdSlotCarousel      — ≥2 ads → priority-ordered carousel with auto-advance.
//   AdSlotError         — network / datasource failure → [AdSlot] renders SizedBox.shrink().
//
// Registered as @injectable (factory — one cubit per AdSlot widget, not a
// singleton, so each placement manages its own load independently).

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/serving_ad.dart';
import '../../domain/usecases/load_serving_ads.dart';

part 'ad_slot_state.dart';

@injectable
class AdSlotCubit extends Cubit<AdSlotState> {
  AdSlotCubit(this._loadServingAds) : super(const AdSlotInitial());

  final LoadServingAds _loadServingAds;

  /// Loads eligible ads for [placement]. Called once from [AdSlot]'s initState.
  Future<void> load(AdPlacement placement) async {
    final result = await _loadServingAds(placement);
    if (isClosed) return;
    if (result is Success<List<ServingAd>>) {
      final ads = result.value;
      if (ads.isEmpty) {
        emit(const AdSlotEmpty());
      } else if (ads.length == 1) {
        emit(AdSlotSingle(ad: ads.first));
      } else {
        emit(AdSlotCarousel(ads: ads));
      }
    } else {
      emit(const AdSlotError());
    }
  }
}
