"use strict";

const {
  QueryCommand,
  PutCommand,
  UpdateCommand,
} = require("@aws-sdk/lib-dynamodb");
const {
  CognitoIdentityProviderClient,
  AdminAddUserToGroupCommand,
} = require("@aws-sdk/client-cognito-identity-provider");
const { GetObjectCommand, S3Client } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const {
  docClient,
  MAIN_TABLE_NAME,
} = require("../../shared/data/dynamo_client");
const {
  ok,
  badRequest,
  conflict,
  forbidden,
  notFound,
  serverError,
} = require("../../shared/utils/response");
const {
  parseJsonBody,
  getPathParam,
  getQueryParam,
} = require("../../shared/utils/validator");
const logger = require("../../shared/utils/logger");
const { getAuthenticatedUser, hasAnyRole } = require("../../shared/utils/auth");
const cognitoClient = new CognitoIdentityProviderClient({});
const USER_POOL_ID = process.env.USER_POOL_ID;
const s3 = new S3Client({});
const bucketName = process.env.UPLOAD_BUCKET_NAME;

async function findApplication(applicationId) {
  for (const status of ["PENDING", "APPROVED", "REJECTED"]) {
    const result = await docClient.send(
      new QueryCommand({
        TableName: MAIN_TABLE_NAME,
        IndexName: "GSI1",
        KeyConditionExpression: "GSI1PK = :gsi1pk",
        ExpressionAttributeValues: {
          ":gsi1pk": `MERCHANT_APP_STATUS#${status}`,
        },
        Limit: 50,
      }),
    );
    const application = (result.Items || []).find(
      (item) => item.applicationId === applicationId,
    );
    if (application) return application;
  }
  return null;
}

exports.handler = async (event) => {
  try {
    const method = event.requestContext?.http?.method;
    const rawPath = event.requestContext?.http?.path || "";
    const user = getAuthenticatedUser(event);

    if (!hasAnyRole(user, ["admin"])) return forbidden("Admin role required");

    if (method === "GET" && rawPath.endsWith("/admin/merchant-applications")) {
      const status = getQueryParam(event, "status") || "PENDING";
      const result = await docClient.send(
        new QueryCommand({
          TableName: MAIN_TABLE_NAME,
          IndexName: "GSI1",
          KeyConditionExpression: "GSI1PK = :gsi1pk",
          ExpressionAttributeValues: {
            ":gsi1pk": `MERCHANT_APP_STATUS#${status.toUpperCase()}`,
          },
          ScanIndexForward: false,
          Limit: 50,
        }),
      );
      return ok(result.Items || [], "Applications fetched");
    }

    const applicationId = getPathParam(event, "applicationId");
    if (!applicationId) return badRequest("Missing applicationId");

    if (method === "GET") {
      const item = await findApplication(applicationId);
      if (!item) return notFound("Application not found");
      const businessLicenseUrl = item.businessLicenseS3Key
        ? await getSignedUrl(
            s3,
            new GetObjectCommand({
              Bucket: bucketName,
              Key: item.businessLicenseS3Key,
            }),
            { expiresIn: 3600 },
          )
        : null;
      return ok({ ...item, businessLicenseUrl }, "Application detail fetched");
    }

    if (method === "POST" && rawPath.endsWith("/approve")) {
      const application = await findApplication(applicationId);
      if (!application) return notFound("Application not found");
      if (application.approvalStatus !== "PENDING") {
        return conflict(`Application is already ${application.approvalStatus}`);
      }
      const { ownerUserId, ownerUsername } = application;
      if (!ownerUserId || !ownerUsername) return conflict("Invalid application owner");

      await cognitoClient.send(
        new AdminAddUserToGroupCommand({
          UserPoolId: USER_POOL_ID,
          Username: ownerUsername,
          GroupName: "merchant",
        }),
      );

      await docClient.send(
        new UpdateCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `USER#${ownerUserId}`,
            SK: `MERCHANT_APP#${applicationId}`,
          },
          UpdateExpression:
            "SET approvalStatus = :approved, reviewedBy = :reviewedBy, reviewedAt = :reviewedAt, GSI1PK = :gsi1pk, GSI1SK = :gsi1sk",
          ExpressionAttributeValues: {
            ":approved": "APPROVED",
            ":reviewedBy": user.userId,
            ":reviewedAt": new Date().toISOString(),
            ":gsi1pk": "MERCHANT_APP_STATUS#APPROVED",
            ":gsi1sk": new Date().toISOString(),
          },
        }),
      );

      const now = new Date().toISOString();
      await docClient.send(
        new PutCommand({
          TableName: MAIN_TABLE_NAME,
          Item: {
            PK: `STORE#store_${ownerUserId}`,
            SK: "META#",
            storeId: `store_${ownerUserId}`,
            ownerUserId,
            storeName: application.businessName || application.fullName,
            GSI1PK: "STORE_DIRECTORY",
            GSI1SK: `${(application.businessName || application.fullName)
              .toLowerCase()
              .normalize("NFD")
              .replace(/[\u0300-\u036f]/g, "")}#store_${ownerUserId}`,
            address: application.address,
            phone: application.phone,
            approvalStatus: "APPROVED",
            createdAt: now,
            updatedAt: now,
          },
        }),
      );
      await docClient.send(
        new UpdateCommand({
          TableName: MAIN_TABLE_NAME,
          Key: { PK: `USER#${ownerUserId}`, SK: "PROFILE#" },
          UpdateExpression: "SET #role = :merchant, updatedAt = :updatedAt",
          ExpressionAttributeNames: { "#role": "role" },
          ExpressionAttributeValues: {
            ":merchant": "merchant",
            ":updatedAt": now,
          },
        }),
      );

      return ok(
        { applicationId, approvalStatus: "APPROVED" },
        "Application approved",
      );
    }

    if (method === "POST" && rawPath.endsWith("/reject")) {
      const body = parseJsonBody(event) || {};
      const application = await findApplication(applicationId);
      if (!application) return notFound("Application not found");
      if (application.approvalStatus !== "PENDING") {
        return conflict(`Application is already ${application.approvalStatus}`);
      }
      const { ownerUserId } = application;
      if (!ownerUserId) return conflict("Invalid application owner");

      await docClient.send(
        new UpdateCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `USER#${ownerUserId}`,
            SK: `MERCHANT_APP#${applicationId}`,
          },
          UpdateExpression:
            "SET approvalStatus = :rejected, rejectReason = :reason, reviewedBy = :reviewedBy, reviewedAt = :reviewedAt, GSI1PK = :gsi1pk, GSI1SK = :gsi1sk",
          ExpressionAttributeValues: {
            ":rejected": "REJECTED",
            ":reason": body.rejectReason || "No reason provided",
            ":reviewedBy": user.userId,
            ":reviewedAt": new Date().toISOString(),
            ":gsi1pk": "MERCHANT_APP_STATUS#REJECTED",
            ":gsi1sk": new Date().toISOString(),
          },
        }),
      );

      return ok(
        { applicationId, approvalStatus: "REJECTED" },
        "Application rejected",
      );
    }

    return badRequest("Unsupported route/method");
  } catch (err) {
    logger.error("admin_approval failed", { error: err.message });
    return serverError("Failed to process admin approval");
  }
};
