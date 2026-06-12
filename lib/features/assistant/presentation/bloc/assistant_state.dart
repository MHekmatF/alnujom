// lib/features/assistant/presentation/bloc/assistant_state.dart
//
// Phase 28 (WS-6) — smart search assistant: cubit state (part of
// assistant_cubit.dart, mirroring the chat feature's part-file idiom).

part of 'assistant_cubit.dart';

class AssistantState extends Equatable {
  const AssistantState({required this.messages, required this.thinking});

  /// Fresh transcript: the localized greeting bubble is rendered from the
  /// structured [AssistantReplyKind.greeting] marker at build time.
  const AssistantState.initial()
    : messages = const [AssistantMessage.greeting()],
      thinking = false;

  final List<AssistantMessage> messages;

  /// True while the brain is composing a reply — renders the typing bubble
  /// and gates re-entrant sends.
  final bool thinking;

  /// Quick-reply suggestion chips show only on a fresh transcript.
  bool get isFresh => messages.length <= 1;

  @override
  List<Object?> get props => [messages, thinking];
}
