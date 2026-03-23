#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

mkdir -p \
  "$ROOT/js/api" \
  "$ROOT/js/components" \
  "$ROOT/js/pages"

need() { [[ -f "$1" ]] || { echo "ERROR: missing $1"; exit 1; }; }

need "$ROOT/js/store.js"
need "$ROOT/js/api/services.js"
need "$ROOT/js/components/Sidebar.js"
need "$ROOT/js/components/UserDropdown.js"
need "$ROOT/js/components/Header.js"
need "$ROOT/js/pages/ActiveResourcesPage.js"
need "$ROOT/js/pages/TimePoliciesPage.js"
need "$ROOT/js/pages/LoginPage.js"
need "$ROOT/app.js"

# ------------------------------------------------------------
# 1) API services
# ------------------------------------------------------------
cat > "$ROOT/js/api/services.js" <<'EOF'
import { request } from "./client.js";

/* Auth */
export const login = (payload) => request("/auth/login", { method: "POST", body: payload });
export const refresh = (payload) => request("/auth/refresh", { method: "POST", body: payload });

/* Accounts */
export const listAccounts = () => request("/accounts");

/* Plan catalog / schemas */
export const getSupportedPlans = () => request("api/v1/plans");
export const getStepSchema = (stepType) => request(`api/v1/schemas/steps/${encodeURIComponent(stepType)}`);
export const getPlanSchema = (planType) => request(`api/v1/schemas/plans/${encodeURIComponent(planType)}`);

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

/* History */
export const listRuns = (accountId, params = {}) =>
  request(`/accounts/${accountId}/runs`, {
    method: "GET",
    query: params,
  });

/* Users */
export const listUsers = () => request("/users");
export const getUser = (userId) => request(`/users/${userId}`);
export const createUser = (body) => request("/users", { method: "POST", body });
export const updateUserRoles = (userId, body) => request(`/users/${userId}/roles`, { method: "PUT", body });
export const updateUserAccounts = (userId, body) => request(`/users/${userId}/accounts`, { method: "PUT", body });
export const deleteUser = (userId) => request(`/users/${userId}`, { method: "DELETE" });
EOF

