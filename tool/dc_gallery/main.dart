// DC "Blue Crown" widget gallery — a STANDALONE dev harness (never shipped).
//
// Renders the new DC design-system widgets with mock data so their pixel-craft
// can be eye-verified on the AVD (light/dark × ar/en) WITHOUT logging in or
// touching the backend — the login-gated publisher screens can't otherwise be
// seen. Lives under tool/ (outside lib/) so it is exempt from the l10n-literal
// linter and can use literal demo strings.
//
// Build:  flutter build apk --debug -t tool/dc_gallery/main.dart --dart-define-from-file=.env.json
// (Reinstall the real app afterwards.)
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import 'package:alnujom/core/theme/app_theme.dart';
import 'package:alnujom/core/theme/color_palette.dart';
import 'package:alnujom/core/theme/colors.dart';
import 'package:alnujom/core/theme/radii.dart';
import 'package:alnujom/core/theme/spacing.dart';
import 'package:alnujom/core/theme/typography.dart';
import 'package:alnujom/core/widgets/_widget_support.dart';
import 'package:alnujom/core/widgets/app_button.dart';
import 'package:alnujom/core/widgets/charts/dc_bar_chart.dart';
import 'package:alnujom/core/widgets/charts/dc_line_chart.dart';
import 'package:alnujom/core/widgets/dc_crown_scaffold.dart';
import 'package:alnujom/core/widgets/ds/dc_quick_link_tile.dart';
import 'package:alnujom/core/widgets/ds/dc_stat_card.dart';
import 'package:alnujom/core/widgets/ds/dc_meta_chip.dart';
import 'package:alnujom/core/widgets/ds/dc_status_chip.dart';
import 'package:alnujom/core/widgets/ds/dc_timeline.dart';
import 'package:alnujom/features/auth/presentation/widgets/auth_status_message.dart';

void main() => runApp(const DcGalleryApp());

class DcGalleryApp extends StatefulWidget {
  const DcGalleryApp({super.key});

  @override
  State<DcGalleryApp> createState() => _DcGalleryAppState();
}

class _DcGalleryAppState extends State<DcGalleryApp> {
  Brightness _brightness = Brightness.light;
  Locale _locale = const Locale('ar');

  void _toggleTheme() => setState(() {
    _brightness = _brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;
  });

  void _toggleLocale() => setState(() {
    _locale = _locale.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        palette: const ModernPalette(),
        brightness: Brightness.light,
        locale: _locale,
      ),
      darkTheme: buildAppTheme(
        palette: const ModernPalette(),
        brightness: Brightness.dark,
        locale: _locale,
      ),
      themeMode: _brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: _locale,
      home: DcGalleryHome(
        onToggleTheme: _toggleTheme,
        onToggleLocale: _toggleLocale,
        isArabic: _locale.languageCode == 'ar',
      ),
    );
  }
}

