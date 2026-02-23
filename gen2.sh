#!/usr/bin/env bash
set -euo pipefail

# DeepSleep SPA refactor patch:
# - Move login to /login (landing + on logout)
# - Settings => Sleep Plans editor (GET/PUT /accounts/{id}/config), no JSON editing
# - Time Policies => UI editor (no JSON)
# - Remove Base URL + Account ID + Business ID inputs from UI (still stored internally; we derive account_id from JWT payload when possible)
# - Keep behavior intact for existing endpoints; only UI/org changes

ROOT="${1:-.}"

# ---------------------------
# 1) API client: same-origin (no Base URL in UI)
# ---------------------------
cat > "$ROOT/js/api/client.js" <<'EOF'
import { Store } from "../store.js";

function authHeaders() {
  const token = Store.getState().auth?.token;
  return token ? { Authorization: `Bearer ${token}` } : {};
}

/**
 * Same-origin client:
 * - Uses relative paths: "/auth/login", "/accounts/.."
 * - No user-editable base URL (internal)
 */
export async function request(path, { method = "GET", query = null, body = null } = {}) {
  const url = new URL(path, window.location.origin);
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
EOF

# ---------------------------
# 2) API services: add SleepPlans config endpoints
# ---------------------------
cat > "$ROOT/js/api/services.js" <<'EOF'
import { request } from "./client.js";

/* Auth */
export const login = (payload) => request("/auth/login", { method: "POST", body: payload });
export const refresh = (payload) => request("/auth/refresh", { method: "POST", body: payload });

/* Account Config (Sleep Plans) */
export const getAccountConfig = (accountId) =>
  request(`/accounts/${accountId}/config`);

export const putAccountConfig = (accountId, body) =>
  request(`/accounts/${accountId}/config`, { method: "PUT", body });

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

# ---------------------------
# 3) Store: stop exposing internal config in Settings UI; add sleepPlans cache
# ---------------------------
cat > "$ROOT/js/store.js" <<'EOF'
import { Storage } from "./utils/storage.js";

const state = {
  route: { name: "login", params: {} },

  ui: { search: "" },

  auth: {
    token: Storage.get("deepsleep.token", ""),
    business_id: Storage.get("deepsleep.business_id", ""),
    email: Storage.get("deepsleep.email", ""),
    roles: Storage.get("deepsleep.roles", "").split(",").filter(Boolean),
  },

  account: {
    // internal; we try to derive from JWT payload on login
    id: Number(Storage.get("deepsleep.account_id", "0") || 0) || 0,
    aws_account_id: Storage.get("deepsleep.aws_account_id", ""), // display only, currently unknown
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

  sleepPlans: {
    // loaded from /accounts/{id}/config
    config: { sleep_plans: {} },
    names: [], // convenience cache
    loading: false,
  },

  policies: {
    list: [],
    selectedId: null,
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

# ---------------------------
# 4) JWT helper (derive account_id/business_id/email when present)
# ---------------------------
mkdir -p "$ROOT/js/utils"
cat > "$ROOT/js/utils/jwt.js" <<'EOF'
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
EOF

# ---------------------------
# 5) Sidebar: rename Settings label => Sleep Plans (still route "settings")
# ---------------------------
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
        <span class="ds-navlink__label">Sleep Plans</span>
      </a>
    </nav>

    <div class="ds-rail__foot">
      <div class="ds-foot__hint">
        <span class="ds-hint__label">Polling:</span>
        <span class="ds-hint__value" id="ds-polling-indicator">10s</span>
      </div>
      <div class="ds-foot__hint">
        <span class="ds-hint__label">API:</span>
        <span class="ds-hint__value" id="ds-api-indicator">same-origin</span>
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

# ---------------------------
# 6) User dropdown logout => go /login
# ---------------------------
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
      // keep email/business_id for chip? product wants landing to login; keep minimal
      Store.setState({ auth: { token: "" } });
      toast("Session", "Logged out.");
      userchip.setAttribute("aria-expanded", "false");
      dropdown.hidden = true;
      location.hash = "#/login";
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

  // AWS account display: allowed to be empty for now
  if (ddAws) ddAws.textContent = s.account.aws_account_id || "—";
  if (ddBiz) ddBiz.textContent = s.auth.business_id || "—";
}
EOF

# ---------------------------
# 7) New page: /login
# ---------------------------
mkdir -p "$ROOT/js/pages"
cat > "$ROOT/js/pages/LoginPage.js" <<'EOF'
import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";
import { toast } from "../utils/toast.js";
import { qs } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";
import { decodeJwtPayload } from "../utils/jwt.js";
import { renderUserInfo } from "../components/UserDropdown.js";

export async function LoginPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  // crumbs
  const crumbs = qs("#ds-crumbs");
  if (crumbs) crumbs.textContent = "Login";

  page.innerHTML = renderPanel({
    title: "Login",
    sub: "Business user authentication. You will be redirected to Discovery after success.",
    bodyHtml: `
      <div style="display:grid;grid-template-columns:1fr;gap:12px;max-width:520px;">
        <div class="ds-field">
          <div class="ds-label">Email</div>
          <input class="ds-input" id="ds-login-email" value="${s.auth.email || ""}" placeholder="you@company.com" />
        </div>

        <div class="ds-field">
          <div class="ds-label">Password</div>
          <input class="ds-input" id="ds-login-pass" type="password" value="" placeholder="••••••••" />
        </div>

        <div class="ds-field">
          <div class="ds-label">Business ID</div>
          <input class="ds-input" id="ds-login-biz" value="${s.auth.business_id || ""}" placeholder="business_id" />
        </div>

        <div class="ds-row">
          <button class="ds-btn ds-btn--wake" id="ds-login-btn" type="button">Login</button>
          <button class="ds-btn" id="ds-login-clear" type="button">Clear Token</button>
        </div>

        <div class="ds-mono-muted">Token: <span id="ds-token-preview">${(s.auth.token || "").slice(0, 28) || "—"}</span></div>
      </div>
    `,
  });

  const email = qs("#ds-login-email");
  const pass = qs("#ds-login-pass");
  const biz = qs("#ds-login-biz");
  const btnLogin = qs("#ds-login-btn");
  const btnClear = qs("#ds-login-clear");
  const tokenPreview = qs("#ds-token-preview");

  btnLogin.addEventListener("click", async () => {
    try {
      const payload = { email: email.value.trim(), password: pass.value, business_id: biz.value.trim() };
      if (!payload.email || !payload.password || !payload.business_id) throw new Error("Missing email/password/business_id.");

      const resp = await Api.login(payload);
      const token = resp?.token;
      if (!token) throw new Error("No token returned.");

      // Save auth
      Storage.set("deepsleep.token", token);
      Storage.set("deepsleep.email", payload.email);
      Storage.set("deepsleep.business_id", payload.business_id);

      // Try to derive internal account_id / business_id from JWT payload if present
      const claims = decodeJwtPayload(token) || {};
      const inferredAccountId =
        Number(claims.account_id || claims.accountId || claims.aws_account_internal_id || 0) || 0;

      // Keep internal account id if inferred; else keep any existing stored value
      if (inferredAccountId) Storage.set("deepsleep.account_id", String(inferredAccountId));

      Store.setState({
        auth: { token, email: payload.email, business_id: payload.business_id },
        account: { id: inferredAccountId || Store.getState().account.id },
      });

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
    toast("Auth", "Token cleared.");
  });
}
EOF

# ---------------------------
# 8) Settings page becomes Sleep Plans page (form-based editor, GET/PUT config)
# ---------------------------
cat > "$ROOT/js/pages/SleepPlansPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";

function requireAuthAndAccount() {
  const s = Store.getState();
  if (!s.auth.token) {
    toast("Auth", "Please login.");
    location.hash = "#/login";
    return false;
  }
  if (!s.account.id) {
    toast("Setup", "Missing internal account_id. Backend should provide it in token claims.");
    // Keep user on page; but without account id we cannot call endpoints.
    return false;
  }
  return true;
}

function getPlanNames(config) {
  const plans = (config?.sleep_plans || {});
  return Object.keys(plans).sort();
}

function buildEmptyEKSPlan() {
  return {
    plan_type: "EKS_CLUSTER_SLEEP",
    step_configs: {
      K8S_WORKLOAD_SCALE: {
        sleep_replicas: 0,
        selector: { exclude_namespaces: ["kube-system", "kube-public"] },
      },
      EKS_NODEGROUP_SCALE: {
        sleep_min: 0,
        sleep_desired: 0,
        sleep_max: 1,
      },
    },
  };
}

function buildEmptyRDSPlan() {
  return {
    plan_type: "RDS_SLEEP",
    step_configs: {
      RDS_INSTANCE_POWER: {
        create_final_snapshot: false,
      },
    },
  };
}

function readCsvNamespaces(val) {
  return String(val || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function safeInt(v, fallback) {
  const n = Number.parseInt(String(v ?? ""), 10);
  return Number.isFinite(n) ? n : fallback;
}

function renderPlansList(config) {
  const plans = config?.sleep_plans || {};
  const names = Object.keys(plans).sort();

  if (!names.length) {
    return `<div class="ds-mono-muted" style="padding:10px;">No plans found.</div>`;
  }

  return names.map((name) => {
    const p = plans[name] || {};
    const type = p.plan_type || "—";
    return `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head" style="margin-bottom:0;">
          <div>
            <div class="ds-panel__title">${h(name)}</div>
            <div class="ds-panel__sub">Type: ${h(type)}</div>
          </div>
          <div class="ds-row">
            <button class="ds-btn ds-btn--ghost" type="button" data-plan-action="edit" data-plan="${h(name)}">Edit</button>
            <button class="ds-btn ds-btn--danger" type="button" data-plan-action="delete" data-plan="${h(name)}">Delete</button>
          </div>
        </div>
      </div>
    `;
  }).join("");
}

function renderEditorBody(mode, planName, planType, plan) {
  // Normalize plan for form fields
  const p = plan || (planType === "RDS_SLEEP" ? buildEmptyRDSPlan() : buildEmptyEKSPlan());
  const type = planType || p.plan_type || "EKS_CLUSTER_SLEEP";

  const isEdit = mode === "edit";

  const eksK8s = (p.step_configs?.K8S_WORKLOAD_SCALE || {});
  const eksNg = (p.step_configs?.EKS_NODEGROUP_SCALE || {});
  const rdsPower = (p.step_configs?.RDS_INSTANCE_POWER || {});

  const excludeNs = (eksK8s.selector?.exclude_namespaces || []).join(",");

  return `
    <div class="ds-row" style="margin-bottom:12px;justify-content:space-between;">
      <span class="ds-badge">${isEdit ? "EDIT" : "NEW"}</span>
      <span class="ds-badge ds-badge--muted">Hard borders • Strict validation happens server-side</span>
    </div>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
      <div>
        <div class="ds-field" style="min-width:unset;">
          <div class="ds-label">Plan Name</div>
          <input class="ds-input" id="ds-plan-name" value="${h(planName || "")}" placeholder="ex: dev" ${isEdit ? "disabled" : ""} />
        </div>

        <div style="height:10px"></div>

        <div class="ds-field" style="min-width:unset;">
          <div class="ds-label">Plan Type</div>
          <select class="ds-select" id="ds-plan-type" ${isEdit ? "disabled" : ""}>
            <option value="EKS_CLUSTER_SLEEP" ${type === "EKS_CLUSTER_SLEEP" ? "selected" : ""}>EKS_CLUSTER_SLEEP</option>
            <option value="RDS_SLEEP" ${type === "RDS_SLEEP" ? "selected" : ""}>RDS_SLEEP</option>
          </select>
        </div>

        <div style="height:12px"></div>

        <div id="ds-plan-form-eks" ${type === "EKS_CLUSTER_SLEEP" ? "" : "hidden"}>
          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">K8S Workloads</div>
                <div class="ds-panel__sub">K8S_WORKLOAD_SCALE</div>
              </div>
            </div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Sleep Replicas</div>
              <input class="ds-input" id="ds-sleep-replicas" inputmode="numeric" value="${h(String(eksK8s.sleep_replicas ?? 0))}" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Exclude Namespaces (CSV)</div>
              <input class="ds-input" id="ds-exclude-namespaces" value="${h(excludeNs)}" placeholder="kube-system,kube-public" />
            </div>
          </div>

          <div style="height:12px"></div>

          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">EKS Nodegroups</div>
                <div class="ds-panel__sub">EKS_NODEGROUP_SCALE (must satisfy min ≤ desired ≤ max, and max ≥ 1)</div>
              </div>
            </div>

            <div class="ds-row">
              <div class="ds-field" style="min-width:140px;">
                <div class="ds-label">Min</div>
                <input class="ds-input" id="ds-sleep-min" inputmode="numeric" value="${h(String(eksNg.sleep_min ?? 0))}" />
              </div>
              <div class="ds-field" style="min-width:140px;">
                <div class="ds-label">Desired</div>
                <input class="ds-input" id="ds-sleep-desired" inputmode="numeric" value="${h(String(eksNg.sleep_desired ?? 0))}" />
              </div>
              <div class="ds-field" style="min-width:140px;">
                <div class="ds-label">Max</div>
                <input class="ds-input" id="ds-sleep-max" inputmode="numeric" value="${h(String(eksNg.sleep_max ?? 1))}" />
              </div>
            </div>
          </div>
        </div>

        <div id="ds-plan-form-rds" ${type === "RDS_SLEEP" ? "" : "hidden"}>
          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">RDS Power</div>
                <div class="ds-panel__sub">RDS_INSTANCE_POWER</div>
              </div>
            </div>

            <div class="ds-row">
              <label class="ds-badge" style="gap:10px;">
                <input type="checkbox" id="ds-rds-final-snap" ${rdsPower.create_final_snapshot ? "checked" : ""} />
                <span>Create final snapshot on sleep</span>
              </label>
            </div>
          </div>
        </div>

        <div style="height:12px"></div>

        <div class="ds-row">
          <button class="ds-btn" type="button" id="ds-plan-save">Save</button>
          <button class="ds-btn ds-btn--ghost" type="button" id="ds-plan-cancel">Cancel</button>
        </div>
      </div>

      <div>
        <div class="ds-label">Preview</div>
        <pre class="ds-textarea" id="ds-plan-preview" style="min-height:320px;white-space:pre;overflow:auto;"></pre>
      </div>
    </div>
  `;
}

function buildPlanFromEditor() {
  const name = (qs("#ds-plan-name")?.value || "").trim();
  const type = (qs("#ds-plan-type")?.value || "EKS_CLUSTER_SLEEP").trim();

  if (!name) throw new Error("Plan name required");

  if (type === "RDS_SLEEP") {
    const createFinal = !!qs("#ds-rds-final-snap")?.checked;
    return {
      name,
      plan: {
        plan_type: "RDS_SLEEP",
        step_configs: {
          RDS_INSTANCE_POWER: { create_final_snapshot: createFinal },
        },
      },
    };
  }

  // EKS
  const sleep_replicas = safeInt(qs("#ds-sleep-replicas")?.value, 0);
  const exclude_namespaces = readCsvNamespaces(qs("#ds-exclude-namespaces")?.value);
  const sleep_min = safeInt(qs("#ds-sleep-min")?.value, 0);
  const sleep_desired = safeInt(qs("#ds-sleep-desired")?.value, 0);
  const sleep_max = safeInt(qs("#ds-sleep-max")?.value, 1);

  return {
    name,
    plan: {
      plan_type: "EKS_CLUSTER_SLEEP",
      step_configs: {
        K8S_WORKLOAD_SCALE: {
          sleep_replicas,
          selector: { exclude_namespaces },
        },
        EKS_NODEGROUP_SCALE: {
          sleep_min,
          sleep_desired,
          sleep_max,
        },
      },
    },
  };
}

function updatePreview(config) {
  const preview = qs("#ds-plan-preview");
  if (!preview) return;

  try {
    const { name, plan } = buildPlanFromEditor();
    const tmp = { sleep_plans: { ...(config.sleep_plans || {}), [name]: plan } };
    preview.textContent = JSON.stringify(tmp, null, 2);
  } catch {
    preview.textContent = JSON.stringify(config, null, 2);
  }
}

async function openEditor({ mode, planName, existingPlan }) {
  const host = qs("#ds-modalhost");
  if (!host) return;

  const type = existingPlan?.plan_type || "EKS_CLUSTER_SLEEP";

  host.innerHTML = `
    <div class="ds-modalbackdrop" data-backdrop="1"></div>
    <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Sleep Plan Editor">
      <div class="ds-modal__head">
        <div class="ds-modal__title">${mode === "edit" ? `Edit Plan: ${h(planName)}` : "Create New Plan"}</div>
        <button class="ds-btn ds-btn--ghost" type="button" data-close="1">Close</button>
      </div>
      <div class="ds-modal__body">
        ${renderEditorBody(mode, planName, type, existingPlan)}
      </div>
    </div>
  `;
  host.style.pointerEvents = "auto";

  const close = () => {
    host.innerHTML = "";
    host.style.pointerEvents = "none";
  };

  host.addEventListener("click", (e) => {
    const t = e.target;
    if (t?.dataset?.backdrop || t?.dataset?.close) close();
  }, { once: true });

  const planTypeSel = qs("#ds-plan-type");
  const eksForm = qs("#ds-plan-form-eks");
  const rdsForm = qs("#ds-plan-form-rds");
  const cancelBtn = qs("#ds-plan-cancel");
  const saveBtn = qs("#ds-plan-save");

  const config = Store.getState().sleepPlans.config;

  function toggleType() {
    const v = planTypeSel.value;
    if (eksForm) eksForm.hidden = v !== "EKS_CLUSTER_SLEEP";
    if (rdsForm) rdsForm.hidden = v !== "RDS_SLEEP";
    updatePreview(config);
  }

  planTypeSel?.addEventListener("change", toggleType);

  // bind preview updates
  [
    "#ds-plan-name",
    "#ds-sleep-replicas",
    "#ds-exclude-namespaces",
    "#ds-sleep-min",
    "#ds-sleep-desired",
    "#ds-sleep-max",
    "#ds-rds-final-snap",
  ].forEach((sel) => {
    const el = qs(sel);
    if (!el) return;
    el.addEventListener("input", () => updatePreview(config));
    el.addEventListener("change", () => updatePreview(config));
  });

  cancelBtn?.addEventListener("click", close);

  saveBtn?.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const accountId = s.account.id;
      const cfg = { ...(s.sleepPlans.config || { sleep_plans: {} }) };
      cfg.sleep_plans = { ...(cfg.sleep_plans || {}) };

      const { name, plan } = buildPlanFromEditor();

      // write back plan
      cfg.sleep_plans[name] = plan;

      // PUT whole config
      const saved = await Api.putAccountConfig(accountId, cfg);

      Store.setState({
        sleepPlans: {
          config: saved || cfg,
          names: getPlanNames(saved || cfg),
        },
      });

      // also refresh plan dropdowns used elsewhere
      toast("Sleep Plans", "Saved.");
      close();
      // rerender page list
      await SleepPlansPage();
    } catch (e) {
      toast("Sleep Plans", e.message || "Save failed");
    }
  });

  toggleType();
  updatePreview(config);
}

export async function SleepPlansPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Sleep Plans";

  page.innerHTML = renderPanel({
    title: "Sleep Plans",
    sub: "Define, edit and delete sleep plan configurations stored in account config.",
    actionsHtml: `<button class="ds-btn ds-btn--wake" id="ds-plan-create" type="button">Create New Plan</button>`,
    bodyHtml: `
      <div class="ds-mono-muted" id="ds-plan-status">—</div>
      <div style="height:10px"></div>
      <div id="ds-plans-container"></div>
    `,
  });

  const status = qs("#ds-plan-status");
  const container = qs("#ds-plans-container");
  const btnCreate = qs("#ds-plan-create");

  if (!requireAuthAndAccount()) {
    status.textContent = "Not ready (missing auth/account).";
    return;
  }

  async function loadConfig() {
    const s = Store.getState();
    status.textContent = "Fetching configuration…";
    try {
      const cfg = await Api.getAccountConfig(s.account.id);
      const names = getPlanNames(cfg);
      Store.setState({ sleepPlans: { config: cfg, names } });
      status.textContent = `OK — ${names.length} plan(s).`;
      container.innerHTML = renderPlansList(cfg);
      bindListActions();
    } catch (e) {
      status.textContent = "Error.";
      toast("Sleep Plans", e.message || "Load failed");
      container.innerHTML = `<div class="ds-mono-muted" style="padding:10px;">Failed to load.</div>`;
    }
  }

  function bindListActions() {
    qsa('[data-plan-action="edit"]').forEach((b) => {
      b.addEventListener("click", async () => {
        const name = b.dataset.plan;
        const cfg = Store.getState().sleepPlans.config;
        const plan = (cfg.sleep_plans || {})[name];
        await openEditor({ mode: "edit", planName: name, existingPlan: plan });
      });
    });

    qsa('[data-plan-action="delete"]').forEach((b) => {
      b.addEventListener("click", async () => {
        const name = b.dataset.plan;
        const ok = await confirmModal({
          title: "Delete Sleep Plan",
          body: `<div class="ds-mono-muted">Delete plan <b>${h(name)}</b> ?</div>`,
          confirmText: "Delete",
          cancelText: "Cancel",
        });
        if (!ok) return;

        try {
          const s = Store.getState();
          const cfg = { ...(s.sleepPlans.config || { sleep_plans: {} }) };
          cfg.sleep_plans = { ...(cfg.sleep_plans || {}) };
          delete cfg.sleep_plans[name];

          const saved = await Api.putAccountConfig(s.account.id, cfg);
          Store.setState({
            sleepPlans: {
              config: saved || cfg,
              names: getPlanNames(saved || cfg),
            },
          });
          toast("Sleep Plans", "Deleted.");
          await loadConfig();
        } catch (e) {
          toast("Sleep Plans", e.message || "Delete failed");
        }
      });
    });
  }

  btnCreate?.addEventListener("click", async () => {
    await openEditor({ mode: "new", planName: "", existingPlan: null });
  });

  await loadConfig();
}
EOF

# ---------------------------
# 9) Time Policies page: form editor (no JSON), uses plan dropdowns from SleepPlans
# ---------------------------
cat > "$ROOT/js/pages/TimePoliciesPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";

const DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];

