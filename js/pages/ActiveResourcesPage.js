import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderActiveRow } from "../components/ResourceRow.js";
import { patchActiveRow } from "../components/ActiveRowPatcher.js";
import * as Api from "../api/services.js";

// ── Pricing cache (module-level, survives navigation) ────────────────────────
// Also mirrored in Store.active.pricingCache for cross-module access (poller).
const PRICING_TTL_MS = 60 * 60 * 1000; // 1 hour

function getPricingCache() {
  return Store.getState().active.pricingCache;
}

function pricingKey(resourceType, resourceName, region) {
  return `${resourceType}|${resourceName}|${region}`;
}

function getCachedPricing(key) {
  const entry = getPricingCache().get(key);
  if (!entry || (Date.now() - entry.ts) > PRICING_TTL_MS) return null;
  return entry;
}

function setCachedPricing(key, cost, savings) {
  getPricingCache().set(key, { cost, savings, ts: Date.now() });
}

// ── Fetch pricing — only for relevant states ──────────────────────────────────
async function fetchPricingForRow(accountId, row, renderToken) {
  const { resource_type, resource_name, region, observed_state } = row;
  const key = pricingKey(resource_type, resource_name, region);

  // Already cached
  if (getCachedPricing(key)) return;

  const state = (observed_state || "").toUpperCase();
  const isSleeping = state === "SLEEPING" || state === "STOPPED" || state === "ASLEEP";
  const isRunning  = state === "RUNNING"  || state === "AVAILABLE" || state === "ACTIVE";

  try {
    if (isSleeping) {
      // Only fetch savings for sleeping resources
      const ps = await Api.getResourceSavings(accountId, resource_type, resource_name, region).catch(() => null);
      const savings = ps?.hourly_savings ?? ps?.savings_per_hour ?? null;
      setCachedPricing(key, null, savings);
    } else if (isRunning) {
      // Only fetch price for running resources
      const p = await Api.getResourcePrice(accountId, resource_type, resource_name, region).catch(() => null);
      const cost = p?.hourly_price ?? p?.cost_per_hour ?? null;
      setCachedPricing(key, cost, null);
    } else {
      return; // DROPPED, UNKNOWN etc — don't fetch
    }
  } catch {
    return;
  }

  // Patch cell in DOM if still on this page
  if (Store.getState().route.name !== "active") return;
  const tr = document.querySelector(`tr[data-key="${key.replaceAll('"', '\\"')}"]`);
  if (!tr) return;

  const entry = getCachedPricing(key);
  const costTd    = tr.querySelector('[data-col="compute-cost"] span');
  const savingsTd = tr.querySelector('[data-col="compute-savings"] span');
  if (costTd && entry?.cost !== null && entry?.cost !== undefined)
    costTd.textContent = `$${Number(entry.cost).toFixed(4)}/hr`;
  if (savingsTd && entry?.savings !== null && entry?.savings !== undefined)
    savingsTd.textContent = `$${Number(entry.savings).toFixed(4)}/hr`;
}

