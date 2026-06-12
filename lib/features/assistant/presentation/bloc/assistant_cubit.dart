// lib/features/assistant/presentation/bloc/assistant_cubit.dart
//
// Phase 28 (WS-6) — smart search assistant: transcript cubit. send(input)
// appends the user message, runs the (swappable) [AssistantBrain] and appends
// its structured reply. The brain is local-first, so "thinking" is usually a
// single frame — except on the optional stats-RPC path.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/assistant_brain.dart';
import '../../domain/entities/assistant_message.dart';

part 'assistant_state.dart';

@injectable
class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit(this._brain) : super(const AssistantState.initial());

  final AssistantBrain _brain;

  /// Appends the user's message and the brain's reply. Blank input and
  /// re-entrant sends (while a reply is pending) are no-ops.
  Future<void> send(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty || state.thinking) return;

    emit(
      AssistantState(
        messages: [...state.messages, AssistantMessage.user(trimmed)],
        thinking: true,
      ),
    );

    AssistantReply reply;
    try {
      reply = await _brain.handle(trimmed);
    } catch (_) {
      // The brain already degrades internally; this is a last-resort guard so
      // the transcript never wedges in "thinking".
      reply = const AssistantReply(kind: AssistantReplyKind.noMatch);
    }
    if (isClosed) return;

    emit(
      AssistantState(
        messages: [...state.messages, AssistantMessage.assistant(reply)],
        thinking: false,
      ),
    );
  }
}