class DcGalleryHome extends StatelessWidget {
  const DcGalleryHome({
    required this.onToggleTheme,
    required this.onToggleLocale,
    required this.isArabic,
    super.key,
  });

  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final ar = isArabic;
    return DcCrownScaffold(
      title: ar ? 'المعرض' : 'Gallery',
      titleWidget: _Identity(
        name: ar ? 'مكتب الشام العقاري' : 'Al Sham Real Estate',
        subtitle: ar ? 'وكيل معتمد' : 'Verified agent',
      ),
      actions: [
        DcCrownIconButton(icon: Icons.translate, onTap: onToggleLocale),
        DcCrownIconButton(icon: Icons.brightness_6, onTap: onToggleTheme),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _Label(ar ? 'بطاقات المؤشرات' : 'KPI cards'),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.5,
            children: [
              DcStatCard(
                icon: Icons.campaign,
                value: '6',
                label: ar ? 'إعلانات نشطة' : 'Active listings',
                sub: ar ? 'من 8 إجمالاً' : 'of 8 total',
                delta: '+1',
                onTap: () {},
              ),
              DcStatCard(
                icon: Icons.visibility,
                value: '4,820',
                label: ar ? 'مشاهدات الشهر' : 'Views this month',
                delta: '+12%',
                onTap: () {},
              ),
              DcStatCard(
                icon: Icons.hourglass_empty,
                value: '2',
                label: ar ? 'قيد المراجعة' : 'Pending review',
              ),
              DcStatCard(
                icon: Icons.trending_up,
                value: '128',
                label: ar ? 'تفاعلات العملاء' : 'Lead interactions',
                delta: '-3%',
                trendUp: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Label(ar ? 'مخطط التفاعلات' : 'Interactions chart'),
          const SizedBox(height: AppSpacing.md),
          DcBarChart(
            title: ar ? 'التفاعلات' : 'Interactions',
            rangeLabel: ar ? 'آخر 7 أيام' : 'Last 7 days',
            totalValue: '3,940',
            totalLabel: ar ? 'الإجمالي' : 'Total',
            bars: const [
              DcBarChartBar(value: 420, label: '12'),
              DcBarChartBar(value: 510, label: '13'),
              DcBarChartBar(value: 380, label: '14'),
              DcBarChartBar(value: 640, label: '15'),
              DcBarChartBar(value: 590, label: '16'),
              DcBarChartBar(value: 720, label: '17'),
              DcBarChartBar(value: 680, label: '18'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Label(ar ? 'مخطط خطي' : 'Line chart'),
          const SizedBox(height: AppSpacing.md),
          // Native CustomPaint (DcLineChart) — the chosen chart engine.
          DcLineChart(
            title: ar ? 'التطوّر' : 'Growth',
            totalValue: '34',
            totalLabel: ar ? 'إعلانات' : 'Listings',
            values: const [3, 5, 2, 8, 15, 7],
            labels: ar
                ? const ['شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز']
                : const ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Label(ar ? 'روابط سريعة' : 'Quick links'),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.92,
            children: [
              DcQuickLinkTile(
                icon: Icons.apartment,
                label: ar ? 'إعلاناتي' : 'My listings',
                onTap: () {},
              ),
              DcQuickLinkTile(
                icon: Icons.forum_outlined,
                label: ar ? 'الاستفسارات' : 'Inquiries',
                badgeLabel: '2',
                onTap: () {},
              ),
              DcQuickLinkTile(
                icon: Icons.event_outlined,
                label: ar ? 'المعاينات' : 'Viewings',
                badgeLabel: '1',
                onTap: () {},
              ),
              DcQuickLinkTile(
                icon: Icons.groups_outlined,
                label: ar ? 'العملاء' : 'Customers',
                onTap: () {},
              ),
              DcQuickLinkTile(
                icon: Icons.bar_chart,
                label: ar ? 'التحليلات' : 'Analytics',
                onTap: () {},
              ),
              DcQuickLinkTile(
                icon: Icons.fact_check_outlined,
                label: ar ? 'المراجعة' : 'Moderation',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Label(ar ? 'شارات الحالة' : 'Status chips'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              DcStatusChip(
                label: ar ? 'منشور' : 'Live',
                tone: DcStatusTone.green,
                icon: Icons.check_circle,
              ),
              DcStatusChip(
                label: ar ? 'قيد المراجعة' : 'Pending',
                tone: DcStatusTone.neutral,
                icon: Icons.hourglass_empty,
              ),
              DcStatusChip(
                label: ar ? 'مرفوض' : 'Rejected',
                tone: DcStatusTone.red,
                icon: Icons.cancel,
              ),
              DcStatusChip(
                label: ar ? 'مسودّة' : 'Draft',
                tone: DcStatusTone.outline,
                icon: Icons.edit_outlined,
              ),
              DcStatusChip(
                label: ar ? 'منتهٍ' : 'Expired',
                tone: DcStatusTone.neutral,
                icon: Icons.history,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              DcStatusChip(
                label: ar ? 'مغلق · ناجح' : 'Closed · won',
                tone: DcStatusTone.green,
                dot: true,
              ),
              DcStatusChip(
                label: ar ? 'تفاوض' : 'Negotiating',
                tone: DcStatusTone.neutral,
                dot: true,
              ),
              DcStatusChip(
                label: ar ? 'مغلق · خسارة' : 'Closed · lost',
                tone: DcStatusTone.red,
                dot: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              DcMetaChip(
                icon: Icons.forum_outlined,
                label: ar ? 'محادثة' : 'Chat',
              ),
              DcMetaChip(
                icon: Icons.mail_outline,
                label: ar ? 'استفسار' : 'Inquiry',
              ),
              DcMetaChip(
                icon: Icons.event_outlined,
                label: ar ? 'معاينة' : 'Viewing',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Label(ar ? 'سجل المراجعة' : 'Moderation timeline'),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: appRadius(AppRadii.lg),
              border: Border.all(color: AppColors.of(context).outline),
            ),
            child: DcModerationTimeline(
              nodes: [
                DcTimelineNode(
                  icon: Icons.verified,
                  tone: DcStatusTone.green,
                  title: ar ? 'تم توثيق الإعلان ميدانياً' : 'Field-verified',
                  time: ar ? 'اليوم · 2:14 م' : 'Today · 2:14 PM',
                ),
                DcTimelineNode(
                  icon: Icons.check_circle,
                  tone: DcStatusTone.green,
                  title: ar ? 'تمت الموافقة والنشر' : 'Approved & published',
                  time: ar ? 'أمس · 6:40 م' : 'Yesterday · 6:40 PM',
                ),
                DcTimelineNode(
                  icon: Icons.cancel,
                  tone: DcStatusTone.red,
                  title: ar ? 'طُلب تعديل' : 'Revision requested',
                  time: ar ? 'منذ 3 أيام' : '3 days ago',
                  body: ar
                      ? 'الصور غير واضحة — يرجى رفع صور أعلى جودة للواجهة.'
                      : 'Photos are unclear — please upload higher-quality shots.',
                ),
                DcTimelineNode(
                  icon: Icons.upload_file,
                  tone: DcStatusTone.neutral,
                  title: ar ? 'أُرسل الإعلان للمراجعة' : 'Submitted for review',
                  time: ar ? 'منذ 4 أيام' : '4 days ago',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Label(ar ? 'شاشات حالة الحساب' : 'Account status screens'),
          const SizedBox(height: AppSpacing.md),
          _StatusScreenButtons(ar: ar),
        ],
      ),
    );
  }
}

/// Launcher buttons for the 4 account-gate screens (pending / publisher-pending
/// / rejected / suspended). Each pushes a full-screen [_StatusScreenDemo] so the
/// DC crown chrome (blue header + white sheet) wrapping the shared
/// [AuthStatusMessage] can be eye-verified — those pages only appear for a
/// specially-statused account, so they can't be reached in the running app.
class _StatusScreenButtons extends StatelessWidget {
  const _StatusScreenButtons({required this.ar});

  final bool ar;

  @override
  Widget build(BuildContext context) {
    final signOut = ar ? 'تسجيل الخروج' : 'Sign out';
    final items =
        <
          ({
            String title,
            IconData icon,
            AuthStatusTone tone,
            String message,
            bool crownSignOut,
            bool bodySignOut,
          })
        >[
          (
            title: ar ? 'قيد الموافقة' : 'Pending approval',
            icon: LucideIcons.clock,
            tone: AuthStatusTone.neutral,
            message: ar
                ? 'حسابك قيد المراجعة من قِبل الفريق. سنُعلمك فور الموافقة عليه.'
                : 'Your account is under review. We will notify you once it is approved.',
            crownSignOut: true,
            bodySignOut: false,
          ),
          (
            title: ar ? 'طلب النشر قيد المراجعة' : 'Publisher request pending',
            icon: LucideIcons.badge_check,
            tone: AuthStatusTone.neutral,
            message: ar
                ? 'طلبك لتصبح ناشراً قيد المراجعة. يمكنك التصفّح ريثما تتم الموافقة.'
                : 'Your request to become a publisher is under review. You can browse meanwhile.',
            crownSignOut: false,
            bodySignOut: false,
          ),
          (
            title: ar ? 'تم رفض الحساب' : 'Account rejected',
            icon: LucideIcons.circle_x,
            tone: AuthStatusTone.error,
            message: ar
                ? 'نأسف، لم تتم الموافقة على حسابك. السبب: بيانات غير مكتملة.'
                : 'Sorry, your account was not approved. Reason: incomplete details.',
            crownSignOut: false,
            bodySignOut: true,
          ),
          (
            title: ar ? 'الحساب موقوف' : 'Account suspended',
            icon: LucideIcons.ban,
            tone: AuthStatusTone.warning,
            message: ar
                ? 'تم إيقاف حسابك مؤقتاً. تواصل مع الدعم لمزيد من المعلومات.'
                : 'Your account has been suspended. Contact support for more information.',
            crownSignOut: false,
            bodySignOut: true,
          ),
        ];

    return Column(
      children: [
        for (final it in items) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(it.icon),
              label: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(it.title),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _StatusScreenDemo(
                    title: it.title,
                    icon: it.icon,
                    tone: it.tone,
                    message: it.message,
                    crownSignOut: it.crownSignOut,
                    bodySignOut: it.bodySignOut,
                    signOutLabel: signOut,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Faithful full-screen proxy of an account-gate page: the exact widget tree the
/// real page builds — [DcCrownScaffold] (title + optional crown sign-out action)
/// over a padded, centred [AuthStatusMessage] (with an optional in-body sign-out
/// button) — minus only the [AuthBloc] wiring, which is behaviour, not visuals.
class _StatusScreenDemo extends StatelessWidget {
  const _StatusScreenDemo({
    required this.title,
    required this.icon,
    required this.tone,
    required this.message,
    required this.crownSignOut,
    required this.bodySignOut,
    required this.signOutLabel,
  });

  final String title;
  final IconData icon;
  final AuthStatusTone tone;
  final String message;
  final bool crownSignOut;
  final bool bodySignOut;
  final String signOutLabel;

  @override
  Widget build(BuildContext context) {
    return DcCrownScaffold(
      title: title,
      dense: true,
      actions: crownSignOut
          ? [DcCrownTextButton(label: signOutLabel, onTap: () {})]
          : null,
      body: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: AuthStatusMessage(
          icon: icon,
          tone: tone,
          title: title,
          message: message,
          action: bodySignOut
              ? AppButton(
                  label: signOutLabel,
                  variant: AppButtonVariant.outlined,
                  onPressed: () {},
                )
              : null,
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final onHeader = colors.onBrandHeader;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onHeader.withValues(alpha: 0.16),
            borderRadius: appRadius(AppRadii.md),
          ),
          child: Icon(Icons.storefront, size: 24, color: onHeader),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.titleMedium.copyWith(
                        color: onHeader,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(Icons.verified, size: 16, color: onHeader),
                ],
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.labelSmall.copyWith(
                  color: onHeader.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Text(
      text,
      style: styles.labelLarge.copyWith(color: colors.onSurface),
    );
  }
}

