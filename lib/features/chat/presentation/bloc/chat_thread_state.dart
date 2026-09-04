part of 'chat_thread_cubit.dart';

enum ChatThreadStatus { loading, messages, error }

final class ChatThreadState extends Equatable {
  const ChatThreadState._({
    required this.status,
    this.messages = const [],
    this.hasMore = false,
    this.loadingOlder = false,
    this.olderFailed = false,
  });

  const ChatThreadState.loading() : this._(status: ChatThreadStatus.loading);

  const ChatThreadState.messages(
    List<Message> messages, {
    bool hasMore = false,
    bool loadingOlder = false,
    bool olderFailed = false,
  }) : this._(
         status: ChatThreadStatus.messages,
         messages: messages,
         hasMore: hasMore,
         loadingOlder: loadingOlder,
         olderFailed: olderFailed,
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

  @override
  List<Object?> get props => [
    status,
    messages,
    hasMore,
    loadingOlder,
    olderFailed,
  ];
}
