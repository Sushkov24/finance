import 'package:finance_tracker/models/models.dart';

enum Period { day, week, month, year }

class PeriodRange {
  const PeriodRange(this.start, this.end);

  final DateTime start;

  /// Exclusive upper bound.
  final DateTime end;

  bool contains(DateTime value) => !value.isBefore(start) && value.isBefore(end);
}

class CategoryShare {
  const CategoryShare({
    required this.name,
    required this.color,
    required this.amount,
    required this.share,
  });

  final String name;
  final String color;
  final double amount;

  /// Fraction of total expenses, 0..1.
  final double share;
}

class TimelinePoint {
  const TimelinePoint(this.label, this.income, this.expense);

  final String label;
  final double income;
  final double expense;
}

class AnalyticsResult {
  const AnalyticsResult({
    required this.income,
    required this.expense,
    required this.categories,
    required this.timeline,
  });

  final double income;
  final double expense;
  final List<CategoryShare> categories;
  final List<TimelinePoint> timeline;
}

/// Pure calculations for analytics charts (no I/O, easy to test).
abstract final class AnalyticsCalculator {
  static const _monthsUk = [
    'Січ', 'Лют', 'Бер', 'Кві', 'Тра', 'Чер',
    'Лип', 'Сер', 'Вер', 'Жов', 'Лис', 'Гру',
  ];

  static PeriodRange rangeFor(Period period, DateTime anchor) => switch (period) {
        Period.day => PeriodRange(
            DateTime(anchor.year, anchor.month, anchor.day),
            DateTime(anchor.year, anchor.month, anchor.day + 1),
          ),
        Period.week => _weekRange(anchor),
        Period.month => PeriodRange(
            DateTime(anchor.year, anchor.month),
            DateTime(anchor.year, anchor.month + 1),
          ),
        Period.year => PeriodRange(DateTime(anchor.year), DateTime(anchor.year + 1)),
      };

  static DateTime shift(Period period, DateTime anchor, int steps) => switch (period) {
        Period.day => DateTime(anchor.year, anchor.month, anchor.day + steps),
        Period.week => DateTime(anchor.year, anchor.month, anchor.day + 7 * steps),
        Period.month => DateTime(anchor.year, anchor.month + steps),
        Period.year => DateTime(anchor.year + steps),
      };

  static List<String> labels(Period period, PeriodRange range) => switch (period) {
        Period.day => [for (var h = 0; h < 24; h++) '$h'],
        Period.week => const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
        Period.month => [for (var d = 1; d <= _daysIn(range.start); d++) '$d'],
        Period.year => _monthsUk,
      };

  static AnalyticsResult compute({
    required List<FinanceTransaction> transactions,
    required Period period,
    required DateTime anchor,
  }) {
    final range = rangeFor(period, anchor);
    final labelList = labels(period, range);
    final count = labelList.length;
    final incomeBuckets = List<double>.filled(count, 0);
    final expenseBuckets = List<double>.filled(count, 0);
    final categoryTotals = <int, double>{};
    final categoryRef = <int, FinanceTransaction>{};
    var income = 0.0;
    var expense = 0.0;

    for (final t in transactions) {
      if (!range.contains(t.date)) continue;
      final index = _bucketIndex(period, t.date);
      if (t.isIncome) {
        income += t.amount;
        incomeBuckets[index] += t.amount;
      } else {
        expense += t.amount;
        expenseBuckets[index] += t.amount;
        categoryTotals[t.categoryId] = (categoryTotals[t.categoryId] ?? 0) + t.amount;
        categoryRef.putIfAbsent(t.categoryId, () => t);
      }
    }

    final categories = [
      for (final entry in categoryTotals.entries)
        CategoryShare(
          name: categoryRef[entry.key]!.categoryName,
          color: categoryRef[entry.key]!.categoryColor,
          amount: entry.value,
          share: expense == 0 ? 0 : entry.value / expense,
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    return AnalyticsResult(
      income: income,
      expense: expense,
      categories: categories,
      timeline: [
        for (var i = 0; i < count; i++)
          TimelinePoint(labelList[i], incomeBuckets[i], expenseBuckets[i]),
      ],
    );
  }

  static PeriodRange _weekRange(DateTime anchor) {
    final start = DateTime(anchor.year, anchor.month, anchor.day - (anchor.weekday - 1));
    return PeriodRange(start, DateTime(start.year, start.month, start.day + 7));
  }

  static int _daysIn(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  static int _bucketIndex(Period period, DateTime t) => switch (period) {
        Period.day => t.hour,
        Period.week => t.weekday - 1,
        Period.month => t.day - 1,
        Period.year => t.month - 1,
      };
}
