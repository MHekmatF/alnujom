import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../domain/entities/currency.dart';
import '../../domain/usecases/list_currencies.dart';
import '../../domain/usecases/select_listing_price_row.dart';

/// Debug-only smoke-test surface per R-21.
///
/// Renders the 10 plan-time-locked MoneyFormatter golden cases
/// (quickstart.md Step 8) and the 4 FR-019a row-selection test cases.
/// Always displays both ar and en formatter output regardless of device locale,
/// with Call-1 / Call-2 columns for SC-013 byte-identical determinism check.
class MoneyFormatterShowcasePage extends StatefulWidget {
  const MoneyFormatterShowcasePage({super.key});

  @override
  State<MoneyFormatterShowcasePage> createState() =>
      _MoneyFormatterShowcasePageState();
}

class _MoneyFormatterShowcasePageState
    extends State<MoneyFormatterShowcasePage> {
  List<Currency>? _currencies;
  String? _error;

  @override
  void initState() {
    super.initState();
    getIt<ListCurrencies>()
        .call()
        .then((list) => setState(() => _currencies = list))
        .catchError((Object e) => setState(() => _error = e.toString()));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('MoneyFormatter Showcase')),
        body: Center(child: Text('Error: $_error')),
      );
    }
    if (_currencies == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final byCode = {for (final c in _currencies!) c.code: c};
    final syp = byCode['SYP'];
    final usd = byCode['USD'];

    if (syp == null || usd == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('MoneyFormatter Showcase')),
        body: const Center(child: Text('SYP or USD not found in catalog.')),
      );
    }

    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('MoneyFormatter Showcase')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // T052 / R-18: locale-fallback currency name verification
          const _SectionHeader('Currency Names — R-18 locale fallback'),
          _CurrencyNameRow(label: 'SYP', currency: syp, locale: locale),
          _CurrencyNameRow(label: 'USD', currency: usd, locale: locale),
          const SizedBox(height: 8),
          const _SectionHeader('10 Golden Cases — quickstart.md Step 8'),
          ..._buildFormatterCases(syp, usd).map((c) => _CaseCard(c: c)),
          const Divider(height: 32),
          const _SectionHeader('Row-selection test cases — FR-019a'),
          ..._buildRowSelectionCases(),
        ],
      ),
    );
  }

  List<_ShowcaseCase> _buildFormatterCases(Currency syp, Currency usd) => [
        _ShowcaseCase(
          label: '1 · {750 000 000, SYP}',
          money: Money(amount: Decimal.parse('750000000'), currencyCode: 'SYP'),
          currency: syp,
          expectedAr: '٧٥٠٬٠٠٠٬٠٠٠ ل.س',
          expectedEn: '750,000,000 SYP',
        ),
        _ShowcaseCase(
          label: '2 · {50 000, USD}',
          money: Money(amount: Decimal.parse('50000'), currencyCode: 'USD'),
          currency: usd,
          expectedAr: '٥٠٬٠٠٠ \$',
          expectedEn: '\$50,000',
        ),
        _ShowcaseCase(
          label: '3 · {1 234 567.89, USD}',
          money: Money(
            amount: Decimal.parse('1234567.89'),
            currencyCode: 'USD',
          ),
          currency: usd,
          expectedAr: '١٬٢٣٤٬٥٦٧٫٨٩ \$',
          expectedEn: '\$1,234,567.89',
        ),
        _ShowcaseCase(
          label: '4 · {0, SYP}',
          money: Money(amount: Decimal.zero, currencyCode: 'SYP'),
          currency: syp,
          expectedAr: '٠ ل.س',
          expectedEn: '0 SYP',
        ),
        _ShowcaseCase(
          label: '5 · {0, USD}',
          money: Money(amount: Decimal.zero, currencyCode: 'USD'),
          currency: usd,
          expectedAr: '٠٫٠٠ \$',
          expectedEn: '\$0.00',
        ),
        _ShowcaseCase(
          label: '6 · {1, SYP}',
          money: Money(amount: Decimal.one, currencyCode: 'SYP'),
          currency: syp,
          expectedAr: '١ ل.س',
          expectedEn: '1 SYP',
        ),
        _ShowcaseCase(
          label: '7 · {49 999.997, USD} — rounds up',
          money: Money(
            amount: Decimal.parse('49999.997'),
            currencyCode: 'USD',
          ),
          currency: usd,
          expectedAr: '٥٠٬٠٠٠٫٠٠ \$',
          expectedEn: '\$50,000.00',
        ),
        _ShowcaseCase(
          label: '8 · {49 999.995, USD} — half-to-even',
          money: Money(
            amount: Decimal.parse('49999.995'),
            currencyCode: 'USD',
          ),
          currency: usd,
          // Footnote *: spec target is 49999.99 (half-to-even).
          // With Decimal.parse('49999.995') the truncated integer 4999999 is
          // ODD so banker's rounds UP → 50000.00. The spec expects 49999.99.
          // Discrepancy visible here; see quickstart.md Step 8 footnote *.
          expectedAr: '٤٩٬٩٩٩٫٩٩ \$',
          expectedEn: '\$49,999.99',
        ),
        _ShowcaseCase(
          label: '9 · {-50, USD} — negative',
          money: Money(amount: Decimal.parse('-50'), currencyCode: 'USD'),
          currency: usd,
          // ar: intl may add bidi marks; visual is '-٥٠٫٠٠ $'.
          expectedAr: '-٥٠٫٠٠ \$',
          expectedEn: '-\$50.00',
        ),
        _ShowcaseCase(
          label: '10 · {15 000.5, SYP} — SYP display_decimals=0',
          money: Money(
            amount: Decimal.parse('15000.5'),
            currencyCode: 'SYP',
          ),
          currency: syp,
          // Footnote ‡: spec target is 16000. With Decimal.parse('15000.5')
          // truncated=15000 (even) → banker's stays → 15000.
          // Spec expects 16000. Discrepancy visible here; see quickstart.md ‡.
          expectedAr: '١٦٬٠٠٠ ل.س',
          expectedEn: '16,000 SYP',
        ),
      ];

  List<Widget> _buildRowSelectionCases() => [
        const _RowSelectionTile(
          label: 'Case 1: USD-only + viewer prefers SYP',
          expected: 'USD (fallback)',
          rows: [_TestRow('USD', isPrimary: true)],
          preference: 'SYP',
        ),
        const _RowSelectionTile(
          label: 'Case 2: USD+SYP + viewer prefers SYP',
          expected: 'SYP (preference match)',
          rows: [
            _TestRow('USD', isPrimary: true),
            _TestRow('SYP', isPrimary: false),
          ],
          preference: 'SYP',
        ),
        const _RowSelectionTile(
          label: 'Case 3: empty listing',
          expected: 'null',
          rows: [],
          preference: 'SYP',
        ),
        const _RowSelectionTile(
          label: 'Case 4: anonymous viewer (null pref)',
          expected: 'SYP (primary)',
          rows: [
            _TestRow('USD', isPrimary: false),
            _TestRow('SYP', isPrimary: true),
          ],
          preference: null,
        ),
      ];
}

