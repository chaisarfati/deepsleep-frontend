import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderInventoryRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

const RESOURCE_TYPES = ["EKS_CLUSTER", "RDS_INSTANCE", "EC2_INSTANCE"];

function csvToList(v) {
  return String(v || "").split(",").map((s) => s.trim()).filter(Boolean);
}

function uniq(arr) {
  return [...new Set(arr.map((x) => String(x).trim()).filter(Boolean))];
}

function buildResourceKey(r) {
  return `${r.resource_type}|${r.resource_name}|${r.region}`;
}

function normalizeResources(resources) {
  return (resources || []).map((r) => ({
    key: buildResourceKey(r),
    resource_type: r.resource_type,
    resource_name: r.resource_name,
    region: r.region,
    labels: r.labels || {},
    registered: !!r.registered,
    observed_state: r.observed_state || null,
    desired_state: r.desired_state || null,
  }));
}

/**
 * Filter resources client-side by active tab and search text.
 * Tabs filter by resource_type; search filters by name + label values.
 */
function getFilteredResources() {
  const { resources, resourceTab, filterText } = Store.getState().discovery;
  const q = (filterText || "").trim().toLowerCase();

  return (resources || []).filter((r) => {
    // Tab filter
    if (resourceTab && resourceTab !== "ALL" && r.resource_type !== resourceTab) return false;

    // Search filter — name + label keys/values
    if (!q) return true;
    if (r.resource_name.toLowerCase().includes(q)) return true;
    const labelStr = Object.entries(r.labels || {})
      .map(([k, v]) => `${k}=${v}`)
      .join(" ")
      .toLowerCase();
    return labelStr.includes(q);
  });
}

