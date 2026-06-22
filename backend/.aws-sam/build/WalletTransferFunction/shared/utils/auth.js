"use strict";

function parseGroups(value) {
  if (Array.isArray(value)) return value;
  if (typeof value !== "string" || value.length === 0) return [];

  try {
    const parsed = JSON.parse(value);
    if (Array.isArray(parsed)) return parsed;
  } catch (_) {
    // API Gateway can expose Cognito groups as a comma-separated string.
  }

  return value
    .replace(/^\[|\]$/g, "")
    .split(",")
    .map((group) => group.trim().replace(/^"|"$/g, ""))
    .filter(Boolean);
}

function getAuthenticatedUser(event) {
  const claims = event?.requestContext?.authorizer?.jwt?.claims || {};
  const groups = parseGroups(claims["cognito:groups"]);

  return {
    userId: claims.sub || null,
    username: claims.username || claims["cognito:username"] || claims.sub || null,
    phone: claims.phone_number || null,
    groups,
    role: groups.includes("admin")
      ? "admin"
      : groups.includes("merchant")
        ? "merchant"
        : "customer",
  };
}

function hasAnyRole(user, allowedRoles) {
  return Boolean(user?.userId) && allowedRoles.includes(user.role);
}

module.exports = {
  getAuthenticatedUser,
  hasAnyRole,
  parseGroups,
};
