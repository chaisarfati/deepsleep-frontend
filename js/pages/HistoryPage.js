import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import * as Api from "../api/services.js";

function csvToList(v) {
  return String(v || "").split(",").map((s) => s.trim()).filter(Boolean);
}

function stateChip(state) {
  if (!state) return `<span class="ds-badge">—</span>`;
  const s = state.toLowerCase();
  if (s === "completed" || s === "success") return `<span class="ds-badge ds-badge--success"><span class="ds-badge-dot"></span>${h(state)}</span>`;
  if (s === "failed"    || s === "error")   return `<span class="ds-badge ds-badge--danger"><span class="ds-badge-dot"></span>${h(state)}</span>`;
  if (s === "running"   || s === "pending") return `<span class="ds-badge ds-badge--accent"><span class="ds-badge-dot"></span>${h(state)}</span>`;
  return `<span class="ds-badge"><span class="ds-badge-dot"></span>${h(state)}</span>`;
}

function actionChip(action) {
  if (!action) return `<span class="ds-badge">—</span>`;
  const a = action.toLowerCase();
  if (a === "sleep") return `<span class="ds-badge" style="background:var(--stone-100);">
    <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6">
      <path d="M10 7.5A5 5 0 0 1 4.5 2 5 5 0 1 0 10 7.5z"/>
    </svg>
    Sleep
  </span>`;
  if (a === "wake") return `<span class="ds-badge ds-badge--accent">
    <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6">
      <path d="M3 2l7 4-7 4V2z"/>
    </svg>
    Wake
  </span>`;
  return `<span class="ds-badge">${h(action)}</span>`;
}

