"use strict";

function ok(data = {}, message = "OK") {
  return {
    statusCode: 200,
    headers: defaultHeaders(),
    body: JSON.stringify({ message, data }),
  };
}

function created(data = {}, message = "Created") {
  return {
    statusCode: 201,
    headers: defaultHeaders(),
    body: JSON.stringify({ message, data }),
  };
}

function badRequest(message = "Bad Request", details = null) {
  return {
    statusCode: 400,
    headers: defaultHeaders(),
    body: JSON.stringify({ message, details }),
  };
}

function unauthorized(message = "Unauthorized") {
  return {
    statusCode: 401,
    headers: defaultHeaders(),
    body: JSON.stringify({ message }),
  };
}

function forbidden(message = "Forbidden") {
  return {
    statusCode: 403,
    headers: defaultHeaders(),
    body: JSON.stringify({ message }),
  };
}

function notFound(message = "Not Found") {
  return {
    statusCode: 404,
    headers: defaultHeaders(),
    body: JSON.stringify({ message }),
  };
}

function conflict(message = "Conflict", details = null) {
  return {
    statusCode: 409,
    headers: defaultHeaders(),
    body: JSON.stringify({ message, details }),
  };
}

function serverError(message = "Internal Server Error", details = null) {
  return {
    statusCode: 500,
    headers: defaultHeaders(),
    body: JSON.stringify({ message, details }),
  };
}

function defaultHeaders() {
  return {
    "Content-Type": "application/json",
  };
}

module.exports = {
  ok,
  created,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  serverError,
};
