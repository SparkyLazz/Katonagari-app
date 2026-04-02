import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';               // PdfColor, PdfPageFormat, PdfGraphics, PdfPoint
import 'package:pdf/widgets.dart' as pw;     // all layout widgets
import 'package:share_plus/share_plus.dart';

import '../../data/database/app_database.dart';
import 'preferences_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReportData — assembled by the UI and passed into generate()
// ─────────────────────────────────────────────────────────────────────────────
class ReportData {
  final String       periodLabel;  // "April 2026" | "Year 2026"
  final double       totalIncome;
  final double       totalExpense;
  final CurrencyInfo currency;
  final List<TransactionWithCategory> transactions;

  const ReportData({
    required this.periodLabel,
    required this.totalIncome,
    required this.totalExpense,
    required this.currency,
    required this.transactions,
  });

  double get netFlow => totalIncome - totalExpense;

  /// EXPENSE transactions grouped by category name, sorted largest first.
  Map<String, double> get categoryBreakdown {
    final map = <String, double>{};
    for (final t in transactions) {
      if (t.transaction.type != 'EXPENSE') continue;
      final name = t.category.name;
      map[name] = (map[name] ?? 0) + t.transaction.amount;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Top 5 largest single expense transactions.
  List<TransactionWithCategory> get topExpenses {
    final list = transactions
        .where((t) => t.transaction.type == 'EXPENSE')
        .toList()
      ..sort((a, b) => b.transaction.amount.compareTo(a.transaction.amount));
    return list.take(5).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────
class PdfReportService {
  PdfReportService._();

  // ── Brand palette (Obsidian Gold dark theme) ──────────────────────────────
  static const _gold    = PdfColor.fromInt(0xFFC8973A);
  static const _dark    = PdfColor.fromInt(0xFF1A1612);
  static const _muted   = PdfColor.fromInt(0xFF8A7D6A);
  static const _border  = PdfColor.fromInt(0xFF2C2924);
  static const _green   = PdfColor.fromInt(0xFF4A9E6A);
  static const _red     = PdfColor.fromInt(0xFFC0504D);
  static const _surface = PdfColor.fromInt(0xFF1A1815);

  static final _dateFmt = DateFormat('dd MMM yyyy');

  // ── Public entry point ────────────────────────────────────────────────────
  static Future<void> generate(ReportData data) async {
    final doc = pw.Document(
      author:  'Katonagari',
      title:   'Financial Report — ${data.periodLabel}',
      creator: 'Katonagari App',
    );

    doc.addPage(_summaryPage(data));
    if (data.transactions.length > 10) {
      doc.addPage(_transactionsPage(data));
    }

    final dir  = await getTemporaryDirectory();
    final safe = data.periodLabel.replaceAll(' ', '_');
    final file = File('${dir.path}/Katonagari_Report_$safe.pdf');
    await file.writeAsBytes(await doc.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Katonagari Financial Report — ${data.periodLabel}',
    );
  }

  // ── Page 1: Summary ────────────────────────────────────────────────────────
  static pw.Page _summaryPage(ReportData data) {
    final cur = data.currency;
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(data.periodLabel),
          pw.SizedBox(height: 24),
          _summaryStrip(data, cur),
          pw.SizedBox(height: 24),
          if (data.categoryBreakdown.isNotEmpty) ...[
            _sectionTitle('Spending by Category'),
            pw.SizedBox(height: 10),
            _categoryTable(data, cur),
            pw.SizedBox(height: 24),
          ],
          if (data.topExpenses.isNotEmpty) ...[
            _sectionTitle('Top 5 Expenses'),
            pw.SizedBox(height: 10),
            _topExpensesTable(data, cur),
          ],
          pw.Spacer(),
          _footer(),
        ],
      ),
    );
  }

  // ── Page 2: Full transaction list ─────────────────────────────────────────
  static pw.Page _transactionsPage(ReportData data) {
    final cur    = data.currency;
    final sorted = [...data.transactions]
      ..sort((a, b) => b.transaction.date.compareTo(a.transaction.date));

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _miniHeader(data.periodLabel),
          pw.SizedBox(height: 16),
          _sectionTitle('All Transactions'),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(
                color: _border, width: 0.5, style: pw.BorderStyle.solid),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(4),
              3: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _surface),
                children: [
                  _th('Date'), _th('Category'), _th('Note'), _th('Amount'),
                ],
              ),
              ...sorted.map((t) {
                final isIncome = t.transaction.type == 'INCOME';
                final sign     = isIncome ? '+' : '-';
                final color    = isIncome ? _green : _red;
                return pw.TableRow(children: [
                  _td(_dateFmt.format(t.transaction.date)),
                  _td(t.category.name),
                  _td(t.transaction.note ?? '-'),
                  _tdColor('$sign ${cur.pdfFormat(t.transaction.amount)}', color),
                ]);
              }),
            ],
          ),
          pw.Spacer(),
          _footer(),
        ],
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  static pw.Widget _header(String period) => pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: _surface,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: _gold),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Katonagari',
                style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _gold)),
            pw.SizedBox(height: 4),
            pw.Text('Financial Report',
                style: pw.TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(period,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _dark)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated ${_dateFmt.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
      ],
    ),
  );

  static pw.Widget _miniHeader(String period) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text('Katonagari',
          style: pw.TextStyle(
              fontSize: 14, fontWeight: pw.FontWeight.bold, color: _gold)),
      pw.Text(period, style: pw.TextStyle(fontSize: 11, color: _muted)),
    ],
  );

  static pw.Widget _summaryStrip(ReportData data, CurrencyInfo cur) {
    final positive = data.netFlow >= 0;
    return pw.Row(children: [
      _summaryCard('Income',  cur.pdfFormat(data.totalIncome),  _green),
      pw.SizedBox(width: 12),
      _summaryCard('Expense', cur.pdfFormat(data.totalExpense), _red),
      pw.SizedBox(width: 12),
      _summaryCard(
        positive ? 'Saved' : 'Deficit',
        cur.pdfFormat(data.netFlow.abs()),
        positive ? _green : _red,
      ),
    ]);
  }

  static pw.Widget _summaryCard(
      String label, String value, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: pw.BoxDecoration(
            color: _surface,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _border),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _muted,
                      letterSpacing: 0.5)),
              pw.SizedBox(height: 6),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      );

  static pw.Widget _sectionTitle(String text) => pw.Text(text,
      style: pw.TextStyle(
          fontSize: 13, fontWeight: pw.FontWeight.bold, color: _dark));

  static pw.Widget _categoryTable(ReportData data, CurrencyInfo cur) {
    final breakdown  = data.categoryBreakdown;
    final totalSpent = data.totalExpense == 0 ? 1.0 : data.totalExpense;

    return pw.Table(
      border: pw.TableBorder.all(
          color: _border, width: 0.5, style: pw.BorderStyle.solid),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _surface),
          children: [
            _th('Category'), _th('Amount'), _th('%'), _th('Bar'),
          ],
        ),
        ...breakdown.entries.map((e) {
          final pct         = (e.value / totalSpent * 100).clamp(0.0, 100.0);
          final pctFraction = pct / 100.0;

          return pw.TableRow(children: [
            _td(e.key),
            _td(cur.pdfFormat(e.value)),
            _td('${pct.toStringAsFixed(1)}%'),
            // Bar drawn directly via PdfGraphics — no FractionallySizedBox needed
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: pw.SizedBox(
                height: 6,
                child: pw.CustomPaint(
                  painter: (PdfGraphics canvas, PdfPoint size) {
                    // Track
                    canvas
                      ..setFillColor(_border)
                      ..drawRRect(0, 0, size.x, size.y, 3, 3)
                      ..fillPath();
                    // Fill
                    final fillW = (size.x * pctFraction).clamp(0.0, size.x);
                    if (fillW > 1) {
                      canvas
                        ..setFillColor(_gold)
                        ..drawRRect(0, 0, fillW, size.y, 3, 3)
                        ..fillPath();
                    }
                  },
                ),
              ),
            ),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _topExpensesTable(ReportData data, CurrencyInfo cur) =>
      pw.Table(
        border: pw.TableBorder.all(
            color: _border, width: 0.5, style: pw.BorderStyle.solid),
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(3),
          2: pw.FlexColumnWidth(4),
          3: pw.FlexColumnWidth(3),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _surface),
            children: [
              _th('Date'), _th('Category'), _th('Note'), _th('Amount'),
            ],
          ),
          ...data.topExpenses.map((t) => pw.TableRow(children: [
            _td(_dateFmt.format(t.transaction.date)),
            _td(t.category.name),
            _td(t.transaction.note ?? '-'),
            _tdColor('- ${cur.pdfFormat(t.transaction.amount)}', _red),
          ])),
        ],
      );

  static pw.Widget _footer() => pw.Column(children: [
    pw.Divider(color: _border, thickness: 0.5),
    pw.SizedBox(height: 4),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Katonagari — Know your money',
            style: pw.TextStyle(fontSize: 8, color: _muted)),
        pw.Text('Free, private & offline',
            style: pw.TextStyle(fontSize: 8, color: _muted)),
      ],
    ),
  ]);

  // ── Table cell helpers ─────────────────────────────────────────────────────
  static pw.Widget _th(String t) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(t,
        style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold, color: _gold)),
  );

  static pw.Widget _td(String t) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 9, color: _dark)),
  );

  static pw.Widget _tdColor(String t, PdfColor color) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    child: pw.Text(t,
        style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CurrencyInfo PDF formatting extension
// ─────────────────────────────────────────────────────────────────────────────
extension _PdfCurrency on CurrencyInfo {
  /// Plain number with currency symbol — safe for PDF fonts (no emoji).
  String pdfFormat(double amount) {
    final fmt = NumberFormat('#,##0', 'en_US');
    return '$symbol ${fmt.format(amount.abs())}';
  }
}