# ------------------------------------------------------------
# 2) Store
# ------------------------------------------------------------
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
    list: [],
    loaded: false,
  },

  plansCatalog: {
    supported: {},
    planSchemas: {},
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
    editorCriteria: [],
  },

  history: {
    runs: [],
  },

  users: {
    list: [],
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

# ------------------------------------------------------------
# 3) Sidebar
# ------------------------------------------------------------
cat > "$ROOT/js/components/Sidebar.js" <<'EOF'
import { Store } from "../store.js";

function isAdmin() {
  return (Store.getState().auth.roles || []).includes("ADMIN");
}

export function renderSidebar() {
  const admin = isAdmin();

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

      <a class="ds-navlink" href="#/history" data-route="history">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M9 3v6l4 2" fill="none" stroke="currentColor" stroke-width="1.7"/>
            <circle cx="9" cy="9" r="6" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <span class="ds-navlink__label">History</span>
      </a>

      ${admin ? `
      <a class="ds-navlink" href="#/users" data-route="users">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <circle cx="6" cy="7" r="2.2" fill="none" stroke="currentColor" stroke-width="1.5"/>
            <circle cx="12" cy="7" r="2.2" fill="none" stroke="currentColor" stroke-width="1.5"/>
            <path d="M2.8 14c.8-1.8 2.2-2.8 4.2-2.8s3.4 1 4.2 2.8" fill="none" stroke="currentColor" stroke-width="1.5"/>
            <path d="M8.8 14c.7-1.5 1.8-2.3 3.2-2.3 1.4 0 2.5.8 3.2 2.3" fill="none" stroke="currentColor" stroke-width="1.5"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Manage Users</span>
      </a>
      ` : ""}
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

# ------------------------------------------------------------------
# 4) UserDropdown
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

  if (!userchip || !dropdown) return;

  userchip.addEventListener("click", async () => {
    const expanded = userchip.getAttribute("aria-expanded") === "true";
    userchip.setAttribute("aria-expanded", expanded ? "false" : "true");
    dropdown.hidden = expanded;
    if (!expanded) {
      await loadAccountsIntoDropdown();

      const switcher = qs("#ds-account-switch");
      if (switcher && !switcher.dataset.bound) {
        switcher.dataset.bound = "1";
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
    }
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
# 5) ActiveResourcesPage
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
      <div class="ds-modalbackdrop" data-role="close"></div>
      <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Choose Sleep Plan">
        <div class="ds-modal__head">
          <div class="ds-modal__title">Choose Sleep Plan</div>
          <button class="ds-btn ds-btn--ghost" type="button" data-role="close">Close</button>
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
          <button class="ds-btn ds-btn--ghost" type="button" data-role="cancel">Cancel</button>
          <button class="ds-btn ds-btn--sleep" type="button" data-role="confirm">Sleep</button>
        </div>
      </div>
    `;
    host.style.pointerEvents = "auto";

    const close = (value) => {
      host.innerHTML = "";
      host.style.pointerEvents = "none";
      resolve(value);
    };

    const onClick = (e) => {
      const role = e.target?.dataset?.role;
      if (role === "close" || role === "cancel") {
        close(null);
      } else if (role === "confirm") {
        const selected = qs("#ds-sleep-plan-select")?.value || null;
        close(selected);
      }
    };

    host.addEventListener("click", onClick);

    // auto cleanup once resolved
    const originalResolve = resolve;
    resolve = (value) => {
      host.removeEventListener("click", onClick);
      originalResolve(value);
    };
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
# 6) TimePoliciesPage
# ------------------------------------------------------------------
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
    toast("Account", "Choose an account from Switch Account first.");
    return false;
  }
  return true;
}

function timezoneOptions(selected = "UTC") {
  const zones = typeof Intl !== "undefined" && Intl.supportedValuesOf
    ? Intl.supportedValuesOf("timeZone")
    : ["UTC", "Asia/Jerusalem", "Asia/Urumqi", "Europe/Paris", "America/New_York"];
  return zones.map((z) => `<option value="${h(z)}" ${z === selected ? "selected" : ""}>${h(z)}</option>`).join("");
}

function defaultWindow() {
  return { days: ["MON", "TUE", "WED", "THU", "FRI"], start: "21:00", end: "07:00", start_date: null, end_date: null };
}

function defaultCriteria() {
  return {
    resource_type: "EKS_CLUSTER",
    plan_name: "",
    regions: [],
    selector: {
      include_names: [],
      exclude_names: [],
      include_labels: {},
      exclude_labels: {},
      include_namespaces: null,
      exclude_namespaces: [],
    },
  };
}

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function listToCsv(v) {
  return Array.isArray(v) ? v.join(",") : "";
}

function kvCsvToDict(v) {
  const out = {};
  csvToList(v).forEach((p) => {
    const i = p.indexOf("=");
    if (i <= 0) return;
    const k = p.slice(0, i).trim();
    const val = p.slice(i + 1).trim();
    if (k) out[k] = val;
  });
  return out;
}

function dictToKvCsv(d) {
  if (!d || typeof d !== "object") return "";
  return Object.entries(d).map(([k, v]) => `${k}=${v}`).join(", ");
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
  const days = win.days;
  const set = days ? new Set(days) : new Set(DOW);

  return DOW.map((d) => `
    <label class="ds-badge" style="gap:10px;">
      <input type="checkbox" data-win-day="${idx}:${d}" ${set.has(d) ? "checked" : ""} />
      <span>${d}</span>
    </label>
  `).join("");
}

function renderWindowsEditor(windows) {
  if (!windows.length) return `<div class="ds-mono-muted">No windows. Add one.</div>`;

  return windows.map((w, idx) => `
    <div class="ds-panel" style="margin:0 0 12px 0;">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Window #${idx + 1}</div>
          <div class="ds-panel__sub">${h((w.days || DOW).join(","))} • ${h(w.start)} → ${h(w.end)}</div>
        </div>
        <div class="ds-row">
          <button class="ds-btn ds-btn--danger" type="button" data-win-remove="${idx}">Remove</button>
        </div>
      </div>

      <div class="ds-row" style="margin-bottom:10px;flex-wrap:wrap;">
        ${renderDayChecks(w, idx)}
      </div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:180px;">
          <div class="ds-label">Start</div>
          <input class="ds-input" type="time" data-win-start="${idx}" value="${h(w.start)}" />
        </div>
        <div class="ds-field" style="min-width:180px;">
          <div class="ds-label">End</div>
          <input class="ds-input" type="time" data-win-end="${idx}" value="${h(w.end)}" />
        </div>
        <div class="ds-field" style="min-width:180px;">
          <div class="ds-label">Start date</div>
          <input class="ds-input" type="date" data-win-sd="${idx}" value="${h(w.start_date || "")}" />
        </div>
        <div class="ds-field" style="min-width:180px;">
          <div class="ds-label">End date</div>
          <input class="ds-input" type="date" data-win-ed="${idx}" value="${h(w.end_date || "")}" />
        </div>
      </div>
    </div>
  `).join("");
}

function criteriaPlanOptions(resourceType, selected) {
  const cfg = Store.getState().sleepPlans.config?.sleep_plans || {};
  const wantedType = resourceType === "EKS_CLUSTER" ? "EKS_CLUSTER_SLEEP" : "RDS_SLEEP";

  const names = Object.entries(cfg)
    .filter(([, plan]) => plan?.plan_type === wantedType)
    .map(([name]) => name);

  if (!names.length) return `<option value="">(no plan)</option>`;
  return names.map((n) => `<option value="${h(n)}" ${n === selected ? "selected" : ""}>${h(n)}</option>`).join("");
}

function renderCriteriaEditor(criteriaList) {
  if (!criteriaList.length) return `<div class="ds-mono-muted">No search criteria. Add one.</div>`;

  return criteriaList.map((c, idx) => `
    <div class="ds-panel" style="margin:0 0 12px 0;">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Search Criteria #${idx + 1}</div>
          <div class="ds-panel__sub">${h(c.resource_type)}</div>
        </div>
        <div class="ds-row">
          <button class="ds-btn ds-btn--danger" type="button" data-crit-remove="${idx}">Remove</button>
        </div>
      </div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:220px;">
          <div class="ds-label">Resource Type</div>
          <select class="ds-select" data-crit-type="${idx}">
            <option value="EKS_CLUSTER" ${c.resource_type === "EKS_CLUSTER" ? "selected" : ""}>EKS_CLUSTER</option>
            <option value="RDS_INSTANCE" ${c.resource_type === "RDS_INSTANCE" ? "selected" : ""}>RDS_INSTANCE</option>
          </select>
        </div>

        <div class="ds-field" style="min-width:220px;">
          <div class="ds-label">Plan</div>
          <select class="ds-select" data-crit-plan="${idx}">
            ${criteriaPlanOptions(c.resource_type, c.plan_name)}
          </select>
        </div>

        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Regions (CSV)</div>
          <input class="ds-input" data-crit-regions="${idx}" value="${h(listToCsv(c.regions))}" placeholder="eu-west-1,eu-central-1" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Names (CSV)</div>
          <input class="ds-input" data-crit-include-names="${idx}" value="${h(listToCsv(c.selector.include_names))}" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Names (CSV)</div>
          <input class="ds-input" data-crit-exclude-names="${idx}" value="${h(listToCsv(c.selector.exclude_names))}" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Labels (key=value CSV)</div>
          <input class="ds-input" data-crit-include-labels="${idx}" value="${h(dictToKvCsv(c.selector.include_labels))}" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Labels (key=value CSV)</div>
          <input class="ds-input" data-crit-exclude-labels="${idx}" value="${h(dictToKvCsv(c.selector.exclude_labels))}" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Namespaces (CSV)</div>
          <input class="ds-input" data-crit-include-ns="${idx}" value="${h(listToCsv(c.selector.include_namespaces))}" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Namespaces (CSV)</div>
          <input class="ds-input" data-crit-exclude-ns="${idx}" value="${h(listToCsv(c.selector.exclude_namespaces))}" />
        </div>
      </div>
    </div>
  `).join("");
}

async function ensureSleepPlansLoaded() {
  const s = Store.getState();
  if (!s.sleepPlans?.config?.sleep_plans || !Object.keys(s.sleepPlans.config.sleep_plans).length) {
    const cfg = await Api.getAccountConfig(s.account.id);
    Store.setState({
      sleepPlans: {
        config: cfg,
        names: Object.keys(cfg.sleep_plans || {}).sort(),
      },
    });
  }
}

function buildPolicyPayload() {
  const name = (qs("#ds-pol-name")?.value || "").trim();
  if (!name) throw new Error("Policy name required.");

  const enabled = !!qs("#ds-pol-enabled")?.checked;
  const timezone = (qs("#ds-pol-timezone")?.value || "UTC").trim() || "UTC";

  const windows = (Store.getState().policies.editorWindows || []).map((w) => ({
    days: (w.days && w.days.length === 7) ? null : (w.days && w.days.length ? w.days : null),
    start: w.start,
    end: w.end,
    start_date: w.start_date || null,
    end_date: w.end_date || null,
  }));

  if (!windows.length) throw new Error("Add at least one time window.");

  const criteria = Store.getState().policies.editorCriteria || [];
  if (!criteria.length) throw new Error("Add at least one search criteria block.");

  const resource_types = [];
  const selector_by_type = {};
  const plan_name_by_type = {};
  const mergedRegions = new Set();

  for (const c of criteria) {
    resource_types.push(c.resource_type);
    if (c.plan_name) plan_name_by_type[c.resource_type] = c.plan_name;
    (c.regions || []).forEach((r) => mergedRegions.add(r));

    const sel = {
      include_names: c.selector.include_names?.length ? c.selector.include_names : null,
      exclude_names: c.selector.exclude_names || [],
      include_labels: c.selector.include_labels || {},
      exclude_labels: c.selector.exclude_labels || {},
      include_namespaces: c.selector.include_namespaces?.length ? c.selector.include_namespaces : null,
      exclude_namespaces: c.selector.exclude_namespaces || [],
    };
    selector_by_type[c.resource_type] = sel;
  }

  return {
    name,
    enabled,
    timezone,
    search: {
      resource_types: [...new Set(resource_types)],
      regions: mergedRegions.size ? Array.from(mergedRegions) : null,
      selector_by_type,
      only_registered: true,
    },
    windows,
    plan_name_by_type,
  };
}

function openPolicyModal(mode = "new") {
  const host = qs("#ds-modalhost");
  if (!host) return;

  const state = Store.getState();
  const windows = state.policies.editorWindows || [defaultWindow()];
  const criteria = state.policies.editorCriteria || [defaultCriteria()];

  host.innerHTML = `
    <div class="ds-modalbackdrop" data-role="close"></div>
    <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Policy Editor" style="width:min(1200px, calc(100vw - 32px)); max-height:88vh;">
      <div class="ds-modal__head">
        <div class="ds-modal__title">${mode === "edit" ? "Edit Policy" : "New Policy"}</div>
        <button class="ds-btn ds-btn--ghost" type="button" data-role="close">Close</button>
      </div>
      <div class="ds-modal__body">
        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">General</div>
              <div class="ds-panel__sub">Name and timezone</div>
            </div>
          </div>
          <div class="ds-row">
            <div class="ds-field" style="min-width:unset;flex:1;">
              <div class="ds-label">Policy Name</div>
              <input class="ds-input" id="ds-pol-name" value="${h(qs("#ds-pol-name")?.value || "")}" placeholder="Dev nights off" />
            </div>
            <div class="ds-field" style="min-width:280px;">
              <div class="ds-label">Timezone</div>
              <select class="ds-select" id="ds-pol-timezone">
                ${timezoneOptions(qs("#ds-pol-timezone")?.value || "UTC")}
              </select>
            </div>
            <label class="ds-badge" style="gap:10px;align-self:flex-end;">
              <input type="checkbox" id="ds-pol-enabled" ${qs("#ds-pol-enabled")?.checked !== false ? "checked" : ""} />
              <span>Enabled</span>
            </label>
          </div>
        </div>

        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Search</div>
              <div class="ds-panel__sub">Compartmentalized by resource type; merged into one SearchRequest on save</div>
            </div>
            <div class="ds-row">
              <button class="ds-btn ds-btn--wake" id="ds-crit-add" type="button">Add Search Criteria</button>
            </div>
          </div>
          <div id="ds-criteria-container">${renderCriteriaEditor(criteria)}</div>
        </div>

        <div class="ds-panel" style="margin:0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Windows</div>
              <div class="ds-panel__sub">Modern date/time/day editor</div>
            </div>
            <div class="ds-row">
              <button class="ds-btn ds-btn--wake" id="ds-win-add" type="button">Add Window</button>
            </div>
          </div>
          <div id="ds-win-container">${renderWindowsEditor(windows)}</div>
        </div>
      </div>
      <div class="ds-modal__foot">
        <button class="ds-btn ds-btn--ghost" type="button" data-role="cancel">Cancel</button>
        <button class="ds-btn" type="button" id="ds-pol-modal-save">${mode === "edit" ? "Update" : "Create"}</button>
      </div>
    </div>
  `;
  host.style.pointerEvents = "auto";

  const close = () => {
    host.innerHTML = "";
    host.style.pointerEvents = "none";
  };

  host.addEventListener("click", (e) => {
    const role = e.target?.dataset?.role;
    if (role === "close" || role === "cancel") close();
  });

  function rerenderModal(mode2 = mode) {
    openPolicyModal(mode2);
  }

  qsa("[data-win-remove]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const idx = Number(btn.dataset.winRemove);
      const next = [...(Store.getState().policies.editorWindows || [])];
      next.splice(idx, 1);
      Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
      rerenderModal(mode);
    });
  });

  qsa("[data-win-day]").forEach((cb) => {
    cb.addEventListener("change", () => {
      const [idxStr, day] = cb.dataset.winDay.split(":");
      const idx = Number(idxStr);
      const next = [...(Store.getState().policies.editorWindows || [])];
      const set = new Set(next[idx].days || DOW);
      if (cb.checked) set.add(day); else set.delete(day);
      next[idx].days = Array.from(set);
      Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
    });
  });

  qsa("[data-win-start]").forEach((inp) => inp.addEventListener("input", () => {
    const idx = Number(inp.dataset.winStart);
    const next = [...(Store.getState().policies.editorWindows || [])];
    next[idx].start = inp.value;
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
  }));

  qsa("[data-win-end]").forEach((inp) => inp.addEventListener("input", () => {
    const idx = Number(inp.dataset.winEnd);
    const next = [...(Store.getState().policies.editorWindows || [])];
    next[idx].end = inp.value;
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
  }));

  qsa("[data-win-sd]").forEach((inp) => inp.addEventListener("input", () => {
    const idx = Number(inp.dataset.winSd);
    const next = [...(Store.getState().policies.editorWindows || [])];
    next[idx].start_date = inp.value || null;
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
  }));

  qsa("[data-win-ed]").forEach((inp) => inp.addEventListener("input", () => {
    const idx = Number(inp.dataset.winEd);
    const next = [...(Store.getState().policies.editorWindows || [])];
    next[idx].end_date = inp.value || null;
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
  }));

  qs("#ds-win-add")?.addEventListener("click", () => {
    const next = [...(Store.getState().policies.editorWindows || [])];
    next.push(defaultWindow());
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
    rerenderModal(mode);
  });

  qsa("[data-crit-remove]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const idx = Number(btn.dataset.critRemove);
      const next = [...(Store.getState().policies.editorCriteria || [])];
      next.splice(idx, 1);
      Store.setState({ policies: { ...Store.getState().policies, editorCriteria: next } });
      rerenderModal(mode);
    });
  });

  qs("#ds-crit-add")?.addEventListener("click", () => {
    const next = [...(Store.getState().policies.editorCriteria || [])];
    next.push(defaultCriteria());
    Store.setState({ policies: { ...Store.getState().policies, editorCriteria: next } });
    rerenderModal(mode);
  });

  qsa("[data-crit-type]").forEach((sel) => {
    sel.addEventListener("change", () => {
      const idx = Number(sel.dataset.critType);
      const next = [...(Store.getState().policies.editorCriteria || [])];
      next[idx].resource_type = sel.value;
      next[idx].plan_name = "";
      Store.setState({ policies: { ...Store.getState().policies, editorCriteria: next } });
      rerenderModal(mode);
    });
  });

  [
    ["data-crit-plan", "plan_name", (v) => v],
    ["data-crit-regions", "regions", csvToList],
    ["data-crit-include-names", "selector.include_names", csvToList],
    ["data-crit-exclude-names", "selector.exclude_names", csvToList],
    ["data-crit-include-labels", "selector.include_labels", kvCsvToDict],
    ["data-crit-exclude-labels", "selector.exclude_labels", kvCsvToDict],
    ["data-crit-include-ns", "selector.include_namespaces", csvToList],
    ["data-crit-exclude-ns", "selector.exclude_namespaces", csvToList],
  ].forEach(([attr, path, parser]) => {
    qsa(`[${attr}]`).forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.getAttribute(attr));
        const next = [...(Store.getState().policies.editorCriteria || [])];
        const val = parser(inp.value);
        if (path.includes(".")) {
          const [a, b] = path.split(".");
          next[idx][a][b] = val;
        } else {
          next[idx][path] = val;
        }
        Store.setState({ policies: { ...Store.getState().policies, editorCriteria: next } });
      });
    });
  });

  qs("#ds-pol-modal-save")?.addEventListener("click", async () => {
    try {
      const nameInput = qs("#ds-pol-name");
      const tzInput = qs("#ds-pol-timezone");
      const enabledInput = qs("#ds-pol-enabled");

      const shadowName = document.querySelector("#ds-pol-name-shadow");
      if (shadowName) shadowName.value = nameInput.value;

      const basePayload = buildPolicyPayload();
      basePayload.name = nameInput.value.trim();
      basePayload.timezone = tzInput.value;
      basePayload.enabled = enabledInput.checked;

      const accountId = Store.getState().account.id;
      const selectedId = Number(Store.getState().policies.selectedId || 0);

      if (mode === "edit" && selectedId) {
        await Api.updatePolicy(accountId, selectedId, basePayload);
        toast("Time Policies", "Updated.");
      } else {
        await Api.createPolicy(accountId, basePayload);
        toast("Time Policies", "Created.");
      }

      close();
      await TimePoliciesPage();
    } catch (e) {
      toast("Time Policies", e.message || "Save failed");
    }
  });
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
      <input type="hidden" id="ds-pol-name-shadow" value="" />
      <div style="display:grid;grid-template-columns:1fr;">
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
      </div>
    `,
  });

  const status = qs("#ds-pol-status");
  const tbody = qs("#ds-pol-tbody");
  const btnRefresh = qs("#ds-pol-refresh");
  const btnNew = qs("#ds-pol-new");

  if (!requireAuthAndAccount()) {
    status.textContent = "Not ready (missing auth/account).";
    return;
  }

  await ensureSleepPlansLoaded();

  function resetEditorState() {
    Store.setState({
      policies: {
        ...Store.getState().policies,
        selectedId: null,
        editorWindows: [defaultWindow()],
        editorCriteria: [defaultCriteria()],
      },
    });
    const shadow = qs("#ds-pol-name-shadow");
    if (shadow) shadow.value = "";
  }

  async function loadList() {
    try {
      const resp = await Api.listPolicies(Store.getState().account.id);
      const list = resp?.policies || [];
      Store.setState({ policies: { ...Store.getState().policies, list } });

      tbody.innerHTML = list.map((p) => {
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
                <button class="ds-btn ds-btn--ghost" type="button" data-pol-select="${p.id}">Select</button>
                <button class="ds-btn ds-btn--danger" type="button" data-pol-delete="${p.id}">Delete</button>
                <button class="ds-btn ds-btn--sleep" type="button" data-pol-run-sleep="${p.id}">Run SLEEP</button>
                <button class="ds-btn ds-btn--wake" type="button" data-pol-run-wake="${p.id}">Run WAKE</button>
              </div>
            </td>
          </tr>
        `;
      }).join("");

      bindListActions();
      status.textContent = `OK — ${list.length} policy(s).`;
    } catch (e) {
      status.textContent = "Error.";
      toast("Time Policies", e.message || "Load failed");
    }
  }

  function bindListActions() {
    qsa("[data-pol-select]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        try {
          const policyId = Number(btn.dataset.polSelect);
          const accountId = Store.getState().account.id;
          const p = await Api.getPolicy(accountId, policyId);

          const criteria = [];
          const resourceTypes = p.search?.resource_types || [];
          const planByType = p.plan_name_by_type || {};
          const selectorByType = p.search?.selector_by_type || {};
          const mergedRegions = p.search?.regions || [];

          for (const rt of resourceTypes) {
            criteria.push({
              resource_type: rt,
              plan_name: planByType[rt] || "",
              regions: [...mergedRegions],
              selector: {
                include_names: selectorByType[rt]?.include_names || [],
                exclude_names: selectorByType[rt]?.exclude_names || [],
                include_labels: selectorByType[rt]?.include_labels || {},
                exclude_labels: selectorByType[rt]?.exclude_labels || {},
                include_namespaces: selectorByType[rt]?.include_namespaces || [],
                exclude_namespaces: selectorByType[rt]?.exclude_namespaces || [],
              },
            });
          }

          Store.setState({
            policies: {
              ...Store.getState().policies,
              selectedId: policyId,
              editorWindows: normalizeWindows(p.windows || []),
              editorCriteria: criteria.length ? criteria : [defaultCriteria()],
            },
          });

          const shadow = qs("#ds-pol-name-shadow");
          if (shadow) shadow.value = p.name || "";

          openPolicyModal("edit");

          // post-open fill
          setTimeout(() => {
            if (qs("#ds-pol-name")) qs("#ds-pol-name").value = p.name || "";
            if (qs("#ds-pol-timezone")) qs("#ds-pol-timezone").value = p.timezone || "UTC";
            if (qs("#ds-pol-enabled")) qs("#ds-pol-enabled").checked = !!p.enabled;
          }, 0);
        } catch (e) {
          toast("Time Policies", e.message || "Failed to load policy");
        }
      });
    });

    qsa("[data-pol-delete]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polDelete);
        const ok = await confirmModal({
          title: "Delete Policy",
          body: `<div class="ds-mono-muted">Policy <b>${h(String(id))}</b> will be deleted.</div>`,
          confirmText: "Delete",
          cancelText: "Cancel",
        });
        if (!ok) return;

        try {
          await Api.deletePolicy(Store.getState().account.id, id);
          toast("Time Policies", "Deleted.");
          await loadList();
        } catch (e) {
          toast("Time Policies", e.message || "Delete failed");
        }
      });
    });

    qsa("[data-pol-run-sleep]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polRunSleep);
        try {
          await Api.runPolicyNow(Store.getState().account.id, id, "SLEEP");
          toast("Time Policies", "Run-now SLEEP submitted.");
        } catch (e) {
          toast("Time Policies", e.message || "Run-now failed");
        }
      });
    });

    qsa("[data-pol-run-wake]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polRunWake);
        try {
          await Api.runPolicyNow(Store.getState().account.id, id, "WAKE");
          toast("Time Policies", "Run-now WAKE submitted.");
        } catch (e) {
          toast("Time Policies", e.message || "Run-now failed");
        }
      });
    });
  }

  btnRefresh?.addEventListener("click", loadList);
  btnNew?.addEventListener("click", () => {
    resetEditorState();
    openPolicyModal("new");
  });

  await loadList();
}
EOF

# ------------------------------------------------------------------
# 7) New page: HistoryPage
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/HistoryPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { fmtTime } from "../utils/time.js";
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

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function renderSteps(steps) {
  const arr = Array.isArray(steps) ? steps : [];
  if (!arr.length) return `<div class="ds-mono-muted">No steps</div>`;

  return `
    <div class="ds-tablewrap" style="margin-top:8px;">
      <table class="ds-table" style="min-width:700px;">
        <thead>
          <tr>
            <th>ID</th>
            <th>Type</th>
            <th>Order</th>
            <th>State</th>
            <th>Error</th>
            <th>Started</th>
            <th>Finished</th>
          </tr>
        </thead>
        <tbody>
          ${arr.map((s) => `
            <tr>
              <td>${s.id}</td>
              <td>${h(s.step_type)}</td>
              <td>${s.order_index}</td>
              <td>${h(s.state)}</td>
              <td class="ds-mono-muted">${h(s.error || "—")}</td>
              <td>${s.started_at ? h(fmtTime(s.started_at)) : "—"}</td>
              <td>${s.finished_at ? h(fmtTime(s.finished_at)) : "—"}</td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    </div>
  `;
}

export async function HistoryPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "History";

  page.innerHTML = renderPanel({
    title: "History",
    sub: "Run history across your resources with filters on dates, regions and resource types.",
    bodyHtml: `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head">
          <div>
            <div class="ds-panel__title">Filters</div>
            <div class="ds-panel__sub">Call GET /accounts/{account_id}/runs with all supported query params</div>
          </div>
        </div>

        <div class="ds-row">
          <div class="ds-field" style="min-width:220px;">
            <div class="ds-label">From date</div>
            <input class="ds-input" id="ds-h-from" type="datetime-local" />
          </div>
          <div class="ds-field" style="min-width:220px;">
            <div class="ds-label">To date</div>
            <input class="ds-input" id="ds-h-to" type="datetime-local" />
          </div>
          <div class="ds-field" style="min-width:unset;flex:1;">
            <div class="ds-label">Regions (CSV)</div>
            <input class="ds-input" id="ds-h-regions" placeholder="eu-west-1,eu-central-1" />
          </div>
          <div class="ds-field" style="min-width:unset;flex:1;">
            <div class="ds-label">Resource types (CSV)</div>
            <input class="ds-input" id="ds-h-types" placeholder="EKS_CLUSTER,RDS_INSTANCE" />
          </div>
          <div class="ds-row" style="align-self:flex-end;">
            <button class="ds-btn" id="ds-h-run" type="button">Load History</button>
          </div>
        </div>
      </div>

      <div class="ds-mono-muted" id="ds-h-status">—</div>
      <div style="height:10px"></div>
      <div id="ds-h-results"></div>
    `,
  });

  if (!requireAuthAndAccount()) {
    qs("#ds-h-status").textContent = "Not ready.";
    return;
  }

  const status = qs("#ds-h-status");
  const results = qs("#ds-h-results");

  async function loadHistory() {
    try {
      const accountId = Store.getState().account.id;
      const from_date = qs("#ds-h-from")?.value || "";
      const to_date = qs("#ds-h-to")?.value || "";
      const regions = csvToList(qs("#ds-h-regions")?.value);
      const resource_types = csvToList(qs("#ds-h-types")?.value);

      const params = {};
      if (from_date) params.from_date = new Date(from_date).toISOString();
      if (to_date) params.to_date = new Date(to_date).toISOString();
      if (regions.length) params.regions = regions;
      if (resource_types.length) params.resource_types = resource_types;

      status.textContent = "Loading…";

      const runs = await Api.listRuns(accountId, params);
      Store.setState({ history: { runs } });

      status.textContent = `OK — ${runs.length} run(s).`;

      results.innerHTML = runs.map((run) => `
        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Run #${run.id} • ${h(run.resource_type)} • ${h(run.resource_name)}</div>
              <div class="ds-panel__sub">
                ${h(run.region)} • ${h(run.action)} • ${h(run.state)}
                • created ${h(fmtTime(run.created_at))}
              </div>
            </div>
          </div>

          <div class="ds-row" style="margin-bottom:8px;">
            <span class="ds-badge">Started: ${run.started_at ? h(fmtTime(run.started_at)) : "—"}</span>
            <span class="ds-badge">Finished: ${run.finished_at ? h(fmtTime(run.finished_at)) : "—"}</span>
            <span class="ds-badge">Error: ${h(run.error || "—")}</span>
          </div>

          ${renderSteps(run.steps)}
        </div>
      `).join("") || `<div class="ds-mono-muted">No runs found.</div>`;
    } catch (e) {
      status.textContent = "Error.";
      toast("History", e.message || "Load failed");
    }
  }

  qs("#ds-h-run")?.addEventListener("click", loadHistory);
  await loadHistory();
}
EOF

# ------------------------------------------------------------------
# 8) New page: ManageUsersPage
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/ManageUsersPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { fmtTime } from "../utils/time.js";
import * as Api from "../api/services.js";

function requireAdmin() {
  const s = Store.getState();
  if (!s.auth.token) {
    toast("Auth", "Please login.");
    location.hash = "#/login";
    return false;
  }
  if (!(s.auth.roles || []).includes("ADMIN")) {
    toast("Users", "Admin only.");
    location.hash = "#/discovery";
    return false;
  }
  return true;
}

function renderUsersTable(users) {
  const list = Array.isArray(users) ? users : [];
  if (!list.length) return `<div class="ds-mono-muted">No users.</div>`;

  return `
    <div class="ds-tablewrap">
      <table class="ds-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Email</th>
            <th>Roles</th>
            <th>Accounts</th>
            <th>Active</th>
            <th>Created</th>
            <th>Updated</th>
            <th style="width:260px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          ${list.map((u) => `
            <tr>
              <td>${u.id}</td>
              <td>${h(u.email)}</td>
              <td>${h((u.roles || []).join(","))}</td>
              <td>${h((u.account_ids || []).join(","))}</td>
              <td>${u.is_active ? "true" : "false"}</td>
              <td>${h(fmtTime(u.created_at))}</td>
              <td>${h(fmtTime(u.updated_at))}</td>
              <td>
                <div class="ds-row">
                  <button class="ds-btn ds-btn--ghost" type="button" data-user-edit="${u.id}">Edit</button>
                  <button class="ds-btn ds-btn--danger" type="button" data-user-delete="${u.id}">Delete</button>
                </div>
              </td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    </div>
  `;
}

function buildAccountOptions(selectedIds) {
  const selected = new Set(selectedIds || []);
  const accounts = Store.getState().accounts.list || [];
  return accounts.map((acc) => `
    <label class="ds-badge" style="gap:10px;">
      <input type="checkbox" data-user-account="${acc.id}" ${selected.has(acc.id) ? "checked" : ""} />
      <span>${h(acc.aws_account_id || String(acc.id))}</span>
    </label>
  `).join("");
}

function openUserModal(mode, user = null) {
  const host = qs("#ds-modalhost");
  if (!host) return;

  const roles = new Set(user?.roles || []);
  const accountIds = user?.account_ids || [];

  host.innerHTML = `
    <div class="ds-modalbackdrop" data-role="close"></div>
    <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Manage User" style="width:min(980px, calc(100vw - 32px)); max-height:88vh;">
      <div class="ds-modal__head">
        <div class="ds-modal__title">${mode === "edit" ? `Edit User #${user.id}` : "Create User"}</div>
        <button class="ds-btn ds-btn--ghost" type="button" data-role="close">Close</button>
      </div>
      <div class="ds-modal__body">
        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Identity</div>
              <div class="ds-panel__sub">Business user + auth microservice projection</div>
            </div>
          </div>

          <div class="ds-row">
            <div class="ds-field" style="min-width:unset;flex:1;">
              <div class="ds-label">Business ID</div>
              <input class="ds-input" id="ds-user-business-id" value="${h(Store.getState().auth.business_id || "")}" ${mode === "edit" ? "disabled" : ""} />
            </div>
            <div class="ds-field" style="min-width:unset;flex:1;">
              <div class="ds-label">Email</div>
              <input class="ds-input" id="ds-user-email" value="${h(user?.email || "")}" ${mode === "edit" ? "disabled" : ""} />
            </div>
            ${mode === "create" ? `
            <div class="ds-field" style="min-width:unset;flex:1;">
              <div class="ds-label">Password</div>
              <input class="ds-input" id="ds-user-password" type="password" value="" />
            </div>
            ` : ""}
          </div>
        </div>

        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Roles</div>
            </div>
          </div>
          <div class="ds-row">
            <label class="ds-badge" style="gap:10px;">
              <input type="checkbox" id="ds-user-role-standard" ${roles.has("STANDARD") ? "checked" : ""} />
              <span>STANDARD</span>
            </label>
            <label class="ds-badge" style="gap:10px;">
              <input type="checkbox" id="ds-user-role-admin" ${roles.has("ADMIN") ? "checked" : ""} />
              <span>ADMIN</span>
            </label>
          </div>
        </div>

        <div class="ds-panel" style="margin:0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Accounts Access</div>
            </div>
          </div>
          <div class="ds-row" style="flex-wrap:wrap;">
            ${buildAccountOptions(accountIds)}
          </div>
        </div>
      </div>
      <div class="ds-modal__foot">
        <button class="ds-btn ds-btn--ghost" type="button" data-role="cancel">Cancel</button>
        <button class="ds-btn" type="button" id="ds-user-save">${mode === "edit" ? "Save" : "Create"}</button>
      </div>
    </div>
  `;
  host.style.pointerEvents = "auto";

  const close = () => {
    host.innerHTML = "";
    host.style.pointerEvents = "none";
  };

  host.addEventListener("click", (e) => {
    const role = e.target?.dataset?.role;
    if (role === "close" || role === "cancel") close();
  });

  qs("#ds-user-save")?.addEventListener("click", async () => {
    try {
      const rolesOut = [];
      if (qs("#ds-user-role-standard")?.checked) rolesOut.push("STANDARD");
      if (qs("#ds-user-role-admin")?.checked) rolesOut.push("ADMIN");

      const account_ids = qsa("[data-user-account]").filter((x) => x.checked).map((x) => Number(x.dataset.userAccount));
      const business_id = Number(qs("#ds-user-business-id")?.value || 0);

      if (mode === "create") {
        const payload = {
          business_id,
          email: (qs("#ds-user-email")?.value || "").trim(),
          password: qs("#ds-user-password")?.value || "",
          roles: rolesOut,
          account_ids,
        };
        await Api.createUser(payload);
        toast("Users", "Created.");
      } else {
        await Api.updateUserRoles(user.id, { roles: rolesOut });
        await Api.updateUserAccounts(user.id, { account_ids });
        toast("Users", "Updated.");
      }

      close();
      await ManageUsersPage();
    } catch (e) {
      toast("Users", e.message || "Save failed");
    }
  });
}

export async function ManageUsersPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Manage Users";

  page.innerHTML = renderPanel({
    title: "Manage Users",
    sub: "Admin-only interface to create, inspect, update roles/accounts and delete business users.",
    actionsHtml: `
      <button class="ds-btn" id="ds-users-refresh" type="button">Refresh</button>
      <button class="ds-btn ds-btn--wake" id="ds-users-new" type="button">Create User</button>
    `,
    bodyHtml: `
      <div class="ds-mono-muted" id="ds-users-status">—</div>
      <div style="height:10px"></div>
      <div id="ds-users-results"></div>
    `,
  });

  if (!requireAdmin()) {
    qs("#ds-users-status").textContent = "Not allowed.";
    return;
  }

  const status = qs("#ds-users-status");
  const results = qs("#ds-users-results");

  async function loadUsers() {
    try {
      status.textContent = "Loading…";
      const resp = await Api.listUsers();
      const users = resp?.users || [];
      Store.setState({ users: { list: users } });
      results.innerHTML = renderUsersTable(users);
      status.textContent = `OK — ${users.length} user(s).`;
      bindActions();
    } catch (e) {
      status.textContent = "Error.";
      toast("Users", e.message || "Load failed");
    }
  }

  function bindActions() {
    qsa("[data-user-edit]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        try {
          const userId = Number(btn.dataset.userEdit);
          const user = await Api.getUser(userId);
          openUserModal("edit", user);
        } catch (e) {
          toast("Users", e.message || "Failed to load user");
        }
      });
    });

    qsa("[data-user-delete]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const userId = Number(btn.dataset.userDelete);
        const ok = await confirmModal({
          title: "Delete User",
          body: `<div class="ds-mono-muted">Delete user #${userId} ?</div>`,
          confirmText: "Delete",
          cancelText: "Cancel",
        });
        if (!ok) return;

        try {
          await Api.deleteUser(userId);
          toast("Users", "Deleted.");
          await loadUsers();
        } catch (e) {
          toast("Users", e.message || "Delete failed");
        }
      });
    });
  }

  qs("#ds-users-refresh")?.addEventListener("click", loadUsers);
  qs("#ds-users-new")?.addEventListener("click", () => openUserModal("create"));

  await loadUsers();
}
EOF

