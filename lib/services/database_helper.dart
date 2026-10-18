import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite database. Schema follows the lab 5 ER model (3NF).
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _fileName = 'finance.db';
  static const _version = 2;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'UAH'");
      await db.execute('ALTER TABLE transactions ADD COLUMN account_amount REAL NOT NULL DEFAULT 0');
      // Existing operations were recorded in the account currency.
      await db.execute('''
        UPDATE transactions SET
          currency = (SELECT a.currency FROM accounts a WHERE a.id = transactions.account_id),
          account_amount = amount
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    const schema = [
      '''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'UAH',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''',
      '''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE')),
        icon TEXT,
        color TEXT
      )''',
      '''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
        amount REAL NOT NULL CHECK (amount > 0),
        currency TEXT NOT NULL DEFAULT 'UAH',
        account_amount REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        note TEXT
      )''',
      'CREATE INDEX idx_transactions_date ON transactions(date)',
      '''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        limit_amount REAL NOT NULL CHECK (limit_amount > 0),
        month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
        year INTEGER NOT NULL,
        UNIQUE (category_id, month, year)
      )''',
    ];
    for (final sql in schema) {
      await db.execute(sql);
    }

    for (final name in ['Готівка', 'Картка', 'Заощадження']) {
      await db.insert('accounts', {'name': name, 'balance': 0, 'currency': 'UAH'});
    }

    const categories = [
      {'name': 'Продукти', 'type': 'EXPENSE', 'icon': 'cart', 'color': '#1E88E5'},
      {'name': 'Транспорт', 'type': 'EXPENSE', 'icon': 'bus', 'color': '#FB8C00'},
      {'name': 'Розваги', 'type': 'EXPENSE', 'icon': 'game', 'color': '#8E24AA'},
      {'name': 'Комунальні', 'type': 'EXPENSE', 'icon': 'home', 'color': '#546E7A'},
      {'name': 'Зарплата', 'type': 'INCOME', 'icon': 'work', 'color': '#43A047'},
      {'name': 'Пасивний дохід', 'type': 'INCOME', 'icon': 'trending', 'color': '#00897B'},
    ];
    for (final category in categories) {
      await db.insert('categories', category);
    }
  }
}
