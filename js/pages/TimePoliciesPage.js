/**
 * TimePoliciesPage.js — Schedule-based automation policies
 * 2026 redesign: policy cards + full-page drawer editor
 */
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import * as Api from "../api/services.js";

const DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];

function requireAuthAndAccount() {
  const s = Store.getState();
  if (!s.auth.token) { toast("Auth", "Please login."); location.hash = "#/login"; return false; }
  if (!s.account.id) { toast("Account", "Choose an account first."); return false; }
  return true;
}

// ── Data helpers ──────────────────────────────────────────────────────────────

function defaultWindow() {
  return { days: ["MON","TUE","WED","THU","FRI"], start: "21:00", end: "07:00", start_date: null, end_date: null };
}

function defaultCriteria() {
  return {
    resource_type: "EKS_CLUSTER",
    plan_name: "",
    regions: [],
    selector: { include_names: [], exclude_names: [], include_labels: {}, exclude_labels: {}, include_namespaces: null, exclude_namespaces: [] },
  };
}

function csvToList(v) { return String(v||"").split(",").map(s=>s.trim()).filter(Boolean); }
function listToCsv(v) { return Array.isArray(v) ? v.join(",") : ""; }
function kvCsvToDict(v) {
  const out = {};
  csvToList(v).forEach(p => { const i = p.indexOf("="); if (i > 0) out[p.slice(0,i).trim()] = p.slice(i+1).trim(); });
  return out;
}
function dictToKvCsv(d) {
  if (!d || typeof d !== "object") return "";
  return Object.entries(d).map(([k,v])=>`${k}=${v}`).join(", ");
}

function timezoneOptions(selected = "UTC") {
  const zones = typeof Intl !== "undefined" && Intl.supportedValuesOf
    ? Intl.supportedValuesOf("timeZone")
    : ["UTC","Europe/Paris","America/New_York","Asia/Tokyo","Asia/Jerusalem"];
  return zones.map(z => `<option value="${h(z)}" ${z===selected?"selected":""}>${h(z)}</option>`).join("");
}

function buildPolicyPayload(editorState) {
  const { name, enabled, timezone, windows, criteria } = editorState;
  if (!name) throw new Error("Policy name required.");
  if (!windows.length) throw new Error("Add at least one time window.");
  if (!criteria.length) throw new Error("Add at least one search criteria.");

  const resource_types = [], selector_by_type = {}, plan_name_by_type = {};
  const mergedRegions = new Set();

  for (const c of criteria) {
    resource_types.push(c.resource_type);
    if (c.plan_name) plan_name_by_type[c.resource_type] = c.plan_name;
    (c.regions || []).forEach(r => mergedRegions.add(r));
    selector_by_type[c.resource_type] = {
      include_names: c.selector.include_names?.length ? c.selector.include_names : null,
      exclude_names: c.selector.exclude_names || [],
      include_labels: c.selector.include_labels || {},
      exclude_labels: c.selector.exclude_labels || {},
      include_namespaces: c.selector.include_namespaces?.length ? c.selector.include_namespaces : null,
      exclude_namespaces: c.selector.exclude_namespaces || [],
    };
  }

  return {
    name, enabled, timezone,
    search: {
      resource_types: [...new Set(resource_types)],
      regions: mergedRegions.size ? Array.from(mergedRegions) : null,
      selector_by_type,
      only_registered: true,
    },
    windows: windows.map(w => ({
      days: w.days && w.days.length === 7 ? null : (w.days?.length ? w.days : null),
      start: w.start, end: w.end,
      start_date: w.start_date || null,
      end_date: w.end_date || null,
    })),
    plan_name_by_type,
  };
}

// ── Policy card ───────────────────────────────────────────────────────────────

function fmtNextTransition(ts) {
  if (!ts) return "—";
  const d = new Date(ts);
  const now = new Date();
  const diff = d - now;
  if (diff < 0) return "overdue";
  const h = Math.floor(diff / 3600000);
  const m = Math.floor((diff % 3600000) / 60000);
  if (h > 48) return `in ${Math.floor(h/24)}d`;
  if (h > 0) return `in ${h}h ${m}m`;
  return `in ${m}m`;
}