function requireAuthAndAccount() {
  const s = Store.getState();
  if (!s.auth.token) {
    toast("Auth", "Please login.");
    location.hash = "#/login";
    return false;
  }
  if (!s.account.id) {
    toast("Setup", "Missing internal account_id. Backend should provide it in token claims.");
    return false;
  }
  return true;
}

function defaultWindow() {
  return { days: ["MON", "TUE", "WED", "THU", "FRI"], start: "21:00", end: "07:00", start_date: null, end_date: null };
}

function normalizeWindows(list) {
  const wins = Array.isArray(list) ? list : [];
  return wins.map((w) => ({
    days: w.days ?? null,
    start: w.start || "21:00",
    end: w.end || "07:00",
    start_date: w.start_date || null,
    end_date: w.end_date || null,
  }));
}

function renderDayChecks(win, idx) {
  const days = win.days; // null => all days
  const set = days ? new Set(days) : null;

  return DOW.map((d) => {
    const checked = set ? set.has(d) : true;
    return `
      <label class="ds-badge" style="gap:10px;">
        <input type="checkbox" data-win="${idx}" data-day="${d}" ${checked ? "checked" : ""} />
        <span>${d}</span>
      </label>
    `;
  }).join("");
}

function renderWindowsEditor(windows) {
  if (!windows.length) {
    return `<div class="ds-mono-muted" style="padding:10px;">No windows. Add one.</div>`;
  }

  return windows.map((w, idx) => {
    const daysLabel = w.days ? w.days.join(",") : "ALL";
    return `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head">
          <div>
            <div class="ds-panel__title">Window #${idx + 1}</div>
            <div class="ds-panel__sub">Days: ${h(daysLabel)} • ${h(w.start)} → ${h(w.end)}</div>
          </div>
          <div class="ds-row">
            <button class="ds-btn ds-btn--danger" type="button" data-win-remove="${idx}">Remove</button>
          </div>
        </div>

        <div class="ds-row" style="margin-bottom:10px;flex-wrap:wrap;">
          ${renderDayChecks(w, idx)}
          <button class="ds-btn ds-btn--ghost" type="button" data-win-all="${idx}">All</button>
          <button class="ds-btn ds-btn--ghost" type="button" data-win-weekdays="${idx}">Weekdays</button>
          <button class="ds-btn ds-btn--ghost" type="button" data-win-weekend="${idx}">Weekend</button>
        </div>

        <div class="ds-row">
          <div class="ds-field" style="min-width:140px;">
            <div class="ds-label">Start (HH:MM)</div>
            <input class="ds-input" data-win-start="${idx}" value="${h(w.start)}" placeholder="21:00" />
          </div>
          <div class="ds-field" style="min-width:140px;">
            <div class="ds-label">End (HH:MM)</div>
            <input class="ds-input" data-win-end="${idx}" value="${h(w.end)}" placeholder="07:00" />
          </div>
          <div class="ds-field" style="min-width:180px;">
            <div class="ds-label">Start date (optional)</div>
            <input class="ds-input" data-win-sd="${idx}" value="${h(w.start_date || "")}" placeholder="YYYY-MM-DD" />
          </div>
          <div class="ds-field" style="min-width:180px;">
            <div class="ds-label">End date (optional)</div>
            <input class="ds-input" data-win-ed="${idx}" value="${h(w.end_date || "")}" placeholder="YYYY-MM-DD" />
          </div>
        </div>
      </div>
    `;
  }).join("");
}

