#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

need() { [[ -f "$1" ]] || { echo "ERROR: missing $1"; exit 1; }; }

mkdir -p \
  "$ROOT/js/api" \
  "$ROOT/js/components" \
  "$ROOT/js/pages" \
  "$ROOT/js/utils"

# ------------------------------------------------------------------
# 1) store.js
# ------------------------------------------------------------------
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
    id: Number(Storage.get("deepsleep.account_id", "0") || 0) || 0,
    aws_account_id: Storage.get("deepsleep.aws_account_id", ""),
    name: Storage.get("deepsleep.account_name", "—"),
  },

  accounts: {
    list: [], // [{id, name, aws_account_id}]
    loaded: false,
  },

  plansCatalog: {
    supported: {},      // GET /plans
    planSchemas: {},    // GET /schemas/plans/{plan_type}
  },

  discovery: {
    lastQuery: null,
    resources: [],
    selectedKeys: new Set(),
    regionsCsv: "eu-west-1,eu-central-1,us-east-1",
    regionsList: [],
    resourceTypes: ["EKS_CLUSTER", "RDS_INSTANCE"],
  },

  active: {
    rowsByKey: new Map(),
    lastPollAt: null,
  },

  sleepPlans: {
    config: { sleep_plans: {} },
    names: [],
    loading: false,
  },

  policies: {
    list: [],
    selectedId: null,
    loading: false,
    editorWindows: [],
    editorSelectors: {
      EKS_CLUSTER: {},
      RDS_INSTANCE: {},
    },
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

# ------------------------------------------------------------------
# 2) js/api/services.js
# ------------------------------------------------------------------
cat > "$ROOT/js/api/services.js" <<'EOF'
import { request } from "./client.js";

/* Auth */
export const login = (payload) => request("/auth/login", { method: "POST", body: payload });
export const refresh = (payload) => request("/auth/refresh", { method: "POST", body: payload });

/* Accounts */
export const listAccounts = () => request("/accounts");

/* Plan catalog / schemas */
export const getSupportedPlans = () => request("/plans");
export const getStepSchema = (stepType) => request(`/schemas/steps/${encodeURIComponent(stepType)}`);
export const getPlanSchema = (planType) => request(`/schemas/plans/${encodeURIComponent(planType)}`);

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

export const unregisterEKS = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/register`, {
    method: "DELETE",
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

export const unregisterRDS = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/register`, {
    method: "DELETE",
    query: { region },
  });

/* Time policies */
export const listPolicies = (accountId) =>
  request(`/accounts/${accountId}/time-policies`);

