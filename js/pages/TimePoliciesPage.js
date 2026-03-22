import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";

const DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
const TYPES = ["EKS_CLUSTER", "RDS_INSTANCE"];

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

function defaultWindow() {
  return { days: ["MON", "TUE", "WED", "THU", "FRI"], start: "21:00", end: "07:00", start_date: null, end_date: null };
}

function normalizeWindows(list) {
  const wins = Array.isArray(list) ? list : [];
  return wins.map((w) => ({
    days: w.days ?? null,
    start: w.start || "21:00",
    end: w.end || "07:00",
    start_date: w.start_date || null,
    end_date: w.end_date || null,
  }));
}

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function kvCsvToDict(v) {
  const out = {};
  const parts = csvToList(v);
  for (const p of parts) {
    const i = p.indexOf("=");
    if (i <= 0) continue;
    const k = p.slice(0, i).trim();
    const val = p.slice(i + 1).trim();
    if (k) out[k] = val;
  }
  return out;
}

function dictToKvCsv(d) {
  if (!d || typeof d !== "object") return "";
  return Object.entries(d).map(([k, v]) => `${k}=${v}`).join(", ");
}

function renderDayChecks(win, idx) {
  const days = win.days;
  const set = days ? new Set(days) : null;

  return DOW.map((d) => {
    const checked = set ? set.has(d) : true;
    return `
      <label class="ds-badge" style="gap:10px;">
        <input type="checkbox" data-win="${idx}" data-day="${d}" ${checked ? "checked" : ""} />
        <span>${d}</span>
      </label>
    `;
  }).join("");
}

function renderWindowsEditor(windows) {
  if (!windows.length) {
    return `<div class="ds-mono-muted" style="padding:10px;">No windows. Add one.</div>`;
  }

  return windows.map((w, idx) => {
    const daysLabel = w.days ? w.days.join(",") : "ALL";
    return `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head">
          <div>
            <div class="ds-panel__title">Window #${idx + 1}</div>
            <div class="ds-panel__sub">Days: ${h(daysLabel)} • ${h(w.start)} → ${h(w.end)}</div>
          </div>
          <div class="ds-row">
            <button class="ds-btn ds-btn--danger" type="button" data-win-remove="${idx}">Remove</button>
          </div>
        </div>

        <div class="ds-row" style="margin-bottom:10px;flex-wrap:wrap;">
          ${renderDayChecks(w, idx)}
          <button class="ds-btn ds-btn--ghost" type="button" data-win-all="${idx}">All</button>
          <button class="ds-btn ds-btn--ghost" type="button" data-win-weekdays="${idx}">Weekdays</button>
          <button class="ds-btn ds-btn--ghost" type="button" data-win-weekend="${idx}">Weekend</button>
        </div>

        <div class="ds-row">
          <div class="ds-field" style="min-width:140px;">
            <div class="ds-label">Start (HH:MM)</div>
            <input class="ds-input" data-win-start="${idx}" value="${h(w.start)}" placeholder="21:00" />
          </div>
          <div class="ds-field" style="min-width:140px;">
            <div class="ds-label">End (HH:MM)</div>
            <input class="ds-input" data-win-end="${idx}" value="${h(w.end)}" placeholder="07:00" />
          </div>
          <div class="ds-field" style="min-width:180px;">
            <div class="ds-label">Start date (optional)</div>
            <input class="ds-input" data-win-sd="${idx}" value="${h(w.start_date || "")}" placeholder="YYYY-MM-DD" />
          </div>
          <div class="ds-field" style="min-width:180px;">
            <div class="ds-label">End date (optional)</div>
            <input class="ds-input" data-win-ed="${idx}" value="${h(w.end_date || "")}" placeholder="YYYY-MM-DD" />
          </div>
        </div>
      </div>
    `;
  }).join("");
}

