/**
 * Дозволяє запити з вказаних джерел (web-клієнтів) до API.
 * Нативні клієнти (мобільний застосунок) CORS не потребують.
 */
function createCors(allowedOrigins = []) {
  const allowed = new Set(allowedOrigins);

  return (req, res, next) => {
    const origin = req.headers.origin;
    if (origin && allowed.has(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      res.setHeader('Access-Control-Max-Age', '600');
    }
    res.append('Vary', 'Origin');

    // Попередній запит браузера (preflight) відповідаємо без передавання маршрутам.
    if (req.method === 'OPTIONS') {
      res.status(204).end();
      return;
    }
    next();
  };
}

module.exports = { createCors };
