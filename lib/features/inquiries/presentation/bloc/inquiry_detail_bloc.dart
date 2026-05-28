// lib/features/inquiries/presentation/bloc/inquiry_detail_bloc.dart
//
// Phase 16 Sub-Phase F (T070) — BLoC driving the InquiryDetailPage.
// On open, auto-transitions new→seen and decrements the unread cubit.
// Optimistic state for mutations; rolls back on failure.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';
import '../../domain/usecases/load_inquiry_detail.dart';
import '../../domain/usecases/update_inquiry_status.dart';
import 'inquiries_unread_cubit.dart';

part 'inquiry_detail_event.dart';
part 'inquiry_detail_state.dart';

@injectable
class InquiryDetailBloc extends Bloc<InquiryDetailEvent, InquiryDetailState> {
  InquiryDetailBloc(
    this._loadDetail,
    this._updateStatus,
    this._unreadCubit,
  ) : super(const InquiryDetailLoading()) {
    on<InquiryDetailOpened>(_onOpened);
    on<MarkResponded>(_onMarkResponded);
    on<MarkClosed>(_onMarkClosed);
    on<ReopenToSeen>(_onReopenToSeen);
    on<ReopenToResponded>(_onReopenToResponded);
  }

  final LoadInquiryDetail _loadDetail;
  final UpdateInquiryStatus _updateStatus;
  final InquiriesUnreadCubit _unreadCubit;

  Future<void> _onOpened(
    InquiryDetailOpened event,
    Emitter<InquiryDetailState> emit,
  ) async {
    emit(const InquiryDetailLoading());

    final result = await _loadDetail(event.id);

    switch (result) {
      case Success<Inquiry>(:final value):
        Inquiry inquiry = value;

        // FR-021 auto-transition: new → seen on first open — ONLY for the
        // listing's publisher. Admins/senders viewing via oversight are
        // read-only (the RLS update policy would block them anyway).
        if (inquiry.status == InquiryStatus.new_ && inquiry.viewerIsPublisher) {
          final transitionResult = await _updateStatus(
            inquiry.id,
            InquiryStatus.seen,
          );
          if (transitionResult is Success<void>) {
            inquiry = inquiry.copyWith(status: InquiryStatus.seen);
            _unreadCubit.decrement();
          }
          // On transition failure: keep new_ status — the trigger will block
          // an invalid transition; we still emit Loaded with original status.
        }
        emit(InquiryDetailLoaded(inquiry: inquiry));

      case FailureResult<Inquiry>(:final failure):
        emit(InquiryDetailError(failure));
    }
  }

  Future<void> _onMarkResponded(
    MarkResponded event,
    Emitter<InquiryDetailState> emit,
  ) => _mutate(emit, InquiryStatus.responded);

  Future<void> _onMarkClosed(
    MarkClosed event,
    Emitter<InquiryDetailState> emit,
  ) => _mutate(emit, InquiryStatus.closed);

  Future<void> _onReopenToSeen(
    ReopenToSeen event,
    Emitter<InquiryDetailState> emit,
  ) => _mutate(emit, InquiryStatus.seen);

  Future<void> _onReopenToResponded(
    ReopenToResponded event,
    Emitter<InquiryDetailState> emit,
  ) => _mutate(emit, InquiryStatus.responded);

  Future<void> _mutate(
    Emitter<InquiryDetailState> emit,
    InquiryStatus targetStatus,
  ) async {
    if (state is! InquiryDetailLoaded) return;
    final loaded = state as InquiryDetailLoaded;
    final previousInquiry = loaded.inquiry;

    // Optimistic update.
    emit(
      InquiryDetailLoaded(
        inquiry: previousInquiry.copyWith(status: targetStatus),
      ),
    );

    final result = await _updateStatus(previousInquiry.id, targetStatus);

    if (result case FailureResult<void>()) {
      // Roll back to previous state.
      emit(InquiryDetailLoaded(inquiry: previousInquiry));
    }
  }
}