function renderPolicyCard(policy) {
  const isEnabled = policy.enabled;
  const windows = policy.windows || [];
  const types = (policy.search?.resource_types || []);
  const nextTs = policy.next_transition_at;
  const intent = policy.last_intent;

  const statusChip = isEnabled
    ? `<span class="ds-status ds-status--running"><span class="ds-status__dot"></span>Enabled</span>`
    : `<span class="ds-status ds-status--sleeping"><span class="ds-status__dot"></span>Disabled</span>`;

  const typeChips = types.map(t => {
    const cls = t.includes("EKS") ? "ds-resource-chip--eks" : t.includes("RDS") ? "ds-resource-chip--rds" : "ds-resource-chip--ec2";
    const short = t === "EKS_CLUSTER" ? "EKS" : t === "RDS_INSTANCE" ? "RDS" : "EC2";
    return `<span class="ds-resource-chip ${cls}">${short}</span>`;
  }).join("");

  const winSummary = windows.length
    ? windows.map(w => `${(w.days||DOW).slice(0,3).join("·")} ${w.start}→${w.end}`).join(" | ")
    : "No windows";

  return `
    <div class="ds-policy-card" data-policy-id="${policy.id}">
      <div class="ds-policy-card__icon" style="${isEnabled ? "background:var(--accent-dim);color:var(--accent);" : ""}">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.6">
          <circle cx="9" cy="9" r="7"/><path d="M9 5v4l2.5 2"/>
        </svg>
      </div>
      <div class="ds-policy-card__body">
        <div style="display:flex;align-items:center;gap:8px;">
          <div class="ds-policy-card__name">${h(policy.name)}</div>
          ${statusChip}
        </div>
        <div class="ds-policy-card__meta" style="display:flex;align-items:center;gap:6px;flex-wrap:wrap;margin-top:5px;">
          ${typeChips}
          <span class="ds-badge">
            <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6">
              <circle cx="6" cy="6" r="4.5"/><path d="M6 3.5V6l2 1.5"/>
            </svg>
            ${h(policy.timezone || "UTC")}
          </span>
          <span class="ds-mono" style="font-size:11px;color:var(--fg-faint);">${h(winSummary)}</span>
          ${nextTs ? `<span class="ds-badge ds-badge--accent">Next: ${h(fmtNextTransition(nextTs))}</span>` : ""}
          ${intent ? `<span class="ds-badge">${h(intent)}</span>` : ""}
        </div>
      </div>
      <div class="ds-policy-card__actions">
        <!-- Toggle enabled -->
        <button class="ds-btn ds-btn--sm ${isEnabled ? "" : "ds-btn--primary"}" data-pol-action="toggle" data-pol-id="${policy.id}" data-pol-enabled="${isEnabled}">
          ${isEnabled ? `<svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M2 6h8"/></svg> Disable` : `<svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 2l7 4-7 4V2z"/></svg> Enable`}
        </button>
        <button class="ds-btn ds-btn--sm" data-pol-action="run-sleep" data-pol-id="${policy.id}" title="Run SLEEP now">
          <svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M10 7.5A5 5 0 0 1 4.5 2 5 5 0 1 0 10 7.5z"/></svg>
          Sleep now
        </button>
        <button class="ds-btn ds-btn--sm" data-pol-action="run-wake" data-pol-id="${policy.id}" title="Run WAKE now">
          <svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 2l7 4-7 4V2z"/></svg>
          Wake now
        </button>
        <button class="ds-btn ds-btn--sm" data-pol-action="edit" data-pol-id="${policy.id}">
          <svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M9 2l1 1-6 6H3V8l6-6z"/></svg>
          Edit
        </button>
        <button class="ds-btn ds-btn--sm ds-btn--danger" data-pol-action="delete" data-pol-id="${policy.id}">
          <svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M1.5 3h9M4 3V1.5h4V3M3 3l.75 7.5h4.5L9 3"/></svg>
        </button>
      </div>
    </div>
  `;
}

