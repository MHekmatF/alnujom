// lib/features/inquiries/presentation/bloc/inquiry_detail_event.dart
part of 'inquiry_detail_bloc.dart';

sealed class InquiryDetailEvent extends Equatable {
  const InquiryDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched when the detail page mounts with a specific inquiry id.
final class InquiryDetailOpened extends InquiryDetailEvent {
  const InquiryDetailOpened(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Transition: current status → responded.
final class MarkResponded extends InquiryDetailEvent {
  const MarkResponded();
}

/// Transition: current status → closed.
final class MarkClosed extends InquiryDetailEvent {
  const MarkClosed();
}

/// Reopen (closed/responded → seen). Per Q2=B reopen path.
final class ReopenToSeen extends InquiryDetailEvent {
  const ReopenToSeen();
}

/// Reopen directly to responded (closed → responded). Per Q2=B.
final class ReopenToResponded extends InquiryDetailEvent {
  const ReopenToResponded();
}
