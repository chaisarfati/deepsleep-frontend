#!/usr/bin/env bash
set -euo pipefail
echo "hi"
# DeepSleep SPA refactor (Vanilla ES Modules, no behavior changes)
# Creates:
#  /css/main.css + module css
#  /js/api/client.js, /js/api/services.js
#  /js/components/*
#  /js/pages/*
#  /js/utils/*
#  /js/store.js
#  app.js (entry)
#  index.html (minimal shell)
#
# Run from your project root (where you want index.html/app.js etc.)
echo "hi"
ROOT="${1:-.}"

mkdir -p \
  "$ROOT/css" \
  "$ROOT/js/api" \
  "$ROOT/js/components" \
  "$ROOT/js/pages" \
  "$ROOT/js/utils"

cat > "$ROOT/index.html" <<'EOF'
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <meta name="color-scheme" content="light" />
  <title>DeepSleep — FinOps Control Plane</title>

  <link rel="stylesheet" href="./css/main.css" />
  <link rel="stylesheet" href="./css/sidebar.css" />
  <link rel="stylesheet" href="./css/header.css" />
  <link rel="stylesheet" href="./css/inventory.css" />
</head>

<body>
  <a class="ds-skip-link" href="#ds-app">Aller au contenu</a>

  <div class="ds-shell">
    <!-- Left rail -->
    <aside class="ds-rail" aria-label="Navigation principale" id="ds-rail"></aside>

    <!-- Main column -->
    <main class="ds-main" id="ds-app">
      <header class="ds-topbar" role="banner" id="ds-topbar"></header>

      <!-- Toast + modal portal -->
      <div class="ds-toaststack" id="ds-toaststack" aria-live="polite" aria-relevant="additions"></div>
      <div class="ds-modalhost" id="ds-modalhost"></div>

      <!-- Routed content -->
      <section class="ds-page" id="ds-page"></section>
    </main>
  </div>

  <script type="module" src="./app.js"></script>
</body>
</html>
EOF

# -------------------- CSS --------------------
cat > "$ROOT/css/main.css" <<'EOF'
/* main.css (variables + reset + shared primitives) */
:root{
  --ds-bg: #D6D2C4;          /* retro industrial beige */
  --ds-surface: #E1DDD0;     /* matte light gray */
  --ds-ink: #1A1A1A;         /* charcoal */
  --ds-shadow: #000000;

  --ds-wake: #3A6B8F;        /* desaturated blue */
  --ds-sleep: #9B4A3A;       /* matte brick red */
  --ds-reg: #5E6B3A;         /* olive */

  --ds-muted: rgba(26,26,26,.68);
  --ds-faint: rgba(26,26,26,.12);

  --ds-radius: 0px;          /* hard edges */
  --ds-border: 1px solid var(--ds-ink);
  --ds-hard-shadow: 4px 4px 0px var(--ds-shadow);

  --ds-mono: ui-monospace, "JetBrains Mono", SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
  --ds-font: var(--ds-mono);

  --ds-rail-w: 260px;
  --ds-topbar-h: 62px;

  --ds-pad-1: 8px;
  --ds-pad-2: 12px;
  --ds-pad-3: 16px;
  --ds-pad-4: 20px;

  --ds-line: 1.45;
}

*{ box-sizing:border-box; }
html, body{ height:100%; }
body{
  margin:0;
  background:var(--ds-bg);
  color:var(--ds-ink);
  font-family:var(--ds-font);
  line-height:var(--ds-line);
  letter-spacing:.1px;
}

a{ color:inherit; text-decoration:none; }
button, input, select, textarea{ font:inherit; color:inherit; }
button{ cursor:pointer; background:transparent; border:none; }

.ds-skip-link{
  position:absolute;
  top:0; left:0;
  transform:translateY(-120%);
  background:var(--ds-surface);
  border:var(--ds-border);
  padding:8px 10px;
  z-index:9999;
}
.ds-skip-link:focus{ transform:translateY(0); }

.ds-shell{
  display:grid;
  grid-template-columns: var(--ds-rail-w) 1fr;
  min-height:100vh;
}

.ds-main{ min-width:0; }
.ds-page{
  padding:var(--ds-pad-4);
  max-width: 1200px;
}

/* Shared atoms */
.ds-panel{
  border:var(--ds-border);
  background:var(--ds-surface);
  box-shadow:var(--ds-hard-shadow);
  padding:var(--ds-pad-3);
  margin-bottom:var(--ds-pad-4);
}
.ds-panel__head{
  display:flex;
  align-items:flex-start;
  justify-content:space-between;
  gap:16px;
  margin-bottom:12px;
}
.ds-panel__title{ font-weight:800; letter-spacing:.2px; }
.ds-panel__sub{ font-size:12px; color:var(--ds-muted); margin-top:4px; }

.ds-row{
  display:flex;
  flex-wrap:wrap;
  gap:10px;
  align-items:center;
}

.ds-badge{
  display:inline-flex;
  align-items:center;
  gap:8px;
  padding:4px 8px;
  border:var(--ds-border);
  background:var(--ds-bg);
  font-size:12px;
  white-space:nowrap;
}
.ds-badge--reg{ border-color: var(--ds-reg); }
.ds-badge--muted{ opacity:.9; }

.ds-btn{
  border:var(--ds-border);
  background:var(--ds-bg);
  padding:10px 12px;
  box-shadow:var(--ds-hard-shadow);
  font-weight:700;
  letter-spacing:.2px;
}
.ds-btn:disabled{ opacity:.55; cursor:not-allowed; }
.ds-btn--wake{ background:color-mix(in srgb, var(--ds-wake) 18%, var(--ds-bg)); }
.ds-btn--sleep{ background:color-mix(in srgb, var(--ds-sleep) 18%, var(--ds-bg)); }
.ds-btn--ghost{ background:transparent; box-shadow:none; }
.ds-btn--danger{ background:color-mix(in srgb, var(--ds-sleep) 22%, var(--ds-surface)); }

.ds-field{
  display:flex;
  flex-direction:column;
  gap:6px;
  min-width:220px;
}
.ds-label{ font-size:12px; color:var(--ds-muted); }
.ds-input, .ds-select, .ds-textarea{
  border:var(--ds-border);
  background:var(--ds-bg);
  padding:10px 10px;
  outline:none;
  min-height:40px;
}
.ds-textarea{ min-height:100px; resize:vertical; }

.ds-tablewrap{ overflow:auto; border:var(--ds-border); background:var(--ds-bg); }
.ds-table{
  width:100%;
  border-collapse:collapse;
  font-size:12.5px;
  min-width: 860px;
}
.ds-table th, .ds-table td{
  border-bottom:1px solid rgba(26,26,26,.18);
  padding:10px 10px;
  text-align:left;
  vertical-align:top;
}
.ds-table th{
  position:sticky;
  top:0;
  background:var(--ds-surface);
  border-bottom:var(--ds-border);
  z-index:1;
}
.ds-table tr:hover td{ background: rgba(26,26,26,.04); }

.ds-kbd{
  border:var(--ds-border);
  padding:2px 6px;
  background:var(--ds-surface);
  font-size:12px;
}

.ds-pill{
  display:inline-flex;
  align-items:center;
  padding:2px 8px;
  border:var(--ds-border);
  background:var(--ds-surface);
  font-size:12px;
}
.ds-pill--running{ border-color: var(--ds-wake); }
.ds-pill--sleeping{ border-color: var(--ds-sleep); }
.ds-pill--locked{ border-color: var(--ds-ink); background: color-mix(in srgb, var(--ds-ink) 8%, var(--ds-surface)); }

.ds-mono-muted{ color:var(--ds-muted); font-size:12px; }

.ds-toaststack{
  position:fixed;
  right:16px;
  bottom:16px;
  display:flex;
  flex-direction:column;
  gap:10px;
  z-index:1000;
}
.ds-toast{
  width:min(420px, calc(100vw - 32px));
  border:var(--ds-border);
  background:var(--ds-surface);
  box-shadow:var(--ds-hard-shadow);
  padding:12px;
  font-size:12.5px;
}
.ds-toast__title{ font-weight:800; margin-bottom:6px; }
.ds-toast__msg{ color:var(--ds-muted); }

.ds-modalhost{
  position:fixed;
  inset:0;
  z-index:900;
  pointer-events:none;
}
.ds-modalbackdrop{
  position:absolute;
  inset:0;
  background:rgba(0,0,0,.22);
  pointer-events:auto;
}
.ds-modal{
  position:absolute;
  top:10vh;
  left:50%;
  transform:translateX(-50%);
  width:min(760px, calc(100vw - 32px));
  border:var(--ds-border);
  background:var(--ds-surface);
  box-shadow:var(--ds-hard-shadow);
  pointer-events:auto;
}
.ds-modal__head{
  display:flex;
  justify-content:space-between;
  align-items:center;
  padding:12px;
  border-bottom:var(--ds-border);
  background:var(--ds-bg);
}
.ds-modal__title{ font-weight:900; }
.ds-modal__body{ padding:12px; }
.ds-modal__foot{
  display:flex;
  justify-content:flex-end;
  gap:10px;
  padding:12px;
  border-top:var(--ds-border);
  background:var(--ds-bg);
}

