const express = require('express');
const { createRepositories } = require('./repositories/repositories');
const { createAuthService } = require('./services/auth-service');
const { createFinanceService } = require('./services/finance-service');
const { createRequireAuth, requireAdmin } = require('./middleware/auth');
const { createRequestLogger, notFound, createErrorHandler } = require('./middleware/errors');
const { createCors } = require('./middleware/cors');
const { createRouter } = require('./routes');

/** Збирає застосунок з усіх шарів: репозиторії → сервіси → маршрути → обробка помилок. */
function createApp({ db, config, log }) {
  const repos = createRepositories(db);
  const authService = createAuthService({
    repos,
    sessionTtlDays: config.sessionTtlDays,
    log,
  });
  const financeService = createFinanceService({ db, repos });

  const app = express();
  app.disable('x-powered-by');
  app.use(createRequestLogger(log));
  app.use(createCors(config.corsOrigins));
  app.use(express.json({ limit: '10kb' }));
  app.use(
    '/api',
    createRouter({
      financeService,
      authService,
      requireAuth: createRequireAuth(authService),
      requireAdmin,
    }),
  );
  app.use(notFound);
  app.use(createErrorHandler(log));
  return app;
}

module.exports = { createApp };
