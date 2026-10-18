import 'package:flutter/foundation.dart';

import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/logic/analytics_calculator.dart';
import 'package:finance_tracker/logic/budget_validator.dart';
import 'package:finance_tracker/services/exchange_rate_service.dart';
import 'package:finance_tracker/services/finance_repository.dart';

/// ViewModel for accounts, categories, transactions and budgets.
/// Totals, analytics and budgets are calculated in the base currency (UAH).
class FinanceViewModel extends ChangeNotifier {
  FinanceViewModel(this._repository);

  final FinanceRepository _repository;

  List<Account> _accounts = [];
  List<FinanceCategory> _categories = [];
  List<FinanceTransaction> _transactions = [];
  List<Budget> _budgets = [];
  ExchangeRates _rates = ExchangeRates.empty;

  List<Account> get accounts => _accounts;
  List<FinanceCategory> get categories => _categories;
  List<FinanceTransaction> get transactions => _transactions;
  List<Budget> get budgets => _budgets;

  double get totalBalance => _accounts.fold<double>(
        0,
        (sum, a) => sum + _rates.toBase(a.balance, a.currency),
      );

  /// Transactions with amounts converted to the base currency.
  List<FinanceTransaction> get _baseTransactions => [
        for (final t in _transactions)
          t.copyWith(amount: _rates.toBase(t.amount, t.currency)),
      ];

  void setRates(ExchangeRates rates) {
    _rates = rates;
    notifyListeners();
  }

  AnalyticsResult analytics(Period period, DateTime anchor) =>
      AnalyticsCalculator.compute(
        transactions: _baseTransactions,
        period: period,
        anchor: anchor,
      );

  List<BudgetStatus> budgetStatusesFor(DateTime month) => BudgetValidator.evaluate(
        budgets: _budgets,
        transactions: _baseTransactions,
        month: month.month,
        year: month.year,
      );

  Future<void> load() async {
    _accounts = await _repository.getAccounts();
    _categories = await _repository.getCategories();
    _transactions = await _repository.getTransactions();
    _budgets = await _repository.getBudgets();
    notifyListeners();
  }

  /// Saves a transaction and returns a budget warning if a 80% / 100% threshold was crossed.
  Future<String?> saveTransaction(FinanceTransaction transaction) async {
    final before = budgetStatusesFor(transaction.date);
    await _repository.saveTransaction(transaction);
    await load();
    final after = budgetStatusesFor(transaction.date);
    return BudgetValidator.crossingMessage(
      before: before,
      after: after,
      categoryId: transaction.categoryId,
    );
  }

  Future<void> deleteTransaction(int id) async {
    await _repository.deleteTransaction(id);
    await load();
  }

  Future<void> addAccount(Account account) async {
    await _repository.insertAccount(account);
    await load();
  }

  Future<void> addCategory(FinanceCategory category) async {
    await _repository.insertCategory(category);
    await load();
  }

  Future<void> updateCategory(FinanceCategory category) async {
    await _repository.updateCategory(category);
    await load();
  }

  Future<void> saveBudget(Budget budget) async {
    await _repository.upsertBudget(budget);
    await load();
  }

  Future<void> deleteBudget(int id) async {
    await _repository.deleteBudget(id);
    await load();
  }
}
