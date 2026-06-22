"use strict";

const {
  GetCommand,
  QueryCommand,
  TransactWriteCommand,
} = require("@aws-sdk/lib-dynamodb");
const {
  docClient,
  MAIN_TABLE_NAME,
} = require("../../shared/data/dynamo_client");
const {
  ok,
  badRequest,
  conflict,
  forbidden,
  serverError,
} = require("../../shared/utils/response");
const {
  parseJsonBody,
  getIdempotencyKey,
} = require("../../shared/utils/validator");
const {
  hashPayload,
  loadIdempotencyRecord,
  lockIdempotencyKey,
  completeIdempotencyKey,
  releaseIdempotencyKey,
} = require("../../shared/utils/idempotency");
const logger = require("../../shared/utils/logger");
const { getAuthenticatedUser, hasAnyRole } = require("../../shared/utils/auth");

exports.handler = async (event) => {
  try {
    const method = event.requestContext?.http?.method;
    const path = event.requestContext?.http?.path || "";
    const user = getAuthenticatedUser(event);
    if (!hasAnyRole(user, ["customer", "merchant"])) {
      return forbidden("Wallet access is not allowed for this role");
    }

    if (method === "GET" && path.endsWith("/wallet/recipients/resolve")) {
      const rawQuery = event.queryStringParameters?.query?.trim();
      if (!rawQuery) return badRequest("query is required");

      let profile = null;
      const userId = rawQuery.replace(/^USER#/, "");
      if (/^[0-9a-f-]{20,}$/i.test(userId)) {
        const result = await docClient.send(
          new GetCommand({
            TableName: MAIN_TABLE_NAME,
            Key: { PK: `USER#${userId}`, SK: "PROFILE#" },
          }),
        );
        profile = result.Item || null;
      } else {
        let phone = rawQuery.replace(/[\s().-]/g, "");
        if (phone.startsWith("0")) phone = `+84${phone.substring(1)}`;
        if (!phone.startsWith("+")) phone = `+${phone}`;
        const result = await docClient.send(
          new QueryCommand({
            TableName: MAIN_TABLE_NAME,
            IndexName: "GSI1",
            KeyConditionExpression: "GSI1PK = :pk",
            ExpressionAttributeValues: { ":pk": `PHONE#${phone}` },
            Limit: 1,
          }),
        );
        profile = result.Items?.[0] || null;
      }

      if (!profile) return badRequest("Recipient not found");
      if (profile.userId === user.userId) {
        return conflict("Cannot transfer to self");
      }
      return ok(
        {
          userId: profile.userId,
          fullName: profile.fullName || "Người dùng ví",
          phoneMasked: profile.phone
            ? `${profile.phone.substring(0, 4)}***${profile.phone.slice(-3)}`
            : null,
        },
        "Recipient resolved",
      );
    }

    if (method === "GET" && path.endsWith("/wallet/balance")) {
      const result = await docClient.send(
        new GetCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `USER#${user.userId}`,
            SK: "WALLET#PRIMARY",
          },
        }),
      );
      return ok(
        result.Item || { balance: 0, currency: "VND" },
        "Balance fetched",
      );
    }

    if (method === "POST" && path.endsWith("/wallet/transfer")) {
      const idempotencyKey = getIdempotencyKey(event);
      if (!idempotencyKey)
        return badRequest("Idempotency-Key header is required");

      const body = parseJsonBody(event);
      if (!body) return badRequest("Invalid JSON body");

      if (!body.toUserId || !body.amount || Number(body.amount) <= 0) {
        return badRequest("toUserId and amount are required");
      }

      if (body.toUserId === user.userId) {
        return conflict("Cannot transfer to self");
      }

      const amount = Number(body.amount);
      const payloadHash = hashPayload({
        fromUserId: user.userId,
        toUserId: body.toUserId,
        amount,
        content: body.content || null,
      });

      const existing = await loadIdempotencyRecord(idempotencyKey);
      if (existing) {
        if (existing.payloadHash !== payloadHash) {
          return conflict("Idempotency key conflict: payload mismatch");
        }
        if (existing.status === "COMPLETED" && existing.responsePayload) {
          return ok(
            existing.responsePayload,
            "Transfer successful (idempotent replay)",
          );
        }
        return conflict("Request with this Idempotency-Key is in progress");
      }

      await lockIdempotencyKey({
        idempotencyKey,
        payloadHash,
        ttlSeconds: 600,
      });

      const txId = `tx_${Date.now()}`;
      const timestamp = new Date().toISOString();

      try {
        await docClient.send(
          new TransactWriteCommand({
          TransactItems: [
            {
              Update: {
                TableName: MAIN_TABLE_NAME,
                Key: {
                  PK: `USER#${user.userId}`,
                  SK: "WALLET#PRIMARY",
                },
                UpdateExpression:
                  "SET balance = balance - :amount, updatedAt = :updatedAt",
                ConditionExpression: "balance >= :amount",
                ExpressionAttributeValues: {
                  ":amount": amount,
                  ":updatedAt": timestamp,
                },
              },
            },
            {
              Update: {
                TableName: MAIN_TABLE_NAME,
                Key: {
                  PK: `USER#${body.toUserId}`,
                  SK: "WALLET#PRIMARY",
                },
                UpdateExpression:
                  "SET balance = balance + :amount, updatedAt = :updatedAt",
                ExpressionAttributeValues: {
                  ":amount": amount,
                  ":updatedAt": timestamp,
                },
              },
            },
            {
              Put: {
                TableName: MAIN_TABLE_NAME,
                Item: {
                  PK: `USER#${user.userId}`,
                  SK: `TX#${timestamp}#${txId}`,
                  txId,
                  direction: "OUT",
                  amount,
                  counterpartyUserId: body.toUserId,
                  status: "SUCCESS",
                  content: body.content || null,
                  idempotencyKey,
                  createdAt: timestamp,
                },
              },
            },
            {
              Put: {
                TableName: MAIN_TABLE_NAME,
                Item: {
                  PK: `USER#${body.toUserId}`,
                  SK: `TX#${timestamp}#${txId}`,
                  txId,
                  direction: "IN",
                  amount,
                  counterpartyUserId: user.userId,
                  status: "SUCCESS",
                  content: body.content || null,
                  idempotencyKey,
                  createdAt: timestamp,
                },
              },
            },
            {
              Put: {
                TableName: MAIN_TABLE_NAME,
                Item: {
                  PK: `TX#${txId}`,
                  SK: "META#",
                  txId,
                  fromUserId: user.userId,
                  toUserId: body.toUserId,
                  amount,
                  status: "SUCCESS",
                  content: body.content || null,
                  idempotencyKey,
                  createdAt: timestamp,
                },
              },
            },
          ],
          }),
        );
      } catch (error) {
        await releaseIdempotencyKey(idempotencyKey);
        if (error.name === "TransactionCanceledException") {
          return conflict("Insufficient balance or receiver wallet not found");
        }
        throw error;
      }

      const responsePayload = { txId, status: "SUCCESS" };

      await completeIdempotencyKey({
        idempotencyKey,
        payloadHash,
        responsePayload,
        ttlSeconds: 86400,
      });

      return ok(responsePayload, "Transfer successful");
    }

    return badRequest("Unsupported route/method");
  } catch (err) {
    logger.error("wallet_transfer failed", { error: err.message });
    return serverError("Failed to process wallet transfer request");
  }
};
