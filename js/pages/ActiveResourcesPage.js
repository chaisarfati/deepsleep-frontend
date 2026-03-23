import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { applyTableFilter } from "../components/TableFilters.js";
import { renderActiveRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

const PRICING_TTL_MS = 60 * 60 * 1000;
const pricingCache = new Map();
let activeRenderToken = 0;

function sleepPlanTypeForResource(resourceType) {
  if (resourceType === "EKS_CLUSTER") return "EKS_CLUSTER_SLEEP";
  if (resourceType === "RDS_INSTANCE") return "RDS_SLEEP";
  return null;
}

function pricingKey(row) {
  return `${row.resource_type}|${row.resource_name}|${row.region}`;
}

function fmtMoneyPerHour(v) {
  if (v === null || v === undefined || v === "") return "—";
  const n = Number(v);
  if (!Number.isFinite(n)) return "—";
  return `$${n}/hour`;
}

function getCachedPricing(row) {
  const cached = pricingCache.get(pricingKey(row));
  if (!cached) return null;
  if ((Date.now() - cached.ts) > PRICING_TTL_MS) return null;
  return cached;
}

function setCachedPricing(row, cost, savings) {
  pricingCache.set(pricingKey(row), {
    cost,
    savings,
    ts: Date.now(),
  });
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

async function fetchPricingForRow(row) {
  const accountId = Store.getState().account.id;

  if (row.resource_type === "EKS_CLUSTER") {
    const priceResp = await Api.getEksClusterPrice(accountId, row.resource_name, row.region).catch(() => null);
    let savingsResp = null;

    if (String(row.observed_state || "").toUpperCase() === "SLEEPING") {
      savingsResp = await Api.getEksClusterPriceSavings(accountId, row.resource_name, row.region).catch(() => null);
    }

    const cost = Number(priceResp?.hourly_price);
    const savings = Number(savingsResp?.hourly_savings);

    return {
      cost: Number.isFinite(cost) ? cost : null,
      savings: Number.isFinite(savings) ? savings : null,
    };
  }

  if (row.resource_type === "RDS_INSTANCE") {
    const priceResp = await Api.getRdsInstancePrice(accountId, row.resource_name, row.region).catch(() => null);
    let savingsResp = null;

    if (String(row.observed_state || "").toUpperCase() === "SLEEPING") {
      savingsResp = await Api.getRdsInstancePriceSavings(accountId, row.resource_name, row.region).catch(() => null);
    }

    const cost = Number(priceResp?.hourly_price);
    const savings = Number(savingsResp?.hourly_savings);

    return {
      cost: Number.isFinite(cost) ? cost : null,
      savings: Number.isFinite(savings) ? savings : null,
    };
  }

  return { cost: null, savings: null };
}

function schedulePricingHydration(rows, renderToken) {
  const queue = [...rows];
  const concurrency = Math.min(4, Math.max(1, queue.length));

  const worker = async () => {
    while (queue.length) {
      const row = queue.shift();
      if (!row) return;
      if (renderToken !== activeRenderToken) return;

      const cached = getCachedPricing(row);
      if (cached) {
        row.compute_cost_estimation = cached.cost;
        row.compute_savings_estimation = cached.savings;
        patchPricingCells(row.key, cached.cost, cached.savings);
        continue;
      }

      if (renderToken !== activeRenderToken) return;

      try {
        const result = await fetchPricingForRow(row);
        row.compute_cost_estimation = result.cost;
        row.compute_savings_estimation = result.savings;
        setCachedPricing(row, result.cost, result.savings);

        if (renderToken === activeRenderToken) {
          patchPricingCells(row.key, result.cost, result.savings);
        }
      } catch {
        row.compute_cost_estimation = null;
        row.compute_savings_estimation = null;
        if (renderToken === activeRenderToken) {
          patchPricingCells(row.key, null, null);
        }
      }
    }
  };

  for (let i = 0; i < concurrency; i += 1) {
    setTimeout(() => { worker(); }, 0);
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
    sub: "Registered resources with one-click Sleep/Wake/Unregister.",
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
    const renderToken = ++activeRenderToken;

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

      const map = new Map();
      for (const row of rows) {
        const cached = getCachedPricing(row);
        if (cached) {
          row.compute_cost_estimation = cached.cost;
          row.compute_savings_estimation = cached.savings;
        }
        map.set(row.key, row);
      }

      Store.getState().active.rowsByKey = map;
      renderActiveTable(map);
      status.textContent = `OK — ${map.size} registered resource(s).`;

      applyTableFilter('[data-table="active"]', Store.getState().ui.search);

      setTimeout(() => {
        if (renderToken === activeRenderToken) {
          schedulePricingHydration(rows, renderToken);
        }
      }, 0);
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
