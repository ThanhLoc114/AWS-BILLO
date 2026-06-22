"use strict";

const {
  GetCommand,
  PutCommand,
  UpdateCommand,
} = require("@aws-sdk/lib-dynamodb");
const {
  docClient,
  MAIN_TABLE_NAME,
} = require("../../shared/data/dynamo_client");
const {
  ok,
  created,
  badRequest,
  unauthorized,
  serverError,
} = require("../../shared/utils/response");
const {
  parseJsonBody,
  requireFields,
} = require("../../shared/utils/validator");
const logger = require("../../shared/utils/logger");
const { getAuthenticatedUser } = require("../../shared/utils/auth");

exports.handler = async (event) => {
  try {
    const method = event.requestContext?.http?.method;
    const user = getAuthenticatedUser(event);
    if (!user.userId) return unauthorized();

    if (method === "GET") {
      const result = await docClient.send(
        new GetCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `USER#${user.userId}`,
            SK: "PROFILE#",
          },
        }),
      );

      return ok(
        result.Item || {
          userId: user.userId,
          role: user.role,
          phone: user.phone,
        },
        "Profile fetched",
      );
    }

    if (method === "PATCH") {
      const body = parseJsonBody(event);
      if (!body) return badRequest("Invalid JSON body");

      const updates = [];
      const names = {};
      const values = {};
      let index = 0;

      ["fullName", "phone", "cccdMasked", "address"].forEach((field) => {
        if (body[field] !== undefined) {
          index += 1;
          names[`#f${index}`] = field;
          values[`:v${index}`] = body[field];
          updates.push(`#f${index} = :v${index}`);
        }
      });

      if (body.phone) {
        values[":gsi1pk"] = `PHONE#${body.phone}`;
        values[":gsi1sk"] = `USER#${user.userId}`;
        updates.push("GSI1PK = :gsi1pk", "GSI1SK = :gsi1sk");
      }

      if (updates.length === 0) {
        return badRequest("No updatable fields provided");
      }

      names["#updatedAt"] = "updatedAt";
      values[":updatedAt"] = new Date().toISOString();
      updates.push("#updatedAt = :updatedAt");

      await docClient.send(
        new UpdateCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `USER#${user.userId}`,
            SK: "PROFILE#",
          },
          UpdateExpression: `SET ${updates.join(", ")}`,
          ExpressionAttributeNames: names,
          ExpressionAttributeValues: values,
        }),
      );

      return ok({}, "Profile updated");
    }

    if (method === "POST") {
      const body = parseJsonBody(event);
      if (!body) return badRequest("Invalid JSON body");

      const check = requireFields(body, ["fullName"]);
      if (!check.valid)
        return badRequest("Missing required fields", check.missing);

      const now = new Date().toISOString();
      await docClient.send(
        new PutCommand({
          TableName: MAIN_TABLE_NAME,
          Item: {
            PK: `USER#${user.userId}`,
            SK: "PROFILE#",
            role: user.role,
            phone: body.phone || user.phone,
            GSI1PK: body.phone || user.phone
              ? `PHONE#${body.phone || user.phone}`
              : undefined,
            GSI1SK: `USER#${user.userId}`,
            fullName: body.fullName,
            cccdMasked: body.cccdMasked || null,
            status: "ACTIVE",
            createdAt: now,
            updatedAt: now,
          },
        }),
      );

      return created({}, "Profile created");
    }

    return badRequest("Unsupported method");
  } catch (err) {
    logger.error("auth_profile handler failed", { error: err.message });
    return serverError("Failed to process auth profile request");
  }
};
