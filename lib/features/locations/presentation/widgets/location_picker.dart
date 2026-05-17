import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/location_picker_selection.dart';
import '../bloc/location_picker_bloc.dart';
import 'location_picker_dropdown.dart';

class LocationPicker extends StatelessWidget {
  const LocationPicker({
    super.key,
    this.initialSelection,
    required this.onChanged,
    this.required = false,
    this.areaRequired = false,
  });

  final LocationPickerSelection? initialSelection;
  final ValueChanged<LocationPickerSelection?> onChanged;
  final bool required;
  final bool areaRequired;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LocationPickerBloc>(
      create: (_) => getIt<LocationPickerBloc>()
        ..add(const LocationPickerMountRequested()),
      child: _LocationPickerBody(
        onChanged: onChanged,
        required: required,
        areaRequired: areaRequired,
      ),
    );
  }
}

class _LocationPickerBody extends StatelessWidget {
  const _LocationPickerBody({
    required this.onChanged,
    required this.required,
    required this.areaRequired,
  });

  final ValueChanged<LocationPickerSelection?> onChanged;
  final bool required;
  final bool areaRequired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return BlocConsumer<LocationPickerBloc, LocationPickerState>(
      listenWhen: (prev, curr) {
        final prevSel =
            prev is LocationPickerReady ? prev.currentSelection : null;
        final currSel =
            curr is LocationPickerReady ? curr.currentSelection : null;
        // Also fire when selection is cleared (e.g. gov reset)
        return prevSel != currSel;
      },
      listener: (context, state) {
        if (state is LocationPickerReady) {
          onChanged(state.currentSelection);
        } else if (state is LocationPickerInitial ||
            state is LocationPickerGovernoratesLoading) {
          onChanged(null);
        }
      },
      builder: (context, state) {
        if (state is LocationPickerGovernoratesLoading ||
            state is LocationPickerInitial) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: LinearProgressIndicator(),
          );
        }

        if (state is LocationPickerLoadFailed) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              l10n.locationsLoadFailed,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          );
        }

        if (state is! LocationPickerReady) {
          return const SizedBox.shrink();
        }

        final govItems = state.governorates
            .map((g) => (g.id, g.localizedName(locale)))
            .toList();

        final cityItems = state.cities
            .map((c) => (c.id, c.localizedName(locale)))
            .toList();

        final areaItems = state.areas
            .map((a) => (a.id, a.localizedName(locale)))
            .toList();

        final citySelected = state.selectedCityId != null;
        final areasEmpty =
            !state.areasLoading && citySelected && areaItems.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocationPickerDropdown(
              label: l10n.locationPickerSelectGovernorate,
              items: govItems,
              value: state.selectedGovernorateId,
              onChanged: (id) {
                if (id != null) {
                  context
                      .read<LocationPickerBloc>()
                      .add(LocationPickerGovernoratePicked(id));
                }
              },
              enabled: true,
            ),
            const SizedBox(height: AppSpacing.md),
            LocationPickerDropdown(
              label: l10n.locationPickerSelectCity,
              items: cityItems,
              value: state.selectedCityId,
              onChanged: (id) {
                if (id != null) {
                  context
                      .read<LocationPickerBloc>()
                      .add(LocationPickerCityPicked(id));
                }
              },
              enabled: state.selectedGovernorateId != null,
              isLoading: state.citiesLoading,
            ),
            const SizedBox(height: AppSpacing.md),
            if (areasEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  l10n.locationPickerNoAreasYet,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              )
            else
              LocationPickerDropdown(
                label: l10n.locationPickerSelectArea,
                items: areaItems,
                value: state.selectedAreaId,
                onChanged: (id) {
                  context
                      .read<LocationPickerBloc>()
                      .add(LocationPickerAreaPicked(id));
                },
                enabled: citySelected,
                isLoading: state.areasLoading,
              ),
          ],
        );
      },
    );
  }
}
