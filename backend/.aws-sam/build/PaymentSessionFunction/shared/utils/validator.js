"use strict";

function parseJsonBody(event) {
  try {
    if (!event.body) return {};
    return typeof event.body === "string" ? JSON.parse(event.body) : event.body;
  } catch (_) {
    return null;
  }
}

function requireFields(payload, fields = []) {
  const missing = fields.filter((field) => {
    const value = payload[field];
    return value === undefined || value === null || value === "";
  });
  return {
    valid: missing.length === 0,
    missing,
  };
}

function getPathParam(event, key) {
  return event?.pathParameters?.[key];
}

function getQueryParam(event, key) {
  return event?.queryStringParameters?.[key];
}

function getIdempotencyKey(event) {
  return (
    event?.headers?.["Idempotency-Key"] ||
    event?.headers?.["idempotency-key"] ||
    null
  );
}

module.exports = {
  parseJsonBody,
  requireFields,
  getPathParam,
  getQueryParam,
  getIdempotencyKey,
};
