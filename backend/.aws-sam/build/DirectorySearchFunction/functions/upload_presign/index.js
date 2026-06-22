"use strict";

const { randomUUID } = require("node:crypto");
const { PutObjectCommand, S3Client } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { created, badRequest, forbidden, serverError } = require("../../shared/utils/response");
const { parseJsonBody } = require("../../shared/utils/validator");
const { getAuthenticatedUser, hasAnyRole } = require("../../shared/utils/auth");
const logger = require("../../shared/utils/logger");

const s3 = new S3Client({});
const bucketName = process.env.UPLOAD_BUCKET_NAME;
const allowedPurposes = new Set(["BUSINESS_LICENSE", "PRODUCT_IMAGE", "AVATAR"]);
const allowedTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

exports.handler = async (event) => {
  try {
    const user = getAuthenticatedUser(event);
    if (!hasAnyRole(user, ["customer", "merchant"])) {
      return forbidden("Upload is not allowed for this role");
    }
    const body = parseJsonBody(event);
    if (!body || !allowedPurposes.has(body.purpose)) {
      return badRequest("Invalid upload purpose");
    }
    if (!allowedTypes.has(body.contentType)) {
      return badRequest("Only JPEG, PNG and WebP images are supported");
    }

    const extension = body.contentType === "image/png"
      ? "png"
      : body.contentType === "image/webp"
        ? "webp"
        : "jpg";
    const s3Key = `${body.purpose.toLowerCase()}/${user.userId}/${randomUUID()}.${extension}`;
    const uploadUrl = await getSignedUrl(
      s3,
      new PutObjectCommand({
        Bucket: bucketName,
        Key: s3Key,
        ContentType: body.contentType,
      }),
      { expiresIn: 300 },
    );

    return created({ uploadUrl, s3Key, expiresIn: 300 }, "Upload URL created");
  } catch (error) {
    logger.error("upload_presign failed", { error: error.message });
    return serverError("Failed to create upload URL");
  }
};
