/**
 * ActiveResourcesPage.js
 *
 * Loading sequence:
 *  1. GET /resource-states          → DB only, instant, renders table immediately
 *  2. POST /resource-states/verify  → fire-and-forget, patches DROPPED in background
 *  3. POST /resource-pricing-batch  → single round-trip for all pricing (deduplicated)
 *     - sent only for RUNNING or SLEEPING resources
 *     - results patched into DOM cells without re-rendering the table
 *     - cached in Store for cross-navigation persistence
 */
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderActiveRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

// ── Pricing cache (module-level, survives navigation) ─────────────────────────
const PRICING_TTL_MS = 60 * 60 * 1000; // 1 hour

function getPricingCache() {
  return Store.getState().active.pricingCache;
}

function pricingCacheKey(resourceType, resourceName, region) {
  return `${resourceType}|${resourceName}|${region}`;
}

function getCached(key) {
  const entry = getPricingCache().get(key);
  if (!entry || Date.now() - entry.ts > PRICING_TTL_MS) return null;
  return entry;
}

function setCache(key, cost, savings) {
  getPricingCache().set(key, { cost, savings, ts: Date.now() });
}

// ── Row map builder ───────────────────────────────────────────────────────────

function buildRowsMap(states = []) {
  const map = new Map();
  for (const s of states) {
    const resourceName = s.resource_name ?? s.cluster_name ?? s.db_instance_id ?? s.instance_id;
    const key = `${s.resource_type}|${resourceName}|${s.region}`;
    map.set(key, {
      key,
      resource_type:  s.resource_type,
      resource_name:  resourceName,
      region:         s.region,
      observed_state: s.observed_state,
      desired_state:  s.desired_state,
      last_action:    s.last_action,
      last_action_at: s.last_action_at,
      locked_until:   s.locked_until,
      updated_at:     s.updated_at,
    });
  }
  return map;
}

// ── Patch a single table row in-place ─────────────────────────────────────────

function patchPricingCells(key, cost, savings) {
  const safeKey = key.replaceAll('"', '\\"');
  const tr = document.querySelector(`tr[data-key="${safeKey}"]`);
  if (!tr) return;
  const costSpan    = tr.querySelector('[data-col="compute-cost"] span');
  const savingsSpan = tr.querySelector('[data-col="compute-savings"] span');
  if (costSpan    && cost    !== null && cost    !== undefined)
    costSpan.textContent    = `$${Number(cost).toFixed(4)}/hr`;
  if (savingsSpan && savings !== null && savings !== undefined)
    savingsSpan.textContent = `$${Number(savings).toFixed(4)}/hr`;
}

