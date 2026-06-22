"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  getAuthenticatedUser,
  hasAnyRole,
  parseGroups,
} = require("../src/shared/utils/auth");

test("parseGroups supports JWT array and API Gateway string formats", () => {
  assert.deepEqual(parseGroups(["merchant"]), ["merchant"]);
  assert.deepEqual(parseGroups('["admin","customer"]'), ["admin", "customer"]);
  assert.deepEqual(parseGroups("[merchant, customer]"), ["merchant", "customer"]);
});

test("admin takes precedence over other groups", () => {
  const user = getAuthenticatedUser({
    requestContext: {
      authorizer: {
        jwt: {
          claims: {
            sub: "user-1",
            username: "0900000000",
            "cognito:groups": '["customer","admin"]',
          },
        },
      },
    },
  });

  assert.equal(user.userId, "user-1");
  assert.equal(user.username, "0900000000");
  assert.equal(user.role, "admin");
  assert.equal(hasAnyRole(user, ["admin"]), true);
  assert.equal(hasAnyRole(user, ["merchant"]), false);
});

test("authenticated users without a group default to customer", () => {
  const user = getAuthenticatedUser({
    requestContext: {
      authorizer: { jwt: { claims: { sub: "user-2" } } },
    },
  });

  assert.equal(user.role, "customer");
  assert.equal(hasAnyRole(user, ["customer"]), true);
});

test("missing JWT subject is not authorized", () => {
  const user = getAuthenticatedUser({});
  assert.equal(user.userId, null);
  assert.equal(hasAnyRole(user, ["customer"]), false);
});
