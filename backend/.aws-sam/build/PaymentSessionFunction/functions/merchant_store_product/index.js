"use strict";

const {
  PutCommand,
  GetCommand,
  QueryCommand,
  UpdateCommand,
  DeleteCommand,
} = require("@aws-sdk/lib-dynamodb");
const { GetObjectCommand, S3Client } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const {
  docClient,
  MAIN_TABLE_NAME,
} = require("../../shared/data/dynamo_client");
const {
  ok,
  created,
  badRequest,
  forbidden,
  serverError,
} = require("../../shared/utils/response");
const { parseJsonBody, getPathParam } = require("../../shared/utils/validator");
const { getAuthenticatedUser, hasAnyRole } = require("../../shared/utils/auth");
const logger = require("../../shared/utils/logger");
const s3 = new S3Client({});
const bucketName = process.env.UPLOAD_BUCKET_NAME;

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

    if (method === "GET" && path.endsWith("/merchant/store")) {
      const result = await docClient.send(
        new GetCommand({
          TableName: MAIN_TABLE_NAME,
          Key: { PK: `STORE#${storeId}`, SK: "META#" },
        }),
      );
      const store = result.Item || {
          storeId,
          ownerUserId: user.userId,
          storeName: "My Store",
          address: "N/A",
        };
      if (store.imageS3Key) {
        store.imageUrl = await getSignedUrl(
          s3,
          new GetObjectCommand({
            Bucket: bucketName,
            Key: store.imageS3Key,
          }),
          { expiresIn: 3600 },
        );
      }
      return ok(store, "Store fetched");
    }

    if (method === "PATCH" && path.endsWith("/merchant/store")) {
      const body = parseJsonBody(event);
      if (!body) return badRequest("Invalid JSON body");

      const storeName = body.storeName || "My Store";
      await docClient.send(
        new UpdateCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `STORE#${storeId}`,
            SK: "META#",
          },
          UpdateExpression:
            "SET storeName = :name, #address = :address, phone = :phone, imageS3Key = :image, GSI1PK = :gsiPk, GSI1SK = :gsiSk, updatedAt = :updatedAt",
          ExpressionAttributeNames: { "#address": "address" },
          ExpressionAttributeValues: {
            ":name": storeName,
            ":address": body.address || "N/A",
            ":phone": body.phone || null,
            ":image": body.imageS3Key || null,
            ":gsiPk": "STORE_DIRECTORY",
            ":gsiSk": `${storeName
              .toLowerCase()
              .normalize("NFD")
              .replace(/[\u0300-\u036f]/g, "")}#${storeId}`,
            ":updatedAt": new Date().toISOString(),
          },
        }),
      );

      return ok({ storeId }, "Store updated");
    }

    if (method === "POST" && path.endsWith("/merchant/products")) {
      const body = parseJsonBody(event);
      if (!body) return badRequest("Invalid JSON body");
      if (!body.name || !body.price)
        return badRequest("name and price are required");

      const productId = `prod_${Date.now()}`;
      await docClient.send(
        new PutCommand({
          TableName: MAIN_TABLE_NAME,
          Item: {
            PK: `STORE#${storeId}`,
            SK: `PRODUCT#${productId}`,
            productId,
            name: body.name,
            price: Number(body.price),
            imageS3Key: body.imageS3Key || null,
            description: body.description || null,
            isActive: true,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          },
        }),
      );

      return created({ productId }, "Product created");
    }

    if (method === "GET" && path.endsWith("/merchant/products")) {
      const result = await docClient.send(
        new QueryCommand({
          TableName: MAIN_TABLE_NAME,
          KeyConditionExpression: "PK = :pk AND begins_with(SK, :prefix)",
          ExpressionAttributeValues: {
            ":pk": `STORE#${storeId}`,
            ":prefix": "PRODUCT#",
          },
        }),
      );
      const products = await Promise.all(
        (result.Items || []).map(async (product) => {
          if (!product.imageS3Key) return product;
          const imageUrl = await getSignedUrl(
            s3,
            new GetObjectCommand({
              Bucket: bucketName,
              Key: product.imageS3Key,
            }),
            { expiresIn: 3600 },
          );
          return { ...product, imageUrl };
        }),
      );
      return ok(products, "Products fetched");
    }

    const productId = getPathParam(event, "productId");
    if (productId && method === "PATCH") {
      const body = parseJsonBody(event);
      if (!body) return badRequest("Invalid JSON body");

      await docClient.send(
        new UpdateCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `STORE#${storeId}`,
            SK: `PRODUCT#${productId}`,
          },
          UpdateExpression:
            "SET #name = :name, price = :price, description = :description, imageS3Key = :imageS3Key, updatedAt = :updatedAt",
          ExpressionAttributeNames: {
            "#name": "name",
          },
          ExpressionAttributeValues: {
            ":name": body.name || "Unnamed",
            ":price": Number(body.price || 0),
            ":description": body.description || null,
            ":imageS3Key": body.imageS3Key || null,
            ":updatedAt": new Date().toISOString(),
          },
        }),
      );
      return ok({ productId }, "Product updated");
    }

    if (productId && method === "DELETE") {
      await docClient.send(
        new DeleteCommand({
          TableName: MAIN_TABLE_NAME,
          Key: {
            PK: `STORE#${storeId}`,
            SK: `PRODUCT#${productId}`,
          },
        }),
      );
      return ok({ productId }, "Product deleted");
    }

    return badRequest("Unsupported route/method");
  } catch (err) {
    logger.error("merchant_store_product failed", { error: err.message });
    return serverError("Failed to process store/product request");
  }
};
