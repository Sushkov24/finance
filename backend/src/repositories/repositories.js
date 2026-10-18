// Репозиторії: єдине місце, де виконуються SQL-запити.
// Усі значення передаються параметрами (захист від SQL-ін'єкцій).

function createRepositories(db) {
  const transactionFilters = (filters) => {
    const where = ['a.user_id = ?'];
    const params = [filters.userId];
    if (filters.from) {
      where.push('t.date >= ?');
      params.push(filters.from);
    }
    if (filters.to) {
      where.push('t.date <= ?');
      params.push(filters.to);
    }
    if (filters.accountId) {
      where.push('t.account_id = ?');
      params.push(filters.accountId);
    }
    if (filters.categoryId) {
      where.push('t.category_id = ?');
      params.push(filters.categoryId);
    }
    return { sql: where.join(' AND '), params };
  };

  return {
    users: {
      findByEmail: db.prepare('SELECT * FROM users WHERE email = ?'),
      findById: db.prepare('SELECT * FROM users WHERE id = ?'),
      countAdmins: db.prepare("SELECT COUNT(*) AS n FROM users WHERE role = 'ADMIN'"),
      insert: db.prepare('INSERT INTO users (email, password_hash, role) VALUES (?, ?, ?)'),
    },

    sessions: {
      insert: db.prepare('INSERT INTO sessions (user_id, token_hash, expires_at) VALUES (?, ?, ?)'),
      findUserByTokenHash: db.prepare(`
        SELECT u.id, u.email, u.role
        FROM sessions s JOIN users u ON u.id = s.user_id
        WHERE s.token_hash = ? AND s.expires_at > ?`),
      deleteByTokenHash: db.prepare('DELETE FROM sessions WHERE token_hash = ?'),
    },

    accounts: {
      listByUser: db.prepare('SELECT * FROM accounts WHERE user_id = ? ORDER BY id'),
      findOwned: db.prepare('SELECT * FROM accounts WHERE id = ? AND user_id = ?'),
      insert: db.prepare(
        'INSERT INTO accounts (user_id, name, balance, currency) VALUES (?, ?, ?, ?)',
      ),
      rename: db.prepare('UPDATE accounts SET name = ? WHERE id = ? AND user_id = ?'),
      adjustBalance: db.prepare('UPDATE accounts SET balance = balance + ? WHERE id = ?'),
      delete: db.prepare('DELETE FROM accounts WHERE id = ? AND user_id = ?'),
    },

    categories: {
      list: db.prepare('SELECT * FROM categories ORDER BY type, name'),
      findById: db.prepare('SELECT * FROM categories WHERE id = ?'),
      insert: db.prepare('INSERT INTO categories (name, type, icon, color) VALUES (?, ?, ?, ?)'),
      update: db.prepare(
        'UPDATE categories SET name = ?, type = ?, icon = ?, color = ? WHERE id = ?',
      ),
      delete: db.prepare('DELETE FROM categories WHERE id = ?'),
    },

    transactions: {
      listByFilters(filters) {
        const { sql, params } = transactionFilters(filters);
        return db
          .prepare(
            `SELECT t.* FROM transactions t
             JOIN accounts a ON a.id = t.account_id
             WHERE ${sql}
             ORDER BY t.date DESC, t.id DESC`,
          )
          .all(...params);
      },
      findOwned: db.prepare(`
        SELECT t.* FROM transactions t
        JOIN accounts a ON a.id = t.account_id
        WHERE t.id = ? AND a.user_id = ?`),
      insert: db.prepare(`
        INSERT INTO transactions
          (account_id, category_id, amount, currency, account_amount, date, note)
        VALUES (?, ?, ?, ?, ?, ?, ?)`),
      updateNote: db.prepare('UPDATE transactions SET note = ? WHERE id = ?'),
      delete: db.prepare('DELETE FROM transactions WHERE id = ?'),
    },

    budgets: {
      listByUser: db.prepare(`
        SELECT * FROM budgets WHERE user_id = ? AND month = ? AND year = ? ORDER BY id`),
      findOwned: db.prepare('SELECT * FROM budgets WHERE id = ? AND user_id = ?'),
      findDuplicate: db.prepare(`
        SELECT id FROM budgets
        WHERE user_id = ? AND category_id = ? AND month = ? AND year = ?`),
      insert: db.prepare(`
        INSERT INTO budgets (user_id, category_id, limit_amount, month, year)
        VALUES (?, ?, ?, ?, ?)`),
      delete: db.prepare('DELETE FROM budgets WHERE id = ? AND user_id = ?'),
      // Витрати за категорією у межах місяця в валюті рахунку (account_amount).
      spentByCategory: db.prepare(`
        SELECT t.category_id, COALESCE(SUM(t.account_amount), 0) AS spent
        FROM transactions t
        JOIN accounts a ON a.id = t.account_id
        JOIN categories c ON c.id = t.category_id
        WHERE a.user_id = ? AND c.type = 'EXPENSE'
          AND substr(t.date, 1, 7) = ?
        GROUP BY t.category_id`),
    },
  };
}

module.exports = { createRepositories };
