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
          <input class="ds-input" id="ds-inv-account" inputmode="numeric" value="${s.account.id || ""}" placeholder="(internal)" />
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
  // read from input first (user can override), fallback to store
  const accountIdFromInput = (qs("#ds-inv-account")?.value || "").trim();
  const accountId = accountIdFromInput || Store.getState().account.id;

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
