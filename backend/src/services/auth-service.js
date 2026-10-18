const crypto = require('node:crypto');
const { HttpError } = require('../errors/http-error');
const { toUser } = require('../models/models');

const SCRYPT_KEY_LENGTH = 64;

function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(password, salt, SCRYPT_KEY_LENGTH);
  return `scrypt$${salt.toString('base64')}$${hash.toString('base64')}`;
}

function verifyPassword(password, stored) {
  const [scheme, saltB64, hashB64] = stored.split('$');
  if (scheme !== 'scrypt' || !saltB64 || !hashB64) return false;
  const expected = Buffer.from(hashB64, 'base64');
  const actual = crypto.scryptSync(password, Buffer.from(saltB64, 'base64'), expected.length);
  return crypto.timingSafeEqual(actual, expected);
}

const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');

// Фіктивний хеш для вирівнювання часу відповіді, коли користувача не існує
// (захист від перебору облікових записів за часом відповіді).
const DUMMY_HASH = hashPassword('dummy-password-0');

function createAuthService({ repos, sessionTtlDays, log }) {
  return {
    register({ email, password }) {
      if (repos.users.findByEmail.get(email)) {
        throw new HttpError(409, 'Користувач з такою поштою вже існує');
      }
      // Перший зареєстрований користувач отримує роль ADMIN (спрощене початкове налаштування).
      const role = repos.users.countAdmins.get().n === 0 ? 'ADMIN' : 'USER';
      const result = repos.users.insert.run(email, hashPassword(password), role);
      log('AUTH', `register user_id=${result.lastInsertRowid} role=${role}`);
      return toUser(repos.users.findById.get(result.lastInsertRowid));
    },

    login({ email, password }) {
      const row = repos.users.findByEmail.get(email);
      const valid = verifyPassword(password, row ? row.password_hash : DUMMY_HASH);
      if (!row || !valid) {
        log('AUTH', `login_failed email=${email}`);
        throw new HttpError(401, 'Невірна пошта або пароль');
      }

      const token = crypto.randomBytes(32).toString('base64url');
      const expiresAt = new Date(Date.now() + sessionTtlDays * 24 * 60 * 60 * 1000).toISOString();
      repos.sessions.insert.run(row.id, sha256(token), expiresAt);
      log('AUTH', `login_ok user_id=${row.id}`);
      return { token, expiresAt, user: toUser(row) };
    },

    logout(token) {
      repos.sessions.deleteByTokenHash.run(sha256(token));
    },

    authenticate(token) {
      const row = repos.sessions.findUserByTokenHash.get(sha256(token), new Date().toISOString());
      return row ? toUser(row) : null;
    },
  };
}

module.exports = { createAuthService };
