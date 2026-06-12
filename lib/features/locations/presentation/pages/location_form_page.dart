import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/failures.dart';
import '../bloc/location_form_bloc.dart';
import '../widgets/bilingual_display_name_field.dart';

class LocationFormPage extends StatelessWidget {
  const LocationFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final params = GoRouterState.of(context).uri.queryParameters;
    final mode = params['mode'] == 'edit'
        ? LocationFormMode.edit
        : LocationFormMode.add;
    final level = switch (params['level']) {
      'city' => LocationLevel.city,
      'area' => LocationLevel.area,
      _ => LocationLevel.governorate,
    };
    final id = params['id'];
    final parentId = params['parentId'];

    return BlocProvider<LocationFormBloc>(
      create: (_) => getIt<LocationFormBloc>()
        ..add(FormOpened(mode: mode, level: level, id: id, parentId: parentId)),
      child: const _LocationFormView(),
    );
  }
}

class _LocationFormView extends StatelessWidget {
  const _LocationFormView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<LocationFormBloc, LocationFormState>(
      listener: (context, state) {
        if (state is LocationFormSaveSuccess) {
          context.pop(true);
        } else if (state is LocationFormSaveFailure) {
          final message = switch (state.failure) {
            KeyAlreadyUsedFailure() => l10n.keyAlreadyUsed,
            SystemRowProtectedFailure() => l10n.cannotDeleteSystemRow,
            NotAuthorizedFailure() => l10n.locationsLoadFailed,
            _ => l10n.locationSaveFailed,
          };
          AppToast.error(context, message);
        }
      },
      child: BlocBuilder<LocationFormBloc, LocationFormState>(
        builder: (context, state) {
          final title = _appBarTitle(l10n, state);
          return Scaffold(
            appBar: AppBar(
              title: Text(title),
              actions: const [LocaleToggleAction()],
            ),
            body: switch (state) {
              LocationFormIdle() ||
              LocationFormLoading() => const AppSpinner.page(),
              LocationFormLoadFailed(:final message) => Center(
                child: Text(message, textAlign: TextAlign.center),
              ),
              LocationFormSaveSuccess() => const AppSpinner.page(),
              LocationFormSaveFailure() => const SizedBox.shrink(),
              LocationFormEditing() => _LocationFormBody(state: state),
            },
          );
        },
      ),
    );
  }

  String _appBarTitle(AppLocalizations l10n, LocationFormState state) {
    if (state is LocationFormEditing) {
      return state.mode == LocationFormMode.add
          ? switch (state.level) {
              LocationLevel.governorate => l10n.addGovernorateButton,
              LocationLevel.city => l10n.addCityButton,
              LocationLevel.area => l10n.addAreaButton,
            }
          : l10n.editAffordance;
    }
    return l10n.editAffordance;
  }
}

class _LocationFormBody extends StatefulWidget {
  const _LocationFormBody({required this.state});

  final LocationFormEditing state;

  @override
  State<_LocationFormBody> createState() => _LocationFormBodyState();
}

class _LocationFormBodyState extends State<_LocationFormBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyController;
  late final TextEditingController _positionController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.state.key);
    _positionController = TextEditingController(
      text: widget.state.position?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _LocationFormBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync controllers if the bloc reloaded the entity (e.g., after conflict)
    if (oldWidget.state.id != widget.state.id ||
        oldWidget.state.key != widget.state.key) {
      _keyController.text = widget.state.key;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        children: [
          TextFormField(
            controller: _keyController,
            enabled: !state.isLoadedSystemRow,
            decoration: InputDecoration(labelText: l10n.keyFieldLabel),
            onChanged: (value) =>
                context.read<LocationFormBloc>().add(KeyChanged(value)),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.keyRequired;
              }
              if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(value.trim())) {
                return l10n.keyRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          BilingualDisplayNameField(
            initialArabic: state.arabicName.isEmpty ? null : state.arabicName,
            initialEnglish: state.englishName,
            onChanged: (value) {
              context.read<LocationFormBloc>().add(
                ArabicNameChanged(value.arabic ?? ''),
              );
              context.read<LocationFormBloc>().add(
                EnglishNameChanged(value.english ?? ''),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _positionController,
            decoration: InputDecoration(labelText: l10n.positionLabel),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              context.read<LocationFormBloc>().add(PositionChanged(parsed));
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _ActiveSwitchRow(
            label: l10n.isActiveToggleLabel,
            value: state.isActive,
            onChanged: (value) => context.read<LocationFormBloc>().add(
              IsActiveToggled(value: value),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.actionCreate,
            loading: state.isSaving,
            expanded: true,
            onPressed: state.isSaving
                ? null
                : () {
                    if (_formKey.currentState?.validate() != true) return;
                    context.read<LocationFormBloc>().add(const SaveRequested());
                  },
          ),
        ],
      ),
    );
  }
}

/// Branded replacement for the stock [SwitchListTile] — tinted icon circle +
/// label on a hairline surface with a trailing [Switch]. Tapping the row
/// toggles, mirroring the original tile behavior.
class _ActiveSwitchRow extends StatelessWidget {
  const _ActiveSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: () => onChanged(!value),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xxl + AppSpacing.sm,
              height: AppSpacing.xxl + AppSpacing.sm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                LucideIcons.map_pin,
                color: colors.primary,
                size: AppSpacing.lg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: styles.bodyLarge)),
            const SizedBox(width: AppSpacing.sm),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