export async function InventoryPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  const initialRegions = uniq(csvToList(s.discovery.regionsCsv || "eu-west-1,eu-central-1,us-east-1"));

  // Only reset regions if first load
  if (!s.discovery.hasLoaded) {
    Store.setState({
      discovery: {
        regionsList: initialRegions,
      },
    });
  }

  page.innerHTML = `
    <div class="ds-page-header">
      <div>
        <div class="ds-page-title">Discovery</div>
        <div class="ds-page-sub">Scan your AWS accounts and register resources for automated management.</div>
      </div>
    </div>

    <!-- Filters panel -->
    <div class="ds-panel">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Search filters</div>
          <div class="ds-panel__sub">Select regions and resource types, then run the discovery scan.</div>
        </div>
        <div class="ds-row">
          <!-- Unregister: minus icon -->
          <button class="ds-btn" id="ds-inv-batch-unreg" type="button">
            <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M2 7h10"/>
            </svg>
            Unregister
          </button>
          <!-- Register: plus icon -->
          <button class="ds-btn ds-btn--primary" id="ds-inv-batch-reg" type="button">
            <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M7 2v10M2 7h10"/>
            </svg>
            Register
          </button>
          <!-- Run Search: magnifier icon, no cross -->
          <button class="ds-btn" id="ds-inv-run" type="button">
            <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.8">
              <circle cx="6" cy="6" r="4"/>
              <path d="M10 10l3 3"/>
            </svg>
            Run Search
          </button>
        </div>
      </div>
      <div class="ds-panel__body">
        <div class="ds-row" style="gap:16px;align-items:flex-start;">
          <!-- Regions -->
          <div class="ds-field" style="flex:1;min-width:280px;">
            <label class="ds-label">Regions</label>
            <div class="ds-row" style="gap:8px;margin-bottom:8px;">
              <input class="ds-input" id="ds-region-input" placeholder="e.g. eu-west-1" style="flex:1;"/>
              <button class="ds-btn" id="ds-region-add" type="button">Add</button>
            </div>
            <div id="ds-region-chips" class="ds-row" style="gap:6px;flex-wrap:wrap;min-height:24px;"></div>
          </div>

          <!-- Resource type tabs — filter display only, not search scope -->
          <div class="ds-field">
            <label class="ds-label">Resource type</label>
            <div id="ds-resource-tabs"></div>
          </div>
        </div>
      </div>
    </div>

    <!-- Status + search bar -->
    <div class="ds-row" style="margin-bottom:10px;gap:8px;align-items:center;">
      <!-- Loading indicator (hidden by default) -->
      <div id="ds-inv-loading" style="display:none;align-items:center;gap:8px;">
        <div class="ds-spinner"></div>
        <span class="ds-mono" style="font-size:12.5px;color:var(--accent);">Scanning resources…</span>
      </div>
      <span class="ds-mono" id="ds-inv-status" style="color:var(--fg-faint);font-size:12.5px;"></span>
      <div class="ds-spacer"></div>
      <!-- Real-time search filter -->
      <input
        class="ds-input"
        id="ds-inv-search"
        placeholder="Filter by name or label…"
        value="${h(s.discovery.filterText || "")}"
        style="width:240px;min-height:32px;padding:5px 10px;font-size:12.5px;"
      />
    </div>

    <!-- Table -->
    <div class="ds-tablewrap">
      <table class="ds-table" aria-label="Inventory">
        <thead>
          <tr>
            <th style="width:42px;">
              <input type="checkbox" id="ds-inv-check-all" aria-label="Select all"
                style="accent-color:var(--accent);width:15px;height:15px;cursor:pointer;"/>
            </th>
            <th>Type</th>
            <th>Name</th>
            <th>Region</th>
            <th>Status</th>
            <th>Observed</th>
            <th>Labels</th>
          </tr>
        </thead>
        <tbody id="ds-inv-tbody">
          <tr><td colspan="7">
            <div class="ds-empty">
              <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <circle cx="11" cy="11" r="7"/><path d="M16.5 16.5l4 4"/>
              </svg>
              <div class="ds-empty__title">No results yet</div>
              <div class="ds-empty__sub">Configure your regions and click Run Search.</div>
            </div>
          </td></tr>
        </tbody>
      </table>
    </div>
  `;

  const btnRun      = qs("#ds-inv-run");
  const btnReg      = qs("#ds-inv-batch-reg");
  const btnUnreg    = qs("#ds-inv-batch-unreg");
  const statusEl    = qs("#ds-inv-status");
  const loadingEl   = qs("#ds-inv-loading");
  const regionInput = qs("#ds-region-input");
  const regionAdd   = qs("#ds-region-add");
  const chipsBox    = qs("#ds-region-chips");
  const tabsBox     = qs("#ds-resource-tabs");
  const searchInput = qs("#ds-inv-search");

  // ── Helpers ──────────────────────────────────────────────

  function setLoading(on) {
    loadingEl.style.display = on ? "flex" : "none";
    statusEl.style.display  = on ? "none" : "";
    btnRun.disabled = on;
  }

  // ── Real-time search filter ───────────────────────────────

  searchInput.addEventListener("input", () => {
    Store.setState({ discovery: { filterText: searchInput.value } });
    renderRows();
  });

  // ── Region chips ──────────────────────────────────────────

  function renderRegionChips() {
    const regions = Store.getState().discovery.regionsList || [];
    if (!regions.length) {
      chipsBox.innerHTML = `<span class="ds-mono" style="color:var(--fg-faint);font-size:12px;">No regions selected</span>`;
      return;
    }
    chipsBox.innerHTML = regions.map((r) => `
      <span class="ds-chip">
        ${h(r)}
        <button class="ds-chip__remove" data-region-remove="${h(r)}" aria-label="Remove ${h(r)}" type="button">
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1.8">
            <path d="M1 1l8 8M9 1L1 9"/>
          </svg>
        </button>
      </span>
    `).join("");

    qsa("[data-region-remove]", chipsBox).forEach((btn) => {
      btn.addEventListener("click", () => {
        const r = btn.dataset.regionRemove;
        const next = (Store.getState().discovery.regionsList || []).filter((x) => x !== r);
        Store.setState({ discovery: { regionsList: next, regionsCsv: next.join(",") } });
        renderRegionChips();
      });
    });
  }

  // ── Type tabs (client-side filter only) ───────────────────

  function renderTabs() {
    const current = Store.getState().discovery.resourceTab || "ALL";
    tabsBox.innerHTML = `
      <div class="ds-tabs" role="tablist" aria-label="Resource type">
        <button class="ds-tab" type="button" data-tab="ALL"          aria-selected="${current === "ALL"          ? "true" : "false"}">All</button>
        <button class="ds-tab" type="button" data-tab="EKS_CLUSTER"  aria-selected="${current === "EKS_CLUSTER"  ? "true" : "false"}">EKS</button>
        <button class="ds-tab" type="button" data-tab="RDS_INSTANCE" aria-selected="${current === "RDS_INSTANCE" ? "true" : "false"}">RDS</button>
        <button class="ds-tab" type="button" data-tab="EC2_INSTANCE" aria-selected="${current === "EC2_INSTANCE" ? "true" : "false"}">EC2</button>
      </div>
    `;

    qsa("[data-tab]", tabsBox).forEach((btn) => {
      btn.addEventListener("click", () => {
        Store.setState({ discovery: { resourceTab: btn.dataset.tab } });
        renderTabs();
        renderRows(); // instant client-side filter
      });
    });
  }

  // ── Region input ──────────────────────────────────────────

  regionAdd.addEventListener("click", () => {
    const v = (regionInput.value || "").trim();
    if (!v) return;
    const next = uniq([...(Store.getState().discovery.regionsList || []), v]);
    Store.setState({ discovery: { regionsList: next, regionsCsv: next.join(",") } });
    regionInput.value = "";
    renderRegionChips();
  });

  regionInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") { e.preventDefault(); regionAdd.click(); }
  });

  // ── Row rendering ─────────────────────────────────────────

  function renderRows() {
    const tbody = qs("#ds-inv-tbody");
    if (!tbody) return;

    const { selectedKeys } = Store.getState().discovery;
    const filtered = getFilteredResources();
    const allResources = Store.getState().discovery.resources || [];

    // If no search at all yet
    if (!Store.getState().discovery.hasLoaded) {
      tbody.innerHTML = `<tr><td colspan="7">
        <div class="ds-empty">
          <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <circle cx="11" cy="11" r="7"/><path d="M16.5 16.5l4 4"/>
          </svg>
          <div class="ds-empty__title">No results yet</div>
          <div class="ds-empty__sub">Configure your regions and click Run Search.</div>
        </div>
      </td></tr>`;
      return;
    }

    if (!filtered.length) {
      const hint = allResources.length
        ? "No resources match the current filter."
        : "No resources found. Try different regions or resource types.";
      tbody.innerHTML = `<tr><td colspan="7">
        <div class="ds-empty">
          <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <circle cx="11" cy="11" r="7"/><path d="M16.5 16.5l4 4"/>
          </svg>
          <div class="ds-empty__title">No resources</div>
          <div class="ds-empty__sub">${hint}</div>
        </div>
      </td></tr>`;
      return;
    }

    tbody.innerHTML = filtered.map((r) => renderInventoryRow(r, selectedKeys.has(r.key))).join("");

    // Checkbox handlers
    qsa(".ds-inv-check", tbody).forEach((cb) => {
      cb.addEventListener("change", () => {
        const key = cb.dataset.key;
        const set = Store.getState().discovery.selectedKeys;
        if (cb.checked) set.add(key); else set.delete(key);
      });
    });

    const checkAll = qs("#ds-inv-check-all");
    if (checkAll) {
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
  }

  // ── Search (full API call) ────────────────────────────────

  async function runSearch() {
    const accountId = Store.getState().account.id;
    if (!accountId) return toast("Inventory", "Choose an account first.");

    const regions = Store.getState().discovery.regionsList || [];

    setLoading(true);

    try {
      const resp = await Api.searchResources(accountId, {
        resource_types: RESOURCE_TYPES,   // always fetch all, tabs filter client-side
        regions: regions.length ? regions : null,
        selector_by_type: {},
        only_registered: false,
      });

      const norm = normalizeResources(resp?.resources || []);
      Store.setState({
        discovery: {
          resources: norm,
          selectedKeys: new Set(),
          lastQuery: { regions },
          hasLoaded: true,
        },
      });

      renderRows();
      statusEl.textContent = `${norm.length} resource(s) found`;
    } catch (e) {
      statusEl.textContent = "Search failed.";
      toast("Inventory", e.message || "Search error");
    } finally {
      setLoading(false);
    }
  }

  // ── Batch register / unregister ───────────────────────────

  async function doBatch(mode) {
    const accountId    = Store.getState().account.id;
    const selectedKeys = Array.from(Store.getState().discovery.selectedKeys || []);
    const resources    = Store.getState().discovery.resources || [];

    if (!accountId)           return toast("Batch", "Choose an account first.");
    if (!selectedKeys.length) return toast("Batch", "Select at least one resource.");

    const hits = resources
      .filter((r) => selectedKeys.includes(r.key))
      .map((r) => ({ resource_type: r.resource_type, resource_name: r.resource_name, region: r.region }));

    if (!hits.length) return toast("Batch", "No valid resources selected.");

    const label = mode === "REGISTER" ? "Register" : "Unregister";
    const confirmed = await confirmModal({
      title: `${label} ${hits.length} resource(s)`,
      body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">
               This will ${mode.toLowerCase()} the selected resources.
             </p>`,
      confirmText: label,
      danger: mode === "UNREGISTER",
    });
    if (!confirmed) return;

    setLoading(true);
    try {
      const resp = await Api.batchRegisterResources(accountId, { hits, mode, dry_run: false });
      const results = resp?.results || [];
      const counts = results.reduce((acc, r) => {
        acc[r.action] = (acc[r.action] || 0) + 1;
        return acc;
      }, {});
      toast("Batch", `Done — ${Object.entries(counts).map(([k, v]) => `${k}: ${v}`).join(", ") || "OK"}`);
      await runSearch();
    } catch (e) {
      statusEl.textContent = "Batch failed.";
      toast("Batch", e.message || "Batch error");
      setLoading(false);
    }
  }

  // ── Wire up ───────────────────────────────────────────────

  btnRun.addEventListener("click", runSearch);
  btnReg.addEventListener("click", () => doBatch("REGISTER"));
  btnUnreg.addEventListener("click", () => doBatch("UNREGISTER"));

  renderRegionChips();
  renderTabs();

  // Show cached results immediately if they exist, don't re-fetch
  if (s.discovery.hasLoaded) {
    renderRows();
    statusEl.textContent = `${(s.discovery.resources || []).length} resource(s) — cached`;
  } else if (s.auth.token && s.account.id) {
    runSearch();
  }
}
