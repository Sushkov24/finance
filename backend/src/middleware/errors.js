const { HttpError } = require('../errors/http-error');

/** Журнал запитів: метод, шлях, статус і тривалість. Тіло запиту та паролі не логуються. */
function createRequestLogger(log) {
  return function requestLogger(req, res, next) {
    const started = process.hrtime.bigint();
    res.on('finish', () => {
      const ms = Number(process.hrtime.bigint() - started) / 1e6;
      log('HTTP', `${req.method} ${req.originalUrl} ${res.statusCode} ${ms.toFixed(1)}ms`);
    });
    next();
  };
}

function notFound(req, res, next) {
  next(new HttpError(404, 'Маршрут не знайдено'));
}

/**
 * Централізована обробка помилок. Формат відповіді: { status, message, details? }.
 * Внутрішні деталі (стек, SQL) клієнту не віддаються.
 */
function createErrorHandler(log) {
  // eslint-disable-next-line no-unused-vars
  return function errorHandler(err, req, res, next) {
    if (err instanceof HttpError) {
      return res.status(err.status).json({
        status: err.status,
        message: err.message,
        ...(err.details ? { details: err.details } : {}),
      });
    }

    // Помилки розбору JSON із express.json().
    if (err.type === 'entity.parse.failed') {
      return res.status(400).json({ status: 400, message: 'Некоректний JSON у тілі запиту' });
    }
    if (err.type === 'entity.too.large') {
      return res.status(413).json({ status: 413, message: 'Тіло запиту занадто велике' });
    }

    // Порушення обмежень SQLite: унікальність або зовнішній ключ.
    // SQLite для RESTRICT-зовнішніх ключів повертає код SQLITE_CONSTRAINT_TRIGGER,
    // тому перевіряємо текст повідомлення.
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
      return res.status(409).json({ status: 409, message: 'Конфлікт даних: значення вже існує' });
    }
    if (typeof err.message === 'string' && err.message.includes('FOREIGN KEY constraint failed')) {
      return res.status(409).json({
        status: 409,
        message: 'Конфлікт даних: ресурс використовується іншими записами',
      });
    }

    log('ERROR', err.stack || String(err));
    return res.status(500).json({ status: 500, message: 'Внутрішня помилка сервера' });
  };
}

module.exports = { createRequestLogger, notFound, createErrorHandler };
