const express = require('express');
const {
  CURRENCIES,
  CATEGORY_TYPES,
  check,
  parseId,
  id,
  text,
  number,
  integer,
  oneOf,
  email,
  password,
  date,
  color,
  optional,
} = require('../validation/validators');

// Query-параметри приходять рядками, тому числові правила застосовуються після Number().
const fromQuery = (rule) => ({ parse: (value) => rule.parse(Number(value)) });

const schemas = {
  register: { email: email(), password: password() },
  login: { email: email(), password: text({ max: 128 }) },
  accountCreate: {
    name: text({ max: 100 }),
    currency: optional(oneOf(CURRENCIES), 'UAH'),
    balance: optional(number({}), 0),
  },
  accountRename: { name: text({ max: 100 }) },
  categoryWrite: {
    name: text({ max: 60 }),
    type: oneOf(CATEGORY_TYPES),
    icon: optional(text({ max: 40 }), 'other'),
    color: optional(color(), '#94A3B8'),
  },
  transactionCreate: {
    accountId: integer({ min: 1 }),
    categoryId: integer({ min: 1 }),
    amount: number({ gt: 0, max: 1e9 }),
    currency: optional(oneOf(CURRENCIES), 'UAH'),
    accountAmount: number({ gt: 0, max: 1e9 }),
    date: date(),
    note: optional(text({ max: 500 }), null),
  },
  transactionPatch: { note: text({ max: 500 }) },
  transactionQuery: {
    from: optional(date(), null),
    to: optional(date(), null),
    accountId: optional(id(), null),
    categoryId: optional(id(), null),
  },
  budgetCreate: {
    categoryId: integer({ min: 1 }),
    limitAmount: number({ gt: 0, max: 1e9 }),
    month: integer({ min: 1, max: 12 }),
    year: integer({ min: 2000, max: 2100 }),
  },
  periodQuery: {
    month: fromQuery(integer({ min: 1, max: 12 })),
    year: fromQuery(integer({ min: 2000, max: 2100 })),
  },
};

function createRouter({ financeService, authService, requireAuth, requireAdmin }) {
  const router = express.Router();

  router.get('/health', (req, res) => {
    res.json({ status: 'ok' });
  });

  // ----- Автентифікація -----
  router.post('/auth/register', (req, res) => {
    const body = check(req.body, schemas.register);
    res.status(201).json({ user: authService.register(body) });
  });

  router.post('/auth/login', (req, res) => {
    const body = check(req.body, schemas.login);
    res.json(authService.login(body));
  });

  router.post('/auth/logout', requireAuth, (req, res) => {
    authService.logout(req.token);
    res.status(204).end();
  });

  router.get('/auth/me', requireAuth, (req, res) => {
    res.json({ user: req.user });
  });

  // Усі наступні маршрути потребують автентифікації.
  router.use(['/accounts', '/categories', '/transactions', '/budgets'], requireAuth);

  // ----- Рахунки (власні дані користувача) -----
  router.get('/accounts', (req, res) => {
    res.json(financeService.listAccounts(req.user.id));
  });

  router.post('/accounts', (req, res) => {
    const body = check(req.body, schemas.accountCreate);
    res.status(201).json(financeService.createAccount(req.user.id, body));
  });

  router.get('/accounts/:id', (req, res) => {
    res.json(financeService.getAccount(req.user.id, parseId(req.params.id)));
  });

  router.patch('/accounts/:id', (req, res) => {
    const body = check(req.body, schemas.accountRename);
    res.json(financeService.renameAccount(req.user.id, parseId(req.params.id), body.name));
  });

  router.delete('/accounts/:id', (req, res) => {
    financeService.deleteAccount(req.user.id, parseId(req.params.id));
    res.status(204).end();
  });

  // ----- Категорії (читання — всім, зміни — лише ADMIN) -----
  router.get('/categories', (req, res) => {
    res.json(financeService.listCategories());
  });

  router.post('/categories', requireAdmin, (req, res) => {
    const body = check(req.body, schemas.categoryWrite);
    res.status(201).json(financeService.createCategory(body));
  });

  router.get('/categories/:id', (req, res) => {
    res.json(financeService.getCategory(parseId(req.params.id)));
  });

  router.put('/categories/:id', requireAdmin, (req, res) => {
    const body = check(req.body, schemas.categoryWrite);
    res.json(financeService.updateCategory(parseId(req.params.id), body));
  });

  router.delete('/categories/:id', requireAdmin, (req, res) => {
    financeService.deleteCategory(parseId(req.params.id));
    res.status(204).end();
  });

  // ----- Транзакції -----
  router.get('/transactions', (req, res) => {
    const filters = check(req.query, schemas.transactionQuery);
    res.json(financeService.listTransactions(req.user.id, filters));
  });

  router.post('/transactions', (req, res) => {
    const body = check(req.body, schemas.transactionCreate);
    res.status(201).json(financeService.createTransaction(req.user.id, body));
  });

  router.get('/transactions/:id', (req, res) => {
    res.json(financeService.getTransaction(req.user.id, parseId(req.params.id)));
  });

  router.patch('/transactions/:id', (req, res) => {
    const body = check(req.body, schemas.transactionPatch);
    res.json(financeService.updateTransactionNote(req.user.id, parseId(req.params.id), body.note));
  });

  router.delete('/transactions/:id', (req, res) => {
    financeService.deleteTransaction(req.user.id, parseId(req.params.id));
    res.status(204).end();
  });

  // ----- Бюджети -----
  router.get('/budgets', (req, res) => {
    const { month, year } = check(req.query, schemas.periodQuery);
    res.json(financeService.listBudgets(req.user.id, month, year));
  });

  router.get('/budgets/status', (req, res) => {
    const { month, year } = check(req.query, schemas.periodQuery);
    res.json(financeService.budgetStatus(req.user.id, month, year));
  });

  router.post('/budgets', (req, res) => {
    const body = check(req.body, schemas.budgetCreate);
    res.status(201).json(financeService.createBudget(req.user.id, body));
  });

  router.delete('/budgets/:id', (req, res) => {
    financeService.deleteBudget(req.user.id, parseId(req.params.id));
    res.status(204).end();
  });

  return router;
}

module.exports = { createRouter };
