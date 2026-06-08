// lib/features/inquiries/presentation/sheets/inquiry_form_sheet.dart
//
// Phase 16 Sub-Phase F (T062) — Modal bottom sheet for submitting an inquiry.
// Uses DraggableScrollableSheet per contracts/phase16-inquiry-form-sheet.md.
// Auth pre-population: reads getIt<AuthBloc>().state at initState time
// (one-shot; the sheet is ephemeral).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/local/last_inquiry_phone_store.dart';
import '../bloc/inquiry_form_bloc.dart';

/// Modal bottom sheet for sending an inquiry on a listing.
///
/// Caller launches via:
/// ```dart
/// final submitted = await showModalBottomSheet<bool>(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => InquiryFormSheet(listingId: listing.id),
/// );
/// if (submitted == true) { /* show success snackbar */ }
/// ```
class InquiryFormSheet extends StatefulWidget {
  const InquiryFormSheet({required this.listingId, super.key});

  final String listingId;

  @override
  State<InquiryFormSheet> createState() => _InquiryFormSheetState();
}

class _InquiryFormSheetState extends State<InquiryFormSheet> {
  late final InquiryFormBloc _bloc;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _messageCtrl;

  /// True when the sheet was opened by a non-authenticated user. Drives the
  /// anonymous-only "remember last phone" prefill (async) + persist (on success).
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _bloc = getIt.get<InquiryFormBloc>(param1: widget.listingId);

    // Auth pre-population — one-shot read at sheet open time.
    final authState = getIt<AuthBloc>().state;
    String prefillName = '';
    String prefillPhone = '';
    if (authState is Authenticated) {
      prefillName = authState.profile.fullName ?? '';
      prefillPhone = authState.profile.phone ?? '';
    } else {
      _isAnonymous = true;
    }

    _nameCtrl = TextEditingController(text: prefillName);
    _phoneCtrl = TextEditingController(text: prefillPhone);
    _messageCtrl = TextEditingController();

    // Anonymous-only: remember the last phone this device submitted and pre-fill
    // it (async; logged-in users already get their profile phone above and are
    // never overwritten by this path).
    if (_isAnonymous) {
      _prefillLastAnonymousPhone();
    }

    // Dispatch initial prefill values into the BLoC.
    if (prefillName.isNotEmpty) {
      _bloc.add(
        InquiryFormFieldChanged(
          field: InquiryFormField.name,
          value: prefillName,
        ),
      );
    }
    if (prefillPhone.isNotEmpty) {
      _bloc.add(
        InquiryFormFieldChanged(
          field: InquiryFormField.phone,
          value: prefillPhone,
        ),
      );
    }

