const { HttpError } = require('../errors/http-error');

const CURRENCIES = ['UAH', 'USD', 'EUR'];
const CATEGORY_TYPES = ['INCOME', 'EXPENSE'];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const COLOR_RE = /^#[0-9A-Fa-f]{6}$/;

// Правило — це об'єкт { parse(value), optional?, default? }.
// parse повертає нормалізоване значення або кидає Error з повідомленням для клієнта.
function text({ min = 1, max = 100 } = {}) {
  return {
    parse(value) {
      if (typeof value !== 'string') throw new Error('має бути рядком');
      const trimmed = value.trim();
      if (trimmed.length < min || trimmed.length > max) {
        throw new Error(`довжина має бути від ${min} до ${max} символів`);
      }
      return trimmed;
    },
  };
}

function number({ gt, min, max } = {}) {
  return {
    parse(value) {
      if (typeof value !== 'number' || !Number.isFinite(value)) {
        throw new Error('має бути числом');
      }
      if (gt !== undefined && value <= gt) throw new Error(`має бути більше ${gt}`);
      if (min !== undefined && value < min) throw new Error(`має бути не менше ${min}`);
      if (max !== undefined && value > max) throw new Error(`має бути не більше ${max}`);
      if (Math.abs(value * 100 - Math.round(value * 100)) > 1e-6) {
        throw new Error('не більше 2 знаків після коми');
      }
      return value;
    },
  };
}

function integer({ min, max } = {}) {
  const base = number({ min, max });
  return {
    parse(value) {
      if (!Number.isInteger(value)) throw new Error('має бути цілим числом');
      return base.parse(value);
    },
  };
}

function id() {
  return {
    parse(value) {
      const n = Number(value);
      if (!Number.isInteger(n) || n <= 0) throw new Error('некоректний ідентифікатор');
      return n;
    },
  };
}

function oneOf(values) {
  return {
    parse(value) {
      if (!values.includes(value)) throw new Error(`має бути одним із: ${values.join(', ')}`);
      return value;
    },
  };
}

function email() {
  return {
    parse(value) {
      if (typeof value !== 'string' || !EMAIL_RE.test(value.trim()) || value.length > 254) {
        throw new Error('некоректний формат електронної пошти');
      }
      return value.trim().toLowerCase();
    },
  };
}

function password() {
  return {
    parse(value) {
      if (typeof value !== 'string' || value.length < 8 || value.length > 128) {
        throw new Error('пароль має містити від 8 до 128 символів');
      }
      if (!/[A-Za-zА-Яа-яІіЇїЄєҐґ]/.test(value) || !/\d/.test(value)) {
        throw new Error('пароль має містити хоча б одну літеру і одну цифру');
      }
      return value;
    },
  };
}

function date() {
  return {
    parse(value) {
      if (typeof value !== 'string' || !DATE_RE.test(value)) {
        throw new Error('дата має формат YYYY-MM-DD');
      }
      const parsed = new Date(`${value}T00:00:00Z`);
      if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
        throw new Error('неіснуюча дата');
      }
      return value;
    },
  };
}

function color() {
  return {
    parse(value) {
      if (typeof value !== 'string' || !COLOR_RE.test(value)) {
        throw new Error('колір має формат #RRGGBB');
      }
      return value.toUpperCase();
    },
  };
}

const optional = (rule, defaultValue = null) => ({ ...rule, optional: true, default: defaultValue });

/**
 * Перевіряє тіло запиту за схемою. Збирає помилки по всіх полях
 * і повертає 400 з масивом details: [{ field, message }].
 */
function check(input, schema) {
  const body = input && typeof input === 'object' && !Array.isArray(input) ? input : {};
  const data = {};
  const details = [];

  for (const [name, rule] of Object.entries(schema)) {
    const raw = body[name];
    if (raw === undefined || raw === null || raw === '') {
      if (rule.optional) {
        data[name] = rule.default;
      } else {
        details.push({ field: name, message: 'поле є обов’язковим' });
      }
      continue;
    }
    try {
      data[name] = rule.parse(raw);
    } catch (err) {
      details.push({ field: name, message: err.message });
    }
  }

  if (details.length > 0) {
    throw new HttpError(400, 'Некоректні дані запиту', details);
  }
  return data;
}

/** Перевіряє ідентифікатор із шляху (/api/accounts/:id). */
function parseId(raw) {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'Некоректний ідентифікатор');
  }
  return id;
}

module.exports = {
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
};