// ── Drawer editor ─────────────────────────────────────────────────────────────

function openPolicyDrawer(mode, existingPolicy, accountId, onSaved) {
  const overlay = document.createElement("div");
  overlay.style.cssText = `position:fixed;inset:0;z-index:180;background:rgba(19,19,16,.35);backdrop-filter:blur(3px);animation:fade-in 160ms ease;`;

  const drawer = document.createElement("div");
  drawer.style.cssText = `
    position:fixed;top:0;right:0;bottom:0;width:min(720px,100vw);
    background:var(--bg-surface);border-left:1px solid var(--border);
    box-shadow:var(--shadow-lg);z-index:181;display:flex;flex-direction:column;overflow:hidden;
    animation:drawer-in 220ms cubic-bezier(.2,.8,.4,1);
  `;

  const style = document.createElement("style");
  style.textContent = `@keyframes drawer-in { from { transform:translateX(100%); } to { transform:translateX(0); } }`;
  document.head.appendChild(style);
  document.body.appendChild(overlay);
  document.body.appendChild(drawer);

  // Editor state
  let editorState = {
    name: existingPolicy?.name || "",
    enabled: existingPolicy?.enabled ?? true,
    timezone: existingPolicy?.timezone || "UTC",
    windows: existingPolicy?.windows ? JSON.parse(JSON.stringify(existingPolicy.windows)) : [defaultWindow()],
    criteria: [],
  };

  // Reconstruct criteria from policy search
  if (existingPolicy?.search) {
    const { resource_types = [], regions = [], selector_by_type = {} } = existingPolicy.search;
    const pnbt = existingPolicy.plan_name_by_type || {};
    editorState.criteria = resource_types.map(rt => ({
      resource_type: rt,
      plan_name: pnbt[rt] || "",
      regions: regions || [],
      selector: selector_by_type[rt] || { include_names: [], exclude_names: [], include_labels: {}, exclude_labels: {}, include_namespaces: null, exclude_namespaces: [] },
    }));
  }
  if (!editorState.criteria.length) editorState.criteria = [defaultCriteria()];

  function close() { overlay.remove(); drawer.remove(); style.remove(); }

  function getPlanOptions(resourceType, selected) {
    const cfg = Store.getState().sleepPlans.config?.sleep_plans || {};
    const wantedType = resourceType === "EKS_CLUSTER" ? "EKS_CLUSTER_SLEEP"
                     : resourceType === "RDS_INSTANCE" ? "RDS_SLEEP"
                     : resourceType === "EC2_INSTANCE" ? "EC2_SLEEP" : null;
    const names = Object.entries(cfg).filter(([,p]) => p?.plan_type === wantedType).map(([n])=>n);
    if (!names.length) return `<option value="">(no plans — configure Sleep Plans first)</option>`;
    return [`<option value="">— select plan —</option>`, ...names.map(n => `<option value="${h(n)}" ${n===selected?"selected":""}>${h(n)}</option>`)].join("");
  }

  function renderWindowCard(w, idx) {
    const days = w.days;
    const set = days ? new Set(days) : new Set(DOW);
    return `
      <div style="border:1px solid var(--border);border-radius:var(--r-lg);padding:16px 18px;margin-bottom:10px;background:var(--stone-50);">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;">
          <span style="font-size:12px;font-weight:600;color:var(--fg-muted);">Window ${idx+1}</span>
          <button class="ds-btn ds-btn--sm ds-btn--danger" data-win-rm="${idx}" type="button">
            <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M1 1l10 10M11 1L1 11"/></svg>
          </button>
        </div>
        <!-- Days -->
        <div style="display:flex;gap:4px;flex-wrap:wrap;margin-bottom:14px;">
          ${DOW.map(d => `
            <label style="cursor:pointer;">
              <input type="checkbox" data-win-day="${idx}:${d}" ${set.has(d)?"checked":""} style="display:none;" class="ds-day-check">
              <span class="ds-day-pill ${set.has(d)?"ds-day-pill--active":""}" data-for="${idx}:${d}">${d.slice(0,2)}</span>
            </label>
          `).join("")}
        </div>
        <!-- Times -->
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr 1fr;gap:10px;">
          <div class="ds-field"><label class="ds-label">Sleep at</label>
            <input class="ds-input" type="time" data-win-start="${idx}" value="${h(w.start)}"/>
          </div>
          <div class="ds-field"><label class="ds-label">Wake at</label>
            <input class="ds-input" type="time" data-win-end="${idx}" value="${h(w.end)}"/>
          </div>
          <div class="ds-field"><label class="ds-label">From date</label>
            <input class="ds-input" type="date" data-win-sd="${idx}" value="${h(w.start_date||"")}"/>
          </div>
          <div class="ds-field"><label class="ds-label">To date</label>
            <input class="ds-input" type="date" data-win-ed="${idx}" value="${h(w.end_date||"")}"/>
          </div>
        </div>
      </div>`;
  }

  function renderCriteriaCard(c, idx) {
    return `
      <div style="border:1px solid var(--border);border-radius:var(--r-lg);padding:16px 18px;margin-bottom:10px;background:var(--stone-50);">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;">
          <span style="font-size:12px;font-weight:600;color:var(--fg-muted);">Criteria ${idx+1} — ${h(c.resource_type)}</span>
          <button class="ds-btn ds-btn--sm ds-btn--danger" data-crit-rm="${idx}" type="button">
            <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M1 1l10 10M11 1L1 11"/></svg>
          </button>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;margin-bottom:12px;">
          <div class="ds-field">
            <label class="ds-label">Resource type</label>
            <select class="ds-select" data-crit-type="${idx}">
              <option value="EKS_CLUSTER" ${c.resource_type==="EKS_CLUSTER"?"selected":""}>EKS Cluster</option>
              <option value="RDS_INSTANCE" ${c.resource_type==="RDS_INSTANCE"?"selected":""}>RDS Instance</option>
              <option value="EC2_INSTANCE" ${c.resource_type==="EC2_INSTANCE"?"selected":""}>EC2 Instance</option>
            </select>
          </div>
          <div class="ds-field">
            <label class="ds-label">Sleep plan</label>
            <select class="ds-select" data-crit-plan="${idx}">${getPlanOptions(c.resource_type, c.plan_name)}</select>
          </div>
          <div class="ds-field">
            <label class="ds-label">Regions</label>
            <input class="ds-input" data-crit-regions="${idx}" value="${h(listToCsv(c.regions))}" placeholder="eu-west-1, us-east-1"/>
          </div>
        </div>
        <!-- Selector — collapsible section -->
        <details style="margin-top:4px;">
          <summary style="font-size:11.5px;font-weight:600;color:var(--fg-muted);cursor:pointer;user-select:none;letter-spacing:.01em;">
            Resource selector (include/exclude filters)
          </summary>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:12px;">
            <div class="ds-field">
              <label class="ds-label">Include names</label>
              <input class="ds-input" data-crit-include-names="${idx}" value="${h(listToCsv(c.selector.include_names))}" placeholder="name1, name2"/>
            </div>
            <div class="ds-field">
              <label class="ds-label">Exclude names</label>
              <input class="ds-input" data-crit-exclude-names="${idx}" value="${h(listToCsv(c.selector.exclude_names))}" placeholder="name1"/>
            </div>
            <div class="ds-field">
              <label class="ds-label">Include labels</label>
              <input class="ds-input" data-crit-include-labels="${idx}" value="${h(dictToKvCsv(c.selector.include_labels))}" placeholder="env=dev"/>
            </div>
            <div class="ds-field">
              <label class="ds-label">Exclude labels</label>
              <input class="ds-input" data-crit-exclude-labels="${idx}" value="${h(dictToKvCsv(c.selector.exclude_labels))}" placeholder="env=prod"/>
            </div>
            <div class="ds-field">
              <label class="ds-label">Include namespaces</label>
              <input class="ds-input" data-crit-include-ns="${idx}" value="${h(listToCsv(c.selector.include_namespaces))}" placeholder="default"/>
            </div>
            <div class="ds-field">
              <label class="ds-label">Exclude namespaces</label>
              <input class="ds-input" data-crit-exclude-ns="${idx}" value="${h(listToCsv(c.selector.exclude_namespaces))}" placeholder="kube-system"/>
            </div>
          </div>
        </details>
      </div>`;
  }

  function renderDrawer() {
    drawer.innerHTML = `
      <style>
        .ds-day-pill { display:inline-block;padding:4px 8px;border-radius:var(--r-pill);border:1px solid var(--border);font-size:11px;font-weight:600;color:var(--fg-muted);cursor:pointer;transition:all var(--t-fast);user-select:none; }
        .ds-day-pill--active { background:var(--accent);border-color:var(--accent);color:#fff; }
      </style>
      <!-- Header -->
      <div style="display:flex;align-items:center;justify-content:space-between;padding:20px 24px;border-bottom:1px solid var(--border);flex-shrink:0;">
        <div>
          <div style="font-family:var(--font-display);font-size:16px;font-weight:700;color:var(--fg-strong);letter-spacing:-.02em;">
            ${mode === "edit" ? `Edit — ${h(editorState.name)}` : "New Time Policy"}
          </div>
          <div style="font-size:12px;color:var(--fg-faint);margin-top:2px;">Automate resource sleep schedules</div>
        </div>
        <button class="ds-btn ds-btn--ghost ds-btn--icon" id="ds-pol-drawer-close" aria-label="Close">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 1l12 12M13 1L1 13"/></svg>
        </button>
      </div>

      <!-- Body -->
      <div style="flex:1;overflow-y:auto;padding:24px;display:flex;flex-direction:column;gap:24px;">

        <!-- General -->
        <div>
          <div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--fg-faint);margin-bottom:12px;">General</div>
          <div style="display:grid;grid-template-columns:1fr 1fr auto;gap:12px;align-items:end;">
            <div class="ds-field">
              <label class="ds-label">Policy name</label>
              <input class="ds-input" id="ds-pol-name" value="${h(editorState.name)}" placeholder="Dev nights off"/>
            </div>
            <div class="ds-field">
              <label class="ds-label">Timezone</label>
              <select class="ds-select" id="ds-pol-timezone">${timezoneOptions(editorState.timezone)}</select>
            </div>
            <label style="display:flex;align-items:center;gap:8px;padding-bottom:4px;cursor:pointer;">
              <label class="ds-toggle"><input type="checkbox" id="ds-pol-enabled" ${editorState.enabled?"checked":""}><span class="ds-toggle__track"></span></label>
              <span class="ds-label" style="margin:0;">Enabled</span>
            </label>
          </div>
        </div>

        <!-- Time Windows -->
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;">
            <div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--fg-faint);">Sleep windows</div>
            <button class="ds-btn ds-btn--sm" id="ds-win-add">
              <svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 1v10M1 6h10"/></svg>
              Add window
            </button>
          </div>
          <div id="ds-pol-windows">
            ${editorState.windows.map((w, i) => renderWindowCard(w, i)).join("")}
          </div>
        </div>

        <!-- Criteria -->
        <div>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;">
            <div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--fg-faint);">Resource criteria</div>
            <button class="ds-btn ds-btn--sm" id="ds-crit-add">
              <svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 1v10M1 6h10"/></svg>
              Add criteria
            </button>
          </div>
          <div id="ds-pol-criteria">
            ${editorState.criteria.map((c, i) => renderCriteriaCard(c, i)).join("")}
          </div>
        </div>

      </div>

      <!-- Footer -->
      <div style="display:flex;justify-content:flex-end;gap:8px;padding:16px 24px;border-top:1px solid var(--border);background:var(--stone-50);flex-shrink:0;">
        <button class="ds-btn ds-btn--ghost" id="ds-pol-drawer-cancel">Cancel</button>
        <button class="ds-btn ds-btn--primary" id="ds-pol-drawer-save">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M2 7l4 4 6-7"/></svg>
          ${mode === "edit" ? "Save changes" : "Create policy"}
        </button>
      </div>
    `;

    bindDrawer();
  }

  function bindDrawer() {
    qs("#ds-pol-drawer-close")?.addEventListener("click", close);
    qs("#ds-pol-drawer-cancel")?.addEventListener("click", close);
    overlay.addEventListener("click", e => { if (e.target === overlay) close(); });

    // General
    qs("#ds-pol-name")?.addEventListener("input", e => { editorState.name = e.target.value.trim(); });
    qs("#ds-pol-timezone")?.addEventListener("change", e => { editorState.timezone = e.target.value; });
    qs("#ds-pol-enabled")?.addEventListener("change", e => { editorState.enabled = e.target.checked; });

    // Windows — add
    qs("#ds-win-add")?.addEventListener("click", () => {
      editorState.windows.push(defaultWindow());
      renderDrawer();
    });

    // Windows — remove
    qsa("[data-win-rm]", drawer).forEach(btn => {
      btn.addEventListener("click", () => {
        editorState.windows.splice(Number(btn.dataset.winRm), 1);
        renderDrawer();
      });
    });

    // Windows — days (visual toggle)
    qsa(".ds-day-check", drawer).forEach(cb => {
      cb.addEventListener("change", () => {
        const [idxS, day] = cb.dataset.winDay.split(":");
        const idx = Number(idxS);
        const set = new Set(editorState.windows[idx].days || DOW);
        if (cb.checked) set.add(day); else set.delete(day);
        editorState.windows[idx].days = Array.from(set);
        // Update pill style without full re-render
        const pill = qs(`[data-for="${idxS}:${day}"]`, drawer);
        if (pill) pill.classList.toggle("ds-day-pill--active", cb.checked);
      });
    });

    // Day pills — click forwarding
    qsa(".ds-day-pill", drawer).forEach(pill => {
      pill.addEventListener("click", () => {
        const check = qs(`input[data-win-day="${pill.dataset.for}"]`, drawer);
        if (check) { check.checked = !check.checked; check.dispatchEvent(new Event("change")); }
      });
    });

    // Windows — times / dates
    const winBindings = [
      ["data-win-start", "start"],
      ["data-win-end",   "end"],
      ["data-win-sd",    "start_date"],
      ["data-win-ed",    "end_date"],
    ];
    winBindings.forEach(([attr, field]) => {
      qsa(`[${attr}]`, drawer).forEach(inp => {
        inp.addEventListener("input", () => {
          editorState.windows[Number(inp.getAttribute(attr))][field] = inp.value || null;
        });
      });
    });

    // Criteria — add
    qs("#ds-crit-add")?.addEventListener("click", () => {
      editorState.criteria.push(defaultCriteria());
      renderDrawer();
    });

    // Criteria — remove
    qsa("[data-crit-rm]", drawer).forEach(btn => {
      btn.addEventListener("click", () => {
        editorState.criteria.splice(Number(btn.dataset.critRm), 1);
        renderDrawer();
      });
    });

    // Criteria — type change (needs re-render for plan options)
    qsa("[data-crit-type]", drawer).forEach(sel => {
      sel.addEventListener("change", () => {
        const idx = Number(sel.dataset.critType);
        editorState.criteria[idx].resource_type = sel.value;
        editorState.criteria[idx].plan_name = "";
        renderDrawer();
      });
    });

    // Criteria — other fields
    const critBindings = [
      ["data-crit-plan",          "plan_name",                  v => v],
      ["data-crit-regions",       "regions",                    csvToList],
      ["data-crit-include-names", "selector.include_names",     csvToList],
      ["data-crit-exclude-names", "selector.exclude_names",     csvToList],
      ["data-crit-include-labels","selector.include_labels",    kvCsvToDict],
      ["data-crit-exclude-labels","selector.exclude_labels",    kvCsvToDict],
      ["data-crit-include-ns",    "selector.include_namespaces",csvToList],
      ["data-crit-exclude-ns",    "selector.exclude_namespaces",csvToList],
    ];
    critBindings.forEach(([attr, path, parser]) => {
      qsa(`[${attr}]`, drawer).forEach(inp => {
        inp.addEventListener("input", () => {
          const idx = Number(inp.getAttribute(attr));
          const val = parser(inp.value);
          if (path.includes(".")) {
            const [a, b] = path.split(".");
            editorState.criteria[idx][a][b] = val;
          } else {
            editorState.criteria[idx][path] = val;
          }
        });
      });
    });

    // Save
    qs("#ds-pol-drawer-save")?.addEventListener("click", async () => {
      try {
        const payload = buildPolicyPayload(editorState);
        if (mode === "edit") {
          await Api.updatePolicy(accountId, existingPolicy.id, payload);
          toast("Time Policies", "Policy updated.");
        } else {
          await Api.createPolicy(accountId, payload);
          toast("Time Policies", "Policy created.");
        }
        close();
        onSaved?.();
      } catch (e) {
        toast("Time Policies", e.message || "Save failed.");
      }
    });
  }

  renderDrawer();
}