function readEditorState() {
  const name = (qs("#ds-pol-name")?.value || "").trim();
  if (!name) throw new Error("Policy name required.");

  const enabled = !!qs("#ds-pol-enabled")?.checked;
  const timezone = (qs("#ds-pol-timezone")?.value || "UTC").trim() || "UTC";

  const regionsCsv = (qs("#ds-pol-regions")?.value || "").trim();
  const regions = regionsCsv ? regionsCsv.split(",").map((x) => x.trim()).filter(Boolean) : null;

  const onlyRegistered = true; // product wants strict registered-only semantics
  const resource_types = [];
  if (qs("#ds-pol-type-eks")?.checked) resource_types.push("EKS_CLUSTER");
  if (qs("#ds-pol-type-rds")?.checked) resource_types.push("RDS_INSTANCE");
  if (!resource_types.length) throw new Error("Select at least one resource type.");

  const planEks = (qs("#ds-pol-plan-eks")?.value || "").trim();
  const planRds = (qs("#ds-pol-plan-rds")?.value || "").trim();
  const plan_name_by_type = {};
  if (resource_types.includes("EKS_CLUSTER")) {
    if (!planEks) throw new Error("Missing plan for EKS_CLUSTER.");
    plan_name_by_type["EKS_CLUSTER"] = planEks;
  }
  if (resource_types.includes("RDS_INSTANCE")) {
    if (!planRds) throw new Error("Missing plan for RDS_INSTANCE.");
    plan_name_by_type["RDS_INSTANCE"] = planRds;
  }

  // windows (from store buffer)
  const windows = Store.getState().policies.editorWindows || [];
  if (!windows.length) throw new Error("Add at least one window.");

  // normalize: days==ALL => null
  const normalizedWindows = windows.map((w) => ({
    days: (w.days && w.days.length === 7) ? null : (w.days && w.days.length ? w.days : null),
    start: w.start,
    end: w.end,
    start_date: w.start_date || null,
    end_date: w.end_date || null,
  }));

  return {
    name,
    enabled,
    timezone,
    search: {
      resource_types,
      regions,
      selector_by_type: {},
      only_registered: onlyRegistered,
    },
    windows: normalizedWindows,
    plan_name_by_type,
  };
}

