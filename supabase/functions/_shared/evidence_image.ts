export const MAX_EVIDENCE_BYTES = 5 * 1024 * 1024;
export const MAX_EVIDENCE_PIXELS = 24_000_000;
export const MAX_EVIDENCE_DIMENSION = 8192;

export type EvidenceFormat = "jpeg" | "webp";

export interface EvidenceDimensions {
  width: number;
  height: number;
}

export interface EvidenceInspection {
  format: EvidenceFormat;
  mimeType: "image/jpeg" | "image/webp";
  width: number;
  height: number;
  byteSize: number;
  sha256: string;
}

export class PermanentEvidenceError extends Error {
  constructor(public readonly code: string, message: string) {
    super(message);
    this.name = "PermanentEvidenceError";
  }
}

function readUint24LE(bytes: Uint8Array, offset: number): number {
  return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
}

function readUint32LE(bytes: Uint8Array, offset: number): number {
  return (bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24)) >>> 0;
}

function ascii(bytes: Uint8Array, offset: number, length: number): string {
  return String.fromCharCode(...bytes.subarray(offset, offset + length));
}

export function detectEvidenceFormat(bytes: Uint8Array): EvidenceFormat {
  if (
    bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
    bytes[2] === 0xff
  ) {
    return "jpeg";
  }
  if (
    bytes.length >= 12 && ascii(bytes, 0, 4) === "RIFF" &&
    ascii(bytes, 8, 4) === "WEBP"
  ) {
    return "webp";
  }
  throw new PermanentEvidenceError(
    "unsupported_image_format",
    "The object is not a JPEG or WebP image.",
  );
}

function jpegDimensions(bytes: Uint8Array): EvidenceDimensions {
  const sofMarkers = new Set([
    0xc0,
    0xc1,
    0xc2,
    0xc3,
    0xc5,
    0xc6,
    0xc7,
    0xc9,
    0xca,
    0xcb,
    0xcd,
    0xce,
    0xcf,
  ]);
  let offset = 2;
  while (offset + 3 < bytes.length) {
    while (offset < bytes.length && bytes[offset] === 0xff) offset++;
    if (offset >= bytes.length) break;
    const marker = bytes[offset++];
    if (
      marker === 0xd8 || marker === 0xd9 || marker === 0x01 ||
      (marker >= 0xd0 && marker <= 0xd7)
    ) {
      continue;
    }
    if (offset + 1 >= bytes.length) break;
    const length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) break;
    if (sofMarkers.has(marker)) {
      if (length < 7) break;
      return {
        height: (bytes[offset + 3] << 8) | bytes[offset + 4],
        width: (bytes[offset + 5] << 8) | bytes[offset + 6],
      };
    }
    offset += length;
  }
  throw new PermanentEvidenceError(
    "image_header_invalid",
    "JPEG dimensions could not be read safely.",
  );
}

function webpDimensions(bytes: Uint8Array): EvidenceDimensions {
  let offset = 12;
  while (offset + 8 <= bytes.length) {
    const chunk = ascii(bytes, offset, 4);
    const size = readUint32LE(bytes, offset + 4);
    const data = offset + 8;
    if (data + size > bytes.length) break;
    if (chunk === "VP8X" && size >= 10) {
      return {
        width: readUint24LE(bytes, data + 4) + 1,
        height: readUint24LE(bytes, data + 7) + 1,
      };
    }
    if (chunk === "VP8L" && size >= 5 && bytes[data] === 0x2f) {
      const b1 = bytes[data + 1];
      const b2 = bytes[data + 2];
      const b3 = bytes[data + 3];
      const b4 = bytes[data + 4];
      return {
        width: 1 + b1 + ((b2 & 0x3f) << 8),
        height: 1 + ((b2 & 0xc0) >> 6) + (b3 << 2) + ((b4 & 0x0f) << 10),
      };
    }
    if (
      chunk === "VP8 " && size >= 10 && bytes[data + 3] === 0x9d &&
      bytes[data + 4] === 0x01 && bytes[data + 5] === 0x2a
    ) {
      return {
        width: (bytes[data + 6] | (bytes[data + 7] << 8)) & 0x3fff,
        height: (bytes[data + 8] | (bytes[data + 9] << 8)) & 0x3fff,
      };
    }
    offset = data + size + (size % 2);
  }
  throw new PermanentEvidenceError(
    "image_header_invalid",
    "WebP dimensions could not be read safely.",
  );
}

export function readEvidenceDimensions(
  bytes: Uint8Array,
  format: EvidenceFormat,
): EvidenceDimensions {
  return format === "jpeg" ? jpegDimensions(bytes) : webpDimensions(bytes);
}

function validateResourceLimits(
  bytes: Uint8Array,
  dimensions: EvidenceDimensions,
): void {
  if (bytes.length === 0 || bytes.length > MAX_EVIDENCE_BYTES) {
    throw new PermanentEvidenceError(
      "image_size_limit",
      "Evidence exceeds the trusted verifier byte limit.",
    );
  }
  if (
    dimensions.width <= 0 || dimensions.height <= 0 ||
    dimensions.width > MAX_EVIDENCE_DIMENSION ||
    dimensions.height > MAX_EVIDENCE_DIMENSION ||
    dimensions.width * dimensions.height > MAX_EVIDENCE_PIXELS
  ) {
    throw new PermanentEvidenceError(
      "decoded_size_limit",
      "Decoded evidence dimensions exceed safe limits.",
    );
  }
}

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    Uint8Array.from(bytes).buffer,
  );
  return Array.from(new Uint8Array(digest)).map((value) =>
    value.toString(16).padStart(2, "0")
  ).join("");
}

export async function inspectEvidenceBytes(
  bytes: Uint8Array,
  declaredFormat: string,
  declaredMimeType: string,
  decode: (bytes: Uint8Array) => EvidenceDimensions,
): Promise<EvidenceInspection> {
  const format = detectEvidenceFormat(bytes);
  const mimeType = format === "jpeg" ? "image/jpeg" : "image/webp";
  if (declaredFormat !== format || declaredMimeType !== mimeType) {
    throw new PermanentEvidenceError(
      "mime_format_mismatch",
      "Actual image format does not match the reservation.",
    );
  }
  const headerDimensions = readEvidenceDimensions(bytes, format);
  validateResourceLimits(bytes, headerDimensions);

  let decoded: EvidenceDimensions;
  try {
    decoded = decode(bytes);
  } catch (_) {
    throw new PermanentEvidenceError(
      "image_decode_failed",
      "Evidence could not be decoded as an image.",
    );
  }
  if (
    decoded.width !== headerDimensions.width ||
    decoded.height !== headerDimensions.height
  ) {
    throw new PermanentEvidenceError(
      "image_dimension_inconsistent",
      "Decoded dimensions do not match the image header.",
    );
  }
  validateResourceLimits(bytes, decoded);
  return {
    format,
    mimeType,
    width: decoded.width,
    height: decoded.height,
    byteSize: bytes.length,
    sha256: await sha256Hex(bytes),
  };
}
