#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

need() { [[ -f "$1" ]] || { echo "ERROR: missing $1"; exit 1; }; }

need "$ROOT/js/api/services.js"
need "$ROOT/js/pages/ActiveResourcesPage.js"
need "$ROOT/js/pages/TimePoliciesPage.js"
need "$ROOT/js/pages/InventoryPage.js"

# -------------------------------------------------------------------
# 0) API services: add missing endpoints
#   - GET /accounts/{account_id}/time-policies/{policy_id}
#   - Unregister endpoints for EKS + RDS
# -------------------------------------------------------------------
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

# -------------------------------------------------------------------
# 1) Active Resources: add Unregister button with confirmation
#   - Add 3rd button per row: Unregister
#   - Calls unregisterEKS/unregisterRDS
#   - After success: remove row + refresh list
# -------------------------------------------------------------------
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
  const unregDisabled = locked; // backend may also refuse if sleeping; we let backend validate

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
          <button class="ds-btn ds-btn--danger" type="button" data-action="unregister" data-key="${h(r.key)}" ${unregDisabled ? "disabled" : ""}>Unregister</button>
        </div>
      </td>
    </tr>
  `;
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
    toast("Setup", "Missing account_id. Backend should provide it in token claims.");
    location.hash = "#/login";
    return;
  }

  qs("#ds-crumbs").textContent = "Active Resources / Control Panel";

  page.innerHTML = renderPanel({
    title: "Control Panel",
    sub: "Registered resources with one-click Sleep/Wake/Unregister. Polls every 10 seconds and patches only changed rows.",
    actionsHtml: `
      <span class="ds-badge ds-badge--reg">Registered</span>
      <span class="ds-badge">Wake: blue</span>
      <span class="ds-badge">Sleep: brick</span>
      <span class="ds-badge">Unregister: danger</span>
    `,
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;">
        <div class="ds-field">
          <div class="ds-label">Account ID</div>
          <input class="ds-input" id="ds-cp-account" inputmode="numeric" value="${s.account.id}" disabled />
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
              <th style="width:320px;">Actions</th>
            </tr>
          </thead>
          <tbody id="ds-cp-tbody"></tbody>
        </table>
      </div>
    `,
  });

  const status = qs("#ds-cp-status");
  const inpPlanEks = qs("#ds-cp-plan-eks");
  const inpPlanRds = qs("#ds-cp-plan-rds");
  const btnRefresh = qs("#ds-cp-refresh");

  function persistControlInputs() {
    const eksPlan = inpPlanEks.value.trim() || "dev";
    const rdsPlan = inpPlanRds.value.trim() || "rds_dev";
    Store.setState({ active: { plans: { EKS_CLUSTER: eksPlan, RDS_INSTANCE: rdsPlan } } });
  }

  async function loadActiveInitial() {
    persistControlInputs();
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
        persistControlInputs();
        const accountId = Store.getState().account.id;
        const key = btn.dataset.key;
        const row = Store.getState().active.rowsByKey.get(key);
        if (!row) return;

        const action = btn.dataset.action;

        const ok = await confirmModal({
          title: `${action.toUpperCase()} ${row.resource_type}`,
          body: `<div class="ds-mono-muted">${row.resource_name} • ${row.region}</div>`,
          confirmText: action === "sleep" ? "Sleep" : (action === "wake" ? "Wake" : "Unregister"),
          cancelText: "Cancel",
        });
        if (!ok) return;

        try {
          btn.disabled = true;

          if (action === "unregister") {
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

          if (row.resource_type === "EKS_CLUSTER") {
            if (action === "sleep") await Api.sleepEKS(accountId, row.resource_name, row.region, Store.getState().active.plans.EKS_CLUSTER);
            else await Api.wakeEKS(accountId, row.resource_name, row.region);
          } else if (row.resource_type === "RDS_INSTANCE") {
            if (action === "sleep") await Api.sleepRDS(accountId, row.resource_name, row.region, Store.getState().active.plans.RDS_INSTANCE);
            else await Api.wakeRDS(accountId, row.resource_name, row.region);
          }

          toast("Orchestrator", "Run submitted. Polling will update state.");
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

# -------------------------------------------------------------------
# 2) Time Policies: keep only "Select" button; on click do GET policy & load into editor
#    Patch: js/pages/TimePoliciesPage.js
# -------------------------------------------------------------------
#need "$ROOT/js/pages/TimePoliciesPage.js"

#perl -0777 -i -pe '
  # Replace the list row render function section by a version with only Select
 # s|return\s*\(list\s*\|\|\s*\[\]\)\.map\(\(p\)\s*=>\s*\{.*?\}\)\.join\(""\);|return (list || []).map((p) => {\n    const next = p.next_transition_at ? fmtTime(p.next_transition_at) : \"—\";\n    return `\n      <tr>\n        <td>${p.id}</td>\n        <td>${h(p.name)}</td>\n        <td>${p.enabled ? `<span class=\"ds-badge ds-badge--reg\">true</span>` : `<span class=\"ds-badge\">false</span>`}</td>\n        <td>${h(p.timezone || \"UTC\")}</td>\n        <td class=\"ds-mono-muted\">${h(next)}</td>\n        <td>\n          <div class=\"ds-row\">\n            <button class=\"ds-btn ds-btn--ghost\" type=\"button\" data-pol=\"select\" data-id=\"${p.id}\">Select</button>\n          </div>\n        </td>\n      </tr>\n    `;\n  }).join(\"\");|s;

  # Remove old bindListActions body and replace with GET+load behavior
  #s|function bindListActions\(\)\s*\{.*?\n\}|function bindListActions() {\n    qsa(\"[data-pol=\\\"select\\\"]\").forEach((b) => {\n      b.addEventListener(\"click\", async () => {\n        const id = Number(b.dataset.id);\n        const s = Store.getState();\n        try {\n          const p = await Api.getPolicy(s.account.id, id);\n\n          inpSel.value = String(p.id);\n          inpName.value = p.name || \"\";\n          chkEnabled.checked = !!p.enabled;\n          inpTz.value = p.timezone || \"UTC\";\n\n          const types = new Set((p.search?.resource_types || []));\n          chkEks.checked = types.has(\"EKS_CLUSTER\");\n          chkRds.checked = types.has(\"RDS_INSTANCE\");\n\n          const regions = p.search?.regions || null;\n          inpRegions.value = Array.isArray(regions) ? regions.join(\",\") : \"\";\n\n          const planByType = p.plan_name_by_type || {};\n          if (planByType.EKS_CLUSTER) selPlanEks.value = planByType.EKS_CLUSTER;\n          if (planByType.RDS_INSTANCE) selPlanRds.value = planByType.RDS_INSTANCE;\n\n          const windows = normalizeWindows(p.windows || []);\n          Store.setState({ policies: { ...Store.getState().policies, editorWindows: windows.length ? windows : [defaultWindow()] } });\n          renderWindows();\n\n          const sbt = p.search?.selector_by_type || {};\n          Store.setState({\n            policies: {\n              ...Store.getState().policies,\n              editorSelectors: {\n                EKS_CLUSTER: sbt.EKS_CLUSTER || {},\n                RDS_INSTANCE: sbt.RDS_INSTANCE || {},\n              },\n            },\n          });\n          renderSelectorsFromStore();\n          bindSelectorInputs();\n\n          toast(\"Editor\", `Loaded policy ${id}.`);\n        } catch (e) {\n          toast(\"Time Policies\", e.message || \"Failed to load policy\");\n        }\n      });\n    });\n  }|s;

#  $_;
#' "$ROOT/js/pages/TimePoliciesPage.js"


need "$ROOT/js/pages/TimePoliciesPage.js"

perl -0777 -i -pe '
  # 1) Remplacement du rendu des lignes (Note les \${...})
  s|return\s*\(list\s*\|\|\s*\[\]\)\.map\(\(p\)\s*=>\s*\{.*?\}\)\.join\(""\);|return (list \|\| []).map((p) => {\n    const next = p.next_transition_at ? fmtTime(p.next_transition_at) : \"—\";\n    return `\n      <tr>\n        <td>\${p.id}</td>\n        <td>\${h(p.name)}</td>\n        <td>\${p.enabled ? `<span class=\"ds-badge ds-badge--reg\">true</span>` : `<span class=\"ds-badge\">false</span>`}</td>\n        <td>\${h(p.timezone \|\| \"UTC\")}</td>\n        <td class=\"ds-mono-muted\">\${h(next)}</td>\n        <td>\n          <div class=\"ds-row\">\n            <button class=\"ds-btn ds-btn--ghost\" type=\"button\" data-pol=\"select\" data-id=\"\${p.id}\">Select</button>\n          </div>\n        </td>\n      </tr>\n    `;\n  }).join(\"\");|s;

  # 2) Remplacement de bindListActions (Note le \${id})
  s|function bindListActions\(\)\s*\{.*?\n\}|function bindListActions() {\n    qsa(\"[data-pol=\\\"select\\\"]\").forEach((b) => {\n      b.addEventListener(\"click\", async () => {\n        const id = Number(b.dataset.id);\n        const s = Store.getState();\n        try {\n          const p = await Api.getPolicy(s.account.id, id);\n\n          inpSel.value = String(p.id);\n          inpName.value = p.name \|\| \"\";\n          chkEnabled.checked = !!p.enabled;\n          inpTz.value = p.timezone \|\| \"UTC\";\n\n          const types = new Set((p.search?.resource_types \|\| []));\n          chkEks.checked = types.has(\"EKS_CLUSTER\");\n          chkRds.checked = types.has(\"RDS_INSTANCE\");\n\n          const regions = p.search?.regions \|\| null;\n          inpRegions.value = Array.isArray(regions) ? regions.join(\",\") : \"\";\n\n          const planByType = p.plan_name_by_type \|\| {};\n          if (planByType.EKS_CLUSTER) selPlanEks.value = planByType.EKS_CLUSTER;\n          if (planByType.RDS_INSTANCE) selPlanRds.value = planByType.RDS_INSTANCE;\n\n          const windows = normalizeWindows(p.windows \|\| []);\n          Store.setState({ policies: { ...Store.getState().policies, editorWindows: windows.length ? windows : [defaultWindow()] } });\n          renderWindows();\n\n          const sbt = p.search?.selector_by_type \|\| {};\n          Store.setState({\n            policies: {\n              ...Store.getState().policies,\n              editorSelectors: {\n                EKS_CLUSTER: sbt.EKS_CLUSTER \|\| {},\n                RDS_INSTANCE: sbt.RDS_INSTANCE \|\| {},\n              },\n            },\n          });\n          renderSelectorsFromStore();\n          bindSelectorInputs();\n\n          toast(\"Editor\", \`Loaded policy \${id}.\`);\n        } catch (e) {\n          toast(\"Time Policies\", e.message \|\| \"Failed to load policy\");\n        }\n      });\n    });\n  }|gs;
' "$ROOT/js/pages/TimePoliciesPage.js"

# -------------------------------------------------------------------
# 3) Inventory:
#   - remove Only Registered dropdown and always send only_registered:false
#   - rename batch buttons: Register/Unregister (same API)
#   - Regions field: chips + add input, send regions array from chips
#   - Resource Types field: checkbox list (scrollable)
# -------------------------------------------------------------------
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

  // regions chips state (UI-only; request uses array)
  const initialRegions = uniq(csvToList(s.discovery.regionsCsv || "eu-west-1,eu-central-1,us-east-1"));
  Store.setState({ discovery: { regionsList: initialRegions } });

  page.innerHTML = renderPanel({
    title: "Inventory",
    sub: "Raw discovery via /resources/search. Select rows then Register/Unregister.",
    actionsHtml: `
      <span class="ds-badge ds-badge--muted">Hint: use global search <span class="ds-kbd">Ctrl</span>+<span class="ds-kbd">F</span> in table</span>
    `,
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;align-items:flex-start;">
        <div class="ds-field">
          <div class="ds-label">Account ID</div>
          <input class="ds-input" id="ds-inv-account" inputmode="numeric" value="${s.account.id || ""}" placeholder="(internal)" disabled />
        </div>

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

    // Requirement: always only_registered = false, remove UI
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
    if (!accountId) return toast("Inventory", "Missing internal account_id.");
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

    if (!accountId) return toast("Batch", "Missing internal account_id.");
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
        only_registered: payload.only_registered, // false (required)
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

  // render initial UI parts
  renderRegions();
  renderTypes();

  // auto-run if logged in and account present
  if (s.auth.token && s.account.id) runSearch();
}
EOF

echo "OK: updated js/api/services.js with getPolicy + unregister endpoints"
echo "OK: updated Active Resources page with Unregister action"
echo "OK: updated Time Policies page Select => GET policy + load"
echo "OK: updated Inventory page (always only_registered=false, Register/Unregister labels, regions chips, types checklist)"
echo "Done."
