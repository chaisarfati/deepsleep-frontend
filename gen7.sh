#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

mkdir -p \
  "$ROOT/js/api" \
  "$ROOT/js/components" \
  "$ROOT/js/pages"

need() { [[ -f "$1" ]] || { echo "ERROR: missing $1"; exit 1; }; }

need "$ROOT/js/api/services.js"
need "$ROOT/js/components/ResourceRow.js"
need "$ROOT/js/pages/ActiveResourcesPage.js"

# ------------------------------------------------------------------
# 1) js/api/services.js
#    - add missing EKS price endpoint
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

/* EKS price / savings */
export const getEksClusterPrice = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/price`, {
    method: "GET",
    query: { region },
  });

export const getEksClusterPriceSavings = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/price-savings`, {
    method: "GET",
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

/* RDS price / savings */
export const getRdsInstancePrice = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/price`, {
    method: "GET",
    query: { region },
  });

export const getRdsInstancePriceSavings = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/price-savings`, {
    method: "GET",
    query: { region },
  });

/* Account aggregated savings */
export const getAccountPriceSavings = (accountId, body) =>
  request(`/accounts/${accountId}/price-savings`, {
    method: "POST",
    body,
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

# ------------------------------------------------------------------
# 2) js/components/ResourceRow.js
#    - rename columns semantics to:
#      Cost of Compute / Savings in Compute
#    - keep placeholders while async pricing fills later
# ------------------------------------------------------------------
cat > "$ROOT/js/components/ResourceRow.js" <<'EOF'
import { escapeHtml as h } from "../utils/dom.js";
import { renderStatePill } from "./Pills.js";
import { fmtTime } from "../utils/time.js";

function fmtMoneyPerHour(v) {
  if (v === null || v === undefined || v === "") return "—";
  const n = Number(v);
  if (!Number.isFinite(n)) return "—";
  return `$${n}/hour`;
}

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
  const unregDisabled = locked;

  return `
    <tr data-key="${h(r.key)}" data-hay="${h(hay)}">
      <td>${h(r.resource_type)}</td>
      <td>${h(r.resource_name)}</td>
      <td>${h(r.region)}</td>
      <td data-col="observed">${observed}</td>
      <td data-col="desired">${h(desired)}</td>
      <td data-col="compute-cost">${h(fmtMoneyPerHour(r.compute_cost_estimation))}</td>
      <td data-col="compute-savings">${h(fmtMoneyPerHour(r.compute_savings_estimation))}</td>
      <td data-col="last">${h(last)}</td>
      <td data-col="updated">${h(updated)}</td>
      <td>
        <div class="ds-row">
          <button class="ds-btn ds-btn--sleep" type="button" data-action="sleep" data-key="${h(r.key)}" ${sleepDisabled ? "disabled" : ""}>Sleep</button>
          <button class="ds-btn ds-btn--wake" type="button" data-action="wake" data-key="${h(r.key)}" ${wakeDisabled ? "disabled" : ""}>Wake</button>
          <button class="ds-btn ds-btn--danger" type="button" data-action="unregister" data-key="${h(r.key)}" ${unregDisabled ? "disabled" : ""}>Unregister</button>
        </div>
      </td>
    </tr>
  `;
}
EOF

# ------------------------------------------------------------------
# 3) js/pages/ActiveResourcesPage.js
#    - render base rows first
#    - then asynchronously fetch price + price-savings and patch only those cells
#    - rename headers to Cost of Compute / Savings in Compute
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

function fmtMoneyPerHour(v) {
  if (v === null || v === undefined || v === "") return "—";
  const n = Number(v);
  if (!Number.isFinite(n)) return "—";
  return `$${n}/hour`;
}

function patchPricingCells(key, cost, savings) {
  const tr = document.querySelector(`tr[data-key="${key.replaceAll('"','\\"')}"]`);
  if (!tr) return;

  const costTd = tr.querySelector('td[data-col="compute-cost"]');
  const savingsTd = tr.querySelector('td[data-col="compute-savings"]');

  if (costTd) costTd.textContent = fmtMoneyPerHour(cost);
  if (savingsTd) savingsTd.textContent = fmtMoneyPerHour(savings);
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

    const onClick = (e) => {
      const role = e.target?.dataset?.role;
      if (role === "close" || role === "cancel") {
        cleanup(null);
      } else if (role === "confirm") {
        const selected = qs("#ds-sleep-plan-select")?.value || null;
        cleanup(selected);
      }
    };

    const cleanup = (value) => {
      host.removeEventListener("click", onClick);
      host.innerHTML = "";
      host.style.pointerEvents = "none";
      resolve(value);
    };

    host.addEventListener("click", onClick);
  });
}

