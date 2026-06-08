// lib/features/chat/presentation/bloc/conversations_cubit.dart
//
// In-app chat — ConversationsCubit: drives the conversation-list page.
// States: loading / list (possibly empty) / error.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/usecases/list_conversations.dart';

part 'conversations_state.dart';

@injectable
class ConversationsCubit extends Cubit<ConversationsState> {
  ConversationsCubit(this._listConversations)
    : super(const ConversationsState.initial());

  final ListConversations _listConversations;

  /// Initial (and retry) load — replaces any prior state.
  Future<void> load() async {
    emit(const ConversationsState.loading());
    final result = await _listConversations();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(ConversationsState.list(value));
      case FailureResult():
        emit(const ConversationsState.error());
    }
  }
}
