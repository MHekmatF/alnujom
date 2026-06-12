// Phase 23 (spec/023-app-settings) — T016
// AppSettingsEditorPage: admin typed-settings editor.
// Route: /admin/settings (gated by requireSettingsManageRedirect, T017).
// Mirrors AdsListPage / AuditLogsViewerPage structure.
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../../../../../features/currencies/domain/entities/currency.dart';
import '../../../../../features/currencies/domain/usecases/list_currencies.dart';
import '../../../../../features/listing_form/domain/entities/listing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/app_setting_key.dart';
import '../bloc/app_settings_editor_cubit.dart';
import '../widgets/settings_dropdown_row.dart';
import '../widgets/settings_section_header.dart';
import '../widgets/settings_text_row.dart';
import '../widgets/settings_toggle_row.dart';

class AppSettingsEditorPage extends StatelessWidget {
  const AppSettingsEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppSettingsEditorCubit>(
      create: (_) => getIt<AppSettingsEditorCubit>()..load(),
      child: const _AppSettingsEditorView(),
    );
  }
}

class _AppSettingsEditorView extends StatelessWidget {
  const _AppSettingsEditorView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsEditorTitle)),
      body: BlocConsumer<AppSettingsEditorCubit, AppSettingsEditorState>(
        listener: (ctx, state) {
          if (state is AppSettingsEditorLoaded) {
            if (state.lastSavedKey != null && state.saveFailure == null) {
              AppToast.success(ctx, l10n.settingsEditorSavedSnackbar);
            }
            if (state.saveFailure != null) {
              AppToast.error(ctx, l10n.settingsEditorSaveError);
            }
          }
        },
        builder: (ctx, state) {
          if (state is AppSettingsEditorLoading) {
            return const AppSpinner.page();
          }
          if (state is AppSettingsEditorError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.settingsEditorLoadError),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => ctx.read<AppSettingsEditorCubit>().load(),
                    child: Text(l10n.settingsEditorRetry),
                  ),
                ],
              ),
            );
          }
          if (state is AppSettingsEditorLoaded) {
            return _SettingsForm(state: state);
          }
          return const AppSpinner.page();
        },
      ),
    );
  }
}

// ─── Settings form ────────────────────────────────────────────────────────────

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({required this.state});

  final AppSettingsEditorLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<AppSettingsEditorCubit>();

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        children: [
          // ── General ────────────────────────────────────────────────────────
          SettingsSectionHeader(l10n.settingsEditorSectionGeneral),
          _LanguagePicker(state: state, l10n: l10n, cubit: cubit),
          const SizedBox(height: AppSpacing.sm),
          _CurrencyPicker(state: state, l10n: l10n, cubit: cubit),

          // ── Listing Defaults ───────────────────────────────────────────────
          SettingsSectionHeader(l10n.settingsEditorSectionListingDefaults),
          _PublisherNameVisibilityPicker(
            state: state,
            l10n: l10n,
            cubit: cubit,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LocationVisibilityPicker(state: state, l10n: l10n, cubit: cubit),

          // ── Maintenance Mode ───────────────────────────────────────────────
          SettingsSectionHeader(l10n.settingsEditorSectionMaintenance),
          _MaintenanceModeSection(state: state, l10n: l10n, cubit: cubit),

          // ── Support Contact ────────────────────────────────────────────────
          SettingsSectionHeader(l10n.settingsEditorSectionSupport),
          _SupportContactSection(state: state, l10n: l10n, cubit: cubit),

          // ── Legal Pages ────────────────────────────────────────────────────
          SettingsSectionHeader(l10n.settingsEditorSectionLegal),
          _LegalUrlsSection(state: state, l10n: l10n, cubit: cubit),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── Language picker ─────────────────────────────────────────────────────────

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({
    required this.state,
    required this.l10n,
    required this.cubit,
  });

  final AppSettingsEditorLoaded state;
  final AppLocalizations l10n;
  final AppSettingsEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final setting = state.settingFor(AppSettingKey.defaultLanguage);
    final currentValue = setting?.value is String
        ? setting!.value as String
        : 'ar';
    final isSaving = state.savingKey == AppSettingKey.defaultLanguage;

    return SettingsDropdownRow(
      label: l10n.settingsEditorDefaultLanguageLabel,
      value: currentValue,
      isSaving: isSaving,
      items: [
        (value: 'ar', label: l10n.settingsEditorLanguageAr),
        (value: 'en', label: l10n.settingsEditorLanguageEn),
      ],
      onSave: (newValue) {
        if (newValue != null) {
          cubit.save(AppSettingKey.defaultLanguage, newValue, l10n);
        }
      },
    );
  }
}

