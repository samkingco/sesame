/**
 * Minimal TOTP implementation using Web Crypto API.
 * SHA-1, 6 digits, 30-second window, ±1 window tolerance.
 */

const BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

export function base32Encode(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let bits = 0;
  let value = 0;
  let result = "";

  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      result += BASE32_ALPHABET[(value >>> bits) & 0x1f];
    }
  }

  if (bits > 0) {
    result += BASE32_ALPHABET[(value << (5 - bits)) & 0x1f];
  }

  return result;
}

export function base32Decode(input: string): Uint8Array {
  const cleaned = input.toUpperCase().replace(/[^A-Z2-7]/g, "");
  const output = new Uint8Array(Math.floor((cleaned.length * 5) / 8));
  let bits = 0;
  let value = 0;
  let index = 0;

  for (const char of cleaned) {
    const i = BASE32_ALPHABET.indexOf(char);
    if (i === -1) continue;
    value = (value << 5) | i;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      output[index++] = (value >>> bits) & 0xff;
    }
  }

  return output.slice(0, index);
}

async function hmacSha1(
  key: Uint8Array,
  message: Uint8Array,
): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, message);
  return new Uint8Array(signature);
}

function intToBytes(num: number): Uint8Array {
  const bytes = new Uint8Array(8);
  for (let i = 7; i >= 0; i--) {
    bytes[i] = num & 0xff;
    num = Math.floor(num / 256);
  }
  return bytes;
}

function dynamicTruncate(hmac: Uint8Array): number {
  const offset = hmac[hmac.length - 1] & 0x0f;
  return (
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff)
  );
}

export async function generateTOTP(
  secret: Uint8Array,
  timeStep?: number,
): Promise<string> {
  const step = timeStep ?? Math.floor(Date.now() / 1000 / 30);
  const message = intToBytes(step);
  const hmac = await hmacSha1(secret, message);
  const code = dynamicTruncate(hmac) % 1_000_000;
  return code.toString().padStart(6, "0");
}

export async function verifyTOTP(
  secret: Uint8Array,
  code: string,
): Promise<boolean> {
  const currentStep = Math.floor(Date.now() / 1000 / 30);

  for (let offset = -1; offset <= 1; offset++) {
    const expected = await generateTOTP(secret, currentStep + offset);
    if (expected === code.padStart(6, "0")) {
      return true;
    }
  }

  return false;
}

export function generateSecret(): Uint8Array {
  const bytes = new Uint8Array(20);
  crypto.getRandomValues(bytes);
  return bytes;
}

export function buildOTPAuthURI(
  email: string,
  secret: string,
  issuer = "Gomashio Industries",
): string {
  const label = encodeURIComponent(`${issuer}:${email}`);
  const encodedIssuer = encodeURIComponent(issuer);
  return `otpauth://totp/${label}?secret=${secret}&issuer=${encodedIssuer}&algorithm=SHA1&digits=6&period=30`;
}
