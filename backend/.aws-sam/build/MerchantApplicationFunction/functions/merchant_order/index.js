"use strict";

const {
  PutCommand,
  GetCommand,
  UpdateCommand,
  BatchGetCommand,
  QueryCommand,
  TransactWriteCommand,
} = require("@aws-sdk/lib-dynamodb");
const {
  docClient,
  MAIN_TABLE_NAME,
} = require("../../shared/data/dynamo_client");
const {
  ok,
  created,
  badRequest,
  forbidden,
  notFound,
  conflict,
  serverError,
} = require("../../shared/utils/response");
const { parseJsonBody, getPathParam } = require("../../shared/utils/validator");
const { getAuthenticatedUser, hasAnyRole } = require("../../shared/utils/auth");
const logger = require("../../shared/utils/logger");

function merchantStoreId(userId) {
  return `store_${userId}`;
}

exports.handler = async (event) => {
  try {
    const method = event.requestContext?.http?.method;
    const path = event.requestContext?.http?.path || "";
    const user = getAuthenticatedUser(event);
    if (!hasAnyRole(user, ["merchant"])) {
      return forbidden("Approved merchant role required");
    }
    const storeId = merchantStoreId(user.userId);

    if (method === "GET" && path.endsWith("/merchant/orders")) {
      const result = await docClient.send(
        new QueryCommand({
          TableName: MAIN_TABLE_NAME,
          IndexName: "GSI1",
          KeyConditionExpression: "GSI1PK = :pk",
          ExpressionAttributeValues: {
            ":pk": `STORE_ORDER#${storeId}`,
          },
          ScanIndexForward: false,
          Limit: 100,
        }),
      );
      return ok(result.Items || [], "Orders fetched");
    }

    if (method === "POST" && path.endsWith("/merchant/orders")) {
      const body = parseJsonBody(event);
      if (!body) return badRequest("Invalid JSON body");
      if (!Array.isArray(body.items) || body.items.length === 0)
        return badRequest("items are required");

      const quantities = new Map();
      for (const item of body.items) {
        const qty = Number(item.qty);
        if (!item.productId || !Number.isInteger(qty) || qty <= 0) {
          return badRequest("Each item requires productId and positive integer qty");
        }
        quantities.set(item.productId, qty);
      }
      const productsResult = await docClient.send(
        new BatchGetCommand({
          RequestItems: {
            [MAIN_TABLE_NAME]: {
              Keys: [...quantities.keys()].map((productId) => ({
                PK: `STORE#${storeId}`,
                SK: `PRODUCT#${productId}`,
              })),
            },
          },
        }),
      );
      const products = productsResult.Responses?.[MAIN_TABLE_NAME] || [];
      if (products.length !== quantities.size || products.some((p) => !p.isActive)) {
        return badRequest("One or more products are invalid or inactive");
      }
      const orderItems = products.map((product) => ({
        productId: product.productId,
        name: product.name,
        price: Number(product.price),
        qty: quantities.get(product.productId),
      }));

      const orderId = `order_${Date.now()}`;
      const totalAmount = orderItems.reduce(
        (sum, item) => sum + Number(item.price || 0) * Number(item.qty || 1),
        0,
      );
      const now = new Date().toISOString();

      await docClient.send(
        new PutCommand({
          TableName: MAIN_TABLE_NAME,
          Item: {
            PK: `STORE#${storeId}`,
            SK: `ORDER#${orderId}`,
            orderId,
            storeId,
            items: orderItems,
            totalAmount,
            status: "WAITING_PAYMENT",
            paymentMethod: null,
            createdAt: now,
            updatedAt: now,
            GSI1PK: `STORE_ORDER#${storeId}`,
            GSI1SK: now,
          },
        }),
      );

      return created(
        { orderId, totalAmount, status: "WAITING_PAYMENT" },
        "Order created",
      );
    }

    const orderId = getPathParam(event, "orderId");
    if (!orderId) return badRequest("Missing orderId");

    if (method === "GET") {
      const result = await docClient.send(
        new GetCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `STORE#${storeId}`,
            SK: `ORDER#${orderId}`,
          },
        }),
      );
      return ok(result.Item || null, "Order fetched");
    }

    if (method === "POST" && path.endsWith("/cancel")) {
      try {
        await docClient.send(
          new UpdateCommand({
            TableName: MAIN_TABLE_NAME,
            Key: {
              PK: `STORE#${storeId}`,
              SK: `ORDER#${orderId}`,
            },
            UpdateExpression:
              "SET #status = :cancelled, cancelledAt = :now, updatedAt = :now",
            ConditionExpression: "#status = :waiting",
            ExpressionAttributeNames: { "#status": "status" },
            ExpressionAttributeValues: {
              ":cancelled": "CANCELLED",
              ":waiting": "WAITING_PAYMENT",
              ":now": new Date().toISOString(),
            },
          }),
        );
      } catch (error) {
        if (error.name === "ConditionalCheckFailedException") {
          return conflict("Only waiting orders can be cancelled");
        }
        throw error;
      }
      return ok({ orderId, status: "CANCELLED" }, "Order cancelled");
    }

    if (method === "POST" && path.endsWith("/refund")) {
      const orderResult = await docClient.send(
        new GetCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `STORE#${storeId}`,
            SK: `ORDER#${orderId}`,
          },
        }),
      );
      const order = orderResult.Item;
      if (!order) return notFound("Order not found");
      if (order.status !== "PAID") {
        return conflict("Only paid orders can be refunded");
      }
      const now = new Date().toISOString();
      const refundTxId = `refund_${Date.now()}`;

      if (order.paymentMethod === "CASH") {
        await docClient.send(
          new UpdateCommand({
            TableName: MAIN_TABLE_NAME,
            Key: {
              PK: `STORE#${storeId}`,
              SK: `ORDER#${orderId}`,
            },
            UpdateExpression:
              "SET #status = :refunded, refundedAt = :now, refundTxId = :txId, updatedAt = :now",
            ConditionExpression: "#status = :paid",
            ExpressionAttributeNames: { "#status": "status" },
            ExpressionAttributeValues: {
              ":refunded": "REFUNDED",
              ":paid": "PAID",
              ":now": now,
              ":txId": refundTxId,
            },
          }),
        );
        return ok(
          { orderId, refundTxId, status: "REFUNDED" },
          "Cash order marked as refunded",
        );
      }

      if (!order.customerUserId) {
        return conflict("This legacy order does not contain payer information");
      }
      const amount = Number(order.totalAmount || 0);
      try {
        await docClient.send(
          new TransactWriteCommand({
            TransactItems: [
              {
                Update: {
                  TableName: MAIN_TABLE_NAME,
                  Key: { PK: `USER#${user.userId}`, SK: "WALLET#PRIMARY" },
                  UpdateExpression:
                    "SET balance = balance - :amount, updatedAt = :now",
                  ConditionExpression: "balance >= :amount",
                  ExpressionAttributeValues: { ":amount": amount, ":now": now },
                },
              },
              {
                Update: {
                  TableName: MAIN_TABLE_NAME,
                  Key: {
                    PK: `USER#${order.customerUserId}`,
                    SK: "WALLET#PRIMARY",
                  },
                  UpdateExpression:
                    "SET balance = balance + :amount, updatedAt = :now",
                  ExpressionAttributeValues: { ":amount": amount, ":now": now },
                },
              },
              {
                Update: {
                  TableName: MAIN_TABLE_NAME,
                  Key: {
                    PK: `STORE#${storeId}`,
                    SK: `ORDER#${orderId}`,
                  },
                  UpdateExpression:
                    "SET #status = :refunded, refundedAt = :now, refundTxId = :txId, updatedAt = :now",
                  ConditionExpression: "#status = :paid",
                  ExpressionAttributeNames: { "#status": "status" },
                  ExpressionAttributeValues: {
                    ":refunded": "REFUNDED",
                    ":paid": "PAID",
                    ":now": now,
                    ":txId": refundTxId,
                  },
                },
              },
              {
                Put: {
                  TableName: MAIN_TABLE_NAME,
                  Item: {
                    PK: `USER#${user.userId}`,
                    SK: `TX#${now}#${refundTxId}`,
                    txId: refundTxId,
                    direction: "OUT",
                    amount,
                    counterpartyUserId: order.customerUserId,
                    orderId,
                    storeId,
                    type: "REFUND",
                    content: "Hoàn tiền đơn hàng",
                    status: "SUCCESS",
                    createdAt: now,
                  },
                },
              },
              {
                Put: {
                  TableName: MAIN_TABLE_NAME,
                  Item: {
                    PK: `USER#${order.customerUserId}`,
                    SK: `TX#${now}#${refundTxId}`,
                    txId: refundTxId,
                    direction: "IN",
                    amount,
                    counterpartyUserId: user.userId,
                    orderId,
                    storeId,
                    type: "REFUND",
                    content: "Nhận hoàn tiền đơn hàng",
                    status: "SUCCESS",
                    createdAt: now,
                  },
                },
              },
              {
                Put: {
                  TableName: MAIN_TABLE_NAME,
                  Item: {
                    PK: `TX#${refundTxId}`,
                    SK: "META#",
                    txId: refundTxId,
                    fromUserId: user.userId,
                    toUserId: order.customerUserId,
                    amount,
                    orderId,
                    type: "REFUND",
                    status: "SUCCESS",
                    createdAt: now,
                  },
                },
              },
            ],
          }),
        );
      } catch (error) {
        if (error.name === "TransactionCanceledException") {
          return conflict("Refund failed: insufficient merchant balance or order changed");
        }
        throw error;
      }
      return ok(
        { orderId, refundTxId, status: "REFUNDED" },
        "Order refunded",
      );
    }

    if (method === "POST" && path.endsWith("/checkout-cash")) {
      await docClient.send(
        new UpdateCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `STORE#${storeId}`,
            SK: `ORDER#${orderId}`,
          },
          UpdateExpression:
            "SET #status = :status, paymentMethod = :pm, updatedAt = :updatedAt",
          ConditionExpression: "#status = :waiting",
          ExpressionAttributeNames: { "#status": "status" },
          ExpressionAttributeValues: {
            ":status": "PAID",
            ":waiting": "WAITING_PAYMENT",
            ":pm": "CASH",
            ":updatedAt": new Date().toISOString(),
          },
        }),
      );
      return ok(
        { orderId, paymentMethod: "CASH", status: "PAID" },
        "Cash checkout completed",
      );
    }

    if (method === "POST" && path.endsWith("/checkout-qr")) {
      const orderResult = await docClient.send(
        new GetCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `STORE#${storeId}`,
            SK: `ORDER#${orderId}`,
          },
        }),
      );
      const order = orderResult.Item;
      if (!order) return notFound("Order not found");
      if (order.status !== "WAITING_PAYMENT") {
        return conflict(`Order is already ${order.status}`);
      }

      const sessionId = `ps_${Date.now()}`;
      const now = Date.now();
      const expiresAt = Math.floor((now + 5 * 60 * 1000) / 1000);

      await docClient.send(
        new PutCommand({
          TableName: MAIN_TABLE_NAME,
          Item: {
            PK: `PAYMENT_SESSION#${sessionId}`,
            SK: "META#",
            sessionId,
            orderId,
            storeId,
            merchantUserId: user.userId,
            amount: Number(order.totalAmount),
            status: "WAITING",
            createdAt: new Date().toISOString(),
            expiresAt,
          },
        }),
      );
      await docClient.send(
        new UpdateCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `STORE#${storeId}`,
            SK: `ORDER#${orderId}`,
          },
          UpdateExpression:
            "SET paymentSessionId = :sessionId, updatedAt = :updatedAt",
          ExpressionAttributeValues: {
            ":sessionId": sessionId,
            ":updatedAt": new Date().toISOString(),
          },
        }),
      );

      return ok(
        { sessionId, qrPayload: `walletapp://pay?sessionId=${sessionId}` },
        "QR checkout session created",
      );
    }

    return badRequest("Unsupported route/method");
  } catch (err) {
    logger.error("merchant_order failed", { error: err.message });
    return serverError("Failed to process order request");
  }
};
