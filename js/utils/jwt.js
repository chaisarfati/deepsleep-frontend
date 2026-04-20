function b64urlToJson(b64url) {
  try {
    const pad = "=".repeat((4 - (b64url.length % 4)) % 4);
    const b64 = (b64url + pad).replaceAll("-", "+").replaceAll("_", "/");
    const json = atob(b64);
    return JSON.parse(json);
  } catch {
    return null;
  }
}

export function decodeJwtPayload(token) {
  if (!token || typeof token !== "string") return null;
  const parts = token.split(".");
  if (parts.length < 2) return null;
  return b64urlToJson(parts[1]);
}
