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
