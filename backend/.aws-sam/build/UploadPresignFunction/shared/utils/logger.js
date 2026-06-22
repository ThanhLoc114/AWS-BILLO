"use strict";

const LOG_LEVEL = process.env.LOG_LEVEL || "INFO";

function log(level, message, context = {}) {
  const levels = ["DEBUG", "INFO", "WARN", "ERROR"];
  if (levels.indexOf(level) < levels.indexOf(LOG_LEVEL)) return;

  console.log(
    JSON.stringify({
      level,
      message,
      context,
      timestamp: new Date().toISOString(),
    }),
  );
}

function debug(message, context = {}) {
  log("DEBUG", message, context);
}

function info(message, context = {}) {
  log("INFO", message, context);
}

function warn(message, context = {}) {
  log("WARN", message, context);
}

function error(message, context = {}) {
  log("ERROR", message, context);
}

module.exports = {
  debug,
  info,
  warn,
  error,
};