// ─── Currency picker ─────────────────────────────────────────────────────────

class _CurrencyPicker extends StatefulWidget {
  const _CurrencyPicker({
    required this.state,
    required this.l10n,
    required this.cubit,
  });

  final AppSettingsEditorLoaded state;
  final AppLocalizations l10n;
  final AppSettingsEditorCubit cubit;

  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  List<Currency>? _currencies;
  bool _loadingCurrencies = true;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencies = await getIt<ListCurrencies>()(activeOnly: true);
      if (mounted) {
        setState(() {
          _currencies = currencies;
          _loadingCurrencies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCurrencies = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCurrencies) {
      return const Padding(
        padding: EdgeInsetsDirectional.all(AppSpacing.sm),
        child: AppSpinner(),
      );
    }

    final l10n = widget.l10n;
    final setting = widget.state.settingFor(AppSettingKey.defaultCurrency);
    final currentValue = setting?.value is String
        ? setting!.value as String
        : null;
    final isSaving = widget.state.savingKey == AppSettingKey.defaultCurrency;
    final currencies = _currencies ?? [];
    // Locale for currency name — use current context locale.
    final locale = Localizations.localeOf(context);

    final items = currencies
        .map(
          (c) =>
              (value: c.code, label: '${c.localizedName(locale)} (${c.code})'),
        )
        .toList();

    // Ensure currentValue is a valid option; null otherwise (unset).
    final validValue =
        currentValue != null && currencies.any((c) => c.code == currentValue)
        ? currentValue
        : null;

    return SettingsDropdownRow(
      label: l10n.settingsEditorDefaultCurrencyLabel,
      value: validValue,
      isSaving: isSaving,
      items: items,
      onSave: (newValue) {
        if (newValue != null) {
          widget.cubit.save(
            AppSettingKey.defaultCurrency,
            newValue,
            widget.l10n,
          );
        }
      },
    );
  }
}

// ─── Publisher name visibility picker ────────────────────────────────────────

class _PublisherNameVisibilityPicker extends StatelessWidget {
  const _PublisherNameVisibilityPicker({
    required this.state,
    required this.l10n,
    required this.cubit,
  });

  final AppSettingsEditorLoaded state;
  final AppLocalizations l10n;
  final AppSettingsEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final setting = state.settingFor(
      AppSettingKey.defaultPublisherNameVisibility,
    );
    final currentValue = setting?.value is String
        ? setting!.value as String
        : ContactNameVisibility.public.name;
    final isSaving =
        state.savingKey == AppSettingKey.defaultPublisherNameVisibility;

    return SettingsDropdownRow(
      label: l10n.settingsEditorDefaultPublisherNameVisibilityLabel,
      value: currentValue,
      isSaving: isSaving,
      items: [
        (
          value: ContactNameVisibility.public.name,
          label: l10n.settingsEditorVisibilityPublic,
        ),
        (
          value: ContactNameVisibility.adminOnly.name,
          label: l10n.settingsEditorVisibilityAdminOnly,
        ),
      ],
      onSave: (newValue) {
        if (newValue != null) {
          cubit.save(
            AppSettingKey.defaultPublisherNameVisibility,
            newValue,
            l10n,
          );
        }
      },
    );
  }
}