function renderSelectorEditor(type, sel) {
  const s = sel || {};
  return `
    <div class="ds-panel" style="margin:0 0 12px 0;">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Selector: ${h(type)}</div>
          <div class="ds-panel__sub">selector_by_type.${h(type)} (names / labels / namespaces)</div>
        </div>
      </div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Names (CSV)</div>
          <input class="ds-input" id="ds-sel-${type}-include-names" value="${h((s.include_names || []).join(","))}" placeholder="name-1,name-2" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Names (CSV)</div>
          <input class="ds-input" id="ds-sel-${type}-exclude-names" value="${h((s.exclude_names || []).join(","))}" placeholder="name-a,name-b" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Labels (CSV key=value)</div>
          <input class="ds-input" id="ds-sel-${type}-include-labels" value="${h(dictToKvCsv(s.include_labels))}" placeholder="env=dev,team=core" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Labels (CSV key=value)</div>
          <input class="ds-input" id="ds-sel-${type}-exclude-labels" value="${h(dictToKvCsv(s.exclude_labels))}" placeholder="tier=prod" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Namespaces (CSV)</div>
          <input class="ds-input" id="ds-sel-${type}-include-ns" value="${h((s.include_namespaces || []).join(","))}" placeholder="ns-a,ns-b" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Namespaces (CSV)</div>
          <input class="ds-input" id="ds-sel-${type}-exclude-ns" value="${h((s.exclude_namespaces || []).join(","))}" placeholder="kube-system,kube-public" />
        </div>
      </div>
    </div>
  `;
}

function readSelectorFromDom(type) {
  const include_names = csvToList(qs(`#ds-sel-${type}-include-names`)?.value);
  const exclude_names = csvToList(qs(`#ds-sel-${type}-exclude-names`)?.value);

  const include_labels = kvCsvToDict(qs(`#ds-sel-${type}-include-labels`)?.value);
  const exclude_labels = kvCsvToDict(qs(`#ds-sel-${type}-exclude-labels`)?.value);

  const include_namespaces_raw = qs(`#ds-sel-${type}-include-ns`)?.value;
  const include_namespaces = String(include_namespaces_raw || "").trim() ? csvToList(include_namespaces_raw) : null;

  const exclude_namespaces = csvToList(qs(`#ds-sel-${type}-exclude-ns`)?.value);

  const out = {
    include_names: include_names.length ? include_names : null,
    exclude_names,
    include_labels,
    exclude_labels,
    include_namespaces,
    exclude_namespaces,
  };

  const hasAny =
    (out.include_names && out.include_names.length) ||
    out.exclude_names.length ||
    Object.keys(out.include_labels).length ||
    Object.keys(out.exclude_labels).length ||
    (out.include_namespaces && out.include_namespaces.length) ||
    out.exclude_namespaces.length;

  return hasAny ? out : null;
}

function readEditorState() {
  const name = (qs("#ds-pol-name")?.value || "").trim();
  if (!name) throw new Error("Policy name required.");

  const enabled = !!qs("#ds-pol-enabled")?.checked;
  const timezone = (qs("#ds-pol-timezone")?.value || "UTC").trim() || "UTC";

  const regionsCsv = (qs("#ds-pol-regions")?.value || "").trim();
  const regions = regionsCsv ? regionsCsv.split(",").map((x) => x.trim()).filter(Boolean) : null;

  const resource_types = [];
  if (qs("#ds-pol-type-eks")?.checked) resource_types.push("EKS_CLUSTER");
  if (qs("#ds-pol-type-rds")?.checked) resource_types.push("RDS_INSTANCE");
  if (!resource_types.length) throw new Error("Select at least one resource type.");

  const planEks = (qs("#ds-pol-plan-eks")?.value || "").trim();
  const planRds = (qs("#ds-pol-plan-rds")?.value || "").trim();
  const plan_name_by_type = {};
  if (resource_types.includes("EKS_CLUSTER")) {
    if (!planEks) throw new Error("Missing plan for EKS_CLUSTER.");
    plan_name_by_type["EKS_CLUSTER"] = planEks;
  }
  if (resource_types.includes("RDS_INSTANCE")) {
    if (!planRds) throw new Error("Missing plan for RDS_INSTANCE.");
    plan_name_by_type["RDS_INSTANCE"] = planRds;
  }

  const windows = Store.getState().policies.editorWindows || [];
  if (!windows.length) throw new Error("Add at least one window.");

  const normalizedWindows = windows.map((w) => ({
    days: (w.days && w.days.length === 7) ? null : (w.days && w.days.length ? w.days : null),
    start: w.start,
    end: w.end,
    start_date: w.start_date || null,
    end_date: w.end_date || null,
  }));

  const selector_by_type = {};
  for (const t of resource_types) {
    const sel = readSelectorFromDom(t);
    if (sel) selector_by_type[t] = sel;
  }

  return {
    name,
    enabled,
    timezone,
    search: {
      resource_types,
      regions,
      only_registered: true,
      selector_by_type,
    },
    windows: normalizedWindows,
    plan_name_by_type,
  };
}

