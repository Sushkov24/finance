// Domain models that mirror the SQLite schema (lab 5, 3NF).

class Account {
  const Account({
    this.id,
    required this.name,
    this.balance = 0,
    this.currency = 'UAH',
  });

  final int? id;
  final String name;
  final double balance;
  final String currency;
}

class FinanceCategory {
  const FinanceCategory({
    this.id,
    required this.name,
    required this.type,
    this.icon = 'other',
    this.color = '#94A3B8',
  });

  final int? id;
  final String name;

  /// `INCOME` or `EXPENSE`.
  final String type;
  final String icon;
  final String color;

  bool get isIncome => type == 'INCOME';
}

class FinanceTransaction {
  const FinanceTransaction({
    this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    this.currency = 'UAH',
    required this.accountAmount,
    required this.date,
    this.note,
    this.categoryName = '',
    this.categoryType = 'EXPENSE',
    this.categoryIcon = 'other',
    this.categoryColor = '#94A3B8',
    this.accountName = '',
    this.accountCurrency = 'UAH',
  });

  final int? id;
  final int accountId;
  final int categoryId;

  /// Amount in [currency], as entered by the user.
  final double amount;
  final String currency;

  /// Same operation expressed in the account currency; applied to the account balance.
  final double accountAmount;
  final DateTime date;
  final String? note;

  /// Joined display fields, filled by the repository.
  final String categoryName;
  final String categoryType;
  final String categoryIcon;
  final String categoryColor;
  final String accountName;
  final String accountCurrency;

  bool get isIncome => categoryType == 'INCOME';

  FinanceTransaction copyWith({double? amount}) => FinanceTransaction(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount ?? this.amount,
        currency: currency,
        accountAmount: accountAmount,
        date: date,
        note: note,
        categoryName: categoryName,
        categoryType: categoryType,
        categoryIcon: categoryIcon,
        categoryColor: categoryColor,
        accountName: accountName,
        accountCurrency: accountCurrency,
      );
}

class Budget {
  const Budget({
    this.id,
    required this.categoryId,
    required this.limitAmount,
    required this.month,
    required this.year,
    this.categoryName = '',
    this.categoryIcon = 'other',
    this.categoryColor = '#94A3B8',
  });

  final int? id;
  final int categoryId;
  final double limitAmount;
  final int month;
  final int year;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
}