function renderStepsTable(steps = []) {
  if (!steps.length) return `<div class="ds-mono" style="color:var(--fg-faint);padding:10px 0;">No steps recorded.</div>`;

  return `
    <div class="ds-tablewrap" style="margin-top:10px;border-radius:var(--r-md);">
      <table class="ds-table" style="min-width:600px;">
        <thead>
          <tr>
            <th>#</th>
            <th>Step Type</th>
            <th>State</th>
            <th>Started</th>
            <th>Finished</th>
            <th>Error</th>
          </tr>
        </thead>
        <tbody>
          ${steps.map((s) => `
            <tr>
              <td><span class="ds-mono" style="color:var(--fg-faint);">${s.order_index ?? s.id}</span></td>
              <td><span class="ds-mono" style="font-size:12px;">${h(s.step_type)}</span></td>
              <td>${stateChip(s.state)}</td>
              <td><span class="ds-mono" style="font-size:11.5px;">${s.started_at  ? h(fmtTime(s.started_at))  : "—"}</span></td>
              <td><span class="ds-mono" style="font-size:11.5px;">${s.finished_at ? h(fmtTime(s.finished_at)) : "—"}</span></td>
              <td><span class="ds-mono" style="font-size:11.5px;color:var(--danger);">${h(s.error || "—")}</span></td>
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

  const s = Store.getState();
  if (!s.auth.token)  { toast("Auth", "Please login."); location.hash = "#/login"; return; }
  if (!s.account.id) {
    page.innerHTML = `<div class="ds-empty">
      <div class="ds-empty__title">No account selected</div>
      <div class="ds-empty__sub">Choose an account from the sidebar to view history.</div>
    </div>`;
    return;
  }

  page.innerHTML = `
    <div class="ds-page-header">
      <div>
        <div class="ds-page-title">History</div>
        <div class="ds-page-sub">Audit log of all sleep and wake operations across your resources.</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="ds-panel">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Filters</div>
          <div class="ds-panel__sub">GET /accounts/{id}/runs</div>
        </div>
        <button class="ds-btn ds-btn--primary" id="ds-h-run" type="button">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.7">
            <circle cx="7" cy="7" r="5.5"/>
            <path d="M5.5 4l4 3-4 3V4z"/>
          </svg>
          Load History
        </button>
      </div>
      <div class="ds-panel__body">
        <div class="ds-row" style="gap:14px;align-items:flex-end;flex-wrap:wrap;">
          <div class="ds-field" style="min-width:200px;">
            <label class="ds-label" for="ds-h-from">From date</label>
            <input class="ds-input" id="ds-h-from" type="datetime-local" />
          </div>
          <div class="ds-field" style="min-width:200px;">
            <label class="ds-label" for="ds-h-to">To date</label>
            <input class="ds-input" id="ds-h-to" type="datetime-local" />
          </div>
          <div class="ds-field" style="min-width:200px;">
            <label class="ds-label" for="ds-h-regions">Regions</label>
            <input class="ds-input" id="ds-h-regions" placeholder="eu-west-1, eu-central-1" />
          </div>
          <div class="ds-field" style="min-width:240px;">
            <label class="ds-label" for="ds-h-types">Resource types</label>
            <input class="ds-input" id="ds-h-types" placeholder="EKS_CLUSTER, RDS_INSTANCE" />
          </div>
        </div>
      </div>
    </div>

    <!-- Status + results -->
    <div class="ds-mono" id="ds-h-status" style="color:var(--fg-faint);margin-bottom:12px;">—</div>
    <div id="ds-h-results"></div>
  `;

  const status  = qs("#ds-h-status");
  const results = qs("#ds-h-results");

  async function loadHistory() {
    const accountId    = Store.getState().account.id;
    const from_date    = qs("#ds-h-from")?.value || "";
    const to_date      = qs("#ds-h-to")?.value   || "";
    const regions      = csvToList(qs("#ds-h-regions")?.value);
    const resource_types = csvToList(qs("#ds-h-types")?.value);

    const params = {};
    if (from_date) params.from_date = new Date(from_date).toISOString();
    if (to_date)   params.to_date   = new Date(to_date).toISOString();
    if (regions.length)       params.regions        = regions;
    if (resource_types.length) params.resource_types = resource_types;

    status.textContent = "Loading…";
    results.innerHTML  = `<div class="ds-loading"><div class="ds-spinner"></div>Fetching run history…</div>`;

    try {
      const runs = await Api.listRuns(accountId, params);
      Store.setState({ history: { runs } });

      status.textContent = `${runs.length} run(s) found`;

      if (!runs.length) {
        results.innerHTML = `
          <div class="ds-empty">
            <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <circle cx="12" cy="12" r="8"/><path d="M12 6v6l3 2"/>
            </svg>
            <div class="ds-empty__title">No history yet</div>
            <div class="ds-empty__sub">Sleep and wake operations will appear here once executed.</div>
          </div>`;
        return;
      }

      results.innerHTML = runs.map((run) => `
        <div class="ds-run-card">
          <div class="ds-run-card__head">
            <div class="ds-row" style="gap:10px;flex-wrap:wrap;">
              <span class="ds-run-card__id">Run #${run.id}</span>
              <div class="ds-run-card__name">${h(run.resource_name)}</div>
            </div>
            <div class="ds-row" style="gap:6px;flex-shrink:0;">
              ${actionChip(run.action)}
              ${stateChip(run.state)}
            </div>
          </div>
          <div class="ds-run-card__body">
            <div class="ds-run-card__meta">
              <span class="ds-badge">
                <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6">
                  <rect x="1" y="1" width="10" height="10" rx="2"/>
                  <path d="M4 5h4M4 7.5h2"/>
                </svg>
                ${h(run.resource_type)}
              </span>
              <span class="ds-badge">
                <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6">
                  <circle cx="6" cy="6" r="4.5"/><path d="M6 3.5V6l2 1.5"/>
                </svg>
                ${run.started_at ? h(fmtTime(run.started_at)) : "—"}
              </span>
              ${run.finished_at ? `<span class="ds-badge">Done: ${h(fmtTime(run.finished_at))}</span>` : ""}
              <span class="ds-badge">${h(run.region)}</span>
              ${run.error ? `<span class="ds-badge ds-badge--danger">${h(run.error)}</span>` : ""}
            </div>
            ${renderStepsTable(run.steps || [])}
          </div>
        </div>
      `).join("");

    } catch (e) {
      status.textContent = "Load failed.";
      results.innerHTML  = `<div class="ds-empty">
        <div class="ds-empty__title">Error loading history</div>
        <div class="ds-empty__sub">${h(e.message || "Unknown error")}</div>
      </div>`;
      toast("History", e.message || "Load failed.");
    }
  }

  qs("#ds-h-run")?.addEventListener("click", loadHistory);
  await loadHistory();
}
