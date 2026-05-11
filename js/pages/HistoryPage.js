/**
 * HistoryPage.js — Audit log
 * Full redesign: timeline layout, real filters, expandable step details
 */
import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import * as Api from "../api/services.js";

// ── Default date range: last 7 days ──────────────────────────────────────────

function nowIso()        { return new Date().toISOString().slice(0, 16); }
function daysAgoIso(d)   { return new Date(Date.now() - d * 86400000).toISOString().slice(0, 16); }

function csvToList(v) { return String(v || "").split(",").map(s => s.trim()).filter(Boolean); }

// ── Chip helpers ──────────────────────────────────────────────────────────────

function stateChip(state) {
  if (!state) return `<span class="ds-badge">—</span>`;
  const s = state.toUpperCase();
  if (s === "SUCCEEDED" || s === "COMPLETED" || s === "SUCCESS")
    return `<span class="ds-badge ds-badge--success"><span class="ds-badge-dot"></span>${h(state)}</span>`;
  if (s === "FAILED" || s === "ERROR")
    return `<span class="ds-badge ds-badge--danger"><span class="ds-badge-dot"></span>${h(state)}</span>`;
  if (s === "RUNNING" || s === "PENDING")
    return `<span class="ds-badge ds-badge--accent"><span class="ds-badge-dot" style="animation:pulse 1.5s ease-in-out infinite;"></span>${h(state)}</span>`;
  return `<span class="ds-badge"><span class="ds-badge-dot"></span>${h(state)}</span>`;
}

function actionChip(action) {
  if (!action) return `<span class="ds-badge">—</span>`;
  const a = action.toUpperCase();
  if (a === "SLEEP") return `<span class="ds-badge" style="background:var(--stone-100);">
    <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6">
      <path d="M10 7.5A5 5 0 0 1 4.5 2 5 5 0 1 0 10 7.5z"/>
    </svg>Sleep</span>`;
  if (a === "WAKE") return `<span class="ds-badge ds-badge--accent">
    <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6">
      <path d="M3 2l7 4-7 4V2z"/>
    </svg>Wake</span>`;
  return `<span class="ds-badge">${h(action)}</span>`;
}

function typeChip(rtype) {
  const cls = rtype === "EKS_CLUSTER" ? "ds-resource-chip--eks" : rtype === "RDS_INSTANCE" ? "ds-resource-chip--rds" : "ds-resource-chip--ec2";
  const short = rtype === "EKS_CLUSTER" ? "EKS" : rtype === "RDS_INSTANCE" ? "RDS" : rtype === "EC2_INSTANCE" ? "EC2" : rtype;
  return `<span class="ds-resource-chip ${cls}" style="font-size:11px;">${h(short)}</span>`;
}

function duration(start, end) {
  if (!start || !end) return null;
  const s = (new Date(end) - new Date(start)) / 1000;
  if (s < 60)  return `${Math.round(s)}s`;
  if (s < 3600) return `${Math.floor(s/60)}m ${Math.round(s%60)}s`;
  return `${Math.floor(s/3600)}h ${Math.floor((s%3600)/60)}m`;
}

// ── Run card ──────────────────────────────────────────────────────────────────

