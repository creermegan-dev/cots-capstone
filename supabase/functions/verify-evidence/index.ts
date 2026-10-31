import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  ImageMagick,
  initializeImageMagick,
} from "npm:@imagemagick/magick-wasm@^0";

import {
  type EvidenceDimensions,
  inspectEvidenceBytes,
  PermanentEvidenceError,
} from "../_shared/evidence_image.ts";

const wasmBytes = await Deno.readFile(
  new URL("./magick.wasm", import.meta.url),
);
await initializeImageMagick(wasmBytes);

interface JobClaim {
  variant_id: string;
  lock_token: string;
  attempts: number;
}

interface VariantRow {
  id: string;
  asset_id: string;
  bucket: string;
  object_path: string;
  format: string;
  mime_type: string;
  width: number;
  height: number;
  byte_size: number;
  sha256: string;
  upload_status: string;
}

interface AssetRow {
  id: string;
  owner_id: string;
}

interface TargetAssociation {
  kind: "capture" | "elimination" | "survey";
  id: string;
  ownerId: string;
}

class TemporaryEvidenceError extends Error {
  constructor(public readonly code: string, message: string) {
    super(message);
    this.name = "TemporaryEvidenceError";
  }
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json",
    },
  });
}

function defaultSecretKey(): string | null {
  const encoded = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (encoded) {
    try {
      const parsed = JSON.parse(encoded) as Record<string, string>;
      if (typeof parsed.default === "string" && parsed.default.length > 0) {
        return parsed.default;
      }
    } catch (_) {
      // Fall through to the legacy local/runtime variable.
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
}

function defaultPublishableKey(): string {
  const encoded = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (encoded) {
    try {
      const parsed = JSON.parse(encoded) as Record<string, string>;
      if (typeof parsed.default === "string" && parsed.default.length > 0) {
        return parsed.default;
      }
    } catch (_) {
      // Fall through to the legacy local/runtime variable.
    }
  }
  const fallback = Deno.env.get("SUPABASE_ANON_KEY");
  if (!fallback) throw new Error("Supabase publishable key is unavailable.");
  return fallback;
}

function constantTimeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  let difference = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index++) {
    difference |= (a[index % Math.max(a.length, 1)] ?? 0) ^
      (b[index % Math.max(b.length, 1)] ?? 0);
  }
  return difference === 0;
}

function decodeWithImageMagick(bytes: Uint8Array): EvidenceDimensions {
  return ImageMagick.read(
    bytes,
    (image) => ({ width: image.width, height: image.height }),
  );
}

