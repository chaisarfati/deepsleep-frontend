import { Store } from "../store.js";

function authHeaders() {
  const token = Store.getState().auth?.token;
  return token ? { Authorization: `Bearer ${token}` } : {};
}

/**
 * API base resolution:
 * - Local dev: define window.__DEEPSLEEP_API_BASE__ = "http://localhost:8000"
 * - Remote with reverse proxy: define window.__DEEPSLEEP_API_BASE__ = "/api"
 * - Fallback: same-origin reverse proxy on "/api"
 */
const RAW_API_BASE = window.__DEEPSLEEP_API_BASE__ || "/api";
const BACKEND_BASE = new URL(
  RAW_API_BASE.endsWith("/") ? RAW_API_BASE : `${RAW_API_BASE}/`,
  window.location.origin
).toString();

export async function request(
  path,
  { method = "GET", query = null, body = null } = {}
) {
  const normalizedPath = path.startsWith("/") ? path.slice(1) : path;
  const url = new URL(normalizedPath, BACKEND_BASE);

  if (query) {
    Object.entries(query).forEach(([k, v]) => {
      if (v !== undefined && v !== null) {
        url.searchParams.set(k, String(v));
      }
    });
  }

  const headers = {
    ...authHeaders(),
  };

  if (body !== null) {
    headers["Content-Type"] = "application/json";
  }

  const res = await fetch(url.toString(), {
    method,
    headers,
    body: body !== null ? JSON.stringify(body) : null,
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