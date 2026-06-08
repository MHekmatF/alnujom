import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/validators/phone_validator.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';
import '../bloc/listing_form_bloc.dart';
import '../bloc/listing_form_event.dart';
import 'step_section.dart';

class StepVisibility extends StatefulWidget {
  const StepVisibility({super.key});

  @override
  State<StepVisibility> createState() => _StepVisibilityState();
}

class _StepVisibilityState extends State<StepVisibility> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  bool _seeded = false;
  String? _phoneError;
  String? _whatsappError;

  @override
  void dispose() {
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ListingFormBloc, ListingFormState>(
      builder: (context, state) {
        final listing = state.draftListing;
        if (listing == null) return const SizedBox.shrink();
        if (!_seeded) {
          _phoneController.text = listing.phone ?? '';
          _whatsappController.text = listing.whatsapp ?? '';
          _seeded = true;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepSection(
              icon: Icons.visibility_outlined,
              title: l10n.listingFormStepVisibilityTitle,
              subtitle: l10n.listingFormStepVisibilitySubtitle,
              children: [
                FieldLabel(label: l10n.fieldLabelLocationVisibility),
                DropdownButtonFormField<LocationVisibility>(
                  initialValue: listing.locationVisibility,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: LocationVisibility.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(_locationVisibilityLabel(v, l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      context.read<ListingFormBloc>().add(
                        FieldChanged.locationVisibility(v),
                      );
                    }
                  },
                ),
                const FieldGap(),
                FieldLabel(label: l10n.fieldLabelContactNameVisibility),
                DropdownButtonFormField<ContactNameVisibility>(
                  initialValue: listing.contactNameVisibility,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: ContactNameVisibility.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(_contactVisibilityLabel(v, l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      context.read<ListingFormBloc>().add(
                        FieldChanged.contactNameVisibility(v),
                      );
                    }
                  },
                ),
                const FieldGap(),
                FieldLabel(label: l10n.fieldLabelHideUntil),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(
                    state.draftVisibility?.hideUntil != null
                        ? state.draftVisibility!.hideUntil!
                              .toIso8601String()
                              .substring(0, 10)
                        : l10n.fieldLabelHideUntilPick,
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          state.draftVisibility?.hideUntil ??
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 2),
                      ),
                    );
                    if (!context.mounted) return;
                    context.read<ListingFormBloc>().add(
                      FieldChanged.hideUntil(picked),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            StepSection(
              icon: Icons.contact_phone_outlined,
              title: l10n.listingFormContactSectionTitle,
              subtitle: l10n.listingFormContactSectionSubtitle,
              children: [
                FieldLabel(
                  label: l10n.fieldLabelPhone,
                  helper: l10n.fieldLabelPhoneOrWhatsappHint,
                  required: true,
                ),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: _phoneError,
                  ),
                  onChanged: (v) {
                    final result = PhoneValidator.validateAndNormalize(v, l10n);
                    setState(() {
                      _phoneError = v.trim().isEmpty ? null : result.error;
                    });
                    context.read<ListingFormBloc>().add(
                      FieldChanged.phone(result.normalized ?? v),
                    );
                  },
                ),
                const FieldGap(),
                FieldLabel(label: l10n.fieldLabelWhatsapp),
                TextField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: _whatsappError,
                  ),
                  onChanged: (v) {
                    final result = PhoneValidator.validateAndNormalize(v, l10n);
                    setState(() {
                      _whatsappError = v.trim().isEmpty ? null : result.error;
                    });
                    context.read<ListingFormBloc>().add(
                      FieldChanged.whatsapp(result.normalized ?? v),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _locationVisibilityLabel(LocationVisibility v, AppLocalizations l10n) {
    switch (v) {
      case LocationVisibility.hidden:
        return l10n.locationVisibilityHidden;
      case LocationVisibility.approximate:
        return l10n.locationVisibilityApproximate;
      case LocationVisibility.exact:
        return l10n.locationVisibilityExact;
      case LocationVisibility.adminOnly:
        return l10n.locationVisibilityAdminOnly;
    }
  }

  String _contactVisibilityLabel(
    ContactNameVisibility v,
    AppLocalizations l10n,
  ) {
    switch (v) {
      case ContactNameVisibility.public:
        return l10n.contactNameVisibilityPublic;
      case ContactNameVisibility.adminOnly:
        return l10n.contactNameVisibilityAdminOnly;
    }
  }
}
