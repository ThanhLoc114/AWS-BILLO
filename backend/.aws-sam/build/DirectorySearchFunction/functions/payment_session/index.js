"use strict";

const {
  GetCommand,
  UpdateCommand,
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
  getPathParam,
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
    const sessionId = getPathParam(event, "sessionId");
    const user = getAuthenticatedUser(event);
    if (!hasAnyRole(user, ["customer", "merchant"])) {
      return forbidden("Payment session access is not allowed for this role");
    }

    if (!sessionId) return badRequest("Missing sessionId");

    if (method === "GET") {
      const sessionResult = await docClient.send(
        new GetCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `PAYMENT_SESSION#${sessionId}`,
            SK: "META#",
          },
        }),
      );

      const session = sessionResult.Item;
      if (!session) return badRequest("Session not found");
      if (user.role === "merchant" && session.merchantUserId !== user.userId) {
        return forbidden("Payment session does not belong to this merchant");
      }

      const [orderResult, storeResult] = await Promise.all([
        docClient.send(
          new GetCommand({
            TableName: MAIN_TABLE_NAME,
            Key: {
              PK: `STORE#${session.storeId}`,
              SK: `ORDER#${session.orderId}`,
            },
          }),
        ),
        docClient.send(
          new GetCommand({
            TableName: MAIN_TABLE_NAME,
            Key: { PK: `STORE#${session.storeId}`, SK: "META#" },
          }),
        ),
      ]);
      const invoice = {
        ...session,
        items: orderResult.Item?.items || [],
        storeName: storeResult.Item?.storeName || "Cửa hàng",
        storeAddress: storeResult.Item?.address || "",
      };

      const nowEpoch = Math.floor(Date.now() / 1000);
      if (
        session.expiresAt &&
        session.expiresAt < nowEpoch &&
        session.status === "WAITING"
      ) {
        await Promise.allSettled([
          docClient.send(
            new UpdateCommand({
              TableName: MAIN_TABLE_NAME,
              Key: { PK: `PAYMENT_SESSION#${sessionId}`, SK: "META#" },
              UpdateExpression: "SET #status = :expired, expiredAt = :now",
              ConditionExpression: "#status = :waiting",
              ExpressionAttributeNames: { "#status": "status" },
              ExpressionAttributeValues: {
                ":expired": "EXPIRED",
                ":waiting": "WAITING",
                ":now": new Date().toISOString(),
              },
            }),
          ),
          docClient.send(
            new UpdateCommand({
              TableName: MAIN_TABLE_NAME,
              Key: {
                PK: `STORE#${session.storeId}`,
                SK: `ORDER#${session.orderId}`,
              },
              UpdateExpression:
                "SET #status = :expired, expiredAt = :now, updatedAt = :now",
              ConditionExpression: "#status = :waiting",
              ExpressionAttributeNames: { "#status": "status" },
              ExpressionAttributeValues: {
                ":expired": "EXPIRED",
                ":waiting": "WAITING_PAYMENT",
                ":now": new Date().toISOString(),
              },
            }),
          ),
        ]);
        return ok({ ...invoice, status: "EXPIRED" }, "Payment session fetched");
      }

      return ok(invoice, "Payment session fetched");
    }

    if (method === "POST" && path.endsWith("/confirm-transfer")) {
      if (!hasAnyRole(user, ["customer"])) {
        return forbidden("Only customers can confirm QR payments");
      }
      const idempotencyKey = getIdempotencyKey(event);
      if (!idempotencyKey)
        return badRequest("Idempotency-Key header is required");

      const sessionResult = await docClient.send(
        new GetCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `PAYMENT_SESSION#${sessionId}`,
            SK: "META#",
          },
        }),
      );

      const session = sessionResult.Item;
      if (!session) return badRequest("Session not found");

      const nowEpoch = Math.floor(Date.now() / 1000);
      if (session.expiresAt < nowEpoch) {
        return conflict("Payment session expired");
      }
      if (session.status !== "WAITING") {
        return conflict(`Payment session already ${session.status}`);
      }

      const payloadHash = hashPayload({
        sessionId,
        payerUserId: user.userId,
        merchantUserId: session.merchantUserId,
        amount: Number(session.amount || 0),
      });

      const existing = await loadIdempotencyRecord(idempotencyKey);
      if (existing) {
        if (existing.payloadHash !== payloadHash) {
          return conflict("Idempotency key conflict: payload mismatch");
        }
        if (existing.status === "COMPLETED" && existing.responsePayload) {
          return ok(
            existing.responsePayload,
            "Transfer confirmed (idempotent replay)",
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
      const senderWalletPK = `USER#${user.userId}`;
      const receiverWalletPK = `USER#${session.merchantUserId}`;

      try {
        await docClient.send(
          new TransactWriteCommand({
          TransactItems: [
            {
              Update: {
                TableName: MAIN_TABLE_NAME,
                Key: { PK: senderWalletPK, SK: "WALLET#PRIMARY" },
                UpdateExpression:
                  "SET balance = balance - :amount, updatedAt = :updatedAt",
                ConditionExpression: "balance >= :amount",
                ExpressionAttributeValues: {
                  ":amount": Number(session.amount || 0),
                  ":updatedAt": timestamp,
                },
              },
            },
            {
              Update: {
                TableName: MAIN_TABLE_NAME,
                Key: { PK: receiverWalletPK, SK: "WALLET#PRIMARY" },
                UpdateExpression:
                  "SET balance = balance + :amount, updatedAt = :updatedAt",
                ExpressionAttributeValues: {
                  ":amount": Number(session.amount || 0),
                  ":updatedAt": timestamp,
                },
              },
            },
            {
              Update: {
                TableName: MAIN_TABLE_NAME,
                Key: {
                  PK: `STORE#${session.storeId}`,
                  SK: `ORDER#${session.orderId}`,
                },
                UpdateExpression:
                  "SET #status = :paid, paymentMethod = :method, paidAt = :paidAt, updatedAt = :paidAt, customerUserId = :customer, paymentTxId = :txId",
                ConditionExpression: "#status = :waitingPayment",
                ExpressionAttributeNames: { "#status": "status" },
                ExpressionAttributeValues: {
                  ":paid": "PAID",
                  ":method": "QR",
                  ":paidAt": timestamp,
                  ":waitingPayment": "WAITING_PAYMENT",
                  ":customer": user.userId,
                  ":txId": txId,
                },
              },
            },
            {
              Put: {
                TableName: MAIN_TABLE_NAME,
                Item: {
                  PK: senderWalletPK,
                  SK: `TX#${timestamp}#${txId}`,
                  txId,
                  direction: "OUT",
                  amount: Number(session.amount || 0),
                  counterpartyUserId: session.merchantUserId,
                  orderId: session.orderId,
                  storeId: session.storeId,
                  type: "QR_PAYMENT",
                  content: "Thanh toán đơn hàng",
                  status: "SUCCESS",
                  idempotencyKey,
                  createdAt: timestamp,
                },
              },
            },
            {
              Put: {
                TableName: MAIN_TABLE_NAME,
                Item: {
                  PK: receiverWalletPK,
                  SK: `TX#${timestamp}#${txId}`,
                  txId,
                  direction: "IN",
                  amount: Number(session.amount || 0),
                  counterpartyUserId: user.userId,
                  orderId: session.orderId,
                  storeId: session.storeId,
                  type: "QR_PAYMENT",
                  content: "Nhận thanh toán đơn hàng",
                  status: "SUCCESS",
                  idempotencyKey,
                  createdAt: timestamp,
                },
              },
            },
            {
              Update: {
                TableName: MAIN_TABLE_NAME,
                Key: { PK: `PAYMENT_SESSION#${sessionId}`, SK: "META#" },
                UpdateExpression: "SET #status = :paid, paidAt = :paidAt",
                ConditionExpression: "#status = :waiting",
                ExpressionAttributeNames: { "#status": "status" },
                ExpressionAttributeValues: {
                  ":paid": "PAID",
                  ":waiting": "WAITING",
                  ":paidAt": timestamp,
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
                  toUserId: session.merchantUserId,
                  amount: Number(session.amount || 0),
                  orderId: session.orderId,
                  type: "QR_PAYMENT",
                  status: "SUCCESS",
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
          return conflict("Insufficient balance or payment state changed");
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

      return ok(responsePayload, "Transfer confirmed");
    }

    return badRequest("Unsupported route/method");
  } catch (err) {
    logger.error("payment_session failed", { error: err.message });
    return serverError("Failed to process payment session request");
  }
};
