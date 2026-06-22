"use strict";

const { QueryCommand, GetCommand } = require("@aws-sdk/lib-dynamodb");
const {
  docClient,
  MAIN_TABLE_NAME,
} = require("../../shared/data/dynamo_client");
const {
  ok,
  badRequest,
  forbidden,
  notFound,
  serverError,
} = require("../../shared/utils/response");
const logger = require("../../shared/utils/logger");
const { getAuthenticatedUser, hasAnyRole } = require("../../shared/utils/auth");

exports.handler = async (event) => {
  try {
    const method = event.requestContext?.http?.method;
    if (method !== "GET") return badRequest("Unsupported method");

    const user = getAuthenticatedUser(event);
    if (!hasAnyRole(user, ["customer", "merchant"])) {
      return forbidden("Transaction history is not allowed for this role");
    }
    const path = event.requestContext?.http?.path || "";
    const detailMatch = path.match(/\/wallet\/transactions\/([^/]+)$/);
    if (detailMatch) {
      const txId = decodeURIComponent(detailMatch[1]);
      const transactionResult = await docClient.send(
        new GetCommand({
          TableName: MAIN_TABLE_NAME,
          Key: { PK: `TX#${txId}`, SK: "META#" },
        }),
      );
      const transaction = transactionResult.Item;
      if (!transaction) return notFound("Transaction not found");
      if (
        transaction.fromUserId !== user.userId &&
        transaction.toUserId !== user.userId
      ) {
        return forbidden("Transaction does not belong to this user");
      }

      let order = null;
      let store = null;
      if (transaction.orderId) {
        const merchantUserId =
          transaction.type === "REFUND"
            ? transaction.fromUserId
            : transaction.toUserId;
        const storeId = `store_${merchantUserId}`;
        const [orderResult, storeResult] = await Promise.all([
          docClient.send(
            new GetCommand({
              TableName: MAIN_TABLE_NAME,
              Key: {
                PK: `STORE#${storeId}`,
                SK: `ORDER#${transaction.orderId}`,
              },
            }),
          ),
          docClient.send(
            new GetCommand({
              TableName: MAIN_TABLE_NAME,
              Key: { PK: `STORE#${storeId}`, SK: "META#" },
            }),
          ),
        ]);
        order = orderResult.Item || null;
        store = storeResult.Item || null;
      }

      return ok(
        {
          transaction: {
            ...transaction,
            direction:
              transaction.toUserId === user.userId ? "IN" : "OUT",
          },
          order,
          store,
        },
        "Transaction detail fetched",
      );
    }

    const result = await docClient.send(
      new QueryCommand({
        TableName: MAIN_TABLE_NAME,
        KeyConditionExpression: "PK = :pk AND begins_with(SK, :prefix)",
        ExpressionAttributeValues: {
          ":pk": `USER#${user.userId}`,
          ":prefix": "TX#",
        },
        ScanIndexForward: false,
        Limit: 100,
      }),
    );

    return ok(result.Items || [], "Transaction history fetched");
  } catch (err) {
    logger.error("transaction_history failed", { error: err.message });
    return serverError("Failed to fetch transaction history");
  }
};
