"use strict";

const {
  GetCommand,
  QueryCommand,
  BatchGetCommand,
} = require("@aws-sdk/lib-dynamodb");
const {
  docClient,
  MAIN_TABLE_NAME,
} = require("../../shared/data/dynamo_client");
const {
  ok,
  badRequest,
  forbidden,
  serverError,
} = require("../../shared/utils/response");
const { getAuthenticatedUser, hasAnyRole } = require("../../shared/utils/auth");
const logger = require("../../shared/utils/logger");

function normalizeSearch(value) {
  return value
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function safeProfile(profile) {
  return {
    userId: profile.userId,
    fullName: profile.fullName || "Người dùng ví",
    phoneMasked: profile.phone
      ? `${profile.phone.substring(0, 4)}***${profile.phone.slice(-3)}`
      : null,
  };
}

exports.handler = async (event) => {
  try {
    if (event.requestContext?.http?.method !== "GET") {
      return badRequest("Unsupported method");
    }
    const user = getAuthenticatedUser(event);
    if (!hasAnyRole(user, ["customer", "merchant"])) {
      return forbidden("Directory access is not allowed for this role");
    }
    const rawQuery = event.queryStringParameters?.query?.trim() || "";
    const normalized = normalizeSearch(rawQuery);

    const recentResult = await docClient.send(
      new QueryCommand({
        TableName: MAIN_TABLE_NAME,
        KeyConditionExpression: "PK = :pk AND begins_with(SK, :prefix)",
        ExpressionAttributeValues: {
          ":pk": `USER#${user.userId}`,
          ":prefix": "TX#",
        },
        ScanIndexForward: false,
        Limit: 30,
      }),
    );
    const recentIds = [
      ...new Set(
        (recentResult.Items || [])
          .map((item) => item.counterpartyUserId)
          .filter((id) => id && id !== user.userId),
      ),
    ].slice(0, 10);
    let profiles = [];
    if (recentIds.length > 0) {
      const profileResult = await docClient.send(
        new BatchGetCommand({
          RequestItems: {
            [MAIN_TABLE_NAME]: {
              Keys: recentIds.map((id) => ({
                PK: `USER#${id}`,
                SK: "PROFILE#",
              })),
            },
          },
        }),
      );
      profiles = profileResult.Responses?.[MAIN_TABLE_NAME] || [];
    }

    if (rawQuery) {
      let exactProfile = null;
      const queryUserId = rawQuery.replace(/^USER#/, "");
      if (/^[0-9a-f-]{20,}$/i.test(queryUserId)) {
        exactProfile = (
          await docClient.send(
            new GetCommand({
              TableName: MAIN_TABLE_NAME,
              Key: { PK: `USER#${queryUserId}`, SK: "PROFILE#" },
            }),
          )
        ).Item;
      } else {
        let phone = rawQuery.replace(/[\s().-]/g, "");
        if (phone.startsWith("0")) phone = `+84${phone.substring(1)}`;
        if (!phone.startsWith("+")) phone = `+${phone}`;
        exactProfile = (
          await docClient.send(
            new QueryCommand({
              TableName: MAIN_TABLE_NAME,
              IndexName: "GSI1",
              KeyConditionExpression: "GSI1PK = :pk",
              ExpressionAttributeValues: { ":pk": `PHONE#${phone}` },
              Limit: 1,
            }),
          )
        ).Items?.[0];
      }
      if (
        exactProfile &&
        exactProfile.userId !== user.userId &&
        !profiles.some((profile) => profile.userId === exactProfile.userId)
      ) {
        profiles.unshift(exactProfile);
      }
      profiles = profiles.filter((profile) =>
        profile.userId === exactProfile?.userId ||
        `${profile.fullName || ""} ${profile.phone || ""} ${profile.userId}`
          .toLowerCase()
          .includes(rawQuery.toLowerCase()),
      );
    }

    const storeQuery = {
      TableName: MAIN_TABLE_NAME,
      IndexName: "GSI1",
      KeyConditionExpression: normalized
        ? "GSI1PK = :pk AND begins_with(GSI1SK, :query)"
        : "GSI1PK = :pk",
      ExpressionAttributeValues: normalized
        ? { ":pk": "STORE_DIRECTORY", ":query": normalized }
        : { ":pk": "STORE_DIRECTORY" },
      Limit: 20,
    };
    const storesResult = await docClient.send(new QueryCommand(storeQuery));

    return ok(
      {
        recipients: profiles.map(safeProfile),
        stores: (storesResult.Items || []).map((store) => ({
          storeId: store.storeId,
          storeName: store.storeName,
          address: store.address,
          phone: store.phone,
        })),
      },
      "Directory fetched",
    );
  } catch (error) {
    logger.error("directory_search failed", { error: error.message });
    return serverError("Failed to search directory");
  }
};