function renderRunCard(run) {
  const steps = run.steps || [];
  const dur = duration(run.started_at, run.finished_at);
  const hasError = run.error || steps.some(s => s.error);

  return `
    <div class="ds-run-card" data-run-id="${run.id}">
      <!-- Header row -->
      <div class="ds-run-card__head" style="cursor:pointer;" data-run-toggle="${run.id}">
        <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;min-width:0;">
          <!-- Status stripe -->
          <div style="width:3px;height:36px;border-radius:99px;background:${
            (run.state||"").toUpperCase() === "SUCCEEDED" ? "var(--success)" :
            (run.state||"").toUpperCase() === "FAILED"    ? "var(--danger)" :
            "var(--accent)"
          };flex-shrink:0;"></div>

          <!-- Identity -->
          <div style="min-width:0;">
            <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
              ${typeChip(run.resource_type)}
              <span class="ds-mono" style="font-size:13px;font-weight:600;color:var(--fg-strong);">${h(run.resource_name)}</span>
              <span class="ds-mono" style="font-size:11px;color:var(--fg-faint);">#${run.id}</span>
            </div>
            <div style="display:flex;align-items:center;gap:8px;margin-top:4px;flex-wrap:wrap;">
              ${actionChip(run.action)}
              ${stateChip(run.state)}
              <span class="ds-badge">
                <svg width="9" height="9" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6">
                  <path d="M1 3h10M3.5 3V1.5h5V3M2.5 3l.75 7h5.5l.75-7"/>
                </svg>
                ${h(run.region)}
              </span>
              ${dur ? `<span class="ds-badge">⏱ ${h(dur)}</span>` : ""}
              ${hasError ? `<span class="ds-badge ds-badge--danger">⚠ Error</span>` : ""}
            </div>
          </div>
        </div>

        <div style="display:flex;align-items:center;gap:8px;flex-shrink:0;">
          <div style="text-align:right;">
            <div class="ds-mono" style="font-size:11.5px;color:var(--fg-muted);">
              ${run.started_at ? h(fmtTime(run.started_at)) : "—"}
            </div>
            ${run.finished_at ? `<div class="ds-mono" style="font-size:11px;color:var(--fg-faint);">→ ${h(fmtTime(run.finished_at))}</div>` : ""}
          </div>
          <!-- Chevron -->
          <svg class="ds-run-chevron" data-for="${run.id}" width="14" height="14" viewBox="0 0 14 14"
            fill="none" stroke="currentColor" stroke-width="1.8"
            style="transition:transform 160ms ease;flex-shrink:0;color:var(--fg-faint);">
            <path d="M3 5l4 4 4-4"/>
          </svg>
        </div>
      </div>

      <!-- Expandable steps -->
      <div id="ds-run-steps-${run.id}" style="display:none;">
        <div style="border-top:1px solid var(--border);padding:16px 18px;">
          ${run.error ? `<div style="padding:10px 12px;background:var(--danger-bg);border:1px solid var(--danger-border);border-radius:var(--r-md);margin-bottom:12px;">
            <span class="ds-mono" style="font-size:12px;color:var(--danger);">${h(run.error)}</span>
          </div>` : ""}

          ${!steps.length
            ? `<div class="ds-mono" style="color:var(--fg-faint);font-size:12.5px;">No step details recorded.</div>`
            : `<div class="ds-tablewrap" style="border-radius:var(--r-md);">
                <table class="ds-table" style="min-width:580px;">
                  <thead><tr>
                    <th>#</th><th>Step</th><th>State</th><th>Started</th><th>Duration</th><th>Error</th>
                  </tr></thead>
                  <tbody>
                    ${steps.map(step => `<tr>
                      <td><span class="ds-mono" style="color:var(--fg-faint);">${step.order_index ?? step.id}</span></td>
                      <td><span class="ds-mono" style="font-size:12px;">${h(step.step_type)}</span></td>
                      <td>${stateChip(step.state)}</td>
                      <td><span class="ds-mono" style="font-size:11.5px;">${step.started_at ? h(fmtTime(step.started_at)) : "—"}</span></td>
                      <td><span class="ds-mono" style="font-size:11.5px;">${duration(step.started_at, step.finished_at) || "—"}</span></td>
                      <td><span class="ds-mono" style="font-size:11.5px;color:var(--danger);">${h(step.error || "—")}</span></td>
                    </tr>`).join("")}
                  </tbody>
                </table>
              </div>`
          }
        </div>
      </div>
    </div>
  `;
}

// ── Page ──────────────────────────────────────────────────────────────────────

