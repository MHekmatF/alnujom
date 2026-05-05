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
import '../core/widgets/price_tag.dart';
import '../core/widgets/property_card.dart';
import '../core/widgets/search_field.dart';
import '../core/widgets/stepper_indicator.dart';
import '../l10n/app_localizations.dart';

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
  ];

  static List<String> sectionHeadersFor(Locale locale) =>
      _GalleryCopy.forLocale(locale).sectionHeaders;

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
            final copy = _GalleryCopy.forLocale(_locale);
            final loc = lookupAppLocalizations(_locale);
            final styles = AppTextStyles.of(context);
            return Scaffold(
              backgroundColor: colors.surface,
              appBar: AppAppBar(title: loc.themeGalleryTitle),
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
                    Text(
                      loc.themeGalleryComponentsSectionHeader,
                      style: styles.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Section(
                      title: copy.chrome,
                      children: [
                        AppAppBar(title: copy.defaultLabel),
                        AppAppBar(
                          title: copy.back,
                          variant: AppAppBarVariant.withBack,
                          onBack: () {},
                        ),
                        AppAppBar(
                          title: copy.search,
                          variant: AppAppBarVariant.withSearch,
                          onSearch: () {},
                        ),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            AppButton(label: copy.primary, onPressed: () {}),
                            AppButton(
                              label: copy.success,
                              variant: AppButtonVariant.filledSuccess,
                              onPressed: () {},
                            ),
                            AppButton(
                              label: copy.outlined,
                              variant: AppButtonVariant.outlined,
                              onPressed: () {},
                            ),
                            AppButton(
                              label: copy.loading,
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
                      title: copy.inputs,
                      children: [
                        SearchField(hint: copy.searchListings),
                        SearchField(
                          hint: copy.loadingSearch,
                          loading: true,
                          showFilterIcon: true,
                          onFilterPressed: () {},
                        ),
                        LocationSelector(
                          city: copy.damascus,
                          area: copy.malki,
                          onTap: () {},
                        ),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            CategoryChip(
                              label: copy.apartment,
                              icon: LucideIcons.building_2,
                              selected: true,
                              onPressed: () {},
                            ),
                            CategoryChip(
                              label: copy.land,
                              icon: LucideIcons.trees,
                              onPressed: () {},
                            ),
                          ],
                        ),
                        AppTextField(
                          label: copy.name,
                          initialValue: copy.sampleName,
                        ),
                        AppTextField(
                          label: copy.errorField,
                          errorText: copy.required,
                        ),
                        AppPhoneField(label: copy.phone),
                        AppPasswordField(label: copy.password),
                        AppMultiLineField(
                          label: copy.description,
                          maxLength: 1000,
                        ),
                        AppNumberField(label: copy.area, unit: copy.areaUnit),
                        AppCurrencyField(label: copy.price),
                        AppDropdown<String>(
                          label: copy.type,
                          value: 'sale',
                          items: [
                            DropdownMenuItem(
                              value: 'sale',
                              child: Text(copy.sale),
                            ),
                            DropdownMenuItem(
                              value: 'rent',
                              child: Text(copy.rent),
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
                          labels: [copy.one, copy.two, copy.three],
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
                      title: copy.cards,
                      children: [
                        PropertyCard(
                          title: copy.propertyTitle,
                          price: '250,000,000',
                          location: copy.propertyLocation,
                          featured: true,
                          favorite: true,
                          onLongPress: () {},
                        ),
                        PropertyCard(
                          title: copy.horizontalCard,
                          price: '800',
                          currency: 'USD',
                          location: copy.aleppo,
                          layout: PropertyCardLayout.horizontal,
                        ),
                        OfficeCard(
                          name: copy.officeName,
                          listingsCount: 42,
                          verified: true,
                          onVisit: () {},
                        ),
                      ],
                    ),
                    _Section(
                      title: copy.badges,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final variant in AppBadgeVariant.values)
                              AppBadge(
                                label: copy.badgeLabel(variant),
                                variant: variant,
                              ),
                          ],
                        ),
                      ],
                    ),
                    _Section(
                      title: copy.sheets,
                      children: [
                        SizedBox(
                          height: 220,
                          child: AppBottomSheet(
                            footer: Text(copy.stickyFooter),
                            child: Text(copy.scrollableSheetBody),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: copy.dialogs,
                      children: [
                        AppDialog(
                          title: copy.confirmListing,
                          message: copy.confirmMessage,
                          actionLabel: copy.confirm,
                          onAction: () {},
                        ),
                      ],
                    ),
                    _Section(
                      title: copy.feedback,
                      children: [
                        EmptyState(
                          headline: copy.noListings,
                          body: copy.createFirstListing,
                        ),
                        const LoadingState.card(),
                        ErrorState(title: copy.couldNotLoad, onRetry: () {}),
                      ],
                    ),
                    _Section(
                      title: copy.media,
                      children: [
                        const StepperIndicator(steps: 4, currentIndex: 1),
                        const ImageGallery(imageUrls: []),
                        MapPreview(onTap: () {}),
                      ],
                    ),
                    _Section(
                      title: copy.chat,
                      children: [
                        ChatBubble(
                          message: copy.chatQuestion,
                          variant: ChatBubbleVariant.theirs,
                        ),
                        ChatBubble(
                          message: copy.chatAnswer,
                          variant: ChatBubbleVariant.mine,
                        ),
                      ],
                    ),
                    _Section(
                      title: copy.priceSection,
                      children: [
                        const PriceTag(
                          amount: '250,000,000',
                          currency: 'ل.س',
                          altText: '≈ 18,000 USD',
                        ),
                      ],
                    ),
                    _Section(
                      title: copy.bottomNav,
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

final class _GalleryCopy {
  const _GalleryCopy({required this.isArabic});

  factory _GalleryCopy.forLocale(Locale locale) =>
      _GalleryCopy(isArabic: locale.languageCode == 'ar');

  final bool isArabic;

  String get title => isArabic ? 'معرض التصميم' : 'Theme Gallery';
  String get chrome => isArabic ? 'الشريط والتنقل' : 'Chrome';
  String get inputs => isArabic ? 'الإدخالات' : 'Inputs';
  String get cards => isArabic ? 'البطاقات' : 'Cards';
  String get badges => isArabic ? 'الشارات' : 'Badges';
  String get sheets => isArabic ? 'الألواح' : 'Sheets';
  String get dialogs => isArabic ? 'الحوارات' : 'Dialogs';
  String get feedback => isArabic ? 'الحالات' : 'Feedback';
  String get media => isArabic ? 'الوسائط' : 'Media';
  String get chat => isArabic ? 'المحادثة' : 'Chat';
  String get priceSection => isArabic ? 'السعر' : 'Price';
  String get bottomNav => isArabic ? 'التنقل السفلي' : 'BottomNav';

  List<String> get sectionHeaders => [
    chrome,
    inputs,
    cards,
    badges,
    sheets,
    dialogs,
    feedback,
    media,
    chat,
    priceSection,
    bottomNav,
  ];

  String get defaultLabel => isArabic ? 'افتراضي' : 'Default';
  String get back => isArabic ? 'رجوع' : 'Back';
  String get search => isArabic ? 'بحث' : 'Search';
  String get primary => isArabic ? 'أساسي' : 'Primary';
  String get success => isArabic ? 'نجاح' : 'Success';
  String get outlined => isArabic ? 'محدد' : 'Outlined';
  String get loading => isArabic ? 'تحميل' : 'Loading';

  String get searchListings => isArabic ? 'ابحث عن عقارات' : 'Search listings';
  String get loadingSearch => isArabic ? 'جار البحث' : 'Loading search';
  String get damascus => isArabic ? 'دمشق' : 'Damascus';
  String get malki => isArabic ? 'المالكي' : 'Malki';
  String get aleppo => isArabic ? 'حلب' : 'Aleppo';
  String get apartment => isArabic ? 'شقة' : 'Apartment';
  String get land => isArabic ? 'أرض' : 'Land';
  String get name => isArabic ? 'الاسم' : 'Name';
  String get sampleName => isArabic ? 'أحمد' : 'Ahmad';
  String get errorField => isArabic ? 'حقل فيه خطأ' : 'Error field';
  String get required => isArabic ? 'مطلوب' : 'Required';
  String get phone => isArabic ? 'الهاتف' : 'Phone';
  String get password => isArabic ? 'كلمة المرور' : 'Password';
  String get description => isArabic ? 'الوصف' : 'Description';
  String get area => isArabic ? 'المساحة' : 'Area';
  String get areaUnit => isArabic ? 'م²' : 'm2';
  String get price => isArabic ? 'السعر' : 'Price';
  String get type => isArabic ? 'النوع' : 'Type';
  String get sale => isArabic ? 'بيع' : 'Sale';
  String get rent => isArabic ? 'إيجار' : 'Rent';
  String get one => isArabic ? 'واحد' : 'One';
  String get two => isArabic ? 'اثنان' : 'Two';
  String get three => isArabic ? 'ثلاثة' : 'Three';

  String get propertyTitle =>
      isArabic ? 'شقة حديثة مع شرفة' : 'Modern apartment with balcony';
  String get propertyLocation =>
      isArabic ? 'دمشق / المالكي' : 'Damascus / Malki';
  String get horizontalCard => isArabic ? 'بطاقة أفقية' : 'Horizontal card';
  String get officeName => isArabic ? 'مكتب النجوم' : 'AlNujom Office';

  String badgeLabel(AppBadgeVariant variant) => switch (variant) {
    AppBadgeVariant.featured => isArabic ? 'مميز' : 'Featured',
    AppBadgeVariant.fresh => isArabic ? 'جديد' : 'New',
    AppBadgeVariant.statusPending => isArabic ? 'قيد المراجعة' : 'Pending',
    AppBadgeVariant.statusApproved => isArabic ? 'مقبول' : 'Approved',
    AppBadgeVariant.statusRejected => isArabic ? 'مرفوض' : 'Rejected',
    AppBadgeVariant.verifiedOffice =>
      isArabic ? 'مكتب موثق' : 'Verified office',
  };

  String get stickyFooter => isArabic ? 'تذييل ثابت' : 'Sticky footer';
  String get scrollableSheetBody =>
      isArabic ? 'محتوى قابل للتمرير' : 'Scrollable sheet body';
  String get confirmListing => isArabic ? 'تأكيد الإعلان' : 'Confirm listing';
  String get confirmMessage => isArabic
      ? 'هذه معاينة لحوار التأكيد.'
      : 'This previews the confirm dialog.';
  String get confirm => isArabic ? 'تأكيد' : 'Confirm';
  String get noListings => isArabic ? 'لا توجد إعلانات بعد' : 'No listings yet';
  String get createFirstListing => isArabic
      ? 'أنشئ أول إعلان ليظهر هنا.'
      : 'Create the first listing to see it here.';
  String get couldNotLoad => isArabic ? 'تعذر التحميل' : 'Could not load';
  String get chatQuestion => isArabic
      ? 'هل ما زال هذا العقار متاحا؟'
      : 'Is this listing still available?';
  String get chatAnswer =>
      isArabic ? 'نعم، يمكنك زيارته اليوم.' : 'Yes, you can visit today.';
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
    final loc = lookupAppLocalizations(locale);
    final styles = AppTextStyles.of(context);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.themeGalleryLocaleSectionHeader,
              style: styles.labelMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
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
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.themeGalleryThemeSectionHeader, style: styles.labelMedium),
            const SizedBox(height: AppSpacing.xs),
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
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.themeGalleryPaletteSectionHeader,
              style: styles.labelMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
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
