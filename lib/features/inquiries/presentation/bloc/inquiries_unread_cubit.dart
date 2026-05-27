// lib/features/inquiries/presentation/bloc/inquiries_unread_cubit.dart
//
// Phase 16 Sub-Phase F (T072) — Singleton Cubit tracking the count of unread
// (status='new') inquiries. Shared between the home AppBar action widget and
// the InquiryDetailBloc (which calls decrement() on new→seen auto-transition).
//
// canShowEntry gate: simpler `count > 0` approach chosen over the "owns ≥1
// approved listing" Supabase check. Rationale: if a publisher has no
// inquiries, the badge hides regardless. The listing-ownership query adds
// latency without meaningful UX benefit at this MVP stage.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/usecases/load_inbox_unread_count.dart';

part 'inquiries_unread_state.dart';

@lazySingleton
class InquiriesUnreadCubit extends Cubit<InquiriesUnreadState> {
  InquiriesUnreadCubit(this._loadUnreadCount)
      : super(const InquiriesUnreadState(count: 0, canShowEntry: false));

  final LoadInboxUnreadCount _loadUnreadCount;

  /// Re-fetches the server-side unread count and updates [canShowEntry].
  Future<void> refresh() async {
    final result = await _loadUnreadCount();
    if (result case Success<int>(:final value)) {
      emit(
        InquiriesUnreadState(
          count: value,
          // canShowEntry = (count > 0): the badge is shown when there are
          // unread inquiries. This is the simplest gate per the inline
          // reasoning in the T072 design note.
          canShowEntry: value > 0,
        ),
      );
    }
    // On failure: silently keep previous state — the badge simply doesn't
    // update until the next successful refresh().
  }

  /// Optimistically decrements the unread count by 1.
  /// Called by [InquiryDetailBloc] after the auto new→seen transition.
  void decrement() {
    final newCount = (state.count - 1).clamp(0, double.maxFinite.toInt());
    emit(
      InquiriesUnreadState(
        count: newCount,
        canShowEntry: newCount > 0,
      ),
    );
  }
}
