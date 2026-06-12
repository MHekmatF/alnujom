// lib/features/assistant/domain/entities/assistant_message.dart
//
// Phase 28 (WS-6) — smart search assistant: chat transcript entities.
//
// Assistant replies are STRUCTURED ([AssistantReply]), not pre-rendered text:
// the domain layer never touches l10n, so the page composes the localized
// sentence from [AssistantReplyKind] + the attached [ParsedQuery]/[AreaStats]
// at render time (and re-renders correctly if the locale changes mid-session).

import 'package:equatable/equatable.dart';

import 'area_stats.dart';
import 'parsed_query.dart';

enum AssistantRole { user, assistant }

enum AssistantReplyKind {
  /// The canned welcome bubble seeded when the page opens.
  greeting,

  /// At least one filter dimension was recognized — render the summary,
  /// the matched-fragment chips and the "Show results" CTA.
  parsed,

  /// Nothing recognized — render the gentle fallback with examples.
  noMatch,

  /// A market-stats question was answered via the `market_area_stats` RPC.
  stats,
}

class AssistantReply extends Equatable {
  const AssistantReply({required this.kind, this.parsed, this.stats});

  final AssistantReplyKind kind;

  /// Present for [AssistantReplyKind.parsed] and [AssistantReplyKind.stats]
  /// (the stats path still carries the parse so the chips + "Show results"
  /// CTA render alongside the answer).
  final ParsedQuery? parsed;

  /// Present for [AssistantReplyKind.stats] only.
  final AreaStats? stats;

  @override
  List<Object?> get props => [kind, parsed, stats];
}

class AssistantMessage extends Equatable {
  const AssistantMessage.user(this.text)
    : role = AssistantRole.user,
      reply = null;

  const AssistantMessage.assistant(this.reply)
    : role = AssistantRole.assistant,
      text = '';

  const AssistantMessage.greeting()
    : role = AssistantRole.assistant,
      text = '',
      reply = const AssistantReply(kind: AssistantReplyKind.greeting);

  final AssistantRole role;

  /// The raw user input (user role only; empty for assistant messages, whose
  /// content is rendered from [reply]).
  final String text;

  final AssistantReply? reply;

  @override
  List<Object?> get props => [role, text, reply];
}
