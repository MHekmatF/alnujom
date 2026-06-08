part of 'conversations_cubit.dart';

enum ConversationsStatus { initial, loading, list, error }

final class ConversationsState extends Equatable {
  const ConversationsState._({
    required this.status,
    this.conversations = const [],
  });

  const ConversationsState.initial()
    : this._(status: ConversationsStatus.initial);

  const ConversationsState.loading()
    : this._(status: ConversationsStatus.loading);

  const ConversationsState.list(List<Conversation> conversations)
    : this._(status: ConversationsStatus.list, conversations: conversations);

  const ConversationsState.error() : this._(status: ConversationsStatus.error);

  final ConversationsStatus status;
  final List<Conversation> conversations;

  @override
  List<Object?> get props => [status, conversations];
}
