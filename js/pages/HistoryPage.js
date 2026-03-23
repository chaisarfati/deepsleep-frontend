import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { fmtTime } from "../utils/time.js";
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

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function renderSteps(steps) {
  const arr = Array.isArray(steps) ? steps : [];
  if (!arr.length) return `<div class="ds-mono-muted">No steps</div>`;

  return `
    <div class="ds-tablewrap" style="margin-top:8px;">
      <table class="ds-table" style="min-width:700px;">
        <thead>
          <tr>
            <th>ID</th>
            <th>Type</th>
            <th>Order</th>
            <th>State</th>
            <th>Error</th>
            <th>Started</th>
            <th>Finished</th>
          </tr>
        </thead>
        <tbody>
          ${arr.map((s) => `
            <tr>
              <td>${s.id}</td>
              <td>${h(s.step_type)}</td>
              <td>${s.order_index}</td>
              <td>${h(s.state)}</td>
              <td class="ds-mono-muted">${h(s.error || "—")}</td>
              <td>${s.started_at ? h(fmtTime(s.started_at)) : "—"}</td>
              <td>${s.finished_at ? h(fmtTime(s.finished_at)) : "—"}</td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    </div>
  `;
}

export async function HistoryPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "History";

  page.innerHTML = renderPanel({
    title: "History",
    sub: "Run history across your resources with filters on dates, regions and resource types.",
    bodyHtml: `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head">
          <div>
            <div class="ds-panel__title">Filters</div>
            <div class="ds-panel__sub">Call GET /accounts/{account_id}/runs with all supported query params</div>
          </div>
        </div>

        <div class="ds-row">
          <div class="ds-field" style="min-width:220px;">
            <div class="ds-label">From date</div>
            <input class="ds-input" id="ds-h-from" type="datetime-local" />
          </div>
          <div class="ds-field" style="min-width:220px;">
            <div class="ds-label">To date</div>
            <input class="ds-input" id="ds-h-to" type="datetime-local" />
          </div>
          <div class="ds-field" style="min-width:unset;flex:1;">
            <div class="ds-label">Regions (CSV)</div>
            <input class="ds-input" id="ds-h-regions" placeholder="eu-west-1,eu-central-1" />
          </div>
          <div class="ds-field" style="min-width:unset;flex:1;">
            <div class="ds-label">Resource types (CSV)</div>
            <input class="ds-input" id="ds-h-types" placeholder="EKS_CLUSTER,RDS_INSTANCE" />
          </div>
          <div class="ds-row" style="align-self:flex-end;">
            <button class="ds-btn" id="ds-h-run" type="button">Load History</button>
          </div>
        </div>
      </div>

      <div class="ds-mono-muted" id="ds-h-status">—</div>
      <div style="height:10px"></div>
      <div id="ds-h-results"></div>
    `,
  });

  if (!requireAuthAndAccount()) {
    qs("#ds-h-status").textContent = "Not ready.";
    return;
  }

  const status = qs("#ds-h-status");
  const results = qs("#ds-h-results");

  async function loadHistory() {
    try {
      const accountId = Store.getState().account.id;
      const from_date = qs("#ds-h-from")?.value || "";
      const to_date = qs("#ds-h-to")?.value || "";
      const regions = csvToList(qs("#ds-h-regions")?.value);
      const resource_types = csvToList(qs("#ds-h-types")?.value);

      const params = {};
      if (from_date) params.from_date = new Date(from_date).toISOString();
      if (to_date) params.to_date = new Date(to_date).toISOString();
      if (regions.length) params.regions = regions;
      if (resource_types.length) params.resource_types = resource_types;

      status.textContent = "Loading…";

      const runs = await Api.listRuns(accountId, params);
      Store.setState({ history: { runs } });

      status.textContent = `OK — ${runs.length} run(s).`;

      results.innerHTML = runs.map((run) => `
        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Run #${run.id} • ${h(run.resource_type)} • ${h(run.resource_name)}</div>
              <div class="ds-panel__sub">
                ${h(run.region)} • ${h(run.action)} • ${h(run.state)}
                • created ${h(fmtTime(run.created_at))}
              </div>
            </div>
          </div>

          <div class="ds-row" style="margin-bottom:8px;">
            <span class="ds-badge">Started: ${run.started_at ? h(fmtTime(run.started_at)) : "—"}</span>
            <span class="ds-badge">Finished: ${run.finished_at ? h(fmtTime(run.finished_at)) : "—"}</span>
            <span class="ds-badge">Error: ${h(run.error || "—")}</span>
          </div>

          ${renderSteps(run.steps)}
        </div>
      `).join("") || `<div class="ds-mono-muted">No runs found.</div>`;
    } catch (e) {
      status.textContent = "Error.";
      toast("History", e.message || "Load failed");
    }
  }

  qs("#ds-h-run")?.addEventListener("click", loadHistory);
  await loadHistory();
}
