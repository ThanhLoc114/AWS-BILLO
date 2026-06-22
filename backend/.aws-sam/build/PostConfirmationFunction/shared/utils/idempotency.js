"use strict";

const { DeleteCommand, GetCommand, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { docClient, IDEMPOTENCY_TABLE_NAME } = require("../data/dynamo_client");

function hashPayload(payload) {
  return JSON.stringify(payload || {});
}

async function loadIdempotencyRecord(idempotencyKey) {
  const result = await docClient.send(
    new GetCommand({
      TableName: IDEMPOTENCY_TABLE_NAME,
      Key: { IdempotencyKey: idempotencyKey },
    }),
  );
  return result.Item || null;
}

async function lockIdempotencyKey({
  idempotencyKey,
  payloadHash,
  ttlSeconds = 600,
}) {
  const nowEpoch = Math.floor(Date.now() / 1000);
  await docClient.send(
    new PutCommand({
      TableName: IDEMPOTENCY_TABLE_NAME,
      Item: {
        IdempotencyKey: idempotencyKey,
        status: "IN_PROGRESS",
        payloadHash,
        expiresAt: nowEpoch + ttlSeconds,
        createdAt: new Date().toISOString(),
      },
      ConditionExpression: "attribute_not_exists(IdempotencyKey)",
    }),
  );
}

async function completeIdempotencyKey({
  idempotencyKey,
  payloadHash,
  responsePayload,
  ttlSeconds = 86400,
}) {
  const nowEpoch = Math.floor(Date.now() / 1000);
  await docClient.send(
    new PutCommand({
      TableName: IDEMPOTENCY_TABLE_NAME,
      Item: {
        IdempotencyKey: idempotencyKey,
        status: "COMPLETED",
        payloadHash,
        responsePayload,
        expiresAt: nowEpoch + ttlSeconds,
        completedAt: new Date().toISOString(),
      },
    }),
  );
}

async function releaseIdempotencyKey(idempotencyKey) {
  await docClient.send(
    new DeleteCommand({
      TableName: IDEMPOTENCY_TABLE_NAME,
      Key: { IdempotencyKey: idempotencyKey },
    }),
  );
}

module.exports = {
  hashPayload,
  loadIdempotencyRecord,
  lockIdempotencyKey,
  completeIdempotencyKey,
  releaseIdempotencyKey,
};
