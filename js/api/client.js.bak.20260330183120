import { Store } from "../store.js";

function authHeaders() {
  const token = Store.getState().auth?.token;
  return token ? { Authorization: `Bearer ${token}` } : {};
}

const BACKEND_URL = "http://localhost:8000";

/**
 * Same-origin client:
 * - Uses relative paths: "/auth/login", "/accounts/.."
 * - No user-editable base URL (internal)
 */
export async function request(path, { method = "GET", query = null, body = null } = {}) {
  const url = new URL(path, BACKEND_URL);
  if (query) Object.entries(query).forEach(([k, v]) => url.searchParams.set(k, String(v)));

  const res = await fetch(url.toString(), {
    method,
    headers: { "Content-Type": "application/json", ...authHeaders() },
    body: body ? JSON.stringify(body) : null,
  });

  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = { raw: text }; }

  if (!res.ok) {
    const msg = (data && (data.detail || data.message)) ? (data.detail || data.message) : `HTTP ${res.status}`;
    throw new Error(msg);
  }
  return data;
}

export const ApiClient = { request };
