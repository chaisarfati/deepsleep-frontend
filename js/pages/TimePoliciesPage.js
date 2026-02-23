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
