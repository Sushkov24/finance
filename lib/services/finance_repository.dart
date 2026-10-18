import 'package:sqflite/sqflite.dart';

import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/services/database_helper.dart';

abstract interface class FinanceRepository {
  Future<List<Account>> getAccounts();
  Future<int> insertAccount(Account account);
  Future<List<FinanceCategory>> getCategories();
  Future<int> insertCategory(FinanceCategory category);
  Future<void> updateCategory(FinanceCategory category);
  Future<List<FinanceTransaction>> getTransactions();
  Future<void> saveTransaction(FinanceTransaction transaction);
  Future<void> deleteTransaction(int id);
  Future<List<Budget>> getBudgets();
  Future<void> upsertBudget(Budget budget);
  Future<void> deleteBudget(int id);
}

/// SQLite implementation. Every balance-changing operation runs in one transaction.
class SqliteFinanceRepository implements FinanceRepository {
  SqliteFinanceRepository(this._helper);

  final DatabaseHelper _helper;

  static const _transactionSelect = '''
    SELECT t.id, t.account_id, t.category_id, t.amount, t.currency, t.account_amount, t.date, t.note,
           c.name AS category_name, c.type AS category_type,
           c.icon AS category_icon, c.color AS category_color,
           a.name AS account_name, a.currency AS account_currency
    FROM transactions t
    JOIN categories c ON c.id = t.category_id
    JOIN accounts a ON a.id = t.account_id
  ''';

  @override
  Future<List<Account>> getAccounts() async {
    final db = await _helper.database;
    final rows = await db.query('accounts', orderBy: 'id');
    return rows
        .map((r) => Account(
              id: r['id'] as int,
              name: r['name'] as String,
              balance: (r['balance'] as num).toDouble(),
              currency: r['currency'] as String,
            ))
        .toList();
  }

  @override
  Future<int> insertAccount(Account account) async {
    final db = await _helper.database;
    return db.insert('accounts', {
      'name': account.name,
      'balance': account.balance,
      'currency': account.currency,
    });
  }

  @override
  Future<List<FinanceCategory>> getCategories() async {
    final db = await _helper.database;
    final rows = await db.query('categories', orderBy: 'type, name');
    return rows
        .map((r) => FinanceCategory(
              id: r['id'] as int,
              name: r['name'] as String,
              type: r['type'] as String,
              icon: (r['icon'] as String?) ?? 'other',
              color: (r['color'] as String?) ?? '#94A3B8',
            ))
        .toList();
  }

  @override
  Future<int> insertCategory(FinanceCategory category) async {
    final db = await _helper.database;
    return db.insert('categories', {
      'name': category.name,
      'type': category.type,
      'icon': category.icon,
      'color': category.color,
    });
  }

  /// Type is not updatable: existing balances depend on it.
  @override
  Future<void> updateCategory(FinanceCategory category) async {
    final db = await _helper.database;
    await db.update(
      'categories',
      {
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<List<FinanceTransaction>> getTransactions() async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      '$_transactionSelect ORDER BY t.date DESC, t.id DESC',
    );
    return rows.map(_transactionFromRow).toList();
  }

  @override
  Future<void> saveTransaction(FinanceTransaction transaction) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      final values = {
        'account_id': transaction.accountId,
        'category_id': transaction.categoryId,
        'amount': transaction.amount,
        'currency': transaction.currency,
        'account_amount': transaction.accountAmount,
        'date': transaction.date.toIso8601String(),
        'note': transaction.note,
      };

      final id = transaction.id;
      if (id != null) {
        await _revertBalance(txn, id);
        await txn.update('transactions', values, where: 'id = ?', whereArgs: [id]);
      } else {
        await txn.insert('transactions', values);
      }

      final type = await _categoryType(txn, transaction.categoryId);
      await _adjustBalance(
        txn,
        transaction.accountId,
        _signed(type, transaction.accountAmount),
      );
    });
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      await _revertBalance(txn, id);
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<List<Budget>> getBudgets() async {
    final db = await _helper.database;
    final rows = await db.rawQuery('''
      SELECT b.id, b.category_id, b.limit_amount, b.month, b.year,
             c.name AS category_name, c.icon AS category_icon, c.color AS category_color
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      ORDER BY b.year DESC, b.month DESC, c.name
    ''');
    return rows
        .map((r) => Budget(
              id: r['id'] as int,
              categoryId: r['category_id'] as int,
              limitAmount: (r['limit_amount'] as num).toDouble(),
              month: r['month'] as int,
              year: r['year'] as int,
              categoryName: r['category_name'] as String,
              categoryIcon: (r['category_icon'] as String?) ?? 'other',
              categoryColor: (r['category_color'] as String?) ?? '#94A3B8',
            ))
        .toList();
  }

  @override
  Future<void> upsertBudget(Budget budget) async {
    final db = await _helper.database;
    await db.insert(
      'budgets',
      {
        'category_id': budget.categoryId,
        'limit_amount': budget.limitAmount,
        'month': budget.month,
        'year': budget.year,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteBudget(int id) async {
    final db = await _helper.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> _categoryType(Transaction txn, int categoryId) async {
    final rows = await txn.query(
      'categories',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [categoryId],
    );
    return rows.first['type'] as String;
  }

  /// Reverses the balance effect of an existing transaction before it is changed or removed.
  Future<void> _revertBalance(Transaction txn, int id) async {
    final rows = await txn.rawQuery('''
      SELECT t.account_id, t.account_amount, c.type AS category_type
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.id = ?
    ''', [id]);
    if (rows.isEmpty) return;

    final row = rows.first;
    final amount = (row['account_amount'] as num).toDouble();
    await _adjustBalance(
      txn,
      row['account_id'] as int,
      -_signed(row['category_type'] as String, amount),
    );
  }

  Future<void> _adjustBalance(Transaction txn, int accountId, double delta) {
    return txn.rawUpdate(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [delta, accountId],
    );
  }

  /// Income increases the balance, expense decreases it.
  static double _signed(String type, double amount) =>
      type == 'INCOME' ? amount : -amount;

  FinanceTransaction _transactionFromRow(Map<String, Object?> r) {
    return FinanceTransaction(
      id: r['id'] as int,
      accountId: r['account_id'] as int,
      categoryId: r['category_id'] as int,
      amount: (r['amount'] as num).toDouble(),
      currency: r['currency'] as String,
      accountAmount: (r['account_amount'] as num).toDouble(),
      date: DateTime.parse(r['date'] as String),
      note: r['note'] as String?,
      categoryName: r['category_name'] as String,
      categoryType: r['category_type'] as String,
      categoryIcon: (r['category_icon'] as String?) ?? 'other',
      categoryColor: (r['category_color'] as String?) ?? '#94A3B8',
      accountName: r['account_name'] as String,
      accountCurrency: r['account_currency'] as String,
    );
  }
}
