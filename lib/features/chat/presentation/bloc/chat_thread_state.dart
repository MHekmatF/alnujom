part of 'chat_thread_cubit.dart';

enum ChatThreadStatus { loading, messages, error }

final class ChatThreadState extends Equatable {
  const ChatThreadState._({
    required this.status,
    this.messages = const [],
    this.hasMore = false,
    this.loadingOlder = false,
    this.olderFailed = false,
    this.otherUserId,
    this.counterpartBlocked = false,
  });

  const ChatThreadState.loading() : this._(status: ChatThreadStatus.loading);

  const ChatThreadState.messages(
    List<Message> messages, {
    bool hasMore = false,
    bool loadingOlder = false,
    bool olderFailed = false,
    String? otherUserId,
    bool counterpartBlocked = false,
  }) : this._(
         status: ChatThreadStatus.messages,
         messages: messages,
         hasMore: hasMore,
         loadingOlder: loadingOlder,
         olderFailed: olderFailed,
         otherUserId: otherUserId,
         counterpartBlocked: counterpartBlocked,
       );

  const ChatThreadState.error() : this._(status: ChatThreadStatus.error);

  final ChatThreadStatus status;

  /// Newest-first (Plan A19) — the order the reversed thread list wants.
  final List<Message> messages;

  /// There may be history before [messages]; show the "load earlier" sentinel.
  final bool hasMore;

  /// A page of older messages is in flight.
  final bool loadingOlder;

  /// The last "load earlier" attempt failed — offer a retry rather than a
  /// spinner that never resolves.
  final bool olderFailed;

  /// Plan A29 — the OTHER person in this conversation, once known. Drives the
  /// report / block menu; null until resolved (or when hidden by RLS).
  final String? otherUserId;

  /// Plan A29 — the caller has blocked the counterpart. Sends will be refused
  /// server-side; the page shows a banner instead of a silent failure.
  final bool counterpartBlocked;

  @override
  List<Object?> get props => [
    status,
    messages,
    hasMore,
    loadingOlder,
    olderFailed,
    otherUserId,
    counterpartBlocked,
  ];
}