/* Responsive */
@media (max-width: 960px){
  .ds-shell{ grid-template-columns: 1fr; }
  .ds-rail{ position:sticky; top:0; z-index:60; border-right:none; border-bottom:var(--ds-border); }
  .ds-topbar{ grid-template-columns: 1fr; height:auto; padding:12px; }
  .ds-topbar__left, .ds-topbar__right{ justify-content:flex-start; }
  .ds-table{ min-width: 760px; }
}
EOF

cat > "$ROOT/css/sidebar.css" <<'EOF'
/* sidebar.css */
.ds-rail{
  border-right:var(--ds-border);
  background:var(--ds-surface);
  padding:var(--ds-pad-3);
  display:flex;
  flex-direction:column;
  gap:var(--ds-pad-3);
}

.ds-rail__brand{
  display:flex;
  gap:10px;
  align-items:center;
  padding:10px;
  border:var(--ds-border);
  box-shadow:var(--ds-hard-shadow);
  background:var(--ds-bg);
}
.ds-brand__mark{
  display:grid;
  place-items:center;
  width:34px;
  height:34px;
  border:var(--ds-border);
  background:var(--ds-surface);
}
.ds-brand__name{ font-weight:700; letter-spacing:.3px; }
.ds-brand__tag{ font-size:12px; color:var(--ds-muted); }

.ds-rail__nav{
  display:flex;
  flex-direction:column;
  gap:8px;
}
.ds-navlink{
  display:flex;
  align-items:center;
  gap:10px;
  padding:10px 10px;
  border:var(--ds-border);
  background:var(--ds-surface);
}
.ds-navlink:hover{ background:var(--ds-bg); }
.ds-navlink[aria-current="page"]{
  background:var(--ds-bg);
  box-shadow:var(--ds-hard-shadow);
}
.ds-navlink__icon{ width:18px; height:18px; display:grid; place-items:center; }

.ds-rail__foot{
  margin-top:auto;
  display:flex;
  flex-direction:column;
  gap:8px;
  padding-top:10px;
  border-top:var(--ds-border);
}
.ds-foot__hint{
  display:flex;
  justify-content:space-between;
  font-size:12px;
  color:var(--ds-muted);
}
.ds-hint__value{ color:var(--ds-ink); }
EOF

cat > "$ROOT/css/header.css" <<'EOF'
/* header.css */
.ds-topbar{
  position:sticky;
  top:0;
  z-index:50;
  height:var(--ds-topbar-h);
  background:var(--ds-surface);
  border-bottom:var(--ds-border);
  display:grid;
  grid-template-columns: 1fr minmax(340px, 560px) 1fr;
  align-items:center;
  padding:0 var(--ds-pad-3);
  gap:var(--ds-pad-3);
}

.ds-crumbs{ font-weight:700; }

.ds-topbar__center{ display:flex; justify-content:center; }
.ds-search{
  width:100%;
  max-width:560px;
  display:flex;
  align-items:center;
  gap:10px;
  border:var(--ds-border);
  background:var(--ds-bg);
  padding:8px 10px;
  box-shadow:var(--ds-hard-shadow);
}
.ds-search__input{
  width:100%;
  background:transparent;
  border:none;
  outline:none;
}
.ds-search__icon{ display:grid; place-items:center; opacity:.9; }

.ds-topbar__right{ display:flex; justify-content:flex-end; position:relative; }
.ds-userchip{
  display:flex;
  align-items:center;
  gap:10px;
  padding:10px 12px;
  border:var(--ds-border);
  background:var(--ds-bg);
  box-shadow:var(--ds-hard-shadow);
}
.ds-userchip__dot{
  width:10px; height:10px;
  border:var(--ds-border);
  background:var(--ds-reg);
}
.ds-userchip__text{
  font-size:13px;
  max-width:220px;
  overflow:hidden;
  text-overflow:ellipsis;
  white-space:nowrap;
}

.ds-dropdown{
  position:absolute;
  right:0;
  top: calc(var(--ds-topbar-h) - 6px);
  width:min(360px, calc(100vw - var(--ds-rail-w) - 24px));
  background:var(--ds-surface);
  border:var(--ds-border);
  box-shadow:var(--ds-hard-shadow);
  padding:12px;
}
.ds-dropdown__row{
  display:flex;
  justify-content:space-between;
  gap:12px;
  padding:6px 0;
}
.ds-dropdown__k{ color:var(--ds-muted); font-size:12px; }
.ds-dropdown__v{
  font-size:12px;
  text-align:right;
  max-width:230px;
  overflow:hidden;
  text-overflow:ellipsis;
}
.ds-dropdown__sep{
  height:1px;
  background:var(--ds-ink);
  opacity:.18;
  margin:10px 0;
}
EOF

cat > "$ROOT/css/inventory.css" <<'EOF'
/* inventory.css (table specifics kept minimal; most styles are shared) */
/* Reserved for inventory-specific overrides if needed later. */
EOF

# -------------------- JS: utils --------------------
cat > "$ROOT/js/utils/dom.js" <<'EOF'
export function qs(sel, root = document) { return root.querySelector(sel); }
export function qsa(sel, root = document) { return Array.from(root.querySelectorAll(sel)); }