async function ensureSleepPlansLoaded() {
  const s = Store.getState();
  if (!s.sleepPlans?.config?.sleep_plans) {
    const cfg = await Api.getAccountConfig(s.account.id);
    const names = Object.keys(cfg.sleep_plans || {}).sort();
    Store.setState({ sleepPlans: { config: cfg, names } });
  }
}

function renderPlansOptions(names) {
  if (!names.length) return `<option value="">(no plans)</option>`;
  return names.map((n) => `<option value="${h(n)}">${h(n)}</option>`).join("");
}

function renderPoliciesList(list) {
  return (list || []).map((p) => {
    const next = p.next_transition_at ? fmtTime(p.next_transition_at) : "—";
    return `
      <tr>
        <td>${p.id}</td>
        <td>${h(p.name)}</td>
        <td>${p.enabled ? `<span class="ds-badge ds-badge--reg">true</span>` : `<span class="ds-badge">false</span>`}</td>
        <td>${h(p.timezone || "UTC")}</td>
        <td class="ds-mono-muted">${h(next)}</td>
        <td>
          <div class="ds-row">
            <button class="ds-btn ds-btn--ghost" type="button" data-pol="select" data-id="${p.id}">Select</button>
          </div>
        </td>
      </tr>
    `;
  }).join("");
}

