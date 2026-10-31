import { assertEquals, assertRejects } from "jsr:@std/assert@1";

import {
  inspectEvidenceBytes,
  PermanentEvidenceError,
  sha256Hex,
} from "./evidence_image.ts";

function jpegHeader(width: number, height: number): Uint8Array {
  return new Uint8Array([
    0xff,
    0xd8,
    0xff,
    0xc0,
    0x00,
    0x0b,
    0x08,
    (height >> 8) & 0xff,
    height & 0xff,
    (width >> 8) & 0xff,
    width & 0xff,
    0x01,
    0x01,
    0x11,
    0x00,
    0xff,
    0xd9,
  ]);
}

function webpHeader(width: number, height: number): Uint8Array {
  const bytes = new Uint8Array(30);
  bytes.set(new TextEncoder().encode("RIFF"), 0);
  bytes[4] = 22;
  bytes.set(new TextEncoder().encode("WEBPVP8X"), 8);
  bytes[16] = 10;
  const w = width - 1;
  const h = height - 1;
  bytes.set([w & 0xff, (w >> 8) & 0xff, (w >> 16) & 0xff], 24);
  bytes.set([h & 0xff, (h >> 8) & 0xff, (h >> 16) & 0xff], 27);
  return bytes;
}

Deno.test("accepts JPEG when declared and decoded dimensions agree", async () => {
  const bytes = jpegHeader(4, 3);
  const result = await inspectEvidenceBytes(
    bytes,
    "jpeg",
    "image/jpeg",
    () => ({ width: 4, height: 3 }),
  );
  assertEquals(result.format, "jpeg");
  assertEquals(result.width, 4);
  assertEquals(result.height, 3);
  assertEquals(result.sha256, await sha256Hex(bytes));
});

Deno.test("accepts WebP when declared and decoded dimensions agree", async () => {
  const bytes = webpHeader(5, 2);
  const result = await inspectEvidenceBytes(
    bytes,
    "webp",
    "image/webp",
    () => ({ width: 5, height: 2 }),
  );
  assertEquals(result.format, "webp");
  assertEquals(result.mimeType, "image/webp");
});

Deno.test("rejects corrupt bytes and MIME substitution", async () => {
  await assertRejects(
    () =>
      inspectEvidenceBytes(
        new Uint8Array([1, 2, 3]),
        "jpeg",
        "image/jpeg",
        () => ({ width: 1, height: 1 }),
      ),
    PermanentEvidenceError,
    "not a JPEG or WebP",
  );
  await assertRejects(
    () =>
      inspectEvidenceBytes(
        jpegHeader(4, 3),
        "webp",
        "image/webp",
        () => ({ width: 4, height: 3 }),
      ),
    PermanentEvidenceError,
    "does not match",
  );
});

Deno.test("rejects failed decode and inconsistent dimensions", async () => {
  await assertRejects(
    () =>
      inspectEvidenceBytes(jpegHeader(4, 3), "jpeg", "image/jpeg", () => {
        throw new Error("decode failed");
      }),
    PermanentEvidenceError,
    "could not be decoded",
  );
  await assertRejects(
    () =>
      inspectEvidenceBytes(
        webpHeader(5, 2),
        "webp",
        "image/webp",
        () => ({ width: 6, height: 2 }),
      ),
    PermanentEvidenceError,
    "do not match",
  );
});

Deno.test("rejects decoded image resource abuse", async () => {
  await assertRejects(
    () =>
      inspectEvidenceBytes(
        webpHeader(8192, 4096),
        "webp",
        "image/webp",
        () => ({ width: 8192, height: 4096 }),
      ),
    PermanentEvidenceError,
    "safe limits",
  );
});