    // Wire text controllers to BLoC.
    _nameCtrl.addListener(() {
      _bloc.add(
        InquiryFormFieldChanged(
          field: InquiryFormField.name,
          value: _nameCtrl.text,
        ),
      );
    });
    _phoneCtrl.addListener(() {
      _bloc.add(
        InquiryFormFieldChanged(
          field: InquiryFormField.phone,
          value: _phoneCtrl.text,
        ),
      );
    });
    _messageCtrl.addListener(() {
      _bloc.add(
        InquiryFormFieldChanged(
          field: InquiryFormField.message,
          value: _messageCtrl.text,
        ),
      );
    });
  }

  /// Loads the last anonymous phone from local storage and pre-fills the phone
  /// field — but only while the field is still empty (so it never clobbers a
  /// value the user has already started typing during the async read).
  Future<void> _prefillLastAnonymousPhone() async {
    final stored = await LastInquiryPhoneStore.read();
    if (!mounted || stored == null || stored.isEmpty) return;
    if (_phoneCtrl.text.isNotEmpty) return;
    _phoneCtrl.text = stored;
    // Sync the BLoC so validation / submit-enable reflect the prefilled value.
    _bloc.add(
      InquiryFormFieldChanged(field: InquiryFormField.phone, value: stored),
    );
  }

  @override
  void dispose() {
    _bloc.close();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InquiryFormBloc>.value(
      value: _bloc,
      child: BlocListener<InquiryFormBloc, InquiryFormState>(
        listener: (context, state) {
          if (state is InquiryFormSubmittedSuccess) {
            // Anonymous-only: remember this phone for the next sheet open.
            // Fire-and-forget — never block the pop on a storage write.
            if (_isAnonymous) {
              LastInquiryPhoneStore.save(_phoneCtrl.text);
            }
            Navigator.of(context).pop(true);
          } else if (state is InquiryFormFailed) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.inquiry_form_submission_failed)),
            );
          }
        },
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return _SheetBody(
              scrollController: scrollController,
              nameCtrl: _nameCtrl,
              phoneCtrl: _phoneCtrl,
              messageCtrl: _messageCtrl,
            );
          },
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.scrollController,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.messageCtrl,
  });

  final ScrollController scrollController;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController messageCtrl;

  static const int _counterThreshold = 1600;
  static const int _maxMessageLength = 2000;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BlocBuilder<InquiryFormBloc, InquiryFormState>(
        builder: (context, state) {
          final isSubmitting = state is InquiryFormSubmitting;
          final errors = state is InquiryFormEditing
              ? state.validationErrors
              : const <String, String>{};
          final messageLength = messageCtrl.text.length;
          final showCounter = messageLength >= _counterThreshold;

          return ListView(
            controller: scrollController,
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            children: [
              // Handle indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(
                      AppRadii.pill,
                    ), // drag-handle bar — fully rounded
                  ),
                ),
              ),
              // Sheet title
              Text(
                l10n.inquiry_form_title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              // Name field
              TextField(
                controller: nameCtrl,
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  labelText: l10n.inquiry_form_name_label,
                  hintText: l10n.inquiry_form_name_placeholder,
                  errorText: errors.containsKey('name')
                      ? l10n.inquiry_form_validation_name_required
                      : null,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              // Phone field
              TextField(
                controller: phoneCtrl,
                enabled: !isSubmitting,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.inquiry_form_phone_label,
                  errorText: errors.containsKey('phone')
                      ? l10n.inquiry_form_validation_phone_invalid
                      : null,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              // Message field (multiline, max 6 lines visible)
              TextField(
                controller: messageCtrl,
                enabled: !isSubmitting,
                maxLines: 6,
                maxLength: _maxMessageLength,
                decoration: InputDecoration(
                  labelText: l10n.inquiry_form_message_label,
                  hintText: l10n.inquiry_form_message_placeholder,
                  // Custom counter rendered below — suppress the built-in one.
                  errorText: errors.containsKey('message')
                      ? _resolveMessageError(l10n, errors['message']!)
                      : null,
                ),
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
              ),
              // Conditional counter — visible at ≥ 1600 chars (R-108).
              if (showCounter)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: AppSpacing.xs,
                    end: AppSpacing.xs,
                  ),
                  child: Text(
                    l10n.inquiry_form_message_counter(
                      _maxMessageLength - messageLength,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: messageLength > 1900
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              // Submit button — disabled while submitting or while any
              // required field is empty.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isSubmitting || !_hasRequiredFields(state))
                      ? null
                      : () => context.read<InquiryFormBloc>().add(
                          const InquiryFormSubmitted(),
                        ),
                  child: isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.inquiry_form_submit_button),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          );
        },
      ),
    );
  }

  bool _hasRequiredFields(InquiryFormState state) {
    if (state is! InquiryFormEditing) return false;
    return state.name.trim().isNotEmpty &&
        state.phone.trim().isNotEmpty &&
        state.message.trim().isNotEmpty;
  }

  String _resolveMessageError(AppLocalizations l10n, String code) {
    return switch (code) {
      'invalid_message_length' => l10n.inquiry_form_validation_message_too_long,
      _ => l10n.inquiry_form_validation_message_required,
    };
  }
}