// ─── Location visibility picker ───────────────────────────────────────────────

class _LocationVisibilityPicker extends StatelessWidget {
  const _LocationVisibilityPicker({
    required this.state,
    required this.l10n,
    required this.cubit,
  });

  final AppSettingsEditorLoaded state;
  final AppLocalizations l10n;
  final AppSettingsEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final setting = state.settingFor(AppSettingKey.defaultLocationVisibility);
    final currentValue = setting?.value is String
        ? setting!.value as String
        : LocationVisibility.approximate.name;
    final isSaving = state.savingKey == AppSettingKey.defaultLocationVisibility;

    return SettingsDropdownRow(
      label: l10n.settingsEditorDefaultLocationVisibilityLabel,
      value: currentValue,
      isSaving: isSaving,
      items: [
        (
          value: LocationVisibility.hidden.name,
          label: l10n.settingsEditorLocationVisibilityHidden,
        ),
        (
          value: LocationVisibility.approximate.name,
          label: l10n.settingsEditorLocationVisibilityApproximate,
        ),
        (
          value: LocationVisibility.exact.name,
          label: l10n.settingsEditorLocationVisibilityExact,
        ),
        (
          value: LocationVisibility.adminOnly.name,
          label: l10n.settingsEditorVisibilityAdminOnly,
        ),
      ],
      onSave: (newValue) {
        if (newValue != null) {
          cubit.save(AppSettingKey.defaultLocationVisibility, newValue, l10n);
        }
      },
    );
  }
}

// ─── Maintenance mode section ─────────────────────────────────────────────────

class _MaintenanceModeSection extends StatelessWidget {
  const _MaintenanceModeSection({
    required this.state,
    required this.l10n,
    required this.cubit,
  });

  final AppSettingsEditorLoaded state;
  final AppLocalizations l10n;
  final AppSettingsEditorCubit cubit;

  Map<String, dynamic> _currentMap() {
    final setting = state.settingFor(AppSettingKey.maintenanceMode);
    if (setting?.value is Map) {
      return Map<String, dynamic>.from(setting!.value as Map);
    }
    return {
      'on': false,
      'message': <String, dynamic>{'ar': '', 'en': ''},
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentMap = _currentMap();
    final isOn = currentMap['on'] as bool? ?? false;
    final messageMap = currentMap['message'];
    final messageAr = messageMap is Map
        ? (messageMap['ar'] as String? ?? '')
        : '';
    final messageEn = messageMap is Map
        ? (messageMap['en'] as String? ?? '')
        : '';
    final isSaving = state.savingKey == AppSettingKey.maintenanceMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsToggleRow(
          label: l10n.settingsEditorMaintenanceToggle,
          value: isOn,
          isSaving: isSaving,
          onChanged: (newValue) {
            final newMap = {...currentMap, 'on': newValue};
            cubit.save(AppSettingKey.maintenanceMode, newMap, l10n);
          },
        ),
        SettingsTextRow(
          label: l10n.settingsEditorMaintenanceMessageArLabel,
          initialValue: messageAr,
          isSaving: isSaving,
          saveLabel: l10n.settingsEditorSaveButton,
          maxLines: 3,
          onSave: (newText) async {
            final newMap = {
              ...currentMap,
              'message': {'ar': newText, 'en': messageEn},
            };
            return cubit.save(AppSettingKey.maintenanceMode, newMap, l10n);
          },
        ),
        SettingsTextRow(
          label: l10n.settingsEditorMaintenanceMessageEnLabel,
          initialValue: messageEn,
          isSaving: isSaving,
          saveLabel: l10n.settingsEditorSaveButton,
          maxLines: 3,
          onSave: (newText) async {
            final newMap = {
              ...currentMap,
              'message': {'ar': messageAr, 'en': newText},
            };
            return cubit.save(AppSettingKey.maintenanceMode, newMap, l10n);
          },
        ),
      ],
    );
  }
}

// ─── Support contact section ──────────────────────────────────────────────────