export function escapeHtml(str) {
  return String(str)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

export function cssEscapeAttr(str) {
  // minimal escape for attribute selector usage
  return String(str).replaceAll('"', '\\"');
}
EOF

cat > "$ROOT/js/utils/time.js" <<'EOF'
export function fmtTime(v) {
  try {
    const d = new Date(v);
    if (Number.isNaN(d.getTime())) return String(v);
    const pad = (n) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  } catch {
    return String(v);
  }
}
EOF

cat > "$ROOT/js/utils/storage.js" <<'EOF'
export const Storage = {
  get(key, fallback = "") {
    const v = localStorage.getItem(key);
    return v === null ? fallback : v;
  },
  set(key, value) {
    localStorage.setItem(key, String(value ?? ""));
  },
  del(key) {
    localStorage.removeItem(key);
  },
};
EOF

cat > "$ROOT/js/utils/toast.js" <<'EOF'
import { qs, escapeHtml } from "./dom.js";

export function toast(title, msg) {
  const stack = qs("#ds-toaststack");
  if (!stack) return;

  const t = document.createElement("div");
  t.className = "ds-toast";
  t.innerHTML = `<div class="ds-toast__title"></div><div class="ds-toast__msg"></div>`;
  t.querySelector(".ds-toast__title").textContent = title;
  t.querySelector(".ds-toast__msg").textContent = msg;

  stack.appendChild(t);
  setTimeout(() => t.remove(), 4200);
}

export function confirmModal({ title, body, confirmText = "Confirm", cancelText = "Cancel" }) {
  const host = qs("#ds-modalhost");
  if (!host) return Promise.resolve(false);

  return new Promise((resolve) => {
    host.innerHTML = `
      <div class="ds-modalbackdrop" data-backdrop="1"></div>
      <div class="ds-modal" role="dialog" aria-modal="true" aria-label="${escapeHtml(title)}">
        <div class="ds-modal__head">
          <div class="ds-modal__title">${escapeHtml(title)}</div>
          <button class="ds-btn ds-btn--ghost" type="button" data-close="1">Close</button>
        </div>
        <div class="ds-modal__body">${body}</div>
        <div class="ds-modal__foot">
          <button class="ds-btn ds-btn--ghost" type="button" data-cancel="1">${escapeHtml(cancelText)}</button>
          <button class="ds-btn" type="button" data-confirm="1">${escapeHtml(confirmText)}</button>
        </div>
      </div>
    `;
    host.style.pointerEvents = "auto";

    const cleanup = (val) => {
      host.innerHTML = "";
      host.style.pointerEvents = "none";
      resolve(val);
    };

    host.addEventListener("click", (e) => {
      const t = e.target;
      if (t && t.dataset && (t.dataset.backdrop || t.dataset.close || t.dataset.cancel)) cleanup(false);
      if (t && t.dataset && t.dataset.confirm) cleanup(true);
    }, { once: true });
  });
}
EOF

cat > "$ROOT/js/utils/poller.js" <<'EOF'
export function createPoller({ intervalMs, tick, guard = () => true, leadingDelayMs = 700 }) {
  let timer = null;

  async function safeTick() {
    if (!guard()) return;
    try { await tick(); } catch { /* caller may handle */ }
  }

  function start() {
    stop();
    timer = setInterval(safeTick, intervalMs);
    setTimeout(safeTick, leadingDelayMs);
  }

  function stop() {
    if (timer) clearInterval(timer);
    timer = null;
  }

  return { start, stop };
}
EOF

cat > "$ROOT/js/utils/router.js" <<'EOF'
export function createRouter() {
  const routes = new Map();

  function parseHash() {
    const raw = location.hash.replace(/^#/, "");
    const path = raw.startsWith("/") ? raw : "/discovery";
    const [p] = path.split("?");
    const parts = p.split("/").filter(Boolean);
    const name = parts[0] || "discovery";
    return { name, params: {} };
  }

  function register(name, handler) { routes.set(name, handler); }
  function go(path) { location.hash = "#" + path; }

  function start(onRoute) {
    window.addEventListener("hashchange", () => onRoute(parseHash()));
    onRoute(parseHash());
  }

  function render(route) {
    const handler = routes.get(route.name) || routes.get("discovery");
    handler?.(route);
  }

  return { register, go, start, render };
}
EOF

# -------------------- JS: store (Pub/Sub) --------------------
cat > "$ROOT/js/store.js" <<'EOF'
import { Storage } from "./utils/storage.js";

const state = {
  route: { name: "discovery", params: {} },

  ui: { search: "" },

  auth: {
    token: Storage.get("deepsleep.token", ""),
    business_id: Storage.get("deepsleep.business_id", ""),
    email: Storage.get("deepsleep.email", ""),
    roles: Storage.get("deepsleep.roles", "").split(",").filter(Boolean),
  },

  account: {
    id: Number(Storage.get("deepsleep.account_id", "0") || 0) || 0,
    aws_account_id: Storage.get("deepsleep.aws_account_id", ""),
    name: Storage.get("deepsleep.account_name", "—"),
  },

  discovery: {
    lastQuery: null,
    resources: [],
    selectedKeys: new Set(),
    onlyRegistered: false,
    regionsCsv: "eu-west-1,eu-central-1,us-east-1",
    resourceTypes: ["EKS_CLUSTER", "RDS_INSTANCE"],
  },

  active: {
    rowsByKey: new Map(),
    lastPollAt: null,
    plans: { EKS_CLUSTER: "dev", RDS_INSTANCE: "rds_dev" },
  },

  policies: {
    list: [],
    selectedId: null,
    editor: null,
    loading: false,
  },
};

const listeners = new Set();

function getState() { return state; }

function setState(patch) {
  deepMerge(state, patch);
  listeners.forEach((fn) => fn(state));
}

function subscribe(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

function deepMerge(target, patch) {
  for (const [k, v] of Object.entries(patch)) {
    if (v && typeof v === "object" && !Array.isArray(v) && !(v instanceof Set) && !(v instanceof Map)) {
      if (!target[k] || typeof target[k] !== "object") target[k] = {};
      deepMerge(target[k], v);
    } else {
      target[k] = v;
    }
  }
}

export const Store = { getState, setState, subscribe };
EOF

# -------------------- JS: API --------------------
cat > "$ROOT/js/api/client.js" <<'EOF'
import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";

const defaults = {
  baseUrl: Storage.get("deepsleep.baseUrl", ""),
};

function setBaseUrl(url) {
  defaults.baseUrl = (url || "").replace(/\/+$/, "");
  Storage.set("deepsleep.baseUrl", defaults.baseUrl);
}

function getBaseUrl() { return defaults.baseUrl; }

function authHeaders() {
  const token = Store.getState().auth?.token;
  return token ? { Authorization: `Bearer ${token}` } : {};
}

export async function request(path, { method = "GET", query = null, body = null } = {}) {
  const baseUrl = getBaseUrl();
  if (!baseUrl) throw new Error("Missing API base URL. Go to Settings.");

  const url = new URL(baseUrl + path);
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

export const ApiClient = { setBaseUrl, getBaseUrl, request };
EOF

cat > "$ROOT/js/api/services.js" <<'EOF'
import { request } from "./client.js";

/* Auth */
export const login = (payload) => request("/auth/login", { method: "POST", body: payload });
export const refresh = (payload) => request("/auth/refresh", { method: "POST", body: payload });

/* Resources */
export const searchResources = (accountId, body) =>
  request(`/accounts/${accountId}/resources/search`, { method: "POST", body });

export const batchRegister = (accountId, body) =>
  request(`/accounts/${accountId}/resources/batch-register`, { method: "POST", body });

/* EKS states + orchestration */
export const listClusterStates = (accountId) =>
  request(`/accounts/${accountId}/cluster-states`);

export const sleepEKS = (accountId, clusterName, region, planName) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/sleep`, {
    method: "POST",
    query: { region, plan_name: planName || "dev" },
  });

export const wakeEKS = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/wake`, {
    method: "POST",
    query: { region },
  });

/* RDS states + orchestration */
export const listRdsStates = (accountId) =>
  request(`/accounts/${accountId}/rds-instance-states`);

export const sleepRDS = (accountId, dbInstanceId, region, planName) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/sleep`, {
    method: "POST",
    query: { region, plan_name: planName || "rds_dev" },
  });

export const wakeRDS = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/wake`, {
    method: "POST",
    query: { region },
  });

/* Time policies */
export const listPolicies = (accountId) =>
  request(`/accounts/${accountId}/time-policies`);

export const createPolicy = (accountId, body) =>
  request(`/accounts/${accountId}/time-policies`, { method: "POST", body });

export const updatePolicy = (accountId, policyId, body) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "PUT", body });

export const deletePolicy = (accountId, policyId) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "DELETE" });

export const runPolicyNow = (accountId, policyId, action) =>
  request(`/accounts/${accountId}/time-policies/${policyId}/run-now`, { method: "POST", body: { action } });
EOF

# -------------------- JS: components --------------------
cat > "$ROOT/js/components/Panel.js" <<'EOF'
import { escapeHtml as h } from "../utils/dom.js";

export function renderPanel({ title, sub, actionsHtml = "", bodyHtml = "" }) {
  return `
    <article class="ds-panel">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">${h(title)}</div>
          ${sub ? `<div class="ds-panel__sub">${h(sub)}</div>` : ""}
        </div>
        ${actionsHtml ? `<div class="ds-row">${actionsHtml}</div>` : ""}
      </div>
      ${bodyHtml}
    </article>
  `;
}
EOF

cat > "$ROOT/js/components/Badges.js" <<'EOF'
import { escapeHtml as h } from "../utils/dom.js";

export function renderBadge(text, variant = "") {
  const cls = variant ? `ds-badge ds-badge--${variant}` : "ds-badge";
  return `<span class="${cls}">${h(text)}</span>`;
}
EOF

cat > "$ROOT/js/components/Pills.js" <<'EOF'
import { escapeHtml as h } from "../utils/dom.js";

export function renderStatePill(state, lockedUntil) {
  const s = (state || "—").toUpperCase();
  if (lockedUntil) return `<span class="ds-pill ds-pill--locked">LOCKED</span>`;
  if (s === "RUNNING") return `<span class="ds-pill ds-pill--running">RUNNING</span>`;
  if (s === "SLEEPING") return `<span class="ds-pill ds-pill--sleeping">SLEEPING</span>`;
  return `<span class="ds-pill">${h(s)}</span>`;
}
EOF

cat > "$ROOT/js/components/Sidebar.js" <<'EOF'
export function renderSidebar() {
  return `
    <div class="ds-rail__brand">
      <div class="ds-brand__mark" aria-hidden="true">
        <svg width="20" height="20" viewBox="0 0 20 20" role="img" aria-label="Logo">
          <rect x="2" y="2" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"></rect>
          <path d="M6 10h8" stroke="currentColor" stroke-width="2"></path>
        </svg>
      </div>
      <div class="ds-brand__text">
        <div class="ds-brand__name">DeepSleep</div>
        <div class="ds-brand__tag">AWS FinOps • EKS/RDS</div>
      </div>
    </div>

    <nav class="ds-rail__nav">
      <a class="ds-navlink" href="#/discovery" data-route="discovery">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M2 7h14M2 11h14M4 3h10M4 15h10" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Discovery</span>
      </a>

      <a class="ds-navlink" href="#/active" data-route="active">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M4 14V4h10v10H4Z" fill="none" stroke="currentColor" stroke-width="1.7"/>
            <path d="M6 6h6M6 9h6M6 12h4" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Active Resources</span>
      </a>

      <a class="ds-navlink" href="#/policies" data-route="policies">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M3 4h12v10H3V4Z" fill="none" stroke="currentColor" stroke-width="1.7"/>
            <path d="M5 7h8M5 10h6" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Time Policies</span>
      </a>

      <a class="ds-navlink" href="#/settings" data-route="settings">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M9 11.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z" fill="none" stroke="currentColor" stroke-width="1.7"/>
            <path d="M3 9l1.6-.6.2-1.8L3.7 5.3 5.3 3.7l1.3 1.1 1.8-.2L9 3l.6 1.6 1.8.2 1.3-1.1 1.6 1.6-1.1 1.3.2 1.8L15 9l-1.6.6-.2 1.8 1.1 1.3-1.6 1.6-1.3-1.1-1.8.2L9 15l-.6-1.6-1.8-.2-1.3 1.1-1.6-1.6 1.1-1.3-.2-1.8L3 9Z" fill="none" stroke="currentColor" stroke-width="1.3"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Settings</span>
      </a>
    </nav>

    <div class="ds-rail__foot">
      <div class="ds-foot__hint">
        <span class="ds-hint__label">Polling:</span>
        <span class="ds-hint__value" id="ds-polling-indicator">10s</span>
      </div>
      <div class="ds-foot__hint">
        <span class="ds-hint__label">API:</span>
        <span class="ds-hint__value" id="ds-api-indicator">—</span>
      </div>
    </div>
  `;
}