async function requireOwner(
  req: Request,
  url: string,
  variantId: string,
  admin: SupabaseClient,
): Promise<string | null> {
  const authorization = req.headers.get("authorization");
  if (!authorization?.toLowerCase().startsWith("bearer ")) return null;
  const token = authorization.slice("bearer ".length).trim();
  if (!token) return null;
  const authClient = createClient(url, defaultPublishableKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await authClient.auth.getUser(
    token,
  );
  if (userError || !userData.user) return null;
  // The session must come from a trusted device (new-device verification).
  const userClient = createClient(url, defaultPublishableKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: trusted, error: trustError } = await userClient.rpc(
    "current_session_trusted",
  );
  if (trustError || trusted !== true) return null;
  const { data: variant, error: variantError } = await admin
    .from("media_variants").select("asset_id").eq("id", variantId)
    .maybeSingle();
  if (variantError || !variant) return null;
  const [{ data: asset, error: assetError }, { data: profile }] = await Promise
    .all([
      admin
        .from("media_assets").select("owner_id").eq("id", variant.asset_id)
        .maybeSingle(),
      admin.from("profiles").select("active").eq("id", userData.user.id)
        .maybeSingle(),
    ]);
  if (
    assetError || asset?.owner_id !== userData.user.id ||
    profile?.active !== true
  ) return null;
  return userData.user.id;
}

async function loadAssociations(
  admin: SupabaseClient,
  variant: VariantRow,
  asset: AssetRow,
): Promise<TargetAssociation[]> {
  const associations: TargetAssociation[] = [];
  const [captures, eliminations, surveys] = await Promise.all([
    admin.from("capture_evidence").select("capture_id").eq(
      "variant_id",
      variant.id,
    ),
    admin.from("elimination_evidence").select("elimination_id").eq(
      "variant_id",
      variant.id,
    ),
    admin.from("survey_evidence").select("survey_id").eq(
      "variant_id",
      variant.id,
    ),
  ]);
  for (const response of [captures, eliminations, surveys]) {
    if (response.error) {
      throw new TemporaryEvidenceError(
        "association_query_failed",
        "Evidence associations could not be read.",
      );
    }
  }
  for (const row of captures.data ?? []) {
    const { data, error } = await admin.from("captures").select("owner_id").eq(
      "id",
      row.capture_id,
    ).single();
    if (error || !data) {
      throw new PermanentEvidenceError(
        "target_missing",
        "Linked capture does not exist.",
      );
    }
    associations.push({
      kind: "capture",
      id: row.capture_id,
      ownerId: data.owner_id,
    });
  }
  for (const row of eliminations.data ?? []) {
    const { data, error } = await admin.from("eliminations").select("owner_id")
      .eq("id", row.elimination_id).single();
    if (error || !data) {
      throw new PermanentEvidenceError(
        "target_missing",
        "Linked elimination does not exist.",
      );
    }
    associations.push({
      kind: "elimination",
      id: row.elimination_id,
      ownerId: data.owner_id,
    });
  }
  for (const row of surveys.data ?? []) {
    const { data, error } = await admin.from("follow_up_surveys").select(
      "owner_id",
    ).eq("id", row.survey_id).single();
    if (error || !data) {
      throw new PermanentEvidenceError(
        "target_missing",
        "Linked survey does not exist.",
      );
    }
    associations.push({
      kind: "survey",
      id: row.survey_id,
      ownerId: data.owner_id,
    });
  }
  if (associations.length === 0) {
    throw new TemporaryEvidenceError(
      "awaiting_evidence_link",
      "Uploaded evidence is waiting for its record link.",
    );
  }
  if (associations.length !== 1) {
    throw new PermanentEvidenceError(
      "ambiguous_record_association",
      "A variant must be linked to exactly one record.",
    );
  }
  const association = associations[0];
  if (association.ownerId !== asset.owner_id) {
    throw new PermanentEvidenceError(
      "owner_association_mismatch",
      "Evidence owner does not match the linked record owner.",
    );
  }
  const expectedBucket = association.kind === "elimination"
    ? "elimination-evidence"
    : "detection-evidence";
  if (variant.bucket !== expectedBucket) {
    throw new PermanentEvidenceError(
      "bucket_association_mismatch",
      "Evidence bucket does not match its record purpose.",
    );
  }
  const expectedPath = `${asset.owner_id}/${variant.asset_id}/${variant.id}`;
  if (variant.object_path !== expectedPath) {
    throw new PermanentEvidenceError(
      "object_path_mismatch",
      "Evidence path does not match its reservation.",
    );
  }
  return associations;
}

async function recordOutcome(
  admin: SupabaseClient,
  claim: JobClaim,
  state: "retry" | "waiting_prerequisite" | "verified" | "rejected",
  code: string | null,
  detail: string | null,
  result: Record<string, unknown>,
  retryAfter: number,
): Promise<void> {
  const { error } = await admin.rpc("record_evidence_verification_outcome", {
    requested_variant: claim.variant_id,
    requested_lock_token: claim.lock_token,
    requested_state: state,
    error_code: code,
    error_detail: detail,
    result_details: result,
    retry_after_seconds: retryAfter,
  });
  if (error) {
    throw new Error(
      `Could not record evidence job outcome: ${error.code ?? "unknown"}`,
    );
  }
}

async function processClaim(
  admin: SupabaseClient,
  claim: JobClaim,
): Promise<Record<string, unknown>> {
  const { data: rawVariant, error: variantError } = await admin
    .from("media_variants").select("*").eq("id", claim.variant_id)
    .maybeSingle();
  if (variantError || !rawVariant) {
    throw new PermanentEvidenceError(
      "reservation_missing",
      "Evidence reservation does not exist.",
    );
  }
  const variant = rawVariant as VariantRow;
  const { data: rawAsset, error: assetError } = await admin
    .from("media_assets").select("id,owner_id").eq("id", variant.asset_id)
    .maybeSingle();
  if (assetError || !rawAsset) {
    throw new PermanentEvidenceError(
      "asset_missing",
      "Evidence asset does not exist.",
    );
  }
  const asset = rawAsset as AssetRow;
  const associations = await loadAssociations(admin, variant, asset);

  if (variant.upload_status !== "verified") {
    if (variant.upload_status === "failed") {
      await recordOutcome(
        admin,
        claim,
        "rejected",
        "already_rejected",
        "Evidence was previously rejected.",
        {},
        60,
      );
      return { variant_id: variant.id, state: "rejected" };
    }
    const { data: blob, error: downloadError } = await admin.storage
      .from(variant.bucket).download(variant.object_path);
    if (downloadError || !blob) {
      throw new TemporaryEvidenceError(
        "object_unavailable",
        "The reserved Storage object is not available yet.",
      );
    }
    const bytes = new Uint8Array(await blob.arrayBuffer());
    const inspected = await inspectEvidenceBytes(
      bytes,
      variant.format,
      variant.mime_type,
      decodeWithImageMagick,
    );
    if (inspected.byteSize !== Number(variant.byte_size)) {
      throw new PermanentEvidenceError(
        "byte_count_mismatch",
        "Stored byte count does not match the reservation.",
      );
    }
    if (inspected.sha256 !== variant.sha256) {
      throw new PermanentEvidenceError(
        "sha256_mismatch",
        "Stored hash does not match the reservation.",
      );
    }
    if (
      inspected.width !== variant.width || inspected.height !== variant.height
    ) {
      throw new PermanentEvidenceError(
        "dimension_mismatch",
        "Stored dimensions do not match the reservation.",
      );
    }
    const receipt = `edge-v1:${crypto.randomUUID()}`;
    const { error: verifyError } = await admin.rpc("record_verified_media", {
      variant: variant.id,
      actual_sha256: inspected.sha256,
      actual_bytes: inspected.byteSize,
      actual_width: inspected.width,
      actual_height: inspected.height,
      receipt,
    });
    if (verifyError) {
      throw new TemporaryEvidenceError(
        "verification_rpc_failed",
        "Trusted verification could not be recorded.",
      );
    }
  }

  const { data: finalization, error: finalizationError } = await admin
    .rpc("finalize_linked_evidence", { requested_variant: variant.id });
  if (finalizationError) {
    throw new TemporaryEvidenceError(
      "finalization_rpc_failed",
      "Record finalization could not be evaluated.",
    );
  }
  const result = (finalization ?? {}) as Record<string, unknown>;
  const allTerminal = result.all_terminal === true;
  await recordOutcome(
    admin,
    claim,
    allTerminal ? "verified" : "waiting_prerequisite",
    allTerminal ? null : "record_prerequisite_pending",
    allTerminal
      ? null
      : "Evidence is verified; a record or Expert prerequisite is still pending.",
    {
      ...result,
      associations: associations.map((value) => ({
        kind: value.kind,
        id: value.id,
      })),
    },
    allTerminal ? 60 : 21600,
  );
  return {
    variant_id: variant.id,
    state: allTerminal ? "finalized" : "waiting_prerequisite",
    result,
  };
}

async function rejectPermanently(
  admin: SupabaseClient,
  claim: JobClaim,
  error: PermanentEvidenceError,
): Promise<Record<string, unknown>> {
  const receipt = `edge-reject-v1:${crypto.randomUUID()}`;
  const { error: rejectError } = await admin.rpc("reject_evidence_media", {
    requested_variant: claim.variant_id,
    requested_lock_token: claim.lock_token,
    rejection_code: error.code,
    rejection_receipt: receipt,
  });
  if (rejectError) {
    throw new Error(
      `Could not reject invalid evidence: ${rejectError.code ?? "unknown"}`,
    );
  }
  await recordOutcome(
    admin,
    claim,
    "rejected",
    error.code,
    error.message,
    {},
    60,
  );
  return { variant_id: claim.variant_id, state: "rejected", code: error.code };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const secretKey = defaultSecretKey();
  if (!url || !secretKey) {
    return json({ error: "server_configuration_unavailable" }, 503);
  }

  let body: { variant_id?: string; batch_limit?: number };
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "invalid_json" }, 400);
  }
  const requestedVariant = typeof body.variant_id === "string"
    ? body.variant_id
    : null;
  const internal = constantTimeEqual(
    req.headers.get("apikey") ?? "",
    secretKey,
  );
  const admin = createClient(url, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  if (!internal) {
    if (
      !requestedVariant ||
      !await requireOwner(req, url, requestedVariant, admin)
    ) {
      return json({ error: "unauthorized" }, 401);
    }
  }
  const limit = internal
    ? Math.min(Math.max(Number(body.batch_limit ?? 5), 1), 10)
    : 1;
  const { data: claims, error: claimError } = await admin.rpc(
    "claim_evidence_verification_jobs",
    {
      requested_variant: requestedVariant,
      requested_limit: limit,
    },
  );
  if (claimError) {
    return json({ error: "claim_failed", code: claimError.code }, 503);
  }
  if (!claims || claims.length === 0) {
    return json(
      { state: "already_processing_or_not_ready", processed: [] },
      202,
    );
  }

  const processed: Record<string, unknown>[] = [];
  for (const rawClaim of claims as JobClaim[]) {
    try {
      processed.push(await processClaim(admin, rawClaim));
    } catch (error) {
      if (error instanceof PermanentEvidenceError) {
        processed.push(await rejectPermanently(admin, rawClaim, error));
        continue;
      }
      const temporary = error instanceof TemporaryEvidenceError
        ? error
        : new TemporaryEvidenceError(
          "unexpected_processing_failure",
          "Evidence processing failed temporarily.",
        );
      const retryAfter = Math.min(
        3600,
        Math.max(30, 30 * 2 ** Math.min(rawClaim.attempts - 1, 7)),
      );
      try {
        await recordOutcome(
          admin,
          rawClaim,
          temporary.code === "awaiting_evidence_link"
            ? "waiting_prerequisite"
            : "retry",
          temporary.code,
          temporary.message,
          {},
          retryAfter,
        );
      } catch (_) {
        // A stale lease is safe: another invocation owns the next attempt.
      }
      processed.push({
        variant_id: rawClaim.variant_id,
        state: "retry",
        code: temporary.code,
      });
    }
  }
  return json({ state: "processed", processed });
});
