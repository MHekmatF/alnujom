import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/color_palette.dart';
import '../core/theme/colors.dart';
import '../core/theme/radii.dart';
import '../core/theme/spacing.dart';
import '../core/theme/typography.dart';
import '../core/widgets/_widget_support.dart';
import '../core/widgets/app_app_bar.dart';
import '../core/widgets/app_badge.dart';
import '../core/widgets/app_bottom_nav.dart';
import '../core/widgets/app_bottom_sheet.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_checkbox.dart';
import '../core/widgets/app_currency_field.dart';
import '../core/widgets/app_date_picker.dart';
import '../core/widgets/app_dialog.dart';
import '../core/widgets/app_dropdown.dart';
import '../core/widgets/app_multi_line_field.dart';
import '../core/widgets/app_number_field.dart';
import '../core/widgets/app_password_field.dart';
import '../core/widgets/app_phone_field.dart';
import '../core/widgets/app_radio_group.dart';
import '../core/widgets/app_stepper_input.dart';
import '../core/widgets/app_tabs.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/app_toggle.dart';
import '../core/widgets/category_chip.dart';
import '../core/widgets/chat_bubble.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/error_state.dart';
import '../core/widgets/image_gallery.dart';
import '../core/widgets/loading_state.dart';
import '../core/widgets/location_selector.dart';
import '../core/widgets/map_preview.dart';
import '../core/widgets/office_card.dart';
import '../core/widgets/palette_tester.dart';
import '../core/widgets/price_tag.dart';
import '../core/widgets/property_card.dart';
import '../core/widgets/search_field.dart';
import '../core/widgets/stepper_indicator.dart';

class ThemeGalleryPage extends StatefulWidget {
  const ThemeGalleryPage({
    super.key,
    this.initialLocale = const Locale('ar'),
    this.initialBrightness = Brightness.light,
    this.initialPalette = ColorPalette.defaultPalette,
  });

  final Locale initialLocale;
  final Brightness initialBrightness;
  final ColorPalette initialPalette;

  static const sectionHeaders = <String>[
    'Chrome',
    'Inputs',
    'Cards',
    'Badges',
    'Sheets',
    'Dialogs',
    'Feedback',
    'Media',
    'Chat',
    'Price',
    'BottomNav',
    'PaletteTester',
  ];

  @override
  State<ThemeGalleryPage> createState() => _ThemeGalleryPageState();
}

class _ThemeGalleryPageState extends State<ThemeGalleryPage> {
  late var _locale = widget.initialLocale;
  late var _brightness = widget.initialBrightness;
  late var _palette = widget.initialPalette;
  var _bottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final direction = _locale.languageCode == 'ar'
        ? TextDirection.rtl
        : TextDirection.ltr;