export function setActiveNav(routeName) {
  document.querySelectorAll(".ds-navlink").forEach((a) => {
    const hit = a.dataset.route === routeName;
    if (hit) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  });
}
EOF

cat > "$ROOT/js/components/Header.js" <<'EOF'
export function renderHeader() {
  return `
    <div class="ds-topbar__left">
      <div class="ds-crumbs" id="ds-crumbs">DeepSleep</div>
    </div>

    <div class="ds-topbar__center">
      <label class="ds-search" aria-label="Recherche">
        <span class="ds-search__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <circle cx="8" cy="8" r="5" fill="none" stroke="currentColor" stroke-width="1.7"/>
            <path d="M12.5 12.5L16 16" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <input id="ds-global-search" class="ds-search__input" type="search" placeholder="Filter resources by name / region / type…" autocomplete="off" />
      </label>
    </div>

    <div class="ds-topbar__right">
      <button class="ds-userchip" id="ds-userchip" type="button" aria-haspopup="menu" aria-expanded="false">
        <span class="ds-userchip__dot" aria-hidden="true"></span>
        <span class="ds-userchip__text" id="ds-userchip-text">User</span>
        <span class="ds-userchip__caret" aria-hidden="true">
          <svg width="14" height="14" viewBox="0 0 14 14">
            <path d="M3 5l4 4 4-4" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
      </button>

      <div class="ds-dropdown" id="ds-user-dropdown" role="menu" aria-label="Profil" hidden>
        <div class="ds-dropdown__row">
          <div class="ds-dropdown__k">Name</div>
          <div class="ds-dropdown__v" id="ds-dd-name">—</div>
        </div>
        <div class="ds-dropdown__row">
          <div class="ds-dropdown__k">AWS Account</div>
          <div class="ds-dropdown__v" id="ds-dd-aws">—</div>
        </div>
        <div class="ds-dropdown__row">
          <div class="ds-dropdown__k">Business ID</div>
          <div class="ds-dropdown__v" id="ds-dd-biz">—</div>
        </div>
        <div class="ds-dropdown__sep" aria-hidden="true"></div>
        <div class="ds-dropdown__row">
          <button class="ds-btn ds-btn--ghost" id="ds-logout-btn" type="button">Logout</button>
        </div>
      </div>
    </div>
  `;
}
EOF

cat > "$ROOT/js/components/UserDropdown.js" <<'EOF'
import { qs } from "../utils/dom.js";
import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { Storage } from "../utils/storage.js";

export function bindUserDropdown() {
  const userchip = qs("#ds-userchip");
  const dropdown = qs("#ds-user-dropdown");
  const logout = qs("#ds-logout-btn");

  if (!userchip || !dropdown) return;

  userchip.addEventListener("click", () => {
    const expanded = userchip.getAttribute("aria-expanded") === "true";
    userchip.setAttribute("aria-expanded", expanded ? "false" : "true");
    dropdown.hidden = expanded;
  });

  document.addEventListener("click", (e) => {
    const inside = userchip.contains(e.target) || dropdown.contains(e.target);
    if (!inside) {
      userchip.setAttribute("aria-expanded", "false");
      dropdown.hidden = true;
    }
  });

  if (logout) {
    logout.addEventListener("click", () => {
      Storage.del("deepsleep.token");
      Store.setState({ auth: { token: "" } });
      toast("Session", "Token cleared. You can re-login in Settings.");
      userchip.setAttribute("aria-expanded", "false");
      dropdown.hidden = true;
      location.hash = "#/settings";
    });
  }
}

export function renderUserInfo() {
  const s = Store.getState();
  const email = s.auth.email || "User";

  const chipText = qs("#ds-userchip-text");
  const ddName = qs("#ds-dd-name");
  const ddAws = qs("#ds-dd-aws");
  const ddBiz = qs("#ds-dd-biz");

  if (chipText) chipText.textContent = email;
  if (ddName) ddName.textContent = email;
  if (ddAws) ddAws.textContent = s.account.aws_account_id || "—";
  if (ddBiz) ddBiz.textContent = s.auth.business_id || "—";
}
EOF

cat > "$ROOT/js/components/SearchBar.js" <<'EOF'
import { qs } from "../utils/dom.js";
import { Store } from "../store.js";

export function bindGlobalSearch(onSearch) {
  const input = qs("#ds-global-search");
  if (!input) return;

  input.addEventListener("input", () => {
    Store.setState({ ui: { search: input.value } });
    onSearch?.(input.value);
  });
}
EOF

cat > "$ROOT/js/components/ResourceRow.js" <<'EOF'
import { escapeHtml as h } from "../utils/dom.js";
import { renderStatePill } from "./Pills.js";
import { fmtTime } from "../utils/time.js";

export function renderInventoryRow(r, checked) {
  const labels = Object.entries(r.labels || {}).slice(0, 6).map(([k, v]) => `${k}:${v}`).join(", ");
  const reg = r.registered ? `<span class="ds-badge ds-badge--reg">REGISTERED</span>` : `<span class="ds-badge">NO</span>`;
  const observed = r.observed_state ? renderStatePill(r.observed_state) : `<span class="ds-mono-muted">—</span>`;
  const hay = `${r.resource_type} ${r.resource_name} ${r.region} ${labels}`;

  return `
    <tr data-key="${h(r.key)}" data-hay="${h(hay)}">
      <td><input type="checkbox" class="ds-inv-check" data-key="${h(r.key)}" ${checked ? "checked" : ""} /></td>
      <td>${h(r.resource_type)}</td>
      <td>${h(r.resource_name)}</td>
      <td>${h(r.region)}</td>
      <td>${reg}</td>
      <td>${observed}</td>
      <td class="ds-mono-muted">${h(labels || "—")}</td>
    </tr>
  `;
}

export function renderActiveRow(r) {
  const observed = renderStatePill(r.observed_state, r.locked_until);
  const desired = r.desired_state || "—";
  const last = r.last_action_at ? `${r.last_action || "—"} @ ${fmtTime(r.last_action_at)}` : "—";
  const updated = r.updated_at ? fmtTime(r.updated_at) : "—";
  const hay = `${r.resource_type} ${r.resource_name} ${r.region}`;

  const locked = !!(r.locked_until && new Date(r.locked_until).getTime() > Date.now());
  const sleepDisabled = locked || String(r.observed_state || "").toUpperCase() === "SLEEPING";
  const wakeDisabled = locked || String(r.observed_state || "").toUpperCase() === "RUNNING";

  return `
    <tr data-key="${h(r.key)}" data-hay="${h(hay)}">
      <td>${h(r.resource_type)}</td>
      <td>${h(r.resource_name)}</td>
      <td>${h(r.region)}</td>
      <td data-col="observed">${observed}</td>
      <td data-col="desired">${h(desired)}</td>
      <td data-col="last">${h(last)}</td>
      <td data-col="updated">${h(updated)}</td>
      <td>
        <div class="ds-row">
          <button class="ds-btn ds-btn--sleep" type="button" data-action="sleep" data-key="${h(r.key)}" ${sleepDisabled ? "disabled" : ""}>Sleep</button>
          <button class="ds-btn ds-btn--wake" type="button" data-action="wake" data-key="${h(r.key)}" ${wakeDisabled ? "disabled" : ""}>Wake</button>
        </div>
      </td>
    </tr>
  `;
}
EOF

cat > "$ROOT/js/components/TableFilters.js" <<'EOF'
import { qs, qsa } from "../utils/dom.js";

export function applyTableFilter(tableSelector, query) {
  const q = (query || "").trim().toLowerCase();
  const tbody = qs(`${tableSelector} tbody`);
  if (!tbody) return;

  qsa("tr", tbody).forEach((tr) => {
    const hay = (tr.getAttribute("data-hay") || "").toLowerCase();
    tr.style.display = (!q || hay.includes(q)) ? "" : "none";
  });
}
EOF

cat > "$ROOT/js/components/ActiveRowPatcher.js" <<'EOF'
import { qs } from "../utils/dom.js";
import { renderStatePill } from "./Pills.js";
import { fmtTime } from "../utils/time.js";
import { Store } from "../store.js";

function patchCell(tr, col, value, lockedUntil) {
  const td = tr.querySelector(`td[data-col="${col}"]`);
  if (!td) return;
  if (col === "observed") {
    td.innerHTML = renderStatePill(value, lockedUntil);
    return;
  }
  td.textContent = String(value ?? "—");
}