export async function TimePoliciesPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Time Policies";

  page.innerHTML = renderPanel({
    title: "Time Policies",
    sub: "Define, edit and delete Time Sleep Policies with a structured UI.",
    actionsHtml: `
      <button class="ds-btn" id="ds-pol-refresh" type="button">Refresh</button>
      <button class="ds-btn ds-btn--wake" id="ds-pol-new" type="button">New Policy</button>
    `,
    bodyHtml: `
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
        <div>
          <div class="ds-mono-muted" id="ds-pol-status">—</div>
          <div style="height:10px"></div>
          <div class="ds-tablewrap">
            <table class="ds-table" aria-label="Policies list">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>Enabled</th>
                  <th>Timezone</th>
                  <th>Next</th>
                  <th style="width:180px;">Actions</th>
                </tr>
              </thead>
              <tbody id="ds-pol-tbody"></tbody>
            </table>
          </div>
        </div>

        <div>
          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">Policy Editor</div>
                <div class="ds-panel__sub">UI editor (no JSON). Registered-only strict semantics.</div>
              </div>
            </div>

            <div class="ds-row" style="margin-bottom:12px;">
              <div class="ds-field" style="min-width:unset;flex:1;">
                <div class="ds-label">Selected policy ID</div>
                <input class="ds-input" id="ds-pol-selected-id" value="" placeholder="(none)" />
              </div>
              <label class="ds-badge" style="gap:10px;">
                <input type="checkbox" id="ds-pol-enabled" checked />
                <span>Enabled</span>
              </label>
            </div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Policy name</div>
              <input class="ds-input" id="ds-pol-name" placeholder="ex: Dev nights off" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Timezone</div>
              <input class="ds-input" id="ds-pol-timezone" value="UTC" placeholder="UTC / Asia/Jerusalem / Europe/Paris" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-panel" style="margin:0;">
              <div class="ds-panel__head">
                <div>
                  <div class="ds-panel__title">Search</div>
                  <div class="ds-panel__sub">resource_types + optional regions + selector_by_type</div>
                </div>
              </div>

              <div class="ds-row" style="margin-bottom:10px;">
                <label class="ds-badge" style="gap:10px;">
                  <input type="checkbox" id="ds-pol-type-eks" checked />
                  <span>EKS_CLUSTER</span>
                </label>
                <label class="ds-badge" style="gap:10px;">
                  <input type="checkbox" id="ds-pol-type-rds" checked />
                  <span>RDS_INSTANCE</span>
                </label>
              </div>

              <div class="ds-field" style="min-width:unset;">
                <div class="ds-label">Regions (CSV, optional)</div>
                <input class="ds-input" id="ds-pol-regions" placeholder="eu-west-1,eu-central-1,us-east-1" />
              </div>

              <div style="height:10px"></div>

              <div class="ds-row">
                <div class="ds-field" style="min-width:unset;flex:1;">
                  <div class="ds-label">Plan for EKS_CLUSTER</div>
                  <select class="ds-select" id="ds-pol-plan-eks"></select>
                </div>
                <div class="ds-field" style="min-width:unset;flex:1;">
                  <div class="ds-label">Plan for RDS_INSTANCE</div>
                  <select class="ds-select" id="ds-pol-plan-rds"></select>
                </div>
              </div>

              <div style="height:12px"></div>

              <div id="ds-selector-container"></div>
            </div>

            <div style="height:12px"></div>

            <div class="ds-panel" style="margin:0;">
              <div class="ds-panel__head">
                <div>
                  <div class="ds-panel__title">Windows</div>
                  <div class="ds-panel__sub">Weekly windows with optional date range</div>
                </div>
                <div class="ds-row">
                  <button class="ds-btn ds-btn--wake" id="ds-win-add" type="button">Add Window</button>
                </div>
              </div>

              <div id="ds-win-container"></div>
            </div>

            <div style="height:12px"></div>

            <div class="ds-row">
              <button class="ds-btn" id="ds-pol-create" type="button">Create</button>
              <button class="ds-btn" id="ds-pol-update" type="button">Update</button>
              <button class="ds-btn ds-btn--danger" id="ds-pol-delete" type="button">Delete</button>
              <span style="flex:1"></span>
              <button class="ds-btn ds-btn--sleep" id="ds-pol-run-sleep" type="button">Run Now: SLEEP</button>
              <button class="ds-btn ds-btn--wake" id="ds-pol-run-wake" type="button">Run Now: WAKE</button>
            </div>
          </div>
        </div>
      </div>
    `,
  });

  const status = qs("#ds-pol-status");
  const tbody = qs("#ds-pol-tbody");

  const btnRefresh = qs("#ds-pol-refresh");
  const btnNew = qs("#ds-pol-new");

  const inpSel = qs("#ds-pol-selected-id");
  const inpName = qs("#ds-pol-name");
  const chkEnabled = qs("#ds-pol-enabled");
  const inpTz = qs("#ds-pol-timezone");
  const chkEks = qs("#ds-pol-type-eks");
  const chkRds = qs("#ds-pol-type-rds");
  const inpRegions = qs("#ds-pol-regions");

  const selPlanEks = qs("#ds-pol-plan-eks");
  const selPlanRds = qs("#ds-pol-plan-rds");

  const selectorContainer = qs("#ds-selector-container");

  const winContainer = qs("#ds-win-container");
  const btnWinAdd = qs("#ds-win-add");

  const btnCreate = qs("#ds-pol-create");
  const btnUpdate = qs("#ds-pol-update");
  const btnDelete = qs("#ds-pol-delete");
  const btnRunSleep = qs("#ds-pol-run-sleep");
  const btnRunWake = qs("#ds-pol-run-wake");

  if (!requireAuthAndAccount()) {
    status.textContent = "Not ready (missing auth/account).";
    return;
  }

  await ensureSleepPlansLoaded();
  const planNames = Store.getState().sleepPlans.names || [];
  selPlanEks.innerHTML = renderPlansOptions(planNames);
  selPlanRds.innerHTML = renderPlansOptions(planNames);

  if (planNames.length) {
    selPlanEks.value = planNames[0];
    selPlanRds.value = planNames[0];
  }

  Store.setState({
    policies: {
      ...Store.getState().policies,
      editorWindows: [defaultWindow()],
      editorSelectors: { EKS_CLUSTER: {}, RDS_INSTANCE: {} }
    }
  });

  function renderSelectorsFromStore() {
    const selState = Store.getState().policies.editorSelectors || {};
    selectorContainer.innerHTML = `
      ${renderSelectorEditor("EKS_CLUSTER", selState.EKS_CLUSTER)}
      ${renderSelectorEditor("RDS_INSTANCE", selState.RDS_INSTANCE)}
    `;
  }

  function syncSelectorsFromDomToStore() {
    const cur = Store.getState().policies.editorSelectors || {};
    const next = { ...cur };
    for (const t of TYPES) {
      next[t] = readSelectorFromDom(t) || {};
    }
    Store.setState({ policies: { ...Store.getState().policies, editorSelectors: next } });
  }

  function bindSelectorInputs() {
    qsa('#ds-selector-container input').forEach((inp) => {
      inp.addEventListener("input", syncSelectorsFromDomToStore);
    });
  }

  function renderWindows() {
    const windows = Store.getState().policies.editorWindows || [];
    winContainer.innerHTML = renderWindowsEditor(windows);

    qsa("[data-win-remove]").forEach((b) => {
      b.addEventListener("click", () => {
        const idx = Number(b.dataset.winRemove);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins.splice(idx, 1);
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
        renderWindows();
      });
    });

    qsa("[data-win-all]").forEach((b) => {
      b.addEventListener("click", () => {
        const idx = Number(b.dataset.winAll);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].days = [...DOW];
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
        renderWindows();
      });
    });

    qsa("[data-win-weekdays]").forEach((b) => {
      b.addEventListener("click", () => {
        const idx = Number(b.dataset.winWeekdays);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].days = ["MON","TUE","WED","THU","FRI"];
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
        renderWindows();
      });
    });

    qsa("[data-win-weekend]").forEach((b) => {
      b.addEventListener("click", () => {
        const idx = Number(b.dataset.winWeekend);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].days = ["SAT","SUN"];
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
        renderWindows();
      });
    });

    qsa('input[type="checkbox"][data-win][data-day]').forEach((cb) => {
      cb.addEventListener("change", () => {
        const idx = Number(cb.dataset.win);
        const day = cb.dataset.day;
        const wins = [...(Store.getState().policies.editorWindows || [])];
        const set = new Set(wins[idx].days || DOW);
        if (cb.checked) set.add(day);
        else set.delete(day);
        wins[idx].days = Array.from(set);
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });

    qsa("[data-win-start]").forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.dataset.winStart);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].start = inp.value.trim();
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });

    qsa("[data-win-end]").forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.dataset.winEnd);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].end = inp.value.trim();
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });

    qsa("[data-win-sd]").forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.dataset.winSd);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].start_date = inp.value.trim() || null;
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });

    qsa("[data-win-ed]").forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.dataset.winEd);
        const wins = [...(Store.getState().policies.editorWindows || [])];
        wins[idx].end_date = inp.value.trim() || null;
        Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
      });
    });
  }

  btnWinAdd.addEventListener("click", () => {
    const wins = [...(Store.getState().policies.editorWindows || [])];
    wins.push(defaultWindow());
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: wins } });
    renderWindows();
  });

  function resetEditor() {
    inpSel.value = "";
    inpName.value = "";
    chkEnabled.checked = true;
    inpTz.value = "UTC";
    chkEks.checked = true;
    chkRds.checked = true;
    inpRegions.value = "";

    Store.setState({
      policies: {
        ...Store.getState().policies,
        editorWindows: [defaultWindow()],
        editorSelectors: { EKS_CLUSTER: {}, RDS_INSTANCE: {} },
      },
    });

    renderSelectorsFromStore();
    bindSelectorInputs();
    renderWindows();
  }

  btnNew.addEventListener("click", resetEditor);

  async function loadList() {
    const s = Store.getState();
    status.textContent = "Loading…";
    try {
      const resp = await Api.listPolicies(s.account.id);
      const list = resp?.policies || [];
      Store.setState({ policies: { ...s.policies, list } });
      tbody.innerHTML = renderPoliciesList(list);
      status.textContent = `OK — ${list.length} policy(s).`;
      bindListActions();
    } catch (e) {
      status.textContent = "Error.";
      toast("Time Policies", e.message || "Load failed");
    }
  }

  function bindListActions() {
    qsa('[data-pol="select"]').forEach((b) => {
      b.addEventListener("click", async () => {
        const id = Number(b.dataset.id);
        const s = Store.getState();
        try {
          const p = await Api.getPolicy(s.account.id, id);

          inpSel.value = String(p.id);
          inpName.value = p.name || "";
          chkEnabled.checked = !!p.enabled;
          inpTz.value = p.timezone || "UTC";

          const types = new Set((p.search?.resource_types || []));
          chkEks.checked = types.has("EKS_CLUSTER");
          chkRds.checked = types.has("RDS_INSTANCE");

          const regions = p.search?.regions || null;
          inpRegions.value = Array.isArray(regions) ? regions.join(",") : "";

          const planByType = p.plan_name_by_type || {};
          if (planByType.EKS_CLUSTER) selPlanEks.value = planByType.EKS_CLUSTER;
          if (planByType.RDS_INSTANCE) selPlanRds.value = planByType.RDS_INSTANCE;

          const windows = normalizeWindows(p.windows || []);
          Store.setState({ policies: { ...Store.getState().policies, editorWindows: windows.length ? windows : [defaultWindow()] } });
          renderWindows();

          const sbt = p.search?.selector_by_type || {};
          Store.setState({
            policies: {
              ...Store.getState().policies,
              editorSelectors: {
                EKS_CLUSTER: sbt.EKS_CLUSTER || {},
                RDS_INSTANCE: sbt.RDS_INSTANCE || {},
              },
            },
          });
          renderSelectorsFromStore();
          bindSelectorInputs();

          toast("Editor", `Loaded policy ${id}.`);
        } catch (e) {
          toast("Time Policies", e.message || "Failed to load policy");
        }
      });
    });
  }

  btnRefresh.addEventListener("click", loadList);

  btnCreate.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const body = readEditorState();
      await Api.createPolicy(s.account.id, body);
      toast("Time Policies", "Created.");
      await loadList();
    } catch (e) {
      toast("Time Policies", e.message || "Create failed");
    }
  });

  btnUpdate.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");
      const body = readEditorState();
      await Api.updatePolicy(s.account.id, id, body);
      toast("Time Policies", "Updated.");
      await loadList();
    } catch (e) {
      toast("Time Policies", e.message || "Update failed");
    }
  });

  btnDelete.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");

      const ok = await confirmModal({
        title: "Delete Policy",
        body: `<div class="ds-mono-muted">Policy <b>${h(String(id))}</b> will be deleted (executions too).</div>`,
        confirmText: "Delete",
        cancelText: "Cancel",
      });
      if (!ok) return;

      await Api.deletePolicy(s.account.id, id);
      toast("Time Policies", "Deleted.");
      resetEditor();
      await loadList();
    } catch (e) {
      toast("Time Policies", e.message || "Delete failed");
    }
  });

  btnRunSleep.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");
      await Api.runPolicyNow(s.account.id, id, "SLEEP");
      toast("Time Policies", "Run-now SLEEP submitted.");
    } catch (e) {
      toast("Time Policies", e.message || "Run-now failed");
    }
  });

  btnRunWake.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const id = Number(inpSel.value || 0);
      if (!id) throw new Error("Missing selected policy ID.");
      await Api.runPolicyNow(s.account.id, id, "WAKE");
      toast("Time Policies", "Run-now WAKE submitted.");
    } catch (e) {
      toast("Time Policies", e.message || "Run-now failed");
    }
  });

  renderSelectorsFromStore();
  bindSelectorInputs();
  renderWindows();
  await loadList();
}
