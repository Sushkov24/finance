const path = require('node:path');

module.exports = {
  port: Number(process.env.PORT) || 3000,
  // ':memory:' використовується в тестах.
  dbPath: process.env.DB_PATH || path.join(__dirname, '..', 'data', 'finance_backend.db'),
  // Джерела web-клієнтів, яким дозволено звертатися до API (через кому).
  corsOrigins: (process.env.CORS_ORIGINS || 'http://localhost:5173').split(',').map((s) => s.trim()),
  sessionTtlDays: 7,
};