// ── Build rows map from unified /resource-states response ─────────────────────
function buildRowsMap(states = []) {
  const map = new Map();
  for (const s of states) {
    // Unified API returns resource_name for all types
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

// ── Page ──────────────────────────────────────────────────────────────────────

export async function ActiveResourcesPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  if (!s.auth.token) {
    toast("Auth", "Please login.");
    location.hash = "#/login";
    return;
  }
  if (!s.account.id) {
    page.innerHTML = `<div class="ds-empty">
      <div class="ds-empty__title">No account selected</div>
      <div class="ds-empty__sub">Choose an account from the sidebar to view active resources.</div>
    </div>`;
    return;
  }

  const accountId = s.account.id;

  page.innerHTML = `
    <div class="ds-page-header">
      <div>
        <div class="ds-page-title">Active Resources</div>
        <div class="ds-page-sub">Monitor and control your registered AWS resources in real-time.</div>
      </div>
      <div class="ds-page-header__actions">
        <!-- Loading indicator -->
        <div id="ds-active-loading" style="display:none;align-items:center;gap:8px;">
          <div class="ds-spinner"></div>
          <span class="ds-mono" style="font-size:12px;color:var(--accent);">Loading…</span>
        </div>
        <span class="ds-mono" id="ds-active-poll" style="color:var(--fg-faint);font-size:11.5px;"></span>
        <button class="ds-btn" id="ds-active-refresh" type="button">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.7">
            <path d="M12 7A5 5 0 1 1 7 2"/><path d="M10 2h3v3"/>
          </svg>
          Refresh
        </button>
      </div>
    </div>

    <!-- Search filter -->
    <div class="ds-row" style="margin-bottom:12px;justify-content:flex-end;">
      <input
        class="ds-input"
        id="ds-active-search"
        placeholder="Filter by name or label…"
        value="${h(s.active.filterText || "")}"
        style="width:240px;min-height:32px;padding:5px 10px;font-size:12.5px;"
      />
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
            <div class="ds-loading"><div class="ds-spinner"></div>Loading resources…</div>
          </td></tr>
        </tbody>
      </table>
    </div>
  `;

  const tbody       = qs("#ds-active-tbody");
  const pollSpan    = qs("#ds-active-poll");
  const refreshBtn  = qs("#ds-active-refresh");
  const loadingEl   = qs("#ds-active-loading");
  const searchInput = qs("#ds-active-search");

  let rowsMap = Store.getState().active.rowsByKey || new Map();
  let renderToken = 0;

  // ── Helpers ────────────────────────────────────────────────

  function setLoading(on) {
    loadingEl.style.display = on ? "flex" : "none";
    refreshBtn.disabled = on;
  }

  function getFilteredRows() {
    const q = (Store.getState().active.filterText || "").trim().toLowerCase();
    const rows = Array.from(rowsMap.values());
    if (!q) return rows;
    return rows.filter((row) =>
      row.resource_name.toLowerCase().includes(q)
    );
  }

  // ── Real-time search ───────────────────────────────────────

  searchInput.addEventListener("input", () => {
    Store.setState({ active: { filterText: searchInput.value } });
    renderTable();
  });

  // ── Render table ───────────────────────────────────────────

  function renderTable() {
    const filtered = getFilteredRows();

    if (!filtered.length) {
      const hasData = rowsMap.size > 0;
      tbody.innerHTML = `<tr><td colspan="8">
        <div class="ds-empty">
          <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <rect x="3" y="3" width="18" height="18" rx="2"/>
            <path d="M9 9h6M9 12h6M9 15h4"/>
          </svg>
          <div class="ds-empty__title">${hasData ? "No match" : "No active resources"}</div>
          <div class="ds-empty__sub">${hasData ? "No resources match your filter." : "Register resources in Discovery to see them here."}</div>
        </div>
      </td></tr>`;
      return;
    }

    tbody.innerHTML = filtered.map((row) => {
      const key = pricingKey(row.resource_type, row.resource_name, row.region);
      const pricing = getCachedPricing(key);
      return renderActiveRow(row, {
        cost:    pricing?.cost    ?? null,
        savings: pricing?.savings ?? null,
      });
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

  // ── Sleep plan picker ──────────────────────────────────────

  async function choosePlan(resourceType) {
    const config = await Api.getAccountConfig(accountId);
    const wantedType = resourceType === "EKS_CLUSTER"  ? "EKS_CLUSTER_SLEEP"
                     : resourceType === "RDS_INSTANCE"  ? "RDS_SLEEP"
                     : resourceType === "EC2_INSTANCE"  ? "EC2_SLEEP"
                     : null;

    const plans = Object.entries(config?.sleep_plans || {})
      .filter(([, plan]) => plan?.plan_type === wantedType)
      .map(([name]) => name);

    if (!plans.length) throw new Error(`No sleep plan for ${resourceType}. Configure one in Sleep Plans.`);
    if (plans.length === 1) return plans[0];

    const host = qs("#ds-modalhost");
    return new Promise((resolve) => {
      host.innerHTML = `
        <div class="ds-modalbackdrop" data-backdrop="1"></div>
        <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Choose Sleep Plan">
          <div class="ds-modal__head">
            <div class="ds-modal__title">Choose Sleep Plan</div>
            <button class="ds-btn ds-btn--ghost ds-btn--icon" type="button" data-role="cancel" aria-label="Close">
              <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M1 1l12 12M13 1L1 13"/>
              </svg>
            </button>
          </div>
          <div class="ds-modal__body">
            <div class="ds-field">
              <label class="ds-label">Available plans for ${h(resourceType)}</label>
              <select class="ds-select" id="ds-plan-select">
                ${plans.map((name) => `<option value="${h(name)}">${h(name)}</option>`).join("")}
              </select>
            </div>
          </div>
          <div class="ds-modal__foot">
            <button class="ds-btn ds-btn--ghost" type="button" data-role="cancel">Cancel</button>
            <button class="ds-btn ds-btn--primary" type="button" data-role="confirm">Sleep with this plan</button>
          </div>
        </div>
      `;
      host.style.pointerEvents = "auto";
      const cleanup = (val) => { host.innerHTML = ""; host.style.pointerEvents = "none"; resolve(val); };
      host.addEventListener("click", (e) => {
        const role = e.target?.dataset?.role;
        if (role === "cancel") cleanup(null);
        if (role === "confirm") cleanup(qs("#ds-plan-select")?.value || plans[0]);
      }, { once: true });
    });
  }

  // ── Actions ────────────────────────────────────────────────

  async function doSleep(resourceType, resourceName, region) {
    const confirmed = await confirmModal({
      title: `Sleep ${resourceName}`,
      body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">
               Initiate sleep on <strong>${h(resourceName)}</strong> (${h(region)}).
             </p>`,
      confirmText: "Sleep",
    });
    if (!confirmed) return;

    let planName;
    try { planName = await choosePlan(resourceType); }
    catch (e) { return toast("Sleep Plans", e.message); }
    if (!planName) return;

    try {
      await Api.sleepResource(accountId, {
        resource_type: resourceType,
        resource_name: resourceName,
        region,
        plan_name: planName,
      });
      toast("Sleep", `${resourceName} → sleep initiated.`);
      await loadResources();
    } catch (e) {
      toast("Sleep", e.message || "Sleep failed.");
    }
  }

  async function doWake(resourceType, resourceName, region) {
    const confirmed = await confirmModal({
      title: `Wake ${resourceName}`,
      body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">
               Wake <strong>${h(resourceName)}</strong> (${h(region)}).
             </p>`,
      confirmText: "Wake",
    });
    if (!confirmed) return;

    try {
      await Api.wakeResource(accountId, {
        resource_type: resourceType,
        resource_name: resourceName,
        region,
      });
      toast("Wake", `${resourceName} → wake initiated.`);
      await loadResources();
    } catch (e) {
      toast("Wake", e.message || "Wake failed.");
    }
  }

  async function doUnregister(resourceType, resourceName, region) {
    const confirmed = await confirmModal({
      title: `Unregister ${resourceName}`,
      body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">
               Remove <strong>${h(resourceName)}</strong> from DeepSleep management.
               The resource will not be deleted from AWS.
             </p>`,
      confirmText: "Unregister",
      danger: true,
    });
    if (!confirmed) return;

    try {
      await Api.unregisterResource(accountId, {
        resource_type: resourceType,
        resource_name: resourceName,
        region,
      });
      toast("Unregister", `${resourceName} removed.`);
      await loadResources();
    } catch (e) {
      toast("Unregister", e.message || "Unregister failed.");
    }
  }

  // ── Load resources from API ────────────────────────────────

  async function loadResources(silent = false) {
    const token = ++renderToken;
    if (!silent) setLoading(true);

    try {
      // Unified endpoint returns all types in one call
      const resp = await Api.listResourceStates(accountId);
      const states = resp?.states || [];

      if (renderToken !== token) return; // navigated away

      rowsMap = buildRowsMap(states);
      Store.setState({
        active: {
          rowsByKey: rowsMap,
          lastPollAt: new Date().toISOString(),
          hasLoaded: true,
        },
      });

      renderTable();

      if (pollSpan) pollSpan.textContent = `Updated ${new Date().toLocaleTimeString()}`;

      // Fire-and-forget pricing for each resource (non-blocking)
      for (const row of rowsMap.values()) {
        // Don't await — let it resolve in the background
        fetchPricingForRow(accountId, row, token).then(() => {
          // If user navigated away, skip DOM update (handled inside fetchPricingForRow)
        });
      }
    } catch (e) {
      if (String(e.message || "").match(/401|403/)) {
        toast("Session", "Authentication lost. Please login.");
        location.hash = "#/login";
        return;
      }
      toast("Active Resources", e.message || "Load failed.");
    } finally {
      if (!silent && renderToken === token) setLoading(false);
    }
  }

  // ── Init ───────────────────────────────────────────────────

  refreshBtn.addEventListener("click", loadResources);

  // Use cached data immediately if available, load fresh in background if stale
  if (s.active.hasLoaded && rowsMap.size > 0) {
    renderTable();
    if (pollSpan) {
      const last = s.active.lastPollAt ? new Date(s.active.lastPollAt).toLocaleTimeString() : "—";
      pollSpan.textContent = `Updated ${last}`;
    }
    setLoading(false);
    // Silently refresh in background — no spinner
    loadResources(true);
  } else {
    await loadResources();
  }
}
