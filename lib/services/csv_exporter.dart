import 'dart:io';
import 'dart:ui' show Rect;

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:finance_tracker/models/models.dart';

abstract final class CsvExporter {
  /// Writes all transactions to a CSV file and opens the system share sheet.
  static Future<void> export(
    List<FinanceTransaction> transactions, {
    Rect? sharePositionOrigin,
  }) async {
    final rows = <List<dynamic>>[
      ['Дата', 'Тип', 'Категорія', 'Рахунок', 'Сума', 'Валюта', 'Примітка'],
      for (final t in transactions)
        [
          DateFormat('yyyy-MM-dd HH:mm').format(t.date),
          t.isIncome ? 'Дохід' : 'Витрата',
          t.categoryName,
          t.accountName,
          t.amount.toStringAsFixed(2),
          t.currency,
          t.note ?? '',
        ],
    ];

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/transactions_$stamp.csv');
    // UTF-8 BOM so that Excel displays Cyrillic correctly.
    await file.writeAsString('\uFEFF${csv.encode(rows)}');

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Експорт операцій',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