async function ensureSleepPlansLoaded() {
  const s = Store.getState();
  if (!s.sleepPlans?.config?.sleep_plans) {
    const cfg = await Api.getAccountConfig(s.account.id);
    const names = Object.keys(cfg.sleep_plans || {}).sort();
    Store.setState({ sleepPlans: { config: cfg, names } });
  }
}

function renderPlansOptions(names) {
  if (!names.length) return `<option value="">(no plans)</option>`;
  return names.map((n) => `<option value="${h(n)}">${h(n)}</option>`).join("");
}

function renderPoliciesList(list) {
  return (list || []).map((p) => {
    const next = p.next_transition_at ? fmtTime(p.next_transition_at) : "—";
    return `
      <tr>
        <td>${p.id}</td>
        <td>${h(p.name)}</td>
        <td>${p.enabled ? `<span class="ds-badge ds-badge--reg">true</span>` : `<span class="ds-badge">false</span>`}</td>
        <td>${h(p.timezone || "UTC")}</td>
        <td class="ds-mono-muted">${h(next)}</td>
        <td>
          <div class="ds-row">
            <button class="ds-btn ds-btn--ghost" type="button" data-pol="select" data-id="${p.id}">Select</button>
            <button class="ds-btn ds-btn--ghost" type="button" data-pol="load" data-id="${p.id}">Load</button>
          </div>
        </td>
      </tr>
    `;
  }).join("");
}

