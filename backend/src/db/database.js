const fs = require('node:fs');
const path = require('node:path');
const Database = require('better-sqlite3');

// Схема відповідає ER-моделі застосунку (accounts, categories, transactions, budgets)
// та доповнена таблицями користувачів і сесій для автентифікації.
const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'USER' CHECK (role IN ('USER', 'ADMIN')),
  created_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sessions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS accounts (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  balance    REAL NOT NULL DEFAULT 0,
  currency   TEXT NOT NULL DEFAULT 'UAH' CHECK (currency IN ('UAH', 'USD', 'EUR')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS categories (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  TEXT NOT NULL,
  type  TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE')),
  icon  TEXT NOT NULL DEFAULT 'other',
  color TEXT NOT NULL DEFAULT '#94A3B8',
  UNIQUE (name, type)
);

CREATE TABLE IF NOT EXISTS transactions (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id     INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  category_id    INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  amount         REAL NOT NULL CHECK (amount > 0),
  currency       TEXT NOT NULL DEFAULT 'UAH' CHECK (currency IN ('UAH', 'USD', 'EUR')),
  account_amount REAL NOT NULL CHECK (account_amount > 0),
  date           TEXT NOT NULL,
  note           TEXT
);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date);

CREATE TABLE IF NOT EXISTS budgets (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id  INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  limit_amount REAL NOT NULL CHECK (limit_amount > 0),
  month        INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
  year         INTEGER NOT NULL,
  UNIQUE (user_id, category_id, month, year)
);
`;

const DEFAULT_CATEGORIES = [
  ['Продукти', 'EXPENSE', 'cart', '#1E88E5'],
  ['Транспорт', 'EXPENSE', 'bus', '#FB8C00'],
  ['Розваги', 'EXPENSE', 'game', '#8E24AA'],
  ['Комунальні', 'EXPENSE', 'home', '#546E7A'],
  ['Зарплата', 'INCOME', 'work', '#43A047'],
  ['Пасивний дохід', 'INCOME', 'trending', '#00897B'],
];

function openDatabase(file) {
  if (file !== ':memory:') {
    fs.mkdirSync(path.dirname(file), { recursive: true });
  }
  const db = new Database(file);
  db.pragma('foreign_keys = ON');
  db.exec(SCHEMA);

  const insertCategory = db.prepare(
    'INSERT OR IGNORE INTO categories (name, type, icon, color) VALUES (?, ?, ?, ?)',
  );
  for (const row of DEFAULT_CATEGORIES) {
    insertCategory.run(...row);
  }
  return db;
}

module.exports = { openDatabase };
