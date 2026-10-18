# Finance Tracker — backend

REST API для застосунку «Фінансовий трекер». Node.js 22+, Express 5, SQLite (better-sqlite3).

## Запуск

```bash
npm install
npm start          # http://localhost:3000/api/health
npm test           # автоматичні тести (node:test, БД у пам'яті)
```

Змінні середовища: `PORT` (за замовчуванням 3000), `DB_PATH` (за замовчуванням `data/finance_backend.db`), `CORS_ORIGINS` (джерела web-клієнтів через кому, за замовчуванням `http://localhost:5173`).

## Структура

```
src/
  server.js        точка входу
  app.js           збирання застосунку (репозиторії → сервіси → маршрути)
  config.js        конфігурація
  db/              схема SQLite та відкриття БД
  routes/          HTTP-маршрути (контролери)
  services/        бізнес-логіка та автентифікація
  repositories/    SQL-запити (параметризовані)
  models/          перетворення рядків БД у DTO
  validation/      перевірка вхідних даних
  middleware/      автентифікація, права доступу, журнал, обробка помилок
  errors/          HttpError
test/api.test.js   тести API
```

## Автентифікація

Реєстрація й логін повертають токен. Токен передається в заголовку `Authorization: Bearer <token>`.
Паролі зберігаються як хеш scrypt, токени — як SHA-256 від значення. Термін дії сесії — 7 днів.
Перший зареєстрований користувач отримує роль `ADMIN`; інші — `USER`.

## Ендпоїнти

| Метод | Шлях | Доступ | Опис |
|---|---|---|---|
| GET | `/api/health` | всі | перевірка стану |
| POST | `/api/auth/register` | всі | реєстрація (201) |
| POST | `/api/auth/login` | всі | логін, повертає токен |
| POST | `/api/auth/logout` | auth | відкликання токена (204) |
| GET | `/api/auth/me` | auth | поточний користувач |
| GET / POST | `/api/accounts` | auth | список / створення рахунку |
| GET / PATCH / DELETE | `/api/accounts/:id` | auth | перегляд / перейменування / видалення |
| GET | `/api/categories` | auth | список категорій |
| POST | `/api/categories` | ADMIN | створення категорії |
| GET / PUT / DELETE | `/api/categories/:id` | GET — auth, зміни — ADMIN | перегляд / зміна / видалення |
| GET / POST | `/api/transactions` | auth | список з фільтрами (`from`, `to`, `accountId`, `categoryId`) / створення |
| GET / PATCH / DELETE | `/api/transactions/:id` | auth | перегляд / зміна нотатки / видалення |
| GET / POST | `/api/budgets` | auth | бюджети за місяць (`month`, `year`) / створення |
| GET | `/api/budgets/status` | auth | виконання бюджетів (`spent`, `remaining`, `ratio`, `level`) |
| DELETE | `/api/budgets/:id` | auth | видалення бюджету |

Формат помилки: `{ "status": 400, "message": "...", "details": [{ "field": "...", "message": "..." }] }`.
