const { HttpError } = require('../errors/http-error');

/** Перевіряє токен Bearer і кладе користувача в req.user. */
function createRequireAuth(authService) {
  return function requireAuth(req, res, next) {
    const header = req.get('authorization') || '';
    const match = /^Bearer\s+(\S+)$/.exec(header);
    const user = match ? authService.authenticate(match[1]) : null;
    if (!user) {
      return next(new HttpError(401, 'Необхідна автентифікація'));
    }
    req.user = user;
    req.token = match[1];
    return next();
  };
}

/** Доступ лише для ролі ADMIN. Має виконуватися після requireAuth. */
function requireAdmin(req, res, next) {
  if (req.user?.role !== 'ADMIN') {
    return next(new HttpError(403, 'Доступ заборонено'));
  }
  return next();
}

module.exports = { createRequireAuth, requireAdmin };