# ------------------------------------------------------------------
# 9) app.js
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
import { HistoryPage } from "./js/pages/HistoryPage.js";
import { ManageUsersPage } from "./js/pages/ManageUsersPage.js";

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
router.register("history", async () => HistoryPage());
router.register("users", async () => ManageUsersPage());

async function rerenderSidebar() {
  const rail = qs("#ds-rail");
  if (rail) rail.innerHTML = renderSidebar();
}

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

  await rerenderSidebar();

  Store.setState({ route });
  setActiveNav(route.name);
  router.render(route);

  const input = qs("#ds-global-search");
  if (input) input.value = Store.getState().ui.search || "";
}

router.start((route) => {
  initialRoute(route);
});

/* ---------- Polling ---------- */
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

echo "OK: rewrote js/api/services.js"
echo "OK: rewrote js/store.js"
echo "OK: rewrote js/components/Sidebar.js"
echo "OK: rewrote js/components/UserDropdown.js"
echo "OK: rewrote js/pages/LoginPage.js"
echo "OK: rewrote js/pages/SleepPlansPage.js"
echo "OK: rewrote js/pages/ActiveResourcesPage.js"
echo "OK: rewrote js/pages/TimePoliciesPage.js"
echo "OK: created js/pages/HistoryPage.js"
echo "OK: created js/pages/ManageUsersPage.js"
echo "OK: rewrote app.js"
echo "Done."