    return Theme(
      data: buildAppTheme(
        palette: _palette,
        brightness: _brightness,
        locale: _locale,
      ),
      child: Directionality(
        textDirection: direction,
        child: Builder(
          builder: (context) {
            final colors = AppColors.of(context);
            return Scaffold(
              backgroundColor: colors.surface,
              appBar: const AppAppBar(title: 'Theme Gallery'),
              body: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Switchers(
                      locale: _locale,
                      brightness: _brightness,
                      palette: _palette,
                      onLocaleChanged: (locale) => setState(() {
                        _locale = locale;
                      }),
                      onBrightnessChanged: (brightness) => setState(() {
                        _brightness = brightness;
                      }),
                      onPaletteChanged: (palette) => setState(() {
                        _palette = palette;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _Section(
                      title: 'Chrome',
                      children: [
                        const AppAppBar(title: 'Default'),
                        AppAppBar(
                          title: 'Back',
                          variant: AppAppBarVariant.withBack,
                          onBack: () {},
                        ),
                        AppAppBar(
                          title: 'Search',
                          variant: AppAppBarVariant.withSearch,
                          onSearch: () {},
                        ),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            AppButton(label: 'Primary', onPressed: () {}),
                            AppButton(
                              label: 'Success',
                              variant: AppButtonVariant.filledSuccess,
                              onPressed: () {},
                            ),
                            AppButton(
                              label: 'Outlined',
                              variant: AppButtonVariant.outlined,
                              onPressed: () {},
                            ),
                            AppButton(
                              label: 'Loading',
                              loading: true,
                              onPressed: () {},
                            ),
                            AppButton.iconButton(
                              icon: LucideIcons.search,
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Inputs',
                      children: [
                        const SearchField(hint: 'Search listings'),
                        SearchField(
                          hint: 'Loading search',
                          loading: true,
                          showFilterIcon: true,
                          onFilterPressed: () {},
                        ),
                        LocationSelector(
                          city: 'Damascus',
                          area: 'Malki',
                          onTap: () {},
                        ),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            CategoryChip(
                              label: 'Apartment',
                              icon: LucideIcons.building_2,
                              selected: true,
                              onPressed: () {},
                            ),
                            CategoryChip(
                              label: 'Land',
                              icon: LucideIcons.trees,
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const AppTextField(
                          label: 'Name',
                          initialValue: 'Ahmad',
                        ),
                        const AppTextField(
                          label: 'Error field',
                          errorText: 'Required',
                        ),
                        const AppPhoneField(label: 'Phone'),
                        const AppPasswordField(label: 'Password'),
                        const AppMultiLineField(
                          label: 'Description',
                          maxLength: 1000,
                        ),
                        const AppNumberField(label: 'Area', unit: 'm2'),
                        const AppCurrencyField(label: 'Price'),
                        AppDropdown<String>(
                          label: 'Type',
                          value: 'sale',
                          items: const [
                            DropdownMenuItem(
                              value: 'sale',
                              child: Text('Sale'),
                            ),
                            DropdownMenuItem(
                              value: 'rent',
                              child: Text('Rent'),
                            ),
                          ],
                          onChanged: (_) {},
                        ),
                        AppStepperInput(value: 2, onChanged: (_) {}),
                        AppDatePicker(
                          value: DateTime(2026, 5, 3),
                          label: 'Date',
                        ),
                        Row(
                          children: [
                            AppToggle(value: true, onChanged: (_) {}),
                            AppCheckbox(value: true, onChanged: (_) {}),
                          ],
                        ),
                        AppRadioGroup<int>(
                          values: const [1, 2, 3],
                          labels: const ['One', 'Two', 'Three'],
                          groupValue: 1,
                          onChanged: (_) {},
                        ),
                        AppTabs(
                          labels: const ['A', 'B', 'C'],
                          selectedIndex: 0,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Cards',
                      children: [
                        PropertyCard(
                          title: 'Modern apartment with balcony',
                          price: '250,000,000',
                          location: 'Damascus / Malki',
                          featured: true,
                          favorite: true,
                          onLongPress: () {},
                        ),
                        const PropertyCard(
                          title: 'Horizontal card',
                          price: '800',
                          currency: 'USD',
                          location: 'Aleppo',
                          layout: PropertyCardLayout.horizontal,
                        ),
                        OfficeCard(
                          name: 'AlNujom Office',
                          listingsCount: 42,
                          verified: true,
                          onVisit: () {},
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Badges',
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final variant in AppBadgeVariant.values)
                              AppBadge(label: variant.name, variant: variant),
                          ],
                        ),
                      ],
                    ),
                    const _Section(
                      title: 'Sheets',
                      children: [
                        SizedBox(
                          height: 220,
                          child: AppBottomSheet(
                            footer: Text('Sticky footer'),
                            child: Text('Scrollable sheet body'),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Dialogs',
                      children: [
                        AppDialog(
                          title: 'Confirm listing',
                          message: 'This previews the confirm dialog.',
                          actionLabel: 'Confirm',
                          onAction: () {},
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Feedback',
                      children: [
                        const EmptyState(
                          headline: 'No listings yet',
                          body: 'Create the first listing to see it here.',
                        ),
                        const LoadingState.card(),
                        ErrorState(title: 'Could not load', onRetry: () {}),
                      ],
                    ),
                    _Section(
                      title: 'Media',
                      children: [
                        const StepperIndicator(steps: 4, currentIndex: 1),
                        const ImageGallery(imageUrls: []),
                        MapPreview(onTap: () {}),
                      ],
                    ),
                    const _Section(
                      title: 'Chat',
                      children: [
                        ChatBubble(
                          message: 'Is this listing still available?',
                          variant: ChatBubbleVariant.theirs,
                        ),
                        ChatBubble(
                          message: 'Yes, you can visit today.',
                          variant: ChatBubbleVariant.mine,
                        ),
                      ],
                    ),
                    const _Section(
                      title: 'Price',
                      children: [
                        PriceTag(
                          amount: '250,000,000',
                          currency: 'ل.س',
                          altText: '≈ 18,000 USD',
                        ),
                      ],
                    ),
                    _Section(
                      title: 'BottomNav',
                      children: [
                        AppBottomNav(
                          currentIndex: _bottomNavIndex,
                          onTabSelected: (index) => setState(() {
                            _bottomNavIndex = index;
                          }),
                          onAddPressed: () {},
                        ),
                      ],
                    ),
                    const _Section(
                      title: 'PaletteTester',
                      children: [
                        // Chip is mounted globally as a floating overlay in
                        // app.dart; the disabled preview avoids double-mount
                        // and keeps this section free of a PaletteCubit dep.
                        SizedBox(
                          height: 80,
                          child: Stack(
                            children: [
                              PaletteTester(designToolsEnabled: false),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Switchers extends StatelessWidget {
  const _Switchers({
    required this.locale,
    required this.brightness,
    required this.palette,
    required this.onLocaleChanged,
    required this.onBrightnessChanged,
    required this.onPaletteChanged,
  });

  final Locale locale;
  final Brightness brightness;
  final ColorPalette palette;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<Brightness> onBrightnessChanged;
  final ValueChanged<ColorPalette> onPaletteChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        SegmentedButton<String>(
          key: const ValueKey<String>('theme-gallery-locale-switcher'),
          segments: const [
            ButtonSegment(value: 'ar', label: Text('ar')),
            ButtonSegment(value: 'en', label: Text('en')),
          ],
          selected: {locale.languageCode},
          onSelectionChanged: (selected) {
            onLocaleChanged(Locale(selected.first));
          },
        ),
        SegmentedButton<Brightness>(
          key: const ValueKey<String>('theme-gallery-theme-switcher'),
          segments: const [
            ButtonSegment(value: Brightness.light, label: Text('light')),
            ButtonSegment(value: Brightness.dark, label: Text('dark')),
          ],
          selected: {brightness},
          onSelectionChanged: (selected) {
            onBrightnessChanged(selected.first);
          },
        ),
        SegmentedButton<String>(
          key: const ValueKey<String>('theme-gallery-palette-switcher'),
          segments: const [
            ButtonSegment(value: 'modern', label: Text('Modern')),
            ButtonSegment(value: 'trust', label: Text('Trust')),
          ],
          selected: {palette.name},
          onSelectionChanged: (selected) {
            onPaletteChanged(ColorPalette.fromName(selected.first));
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: styles.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              border: Border.all(color: colors.outline),
              borderRadius: appRadius(AppRadii.md),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final child in children) ...[
                    child,
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
