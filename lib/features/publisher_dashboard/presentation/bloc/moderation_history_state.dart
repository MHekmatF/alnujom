import 'package:equatable/equatable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/moderation_history_entry.dart';

/// Phase 12 / US6 — state hierarchy for [ModerationHistoryCubit].
sealed class ModerationHistoryState extends Equatable {
  const ModerationHistoryState();
}

final class ModerationHistoryInitial extends ModerationHistoryState {
  const ModerationHistoryInitial();

  @override
  List<Object?> get props => [];
}

final class ModerationHistoryLoading extends ModerationHistoryState {
  const ModerationHistoryLoading();

  @override
  List<Object?> get props => [];
}

final class ModerationHistoryLoaded extends ModerationHistoryState {
  const ModerationHistoryLoaded(this.entries);

  final List<ModerationHistoryEntry> entries;

  @override
  List<Object?> get props => [entries];
}

final class ModerationHistoryError extends ModerationHistoryState {
  const ModerationHistoryError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