// ── Page ──────────────────────────────────────────────────────────────────────

export async function TimePoliciesPage() {
  const page = qs("#ds-page");
  if (!page) return;
  if (!requireAuthAndAccount()) return;

  const accountId = Store.getState().account.id;

  page.innerHTML = `
    <div class="ds-page-header">
      <div>
        <div class="ds-page-title">Time Policies</div>
        <div class="ds-page-sub">Automate sleep and wake schedules for your registered resources.</div>
      </div>
      <div class="ds-page-header__actions">
        <div id="ds-pol-loading" style="display:none;align-items:center;gap:8px;">
          <div class="ds-spinner"></div>
          <span class="ds-mono" style="font-size:12px;color:var(--accent);">Loading…</span>
        </div>
        <button class="ds-btn ds-btn--primary" id="ds-pol-create">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2"><path d="M7 2v10M2 7h10"/></svg>
          New Policy
        </button>
      </div>
    </div>

    <!-- Stats -->
    <div class="ds-stat-grid" id="ds-pol-stats" style="grid-template-columns:repeat(3,1fr);margin-bottom:20px;"></div>

    <!-- List -->
    <div id="ds-pol-container">
      <div class="ds-empty"><div class="ds-spinner"></div></div>
    </div>
  `;

  const container = qs("#ds-pol-container");
  const loadingEl = qs("#ds-pol-loading");
  const statsEl   = qs("#ds-pol-stats");
  const btnCreate = qs("#ds-pol-create");

  function renderStats(policies) {
    const total   = policies.length;
    const enabled = policies.filter(p => p.enabled).length;
    statsEl.innerHTML = `
      <div class="ds-stat">
        <div class="ds-stat__label">Total policies</div>
        <div class="ds-stat__value">${total}</div>
      </div>
      <div class="ds-stat ds-stat--success">
        <div class="ds-stat__label">Enabled</div>
        <div class="ds-stat__value">${enabled}</div>
      </div>
      <div class="ds-stat">
        <div class="ds-stat__label">Disabled</div>
        <div class="ds-stat__value">${total - enabled}</div>
      </div>
    `;
  }

  async function loadAndRender() {
    loadingEl.style.display = "flex";
    try {
      // Load sleep plans in parallel (needed for plan picker in drawer)
      const [policiesResp, cfg] = await Promise.all([
        Api.listPolicies(accountId),
        Api.getAccountConfig(accountId).catch(() => ({ sleep_plans: {} })),
      ]);

      Store.setState({ sleepPlans: { config: cfg } });

      const policies = policiesResp?.policies || [];
      Store.setState({ policies: { list: policies } });

      renderStats(policies);

      if (!policies.length) {
        container.innerHTML = `
          <div class="ds-empty" style="margin-top:60px;">
            <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <circle cx="12" cy="12" r="8"/><path d="M12 6v6l3 2"/>
            </svg>
            <div class="ds-empty__title">No time policies yet</div>
            <div class="ds-empty__sub">Create your first policy to automate resource sleep schedules.</div>
            <button class="ds-btn ds-btn--primary" id="ds-pol-create-empty" style="margin-top:16px;">
              <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2"><path d="M7 2v10M2 7h10"/></svg>
              Create first policy
            </button>
          </div>`;
        qs("#ds-pol-create-empty")?.addEventListener("click", () =>
          openPolicyDrawer("new", null, accountId, loadAndRender)
        );
        return;
      }

      container.innerHTML = `<div style="display:grid;gap:8px;">${policies.map(p => renderPolicyCard(p)).join("")}</div>`;
      bindListActions(policies);

    } catch (e) {
      container.innerHTML = `<div class="ds-empty"><div class="ds-empty__title">Failed to load</div><div class="ds-empty__sub">${h(e.message)}</div></div>`;
      toast("Time Policies", e.message || "Load failed.");
    } finally {
      loadingEl.style.display = "none";
    }
  }

  function bindListActions(policies) {
    const byId = Object.fromEntries(policies.map(p => [p.id, p]));

    qsa("[data-pol-action='edit']", container).forEach(btn => {
      btn.addEventListener("click", () => {
        const pol = byId[Number(btn.dataset.polId)];
        if (pol) openPolicyDrawer("edit", pol, accountId, loadAndRender);
      });
    });

    qsa("[data-pol-action='toggle']", container).forEach(btn => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polId);
        const isEnabled = btn.dataset.polEnabled === "true";
        try {
          if (isEnabled) await Api.disablePolicy(accountId, id);
          else await Api.enablePolicy(accountId, id);
          toast("Time Policies", isEnabled ? "Policy disabled." : "Policy enabled.");
          await loadAndRender();
        } catch (e) { toast("Time Policies", e.message || "Toggle failed."); }
      });
    });

    qsa("[data-pol-action='run-sleep']", container).forEach(btn => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polId);
        const pol = byId[id];
        const ok = await confirmModal({
          title: `Run SLEEP now — ${pol?.name}`,
          body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">This will immediately execute a sleep pass for this policy, regardless of schedule.</p>`,
          confirmText: "Run Sleep",
        });
        if (!ok) return;
        try {
          await Api.runPolicyNow(accountId, id, "SLEEP");
          toast("Time Policies", "Sleep triggered.");
        } catch (e) { toast("Time Policies", e.message || "Failed."); }
      });
    });

    qsa("[data-pol-action='run-wake']", container).forEach(btn => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polId);
        const pol = byId[id];
        const ok = await confirmModal({
          title: `Run WAKE now — ${pol?.name}`,
          body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">This will immediately execute a wake pass for this policy.</p>`,
          confirmText: "Run Wake",
        });
        if (!ok) return;
        try {
          await Api.runPolicyNow(accountId, id, "WAKE");
          toast("Time Policies", "Wake triggered.");
        } catch (e) { toast("Time Policies", e.message || "Failed."); }
      });
    });

    qsa("[data-pol-action='delete']", container).forEach(btn => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polId);
        const pol = byId[id];
        const ok = await confirmModal({
          title: `Delete "${pol?.name}"?`,
          body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">This policy and its execution history will be permanently removed.</p>`,
          confirmText: "Delete",
          danger: true,
        });
        if (!ok) return;
        try {
          await Api.deletePolicy(accountId, id);
          toast("Time Policies", "Deleted.");
          await loadAndRender();
        } catch (e) { toast("Time Policies", e.message || "Delete failed."); }
      });
    });
  }

  btnCreate.addEventListener("click", () =>
    openPolicyDrawer("new", null, accountId, loadAndRender)
  );

  await loadAndRender();
}
