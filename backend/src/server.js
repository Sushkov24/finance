const config = require('./config');
const { openDatabase } = require('./db/database');
const { createApp } = require('./app');
const { log } = require('./logger');

const db = openDatabase(config.dbPath);
const app = createApp({ db, config, log });

const server = app.listen(config.port, () => {
  log('SERVER', `http://localhost:${config.port}/api/health`);
});

function shutdown() {
  server.close(() => {
    db.close();
    process.exit(0);
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