export async function TimePoliciesPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Time Policies";

  page.innerHTML = renderPanel({
    title: "Time Policies",
    sub: "Define, edit and delete Time Sleep Policies with a structured UI.",
    actionsHtml: `
      <button class="ds-btn" id="ds-pol-refresh" type="button">Refresh</button>
      <button class="ds-btn ds-btn--wake" id="ds-pol-new" type="button">New Policy</button>
    `,
    bodyHtml: `
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
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
                <div class="ds-panel__sub">UI editor (no JSON). Registered-only strict semantics.</div>
              </div>
            </div>

            <div class="ds-row" style="margin-bottom:12px;">
              <div class="ds-field" style="min-width:unset;flex:1;">
                <div class="ds-label">Selected policy ID</div>
                <input class="ds-input" id="ds-pol-selected-id" value="" placeholder="(none)" />
              </div>
              <label class="ds-badge" style="gap:10px;">
                <input type="checkbox" id="ds-pol-enabled" checked />
                <span>Enabled</span>
              </label>
            </div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Policy name</div>
              <input class="ds-input" id="ds-pol-name" placeholder="ex: night-sleep" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Timezone</div>
              <input class="ds-input" id="ds-pol-timezone" value="UTC" placeholder="UTC / Europe/Paris / Asia/Jerusalem" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-panel" style="margin:0;">
              <div class="ds-panel__head">
                <div>
                  <div class="ds-panel__title">Search</div>
                  <div class="ds-panel__sub">resource_types + optional regions CSV</div>
                </div>
              </div>

              <div class="ds-row" style="margin-bottom:10px;">
                <label class="ds-badge" style="gap:10px;">
                  <input type="checkbox" id="ds-pol-type-eks" checked />
                  <span>EKS_CLUSTER</span>
                </label>
                <label class="ds-badge" style="gap:10px;">
                  <input type="checkbox" id="ds-pol-type-rds" checked />
                  <span>RDS_INSTANCE</span>
                </label>
              </div>

              <div class="ds-field" style="min-width:unset;">
                <div class="ds-label">Regions (CSV, optional)</div>
                <input class="ds-input" id="ds-pol-regions" placeholder="eu-west-1,eu-central-1,us-east-1" />
              </div>

              <div style="height:10px"></div>

              <div class="ds-row">
                <div class="ds-field" style="min-width:unset;flex:1;">
                  <div class="ds-label">Plan for EKS_CLUSTER</div>
                  <select class="ds-select" id="ds-pol-plan-eks"></select>
                </div>
                <div class="ds-field" style="min-width:unset;flex:1;">
                  <div class="ds-label">Plan for RDS_INSTANCE</div>
                  <select class="ds-select" id="ds-pol-plan-rds"></select>
                </div>
              </div>
            </div>

            <div style="height:12px"></div>

            <div class="ds-panel" style="margin:0;">
              <div class="ds-panel__head">
                <div>
                  <div class="ds-panel__title">Windows</div>
                  <div class="ds-panel__sub">Weekly windows with optional date range</div>
                </div>
                <div class="ds-row">
                  <button class="ds-btn ds-btn--wake" id="ds-win-add" type="button">Add Window</button>
                </div>
              </div>

              <div id="ds-win-container"></div>
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
  const inpName = qs("#ds-pol-name");
  const chkEnabled = qs("#ds-pol-enabled");
  const inpTz = qs("#ds-pol-timezone");
  const chkEks = qs("#ds-pol-type-eks");
  const chkRds = qs("#ds-pol-type-rds");
  const inpRegions = qs("#ds-pol-regions");

  const selPlanEks = qs("#ds-pol-plan-eks");
  const selPlanRds = qs("#ds-pol-plan-rds");

  const winContainer = qs("#ds-win-container");
  const btnWinAdd = qs("#ds-win-add");

  const btnCreate = qs("#ds-pol-create");
  const btnUpdate = qs("#ds-pol-update");
  const btnDelete = qs("#ds-pol-delete");
  const btnRunSleep = qs("#ds-pol-run-sleep");
  const btnRunWake = qs("#ds-pol-run-wake");

  if (!requireAuthAndAccount()) {
    status.textContent = "Not ready (missing auth/account).";
    return;
  }

  await ensureSleepPlansLoaded();
  const planNames = Store.getState().sleepPlans.names || [];
  selPlanEks.innerHTML = renderPlansOptions(planNames);
  selPlanRds.innerHTML = renderPlansOptions(planNames);

  // default pick
  if (planNames.length) {
    selPlanEks.value = planNames[0];
    selPlanRds.value = planNames[0];
  }

  // windows buffer in store (so edits survive small rerenders)
  Store.setState({ policies: { ...Store.getState().policies, editorWindows: [defaultWindow()] } });

  function renderWindows() {
    const windows = Store.getState().policies.editorWindows || [];
    winContainer.innerHTML = renderWindowsEditor(windows);

    // remove window
    qsa("[data-win-remove]").forEach((b) => {
      b.addEventListener("click", () => {
        const idx = Number(b.dataset.winRemove);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins.splice(idx, 1);
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
        renderWindows();
      });
    });

    // quick sets
    qsa("[data-win-all]").forEach((b) => {
      b.addEventListener("click", () => {
        const idx = Number(b.dataset.winAll);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].days = [...DOW];
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
        renderWindows();
      });
    });
    qsa("[data-win-weekdays]").forEach((b) => {
      b.addEventListener("click", () => {
        const idx = Number(b.dataset.winWeekdays);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].days = ["MON","TUE","WED","THU","FRI"];
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
        renderWindows();
      });
    });
    qsa("[data-win-weekend]").forEach((b) => {
      b.addEventListener("click", () => {
        const idx = Number(b.dataset.winWeekend);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].days = ["SAT","SUN"];
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
        renderWindows();
      });
    });

    // day toggles
    qsa('input[type="checkbox"][data-win][data-day]').forEach((cb) => {
      cb.addEventListener("change", () => {
        const idx = Number(cb.dataset.win);
        const day = cb.dataset.day;
        const wins = [...(Store.getState().policies.editorWindows || [])];
        const set = new Set(wins[idx].days || DOW);
        if (cb.checked) set.add(day);
        else set.delete(day);
        wins[idx].days = Array.from(set);
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });

    // time inputs
    qsa("[data-win-start]").forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.dataset.winStart);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].start = inp.value.trim();
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });
    qsa("[data-win-end]").forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.dataset.winEnd);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].end = inp.value.trim();
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });
    qsa("[data-win-sd]").forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.dataset.winSd);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].start_date = inp.value.trim() || null;
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });
    qsa("[data-win-ed]").forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.dataset.winEd);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].end_date = inp.value.trim() || null;
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });
  }

  btnWinAdd.addEventListener("click", () => {
    const wins = [...(Store.getState().policies.editorWindows || [])];
    wins.push(defaultWindow());
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
    renderWindows();
  });

  function resetEditor() {
    inpSel.value = "";
    inpName.value = "";
    chkEnabled.checked = true;
    inpTz.value = "UTC";
    chkEks.checked = true;
    chkRds.checked = true;
    inpRegions.value = "";
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: [defaultWindow()] } });
    renderWindows();
  }

  btnNew.addEventListener("click", resetEditor);

  async function loadList() {
    const s = Store.getState();
    status.textContent = "Loading…";
    try {
      const resp = await Api.listPolicies(s.account.id);
      const list = resp?.policies || [];
      Store.setState({ policies: { ...s.policies, list } });
      tbody.innerHTML = renderPoliciesList(list);
      status.textContent = `OK — ${list.length} policy(s).`;
      bindListActions();
    } catch (e) {
      status.textContent = "Error.";
      toast("Time Policies", e.message || "Load failed");
    }
  }

  function bindListActions() {
    qsa('[data-pol="select"]').forEach((b) => {
      b.addEventListener("click", () => {
        const id = Number(b.dataset.id);
        inpSel.value = String(id);
        toast("Editor", `Selected policy ${id}.`);
      });
    });

    qsa('[data-pol="load"]').forEach((b) => {
      b.addEventListener("click", () => {
        const id = Number(b.dataset.id);
        const p = Store.getState().policies.list.find((x) => x.id === id);
        if (!p) return;

        inpSel.value = String(id);
        inpName.value = p.name || "";
        chkEnabled.checked = !!p.enabled;
        inpTz.value = p.timezone || "UTC";

        const types = new Set((p.search?.resource_types || []));
        chkEks.checked = types.has("EKS_CLUSTER");
        chkRds.checked = types.has("RDS_INSTANCE");

        const regions = p.search?.regions || null;
        inpRegions.value = Array.isArray(regions) ? regions.join(",") : "";

        const planByType = p.plan_name_by_type || {};
        if (planByType.EKS_CLUSTER) selPlanEks.value = planByType.EKS_CLUSTER;
        if (planByType.RDS_INSTANCE) selPlanRds.value = planByType.RDS_INSTANCE;

        const windows = normalizeWindows(p.windows || []);
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: windows.length ? windows : [defaultWindow()] } });
        renderWindows();

        toast("Editor", "Loaded into editor.");
      });
    });
  }

  btnRefresh.addEventListener("click", loadList);

  btnCreate.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const body = readEditorState();
      await Api.createPolicy(s.account.id, body);
      toast("Time Policies", "Created.");
      await loadList();
    } catch (e) {
      toast("Time Policies", e.message || "Create failed");
    }
  });

  btnUpdate.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");
      const body = readEditorState();
      await Api.updatePolicy(s.account.id, id, body);
      toast("Time Policies", "Updated.");
      await loadList();
    } catch (e) {
      toast("Time Policies", e.message || "Update failed");
    }
  });

  btnDelete.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");

      const ok = await confirmModal({
        title: "Delete Policy",
        body: `<div class="ds-mono-muted">Policy <b>${h(String(id))}</b> will be deleted (executions too).</div>`,
        confirmText: "Delete",
        cancelText: "Cancel",
      });
      if (!ok) return;

      await Api.deletePolicy(s.account.id, id);
      toast("Time Policies", "Deleted.");
      resetEditor();
      await loadList();
    } catch (e) {
      toast("Time Policies", e.message || "Delete failed");
    }
  });

  btnRunSleep.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");
      await Api.runPolicyNow(s.account.id, id, "SLEEP");
      toast("Time Policies", "Run-now SLEEP submitted.");
    } catch (e) {
      toast("Time Policies", e.message || "Run-now failed");
    }
  });

  btnRunWake.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");
      await Api.runPolicyNow(s.account.id, id, "WAKE");
      toast("Time Policies", "Run-now WAKE submitted.");
    } catch (e) {
      toast("Time Policies", e.message || "Run-now failed");
    }
  });

  renderWindows();
  await loadList();
}
EOF

# ---------------------------
# 10) app.js: register /login, route landing, settings->SleepPlans, policies updated
# ---------------------------
cat > "$ROOT/app.js" <<'EOF'
import { Store } from "./js/store.js";
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

import { LoginPage } from "./js/pages/LoginPage.js";
import { InventoryPage } from "./js/pages/InventoryPage.js";
import { ActiveResourcesPage } from "./js/pages/ActiveResourcesPage.js";
import { TimePoliciesPage } from "./js/pages/TimePoliciesPage.js";
import { SleepPlansPage } from "./js/pages/SleepPlansPage.js";

import * as Api from "./js/api/services.js";

/* ---------- Bootstrapping shell ---------- */
(function bootstrapShell(){
  const rail = qs("#ds-rail");
  if (rail) rail.innerHTML = renderSidebar();

  const topbar = qs("#ds-topbar");
  if (topbar) topbar.innerHTML = renderHeader();

  bindUserDropdown();
  renderUserInfo();

  bindGlobalSearch((q) => {
    const route = Store.getState().route.name;
    if (route === "discovery") applyTableFilter('[data-table="discovery"]', q);
    if (route === "active") applyTableFilter('[data-table="active"]', q);
  });

  // API indicator is internal now
  const apiIndicator = qs("#ds-api-indicator");
  if (apiIndicator) apiIndicator.textContent = "same-origin";
})();

/* ---------- Router ---------- */
const router = createRouter();

router.register("login", async () => LoginPage());
router.register("discovery", async () => InventoryPage());
router.register("active", async () => ActiveResourcesPage());
router.register("policies", async () => TimePoliciesPage());
router.register("settings", async () => SleepPlansPage());

function initialRoute(route) {
  const s = Store.getState();
  const hasToken = !!s.auth.token;

  // Landing: if not logged in -> /login
  if (!hasToken && route.name !== "login") {
    location.hash = "#/login";
    return;
  }

  // If logged in and user hits /login, redirect to discovery
  if (hasToken && route.name === "login") {
    location.hash = "#/discovery";
    return;
  }

  Store.setState({ route });
  setActiveNav(route.name);
  router.render(route);

  // keep search input in sync
  const input = qs("#ds-global-search");
  if (input) input.value = Store.getState().ui.search || "";
}

router.start((route) => initialRoute(route));

/* ---------- Polling (10s) ----------
   Fetch /accounts/{id}/cluster-states and patch only changed rows.
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

# ---------------------------
# 11) Remove old SettingsPage.js if exists and keep folder clean
# ---------------------------
if [[ -f "$ROOT/js/pages/SettingsPage.js" ]]; then
  rm -f "$ROOT/js/pages/SettingsPage.js"
fi

# ---------------------------
# 12) README note update (optional)
# ---------------------------
cat > "$ROOT/README.refactor.txt" <<'EOF'
DeepSleep Vanilla SPA (no framework) — Updated UX

Key changes:
- /login route is the landing page when not authenticated.
- Logout redirects to /login.
- Top-right user dropdown displays:
  - Email
  - Business ID
  - AWS Account (currently unknown => blank/—)
- "Sleep Plans" tab (route: /settings) is the UI editor for account sleep plans:
  - GET /accounts/{account_id}/config
  - PUT /accounts/{account_id}/config
- "Time Policies" tab is a full UI editor (no JSON), including window editor + plan_name_by_type.

Notes:
- API base URL is same-origin (internal), not user-configurable.
- account_id is internal; UI does not ask for it. Frontend attempts to infer it from JWT claims on login.
  If your JWT does not include it, set it server-side or add a lightweight "me" endpoint.
EOF

echo "OK: patched files for /login, Sleep Plans UI, and Time Policies UI under: $ROOT"
echo "Next: ensure JWT includes account_id (or add an endpoint to fetch it), then serve statically."
