"use strict";

const { PutCommand } = require("@aws-sdk/lib-dynamodb");
const {
  docClient,
  MAIN_TABLE_NAME,
} = require("../../shared/data/dynamo_client");
const logger = require("../../shared/utils/logger");

exports.handler = async (event) => {
  const attributes = event?.request?.userAttributes || {};
  const userId = attributes.sub;
  if (!userId) throw new Error("Missing Cognito user sub");

  const now = new Date().toISOString();
  const putIfMissing = async (item) => {
    try {
      await docClient.send(
        new PutCommand({
          TableName: MAIN_TABLE_NAME,
          Item: item,
          ConditionExpression: "attribute_not_exists(PK)",
        }),
      );
    } catch (error) {
      if (error.name !== "ConditionalCheckFailedException") throw error;
      logger.info("Wallet item already initialized", { userId, sk: item.SK });
    }
  };

  await putIfMissing({
    PK: `USER#${userId}`,
    SK: "PROFILE#",
    userId,
    role: "customer",
    phone: attributes.phone_number || null,
    GSI1PK: attributes.phone_number
      ? `PHONE#${attributes.phone_number}`
      : undefined,
    GSI1SK: `USER#${userId}`,
    fullName: "Khách hàng",
    status: "ACTIVE",
    createdAt: now,
    updatedAt: now,
  });
  await putIfMissing({
    PK: `USER#${userId}`,
    SK: "WALLET#PRIMARY",
    balance: 0,
    currency: "VND",
    walletStatus: "ACTIVE",
    version: 1,
    createdAt: now,
    updatedAt: now,
  });

  return event;
};
