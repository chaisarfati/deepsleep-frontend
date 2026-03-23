import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { qs, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";

function requireAuthAndAccount() {
  const s = Store.getState();
  if (!s.auth.token) {
    toast("Auth", "Please login.");
    location.hash = "#/login";
    return false;
  }
  if (!s.account.id) {
    toast("Account", "Choose an account from Switch Account first.");
    return false;
  }
  return true;
}

function formatUsd(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return "—";
  return `$${n.toFixed(2)}`;
}

function nowIsoMinusDays(days) {
  const d = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  return d.toISOString().slice(0, 16);
}

function renderBreakdown(data) {
  const breakdown = data?.savings_by_resource_type || {};
  const types = Object.keys(breakdown);

  if (!types.length) {
    return `<div class="ds-mono-muted">No savings data for this selection.</div>`;
  }

  return types.map((type) => {
    const resources = breakdown[type] || {};
    const rows = Object.entries(resources).sort((a, b) => Number(b[1]) - Number(a[1]));
    const total = rows.reduce((acc, [, v]) => acc + Number(v || 0), 0);

    return `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head">
          <div>
            <div class="ds-panel__title">${h(type)}</div>
            <div class="ds-panel__sub">Total: ${formatUsd(total)}</div>
          </div>
        </div>

        <div class="ds-tablewrap">
          <table class="ds-table">
            <thead>
              <tr>
                <th>Resource</th>
                <th>Savings</th>
              </tr>
            </thead>
            <tbody>
              ${rows.map(([name, value]) => `
                <tr>
                  <td>${h(name)}</td>
                  <td>${formatUsd(value)}</td>
                </tr>
              `).join("")}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }).join("");
}

export async function SavingsPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Savings";

  page.innerHTML = renderPanel({
    title: "Savings Overview",
    sub: "Consult total compute savings for a date range, region and selected resource types.",
    bodyHtml: `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head">
          <div>
            <div class="ds-panel__title">Filters</div>
            <div class="ds-panel__sub">Uses POST /accounts/{account_id}/price-savings</div>
          </div>
        </div>

        <div class="ds-row">
          <div class="ds-field" style="min-width:240px;">
            <div class="ds-label">From</div>
            <input class="ds-input" id="ds-sav-from" type="datetime-local" value="${nowIsoMinusDays(7)}" />
          </div>

          <div class="ds-field" style="min-width:240px;">
            <div class="ds-label">To</div>
            <input class="ds-input" id="ds-sav-to" type="datetime-local" value="${new Date().toISOString().slice(0,16)}" />
          </div>

          <div class="ds-field" style="min-width:220px;">
            <div class="ds-label">Region</div>
            <input class="ds-input" id="ds-sav-region" value="eu-west-1" placeholder="eu-west-1" />
          </div>

          <div class="ds-field" style="min-width:280px;">
            <div class="ds-label">Resource Types</div>
            <div class="ds-row" style="gap:10px;">
              <label class="ds-badge" style="gap:10px;">
                <input type="checkbox" id="ds-sav-eks" checked />
                <span>EKS_CLUSTER</span>
              </label>
              <label class="ds-badge" style="gap:10px;">
                <input type="checkbox" id="ds-sav-rds" checked />
                <span>RDS_INSTANCE</span>
              </label>
            </div>
          </div>

          <div class="ds-row" style="align-self:flex-end;">
            <button class="ds-btn ds-btn--wake" id="ds-sav-run" type="button">Load Savings</button>
          </div>
        </div>
      </div>

      <div id="ds-sav-summary"></div>
      <div id="ds-sav-breakdown"></div>
    `,
  });

  if (!requireAuthAndAccount()) return;

  const summary = qs("#ds-sav-summary");
  const breakdown = qs("#ds-sav-breakdown");

  async function loadSavings() {
    try {
      const accountId = Store.getState().account.id;
      const from = qs("#ds-sav-from")?.value;
      const to = qs("#ds-sav-to")?.value;
      const region = (qs("#ds-sav-region")?.value || "").trim();

      const resource_types = [];
      if (qs("#ds-sav-eks")?.checked) resource_types.push("EKS_CLUSTER");
      if (qs("#ds-sav-rds")?.checked) resource_types.push("RDS_INSTANCE");

      if (!from || !to) throw new Error("from/to are required");
      if (!region) throw new Error("region is required");
      if (!resource_types.length) throw new Error("Select at least one resource type");

      const payload = {
        resource_types,
        region,
        from_date: new Date(from).toISOString(),
        to_date: new Date(to).toISOString(),
      };

      summary.innerHTML = `<div class="ds-mono-muted">Loading…</div>`;
      breakdown.innerHTML = "";

      const resp = await Api.getAccountPriceSavings(accountId, payload);

      summary.innerHTML = `
        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Global Savings</div>
              <div class="ds-panel__sub">
                ${h(resp.from_date)} → ${h(resp.to_date)} • ${h(resp.currency || "USD")}
              </div>
            </div>
          </div>

          <div class="ds-row">
            <span class="ds-badge ds-badge--reg" style="font-size:16px;padding:10px 14px;">
              Total: ${formatUsd(resp.total_savings)}
            </span>
            <span class="ds-badge">Region: ${h(region)}</span>
            <span class="ds-badge">Types: ${h(resource_types.join(", "))}</span>
          </div>
        </div>
      `;

      breakdown.innerHTML = renderBreakdown(resp);
    } catch (e) {
      summary.innerHTML = `<div class="ds-mono-muted">Error.</div>`;
      breakdown.innerHTML = "";
      toast("Savings", e.message || "Load failed");
    }
  }

  qs("#ds-sav-run")?.addEventListener("click", loadSavings);
  await loadSavings();
}
