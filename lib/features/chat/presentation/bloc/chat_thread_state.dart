part of 'chat_thread_cubit.dart';

enum ChatThreadStatus { loading, messages, error }

final class ChatThreadState extends Equatable {
  const ChatThreadState._({required this.status, this.messages = const []});

  const ChatThreadState.loading() : this._(status: ChatThreadStatus.loading);

  const ChatThreadState.messages(List<Message> messages)
    : this._(status: ChatThreadStatus.messages, messages: messages);

  const ChatThreadState.error() : this._(status: ChatThreadStatus.error);

  final ChatThreadStatus status;
  final List<Message> messages;

  @override
  List<Object?> get props => [status, messages];
}
