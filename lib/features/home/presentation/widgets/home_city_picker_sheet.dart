import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../locations/domain/entities/governorate_with_city_count.dart';
import '../../../locations/domain/repositories/locations_repository.dart';

/// Bottom sheet that lets the user pick a Syrian governorate to browse.
///
/// Returns the chosen governorate id via [Navigator.pop] (null when dismissed).
/// The Home crown location chip opens it and routes to Search filtered by that
/// area. Reuses the same [LocationsRepository] the search filter sheet reads.
class HomeCityPickerSheet extends StatefulWidget {
  const HomeCityPickerSheet({super.key});

  @override
  State<HomeCityPickerSheet> createState() => _HomeCityPickerSheetState();
}

class _HomeCityPickerSheetState extends State<HomeCityPickerSheet> {
  List<GovernorateWithCityCount>? _governorates;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await getIt<LocationsRepository>().listGovernorates(
        includeInactive: false,
      );
      if (mounted) setState(() => _governorates = result);
    } on Object {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);
    final govs = _governorates;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                l10n.home_city_picker_title,
                style: styles.titleMedium,
              ),
            ),
            if (_error)
              Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                child: Text(
                  l10n.home_city_picker_error,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              )
            else if (govs == null)
              const Padding(
                padding: EdgeInsetsDirectional.all(AppSpacing.xl),
                child: Center(child: AppSpinner()),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: govs.length,
                  itemBuilder: (context, i) {
                    final gov = govs[i].governorate;
                    return ListTile(
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: colors.primary,
                      ),
                      title: Text(
                        gov.localizedName(locale),
                        style: styles.titleMedium,
                      ),
                      onTap: () => Navigator.of(context).pop(gov.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
