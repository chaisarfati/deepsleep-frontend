import { Store } from "../store.js";

function authHeaders() {
  const token = Store.getState().auth?.token;
  return token ? { Authorization: `Bearer ${token}` } : {};
}

const BACKEND_BASE = `${window.location.origin}/api/`;

/**
 * Same-origin client:
 * - Uses relative API paths like "/auth/login", "/accounts/.."
 * - Browser origin decides the host, then Nginx proxies "/api" to backend
 */
export async function request(path, { method = "GET", query = null, body = null } = {}) {
  const normalizedPath = path.startsWith("/") ? path.slice(1) : path;
  const url = new URL(normalizedPath, BACKEND_BASE);

  if (query) {
    Object.entries(query).forEach(([k, v]) => {
      if (v !== undefined && v !== null) {
        url.searchParams.set(k, String(v));
      }
    });
  }

  const res = await fetch(url.toString(), {
    method,
    headers: {
      "Content-Type": "application/json",
      ...authHeaders(),
    },
    body: body ? JSON.stringify(body) : null,
  });

  const text = await res.text();
  let data = null;

  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text ? { raw: text } : null;
  }

  if (!res.ok) {
    const msg =
      data && (data.detail || data.message)
        ? (data.detail || data.message)
        : `HTTP ${res.status}`;
    throw new Error(msg);
  }

  return data;
}

export const ApiClient = { request };