export function patchActiveRow(key, newRow) {
  const tr = qs(`tr[data-key="${key.replaceAll('"','\\"')}"]`);
  if (!tr) return;

  const old = Store.getState().active.rowsByKey.get(key) || {};
  const changed =
    old.observed_state !== newRow.observed_state ||
    old.desired_state !== newRow.desired_state ||
    String(old.locked_until || "") !== String(newRow.locked_until || "") ||
    String(old.updated_at || "") !== String(newRow.updated_at || "") ||
    String(old.last_action || "") !== String(newRow.last_action || "") ||
    String(old.last_action_at || "") !== String(newRow.last_action_at || "");

  if (!changed) return;

  Store.getState().active.rowsByKey.set(key, newRow);

  patchCell(tr, "observed", newRow.observed_state, newRow.locked_until);
  patchCell(tr, "desired", newRow.desired_state, null);

  const lastText = newRow.last_action_at
    ? `${newRow.last_action || "—"} @ ${fmtTime(newRow.last_action_at)}`
    : "—";
  patchCell(tr, "last", lastText, null);

  patchCell(tr, "updated", newRow.updated_at ? fmtTime(newRow.updated_at) : "—", null);
}
EOF

# -------------------- JS: pages --------------------
cat > "$ROOT/js/pages/InventoryPage.js" <<'EOF'
import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { applyTableFilter } from "../components/TableFilters.js";
import { renderInventoryRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

export async function InventoryPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Discovery / Inventory";

  page.innerHTML = renderPanel({
    title: "Inventory",
    sub: "Raw discovery via /resources/search. Select rows then Batch Register.",
    actionsHtml: `
      <span class="ds-badge ds-badge--muted">Hint: use global search <span class="ds-kbd">Ctrl</span>+<span class="ds-kbd">F</span> in table</span>
    `,
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;">
        <div class="ds-field">
          <div class="ds-label">Account ID</div>
          <input class="ds-input" id="ds-inv-account" inputmode="numeric" value="${s.account.id || ""}" placeholder="e.g. 1" />
        </div>
        <div class="ds-field">
          <div class="ds-label">Regions (CSV)</div>
          <input class="ds-input" id="ds-inv-regions" value="${s.discovery.regionsCsv}" placeholder="eu-west-1,us-east-1" />
        </div>
        <div class="ds-field">
          <div class="ds-label">Resource Types</div>
          <select class="ds-select" id="ds-inv-types" multiple size="2" aria-label="Resource types">
            <option value="EKS_CLUSTER" ${s.discovery.resourceTypes.includes("EKS_CLUSTER") ? "selected" : ""}>EKS_CLUSTER</option>
            <option value="RDS_INSTANCE" ${s.discovery.resourceTypes.includes("RDS_INSTANCE") ? "selected" : ""}>RDS_INSTANCE</option>
          </select>
        </div>
        <div class="ds-field" style="min-width:260px;">
          <div class="ds-label">Only Registered</div>
          <select class="ds-select" id="ds-inv-onlyreg">
            <option value="0" ${s.discovery.onlyRegistered ? "" : "selected"}>false</option>
            <option value="1" ${s.discovery.onlyRegistered ? "selected" : ""}>true</option>
          </select>
        </div>
        <div class="ds-row" style="margin-left:auto;">
          <button class="ds-btn" id="ds-inv-run" type="button">Run Search</button>
          <button class="ds-btn ds-btn--wake" id="ds-inv-batch-reg" type="button">Batch Register</button>
          <button class="ds-btn ds-btn--sleep" id="ds-inv-batch-unreg" type="button">Batch Unregister</button>
        </div>
      </div>

      <div class="ds-mono-muted" id="ds-inv-status">—</div>
      <div style="height:10px"></div>

      <div class="ds-tablewrap" data-table="discovery">
        <table class="ds-table" aria-label="Inventory table">
          <thead>
            <tr>
              <th style="width:42px;"><input type="checkbox" id="ds-inv-check-all" aria-label="Select all"/></th>
              <th>Type</th>
              <th>Name</th>
              <th>Region</th>
              <th>Registered</th>
              <th>Observed</th>
              <th>Labels</th>
            </tr>
          </thead>
          <tbody id="ds-inv-tbody"></tbody>
        </table>
      </div>
    `,
  });

  const invAccount = qs("#ds-inv-account");
  const invRegions = qs("#ds-inv-regions");
  const invTypes = qs("#ds-inv-types");
  const invOnlyReg = qs("#ds-inv-onlyreg");
  const btnRun = qs("#ds-inv-run");
  const btnReg = qs("#ds-inv-batch-reg");
  const btnUnreg = qs("#ds-inv-batch-unreg");
  const status = qs("#ds-inv-status");

  function readSearchPayload() {
    const accountId = Number(invAccount.value || 0);
    const regions = invRegions.value.split(",").map((x) => x.trim()).filter(Boolean);
    const types = Array.from(invTypes.selectedOptions).map((o) => o.value);
    const only_registered = invOnlyReg.value === "1";

    const payload = {
      resource_types: types.length ? types : ["EKS_CLUSTER", "RDS_INSTANCE"],
      regions: regions.length ? regions : null,
      selector_by_type: {},
      only_registered,
    };

    Storage.set("deepsleep.account_id", String(accountId || ""));
    Store.setState({
      account: { id: accountId },
      discovery: { regionsCsv: invRegions.value, onlyRegistered: only_registered, resourceTypes: payload.resource_types },
    });

    return { accountId, payload };
  }

  function renderInventoryRows() {
    const tbody = qs("#ds-inv-tbody");
    const { resources, selectedKeys } = Store.getState().discovery;

    tbody.innerHTML = resources.map((r) => renderInventoryRow(r, selectedKeys.has(r.key))).join("");

    qsa(".ds-inv-check", tbody).forEach((cb) => {
      cb.addEventListener("change", () => {
        const key = cb.dataset.key;
        const set = Store.getState().discovery.selectedKeys;
        if (cb.checked) set.add(key); else set.delete(key);
      });
    });

    const checkAll = qs("#ds-inv-check-all");
    checkAll.checked = false;
    checkAll.addEventListener("change", () => {
      const set = Store.getState().discovery.selectedKeys;
      set.clear();
      qsa(".ds-inv-check", tbody).forEach((cb) => {
        cb.checked = checkAll.checked;
        if (checkAll.checked) set.add(cb.dataset.key);
      });
    });
  }

  async function runSearch() {
    const { accountId, payload } = readSearchPayload();
    if (!accountId) return toast("Inventory", "Missing account_id.");
    status.textContent = "Searching…";

    try {
      const resp = await Api.searchResources(accountId, payload);
      const resources = (resp && resp.resources) ? resp.resources : [];

      const norm = resources.map((r) => ({
        key: `${r.resource_type}|${r.resource_name}|${r.region}`,
        resource_type: r.resource_type,
        resource_name: r.resource_name,
        region: r.region,
        labels: r.labels || {},
        registered: !!r.registered,
        observed_state: r.observed_state || null,
        desired_state: r.desired_state || null,
      }));

      Store.setState({ discovery: { resources: norm, selectedKeys: new Set(), lastQuery: payload } });
      renderInventoryRows();
      status.textContent = `OK — ${norm.length} resource(s).`;

      applyTableFilter('[data-table="discovery"]', Store.getState().ui.search);
    } catch (e) {
      status.textContent = "Error.";
      toast("Inventory", e.message || "Search failed");
    }
  }

  async function doBatch(mode) {
    const { accountId, payload } = readSearchPayload();
    const selected = Array.from(Store.getState().discovery.selectedKeys);

    if (!accountId) return toast("Batch", "Missing account_id.");
    if (!selected.length) return toast("Batch", "Select at least one row.");

    const ok = await confirmModal({
      title: `Batch ${mode}`,
      body: `<div class="ds-mono-muted">Selected: ${selected.length}. This will call /resources/batch-register.</div>`,
      confirmText: `Run ${mode}`,
      cancelText: "Cancel",
    });
    if (!ok) return;

    const byType = new Map();
    for (const key of selected) {
      const [t, name] = key.split("|");
      if (!byType.has(t)) byType.set(t, []);
      byType.get(t).push(name);
    }

    const selector_by_type = {};
    for (const [t, names] of byType.entries()) {
      selector_by_type[t] = {
        include_names: names,
        exclude_names: [],
        include_labels: {},
        exclude_labels: {},
        include_namespaces: null,
        exclude_namespaces: [],
      };
    }

    const body = {
      search: {
        resource_types: payload.resource_types,
        regions: payload.regions,
        selector_by_type,
        only_registered: payload.only_registered,
      },
      mode,
      dry_run: false,
    };

    status.textContent = `Batch ${mode}…`;
    try {
      const resp = await Api.batchRegister(accountId, body);
      const results = resp?.results || [];
      const counts = results.reduce((acc, r) => {
        acc[r.action] = (acc[r.action] || 0) + 1;
        return acc;
      }, {});
      toast("Batch", `OK — ${Object.entries(counts).map(([k,v]) => `${k}:${v}`).join(" ") || "done"}`);
      await runSearch();
    } catch (e) {
      status.textContent = "Batch error.";
      toast("Batch", e.message || "Batch failed");
    }
  }

  btnRun.addEventListener("click", runSearch);
  btnReg.addEventListener("click", () => doBatch("REGISTER"));
  btnUnreg.addEventListener("click", () => doBatch("UNREGISTER"));

  // Auto-run if we already have a token + account id
  if (s.auth.token && s.account.id) runSearch();
}
EOF

cat > "$ROOT/js/pages/ActiveResourcesPage.js" <<'EOF'
import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { applyTableFilter } from "../components/TableFilters.js";
import { renderActiveRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

export async function ActiveResourcesPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  if (!s.account.id) {
    toast("Setup", "Missing account_id. Configure it in Settings.");
    location.hash = "#/settings";
    return;
  }

  qs("#ds-crumbs").textContent = "Active Resources / Control Panel";

  page.innerHTML = renderPanel({
    title: "Control Panel",
    sub: "Registered resources with one-click Sleep/Wake. Polls every 10 seconds and patches only changed rows.",
    actionsHtml: `
      <span class="ds-badge ds-badge--reg">Registered</span>
      <span class="ds-badge">Wake: blue</span>
      <span class="ds-badge">Sleep: brick</span>
    `,
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;">
        <div class="ds-field">
          <div class="ds-label">Account ID</div>
          <input class="ds-input" id="ds-cp-account" inputmode="numeric" value="${s.account.id}" />
        </div>

        <div class="ds-field">
          <div class="ds-label">EKS plan_name</div>
          <input class="ds-input" id="ds-cp-plan-eks" value="${s.active.plans.EKS_CLUSTER || "dev"}" />
        </div>

        <div class="ds-field">
          <div class="ds-label">RDS plan_name</div>
          <input class="ds-input" id="ds-cp-plan-rds" value="${s.active.plans.RDS_INSTANCE || "rds_dev"}" />
        </div>

        <div class="ds-row" style="margin-left:auto;">
          <button class="ds-btn" id="ds-cp-refresh" type="button">Refresh Now</button>
        </div>
      </div>

      <div class="ds-mono-muted" id="ds-cp-status">—</div>
      <div style="height:10px"></div>

      <div class="ds-tablewrap" data-table="active">
        <table class="ds-table" aria-label="Active resources table">
          <thead>
            <tr>
              <th>Type</th>
              <th>Name</th>
              <th>Region</th>
              <th>Observed</th>
              <th>Desired</th>
              <th>Last</th>
              <th>Updated</th>
              <th style="width:220px;">Toggle</th>
            </tr>
          </thead>
          <tbody id="ds-cp-tbody"></tbody>
        </table>
      </div>
    `,
  });

  const status = qs("#ds-cp-status");
  const inpAccount = qs("#ds-cp-account");
  const inpPlanEks = qs("#ds-cp-plan-eks");
  const inpPlanRds = qs("#ds-cp-plan-rds");
  const btnRefresh = qs("#ds-cp-refresh");

  function persistControlInputs() {
    const accountId = Number(inpAccount.value || 0);
    const eksPlan = inpPlanEks.value.trim() || "dev";
    const rdsPlan = inpPlanRds.value.trim() || "rds_dev";

    Storage.set("deepsleep.account_id", String(accountId || ""));
    Store.setState({ account: { id: accountId }, active: { plans: { EKS_CLUSTER: eksPlan, RDS_INSTANCE: rdsPlan } } });
  }

  async function loadActiveInitial() {
    persistControlInputs();
    const accountId = Store.getState().account.id;
    if (!accountId) return toast("Control Panel", "Missing account_id.");

    status.textContent = "Loading…";
    try {
      const [eks, rds] = await Promise.all([
        Api.listClusterStates(accountId).catch(() => ({ clusters: [] })),
        Api.listRdsStates(accountId).catch(() => ({ instances: [] })),
      ]);

      const map = new Map();
      for (const c of (eks.clusters || [])) {
        const key = `EKS_CLUSTER|${c.cluster_name}|${c.region}`;
        map.set(key, {
          key,
          resource_type: "EKS_CLUSTER",
          resource_name: c.cluster_name,
          region: c.region,
          observed_state: c.observed_state,
          desired_state: c.desired_state,
          last_action: c.last_action,
          last_action_at: c.last_action_at,
          locked_until: c.locked_until,
          updated_at: c.updated_at,
        });
      }
      for (const r of (rds.instances || [])) {
        const key = `RDS_INSTANCE|${r.db_instance_id}|${r.region}`;
        map.set(key, {
          key,
          resource_type: "RDS_INSTANCE",
          resource_name: r.db_instance_id,
          region: r.region,
          observed_state: r.observed_state,
          desired_state: r.desired_state,
          last_action: r.last_action,
          last_action_at: r.last_action_at,
          locked_until: r.locked_until,
          updated_at: r.updated_at,
        });
      }

      Store.getState().active.rowsByKey = map;
      renderActiveTable(map);
      status.textContent = `OK — ${map.size} registered resource(s).`;

      applyTableFilter('[data-table="active"]', Store.getState().ui.search);
    } catch (e) {
      status.textContent = "Error.";
      toast("Control Panel", e.message || "Load failed");
    }
  }

  function renderActiveTable(map) {
    const tbody = qs("#ds-cp-tbody");
    const rows = Array.from(map.values()).sort((a, b) => a.resource_type.localeCompare(b.resource_type) || a.resource_name.localeCompare(b.resource_name));
    tbody.innerHTML = rows.map((r) => renderActiveRow(r)).join("");
    bindActiveRowActions();
  }

  function bindActiveRowActions() {
    qsa('[data-action="sleep"], [data-action="wake"]').forEach((btn) => {
      btn.addEventListener("click", async () => {
        persistControlInputs();
        const accountId = Store.getState().account.id;
        const key = btn.dataset.key;
        const row = Store.getState().active.rowsByKey.get(key);
        if (!row) return;

        const action = btn.dataset.action;

        const ok = await confirmModal({
          title: `${action.toUpperCase()} ${row.resource_type}`,
          body: `<div class="ds-mono-muted">${row.resource_name} • ${row.region}</div>`,
          confirmText: action === "sleep" ? "Sleep" : "Wake",
          cancelText: "Cancel",
        });
        if (!ok) return;

        try {
          btn.disabled = true;

          if (row.resource_type === "EKS_CLUSTER") {
            if (action === "sleep") await Api.sleepEKS(accountId, row.resource_name, row.region, Store.getState().active.plans.EKS_CLUSTER);
            else await Api.wakeEKS(accountId, row.resource_name, row.region);
          } else if (row.resource_type === "RDS_INSTANCE") {
            if (action === "sleep") await Api.sleepRDS(accountId, row.resource_name, row.region, Store.getState().active.plans.RDS_INSTANCE);
            else await Api.wakeRDS(accountId, row.resource_name, row.region);
          }

          toast("Orchestrator", "Run submitted. Polling will update state.");
        } catch (e) {
          toast("Orchestrator", e.message || "Action failed");
        } finally {
          btn.disabled = false;
        }
      });
    });
  }

  btnRefresh.addEventListener("click", loadActiveInitial);
  inpAccount.addEventListener("change", loadActiveInitial);

  await loadActiveInitial();
}
EOF

