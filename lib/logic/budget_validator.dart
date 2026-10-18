import 'package:finance_tracker/models/models.dart';

enum BudgetLevel { ok, warning, exceeded }

class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.spent,
    required this.level,
  });

  final Budget budget;
  final double spent;
  final BudgetLevel level;

  double get ratio => budget.limitAmount == 0 ? 0 : spent / budget.limitAmount;

  double get remaining => budget.limitAmount - spent;
}

/// Evaluates monthly category limits and reports 80% / 100% threshold crossings.
abstract final class BudgetValidator {
  static const warningThreshold = 0.8;

  static List<BudgetStatus> evaluate({
    required List<Budget> budgets,
    required List<FinanceTransaction> transactions,
    required int month,
    required int year,
  }) {
    final result = <BudgetStatus>[];
    for (final budget in budgets) {
      if (budget.month != month || budget.year != year) continue;

      var spent = 0.0;
      for (final t in transactions) {
        if (!t.isIncome &&
            t.categoryId == budget.categoryId &&
            t.date.month == month &&
            t.date.year == year) {
          spent += t.amount;
        }
      }

      final ratio = budget.limitAmount == 0 ? 0.0 : spent / budget.limitAmount;
      final level = ratio >= 1
          ? BudgetLevel.exceeded
          : ratio >= warningThreshold
              ? BudgetLevel.warning
              : BudgetLevel.ok;
      result.add(BudgetStatus(budget: budget, spent: spent, level: level));
    }
    return result;
  }

  /// Returns a message if the category level increased compared with [before].
  static String? crossingMessage({
    required List<BudgetStatus> before,
    required List<BudgetStatus> after,
    required int categoryId,
  }) {
    final now = _find(after, categoryId);
    if (now == null) return null;
    final previousLevel = _find(before, categoryId)?.level ?? BudgetLevel.ok;
    if (now.level.index <= previousLevel.index) return null;

    final name = now.budget.categoryName;
    return now.level == BudgetLevel.exceeded
        ? 'Ліміт «$name» перевищено'
        : 'Ліміт «$name» досягнуто на ${(warningThreshold * 100).round()}%';
  }

  static BudgetStatus? _find(List<BudgetStatus> list, int categoryId) {
    for (final status in list) {
      if (status.budget.categoryId == categoryId) return status;
    }
    return null;
  }
}
