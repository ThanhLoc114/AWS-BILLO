"use strict";

const { PutCommand, QueryCommand } = require("@aws-sdk/lib-dynamodb");
const {
  docClient,
  MAIN_TABLE_NAME,
} = require("../../shared/data/dynamo_client");
const {
  ok,
  created,
  badRequest,
  forbidden,
  conflict,
  serverError,
} = require("../../shared/utils/response");
const {
  parseJsonBody,
  requireFields,
} = require("../../shared/utils/validator");
const logger = require("../../shared/utils/logger");
const { getAuthenticatedUser, hasAnyRole } = require("../../shared/utils/auth");

exports.handler = async (event) => {
  try {
    const method = event.requestContext?.http?.method;
    const user = getAuthenticatedUser(event);
    if (!hasAnyRole(user, ["customer", "merchant"])) {
      return forbidden("Customer or merchant role required");
    }

    if (method === "POST") {
      if (user.role === "merchant") {
        return conflict("User is already an approved merchant");
      }
      const existingResult = await docClient.send(
        new QueryCommand({
          TableName: MAIN_TABLE_NAME,
          KeyConditionExpression: "PK = :pk AND begins_with(SK, :prefix)",
          ExpressionAttributeValues: {
            ":pk": `USER#${user.userId}`,
            ":prefix": "MERCHANT_APP#",
          },
          ScanIndexForward: false,
          Limit: 1,
        }),
      );
      const existing = existingResult.Items?.[0];
      if (existing && ["PENDING", "APPROVED"].includes(existing.approvalStatus)) {
        return conflict(`Merchant application is already ${existing.approvalStatus}`);
      }
      const body = parseJsonBody(event);
      if (!body) return badRequest("Invalid JSON body");

      const check = requireFields(body, [
        "fullName",
        "businessName",
        "phone",
        "cccd",
        "address",
        "businessLicenseS3Key",
      ]);
      if (!check.valid)
        return badRequest("Missing required fields", check.missing);

      const applicationId = `app_${Date.now()}`;
      const now = new Date().toISOString();

      await docClient.send(
        new PutCommand({
          TableName: MAIN_TABLE_NAME,
          Item: {
            PK: `USER#${user.userId}`,
            SK: `MERCHANT_APP#${applicationId}`,
            applicationId,
            ownerUserId: user.userId,
            ownerUsername: user.username,
            fullName: body.fullName,
            businessName: body.businessName,
            phone: body.phone,
            cccdMasked: body.cccd.slice(-4).padStart(body.cccd.length, "*"),
            address: body.address,
            businessLicenseS3Key: body.businessLicenseS3Key,
            approvalStatus: "PENDING",
            createdAt: now,
            updatedAt: now,
            GSI1PK: "MERCHANT_APP_STATUS#PENDING",
            GSI1SK: now,
          },
        }),
      );

      return created(
        { applicationId, approvalStatus: "PENDING" },
        "Merchant application submitted",
      );
    }

    if (method === "GET") {
      const result = await docClient.send(
        new QueryCommand({
          TableName: MAIN_TABLE_NAME,
          KeyConditionExpression: "PK = :pk AND begins_with(SK, :skPrefix)",
          ExpressionAttributeValues: {
            ":pk": `USER#${user.userId}`,
            ":skPrefix": "MERCHANT_APP#",
          },
          ScanIndexForward: false,
          Limit: 1,
        }),
      );

      const latest = result.Items?.[0];
      if (!latest)
        return ok({ approvalStatus: "NOT_SUBMITTED" }, "No application found");

      return ok(latest, "Merchant application fetched");
    }

    return badRequest("Unsupported method");
  } catch (err) {
    logger.error("merchant_application failed", { error: err.message });
    return serverError("Failed to process merchant application");
  }
};
