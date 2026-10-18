/** Помилка з HTTP-статусом, яку обробляє централізований error-handler. */
class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.details = details;
  }
}

module.exports = { HttpError };