cat > "$ROOT/js/pages/TimePoliciesPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";

export async function TimePoliciesPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  if (!s.account.id) {
    toast("Setup", "Missing account_id. Configure it in Settings.");
    location.hash = "#/settings";
    return;
  }

  qs("#ds-crumbs").textContent = "Time Policies / Editor";

  page.innerHTML = renderPanel({
    title: "Time Policies",
    sub: "Create structured weekly windows (TimeWindowDTO) and attach SearchRequest + plan_name_by_type.",
    actionsHtml: `
      <button class="ds-btn" id="ds-pol-refresh" type="button">Refresh</button>
      <button class="ds-btn ds-btn--wake" id="ds-pol-new" type="button">New Policy</button>
    `,
    bodyHtml: `
      <div class="ds-grid-2" style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
        <div>
          <div class="ds-mono-muted" id="ds-pol-status">—</div>
          <div style="height:10px"></div>
          <div class="ds-tablewrap">
            <table class="ds-table" aria-label="Policies list">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>Enabled</th>
                  <th>Timezone</th>
                  <th>Next</th>
                  <th style="width:180px;">Actions</th>
                </tr>
              </thead>
              <tbody id="ds-pol-tbody"></tbody>
            </table>
          </div>
        </div>

        <div>
          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">Policy Editor</div>
                <div class="ds-panel__sub">JSON editor (safe baseline). You can paste TimePolicyCreateRequest / UpdateRequest fields.</div>
              </div>
            </div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Selected policy ID</div>
              <input class="ds-input" id="ds-pol-selected-id" value="${s.policies.selectedId ?? ""}" placeholder="(none)" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Payload (Create or Update)</div>
              <textarea class="ds-textarea" id="ds-pol-json" spellcheck="false" placeholder='{
  "name": "Night Sleep",
  "enabled": true,
  "timezone": "UTC",
  "search": { "resource_types": ["EKS_CLUSTER","RDS_INSTANCE"], "regions": null, "selector_by_type": {}, "only_registered": true },
  "windows": [ { "days": ["MON","TUE","WED","THU","FRI"], "start": "21:00", "end": "07:00" } ],
  "plan_name_by_type": { "EKS_CLUSTER": "dev", "RDS_INSTANCE": "rds_dev" }
}'></textarea>
            </div>

            <div style="height:12px"></div>

            <div class="ds-row">
              <button class="ds-btn" id="ds-pol-create" type="button">Create</button>
              <button class="ds-btn" id="ds-pol-update" type="button">Update</button>
              <button class="ds-btn ds-btn--danger" id="ds-pol-delete" type="button">Delete</button>
              <span style="flex:1"></span>
              <button class="ds-btn ds-btn--sleep" id="ds-pol-run-sleep" type="button">Run Now: SLEEP</button>
              <button class="ds-btn ds-btn--wake" id="ds-pol-run-wake" type="button">Run Now: WAKE</button>
            </div>
          </div>
        </div>
      </div>
    `,
  });

  const status = qs("#ds-pol-status");
  const tbody = qs("#ds-pol-tbody");
  const btnRefresh = qs("#ds-pol-refresh");
  const btnNew = qs("#ds-pol-new");
  const inpSel = qs("#ds-pol-selected-id");
  const txt = qs("#ds-pol-json");
  const btnCreate = qs("#ds-pol-create");
  const btnUpdate = qs("#ds-pol-update");
  const btnDelete = qs("#ds-pol-delete");
  const btnRunSleep = qs("#ds-pol-run-sleep");
  const btnRunWake = qs("#ds-pol-run-wake");

  async function loadList() {
    const accountId = Store.getState().account.id;
    status.textContent = "Loading…";
    try {
      const resp = await Api.listPolicies(accountId);
      const list = resp?.policies || [];
      Store.setState({ policies: { list } });
      renderList(list);
      status.textContent = `OK — ${list.length} policy(s).`;
    } catch (e) {
      status.textContent = "Error.";
      toast("Time Policies", e.message || "Load failed");
    }
  }

  function renderList(list) {
    tbody.innerHTML = list.map((p) => {
      const next = p.next_transition_at ? fmtTime(p.next_transition_at) : "—";
      return `
        <tr>
          <td>${p.id}</td>
          <td>${p.name}</td>
          <td>${p.enabled ? `<span class="ds-badge ds-badge--reg">true</span>` : `<span class="ds-badge">false</span>`}</td>
          <td>${p.timezone || "UTC"}</td>
          <td class="ds-mono-muted">${next}</td>
          <td>
            <div class="ds-row">
              <button class="ds-btn ds-btn--ghost" type="button" data-pol="select" data-id="${p.id}">Select</button>
              <button class="ds-btn ds-btn--ghost" type="button" data-pol="copy" data-id="${p.id}">Copy JSON</button>
            </div>
          </td>
        </tr>
      `;
    }).join("");

    qsa('[data-pol="select"]').forEach((b) => {
      b.addEventListener("click", () => {
        const id = Number(b.dataset.id);
        Store.setState({ policies: { selectedId: id } });
        inpSel.value = String(id);
        toast("Editor", `Selected policy ${id}.`);
      });
    });

    qsa('[data-pol="copy"]').forEach((b) => {
      b.addEventListener("click", () => {
        const id = Number(b.dataset.id);
        const p = Store.getState().policies.list.find((x) => x.id === id);
        if (!p) return;
        const payload = {
          name: p.name,
          enabled: p.enabled,
          timezone: p.timezone,
          search: p.search,
          windows: p.windows,
          plan_name_by_type: p.plan_name_by_type || {},
        };
        txt.value = JSON.stringify(payload, null, 2);
        toast("Editor", "JSON copied into editor.");
      });
    });
  }

  function readJson() {
    const raw = txt.value.trim();
    if (!raw) throw new Error("Editor is empty.");
    return JSON.parse(raw);
  }

  btnRefresh.addEventListener("click", loadList);

  btnNew.addEventListener("click", () => {
    txt.value = `{
  "name": "Night Sleep",
  "enabled": true,
  "timezone": "UTC",
  "search": {
    "resource_types": ["EKS_CLUSTER", "RDS_INSTANCE"],
    "regions": null,
    "selector_by_type": {},
    "only_registered": true
  },
  "windows": [
    { "days": ["MON","TUE","WED","THU","FRI"], "start": "21:00", "end": "07:00" }
  ],
  "plan_name_by_type": { "EKS_CLUSTER": "dev", "RDS_INSTANCE": "rds_dev" }
}`;
    toast("Editor", "Template inserted.");
  });

  btnCreate.addEventListener("click", async () => {
    try {
      const accountId = Store.getState().account.id;
      const body = readJson();
      await Api.createPolicy(accountId, body);
      toast("Time Policies", "Created.");
      await loadList();
    } catch (e) {
      toast("Time Policies", e.message || "Create failed");
    }
  });

  btnUpdate.addEventListener("click", async () => {
    try {
      const accountId = Store.getState().account.id;
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");
      const body = readJson();
      await Api.updatePolicy(accountId, id, body);
      toast("Time Policies", "Updated.");
      await loadList();
    } catch (e) {
      toast("Time Policies", e.message || "Update failed");
    }
  });

  btnDelete.addEventListener("click", async () => {
    try {
      const accountId = Store.getState().account.id;
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");

      const ok = await confirmModal({
        title: "Delete Policy",
        body: `<div class="ds-mono-muted">Policy ${id} will be deleted (executions too).</div>`,
        confirmText: "Delete",
        cancelText: "Cancel",
      });
      if (!ok) return;

      await Api.deletePolicy(accountId, id);
      toast("Time Policies", "Deleted.");
      inpSel.value = "";
      Store.setState({ policies: { selectedId: null } });
      await loadList();
    } catch (e) {
      toast("Time Policies", e.message || "Delete failed");
    }
  });

  btnRunSleep.addEventListener("click", async () => {
    try {
      const accountId = Store.getState().account.id;
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");
      await Api.runPolicyNow(accountId, id, "SLEEP");
      toast("Time Policies", "Run-now SLEEP submitted.");
    } catch (e) {
      toast("Time Policies", e.message || "Run-now failed");
    }
  });

  btnRunWake.addEventListener("click", async () => {
    try {
      const accountId = Store.getState().account.id;
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");
      await Api.runPolicyNow(accountId, id, "WAKE");
      toast("Time Policies", "Run-now WAKE submitted.");
    } catch (e) {
      toast("Time Policies", e.message || "Run-now failed");
    }
  });

  await loadList();
}
EOF

