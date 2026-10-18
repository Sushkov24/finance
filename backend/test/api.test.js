const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');
const { openDatabase } = require('../src/db/database');

// Тести працюють на окремій БД у пам'яті та не чіпають файл застосунку.
let server;
let db;
let base;
const state = {};

before(async () => {
  db = openDatabase(':memory:');
  const app = createApp({
    db,
    config: { sessionTtlDays: 7, corsOrigins: ['http://localhost:5173'] },
    log: () => {},
  });
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api`;
});

test('CORS: дозволене джерело отримує заголовки, стороннє — ні', async () => {
  const allowed = await fetch(base + '/health', {
    headers: { origin: 'http://localhost:5173' },
  });
  assert.equal(allowed.headers.get('access-control-allow-origin'), 'http://localhost:5173');

  const preflight = await fetch(base + '/transactions', {
    method: 'OPTIONS',
    headers: { origin: 'http://localhost:5173', 'access-control-request-method': 'POST' },
  });
  assert.equal(preflight.status, 204);
  assert.match(preflight.headers.get('access-control-allow-methods'), /POST/);

  const foreign = await fetch(base + '/health', {
    headers: { origin: 'https://evil.example' },
  });
  assert.equal(foreign.headers.get('access-control-allow-origin'), null);
});

after(() => {
  server.close();
  db.close();
});

async function call(method, path, { body, token, raw } = {}) {
  const headers = {};
  if (body !== undefined || raw !== undefined) headers['content-type'] = 'application/json';
  if (token) headers.authorization = `Bearer ${token}`;
  const payload = raw !== undefined ? raw : body !== undefined ? JSON.stringify(body) : undefined;
  const res = await fetch(base + path, { method, headers, body: payload });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

test('перший зареєстрований користувач отримує роль ADMIN, наступні — USER', async () => {
  const admin = await call('POST', '/auth/register', {
    body: { email: 'admin@example.com', password: 'Password1' },
  });
  assert.equal(admin.status, 201);
  assert.equal(admin.body.user.role, 'ADMIN');

  const anna = await call('POST', '/auth/register', {
    body: { email: 'anna@example.com', password: 'Password2' },
  });
  assert.equal(anna.status, 201);
  assert.equal(anna.body.user.role, 'USER');
});

test('пароль зберігається у вигляді хешу scrypt, а не у відкритому вигляді', () => {
  const row = db.prepare("SELECT password_hash FROM users WHERE email = 'anna@example.com'").get();
  assert.ok(row.password_hash.startsWith('scrypt$'));
  assert.notEqual(row.password_hash, 'Password2');
});

test('некоректні дані повертають 400 з переліком полів', async () => {
  const res = await call('POST', '/auth/register', {
    body: { email: 'bad', password: 'short' },
  });
  assert.equal(res.status, 400);
  assert.deepEqual(res.body.details.map((d) => d.field).sort(), ['email', 'password']);
});

test('повторна реєстрація тієї самої пошти повертає 409', async () => {
  const res = await call('POST', '/auth/register', {
    body: { email: 'anna@example.com', password: 'Password2' },
  });
  assert.equal(res.status, 409);
});

test('логін: невірний пароль — 401, правильний — токен', async () => {
  const bad = await call('POST', '/auth/login', {
    body: { email: 'anna@example.com', password: 'WrongPass1' },
  });
  assert.equal(bad.status, 401);

  const ok = await call('POST', '/auth/login', {
    body: { email: 'anna@example.com', password: 'Password2' },
  });
  assert.equal(ok.status, 200);
  assert.ok(ok.body.token.length >= 40);
  state.annaToken = ok.body.token;

  const admin = await call('POST', '/auth/login', {
    body: { email: 'admin@example.com', password: 'Password1' },
  });
  state.adminToken = admin.body.token;
});

test('захищені маршрути без токена повертають 401', async () => {
  const res = await call('GET', '/accounts');
  assert.equal(res.status, 401);
});

test('користувач бачить лише свої рахунки', async () => {
  const created = await call('POST', '/accounts', {
    token: state.annaToken,
    body: { name: 'Картка', currency: 'UAH', balance: 1000 },
  });
  assert.equal(created.status, 201);
  state.accountId = created.body.id;

  const adminList = await call('GET', '/accounts', { token: state.adminToken });
  assert.equal(adminList.body.length, 0);

  const foreign = await call('GET', `/accounts/${state.accountId}`, { token: state.adminToken });
  assert.equal(foreign.status, 404);
});

test('витрата зменшує баланс, видалення транзакції повертає його', async () => {
  const tx = await call('POST', '/transactions', {
    token: state.annaToken,
    body: {
      accountId: state.accountId,
      categoryId: 1,
      amount: 200,
      accountAmount: 200,
      date: '2030-05-10',
      note: 'Сільпо',
    },
  });
  assert.equal(tx.status, 201);

  let account = await call('GET', `/accounts/${state.accountId}`, { token: state.annaToken });
  assert.equal(account.body.balance, 800);

  const del = await call('DELETE', `/transactions/${tx.body.id}`, { token: state.annaToken });
  assert.equal(del.status, 204);

  account = await call('GET', `/accounts/${state.accountId}`, { token: state.annaToken });
  assert.equal(account.body.balance, 1000);
});

test('дохід збільшує баланс рахунку', async () => {
  const res = await call('POST', '/transactions', {
    token: state.annaToken,
    body: {
      accountId: state.accountId,
      categoryId: 5,
      amount: 500,
      accountAmount: 500,
      date: '2030-05-01',
    },
  });
  assert.equal(res.status, 201);
  const account = await call('GET', `/accounts/${state.accountId}`, { token: state.annaToken });
  assert.equal(account.body.balance, 1500);
});

test('для тієї самої валюти сума в рахунку має дорівнювати сумі операції', async () => {
  const res = await call('POST', '/transactions', {
    token: state.annaToken,
    body: {
      accountId: state.accountId,
      categoryId: 1,
      amount: 100,
      accountAmount: 120,
      date: '2030-05-02',
    },
  });
  assert.equal(res.status, 400);
});

test('міжвалютна операція конвертується у валюту рахунку', async () => {
  const res = await call('POST', '/transactions', {
    token: state.annaToken,
    body: {
      accountId: state.accountId,
      categoryId: 2,
      amount: 10,
      currency: 'USD',
      accountAmount: 415,
      date: '2030-05-03',
    },
  });
  assert.equal(res.status, 201);
  const account = await call('GET', `/accounts/${state.accountId}`, { token: state.annaToken });
  assert.equal(account.body.balance, 1085);
});

test('змінювати категорії може лише ADMIN', async () => {
  const forbidden = await call('POST', '/categories', {
    token: state.annaToken,
    body: { name: 'Подорожі', type: 'EXPENSE' },
  });
  assert.equal(forbidden.status, 403);

  const created = await call('POST', '/categories', {
    token: state.adminToken,
    body: { name: 'Подорожі', type: 'EXPENSE' },
  });
  assert.equal(created.status, 201);

  const list = await call('GET', '/categories', { token: state.annaToken });
  assert.equal(list.status, 200);
  assert.ok(list.body.some((c) => c.name === 'Подорожі'));
});

test('категорію, що використовується транзакціями, не можна видалити (409)', async () => {
  const tx = await call('POST', '/transactions', {
    token: state.annaToken,
    body: {
      accountId: state.accountId,
      categoryId: 1,
      amount: 50,
      accountAmount: 50,
      date: '2030-05-04',
    },
  });
  const res = await call('DELETE', '/categories/1', { token: state.adminToken });
  assert.equal(res.status, 409);
  await call('DELETE', `/transactions/${tx.body.id}`, { token: state.annaToken });
});

test('бюджет: створення, перевірка дубля і статус OK/WARNING/EXCEEDED', async () => {
  const budget = await call('POST', '/budgets', {
    token: state.annaToken,
    body: { categoryId: 1, limitAmount: 1000, month: 5, year: 2030 },
  });
  assert.equal(budget.status, 201);

  const incomeBudget = await call('POST', '/budgets', {
    token: state.annaToken,
    body: { categoryId: 5, limitAmount: 1000, month: 5, year: 2030 },
  });
  assert.equal(incomeBudget.status, 400);

  const duplicate = await call('POST', '/budgets', {
    token: state.annaToken,
    body: { categoryId: 1, limitAmount: 500, month: 5, year: 2030 },
  });
  assert.equal(duplicate.status, 409);

  await call('POST', '/transactions', {
    token: state.annaToken,
    body: {
      accountId: state.accountId,
      categoryId: 1,
      amount: 850,
      accountAmount: 850,
      date: '2030-05-10',
    },
  });
  let status = await call('GET', '/budgets/status?month=5&year=2030', { token: state.annaToken });
  assert.equal(status.body[0].spent, 850);
  assert.equal(status.body[0].level, 'WARNING');

  await call('POST', '/transactions', {
    token: state.annaToken,
    body: {
      accountId: state.accountId,
      categoryId: 1,
      amount: 200,
      accountAmount: 200,
      date: '2030-05-11',
    },
  });
  status = await call('GET', '/budgets/status?month=5&year=2030', { token: state.annaToken });
  assert.equal(status.body[0].spent, 1050);
  assert.equal(status.body[0].level, 'EXCEEDED');
});

test('некоректний JSON повертає 400, невідомий маршрут — 404', async () => {
  const badJson = await call('POST', '/auth/login', { raw: '{bad json' });
  assert.equal(badJson.status, 400);

  const notFound = await call('GET', '/unknown', { token: state.annaToken });
  assert.equal(notFound.status, 404);
});

test('logout відкликає токен', async () => {
  const out = await call('POST', '/auth/logout', { token: state.annaToken });
  assert.equal(out.status, 204);
  const res = await call('GET', '/accounts', { token: state.annaToken });
  assert.equal(res.status, 401);
});
