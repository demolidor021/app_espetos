import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';

class Reports {
  static Future<File> buildMonthlyPdf(int year, int month) async {
    final db = DBHelper();
    final fmtDate = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final sales = await db.getSalesBetween(start, end);
    final summary = await db.getMonthlySummary(year, month);

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text('Relatório Mensal • ${month.toString().padLeft(2, '0')}/$year',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Resumo:'),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Vendas', 'Itens', 'Faturamento', 'Lucro', 'Ticket Médio', 'Margem %'],
            data: [
              [
                summary['salesCount'],
                summary['itemsCount'],
                currency.format(summary['totalRevenue']),
                currency.format(summary['totalProfit']),
                currency.format(summary['avgTicket']),
                (summary['marginPct'] as double).toStringAsFixed(1) + '%',
              ]
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Vendas:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Data', 'Item', 'Qtd', 'Preço', 'Custo', 'Total', 'Lucro'],
            data: sales.map((s) => [
              fmtDate.format(DateTime.fromMillisecondsSinceEpoch(s.dateMillis)),
              s.item,
              s.qty.toString(),
              currency.format(s.unitPrice),
              currency.format(s.unitCost),
              currency.format(s.total),
              currency.format(s.profit),
            ]).toList(),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/relatorio_${year}_${month.toString().padLeft(2, '0')}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> exportCsv(DateTime start, DateTime end) async {
    final db = DBHelper();
    final sales = await db.getSalesBetween(start, end);

    final buffer = StringBuffer();
    buffer.writeln('data,item,quantidade,preco_unitario,custo_unitario,total,lucro');
    for (final s in sales) {
      final dt = DateTime.fromMillisecondsSinceEpoch(s.dateMillis).toIso8601String();
      buffer.writeln('${dt},${s.item},${s.qty},${s.unitPrice},${s.unitCost},${s.total},${s.profit}');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/vendas_${start.toIso8601String().substring(0,10)}_a_${end.toIso8601String().substring(0,10)}.csv');
    await file.writeAsString(buffer.toString());
    return file;
  }

  static Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Compartilhando relatório');
  }
}
