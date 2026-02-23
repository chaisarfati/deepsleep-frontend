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