class _SupportContactSection extends StatelessWidget {
  const _SupportContactSection({
    required this.state,
    required this.l10n,
    required this.cubit,
  });

  final AppSettingsEditorLoaded state;
  final AppLocalizations l10n;
  final AppSettingsEditorCubit cubit;

  Map<String, dynamic> _currentMap() {
    final setting = state.settingFor(AppSettingKey.supportContact);
    if (setting?.value is Map) {
      return Map<String, dynamic>.from(setting!.value as Map);
    }
    return {'phone': '', 'whatsapp': '', 'email': ''};
  }

  @override
  Widget build(BuildContext context) {
    final currentMap = _currentMap();
    final phone = currentMap['phone'] as String? ?? '';
    final whatsapp = currentMap['whatsapp'] as String? ?? '';
    final email = currentMap['email'] as String? ?? '';
    final isSaving = state.savingKey == AppSettingKey.supportContact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsTextRow(
          label: l10n.settingsEditorSupportPhoneLabel,
          initialValue: phone,
          isSaving: isSaving,
          saveLabel: l10n.settingsEditorSaveButton,
          keyboardType: TextInputType.phone,
          onSave: (newPhone) async {
            final newMap = {...currentMap, 'phone': newPhone};
            return cubit.save(AppSettingKey.supportContact, newMap, l10n);
          },
        ),
        SettingsTextRow(
          label: l10n.settingsEditorSupportWhatsappLabel,
          initialValue: whatsapp,
          isSaving: isSaving,
          saveLabel: l10n.settingsEditorSaveButton,
          keyboardType: TextInputType.phone,
          onSave: (newWhatsapp) async {
            final newMap = {...currentMap, 'whatsapp': newWhatsapp};
            return cubit.save(AppSettingKey.supportContact, newMap, l10n);
          },
        ),
        SettingsTextRow(
          label: l10n.settingsEditorSupportEmailLabel,
          initialValue: email,
          isSaving: isSaving,
          saveLabel: l10n.settingsEditorSaveButton,
          keyboardType: TextInputType.emailAddress,
          onSave: (newEmail) async {
            final newMap = {...currentMap, 'email': newEmail};
            return cubit.save(AppSettingKey.supportContact, newMap, l10n);
          },
        ),
      ],
    );
  }
}

// ─── Legal URLs section ───────────────────────────────────────────────────────

class _LegalUrlsSection extends StatelessWidget {
  const _LegalUrlsSection({
    required this.state,
    required this.l10n,
    required this.cubit,
  });

  final AppSettingsEditorLoaded state;
  final AppLocalizations l10n;
  final AppSettingsEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final termsSetting = state.settingFor(AppSettingKey.termsUrl);
    final privacySetting = state.settingFor(AppSettingKey.privacyUrl);
    final termsValue = termsSetting?.value is String
        ? termsSetting!.value as String
        : '';
    final privacyValue = privacySetting?.value is String
        ? privacySetting!.value as String
        : '';
    final isSavingTerms = state.savingKey == AppSettingKey.termsUrl;
    final isSavingPrivacy = state.savingKey == AppSettingKey.privacyUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsTextRow(
          label: l10n.settingsEditorTermsUrlLabel,
          initialValue: termsValue,
          isSaving: isSavingTerms,
          saveLabel: l10n.settingsEditorSaveButton,
          keyboardType: TextInputType.url,
          onSave: (newUrl) async {
            return cubit.save(AppSettingKey.termsUrl, newUrl, l10n);
          },
        ),
        SettingsTextRow(
          label: l10n.settingsEditorPrivacyUrlLabel,
          initialValue: privacyValue,
          isSaving: isSavingPrivacy,
          saveLabel: l10n.settingsEditorSaveButton,
          keyboardType: TextInputType.url,
          onSave: (newUrl) async {
            return cubit.save(AppSettingKey.privacyUrl, newUrl, l10n);
          },
        ),
      ],
    );
  }
}
