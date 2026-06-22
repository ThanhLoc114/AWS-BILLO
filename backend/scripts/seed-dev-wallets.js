"use strict";

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
  UpdateCommand,
} = require("@aws-sdk/lib-dynamodb");

const tableName = process.env.TABLE_NAME || "wallet-app-main-dev";
const region = process.env.AWS_REGION || "ap-southeast-1";
const currentUserId = process.env.CURRENT_USER_ID;
const receiverUserId = process.env.RECEIVER_USER_ID || "dev-receiver-001";

if (process.env.SEED_DEV_WALLETS !== "1") {
  throw new Error("Set SEED_DEV_WALLETS=1 to confirm this dev-only operation");
}
if (!tableName.endsWith("-dev")) {
  throw new Error(`Refusing to seed non-dev table: ${tableName}`);
}
if (!currentUserId) {
  throw new Error("CURRENT_USER_ID is required");
}

const client = DynamoDBDocumentClient.from(new DynamoDBClient({ region }), {
  marshallOptions: { removeUndefinedValues: true },
});
const now = new Date().toISOString();

async function run() {
  await client.send(
    new UpdateCommand({
      TableName: tableName,
      Key: { PK: `USER#${currentUserId}`, SK: "WALLET#PRIMARY" },
      UpdateExpression:
        "SET balance = :balance, currency = :currency, walletStatus = :status, updatedAt = :updatedAt",
      ConditionExpression: "attribute_exists(PK)",
      ExpressionAttributeValues: {
        ":balance": 1000000,
        ":currency": "VND",
        ":status": "ACTIVE",
        ":updatedAt": now,
      },
    }),
  );

  await client.send(
    new PutCommand({
      TableName: tableName,
      Item: {
        PK: `USER#${receiverUserId}`,
        SK: "PROFILE#",
        userId: receiverUserId,
        role: "customer",
        fullName: "Ví nhận thử nghiệm",
        status: "ACTIVE",
        createdAt: now,
        updatedAt: now,
      },
    }),
  );
  await client.send(
    new PutCommand({
      TableName: tableName,
      Item: {
        PK: `USER#${receiverUserId}`,
        SK: "WALLET#PRIMARY",
        balance: 100000,
        currency: "VND",
        walletStatus: "ACTIVE",
        version: 1,
        createdAt: now,
        updatedAt: now,
      },
    }),
  );

  process.stdout.write(
    JSON.stringify(
      {
        tableName,
        sender: { userId: currentUserId, balance: 1000000 },
        receiver: { userId: receiverUserId, balance: 100000 },
      },
      null,
      2,
    ),
  );
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
