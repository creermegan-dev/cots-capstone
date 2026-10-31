import { createClient } from "npm:@supabase/supabase-js@2";
import {
  ImageMagick,
  initializeImageMagick,
  MagickFormat,
} from "npm:@imagemagick/magick-wasm@^0";

const apiUrl = Deno.env.get("SUPABASE_URL")!;
const secretKey = Deno.env.get("SUPABASE_SECRET_KEY")!;
const verifierUrl = Deno.env.get("VERIFIER_URL")!;
if (!apiUrl || !secretKey || !verifierUrl) {
  throw new Error("Local integration environment is incomplete.");
}

await initializeImageMagick(
  await Deno.readFile("/app/supabase/functions/verify-evidence/magick.wasm"),
);
const admin = createClient(apiUrl, secretKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function check(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

async function hash(bytes: Uint8Array): Promise<string> {
  const value = await crypto.subtle.digest(
    "SHA-256",
    Uint8Array.from(bytes).buffer,
  );
  return Array.from(new Uint8Array(value)).map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

function imageFixtures(): { jpeg: Uint8Array; webp: Uint8Array } {
  const header = new TextEncoder().encode("P6\n2 1\n255\n");
  const ppm = new Uint8Array(header.length + 6);
  ppm.set(header);
  ppm.set([255, 0, 0, 0, 255, 0], header.length);
  return ImageMagick.read(ppm, (image) => ({
    jpeg: image.write(MagickFormat.Jpeg, (data) => Uint8Array.from(data)),
    webp: image.write(MagickFormat.WebP, (data) => Uint8Array.from(data)),
  }));
}

async function insert(
  table: string,
  values: Record<string, unknown> | Record<string, unknown>[],
): Promise<void> {
  const { error } = await admin.from(table).insert(values);
  if (error) {
    throw new Error(`${table} insert failed: ${error.code} ${error.message}`);
  }
}

async function invoke(
  body: Record<string, unknown>,
  authorized = true,
): Promise<{ status: number; body: any }> {
  const response = await fetch(verifierUrl, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(authorized ? { apikey: secretKey } : {}),
    },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
}

const runId = crypto.randomUUID().slice(0, 8);
const password = `Local-only-${crypto.randomUUID()}!`;
const createUser = async (role: string) => {
  const { data, error } = await admin.auth.admin.createUser({
    email: `${role}-${runId}@example.invalid`,
    password,
    email_confirm: true,
    user_metadata: { full_name: `${role} fixture` },
  });
  if (error || !data.user) {
    throw new Error(`Could not create ${role} fixture: ${error?.message}`);
  }
  return data.user.id;
};

const administratorId = await createUser("administrator");
const expertId = await createUser("expert");
const ownerId = await createUser("diver");
await insert("privileged_role_slots", [
  { role: "administrator", user_id: administratorId },
  { role: "expert", user_id: expertId },
]);
let response: any = await admin.from("setup_state").update({
  completed_at: new Date().toISOString(),
}).eq("singleton", true);
if (response.error) throw response.error;
response = await admin.from("profiles").update({
  field_verified: true,
  verified_by: administratorId,
  verified_at: new Date().toISOString(),
}).eq("id", ownerId);
if (response.error) throw response.error;

const areaId = crypto.randomUUID();
await insert("monitoring_areas", {
  id: areaId,
  code: `EDGE-${runId}`,
  name: "Edge verifier integration area",
  geography_version: "local-test",
});
const fixtures = imageFixtures();

async function createCapture(
  withReviewItem = false,
): Promise<{ captureId: string; itemId?: string }> {
  const captureId = crypto.randomUUID();
  await insert("captures", {
    id: captureId,
    owner_id: ownerId,
    idempotency_key: crypto.randomUUID(),
    area_id: areaId,
    captured_at: new Date().toISOString(),
    capture_time_source: "device",
    model_name: "edge-integration",
    model_sha256: "a".repeat(64),
    source_width: 2,
    source_height: 1,
    gps_source: "unavailable",
  });
  if (!withReviewItem) return { captureId };
  const itemId = crypto.randomUUID();
  await insert("detection_items", {
    id: itemId,
    capture_id: captureId,
    item_index: 0,
    confidence: 0.6,
    x1: 0,
    y1: 0,
    x2: 1,
    y2: 1,
  });
  return { captureId, itemId };
}

async function reserveAndLink(options: {
  bytes: Uint8Array;
  format: "jpeg" | "webp";
  mimeType: "image/jpeg" | "image/webp";
  targetKind: "capture" | "elimination";
  targetId: string;
  upload?: boolean;
  reservedHash?: string;
  reservedWidth?: number;
  reservedBytes?: number;
}): Promise<string> {
  const assetId = crypto.randomUUID();
  const variantId = crypto.randomUUID();
  const bucket = options.targetKind === "elimination"
    ? "elimination-evidence"
    : "detection-evidence";
  const path = `${ownerId}/${assetId}/${variantId}`;
  const actualHash = await hash(options.bytes);
  await insert("media_assets", {
    id: assetId,
    owner_id: ownerId,
    idempotency_key: crypto.randomUUID(),
    original_name: `fixture.${options.format === "jpeg" ? "jpg" : "webp"}`,
    original_sha256: actualHash,
    original_bytes: options.bytes.length,
    raw_width: 2,
    raw_height: 1,
    source_width: 2,
    source_height: 1,
    captured_at: new Date().toISOString(),
    capture_time_source: "device",
  });
  await insert("media_variants", {
    id: variantId,
    asset_id: assetId,
    kind: "evidence",
    version: 1,
    bucket,
    object_path: path,
    format: options.format,
    mime_type: options.mimeType,
    width: options.reservedWidth ?? 2,
    height: 1,
    byte_size: options.reservedBytes ?? options.bytes.length,
    sha256: options.reservedHash ?? actualHash,
    encoder: "edge-integration",
  });
  if (options.upload !== false) {
    const { error } = await admin.storage.from(bucket).upload(
      path,
      options.bytes,
      {
        contentType: options.mimeType,
        upsert: false,
      },
    );
    if (error) throw new Error(`Storage upload failed: ${error.message}`);
  }
  await insert(
    options.targetKind === "elimination"
      ? "elimination_evidence"
      : "capture_evidence",
    options.targetKind === "elimination"
      ? { elimination_id: options.targetId, variant_id: variantId }
      : { capture_id: options.targetId, variant_id: variantId },
  );
  return variantId;
}

const unauthorized = await invoke({ variant_id: crypto.randomUUID() }, false);
check(
  unauthorized.status === 401 && unauthorized.body.error === "unauthorized",
  "Unauthorized request was not denied.",
);

const validCapture = await createCapture();
const validJpegVariant = await reserveAndLink({
  bytes: fixtures.jpeg,
  format: "jpeg",
  mimeType: "image/jpeg",
  targetKind: "capture",
  targetId: validCapture.captureId,
});
const validJpegResult = await invoke({ variant_id: validJpegVariant });
check(validJpegResult.status === 200, "Valid JPEG invocation failed.");
response = await admin.from("media_variants").select("upload_status").eq(
  "id",
  validJpegVariant,
).single();
check(
  response.data?.upload_status === "verified",
  "Valid JPEG was not verified.",
);
response = await admin.from("captures").select("status").eq(
  "id",
  validCapture.captureId,
).single();
check(
  response.data?.status === "finalized",
  "Valid JPEG capture did not finalize.",
);
const repeated = await invoke({ variant_id: validJpegVariant });
check(
  repeated.body.state === "already_processing_or_not_ready",
  "Repeated processing was not idempotent.",
);

const eliminationId = crypto.randomUUID();
await insert("eliminations", {
  id: eliminationId,
  owner_id: ownerId,
  idempotency_key: crypto.randomUUID(),
  capture_id: validCapture.captureId,
  captured_at: new Date().toISOString(),
  removed_count: 1,
  method: "manual removal",
  gps_source: "unavailable",
});
const webpVariant = await reserveAndLink({
  bytes: fixtures.webp,
  format: "webp",
  mimeType: "image/webp",
  targetKind: "elimination",
  targetId: eliminationId,
});
await invoke({ variant_id: webpVariant });
response = await admin.from("media_variants").select("upload_status").eq(
  "id",
  webpVariant,
).single();
check(
  response.data?.upload_status === "verified",
  "Valid WebP was not verified.",
);
response = await admin.from("eliminations").select("status").eq(
  "id",
  eliminationId,
).single();
check(
  response.data?.status === "finalized",
  "Valid WebP elimination did not finalize.",
);

const reviewCapture = await createCapture(true);
const reviewVariant = await reserveAndLink({
  bytes: fixtures.jpeg,
  format: "jpeg",
  mimeType: "image/jpeg",
  targetKind: "capture",
  targetId: reviewCapture.captureId,
});
const waiting = await invoke({ variant_id: reviewVariant });
check(
  waiting.body.processed?.[0]?.state === "waiting_prerequisite",
  "Review-band capture did not remain pending.",
);
response = await admin.from("captures").select("status").eq(
  "id",
  reviewCapture.captureId,
).single();
check(
  response.data?.status === "pending",
  "Byte verification bypassed Expert review.",
);
await insert("expert_decisions", {
  capture_id: reviewCapture.captureId,
  expert_id: expertId,
  decision: "correct",
  reason: "Local integration review",
  corrected_count: 1,
  item_decisions: [{ item_id: reviewCapture.itemId, decision: "approve" }],
});
await invoke({ variant_id: reviewVariant });
response = await admin.from("captures").select("status").eq(
  "id",
  reviewCapture.captureId,
).single();
check(
  response.data?.status === "finalized",
  "Expert-reviewed capture did not finalize on retry.",
);

const missingCapture = await createCapture();
const missingVariant = await reserveAndLink({
  bytes: fixtures.jpeg,
  format: "jpeg",
  mimeType: "image/jpeg",
  targetKind: "capture",
  targetId: missingCapture.captureId,
  upload: false,
});
const missing = await invoke({ variant_id: missingVariant });
check(
  missing.body.processed?.[0]?.code === "object_unavailable",
  "Missing object was not classified as temporary.",
);

const rejectionCases = [
  {
    name: "hash",
    bytes: fixtures.jpeg,
    format: "jpeg" as const,
    mime: "image/jpeg" as const,
    hash: "0".repeat(64),
  },
  {
    name: "byte-count",
    bytes: fixtures.jpeg,
    format: "jpeg" as const,
    mime: "image/jpeg" as const,
    byteSize: fixtures.jpeg.length + 1,
  },
  {
    name: "dimension",
    bytes: fixtures.jpeg,
    format: "jpeg" as const,
    mime: "image/jpeg" as const,
    width: 3,
  },
  {
    name: "mime",
    bytes: fixtures.webp,
    format: "jpeg" as const,
    mime: "image/jpeg" as const,
  },
  {
    name: "corrupt",
    bytes: new Uint8Array([1, 2, 3, 4]),
    format: "jpeg" as const,
    mime: "image/jpeg" as const,
  },
];
for (const fixture of rejectionCases) {
  const capture = await createCapture();
  const variantId = await reserveAndLink({
    bytes: fixture.bytes,
    format: fixture.format,
    mimeType: fixture.mime,
    targetKind: "capture",
    targetId: capture.captureId,
    reservedHash: fixture.hash,
    reservedWidth: fixture.width,
    reservedBytes: fixture.byteSize,
  });
  const result = await invoke({ variant_id: variantId });
  check(
    result.body.processed?.[0]?.state === "rejected",
    `${fixture.name} mismatch was not rejected.`,
  );
  response = await admin.from("media_variants").select("upload_status").eq(
    "id",
    variantId,
  ).single();
  check(
    response.data?.upload_status === "failed",
    `${fixture.name} mismatch did not mark media failed.`,
  );
}

const concurrentCapture = await createCapture();
const concurrentVariant = await reserveAndLink({
  bytes: fixtures.jpeg,
  format: "jpeg",
  mimeType: "image/jpeg",
  targetKind: "capture",
  targetId: concurrentCapture.captureId,
});
await Promise.all([
  invoke({ variant_id: concurrentVariant }),
  invoke({ variant_id: concurrentVariant }),
]);
response = await admin.from("audit_events").select("id", {
  count: "exact",
  head: true,
})
  .eq("action", "media_verified").eq("target_id", concurrentVariant);
check(
  response.count === 1,
  "Concurrent processing wrote more than one verification event.",
);

console.log(JSON.stringify({
  unauthorized: "denied",
  jpeg: "verified",
  webp: "verified",
  expertPrerequisite: "enforced",
  missingObject: "retry",
  permanentRejections: rejectionCases.length,
  concurrentVerificationEvents: response.count,
}));
