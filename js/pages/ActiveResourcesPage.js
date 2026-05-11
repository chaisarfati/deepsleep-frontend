/**
 * ActiveResourcesPage.js
 *
 * Loading sequence:
 *  1. GET /resource-states          → DB only, instant render
 *  2. POST /resource-states/verify  → fire-and-forget, patches DROPPED
 *  3. Streaming pricing             → one request per resource in parallel
 *     Each resolves independently and patches its cell immediately.
 *     Only RUNNING → cost, only SLEEPING → savings.
 *     EKS with all nodegroups at 0 → cost $0.00 (not null)
 */
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderActiveRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

// ── Pricing cache ─────────────────────────────────────────────────────────────
const PRICING_TTL_MS = 60 * 60 * 1000;

function getCache()  { return Store.getState().active.pricingCache; }
function cacheKey(t, n, r) { return `${t}|${n}|${r}`; }

function getCached(key) {
  const e = getCache().get(key);
  return e && Date.now() - e.ts < PRICING_TTL_MS ? e : null;
}
function setCache(key, cost, savings) {
  getCache().set(key, { cost, savings, ts: Date.now() });
}

// ── Row map builder ───────────────────────────────────────────────────────────
function buildRowsMap(states = []) {
  const map = new Map();
  for (const s of states) {
    const rn  = s.resource_name ?? s.cluster_name ?? s.db_instance_id ?? s.instance_id;
    const key = cacheKey(s.resource_type, rn, s.region);
    map.set(key, {
      key, resource_type: s.resource_type, resource_name: rn, region: s.region,
      observed_state: s.observed_state, desired_state: s.desired_state,
      last_action: s.last_action, last_action_at: s.last_action_at,
      locked_until: s.locked_until, updated_at: s.updated_at,
    });
  }
  return map;
}

// ── DOM patching ──────────────────────────────────────────────────────────────
function patchPriceCell(key, cost, savings) {
  const tr = document.querySelector(`tr[data-key="${key.replaceAll('"', '\\"')}"]`);
  if (!tr) return;
  const costSpan    = tr.querySelector('[data-col="compute-cost"] span');
  const savingsSpan = tr.querySelector('[data-col="compute-savings"] span');
  if (costSpan    && cost    !== null && cost    !== undefined)
    costSpan.textContent    = `$${Number(cost).toFixed(4)}/hr`;
  if (savingsSpan && savings !== null && savings !== undefined)
    savingsSpan.textContent = `$${Number(savings).toFixed(4)}/hr`;
}

function patchStateCell(key, newState) {
  const tr = document.querySelector(`tr[data-key="${key.replaceAll('"', '\\"')}"]`);
  if (!tr) return;
  const cell = tr.querySelector('[data-col="observed"]');
  if (cell) cell.innerHTML = `<span class="ds-status ds-status--stopped"><span class="ds-status__dot"></span>${h(newState)}</span>`;
}