async function fetchRowPricing(row) {
  const accountId = Store.getState().account.id;

  try {
    if (row.resource_type === "EKS_CLUSTER") {
      const [priceResp, savingsResp] = await Promise.all([
        Api.getEksClusterPrice(accountId, row.resource_name, row.region).catch(() => null),
        Api.getEksClusterPriceSavings(accountId, row.resource_name, row.region).catch(() => null),
      ]);

      const cost = Number(priceResp?.hourly_price);
      const savings = Number(savingsResp?.hourly_savings);

      row.compute_cost_estimation = Number.isFinite(cost) ? cost : null;
      row.compute_savings_estimation = Number.isFinite(savings) ? savings : null;
      patchPricingCells(row.key, row.compute_cost_estimation, row.compute_savings_estimation);
      return;
    }

    if (row.resource_type === "RDS_INSTANCE") {
      const [priceResp, savingsResp] = await Promise.all([
        Api.getRdsInstancePrice(accountId, row.resource_name, row.region).catch(() => null),
        Api.getRdsInstancePriceSavings(accountId, row.resource_name, row.region).catch(() => null),
      ]);

      const cost = Number(priceResp?.hourly_price);
      const savings = Number(savingsResp?.hourly_savings);

      row.compute_cost_estimation = Number.isFinite(cost) ? cost : null;
      row.compute_savings_estimation = Number.isFinite(savings) ? savings : null;
      patchPricingCells(row.key, row.compute_cost_estimation, row.compute_savings_estimation);
    }
  } catch {
    row.compute_cost_estimation = null;
    row.compute_savings_estimation = null;
    patchPricingCells(row.key, null, null);
  }
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
              <th>Cost of Compute</th>
              <th>Savings in Compute</th>
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

      const rows = [];

      for (const c of (eks.clusters || [])) {
        rows.push({
          key: `EKS_CLUSTER|${c.cluster_name}|${c.region}`,
          resource_type: "EKS_CLUSTER",
          resource_name: c.cluster_name,
          region: c.region,
          observed_state: c.observed_state,
          desired_state: c.desired_state,
          last_action: c.last_action,
          last_action_at: c.last_action_at,
          locked_until: c.locked_until,
          updated_at: c.updated_at,
          compute_cost_estimation: null,
          compute_savings_estimation: null,
        });
      }

      for (const r of (rds.instances || [])) {
        rows.push({
          key: `RDS_INSTANCE|${r.db_instance_id}|${r.region}`,
          resource_type: "RDS_INSTANCE",
          resource_name: r.db_instance_id,
          region: r.region,
          observed_state: r.observed_state,
          desired_state: r.desired_state,
          last_action: r.last_action,
          last_action_at: r.last_action_at,
          locked_until: r.locked_until,
          updated_at: r.updated_at,
          compute_cost_estimation: null,
          compute_savings_estimation: null,
        });
      }

      // 1) populate base info immediately
      const map = new Map();
      for (const row of rows) {
        map.set(row.key, row);
      }

      Store.getState().active.rowsByKey = map;
      renderActiveTable(map);
      status.textContent = `OK — ${map.size} registered resource(s).`;

      applyTableFilter('[data-table="active"]', Store.getState().ui.search);

      // 2) populate pricing asynchronously afterwards
      for (const row of rows) {
        fetchRowPricing(row);
      }
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

echo "OK: rewrote js/api/services.js"
echo "OK: rewrote js/components/ResourceRow.js"
echo "OK: rewrote js/pages/ActiveResourcesPage.js"
echo "Done."