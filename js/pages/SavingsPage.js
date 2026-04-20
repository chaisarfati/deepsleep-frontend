import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import * as Api from "../api/services.js";

function fmt(v, decimals = 2) {
  const n = Number(v);
  if (!Number.isFinite(n)) return "—";
  return `$${n.toFixed(decimals)}`;
}

function nowIso() { return new Date().toISOString().slice(0, 16); }
function isoMinusDays(d) { return new Date(Date.now() - d * 86400000).toISOString().slice(0, 16); }

function tabToTypes(tab) {
  if (tab === "EKS_CLUSTER")  return ["EKS_CLUSTER"];
  if (tab === "RDS_INSTANCE") return ["RDS_INSTANCE"];
  if (tab === "EC2_INSTANCE") return ["EC2_INSTANCE"];
  return ["EKS_CLUSTER", "RDS_INSTANCE", "EC2_INSTANCE"];
}

export async function SavingsPage() {
  const page = qs("#ds-page");
  if (!page) return;

  const s = Store.getState();
  if (!s.auth.token)  { toast("Auth", "Please login."); location.hash = "#/login"; return; }
  if (!s.account.id) {
    page.innerHTML = `<div class="ds-empty">
      <div class="ds-empty__title">No account selected</div>
      <div class="ds-empty__sub">Choose an account from the sidebar.</div>
    </div>`;
    return;
  }

  const currentTab = s.savings?.resourceTab || "ALL";
  Store.setState({ savings: { resourceTab: currentTab } });

  page.innerHTML = `
    <div class="ds-page-header">
      <div>
        <div class="ds-page-title">Savings</div>
        <div class="ds-page-sub">Compute cost savings across your registered AWS resources.</div>
      </div>
    </div>

    <!-- Hero -->
    <div class="ds-savings-hero" id="ds-sav-hero">
      <div class="ds-savings-hero__label" id="ds-sav-hero-label">Total Savings</div>
      <div class="ds-savings-hero__amount" id="ds-sav-total">—</div>
      <div class="ds-savings-hero__sub" id="ds-sav-range">Select a date range and click Load.</div>
    </div>

    <!-- Filters -->
    <div class="ds-panel">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Filters</div>
          <div class="ds-panel__sub">POST /accounts/{id}/price-savings</div>
        </div>
        <button class="ds-btn ds-btn--primary" id="ds-sav-run" type="button">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.7">
            <circle cx="7" cy="7" r="5.5"/>
            <path d="M5.5 4l4 3-4 3V4z"/>
          </svg>
          Load Savings
        </button>
      </div>
      <div class="ds-panel__body">
        <div class="ds-row" style="gap:14px;align-items:flex-end;flex-wrap:wrap;">
          <div class="ds-field" style="min-width:200px;">
            <label class="ds-label" for="ds-sav-from">From</label>
            <input class="ds-input" id="ds-sav-from" type="datetime-local" value="${isoMinusDays(7)}" />
          </div>
          <div class="ds-field" style="min-width:200px;">
            <label class="ds-label" for="ds-sav-to">To</label>
            <input class="ds-input" id="ds-sav-to" type="datetime-local" value="${nowIso()}" />
          </div>
          <div class="ds-field" style="min-width:180px;">
            <label class="ds-label" for="ds-sav-region">Region</label>
            <input class="ds-input" id="ds-sav-region" value="eu-west-1" placeholder="eu-west-1" />
          </div>
          <div class="ds-field">
            <label class="ds-label">Resource type</label>
            <div id="ds-savings-tabs"></div>
          </div>
        </div>
      </div>
    </div>

    <!-- Breakdown -->
    <div id="ds-sav-breakdown"></div>
  `;

  const tabsBox   = qs("#ds-savings-tabs");
  const breakdown = qs("#ds-sav-breakdown");
  const totalEl   = qs("#ds-sav-total");
  const rangeEl   = qs("#ds-sav-range");

  function renderTabs() {
    const current = Store.getState().savings?.resourceTab || "ALL";
    tabsBox.innerHTML = `
      <div class="ds-tabs" role="tablist" aria-label="Resource type">
        <button class="ds-tab" type="button" data-stab="ALL"          aria-selected="${current === "ALL"          ? "true" : "false"}">All</button>
        <button class="ds-tab" type="button" data-stab="EKS_CLUSTER"  aria-selected="${current === "EKS_CLUSTER"  ? "true" : "false"}">EKS</button>
        <button class="ds-tab" type="button" data-stab="RDS_INSTANCE" aria-selected="${current === "RDS_INSTANCE" ? "true" : "false"}">RDS</button>
        <button class="ds-tab" type="button" data-stab="EC2_INSTANCE" aria-selected="${current === "EC2_INSTANCE" ? "true" : "false"}">EC2</button>
      </div>
    `;
    qsa("[data-stab]", tabsBox).forEach((btn) => {
      btn.addEventListener("click", () => {
        Store.setState({ savings: { resourceTab: btn.dataset.stab } });
        renderTabs();
      });
    });
  }

  async function loadSavings() {
    const accountId = Store.getState().account.id;
    const from = qs("#ds-sav-from")?.value;
    const to   = qs("#ds-sav-to")?.value;
    const region = (qs("#ds-sav-region")?.value || "").trim();
    const resource_types = tabToTypes(Store.getState().savings?.resourceTab || "ALL");

    if (!from || !to)  { toast("Savings", "From and To dates are required."); return; }
    if (!region)       { toast("Savings", "Region is required."); return; }

    totalEl.textContent = "Loading…";
    breakdown.innerHTML = `<div class="ds-loading"><div class="ds-spinner"></div>Fetching savings data…</div>`;

    try {
      const resp = await Api.getAccountPriceSavings(accountId, {
        resource_types,
        region,
        from_date: new Date(from).toISOString(),
        to_date:   new Date(to).toISOString(),
      });

      const total = Number(resp?.total_savings ?? 0);
      totalEl.textContent = `$${total.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
      // Update hero label to reflect actual date range
      const heroLabel = qs("#ds-sav-hero-label");
      if (heroLabel) {
        const fromDate = new Date(from);
        const toDate   = new Date(to);
        const days = Math.round((toDate - fromDate) / (1000 * 60 * 60 * 24));
        heroLabel.textContent = `Total Savings (${days} day${days !== 1 ? "s" : ""})`;
      }
      rangeEl.textContent = `${region} · ${resource_types.join(", ")} · ${new Date(from).toLocaleDateString()} → ${new Date(to).toLocaleDateString()}`;

      // Render breakdown
      const byType = resp?.savings_by_resource_type || {};
      const types = Object.keys(byType);

      if (!types.length) {
        breakdown.innerHTML = `
          <div class="ds-empty">
            <div class="ds-empty__title">No savings data</div>
            <div class="ds-empty__sub">No resources recorded savings in this period.</div>
          </div>`;
        return;
      }

      breakdown.innerHTML = types.map((type) => {
        const resources = byType[type] || {};
        const rows = Object.entries(resources).sort((a, b) => Number(b[1]) - Number(a[1]));
        const typeTotal = rows.reduce((acc, [, v]) => acc + Number(v || 0), 0);

        return `
          <div class="ds-panel" style="margin-bottom:12px;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">${h(type)}</div>
                <div class="ds-panel__sub">Total: ${fmt(typeTotal)}</div>
              </div>
              <span class="ds-badge ds-badge--success" style="font-size:15px;padding:8px 14px;">${fmt(typeTotal)}</span>
            </div>
            <div class="ds-panel__body" style="padding-top:0;">
              <div class="ds-tablewrap">
                <table class="ds-table">
                  <thead>
                    <tr>
                      <th>Resource</th>
                      <th style="text-align:right;">Savings</th>
                      <th style="text-align:right;">Share</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${rows.map(([name, value]) => `
                      <tr>
                        <td><span class="ds-mono" style="font-size:12px;">${h(name)}</span></td>
                        <td style="text-align:right;">
                          <span class="ds-badge ds-badge--success">${fmt(value)}</span>
                        </td>
                        <td style="text-align:right;">
                          <span class="ds-mono" style="color:var(--fg-muted);">
                            ${typeTotal > 0 ? `${((Number(value) / typeTotal) * 100).toFixed(1)}%` : "—"}
                          </span>
                        </td>
                      </tr>
                    `).join("")}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        `;
      }).join("");

    } catch (e) {
      totalEl.textContent = "—";
      breakdown.innerHTML = `<div class="ds-empty">
        <div class="ds-empty__title">Error loading savings</div>
        <div class="ds-empty__sub">${h(e.message || "Unknown error")}</div>
      </div>`;
      toast("Savings", e.message || "Load failed.");
    }
  }

  qs("#ds-sav-run")?.addEventListener("click", loadSavings);
  renderTabs();
  await loadSavings();
}