export const getPolicy = (accountId, policyId) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`);

export const createPolicy = (accountId, body) =>
  request(`/accounts/${accountId}/time-policies`, { method: "POST", body });

export const updatePolicy = (accountId, policyId, body) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "PUT", body });

export const deletePolicy = (accountId, policyId) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "DELETE" });

export const runPolicyNow = (accountId, policyId, action) =>
  request(`/accounts/${accountId}/time-policies/${policyId}/run-now`, { method: "POST", body: { action } });
EOF

# ------------------------------------------------------------------
# 3) js/components/Header.js
# ------------------------------------------------------------------
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
        <div class="ds-dropdown__row">
          <div class="ds-dropdown__k">Switch Account</div>
          <div class="ds-dropdown__v" style="min-width:180px;max-width:none;">
            <select class="ds-select" id="ds-account-switch" style="min-width:180px;">
              <option value="">(loading...)</option>
            </select>
          </div>
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

# ------------------------------------------------------------------
# 4) js/components/UserDropdown.js
# ------------------------------------------------------------------
cat > "$ROOT/js/components/UserDropdown.js" <<'EOF'
import { qs } from "../utils/dom.js";
import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { Storage } from "../utils/storage.js";
import * as Api from "../api/services.js";

function rerenderCurrentRoute() {
  window.dispatchEvent(new Event("hashchange"));
}

export async function loadAccountsIntoDropdown() {
  const token = Store.getState().auth?.token;
  const select = qs("#ds-account-switch");
  if (!select) return;
  if (!token) {
    select.innerHTML = `<option value="">(login required)</option>`;
    return;
  }

  try {
    const resp = await Api.listAccounts();
    const accounts = resp?.accounts || [];

    Store.setState({ accounts: { list: accounts, loaded: true } });

    if (!accounts.length) {
      select.innerHTML = `<option value="">(no account)</option>`;
      return;
    }

    let currentId = Store.getState().account.id;
    let currentAws = Store.getState().account.aws_account_id;

    if (!currentId) {
      currentId = accounts[0].id;
      currentAws = accounts[0].aws_account_id || "";
      Storage.set("deepsleep.account_id", String(currentId));
      Storage.set("deepsleep.aws_account_id", currentAws);
      Store.setState({ account: { id: currentId, aws_account_id: currentAws } });
    }

    select.innerHTML = accounts.map((acc) => `
      <option value="${acc.id}" ${Number(acc.id) === Number(currentId) ? "selected" : ""}>
        ${acc.aws_account_id}
      </option>
    `).join("");

    renderUserInfo();
  } catch (e) {
    select.innerHTML = `<option value="">(failed)</option>`;
    toast("Accounts", e.message || "Failed to load accounts");
  }
}

export function bindUserDropdown() {
  const userchip = qs("#ds-userchip");
  const dropdown = qs("#ds-user-dropdown");
  const logout = qs("#ds-logout-btn");
  const switcher = qs("#ds-account-switch");

  if (!userchip || !dropdown) return;

  userchip.addEventListener("click", async () => {
    const expanded = userchip.getAttribute("aria-expanded") === "true";
    userchip.setAttribute("aria-expanded", expanded ? "false" : "true");
    dropdown.hidden = expanded;
    if (!expanded) {
      await loadAccountsIntoDropdown();
    }
  });

  document.addEventListener("click", (e) => {
    const inside = userchip.contains(e.target) || dropdown.contains(e.target);
    if (!inside) {
      userchip.setAttribute("aria-expanded", "false");
      dropdown.hidden = true;
    }
  });

  if (switcher) {
    switcher.addEventListener("change", () => {
      const id = Number(switcher.value || 0);
      const account = (Store.getState().accounts.list || []).find((x) => Number(x.id) === id);
      if (!account) return;

      Storage.set("deepsleep.account_id", String(account.id));
      Storage.set("deepsleep.aws_account_id", account.aws_account_id || "");

      Store.setState({
        account: {
          id: account.id,
          aws_account_id: account.aws_account_id || "",
          name: account.name || "—",
        },
      });

      renderUserInfo();
      toast("Account", `Switched to ${account.aws_account_id}`);
      rerenderCurrentRoute();
    });
  }

  if (logout) {
    logout.addEventListener("click", () => {
      Storage.del("deepsleep.token");
      Storage.del("deepsleep.account_id");
      Storage.del("deepsleep.aws_account_id");

      Store.setState({
        auth: { token: "" },
        account: { id: 0, aws_account_id: "" },
        accounts: { list: [], loaded: false },
      });

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
  if (ddAws) ddAws.textContent = s.account.aws_account_id || "—";
  if (ddBiz) ddBiz.textContent = s.auth.business_id || "—";
}
EOF

# ------------------------------------------------------------------
# 5) js/pages/LoginPage.js
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/LoginPage.js" <<'EOF'
import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";
import { toast } from "../utils/toast.js";
import { qs } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";
import { renderUserInfo } from "../components/UserDropdown.js";

export async function LoginPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

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

      Storage.set("deepsleep.token", token);
      Storage.set("deepsleep.email", payload.email);
      Storage.set("deepsleep.business_id", payload.business_id);

      // account is now loaded from GET /accounts in dropdown logic
      Store.setState({
        auth: { token, email: payload.email, business_id: payload.business_id },
        account: { id: 0, aws_account_id: "" },
        accounts: { list: [], loaded: false },
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
    Storage.del("deepsleep.account_id");
    Storage.del("deepsleep.aws_account_id");

    Store.setState({
      auth: { token: "" },
      account: { id: 0, aws_account_id: "" },
      accounts: { list: [], loaded: false },
    });

    tokenPreview.textContent = "—";
    toast("Auth", "Token cleared.");
  });
}
EOF

# ------------------------------------------------------------------
# 6) js/pages/SleepPlansPage.js
#    Uses:
#      GET /plans
#      GET /schemas/plans/{plan_type}
#      GET/PUT /accounts/{id}/config
# ------------------------------------------------------------------
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
    toast("Account", "Choose an account from Switch Account first.");
    return false;
  }
  return true;
}

function getPlanNames(config) {
  return Object.keys(config?.sleep_plans || {}).sort();
}

function normalizePrimitiveBySchema(value, schema) {
  const type = schema?.type;
  if (type === "integer" || type === "number") {
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
  }
  if (type === "boolean") {
    return !!value;
  }
  return value ?? "";
}

function defaultValueFromSchema(schema) {
  if (!schema) return null;
  if (schema.default !== undefined) return schema.default;
  if (schema.type === "boolean") return false;
  if (schema.type === "integer" || schema.type === "number") return 0;
  if (schema.type === "array") return [];
  if (schema.type === "object") return {};
  return "";
}

function buildInitialStepValue(stepSchema, existingValue) {
  if (existingValue !== undefined) return existingValue;
  const props = stepSchema?.properties || {};
  const out = {};
  for (const [field, fieldSchema] of Object.entries(props)) {
    out[field] = defaultValueFromSchema(fieldSchema);
  }
  return out;
}

function setDeep(obj, path, value) {
  const parts = path.split(".");
  let cur = obj;
  while (parts.length > 1) {
    const p = parts.shift();
    if (!cur[p] || typeof cur[p] !== "object") cur[p] = {};
    cur = cur[p];
  }
  cur[parts[0]] = value;
}

function getDeep(obj, path) {
  return path.split(".").reduce((acc, p) => (acc ? acc[p] : undefined), obj);
}

function dictToKvCsv(d) {
  if (!d || typeof d !== "object") return "";
  return Object.entries(d).map(([k, v]) => `${k}=${v}`).join(", ");
}

function kvCsvToDict(v) {
  const out = {};
  String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .forEach((entry) => {
      const idx = entry.indexOf("=");
      if (idx <= 0) return;
      const k = entry.slice(0, idx).trim();
      const val = entry.slice(idx + 1).trim();
      if (k) out[k] = val;
    });
  return out;
}

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function renderField(stepType, fieldName, fieldSchema, value, path) {
  const label = fieldSchema?.title || fieldName;
  const type = fieldSchema?.type;

  if (type === "boolean") {
    return `
      <label class="ds-badge" style="gap:10px;">
        <input type="checkbox" data-plan-path="${h(path)}" ${value ? "checked" : ""} />
        <span>${h(label)}</span>
      </label>
    `;
  }

  if (type === "integer" || type === "number") {
    return `
      <div class="ds-field" style="min-width:180px;">
        <div class="ds-label">${h(label)}</div>
        <input class="ds-input" data-plan-path="${h(path)}" type="number" value="${h(String(value ?? 0))}" />
      </div>
    `;
  }

  if (type === "array" && fieldSchema?.items?.type === "string") {
    return `
      <div class="ds-field" style="min-width:unset;flex:1;">
        <div class="ds-label">${h(label)} (CSV)</div>
        <input class="ds-input" data-plan-path="${h(path)}" value="${h((value || []).join(","))}" />
      </div>
    `;
  }

  if (type === "object") {
    return `
      <div class="ds-field" style="min-width:unset;flex:1;">
        <div class="ds-label">${h(label)} (CSV key=value)</div>
        <input class="ds-input" data-plan-path="${h(path)}" value="${h(dictToKvCsv(value || {}))}" />
      </div>
    `;
  }

  return `
    <div class="ds-field" style="min-width:unset;flex:1;">
      <div class="ds-label">${h(label)}</div>
      <input class="ds-input" data-plan-path="${h(path)}" value="${h(String(value ?? ""))}" />
    </div>
  `;
}

function serializeFieldValue(rawValue, schema) {
  if (schema?.type === "boolean") return !!rawValue;
  if (schema?.type === "integer" || schema?.type === "number") {
    const n = Number(rawValue);
    return Number.isFinite(n) ? n : 0;
  }
  if (schema?.type === "array" && schema?.items?.type === "string") {
    return csvToList(rawValue);
  }
  if (schema?.type === "object") {
    return kvCsvToDict(rawValue);
  }
  return rawValue;
}

function renderStepEditor(stepType, stepSchema, stepValue) {
  const props = stepSchema?.properties || {};
  const fields = Object.entries(props).map(([fieldName, fieldSchema]) => {
    const path = `${stepType}.${fieldName}`;
    const value = stepValue?.[fieldName];
    return renderField(stepType, fieldName, fieldSchema, value, path);
  });

  return `
    <div class="ds-panel" style="margin:0 0 12px 0;">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">${h(stepType)}</div>
          <div class="ds-panel__sub">${h(stepSchema?.title || "Step config")}</div>
        </div>
      </div>
      <div class="ds-row">${fields.join("")}</div>
    </div>
  `;
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

async function ensurePlanCatalogLoaded() {
  const state = Store.getState();
  const cached = state.plansCatalog.supported || {};
  if (Object.keys(cached).length) return cached;

  const supported = await Api.getSupportedPlans();
  Store.setState({ plansCatalog: { ...state.plansCatalog, supported } });
  return supported;
}

async function ensurePlanSchemaLoaded(planType) {
  const state = Store.getState();
  const cached = state.plansCatalog.planSchemas?.[planType];
  if (cached) return cached;

  const schema = await Api.getPlanSchema(planType);
  const next = { ...(state.plansCatalog.planSchemas || {}), [planType]: schema };
  Store.setState({ plansCatalog: { ...state.plansCatalog, planSchemas: next } });
  return schema;
}

async function openEditor({ mode, planName, existingPlan }) {
  const host = qs("#ds-modalhost");
  if (!host) return;

  const supported = await ensurePlanCatalogLoaded();
  const supportedPlanTypes = Object.keys(supported || {}).sort();
  const initialPlanType = existingPlan?.plan_type || supportedPlanTypes[0];
  const initialSchema = await ensurePlanSchemaLoaded(initialPlanType);

  let editorState = {
    name: planName || "",
    plan_type: initialPlanType,
    step_configs: {},
  };

  for (const [stepType, stepSchema] of Object.entries(initialSchema || {})) {
    const existingStep = existingPlan?.step_configs?.[stepType];
    editorState.step_configs[stepType] = buildInitialStepValue(stepSchema, existingStep);
  }

  function renderEditor() {
    const currentSchema = Store.getState().plansCatalog.planSchemas?.[editorState.plan_type] || {};
    const stepEditors = Object.entries(currentSchema).map(([stepType, stepSchema]) => {
      return renderStepEditor(stepType, stepSchema, editorState.step_configs?.[stepType] || {});
    }).join("");

    host.innerHTML = `
      <div class="ds-modalbackdrop" data-backdrop="1"></div>
      <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Sleep Plan Editor">
        <div class="ds-modal__head">
          <div class="ds-modal__title">${mode === "edit" ? `Edit Plan: ${h(editorState.name)}` : "Create New Plan"}</div>
          <button class="ds-btn ds-btn--ghost" type="button" data-close="1">Close</button>
        </div>
        <div class="ds-modal__body">
          <div class="ds-row" style="margin-bottom:12px;justify-content:space-between;">
            <span class="ds-badge">${mode === "edit" ? "EDIT" : "NEW"}</span>
            <span class="ds-badge ds-badge--muted">Source of truth: /plans + /schemas/plans/{plan_type}</span>
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
            <div>
              <div class="ds-field" style="min-width:unset;">
                <div class="ds-label">Plan Name</div>
                <input class="ds-input" id="ds-plan-name" value="${h(editorState.name)}" placeholder="ex: dev" ${mode === "edit" ? "disabled" : ""} />
              </div>

              <div style="height:10px"></div>

              <div class="ds-field" style="min-width:unset;">
                <div class="ds-label">Plan Type</div>
                <select class="ds-select" id="ds-plan-type" ${mode === "edit" ? "disabled" : ""}>
                  ${supportedPlanTypes.map((pt) => `<option value="${h(pt)}" ${pt === editorState.plan_type ? "selected" : ""}>${h(pt)}</option>`).join("")}
                </select>
              </div>

              <div style="height:12px"></div>
              <div id="ds-steps-container">${stepEditors}</div>

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
        </div>
      </div>
    `;
    host.style.pointerEvents = "auto";

    bindEditor();
    updatePreview();
  }

  function close() {
    host.innerHTML = "";
    host.style.pointerEvents = "none";
  }

  async function onPlanTypeChange() {
    const select = qs("#ds-plan-type");
    const nextType = select?.value;
    if (!nextType || nextType === editorState.plan_type) return;

    editorState.plan_type = nextType;
    const schema = await ensurePlanSchemaLoaded(nextType);
    editorState.step_configs = {};
    for (const [stepType, stepSchema] of Object.entries(schema || {})) {
      editorState.step_configs[stepType] = buildInitialStepValue(stepSchema, undefined);
    }
    renderEditor();
  }

  function updatePreview() {
    const preview = qs("#ds-plan-preview");
    if (!preview) return;
    const name = editorState.name || "(plan_name)";
    preview.textContent = JSON.stringify({
      sleep_plans: {
        [name]: {
          plan_type: editorState.plan_type,
          step_configs: editorState.step_configs,
        },
      },
    }, null, 2);
  }

  function bindEditor() {
    const nameInput = qs("#ds-plan-name");
    const typeSelect = qs("#ds-plan-type");
    const cancelBtn = qs("#ds-plan-cancel");
    const saveBtn = qs("#ds-plan-save");

    host.addEventListener("click", (e) => {
      const t = e.target;
      if (t?.dataset?.backdrop || t?.dataset?.close) close();
    }, { once: true });

    nameInput?.addEventListener("input", () => {
      editorState.name = nameInput.value.trim();
      updatePreview();
    });

    typeSelect?.addEventListener("change", onPlanTypeChange);

    qsa("[data-plan-path]").forEach((el) => {
      el.addEventListener("input", () => {
        const path = el.dataset.planPath;
        const [stepType, fieldName] = path.split(".");
        const planSchema = Store.getState().plansCatalog.planSchemas?.[editorState.plan_type] || {};
        const fieldSchema = planSchema?.[stepType]?.properties?.[fieldName];
        const raw = el.type === "checkbox" ? el.checked : el.value;
        const nextVal = serializeFieldValue(raw, fieldSchema);
        setDeep(editorState.step_configs, path, nextVal);
        updatePreview();
      });
      el.addEventListener("change", () => {
        const path = el.dataset.planPath;
        const [stepType, fieldName] = path.split(".");
        const planSchema = Store.getState().plansCatalog.planSchemas?.[editorState.plan_type] || {};
        const fieldSchema = planSchema?.[stepType]?.properties?.[fieldName];
        const raw = el.type === "checkbox" ? el.checked : el.value;
        const nextVal = serializeFieldValue(raw, fieldSchema);
        setDeep(editorState.step_configs, path, nextVal);
        updatePreview();
      });
    });

    cancelBtn?.addEventListener("click", close);

    saveBtn?.addEventListener("click", async () => {
      try {
        const s = Store.getState();
        if (!editorState.name) throw new Error("Plan name required");

        const cfg = { ...(s.sleepPlans.config || { sleep_plans: {} }) };
        cfg.sleep_plans = { ...(cfg.sleep_plans || {}) };

        cfg.sleep_plans[editorState.name] = {
          plan_type: editorState.plan_type,
          step_configs: editorState.step_configs,
        };

        const saved = await Api.putAccountConfig(s.account.id, cfg);

        Store.setState({
          sleepPlans: {
            config: saved || cfg,
            names: getPlanNames(saved || cfg),
          },
        });

        toast("Sleep Plans", "Saved.");
        close();
        await SleepPlansPage();
      } catch (e) {
        toast("Sleep Plans", e.message || "Save failed");
      }
    });
  }

  renderEditor();
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
      await ensurePlanCatalogLoaded();
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

# ------------------------------------------------------------------
# 7) js/pages/InventoryPage.js
#    - remove Account ID field
#    - remove hint
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/InventoryPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { applyTableFilter } from "../components/TableFilters.js";
import { renderInventoryRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function uniq(arr) {
  const out = [];
  const set = new Set();
  for (const x of arr) {
    const k = String(x || "").trim();
    if (!k || set.has(k)) continue;
    set.add(k);
    out.push(k);
  }
  return out;
}

function renderRegionChips(regions) {
  const list = regions || [];
  if (!list.length) return `<div class="ds-mono-muted" style="padding:6px 0;">No regions selected.</div>`;
  return `
    <div class="ds-row" style="gap:8px;flex-wrap:wrap;">
      ${list.map((r) => `
        <span class="ds-badge" style="gap:10px;">
          <span>${h(r)}</span>
          <button class="ds-btn ds-btn--ghost" type="button" data-region-remove="${h(r)}" style="padding:0 6px;box-shadow:none;">x</button>
        </span>
      `).join("")}
    </div>
  `;
}

function renderTypeChecklist(selectedTypes) {
  const sel = new Set(selectedTypes || []);
  return `
    <div class="ds-panel" style="margin:0;padding:10px;max-height:92px;overflow:auto;">
      <label class="ds-badge" style="gap:10px;display:flex;align-items:center;margin-bottom:8px;">
        <input type="checkbox" class="ds-type-check" value="EKS_CLUSTER" ${sel.has("EKS_CLUSTER") ? "checked" : ""} />
        <span>EKS_CLUSTER</span>
      </label>
      <label class="ds-badge" style="gap:10px;display:flex;align-items:center;">
        <input type="checkbox" class="ds-type-check" value="RDS_INSTANCE" ${sel.has("RDS_INSTANCE") ? "checked" : ""} />
        <span>RDS_INSTANCE</span>
      </label>
    </div>
  `;
}

export async function InventoryPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Discovery / Inventory";

  const initialRegions = uniq(csvToList(s.discovery.regionsCsv || "eu-west-1,eu-central-1,us-east-1"));
  Store.setState({ discovery: { regionsList: initialRegions } });

  page.innerHTML = renderPanel({
    title: "Inventory",
    sub: "Raw discovery via /resources/search. Select rows then Register/Unregister.",
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;align-items:flex-start;">
        <div class="ds-field" style="min-width:340px;flex:1;">
          <div class="ds-label">Regions</div>
          <div class="ds-row" style="gap:10px;">
            <input class="ds-input" id="ds-region-input" placeholder="Type a region and press Add (e.g. eu-west-1)" />
            <button class="ds-btn" id="ds-region-add" type="button">Add</button>
          </div>
          <div style="height:8px"></div>
          <div id="ds-region-chips"></div>
        </div>

        <div class="ds-field" style="min-width:240px;">
          <div class="ds-label">Resource Types</div>
          <div id="ds-types-box"></div>
        </div>

        <div class="ds-row" style="margin-left:auto;align-self:flex-end;">
          <button class="ds-btn" id="ds-inv-run" type="button">Run Search</button>
          <button class="ds-btn ds-btn--wake" id="ds-inv-batch-reg" type="button">Register</button>
          <button class="ds-btn ds-btn--danger" id="ds-inv-batch-unreg" type="button">Unregister</button>
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

  const btnRun = qs("#ds-inv-run");
  const btnReg = qs("#ds-inv-batch-reg");
  const btnUnreg = qs("#ds-inv-batch-unreg");
  const status = qs("#ds-inv-status");

  const regionInput = qs("#ds-region-input");
  const regionAdd = qs("#ds-region-add");
  const chips = qs("#ds-region-chips");
  const typesBox = qs("#ds-types-box");

  function renderRegions() {
    const regions = Store.getState().discovery.regionsList || [];
    chips.innerHTML = renderRegionChips(regions);
    qsa("[data-region-remove]").forEach((b) => {
      b.addEventListener("click", () => {
        const r = b.dataset.regionRemove;
        const next = (Store.getState().discovery.regionsList || []).filter((x) => x !== r);
        Store.setState({ discovery: { regionsList: next, regionsCsv: next.join(",") } });
        renderRegions();
      });
    });
  }

  function renderTypes() {
    const types = Store.getState().discovery.resourceTypes || ["EKS_CLUSTER", "RDS_INSTANCE"];
    typesBox.innerHTML = renderTypeChecklist(types);
    qsa(".ds-type-check", typesBox).forEach((cb) => {
      cb.addEventListener("change", () => {
        const picked = qsa(".ds-type-check", typesBox).filter((x) => x.checked).map((x) => x.value);
        Store.setState({ discovery: { resourceTypes: picked.length ? picked : ["EKS_CLUSTER", "RDS_INSTANCE"] } });
      });
    });
  }

  regionAdd.addEventListener("click", () => {
    const v = (regionInput.value || "").trim();
    if (!v) return;
    const next = uniq([...(Store.getState().discovery.regionsList || []), v]);
    Store.setState({ discovery: { regionsList: next, regionsCsv: next.join(",") } });
    regionInput.value = "";
    renderRegions();
  });

  regionInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      regionAdd.click();
    }
  });

  function readSearchPayload() {
    const accountId = Store.getState().account.id;
    const regions = (Store.getState().discovery.regionsList || []);
    const types = Store.getState().discovery.resourceTypes || ["EKS_CLUSTER", "RDS_INSTANCE"];

    const payload = {
      resource_types: types.length ? types : ["EKS_CLUSTER", "RDS_INSTANCE"],
      regions: regions.length ? regions : null,
      selector_by_type: {},
      only_registered: false,
    };

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
    if (!accountId) return toast("Inventory", "Choose an account from Switch Account first.");
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

    if (!accountId) return toast("Batch", "Choose an account from Switch Account first.");
    if (!selected.length) return toast("Batch", "Select at least one row.");

    const ok = await confirmModal({
      title: mode === "REGISTER" ? "Register selected" : "Unregister selected",
      body: `<div class="ds-mono-muted">Selected: ${selected.length}. This will call /resources/batch-register.</div>`,
      confirmText: mode === "REGISTER" ? "Register" : "Unregister",
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
        only_registered: false,
      },
      mode,
      dry_run: false,
    };

    status.textContent = `${mode}…`;
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

  renderRegions();
  renderTypes();

  if (s.auth.token && s.account.id) runSearch();
}
EOF

# ------------------------------------------------------------------
# 8) js/pages/ActiveResourcesPage.js
#    - remove registered/wake/sleep/unregister badges
#    - remove EKS/RDS plan_name fields
#    - on Sleep click => prompt select relevant sleep plan from account config
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/ActiveResourcesPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { applyTableFilter } from "../components/TableFilters.js";
import { renderActiveRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

function sleepPlanTypeForResource(resourceType) {
  if (resourceType === "EKS_CLUSTER") return "EKS_CLUSTER_SLEEP";
  if (resourceType === "RDS_INSTANCE") return "RDS_SLEEP";
  return null;
}

async function choosePlanForSleep(resourceType) {
  const accountId = Store.getState().account.id;
  const config = await Api.getAccountConfig(accountId);
  const wantedPlanType = sleepPlanTypeForResource(resourceType);

  const plans = Object.entries(config?.sleep_plans || {})
    .filter(([, plan]) => plan?.plan_type === wantedPlanType)
    .map(([name]) => name);

  if (!plans.length) {
    throw new Error(`No available ${wantedPlanType} sleep plan found for this account.`);
  }

  const host = qs("#ds-modalhost");
  if (!host) throw new Error("Modal host not found.");

  return new Promise((resolve) => {
    host.innerHTML = `
      <div class="ds-modalbackdrop" data-backdrop="1"></div>
      <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Choose Sleep Plan">
        <div class="ds-modal__head">
          <div class="ds-modal__title">Choose Sleep Plan</div>
          <button class="ds-btn ds-btn--ghost" type="button" data-close="1">Close</button>
        </div>
        <div class="ds-modal__body">
          <div class="ds-field" style="min-width:unset;">
            <div class="ds-label">Available plans for ${h(resourceType)}</div>
            <select class="ds-select" id="ds-sleep-plan-select">
              ${plans.map((name) => `<option value="${h(name)}">${h(name)}</option>`).join("")}
            </select>
          </div>
        </div>
        <div class="ds-modal__foot">
          <button class="ds-btn ds-btn--ghost" type="button" data-cancel="1">Cancel</button>
          <button class="ds-btn ds-btn--sleep" type="button" data-confirm="1">Sleep</button>
        </div>
      </div>
    `;
    host.style.pointerEvents = "auto";

    const cleanup = (value) => {
      host.innerHTML = "";
      host.style.pointerEvents = "none";
      resolve(value);
    };

    host.addEventListener("click", (e) => {
      const t = e.target;
      if (t?.dataset?.backdrop || t?.dataset?.close || t?.dataset?.cancel) cleanup(null);
      if (t?.dataset?.confirm) {
        const selected = qs("#ds-sleep-plan-select")?.value || null;
        cleanup(selected);
      }
    }, { once: true });
  });
}

export async function ActiveResourcesPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  if (!s.account.id) {
    toast("Account", "Choose an account from Switch Account first.");
    location.hash = "#/discovery";
    return;
  }

  qs("#ds-crumbs").textContent = "Active Resources / Control Panel";

  page.innerHTML = renderPanel({
    title: "Control Panel",
    sub: "Registered resources with one-click Sleep/Wake/Unregister. Polls every 10 seconds and patches only changed rows.",
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;">
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
              <th style="width:320px;">Actions</th>
            </tr>
          </thead>
          <tbody id="ds-cp-tbody"></tbody>
        </table>
      </div>
    `,
  });

  const status = qs("#ds-cp-status");
  const btnRefresh = qs("#ds-cp-refresh");

  async function loadActiveInitial() {
    const accountId = Store.getState().account.id;

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

  function removeRow(key) {
    const tr = document.querySelector(`tr[data-key="${key.replaceAll('"','\\"')}"]`);
    if (tr) tr.remove();
    Store.getState().active.rowsByKey.delete(key);
  }

  function bindActiveRowActions() {
    qsa('[data-action="sleep"], [data-action="wake"], [data-action="unregister"]').forEach((btn) => {
      btn.addEventListener("click", async () => {
        const accountId = Store.getState().account.id;
        const key = btn.dataset.key;
        const row = Store.getState().active.rowsByKey.get(key);
        if (!row) return;

        const action = btn.dataset.action;

        try {
          btn.disabled = true;

          if (action === "unregister") {
            const ok = await confirmModal({
              title: `UNREGISTER ${row.resource_type}`,
              body: `<div class="ds-mono-muted">${row.resource_name} • ${row.region}</div>`,
              confirmText: "Unregister",
              cancelText: "Cancel",
            });
            if (!ok) return;

            if (row.resource_type === "EKS_CLUSTER") {
              await Api.unregisterEKS(accountId, row.resource_name, row.region);
            } else if (row.resource_type === "RDS_INSTANCE") {
              await Api.unregisterRDS(accountId, row.resource_name, row.region);
            }
            toast("Registry", "Unregistered.");
            removeRow(key);
            status.textContent = `OK — ${Store.getState().active.rowsByKey.size} registered resource(s).`;
            return;
          }

          if (action === "sleep") {
            const selectedPlan = await choosePlanForSleep(row.resource_type);
            if (!selectedPlan) return;

            if (row.resource_type === "EKS_CLUSTER") {
              await Api.sleepEKS(accountId, row.resource_name, row.region, selectedPlan);
            } else if (row.resource_type === "RDS_INSTANCE") {
              await Api.sleepRDS(accountId, row.resource_name, row.region, selectedPlan);
            }
            toast("Orchestrator", `Sleep submitted with plan ${selectedPlan}.`);
            return;
          }

          if (action === "wake") {
            const ok = await confirmModal({
              title: `WAKE ${row.resource_type}`,
              body: `<div class="ds-mono-muted">${row.resource_name} • ${row.region}</div>`,
              confirmText: "Wake",
              cancelText: "Cancel",
            });
            if (!ok) return;

            if (row.resource_type === "EKS_CLUSTER") {
              await Api.wakeEKS(accountId, row.resource_name, row.region);
            } else if (row.resource_type === "RDS_INSTANCE") {
              await Api.wakeRDS(accountId, row.resource_name, row.region);
            }
            toast("Orchestrator", "Wake submitted.");
          }
        } catch (e) {
          toast("Action", e.message || "Action failed");
        } finally {
          btn.disabled = false;
        }
      });
    });
  }

  btnRefresh.addEventListener("click", loadActiveInitial);

  await loadActiveInitial();
}
EOF