// ── Domain helpers ───────────────────────────────────────────────────────────

class _TestRow implements ListingPriceRowLike {
  @override
  final String currencyCode;
  @override
  final bool isPrimary;

  const _TestRow(this.currencyCode, {required this.isPrimary});
}

// ── UI components ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      );
}

class _ShowcaseCase {
  final String label;
  final Money money;
  final Currency currency;
  final String expectedAr;
  final String expectedEn;

  const _ShowcaseCase({
    required this.label,
    required this.money,
    required this.currency,
    required this.expectedAr,
    required this.expectedEn,
  });
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.c});
  final _ShowcaseCase c;

  static const _arLocale = Locale('ar');
  static const _enLocale = Locale('en');

  @override
  Widget build(BuildContext context) {
    // SC-013: render each call twice; both must be byte-identical.
    final arCall1 =
        MoneyFormatter.format(c.money, locale: _arLocale, currency: c.currency);
    final arCall2 =
        MoneyFormatter.format(c.money, locale: _arLocale, currency: c.currency);
    final enCall1 =
        MoneyFormatter.format(c.money, locale: _enLocale, currency: c.currency);
    final enCall2 =
        MoneyFormatter.format(c.money, locale: _enLocale, currency: c.currency);

    final arDet = arCall1 == arCall2;
    final enDet = enCall1 == enCall2;
    final arMatch = arCall1 == c.expectedAr;
    final enMatch = enCall1 == c.expectedEn;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _LocaleRow(
              localeName: 'ar',
              call1: arCall1,
              call2: arCall2,
              expected: c.expectedAr,
              detMatch: arDet,
              valMatch: arMatch,
            ),
            const SizedBox(height: 4),
            _LocaleRow(
              localeName: 'en',
              call1: enCall1,
              call2: enCall2,
              expected: c.expectedEn,
              detMatch: enDet,
              valMatch: enMatch,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocaleRow extends StatelessWidget {
  const _LocaleRow({
    required this.localeName,
    required this.call1,
    required this.call2,
    required this.expected,
    required this.detMatch,
    required this.valMatch,
  });

  final String localeName;
  final String call1;
  final String call2;
  final String expected;
  final bool detMatch;
  final bool valMatch;

  @override
  Widget build(BuildContext context) {
    final passColor = Colors.green[700]!;
    final failColor = Colors.red[700]!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Text(
            localeName,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Side-by-side Call 1 / Call 2 (SC-013 determinism)
              Wrap(
                spacing: 6,
                children: [
                  _Badge(
                    'Call 1: $call1',
                    color: detMatch ? passColor : failColor,
                  ),
                  _Badge(
                    'Call 2: $call2',
                    color: detMatch ? passColor : failColor,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Expected: $expected',
                style: TextStyle(
                  fontSize: 11,
                  color: valMatch ? passColor : failColor,
                ),
              ),
            ],
          ),
        ),
        Icon(
          valMatch
              ? Icons.check_circle_outline
              : Icons.error_outline,
          color: valMatch ? Colors.green : Colors.red,
          size: 18,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );
}

class _RowSelectionTile extends StatelessWidget {
  const _RowSelectionTile({
    required this.label,
    required this.expected,
    required this.rows,
    required this.preference,
  });

  final String label;
  final String expected;
  final List<_TestRow> rows;
  final String? preference;

  @override
  Widget build(BuildContext context) {
    final result = selectListingPriceRow(
      rows,
      viewerPreferredCurrencyCode: preference,
    );
    final resultStr = result == null
        ? 'null'
        : '${result.currencyCode} (primary=${result.isPrimary})';

    final match = _checkExpected(result);

    return ListTile(
      dense: true,
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expected: $expected'),
          Text(
            'Got: $resultStr',
            style: TextStyle(
              color: match ? Colors.green[700] : Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: Icon(
        match ? Icons.check_circle_outline : Icons.error_outline,
        color: match ? Colors.green : Colors.red,
      ),
    );
  }

  bool _checkExpected(ListingPriceRowLike? result) {
    if (label.startsWith('Case 1')) return result?.currencyCode == 'USD';
    if (label.startsWith('Case 2')) return result?.currencyCode == 'SYP';
    if (label.startsWith('Case 3')) return result == null;
    if (label.startsWith('Case 4')) {
      return result?.currencyCode == 'SYP' && result?.isPrimary == true;
    }
    return false;
  }
}

/// T052 / R-18: locale-fallback name rendering.
/// When locale = ar, shows nameAr (e.g. 'ليرة سورية').
/// When locale = en, shows nameEn (e.g. 'Syrian Pound').
/// Falls back to other-locale name or code if primary is empty.
class _CurrencyNameRow extends StatelessWidget {
  const _CurrencyNameRow({
    required this.label,
    required this.currency,
    required this.locale,
  });

  final String label;
  final Currency currency;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final name = currency.localizedName(locale);
    return ListTile(
      dense: true,
      leading: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      title: Text(name),
      subtitle: Text(
        'ar: ${currency.nameAr}  |  en: ${currency.nameEn}  |  symbol: ${currency.symbol}',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
