// lib/features/crm/presentation/bloc/crm_leads_cubit.dart
//
// Phase 029 (F1) — drives the CRM pipeline page: the lead list (stage-filtered),
// the "due today" reminder banner, and manual-lead creation. Also requests the
// notification permission once on first load (so reminders can be scheduled).

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/notifications/local_reminder_scheduler.dart';
import '../../domain/entities/crm_lead.dart';
import '../../domain/entities/crm_reminder.dart';
import '../../domain/entities/crm_stage.dart';
import '../../domain/repositories/crm_repository.dart';

part 'crm_leads_state.dart';

@injectable
class CrmLeadsCubit extends Cubit<CrmLeadsState> {
  CrmLeadsCubit(this._repository, this._scheduler)
    : super(const CrmLeadsState());

  final CrmRepository _repository;
  final LocalReminderScheduler _scheduler;

  bool _askedPermission = false;

  Future<void> load() async {
    emit(state.copyWith(status: CrmLeadsStatus.loading));

    // One-time: ask for notification permission so reminders can fire.
    if (!_askedPermission) {
      _askedPermission = true;
      final granted = await _scheduler.requestPermission();
      if (!isClosed && !granted) {
        emit(state.copyWith(permissionDenied: true));
      }
    }

    final leadsResult = await _repository.loadLeads(stage: state.stageFilter);
    final remindersResult = await _repository.loadOpenReminders();

    if (isClosed) return;

    switch (leadsResult) {
      case Success<List<CrmLead>>(:final value):
        final now = DateTime.now();
        final due = switch (remindersResult) {
          Success<List<CrmReminder>>(:final value) =>
            value.where((r) => r.isDueOrOverdue(now)).toList()
              ..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
          FailureResult<List<CrmReminder>>() => const <CrmReminder>[],
        };
        emit(
          state.copyWith(
            status: CrmLeadsStatus.ready,
            leads: value,
            dueReminders: due,
          ),
        );
      case FailureResult<List<CrmLead>>():
        emit(state.copyWith(status: CrmLeadsStatus.error));
    }
  }

  /// Changes the stage filter and reloads.
  Future<void> setStageFilter(CrmStage? stage) async {
    emit(
      state.copyWith(
        stageFilter: stage,
        clearStageFilter: stage == null,
      ),
    );
    await load();
  }

  /// Creates a manual lead and reloads on success. Returns true on success.
  Future<bool> createManualLead(String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return false;
    final result = await _repository.createManualLead(displayName: trimmed);
    if (result is Success<String>) {
      await load();
      return true;
    }
    return false;
  }
}