function patchStateCell(key, newState) {
  const safeKey = key.replaceAll('"', '\\"');
  const tr = document.querySelector(`tr[data-key="${safeKey}"]`);
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
        <!-- Indicators -->
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
          <span class="ds-mono" style="font-size:11px;color:var(--fg-faint);">Fetching costs…</span>
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

    <!-- Search -->
    <div class="ds-row" style="margin-bottom:12px;justify-content:flex-end;">
      <input class="ds-input" id="ds-active-search" placeholder="Filter by name…"
        value="${h(s.active.filterText || "")}"
        style="width:240px;min-height:32px;padding:5px 10px;font-size:12.5px;"/>
    </div>

    <div class="ds-tablewrap">
      <table class="ds-table" aria-label="Active resources">
        <thead>
          <tr>
            <th>Type</th>
            <th>Name</th>
            <th>Region</th>
            <th>Observed</th>
            <th>Desired</th>
            <th>Cost/hr</th>
            <th>Savings/hr</th>
            <th style="min-width:210px;">Actions</th>
          </tr>
        </thead>
        <tbody id="ds-active-tbody">
          <tr><td colspan="8">
            <div class="ds-loading"><div class="ds-spinner"></div>Loading…</div>
          </td></tr>
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
  const searchInput = qs("#ds-active-search");

  let rowsMap = Store.getState().active.rowsByKey || new Map();
  let renderToken = 0;

  // ── Helpers ────────────────────────────────────────────────────────────────

  function setLoading(on) {
    loadingEl.style.display = on ? "flex" : "none";
    refreshBtn.disabled = on;
  }

  function getFilteredRows() {
    const q = (Store.getState().active.filterText || "").trim().toLowerCase();
    const rows = Array.from(rowsMap.values());
    return q ? rows.filter(r => r.resource_name.toLowerCase().includes(q)) : rows;
  }

  searchInput.addEventListener("input", () => {
    Store.setState({ active: { filterText: searchInput.value } });
    renderTable();
  });

  // ── Table render ───────────────────────────────────────────────────────────

  function renderTable() {
    const filtered = getFilteredRows();
    if (!filtered.length) {
      tbody.innerHTML = `<tr><td colspan="8">
        <div class="ds-empty">
          <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 9h6M9 12h6M9 15h4"/>
          </svg>
          <div class="ds-empty__title">${rowsMap.size ? "No match" : "No active resources"}</div>
          <div class="ds-empty__sub">${rowsMap.size ? "No resources match your filter." : "Register resources in Discovery to see them here."}</div>
        </div>
      </td></tr>`;
      return;
    }

    tbody.innerHTML = filtered.map((row) => {
      const key = pricingCacheKey(row.resource_type, row.resource_name, row.region);
      const cached = getCached(key);
      return renderActiveRow(row, { cost: cached?.cost ?? null, savings: cached?.savings ?? null });
    }).join("");

    bindRowActions();
  }

  function bindRowActions() {
    qsa("[data-action]", tbody).forEach((btn) => {
      btn.addEventListener("click", async () => {
        const { action, resourceType, resourceName, region } = btn.dataset;
        if (action === "wake")       await doWake(resourceType, resourceName, region);
        if (action === "sleep")      await doSleep(resourceType, resourceName, region);
        if (action === "unregister") await doUnregister(resourceType, resourceName, region);
      });
    });
  }

  // ── Step 1: Load states from DB (instant) ─────────────────────────────────

  async function loadStates(token) {
    try {
      const resp = await Api.listResourceStates(accountId);
      if (renderToken !== token) return null;

      const states = resp?.states || [];
      rowsMap = buildRowsMap(states);
      Store.setState({
        active: { rowsByKey: rowsMap, lastPollAt: new Date().toISOString(), hasLoaded: true },
      });

      renderTable();
      if (pollSpan) pollSpan.textContent = `Updated ${new Date().toLocaleTimeString()}`;

      return states;
    } catch (e) {
      if (String(e.message || "").match(/401|403/)) {
        toast("Session", "Authentication lost."); location.hash = "#/login";
      } else {
        toast("Active Resources", e.message || "Load failed.");
      }
      return null;
    }
  }

  // ── Step 2: Verify existence (fire-and-forget, non-blocking) ──────────────

  async function verifyExistence(states, token) {
    // Only verify non-DROPPED resources — no point re-verifying what we know is gone
    const toVerify = states
      .filter(s => (s.observed_state || "").toUpperCase() !== "DROPPED")
      .map(s => ({
        resource_type: s.resource_type,
        resource_name: s.resource_name,
        region: s.region,
      }));

    if (!toVerify.length) return;

    verifyingEl.style.display = "flex";
    try {
      const resp = await Api.verifyResourceExistence(accountId, toVerify);
      if (renderToken !== token) return;

      const dropped = (resp?.results || []).filter(r => r.newly_dropped);
      if (dropped.length) {
        // Patch DROPPED state cells without re-rendering the whole table
        for (const r of dropped) {
          const key = `${r.resource_type}|${r.resource_name}|${r.region}`;
          patchStateCell(key, "DROPPED");
          // Update in-memory map too
          const row = rowsMap.get(key);
          if (row) row.observed_state = "DROPPED";
        }
        toast("Active Resources", `${dropped.length} resource(s) no longer exist on AWS and have been marked as DROPPED.`);
      }
    } catch (e) {
      // Non-fatal — verify is best-effort
      console.warn("Verify existence failed:", e.message);
    } finally {
      verifyingEl.style.display = "none";
    }
  }

  // ── Step 3: Batch pricing (single round-trip, deduplicated) ───────────────

  async function loadPricing(states, token) {
    // Only price RUNNING and SLEEPING resources; skip DROPPED/UNKNOWN
    const toPriceResources = states.filter(s => {
      const state = (s.observed_state || "").toUpperCase();
      if (state === "DROPPED" || !state) return false;

      const resourceName = s.resource_name;
      const key = pricingCacheKey(s.resource_type, resourceName, s.region);
      if (getCached(key)) return false; // already cached

      return state === "RUNNING" || state === "AVAILABLE" || state === "ACTIVE"
          || state === "SLEEPING" || state === "STOPPED" || state === "ASLEEP";
    }).map(s => ({
      resource_type:  s.resource_type,
      resource_name:  s.resource_name,
      region:         s.region,
      observed_state: s.observed_state,
    }));

    if (!toPriceResources.length) return;

    pricingEl.style.display = "flex";
    try {
      const resp = await Api.getResourcePricingBatch(accountId, toPriceResources);
      if (renderToken !== token) return;

      const pricing = resp?.pricing || {};
      for (const [key, { cost, savings }] of Object.entries(pricing)) {
        setCache(key, cost, savings);
        patchPricingCells(key, cost, savings);
      }
    } catch (e) {
      console.warn("Batch pricing failed:", e.message);
    } finally {
      pricingEl.style.display = "none";
    }
  }

  // ── Full load sequence ─────────────────────────────────────────────────────

  async function loadResources(silent = false) {
    const token = ++renderToken;
    if (!silent) setLoading(true);

    try {
      const states = await loadStates(token);
      if (!states) return;

      // Steps 2 and 3 run in parallel — both are non-blocking from UX perspective
      verifyExistence(states, token);  // fire-and-forget
      loadPricing(states, token);      // fire-and-forget
    } finally {
      if (!silent && renderToken === token) setLoading(false);
    }
  }

  // ── Action handlers ────────────────────────────────────────────────────────

  async function choosePlan(resourceType) {
    const config = await Api.getAccountConfig(accountId);
    const wantedType = resourceType === "EKS_CLUSTER" ? "EKS_CLUSTER_SLEEP"
                     : resourceType === "RDS_INSTANCE" ? "RDS_SLEEP"
                     : resourceType === "EC2_INSTANCE" ? "EC2_SLEEP" : null;
    const plans = Object.entries(config?.sleep_plans || {})
      .filter(([, p]) => p?.plan_type === wantedType)
      .map(([n]) => n);
    if (!plans.length) throw new Error(`No sleep plan for ${resourceType}.`);
    if (plans.length === 1) return plans[0];

    const host = qs("#ds-modalhost");
    return new Promise((resolve) => {
      host.innerHTML = `
        <div class="ds-modalbackdrop" data-backdrop="1"></div>
        <div class="ds-modal" role="dialog" aria-modal="true">
          <div class="ds-modal__head">
            <div class="ds-modal__title">Choose Sleep Plan</div>
            <button class="ds-btn ds-btn--ghost ds-btn--icon" type="button" data-role="cancel" aria-label="Close">
              <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 1l12 12M13 1L1 13"/></svg>
            </button>
          </div>
          <div class="ds-modal__body">
            <div class="ds-field">
              <label class="ds-label">Available plans</label>
              <select class="ds-select" id="ds-plan-select">
                ${plans.map(n => `<option value="${h(n)}">${h(n)}</option>`).join("")}
              </select>
            </div>
          </div>
          <div class="ds-modal__foot">
            <button class="ds-btn ds-btn--ghost" type="button" data-role="cancel">Cancel</button>
            <button class="ds-btn ds-btn--primary" type="button" data-role="confirm">Sleep with this plan</button>
          </div>
        </div>`;
      host.style.pointerEvents = "auto";
      const cleanup = (val) => { host.innerHTML = ""; host.style.pointerEvents = "none"; resolve(val); };
      host.addEventListener("click", (e) => {
        const role = e.target?.dataset?.role;
        if (role === "cancel") cleanup(null);
        if (role === "confirm") cleanup(qs("#ds-plan-select")?.value || plans[0]);
      }, { once: true });
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
      confirmText: "Unregister",
      danger: true,
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
    // Show cached data immediately
    renderTable();
    if (pollSpan) {
      const last = s.active.lastPollAt ? new Date(s.active.lastPollAt).toLocaleTimeString() : "—";
      pollSpan.textContent = `Updated ${last}`;
    }
    setLoading(false);
    // Silent background refresh
    loadResources(true);
  } else {
    await loadResources(false);
  }
}