# ------------------------------------------------------------------
# 9) js/pages/TimePoliciesPage.js
#    Keep single Select button and GET current policy
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/TimePoliciesPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";

const DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
const TYPES = ["EKS_CLUSTER", "RDS_INSTANCE"];

function requireAuthAndAccount() {
  const s = Store.getState();
  if (!s.auth.token) {
    toast("Auth", "Please login.");
    location.hash = "#/login";
    return false;
  }
  if (!s.account.id) {
    toast("Account", "Choose an account from Switch Account first.");
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

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function kvCsvToDict(v) {
  const out = {};
  const parts = csvToList(v);
  for (const p of parts) {
    const i = p.indexOf("=");
    if (i <= 0) continue;
    const k = p.slice(0, i).trim();
    const val = p.slice(i + 1).trim();
    if (k) out[k] = val;
  }
  return out;
}

function dictToKvCsv(d) {
  if (!d || typeof d !== "object") return "";
  return Object.entries(d).map(([k, v]) => `${k}=${v}`).join(", ");
}

function renderDayChecks(win, idx) {
  const days = win.days;
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

function renderSelectorEditor(type, sel) {
  const s = sel || {};
  return `
    <div class="ds-panel" style="margin:0 0 12px 0;">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Selector: ${h(type)}</div>
          <div class="ds-panel__sub">selector_by_type.${h(type)} (names / labels / namespaces)</div>
        </div>
      </div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Names (CSV)</div>
          <input class="ds-input" id="ds-sel-${type}-include-names" value="${h((s.include_names || []).join(","))}" placeholder="name-1,name-2" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Names (CSV)</div>
          <input class="ds-input" id="ds-sel-${type}-exclude-names" value="${h((s.exclude_names || []).join(","))}" placeholder="name-a,name-b" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Labels (CSV key=value)</div>
          <input class="ds-input" id="ds-sel-${type}-include-labels" value="${h(dictToKvCsv(s.include_labels))}" placeholder="env=dev,team=core" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Labels (CSV key=value)</div>
          <input class="ds-input" id="ds-sel-${type}-exclude-labels" value="${h(dictToKvCsv(s.exclude_labels))}" placeholder="tier=prod" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Namespaces (CSV)</div>
          <input class="ds-input" id="ds-sel-${type}-include-ns" value="${h((s.include_namespaces || []).join(","))}" placeholder="ns-a,ns-b" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Namespaces (CSV)</div>
          <input class="ds-input" id="ds-sel-${type}-exclude-ns" value="${h((s.exclude_namespaces || []).join(","))}" placeholder="kube-system,kube-public" />
        </div>
      </div>
    </div>
  `;
}

function readSelectorFromDom(type) {
  const include_names = csvToList(qs(`#ds-sel-${type}-include-names`)?.value);
  const exclude_names = csvToList(qs(`#ds-sel-${type}-exclude-names`)?.value);

  const include_labels = kvCsvToDict(qs(`#ds-sel-${type}-include-labels`)?.value);
  const exclude_labels = kvCsvToDict(qs(`#ds-sel-${type}-exclude-labels`)?.value);

  const include_namespaces_raw = qs(`#ds-sel-${type}-include-ns`)?.value;
  const include_namespaces = String(include_namespaces_raw || "").trim() ? csvToList(include_namespaces_raw) : null;

  const exclude_namespaces = csvToList(qs(`#ds-sel-${type}-exclude-ns`)?.value);

  const out = {
    include_names: include_names.length ? include_names : null,
    exclude_names,
    include_labels,
    exclude_labels,
    include_namespaces,
    exclude_namespaces,
  };

  const hasAny =
    (out.include_names && out.include_names.length) ||
    out.exclude_names.length ||
    Object.keys(out.include_labels).length ||
    Object.keys(out.exclude_labels).length ||
    (out.include_namespaces && out.include_namespaces.length) ||
    out.exclude_namespaces.length;

  return hasAny ? out : null;
}

function readEditorState() {
  const name = (qs("#ds-pol-name")?.value || "").trim();
  if (!name) throw new Error("Policy name required.");

  const enabled = !!qs("#ds-pol-enabled")?.checked;
  const timezone = (qs("#ds-pol-timezone")?.value || "UTC").trim() || "UTC";

  const regionsCsv = (qs("#ds-pol-regions")?.value || "").trim();
  const regions = regionsCsv ? regionsCsv.split(",").map((x) => x.trim()).filter(Boolean) : null;

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

  const windows = Store.getState().policies.editorWindows || [];
  if (!windows.length) throw new Error("Add at least one window.");

  const normalizedWindows = windows.map((w) => ({
    days: (w.days && w.days.length === 7) ? null : (w.days && w.days.length ? w.days : null),
    start: w.start,
    end: w.end,
    start_date: w.start_date || null,
    end_date: w.end_date || null,
  }));

  const selector_by_type = {};
  for (const t of resource_types) {
    const sel = readSelectorFromDom(t);
    if (sel) selector_by_type[t] = sel;
  }

  return {
    name,
    enabled,
    timezone,
    search: {
      resource_types,
      regions,
      only_registered: true,
      selector_by_type,
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
              <input class="ds-input" id="ds-pol-name" placeholder="ex: Dev nights off" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Timezone</div>
              <input class="ds-input" id="ds-pol-timezone" value="UTC" placeholder="UTC / Asia/Jerusalem / Europe/Paris" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-panel" style="margin:0;">
              <div class="ds-panel__head">
                <div>
                  <div class="ds-panel__title">Search</div>
                  <div class="ds-panel__sub">resource_types + optional regions + selector_by_type</div>
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

              <div style="height:12px"></div>

              <div id="ds-selector-container"></div>
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

  const selectorContainer = qs("#ds-selector-container");

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

  if (planNames.length) {
    selPlanEks.value = planNames[0];
    selPlanRds.value = planNames[0];
  }

  Store.setState({
    policies: {
      ...Store.getState().policies,
      editorWindows: [defaultWindow()],
      editorSelectors: { EKS_CLUSTER: {}, RDS_INSTANCE: {} }
    }
  });

  function renderSelectorsFromStore() {
    const selState = Store.getState().policies.editorSelectors || {};
    selectorContainer.innerHTML = `
      ${renderSelectorEditor("EKS_CLUSTER", selState.EKS_CLUSTER)}
      ${renderSelectorEditor("RDS_INSTANCE", selState.RDS_INSTANCE)}
    `;
  }

  function syncSelectorsFromDomToStore() {
    const cur = Store.getState().policies.editorSelectors || {};
    const next = { ...cur };
    for (const t of TYPES) {
      next[t] = readSelectorFromDom(t) || {};
    }
    Store.setState({ policies: { ...Store.getState().policies, editorSelectors: next } });
  }

  function bindSelectorInputs() {
    qsa('#ds-selector-container input').forEach((inp) => {
      inp.addEventListener("input", syncSelectorsFromDomToStore);
    });
  }

  function renderWindows() {
    const windows = Store.getState().policies.editorWindows || [];
    winContainer.innerHTML = renderWindowsEditor(windows);

    qsa("[data-win-remove]").forEach((b) => {
      b.addEventListener("click", () => {
        const idx = Number(b.dataset.winRemove);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins.splice(idx, 1);
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
        renderWindows();
      });
    });

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

    Store.setState({
      policies: {
        ...Store.getState().policies,
        editorWindows: [defaultWindow()],
        editorSelectors: { EKS_CLUSTER: {}, RDS_INSTANCE: {} },
      },
    });

    renderSelectorsFromStore();
    bindSelectorInputs();
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
      b.addEventListener("click", async () => {
        const id = Number(b.dataset.id);
        const s = Store.getState();
        try {
          const p = await Api.getPolicy(s.account.id, id);

          inpSel.value = String(p.id);
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

          const sbt = p.search?.selector_by_type || {};
          Store.setState({
            policies: {
              ...Store.getState().policies,
              editorSelectors: {
                EKS_CLUSTER: sbt.EKS_CLUSTER || {},
                RDS_INSTANCE: sbt.RDS_INSTANCE || {},
              },
            },
          });
          renderSelectorsFromStore();
          bindSelectorInputs();

          toast("Editor", `Loaded policy ${id}.`);
        } catch (e) {
          toast("Time Policies", e.message || "Failed to load policy");
        }
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

  renderSelectorsFromStore();
  bindSelectorInputs();
  renderWindows();
  await loadList();
}
EOF

# ------------------------------------------------------------------
# 10) app.js
#    - ensure account loading hooked to dropdown/user info flow
# ------------------------------------------------------------------
cat > "$ROOT/app.js" <<'EOF'
import { Store } from "./js/store.js";
import { createRouter } from "./js/utils/router.js";
import { createPoller } from "./js/utils/poller.js";
import { qs } from "./js/utils/dom.js";
import { toast } from "./js/utils/toast.js";

import { renderSidebar, setActiveNav } from "./js/components/Sidebar.js";
import { renderHeader } from "./js/components/Header.js";
import { bindUserDropdown, renderUserInfo, loadAccountsIntoDropdown } from "./js/components/UserDropdown.js";
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

async function initialRoute(route) {
  const s = Store.getState();
  const hasToken = !!s.auth.token;

  if (!hasToken && route.name !== "login") {
    location.hash = "#/login";
    return;
  }

  if (hasToken && route.name === "login") {
    location.hash = "#/discovery";
    return;
  }

  if (hasToken) {
    await loadAccountsIntoDropdown();
  }

  Store.setState({ route });
  setActiveNav(route.name);
  router.render(route);

  const input = qs("#ds-global-search");
  if (input) input.value = Store.getState().ui.search || "";
}

router.start((route) => {
  initialRoute(route);
});

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

echo "OK: rewrote store.js"
echo "OK: rewrote js/api/services.js"
echo "OK: rewrote js/components/Header.js"
echo "OK: rewrote js/components/UserDropdown.js"
echo "OK: rewrote js/pages/LoginPage.js"
echo "OK: rewrote js/pages/SleepPlansPage.js"
echo "OK: rewrote js/pages/InventoryPage.js"
echo "OK: rewrote js/pages/ActiveResourcesPage.js"
echo "OK: rewrote js/pages/TimePoliciesPage.js"
echo "OK: rewrote app.js"
echo "Done."
