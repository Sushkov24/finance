// Моделі (DTO): перетворюють рядки SQLite (snake_case) у відповіді API (camelCase).
// Внутрішні поля, як-от password_hash, сюди не потрапляють.

const toUser = (row) => ({
  id: row.id,
  email: row.email,
  role: row.role,
});

const toAccount = (row) => ({
  id: row.id,
  name: row.name,
  balance: row.balance,
  currency: row.currency,
});

const toCategory = (row) => ({
  id: row.id,
  name: row.name,
  type: row.type,
  icon: row.icon,
  color: row.color,
});

const toTransaction = (row) => ({
  id: row.id,
  accountId: row.account_id,
  categoryId: row.category_id,
  amount: row.amount,
  currency: row.currency,
  accountAmount: row.account_amount,
  date: row.date,
  note: row.note,
});

const toBudget = (row) => ({
  id: row.id,
  categoryId: row.category_id,
  limitAmount: row.limit_amount,
  month: row.month,
  year: row.year,
});

module.exports = { toUser, toAccount, toCategory, toTransaction, toBudget };