export async function HistoryPage() {
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

  // Default filter: last 7 days
  const defaultFrom = daysAgoIso(7);
  const defaultTo   = nowIso();

  page.innerHTML = `
    <div class="ds-page-header">
      <div>
        <div class="ds-page-title">History</div>
        <div class="ds-page-sub">Audit log of all sleep and wake operations across your resources.</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="ds-panel" style="margin-bottom:16px;">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Filters</div>
        </div>
        <button class="ds-btn ds-btn--primary" id="ds-h-run" type="button">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.7">
            <circle cx="6" cy="6" r="4"/><path d="M10 10l3 3"/>
          </svg>
          Search
        </button>
      </div>
      <div class="ds-panel__body">
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr 1fr;gap:12px;align-items:end;flex-wrap:wrap;">
          <div class="ds-field">
            <label class="ds-label" for="ds-h-from">From</label>
            <input class="ds-input" id="ds-h-from" type="datetime-local" value="${defaultFrom}"/>
          </div>
          <div class="ds-field">
            <label class="ds-label" for="ds-h-to">To</label>
            <input class="ds-input" id="ds-h-to" type="datetime-local" value="${defaultTo}"/>
          </div>
          <div class="ds-field">
            <label class="ds-label" for="ds-h-regions">Regions</label>
            <input class="ds-input" id="ds-h-regions" placeholder="eu-west-1, us-east-1"/>
          </div>
          <div class="ds-field">
            <label class="ds-label" for="ds-h-types">Resource types</label>
            <select class="ds-select" id="ds-h-types">
              <option value="">All types</option>
              <option value="EKS_CLUSTER">EKS</option>
              <option value="RDS_INSTANCE">RDS</option>
              <option value="EC2_INSTANCE">EC2</option>
            </select>
          </div>
        </div>

        <!-- Quick range buttons -->
        <div class="ds-row" style="margin-top:12px;gap:6px;">
          <span class="ds-mono" style="font-size:11px;color:var(--fg-faint);line-height:30px;">Quick:</span>
          ${[1, 7, 14, 30].map(d =>
            `<button class="ds-btn ds-btn--sm ds-btn--ghost" data-quick-days="${d}" type="button">Last ${d}d</button>`
          ).join("")}
        </div>
      </div>
    </div>

    <!-- Status + loading -->
    <div class="ds-row" style="margin-bottom:12px;gap:10px;align-items:center;">
      <div id="ds-h-loading" style="display:none;align-items:center;gap:8px;">
        <div class="ds-spinner"></div>
        <span class="ds-mono" style="font-size:12px;color:var(--accent);">Loading…</span>
      </div>
      <span class="ds-mono" id="ds-h-status" style="color:var(--fg-faint);font-size:12.5px;"></span>
      <div class="ds-spacer"></div>
      <!-- Action filter -->
      <div class="ds-tabs" style="height:32px;" role="tablist" id="ds-h-action-tabs">
        ${["ALL","SLEEP","WAKE"].map(a =>
          `<button class="ds-tab" type="button" data-action-tab="${a}" aria-selected="${a === "ALL"}" style="min-height:28px;padding:0 12px;font-size:12px;">${a === "ALL" ? "All" : a}</button>`
        ).join("")}
      </div>
      <!-- Local search -->
      <input class="ds-input" id="ds-h-search" placeholder="Filter by name…"
        style="width:200px;min-height:32px;padding:5px 10px;font-size:12.5px;"/>
    </div>

    <!-- Stats bar -->
    <div class="ds-stat-grid" id="ds-h-stats" style="grid-template-columns:repeat(4,1fr);margin-bottom:16px;display:none;"></div>

    <!-- Results -->
    <div id="ds-h-results">
      <div class="ds-empty">
        <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <circle cx="12" cy="12" r="8"/><path d="M12 6v6l3 2"/>
        </svg>
        <div class="ds-empty__title">Select a date range and click Search</div>
        <div class="ds-empty__sub">Default shows the last 7 days.</div>
      </div>
    </div>
  `;

  const statusEl  = qs("#ds-h-status");
  const loadingEl = qs("#ds-h-loading");
  const resultsEl = qs("#ds-h-results");
  const statsEl   = qs("#ds-h-stats");
  const searchEl  = qs("#ds-h-search");

  let allRuns = [];
  let activeActionTab = "ALL";

  // ── Quick range ───────────────────────────────────────────────────────────

  qsa("[data-quick-days]").forEach(btn => {
    btn.addEventListener("click", () => {
      const d = Number(btn.dataset.quickDays);
      qs("#ds-h-from").value = daysAgoIso(d);
      qs("#ds-h-to").value   = nowIso();
    });
  });

  // ── Action tabs ───────────────────────────────────────────────────────────

  function bindActionTabs() {
    qsa("[data-action-tab]").forEach(btn => {
      btn.addEventListener("click", () => {
        activeActionTab = btn.dataset.actionTab;
        qsa("[data-action-tab]").forEach(b => b.setAttribute("aria-selected", b === btn ? "true" : "false"));
        renderFiltered();
      });
    });
  }

  // ── Local filter ──────────────────────────────────────────────────────────

  searchEl.addEventListener("input", renderFiltered);

  function renderFiltered() {
    const q = (searchEl.value || "").trim().toLowerCase();
    const filtered = allRuns.filter(r => {
      if (activeActionTab !== "ALL" && r.action?.toUpperCase() !== activeActionTab) return false;
      if (q && !(r.resource_name || "").toLowerCase().includes(q)) return false;
      return true;
    });

    if (!filtered.length) {
      resultsEl.innerHTML = `<div class="ds-empty">
        <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <circle cx="12" cy="12" r="8"/><path d="M12 6v6l3 2"/>
        </svg>
        <div class="ds-empty__title">${allRuns.length ? "No match" : "No operations found"}</div>
        <div class="ds-empty__sub">${allRuns.length ? "Try adjusting filters." : "No sleep or wake operations in this time range."}</div>
      </div>`;
      return;
    }

    resultsEl.innerHTML = `<div style="display:grid;gap:8px;">${filtered.map(r => renderRunCard(r)).join("")}</div>`;
    bindExpandToggles();
  }

  function bindExpandToggles() {
    qsa("[data-run-toggle]", resultsEl).forEach(header => {
      header.addEventListener("click", () => {
        const id = header.dataset.runToggle;
        const body = qs(`#ds-run-steps-${id}`);
        const chevron = qs(`[data-for="${id}"].ds-run-chevron`);
        if (!body) return;
        const isOpen = body.style.display !== "none";
        body.style.display = isOpen ? "none" : "block";
        if (chevron) chevron.style.transform = isOpen ? "" : "rotate(180deg)";
      });
    });
  }

  // ── Stats bar ─────────────────────────────────────────────────────────────

  function renderStats(runs) {
    const total     = runs.length;
    const succeeded = runs.filter(r => (r.state||"").toUpperCase() === "SUCCEEDED").length;
    const failed    = runs.filter(r => (r.state||"").toUpperCase() === "FAILED").length;
    const sleeping  = runs.filter(r => (r.action||"").toUpperCase() === "SLEEP").length;

    statsEl.style.display = "grid";
    statsEl.innerHTML = `
      <div class="ds-stat"><div class="ds-stat__label">Total runs</div><div class="ds-stat__value">${total}</div></div>
      <div class="ds-stat ds-stat--success"><div class="ds-stat__label">Succeeded</div><div class="ds-stat__value">${succeeded}</div></div>
      <div class="ds-stat ds-stat--${failed ? "danger" : ""}"><div class="ds-stat__label">Failed</div><div class="ds-stat__value" ${failed ? 'style="color:var(--danger);"' : ""}>${failed}</div></div>
      <div class="ds-stat"><div class="ds-stat__label">Sleep ops</div><div class="ds-stat__value">${sleeping}</div></div>
    `;
    // Override danger stat color
    if (!failed) statsEl.querySelectorAll(".ds-stat")[2].querySelector(".ds-stat__value").style.color = "";
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  async function loadHistory() {
    const accountId = Store.getState().account.id;
    const from = qs("#ds-h-from")?.value || "";
    const to   = qs("#ds-h-to")?.value   || "";
    const regionRaw = qs("#ds-h-regions")?.value || "";
    const typeVal   = qs("#ds-h-types")?.value || "";

    if (!from || !to) return toast("History", "Please select a date range.");

    const params = {
      from_date: new Date(from).toISOString(),
      to_date:   new Date(to).toISOString(),
    };
    const regions = csvToList(regionRaw);
    if (regions.length) params.regions = regions;
    if (typeVal)        params.resource_types = [typeVal];

    loadingEl.style.display = "flex";
    statusEl.textContent = "";
    statsEl.style.display = "none";
    resultsEl.innerHTML = `<div class="ds-loading"><div class="ds-spinner"></div>Fetching history…</div>`;

    try {
      const runs = await Api.listRuns(accountId, params);
      allRuns = Array.isArray(runs) ? runs : (runs?.runs || []);
      Store.setState({ history: { runs: allRuns } });

      const dayDiff = Math.round((new Date(to) - new Date(from)) / 86400000);
      statusEl.textContent = `${allRuns.length} run(s) · last ${dayDiff}d`;

      renderStats(allRuns);
      renderFiltered();
    } catch (e) {
      statsEl.style.display = "none";
      resultsEl.innerHTML = `<div class="ds-empty">
        <div class="ds-empty__title">Error loading history</div>
        <div class="ds-empty__sub">${h(e.message || "Unknown error")}</div>
      </div>`;
      toast("History", e.message || "Load failed.");
    } finally {
      loadingEl.style.display = "none";
    }
  }

  qs("#ds-h-run")?.addEventListener("click", loadHistory);
  bindActionTabs();

  // Auto-load with defaults
  await loadHistory();
}