// ── Page ──────────────────────────────────────────────────────────────────────
export async function ActiveResourcesPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  if (!s.auth.token) { toast("Auth", "Please login."); location.hash = "#/login"; return; }
  if (!s.account.id) {
    page.innerHTML = `<div class="ds-empty">
      <div class="ds-empty__title">No account selected</div>
      <div class="ds-empty__sub">Choose an account from the sidebar.</div>
    </div>`;
    return;
  }

  const accountId = s.account.id;

  page.innerHTML = `
    <div class="ds-page-header">
      <div>
        <div class="ds-page-title">Active Resources</div>
        <div class="ds-page-sub">Registered resources and their current DeepSleep state.</div>
      </div>
      <div class="ds-page-header__actions">
        <div id="ds-active-loading" style="display:none;align-items:center;gap:8px;">
          <div class="ds-spinner"></div>
          <span class="ds-mono" style="font-size:12px;color:var(--accent);">Loading…</span>
        </div>
        <div id="ds-active-verifying" style="display:none;align-items:center;gap:6px;">
          <div class="ds-spinner" style="width:12px;height:12px;border-width:1.5px;"></div>
          <span class="ds-mono" style="font-size:11px;color:var(--fg-faint);">Verifying…</span>
        </div>
        <div id="ds-active-pricing" style="display:none;align-items:center;gap:6px;">
          <div class="ds-spinner" style="width:12px;height:12px;border-width:1.5px;"></div>
          <span class="ds-mono" id="ds-pricing-progress" style="font-size:11px;color:var(--fg-faint);">Fetching costs…</span>
        </div>
        <span class="ds-mono" id="ds-active-poll" style="color:var(--fg-faint);font-size:11.5px;"></span>
        <button class="ds-btn" id="ds-active-refresh">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.7">
            <path d="M12 7A5 5 0 1 1 7 2"/><path d="M10 2h3v3"/>
          </svg>
          Refresh
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div class="ds-row" style="margin-bottom:12px;gap:8px;flex-wrap:wrap;">
      <!-- Type tabs -->
      <div class="ds-tabs" role="tablist" id="ds-active-type-tabs">
        ${["ALL","EKS_CLUSTER","RDS_INSTANCE","EC2_INSTANCE"].map(t => {
          const lbl = t === "ALL" ? "All" : t === "EKS_CLUSTER" ? "EKS" : t === "RDS_INSTANCE" ? "RDS" : "EC2";
          const cur = s.active.typeFilter || "ALL";
          return `<button class="ds-tab" type="button" data-type-tab="${t}" aria-selected="${t === cur}">${lbl}</button>`;
        }).join("")}
      </div>
      <!-- Region chips -->
      <div id="ds-active-region-filter" style="display:flex;align-items:center;gap:6px;flex-wrap:wrap;"></div>
      <div class="ds-spacer"></div>
      <!-- Name search -->
      <input class="ds-input" id="ds-active-search" placeholder="Filter by name…"
        value="${h(s.active.filterText || "")}"
        style="width:200px;min-height:32px;padding:5px 10px;font-size:12.5px;"/>
    </div>

    <div class="ds-tablewrap">
      <table class="ds-table" aria-label="Active resources">
        <thead>
          <tr>
            <th>Type</th><th>Name</th><th>Region</th>
            <th>Observed</th><th>Desired</th>
            <th>Cost/hr</th><th>Savings/hr</th>
            <th style="min-width:210px;">Actions</th>
          </tr>
        </thead>
        <tbody id="ds-active-tbody">
          <tr><td colspan="8"><div class="ds-loading"><div class="ds-spinner"></div>Loading…</div></td></tr>
        </tbody>
      </table>
    </div>
  `;

  const tbody       = qs("#ds-active-tbody");
  const pollSpan    = qs("#ds-active-poll");
  const refreshBtn  = qs("#ds-active-refresh");
  const loadingEl   = qs("#ds-active-loading");
  const verifyingEl = qs("#ds-active-verifying");
  const pricingEl   = qs("#ds-active-pricing");
  const pricingProg = qs("#ds-pricing-progress");
  const searchInput = qs("#ds-active-search");

  let rowsMap = new Map(Store.getState().active.rowsByKey || []);
  let renderToken = 0;

  // ── Filters ────────────────────────────────────────────────────────────────

  function getTypeFilter()   { return Store.getState().active.typeFilter   || "ALL"; }
  function getRegionFilter() { return Store.getState().active.regionFilter || null; }

  function getFilteredRows() {
    const q      = (Store.getState().active.filterText || "").trim().toLowerCase();
    const type   = getTypeFilter();
    const region = getRegionFilter();
    return Array.from(rowsMap.values()).filter(r => {
      if (type !== "ALL" && r.resource_type !== type) return false;
      if (region && r.region !== region) return false;
      if (q && !r.resource_name.toLowerCase().includes(q)) return false;
      return true;
    });
  }

  function getUniqueRegions() {
    return [...new Set(Array.from(rowsMap.values()).map(r => r.region))].sort();
  }

  function renderRegionFilter() {
    const regionBox = qs("#ds-active-region-filter");
    if (!regionBox) return;
    const regions = getUniqueRegions();
    const cur = getRegionFilter();

    if (!regions.length) { regionBox.innerHTML = ""; return; }

    regionBox.innerHTML = `
      <span class="ds-mono" style="font-size:11px;color:var(--fg-faint);">Region:</span>
      <button class="ds-chip ${!cur ? 'ds-chip--active' : ''}" data-region-filter="" type="button" style="${!cur ? "background:var(--accent-dim);border-color:rgba(44,107,237,.2);color:var(--accent);" : ""}">All</button>
      ${regions.map(r => `
        <button class="ds-chip ${cur === r ? 'ds-chip--active' : ''}" data-region-filter="${h(r)}" type="button"
          style="${cur === r ? "background:var(--accent-dim);border-color:rgba(44,107,237,.2);color:var(--accent);" : ""}">
          ${h(r)}
        </button>`
      ).join("")}
    `;

    qsa("[data-region-filter]", regionBox).forEach(btn => {
      btn.addEventListener("click", () => {
        Store.setState({ active: { regionFilter: btn.dataset.regionFilter || null } });
        renderRegionFilter();
        renderTable();
      });
    });
  }

  // Type tabs
  qsa("[data-type-tab]").forEach(btn => {
    btn.addEventListener("click", () => {
      Store.setState({ active: { typeFilter: btn.dataset.typeTab } });
      qsa("[data-type-tab]").forEach(b => b.setAttribute("aria-selected", b === btn ? "true" : "false"));
      renderTable();
    });
  });

  // Search
  searchInput.addEventListener("input", () => {
    Store.setState({ active: { filterText: searchInput.value } });
    renderTable();
  });

  // ── Table render ───────────────────────────────────────────────────────────
  function renderTable() {
    const filtered = getFilteredRows();
    if (!filtered.length) {
      tbody.innerHTML = `<tr><td colspan="8"><div class="ds-empty">
        <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 9h6M9 12h6M9 15h4"/>
        </svg>
        <div class="ds-empty__title">${rowsMap.size ? "No match" : "No active resources"}</div>
        <div class="ds-empty__sub">${rowsMap.size ? "Adjust filters." : "Register resources in Discovery."}</div>
      </div></td></tr>`;
      return;
    }

    tbody.innerHTML = filtered.map(row => {
      const key    = cacheKey(row.resource_type, row.resource_name, row.region);
      const cached = getCached(key);
      return renderActiveRow(row, { cost: cached?.cost ?? null, savings: cached?.savings ?? null });
    }).join("");

    bindRowActions();
  }

  function bindRowActions() {
    qsa("[data-action]", tbody).forEach(btn => {
      btn.addEventListener("click", async () => {
        const { action, resourceType, resourceName, region } = btn.dataset;
        if (action === "wake")       await doWake(resourceType, resourceName, region);
        if (action === "sleep")      await doSleep(resourceType, resourceName, region);
        if (action === "unregister") await doUnregister(resourceType, resourceName, region);
      });
    });
  }

  function setLoading(on) {
    loadingEl.style.display = on ? "flex" : "none";
    refreshBtn.disabled = on;
  }

  // ── Step 1: Load states ────────────────────────────────────────────────────
  async function loadStates(token) {
    try {
      const resp   = await Api.listResourceStates(accountId);
      if (renderToken !== token) return null;
      const states = resp?.states || [];
      rowsMap = buildRowsMap(states);
      Store.setState({ active: { rowsByKey: rowsMap, lastPollAt: new Date().toISOString(), hasLoaded: true } });
      renderTable();
      renderRegionFilter();
      if (pollSpan) pollSpan.textContent = `Updated ${new Date().toLocaleTimeString()}`;
      return states;
    } catch (e) {
      if (/401|403/.test(e.message || "")) { toast("Session", "Authentication lost."); location.hash = "#/login"; }
      else toast("Active Resources", e.message || "Load failed.");
      return null;
    }
  }

  // ── Step 2: Verify existence (fire-and-forget) ────────────────────────────
  async function verifyExistence(states, token) {
    const toVerify = states
      .filter(s => (s.observed_state || "").toUpperCase() !== "DROPPED")
      .map(s => ({ resource_type: s.resource_type, resource_name: s.resource_name, region: s.region }));
    if (!toVerify.length) return;

    verifyingEl.style.display = "flex";
    try {
      const resp = await Api.verifyResourceExistence(accountId, toVerify);
      if (renderToken !== token) return;
      const dropped = (resp?.results || []).filter(r => r.newly_dropped);
      for (const r of dropped) {
        const key = cacheKey(r.resource_type, r.resource_name, r.region);
        patchStateCell(key, "DROPPED");
        const row = rowsMap.get(key);
        if (row) row.observed_state = "DROPPED";
      }
      if (dropped.length) toast("Active Resources", `${dropped.length} resource(s) marked as DROPPED.`);
    } catch (e) {
      console.warn("Verify failed:", e.message);
    } finally {
      verifyingEl.style.display = "none";
    }
  }

  // ── Step 3: Streaming pricing ─────────────────────────────────────────────
  // Fire one request per resource in parallel.
  // Each resolves and patches its DOM cell immediately.
  // This gives the "prices appearing one by one" effect without any special streaming API.
  async function loadPricingStreaming(states, token) {
    const toPriceResources = states.filter(s => {
      const state = (s.observed_state || "").toUpperCase();
      if (state === "DROPPED" || !state) return false;
      const rn  = s.resource_name ?? s.cluster_name ?? s.db_instance_id ?? s.instance_id;
      const key = cacheKey(s.resource_type, rn, s.region);
      if (getCached(key)) return false; // already cached
      return state === "RUNNING" || state === "AVAILABLE" || state === "ACTIVE"
          || state === "SLEEPING" || state === "STOPPED" || state === "ASLEEP";
    });

    if (!toPriceResources.length) return;

    pricingEl.style.display = "flex";
    let done = 0;
    const total = toPriceResources.length;

    function updateProgress() {
      done++;
      if (pricingProg) pricingProg.textContent = `Fetching costs… ${done}/${total}`;
      if (done >= total) {
        setTimeout(() => { pricingEl.style.display = "none"; }, 600);
      }
    }

    // One request per resource, all in parallel, each patches DOM on resolve
    await Promise.allSettled(toPriceResources.map(async (s) => {
      const rn    = s.resource_name ?? s.cluster_name ?? s.db_instance_id ?? s.instance_id;
      const rtype = s.resource_type;
      const region= s.region;
      const state = (s.observed_state || "").toUpperCase();
      const key   = cacheKey(rtype, rn, region);
      const isSleeping = state === "SLEEPING" || state === "STOPPED" || state === "ASLEEP";

      try {
        if (isSleeping) {
          const resp = await Api.getResourcePricingBatch(accountId, [{
            resource_type: rtype, resource_name: rn, region, observed_state: s.observed_state,
          }]);
          if (renderToken !== token) return;
          const pricing = resp?.pricing?.[key];
          // Point 7 fix: treat null savings as 0 when resource is truly sleeping
          const savings = pricing?.savings ?? 0;
          setCache(key, null, savings);
          patchPriceCell(key, null, savings);
        } else {
          const resp = await Api.getResourcePricingBatch(accountId, [{
            resource_type: rtype, resource_name: rn, region, observed_state: s.observed_state,
          }]);
          if (renderToken !== token) return;
          const pricing = resp?.pricing?.[key];
          // Point 7 fix: EKS with all nodes at 0 → cost is 0, not null
          const cost = pricing?.cost ?? 0;
          setCache(key, cost, null);
          patchPriceCell(key, cost, null);
        }
      } catch (e) {
        console.warn(`Pricing failed for ${key}:`, e.message);
      } finally {
        updateProgress();
      }
    }));
  }

  // ── Full load sequence ─────────────────────────────────────────────────────
  async function loadResources(silent = false) {
    const token = ++renderToken;
    if (!silent) setLoading(true);
    try {
      const states = await loadStates(token);
      if (!states) return;
      verifyExistence(states, token);      // fire-and-forget
      loadPricingStreaming(states, token); // fire-and-forget, streams results
    } finally {
      if (!silent && renderToken === token) setLoading(false);
    }
  }

  // ── Action handlers ────────────────────────────────────────────────────────
  async function choosePlan(resourceType) {
    const config = await Api.getAccountConfig(accountId);
    const PLAN_TYPE_MAP = {
      EKS_CLUSTER:  "EKS_CLUSTER_SLEEP",
      RDS_INSTANCE: "RDS_SLEEP",
      EC2_INSTANCE: "EC2_INSTANCE_SLEEP",
    };

    const wantedType = PLAN_TYPE_MAP[resourceType];
    if (!wantedType) throw new Error(`Unknown resource type: ${resourceType}`);

    const plans = Object.entries(config?.sleep_plans || {})
      .filter(([, p]) => p?.plan_type === wantedType).map(([n]) => n);
    if (!plans.length) throw new Error(`No sleep plan for ${resourceType}.`);
    if (plans.length === 1) return plans[0];
    const host = qs("#ds-modalhost");
    return new Promise((resolve) => {
      host.innerHTML = `
        <div class="ds-modalbackdrop" data-backdrop="1"></div>
        <div class="ds-modal" role="dialog" aria-modal="true">
          <div class="ds-modal__head">
            <div class="ds-modal__title">Choose Sleep Plan</div>
            <button class="ds-btn ds-btn--ghost ds-btn--icon" type="button" data-close="1" aria-label="Close">
              <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 1l12 12M13 1L1 13"/></svg>
            </button>
          </div>
          <div class="ds-modal__body">
            <div class="ds-field">
              <label class="ds-label">Available plans</label>
              <select class="ds-select" id="ds-plan-select">${plans.map(n => `<option value="${h(n)}">${h(n)}</option>`).join("")}</select>
            </div>
          </div>
          <div class="ds-modal__foot">
            <button class="ds-btn ds-btn--ghost" type="button" data-cancel="1">Cancel</button>
            <button class="ds-btn ds-btn--primary" type="button" data-confirm="1">Sleep with this plan</button>
          </div>
        </div>`;
      host.style.pointerEvents = "auto";
      function cleanup(val) {
        host.removeEventListener("click", handler);
        host.innerHTML = ""; host.style.pointerEvents = "none"; resolve(val);
      }
      function handler(e) {
        const btn = e.target?.closest("[data-backdrop],[data-close],[data-cancel],[data-confirm]");
        if (!btn) return;
        if (btn.dataset.confirm) cleanup(qs("#ds-plan-select")?.value || plans[0]);
        else cleanup(null);
      }
      host.addEventListener("click", handler);
    });
  }

  async function doSleep(resourceType, resourceName, region) {
    const confirmed = await confirmModal({
      title: `Sleep ${resourceName}`,
      body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">Initiate sleep on <strong>${h(resourceName)}</strong> (${h(region)}).</p>`,
      confirmText: "Sleep",
    });
    if (!confirmed) return;
    let planName;
    try { planName = await choosePlan(resourceType); }
    catch (e) { return toast("Sleep Plans", e.message); }
    if (!planName) return;
    try {
      await Api.sleepResource(accountId, { resource_type: resourceType, resource_name: resourceName, region, plan_name: planName });
      toast("Sleep", `${resourceName} → sleep initiated.`);
      await loadResources();
    } catch (e) { toast("Sleep", e.message || "Sleep failed."); }
  }

  async function doWake(resourceType, resourceName, region) {
    const confirmed = await confirmModal({
      title: `Wake ${resourceName}`,
      body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">Wake <strong>${h(resourceName)}</strong> (${h(region)}).</p>`,
      confirmText: "Wake",
    });
    if (!confirmed) return;
    try {
      await Api.wakeResource(accountId, { resource_type: resourceType, resource_name: resourceName, region });
      toast("Wake", `${resourceName} → wake initiated.`);
      await loadResources();
    } catch (e) { toast("Wake", e.message || "Wake failed."); }
  }

  async function doUnregister(resourceType, resourceName, region) {
    const confirmed = await confirmModal({
      title: `Unregister ${resourceName}`,
      body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">Remove <strong>${h(resourceName)}</strong> from DeepSleep. The AWS resource will not be deleted.</p>`,
      confirmText: "Unregister", danger: true,
    });
    if (!confirmed) return;
    try {
      await Api.unregisterResource(accountId, { resource_type: resourceType, resource_name: resourceName, region });
      toast("Unregister", `${resourceName} removed.`);
      await loadResources();
    } catch (e) { toast("Unregister", e.message || "Unregister failed."); }
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  refreshBtn.addEventListener("click", () => loadResources(false));

  if (s.active.hasLoaded && rowsMap.size > 0) {
    renderTable();
    renderRegionFilter();
    if (pollSpan) {
      const last = s.active.lastPollAt ? new Date(s.active.lastPollAt).toLocaleTimeString() : "—";
      pollSpan.textContent = `Updated ${last}`;
    }
    setLoading(false);
    loadResources(true);
  } else {
    await loadResources(false);
  }
}
