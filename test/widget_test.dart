import 'package:flutter_test/flutter_test.dart';

import 'package:finance_tracker/logic/analytics_calculator.dart';
import 'package:finance_tracker/logic/budget_validator.dart';
import 'package:finance_tracker/logic/transaction_filter.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/services/security_service.dart';

FinanceTransaction _tx({
  required double amount,
  required DateTime date,
  int categoryId = 1,
  String type = 'EXPENSE',
  String categoryName = 'Продукти',
  String accountName = 'Картка',
  String? note,
}) =>
    FinanceTransaction(
      accountId: 1,
      categoryId: categoryId,
      amount: amount,
      accountAmount: amount,
      date: date,
      note: note,
      categoryName: categoryName,
      categoryType: type,
      accountName: accountName,
    );

void main() {
  group('AnalyticsCalculator', () {
    test('month range includes the last moment of the month only', () {
      final range = AnalyticsCalculator.rangeFor(Period.month, DateTime(2025, 2, 15));

      expect(range.contains(DateTime(2025, 2, 1)), isTrue);
      expect(range.contains(DateTime(2025, 2, 28, 23, 59)), isTrue);
      expect(range.contains(DateTime(2025, 3, 1)), isFalse);
    });

    test('week range starts on Monday', () {
      // 2025-03-05 is a Wednesday, so the week starts on 2025-03-03.
      final range = AnalyticsCalculator.rangeFor(Period.week, DateTime(2025, 3, 5));

      expect(range.start, DateTime(2025, 3, 3));
      expect(range.end, DateTime(2025, 3, 10));
    });
  });

  group('BudgetValidator', () {
    final budget = Budget(
      id: 1,
      categoryId: 1,
      limitAmount: 1000,
      month: 3,
      year: 2025,
      categoryName: 'Продукти',
    );

    List<BudgetStatus> statusFor(double spent) => BudgetValidator.evaluate(
          budgets: [budget],
          transactions: [_tx(amount: spent, date: DateTime(2025, 3, 2))],
          month: 3,
          year: 2025,
        );

    test('level is ok below 80%', () {
      expect(statusFor(500).single.level, BudgetLevel.ok);
    });

    test('level is warning from 80% up to 100%', () {
      expect(statusFor(800).single.level, BudgetLevel.warning);
    });

    test('level is exceeded at 100% and above', () {
      expect(statusFor(1200).single.level, BudgetLevel.exceeded);
    });

    test('crossingMessage reports a newly reached threshold', () {
      final message = BudgetValidator.crossingMessage(
        before: statusFor(500),
        after: statusFor(850),
        categoryId: 1,
      );

      expect(message, 'Ліміт «Продукти» досягнуто на 80%');
    });

    test('crossingMessage is null when the level did not change', () {
      final message = BudgetValidator.crossingMessage(
        before: statusFor(850),
        after: statusFor(900),
        categoryId: 1,
      );

      expect(message, isNull);
    });
  });

  group('TransactionFilter', () {
    final items = [
      _tx(amount: 100, date: DateTime(2025, 3, 1), note: 'Сільпо'),
      _tx(
        amount: 5000,
        date: DateTime(2025, 3, 10),
        type: 'INCOME',
        categoryId: 2,
        categoryName: 'Зарплата',
      ),
    ];

    test('query is case-insensitive and matches notes', () {
      final result = const TransactionFilter(query: 'СІЛЬПО').apply(items);

      expect(result, hasLength(1));
      expect(result.single.amount, 100);
    });

    test('type filter keeps only matching transactions', () {
      final result = const TransactionFilter(type: 'INCOME').apply(items);

      expect(result, hasLength(1));
      expect(result.single.isIncome, isTrue);
    });

    test('upper date bound is inclusive for the whole day', () {
      final result = TransactionFilter(to: DateTime(2025, 3, 10)).apply(items);

      expect(result, hasLength(2));
    });

    test('amount range keeps values inside bounds', () {
      final result = const TransactionFilter(minAmount: 200, maxAmount: 6000).apply(items);

      expect(result, hasLength(1));
      expect(result.single.isIncome, isTrue);
    });
  });

  group('SecurityService.hashPin', () {
    test('is deterministic for the same pin and salt', () {
      expect(
        SecurityService.hashPin('1234', 'salt'),
        SecurityService.hashPin('1234', 'salt'),
      );
    });

    test('changes when the salt changes', () {
      expect(
        SecurityService.hashPin('1234', 'salt-a'),
        isNot(SecurityService.hashPin('1234', 'salt-b')),
      );
    });

    test('differs for different pins', () {
      expect(
        SecurityService.hashPin('1234', 'salt'),
        isNot(SecurityService.hashPin('4321', 'salt')),
      );
    });
  });
}

