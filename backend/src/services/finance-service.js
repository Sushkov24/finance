const { HttpError } = require('../errors/http-error');
const { toAccount, toCategory, toTransaction, toBudget } = require('../models/models');

// Ті самі пороги, що й у застосунку (BudgetValidator): 80% — попередження, 100% — перевищення.
const WARNING_THRESHOLD = 0.8;

function budgetLevel(ratio) {
  if (ratio >= 1) return 'EXCEEDED';
  if (ratio >= WARNING_THRESHOLD) return 'WARNING';
  return 'OK';
}

function createFinanceService({ db, repos }) {
  const findOwnedAccount = (userId, accountId) => {
    const row = repos.accounts.findOwned.get(accountId, userId);
    if (!row) throw new HttpError(404, 'Рахунок не знайдено');
    return row;
  };

  const findCategory = (categoryId) => {
    const row = repos.categories.findById.get(categoryId);
    if (!row) throw new HttpError(404, 'Категорію не знайдено');
    return row;
  };

  // Вплив операції на баланс: дохід збільшує, витрата зменшує.
  const balanceDelta = (categoryType, accountAmount) =>
    categoryType === 'INCOME' ? accountAmount : -accountAmount;

  return {
    // ----- Рахунки -----
    listAccounts(userId) {
      return repos.accounts.listByUser.all(userId).map(toAccount);
    },

    createAccount(userId, { name, currency, balance }) {
      const result = repos.accounts.insert.run(userId, name, balance, currency);
      return toAccount(repos.accounts.findOwned.get(result.lastInsertRowid, userId));
    },

    getAccount(userId, accountId) {
      return toAccount(findOwnedAccount(userId, accountId));
    },

    renameAccount(userId, accountId, name) {
      findOwnedAccount(userId, accountId);
      repos.accounts.rename.run(name, accountId, userId);
      return toAccount(findOwnedAccount(userId, accountId));
    },

    deleteAccount(userId, accountId) {
      findOwnedAccount(userId, accountId);
      repos.accounts.delete.run(accountId, userId);
    },

    // ----- Категорії (загальні, змінює лише адміністратор) -----
    listCategories() {
      return repos.categories.list.all().map(toCategory);
    },

    getCategory(categoryId) {
      return toCategory(findCategory(categoryId));
    },

    createCategory({ name, type, icon, color }) {
      const result = repos.categories.insert.run(name, type, icon, color);
      return toCategory(repos.categories.findById.get(result.lastInsertRowid));
    },

    updateCategory(categoryId, { name, type, icon, color }) {
      findCategory(categoryId);
      repos.categories.update.run(name, type, icon, color, categoryId);
      return toCategory(repos.categories.findById.get(categoryId));
    },

    deleteCategory(categoryId) {
      findCategory(categoryId);
      repos.categories.delete.run(categoryId);
    },

    // ----- Транзакції -----
    listTransactions(userId, filters) {
      return repos.transactions
        .listByFilters({ userId, ...filters })
        .map(toTransaction);
    },

    getTransaction(userId, transactionId) {
      const row = repos.transactions.findOwned.get(transactionId, userId);
      if (!row) throw new HttpError(404, 'Транзакцію не знайдено');
      return toTransaction(row);
    },

    createTransaction(userId, input) {
      const account = findOwnedAccount(userId, input.accountId);
      const category = findCategory(input.categoryId);

      // Якщо валюта операції збігається з валютою рахунку, сума в рахунку має дорівнювати сумі операції.
      if (input.currency === account.currency && input.accountAmount !== input.amount) {
        throw new HttpError(400, 'Некоректні дані запиту', [
          { field: 'accountAmount', message: 'для тієї самої валюти має дорівнювати amount' },
        ]);
      }

      return db.transaction(() => {
        const result = repos.transactions.insert.run(
          account.id,
          category.id,
          input.amount,
          input.currency,
          input.accountAmount,
          input.date,
          input.note,
        );
        repos.accounts.adjustBalance.run(
          balanceDelta(category.type, input.accountAmount),
          account.id,
        );
        return toTransaction(repos.transactions.findOwned.get(result.lastInsertRowid, userId));
      })();
    },

    updateTransactionNote(userId, transactionId, note) {
      const row = repos.transactions.findOwned.get(transactionId, userId);
      if (!row) throw new HttpError(404, 'Транзакцію не знайдено');
      repos.transactions.updateNote.run(note, transactionId);
      return toTransaction(repos.transactions.findOwned.get(transactionId, userId));
    },

    deleteTransaction(userId, transactionId) {
      const row = repos.transactions.findOwned.get(transactionId, userId);
      if (!row) throw new HttpError(404, 'Транзакцію не знайдено');
      const category = repos.categories.findById.get(row.category_id);

      // Скасовуємо вплив транзакції на баланс рахунку.
      db.transaction(() => {
        repos.transactions.delete.run(transactionId);
        repos.accounts.adjustBalance.run(-balanceDelta(category.type, row.account_amount), row.account_id);
      })();
    },

    // ----- Бюджети -----
    listBudgets(userId, month, year) {
      return repos.budgets.listByUser.all(userId, month, year).map(toBudget);
    },

    createBudget(userId, { categoryId, limitAmount, month, year }) {
      const category = findCategory(categoryId);
      if (category.type !== 'EXPENSE') {
        throw new HttpError(400, 'Некоректні дані запиту', [
          { field: 'categoryId', message: 'бюджет можна встановити лише для категорії витрат' },
        ]);
      }
      if (repos.budgets.findDuplicate.get(userId, categoryId, month, year)) {
        throw new HttpError(409, 'Бюджет для цієї категорії та місяця вже існує');
      }
      const result = repos.budgets.insert.run(userId, categoryId, limitAmount, month, year);
      return toBudget(repos.budgets.findOwned.get(result.lastInsertRowid, userId));
    },

    deleteBudget(userId, budgetId) {
      const result = repos.budgets.delete.run(budgetId, userId);
      if (result.changes === 0) throw new HttpError(404, 'Бюджет не знайдено');
    },

    budgetStatus(userId, month, year) {
      const period = `${year}-${String(month).padStart(2, '0')}`;
      const spentRows = repos.budgets.spentByCategory.all(userId, period);
      const spentByCategory = new Map(spentRows.map((r) => [r.category_id, r.spent]));

      return repos.budgets.listByUser.all(userId, month, year).map((row) => {
        const spent = spentByCategory.get(row.category_id) ?? 0;
        const ratio = row.limit_amount === 0 ? 0 : spent / row.limit_amount;
        return {
          ...toBudget(row),
          spent,
          remaining: row.limit_amount - spent,
          ratio,
          level: budgetLevel(ratio),
        };
      });
    },
  };
}

module.exports = { createFinanceService };