cat > "$ROOT/js/pages/SettingsPage.js" <<'EOF'
import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";
import { toast } from "../utils/toast.js";
import { qs } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { ApiClient } from "../api/client.js";
import * as Api from "../api/services.js";
import { renderUserInfo } from "../components/UserDropdown.js";

export async function SettingsPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Settings";

  page.innerHTML = renderPanel({
    title: "Connection & Auth",
    sub: "No framework. Vanilla state + manual render. Store minimal config in localStorage.",
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;">
        <span class="ds-badge">Neo-90s Matte</span>
        <span class="ds-badge ds-badge--muted">Hard borders • Hard shadows • Monospace</span>
      </div>

      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
        <div>
          <div class="ds-field">
            <div class="ds-label">API Base URL</div>
            <input class="ds-input" id="ds-set-baseurl" value="${ApiClient.getBaseUrl() || ""}" placeholder="e.g. http://localhost:8000" />
          </div>

          <div style="height:10px"></div>

          <div class="ds-field">
            <div class="ds-label">Account ID (internal)</div>
            <input class="ds-input" id="ds-set-accountid" inputmode="numeric" value="${s.account.id || ""}" placeholder="e.g. 1" />
          </div>

          <div style="height:10px"></div>

          <div class="ds-field">
            <div class="ds-label">AWS Account ID (display)</div>
            <input class="ds-input" id="ds-set-aws" value="${s.account.aws_account_id || ""}" placeholder="e.g. 123456789012" />
          </div>

          <div style="height:10px"></div>

          <div class="ds-field">
            <div class="ds-label">Business ID</div>
            <input class="ds-input" id="ds-set-biz" value="${s.auth.business_id || ""}" placeholder="UUID / int" />
          </div>

          <div style="height:12px"></div>

          <div class="ds-row">
            <button class="ds-btn" id="ds-set-save" type="button">Save Settings</button>
          </div>
        </div>

        <div>
          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">Login</div>
                <div class="ds-panel__sub">Calls /auth/login (business_user) and stores token.</div>
              </div>
            </div>

            <div class="ds-field">
              <div class="ds-label">Email</div>
              <input class="ds-input" id="ds-login-email" value="${s.auth.email || ""}" placeholder="you@company.com" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field">
              <div class="ds-label">Password</div>
              <input class="ds-input" id="ds-login-pass" type="password" value="" placeholder="••••••••" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field">
              <div class="ds-label">Business ID</div>
              <input class="ds-input" id="ds-login-biz" value="${s.auth.business_id || ""}" placeholder="business_id" />
            </div>

            <div style="height:12px"></div>

            <div class="ds-row">
              <button class="ds-btn ds-btn--wake" id="ds-login-btn" type="button">Login</button>
              <button class="ds-btn" id="ds-token-clear" type="button">Clear Token</button>
            </div>

            <div style="height:12px"></div>
            <div class="ds-mono-muted">Token: <span id="ds-token-preview">${(s.auth.token || "").slice(0, 28) || "—"}</span></div>
          </div>
        </div>
      </div>
    `,
  });

  const baseUrl = qs("#ds-set-baseurl");
  const accountId = qs("#ds-set-accountid");
  const aws = qs("#ds-set-aws");
  const biz = qs("#ds-set-biz");
  const btnSave = qs("#ds-set-save");

  const email = qs("#ds-login-email");
  const pass = qs("#ds-login-pass");
  const biz2 = qs("#ds-login-biz");
  const btnLogin = qs("#ds-login-btn");
  const btnClear = qs("#ds-token-clear");
  const tokenPreview = qs("#ds-token-preview");

  btnSave.addEventListener("click", () => {
    ApiClient.setBaseUrl(baseUrl.value.trim());
    Storage.set("deepsleep.account_id", String(Number(accountId.value || 0) || ""));
    Storage.set("deepsleep.aws_account_id", aws.value.trim());
    Storage.set("deepsleep.business_id", biz.value.trim());

    Store.setState({
      account: { id: Number(accountId.value || 0), aws_account_id: aws.value.trim() },
      auth: { business_id: biz.value.trim() },
    });

    // update header chips
    renderUserInfo();
    const api = qs("#ds-api-indicator");
    if (api) api.textContent = ApiClient.getBaseUrl() || "—";

    toast("Settings", "Saved.");
  });

  btnLogin.addEventListener("click", async () => {
    try {
      ApiClient.setBaseUrl(baseUrl.value.trim());

      const payload = { email: email.value.trim(), password: pass.value, business_id: biz2.value.trim() };
      if (!payload.email || !payload.password || !payload.business_id) throw new Error("Missing email/password/business_id.");

      const resp = await Api.login(payload);
      const token = resp?.token;
      if (!token) throw new Error("No token returned.");

      Storage.set("deepsleep.token", token);
      Storage.set("deepsleep.email", payload.email);
      Storage.set("deepsleep.business_id", payload.business_id);

      Store.setState({ auth: { token, email: payload.email, business_id: payload.business_id } });
      tokenPreview.textContent = token.slice(0, 28);
      renderUserInfo();
      toast("Auth", "Login OK.");

      location.hash = "#/discovery";
    } catch (e) {
      toast("Auth", e.message || "Login failed");
    }
  });

  btnClear.addEventListener("click", () => {
    Storage.del("deepsleep.token");
    Store.setState({ auth: { token: "" } });
    tokenPreview.textContent = "—";
    renderUserInfo();
    toast("Auth", "Token cleared.");
  });
}
EOF

# -------------------- JS: app entry + polling wiring --------------------
cat > "$ROOT/app.js" <<'EOF'
import { Store } from "./js/store.js";
import { ApiClient } from "./js/api/client.js";
import { createRouter } from "./js/utils/router.js";
import { createPoller } from "./js/utils/poller.js";
import { qs } from "./js/utils/dom.js";
import { toast } from "./js/utils/toast.js";

import { renderSidebar, setActiveNav } from "./js/components/Sidebar.js";
import { renderHeader } from "./js/components/Header.js";
import { bindUserDropdown, renderUserInfo } from "./js/components/UserDropdown.js";
import { bindGlobalSearch } from "./js/components/SearchBar.js";
import { applyTableFilter } from "./js/components/TableFilters.js";
import { patchActiveRow } from "./js/components/ActiveRowPatcher.js";

import { InventoryPage } from "./js/pages/InventoryPage.js";
import { ActiveResourcesPage } from "./js/pages/ActiveResourcesPage.js";
import { TimePoliciesPage } from "./js/pages/TimePoliciesPage.js";
import { SettingsPage } from "./js/pages/SettingsPage.js";

import * as Api from "./js/api/services.js";

/* ---------- Bootstrapping shell ---------- */
(function bootstrapShell(){
  // sidebar
  const rail = qs("#ds-rail");
  if (rail) rail.innerHTML = renderSidebar();

  // header
  const topbar = qs("#ds-topbar");
  if (topbar) topbar.innerHTML = renderHeader();

  // bind header behaviors
  bindUserDropdown();
  renderUserInfo();

  bindGlobalSearch((q) => {
    const route = Store.getState().route.name;
    if (route === "discovery") applyTableFilter('[data-table="discovery"]', q);
    if (route === "active") applyTableFilter('[data-table="active"]', q);
  });

  // API indicator
  ApiClient.setBaseUrl(localStorage.getItem("deepsleep.baseUrl") || "");
  const apiIndicator = qs("#ds-api-indicator");
  if (apiIndicator) apiIndicator.textContent = ApiClient.getBaseUrl() || "—";
})();

/* ---------- Router ---------- */
const router = createRouter();

router.register("discovery", async () => InventoryPage());
router.register("active", async () => ActiveResourcesPage());
router.register("policies", async () => TimePoliciesPage());
router.register("settings", async () => SettingsPage());

router.start((route) => {
  Store.setState({ route });

  setActiveNav(route.name);
  router.render(route);

  // keep search input in sync (do not change behavior, just reflect state)
  const input = qs("#ds-global-search");
  if (input) input.value = Store.getState().ui.search || "";
});

/* ---------- Polling (10s) ----------
   Requirement: fetch /accounts/{id}/cluster-states and update only concerned rows.
   (We also patch RDS states for consistency, same as previous SPA behavior.)
*/
const poller = createPoller({
  intervalMs: 10_000,
  guard: () => {
    const s = Store.getState();
    return !!(s.account.id && s.auth.token && s.route.name === "active");
  },
  tick: async () => {
    const s = Store.getState();
    const accountId = s.account.id;

    try {
      const eks = await Api.listClusterStates(accountId);
      const clusters = eks?.clusters || [];
      for (const c of clusters) {
        const key = `EKS_CLUSTER|${c.cluster_name}|${c.region}`;
        patchActiveRow(key, {
          key,
          resource_type: "EKS_CLUSTER",
          resource_name: c.cluster_name,
          region: c.region,
          observed_state: c.observed_state,
          desired_state: c.desired_state,
          last_action: c.last_action,
          last_action_at: c.last_action_at,
          locked_until: c.locked_until,
          updated_at: c.updated_at,
        });
      }

      const rds = await Api.listRdsStates(accountId);
      const instances = rds?.instances || [];
      for (const r of instances) {
        const key = `RDS_INSTANCE|${r.db_instance_id}|${r.region}`;
        patchActiveRow(key, {
          key,
          resource_type: "RDS_INSTANCE",
          resource_name: r.db_instance_id,
          region: r.region,
          observed_state: r.observed_state,
          desired_state: r.desired_state,
          last_action: r.last_action,
          last_action_at: r.last_action_at,
          locked_until: r.locked_until,
          updated_at: r.updated_at,
        });
      }

      Store.setState({ active: { lastPollAt: new Date().toISOString() } });
    } catch (e) {
      toast("Polling", e.message || "Poll failed");
    }
  },
});

poller.start();
EOF

# Helpful note
cat > "$ROOT/README.refactor.txt" <<'EOF'
DeepSleep Vanilla SPA Refactor (no behavior changes)

Entry:
- index.html includes CSS and app.js (module)
- app.js renders Sidebar+Header into placeholders and routes pages.

Structure:
- css/main.css variables+reset+shared atoms
- css/sidebar.css, css/header.css, css/inventory.css module CSS

- js/store.js Pub/Sub-like Store (getState/setState/subscribe)
- js/api/client.js base URL + auth + request()
- js/api/services.js typed endpoints

- js/components/* pure render/bind helpers
- js/pages/* per-route page logic
- js/utils/* dom/time/storage/toast/router/poller

Run:
- Serve with any static server (e.g. python -m http.server) and set API Base URL in Settings.
EOF

echo "OK: generated refactored file tree under: $ROOT"
echo "Open index.html via a static server and ensure your API Base URL is configured in Settings."
