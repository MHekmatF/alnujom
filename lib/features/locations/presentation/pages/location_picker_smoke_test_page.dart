import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/locale_toggle_action.dart';
import '../../domain/entities/location_picker_selection.dart';
import '../widgets/location_picker.dart';

class LocationPickerSmokeTestPage extends StatefulWidget {
  const LocationPickerSmokeTestPage({super.key});

  @override
  State<LocationPickerSmokeTestPage> createState() =>
      _LocationPickerSmokeTestPageState();
}

class _LocationPickerSmokeTestPageState
    extends State<LocationPickerSmokeTestPage> {
  LocationPickerSelection? _latest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LocationPicker smoke test'),
        actions: const [LocaleToggleAction()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocationPicker(onChanged: (sel) => setState(() => _latest = sel)),
            const SizedBox(height: AppSpacing.xl),
            Text(
              _latest == null
                  ? 'no selection'
                  : 'gov=${_latest!.governorateId} '
                        'city=${_latest!.cityId} '
                        'area=${_latest!.areaId ?? "null"}',
            ),
          ],
        ),
      ),
    );
  }
}
