"use strict";

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");

const tableName = process.env.TABLE_NAME || "wallet-app-main-dev";
const region = process.env.AWS_REGION || "ap-southeast-1";
const userId = process.env.CUSTOMER_USER_ID;
const phone = process.env.CUSTOMER_PHONE;

if (process.env.SEED_DEV_CUSTOMER !== "1") {
  throw new Error("Set SEED_DEV_CUSTOMER=1 to confirm this dev-only operation");
}
if (!tableName.endsWith("-dev")) {
  throw new Error(`Refusing to seed non-dev table: ${tableName}`);
}
if (!userId || !phone) throw new Error("CUSTOMER_USER_ID and CUSTOMER_PHONE are required");

const client = DynamoDBDocumentClient.from(new DynamoDBClient({ region }));
const now = new Date().toISOString();

async function run() {
  await client.send(
    new PutCommand({
      TableName: tableName,
      Item: {
        PK: `USER#${userId}`,
        SK: "PROFILE#",
        userId,
        role: "customer",
        phone,
        fullName: "Customer Dev",
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
        PK: `USER#${userId}`,
        SK: "WALLET#PRIMARY",
        balance: 1000000,
        currency: "VND",
        walletStatus: "ACTIVE",
        version: 1,
        createdAt: now,
        updatedAt: now,
      },
    }),
  );
  process.stdout.write(JSON.stringify({ userId, phone, balance: 1000000 }, null, 2));
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
