import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";

const DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];

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

function timezoneOptions(selected = "UTC") {
  const zones = typeof Intl !== "undefined" && Intl.supportedValuesOf
    ? Intl.supportedValuesOf("timeZone")
    : ["UTC", "Asia/Jerusalem", "Asia/Urumqi", "Europe/Paris", "America/New_York"];
  return zones.map((z) => `<option value="${h(z)}" ${z === selected ? "selected" : ""}>${h(z)}</option>`).join("");
}

function defaultWindow() {
  return { days: ["MON", "TUE", "WED", "THU", "FRI"], start: "21:00", end: "07:00", start_date: null, end_date: null };
}

function defaultCriteria() {
  return {
    resource_type: "EKS_CLUSTER",
    plan_name: "",
    regions: [],
    selector: {
      include_names: [],
      exclude_names: [],
      include_labels: {},
      exclude_labels: {},
      include_namespaces: null,
      exclude_namespaces: [],
    },
  };
}

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function listToCsv(v) {
  return Array.isArray(v) ? v.join(",") : "";
}

function kvCsvToDict(v) {
  const out = {};
  csvToList(v).forEach((p) => {
    const i = p.indexOf("=");
    if (i <= 0) return;
    const k = p.slice(0, i).trim();
    const val = p.slice(i + 1).trim();
    if (k) out[k] = val;
  });
  return out;
}

function dictToKvCsv(d) {
  if (!d || typeof d !== "object") return "";
  return Object.entries(d).map(([k, v]) => `${k}=${v}`).join(", ");
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

function renderDayChecks(win, idx) {
  const days = win.days;
  const set = days ? new Set(days) : new Set(DOW);

  return DOW.map((d) => `
    <label class="ds-badge" style="gap:10px;">
      <input type="checkbox" data-win-day="${idx}:${d}" ${set.has(d) ? "checked" : ""} />
      <span>${d}</span>
    </label>
  `).join("");
}

function renderWindowsEditor(windows) {
  if (!windows.length) return `<div class="ds-mono-muted">No windows. Add one.</div>`;

  return windows.map((w, idx) => `
    <div class="ds-panel" style="margin:0 0 12px 0;">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Window #${idx + 1}</div>
          <div class="ds-panel__sub">${h((w.days || DOW).join(","))} • ${h(w.start)} → ${h(w.end)}</div>
        </div>
        <div class="ds-row">
          <button class="ds-btn ds-btn--danger" type="button" data-win-remove="${idx}">Remove</button>
        </div>
      </div>

      <div class="ds-row" style="margin-bottom:10px;flex-wrap:wrap;">
        ${renderDayChecks(w, idx)}
      </div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:180px;">
          <div class="ds-label">Start</div>
          <input class="ds-input" type="time" data-win-start="${idx}" value="${h(w.start)}" />
        </div>
        <div class="ds-field" style="min-width:180px;">
          <div class="ds-label">End</div>
          <input class="ds-input" type="time" data-win-end="${idx}" value="${h(w.end)}" />
        </div>
        <div class="ds-field" style="min-width:180px;">
          <div class="ds-label">Start date</div>
          <input class="ds-input" type="date" data-win-sd="${idx}" value="${h(w.start_date || "")}" />
        </div>
        <div class="ds-field" style="min-width:180px;">
          <div class="ds-label">End date</div>
          <input class="ds-input" type="date" data-win-ed="${idx}" value="${h(w.end_date || "")}" />
        </div>
      </div>
    </div>
  `).join("");
}

function criteriaPlanOptions(resourceType, selected) {
  const cfg = Store.getState().sleepPlans.config?.sleep_plans || {};
  const wantedType = resourceType === "EKS_CLUSTER" ? "EKS_CLUSTER_SLEEP" : "RDS_SLEEP";

  const names = Object.entries(cfg)
    .filter(([, plan]) => plan?.plan_type === wantedType)
    .map(([name]) => name);

  if (!names.length) return `<option value="">(no plan)</option>`;
  return names.map((n) => `<option value="${h(n)}" ${n === selected ? "selected" : ""}>${h(n)}</option>`).join("");
}

function renderCriteriaEditor(criteriaList) {
  if (!criteriaList.length) return `<div class="ds-mono-muted">No search criteria. Add one.</div>`;

  return criteriaList.map((c, idx) => `
    <div class="ds-panel" style="margin:0 0 12px 0;">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Search Criteria #${idx + 1}</div>
          <div class="ds-panel__sub">${h(c.resource_type)}</div>
        </div>
        <div class="ds-row">
          <button class="ds-btn ds-btn--danger" type="button" data-crit-remove="${idx}">Remove</button>
        </div>
      </div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:220px;">
          <div class="ds-label">Resource Type</div>
          <select class="ds-select" data-crit-type="${idx}">
            <option value="EKS_CLUSTER" ${c.resource_type === "EKS_CLUSTER" ? "selected" : ""}>EKS_CLUSTER</option>
            <option value="RDS_INSTANCE" ${c.resource_type === "RDS_INSTANCE" ? "selected" : ""}>RDS_INSTANCE</option>
          </select>
        </div>

        <div class="ds-field" style="min-width:220px;">
          <div class="ds-label">Plan</div>
          <select class="ds-select" data-crit-plan="${idx}">
            ${criteriaPlanOptions(c.resource_type, c.plan_name)}
          </select>
        </div>

        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Regions (CSV)</div>
          <input class="ds-input" data-crit-regions="${idx}" value="${h(listToCsv(c.regions))}" placeholder="eu-west-1,eu-central-1" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Names (CSV)</div>
          <input class="ds-input" data-crit-include-names="${idx}" value="${h(listToCsv(c.selector.include_names))}" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Names (CSV)</div>
          <input class="ds-input" data-crit-exclude-names="${idx}" value="${h(listToCsv(c.selector.exclude_names))}" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Labels (key=value CSV)</div>
          <input class="ds-input" data-crit-include-labels="${idx}" value="${h(dictToKvCsv(c.selector.include_labels))}" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Labels (key=value CSV)</div>
          <input class="ds-input" data-crit-exclude-labels="${idx}" value="${h(dictToKvCsv(c.selector.exclude_labels))}" />
        </div>
      </div>

      <div style="height:10px"></div>

      <div class="ds-row">
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Include Namespaces (CSV)</div>
          <input class="ds-input" data-crit-include-ns="${idx}" value="${h(listToCsv(c.selector.include_namespaces))}" />
        </div>
        <div class="ds-field" style="min-width:unset;flex:1;">
          <div class="ds-label">Exclude Namespaces (CSV)</div>
          <input class="ds-input" data-crit-exclude-ns="${idx}" value="${h(listToCsv(c.selector.exclude_namespaces))}" />
        </div>
      </div>
    </div>
  `).join("");
}

async function ensureSleepPlansLoaded() {
  const s = Store.getState();
  if (!s.sleepPlans?.config?.sleep_plans || !Object.keys(s.sleepPlans.config.sleep_plans).length) {
    const cfg = await Api.getAccountConfig(s.account.id);
    Store.setState({
      sleepPlans: {
        config: cfg,
        names: Object.keys(cfg.sleep_plans || {}).sort(),
      },
    });
  }
}

function buildPolicyPayload() {
  const name = (qs("#ds-pol-name")?.value || "").trim();
  if (!name) throw new Error("Policy name required.");

  const enabled = !!qs("#ds-pol-enabled")?.checked;
  const timezone = (qs("#ds-pol-timezone")?.value || "UTC").trim() || "UTC";

  const windows = (Store.getState().policies.editorWindows || []).map((w) => ({
    days: (w.days && w.days.length === 7) ? null : (w.days && w.days.length ? w.days : null),
    start: w.start,
    end: w.end,
    start_date: w.start_date || null,
    end_date: w.end_date || null,
  }));

  if (!windows.length) throw new Error("Add at least one time window.");

  const criteria = Store.getState().policies.editorCriteria || [];
  if (!criteria.length) throw new Error("Add at least one search criteria block.");

  const resource_types = [];
  const selector_by_type = {};
  const plan_name_by_type = {};
  const mergedRegions = new Set();

  for (const c of criteria) {
    resource_types.push(c.resource_type);
    if (c.plan_name) plan_name_by_type[c.resource_type] = c.plan_name;
    (c.regions || []).forEach((r) => mergedRegions.add(r));

    const sel = {
      include_names: c.selector.include_names?.length ? c.selector.include_names : null,
      exclude_names: c.selector.exclude_names || [],
      include_labels: c.selector.include_labels || {},
      exclude_labels: c.selector.exclude_labels || {},
      include_namespaces: c.selector.include_namespaces?.length ? c.selector.include_namespaces : null,
      exclude_namespaces: c.selector.exclude_namespaces || [],
    };
    selector_by_type[c.resource_type] = sel;
  }

  return {
    name,
    enabled,
    timezone,
    search: {
      resource_types: [...new Set(resource_types)],
      regions: mergedRegions.size ? Array.from(mergedRegions) : null,
      selector_by_type,
      only_registered: true,
    },
    windows,
    plan_name_by_type,
  };
}

function openPolicyModal(mode = "new") {
  const host = qs("#ds-modalhost");
  if (!host) return;

  const state = Store.getState();
  const windows = state.policies.editorWindows || [defaultWindow()];
  const criteria = state.policies.editorCriteria || [defaultCriteria()];

  host.innerHTML = `
    <div class="ds-modalbackdrop" data-role="close"></div>
    <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Policy Editor" style="width:min(1200px, calc(100vw - 32px)); max-height:88vh;">
      <div class="ds-modal__head">
        <div class="ds-modal__title">${mode === "edit" ? "Edit Policy" : "New Policy"}</div>
        <button class="ds-btn ds-btn--ghost" type="button" data-role="close">Close</button>
      </div>
      <div class="ds-modal__body">
        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">General</div>
              <div class="ds-panel__sub">Name and timezone</div>
            </div>
          </div>
          <div class="ds-row">
            <div class="ds-field" style="min-width:unset;flex:1;">
              <div class="ds-label">Policy Name</div>
              <input class="ds-input" id="ds-pol-name" value="${h(qs("#ds-pol-name")?.value || "")}" placeholder="Dev nights off" />
            </div>
            <div class="ds-field" style="min-width:280px;">
              <div class="ds-label">Timezone</div>
              <select class="ds-select" id="ds-pol-timezone">
                ${timezoneOptions(qs("#ds-pol-timezone")?.value || "UTC")}
              </select>
            </div>
            <label class="ds-badge" style="gap:10px;align-self:flex-end;">
              <input type="checkbox" id="ds-pol-enabled" ${qs("#ds-pol-enabled")?.checked !== false ? "checked" : ""} />
              <span>Enabled</span>
            </label>
          </div>
        </div>

        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Search</div>
              <div class="ds-panel__sub">Compartmentalized by resource type; merged into one SearchRequest on save</div>
            </div>
            <div class="ds-row">
              <button class="ds-btn ds-btn--wake" id="ds-crit-add" type="button">Add Search Criteria</button>
            </div>
          </div>
          <div id="ds-criteria-container">${renderCriteriaEditor(criteria)}</div>
        </div>

        <div class="ds-panel" style="margin:0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Windows</div>
              <div class="ds-panel__sub">Modern date/time/day editor</div>
            </div>
            <div class="ds-row">
              <button class="ds-btn ds-btn--wake" id="ds-win-add" type="button">Add Window</button>
            </div>
          </div>
          <div id="ds-win-container">${renderWindowsEditor(windows)}</div>
        </div>
      </div>
      <div class="ds-modal__foot">
        <button class="ds-btn ds-btn--ghost" type="button" data-role="cancel">Cancel</button>
        <button class="ds-btn" type="button" id="ds-pol-modal-save">${mode === "edit" ? "Update" : "Create"}</button>
      </div>
    </div>
  `;
  host.style.pointerEvents = "auto";

  const close = () => {
    host.innerHTML = "";
    host.style.pointerEvents = "none";
  };

  host.addEventListener("click", (e) => {
    const role = e.target?.dataset?.role;
    if (role === "close" || role === "cancel") close();
  });

  function rerenderModal(mode2 = mode) {
    openPolicyModal(mode2);
  }

  qsa("[data-win-remove]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const idx = Number(btn.dataset.winRemove);
      const next = [...(Store.getState().policies.editorWindows || [])];
      next.splice(idx, 1);
      Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
      rerenderModal(mode);
    });
  });

  qsa("[data-win-day]").forEach((cb) => {
    cb.addEventListener("change", () => {
      const [idxStr, day] = cb.dataset.winDay.split(":");
      const idx = Number(idxStr);
      const next = [...(Store.getState().policies.editorWindows || [])];
      const set = new Set(next[idx].days || DOW);
      if (cb.checked) set.add(day); else set.delete(day);
      next[idx].days = Array.from(set);
      Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
    });
  });

  qsa("[data-win-start]").forEach((inp) => inp.addEventListener("input", () => {
    const idx = Number(inp.dataset.winStart);
    const next = [...(Store.getState().policies.editorWindows || [])];
    next[idx].start = inp.value;
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
  }));

  qsa("[data-win-end]").forEach((inp) => inp.addEventListener("input", () => {
    const idx = Number(inp.dataset.winEnd);
    const next = [...(Store.getState().policies.editorWindows || [])];
    next[idx].end = inp.value;
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
  }));

  qsa("[data-win-sd]").forEach((inp) => inp.addEventListener("input", () => {
    const idx = Number(inp.dataset.winSd);
    const next = [...(Store.getState().policies.editorWindows || [])];
    next[idx].start_date = inp.value || null;
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
  }));

  qsa("[data-win-ed]").forEach((inp) => inp.addEventListener("input", () => {
    const idx = Number(inp.dataset.winEd);
    const next = [...(Store.getState().policies.editorWindows || [])];
    next[idx].end_date = inp.value || null;
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
  }));

  qs("#ds-win-add")?.addEventListener("click", () => {
    const next = [...(Store.getState().policies.editorWindows || [])];
    next.push(defaultWindow());
    Store.setState({ policies: { ...Store.getState().policies, editorWindows: next } });
    rerenderModal(mode);
  });

  qsa("[data-crit-remove]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const idx = Number(btn.dataset.critRemove);
      const next = [...(Store.getState().policies.editorCriteria || [])];
      next.splice(idx, 1);
      Store.setState({ policies: { ...Store.getState().policies, editorCriteria: next } });
      rerenderModal(mode);
    });
  });

  qs("#ds-crit-add")?.addEventListener("click", () => {
    const next = [...(Store.getState().policies.editorCriteria || [])];
    next.push(defaultCriteria());
    Store.setState({ policies: { ...Store.getState().policies, editorCriteria: next } });
    rerenderModal(mode);
  });

  qsa("[data-crit-type]").forEach((sel) => {
    sel.addEventListener("change", () => {
      const idx = Number(sel.dataset.critType);
      const next = [...(Store.getState().policies.editorCriteria || [])];
      next[idx].resource_type = sel.value;
      next[idx].plan_name = "";
      Store.setState({ policies: { ...Store.getState().policies, editorCriteria: next } });
      rerenderModal(mode);
    });
  });

  [
    ["data-crit-plan", "plan_name", (v) => v],
    ["data-crit-regions", "regions", csvToList],
    ["data-crit-include-names", "selector.include_names", csvToList],
    ["data-crit-exclude-names", "selector.exclude_names", csvToList],
    ["data-crit-include-labels", "selector.include_labels", kvCsvToDict],
    ["data-crit-exclude-labels", "selector.exclude_labels", kvCsvToDict],
    ["data-crit-include-ns", "selector.include_namespaces", csvToList],
    ["data-crit-exclude-ns", "selector.exclude_namespaces", csvToList],
  ].forEach(([attr, path, parser]) => {
    qsa(`[${attr}]`).forEach((inp) => {
      inp.addEventListener("input", () => {
        const idx = Number(inp.getAttribute(attr));
        const next = [...(Store.getState().policies.editorCriteria || [])];
        const val = parser(inp.value);
        if (path.includes(".")) {
          const [a, b] = path.split(".");
          next[idx][a][b] = val;
        } else {
          next[idx][path] = val;
        }
        Store.setState({ policies: { ...Store.getState().policies, editorCriteria: next } });
      });
    });
  });

  qs("#ds-pol-modal-save")?.addEventListener("click", async () => {
    try {
      const nameInput = qs("#ds-pol-name");
      const tzInput = qs("#ds-pol-timezone");
      const enabledInput = qs("#ds-pol-enabled");

      const shadowName = document.querySelector("#ds-pol-name-shadow");
      if (shadowName) shadowName.value = nameInput.value;

      const basePayload = buildPolicyPayload();
      basePayload.name = nameInput.value.trim();
      basePayload.timezone = tzInput.value;
      basePayload.enabled = enabledInput.checked;

      const accountId = Store.getState().account.id;
      const selectedId = Number(Store.getState().policies.selectedId || 0);

      if (mode === "edit" && selectedId) {
        await Api.updatePolicy(accountId, selectedId, basePayload);
        toast("Time Policies", "Updated.");
      } else {
        await Api.createPolicy(accountId, basePayload);
        toast("Time Policies", "Created.");
      }

      close();
      await TimePoliciesPage();
    } catch (e) {
      toast("Time Policies", e.message || "Save failed");
    }
  });
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
      <input type="hidden" id="ds-pol-name-shadow" value="" />
      <div style="display:grid;grid-template-columns:1fr;">
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
      </div>
    `,
  });

  const status = qs("#ds-pol-status");
  const tbody = qs("#ds-pol-tbody");
  const btnRefresh = qs("#ds-pol-refresh");
  const btnNew = qs("#ds-pol-new");

  if (!requireAuthAndAccount()) {
    status.textContent = "Not ready (missing auth/account).";
    return;
  }

  await ensureSleepPlansLoaded();

  function resetEditorState() {
    Store.setState({
      policies: {
        ...Store.getState().policies,
        selectedId: null,
        editorWindows: [defaultWindow()],
        editorCriteria: [defaultCriteria()],
      },
    });
    const shadow = qs("#ds-pol-name-shadow");
    if (shadow) shadow.value = "";
  }

  async function loadList() {
    try {
      const resp = await Api.listPolicies(Store.getState().account.id);
      const list = resp?.policies || [];
      Store.setState({ policies: { ...Store.getState().policies, list } });

      tbody.innerHTML = list.map((p) => {
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
                <button class="ds-btn ds-btn--ghost" type="button" data-pol-select="${p.id}">Select</button>
                <button class="ds-btn ds-btn--danger" type="button" data-pol-delete="${p.id}">Delete</button>
                <button class="ds-btn ds-btn--sleep" type="button" data-pol-run-sleep="${p.id}">Run SLEEP</button>
                <button class="ds-btn ds-btn--wake" type="button" data-pol-run-wake="${p.id}">Run WAKE</button>
              </div>
            </td>
          </tr>
        `;
      }).join("");

      bindListActions();
      status.textContent = `OK — ${list.length} policy(s).`;
    } catch (e) {
      status.textContent = "Error.";
      toast("Time Policies", e.message || "Load failed");
    }
  }

  function bindListActions() {
    qsa("[data-pol-select]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        try {
          const policyId = Number(btn.dataset.polSelect);
          const accountId = Store.getState().account.id;
          const p = await Api.getPolicy(accountId, policyId);

          const criteria = [];
          const resourceTypes = p.search?.resource_types || [];
          const planByType = p.plan_name_by_type || {};
          const selectorByType = p.search?.selector_by_type || {};
          const mergedRegions = p.search?.regions || [];

          for (const rt of resourceTypes) {
            criteria.push({
              resource_type: rt,
              plan_name: planByType[rt] || "",
              regions: [...mergedRegions],
              selector: {
                include_names: selectorByType[rt]?.include_names || [],
                exclude_names: selectorByType[rt]?.exclude_names || [],
                include_labels: selectorByType[rt]?.include_labels || {},
                exclude_labels: selectorByType[rt]?.exclude_labels || {},
                include_namespaces: selectorByType[rt]?.include_namespaces || [],
                exclude_namespaces: selectorByType[rt]?.exclude_namespaces || [],
              },
            });
          }

          Store.setState({
            policies: {
              ...Store.getState().policies,
              selectedId: policyId,
              editorWindows: normalizeWindows(p.windows || []),
              editorCriteria: criteria.length ? criteria : [defaultCriteria()],
            },
          });

          const shadow = qs("#ds-pol-name-shadow");
          if (shadow) shadow.value = p.name || "";

          openPolicyModal("edit");

          // post-open fill
          setTimeout(() => {
            if (qs("#ds-pol-name")) qs("#ds-pol-name").value = p.name || "";
            if (qs("#ds-pol-timezone")) qs("#ds-pol-timezone").value = p.timezone || "UTC";
            if (qs("#ds-pol-enabled")) qs("#ds-pol-enabled").checked = !!p.enabled;
          }, 0);
        } catch (e) {
          toast("Time Policies", e.message || "Failed to load policy");
        }
      });
    });

    qsa("[data-pol-delete]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polDelete);
        const ok = await confirmModal({
          title: "Delete Policy",
          body: `<div class="ds-mono-muted">Policy <b>${h(String(id))}</b> will be deleted.</div>`,
          confirmText: "Delete",
          cancelText: "Cancel",
        });
        if (!ok) return;

        try {
          await Api.deletePolicy(Store.getState().account.id, id);
          toast("Time Policies", "Deleted.");
          await loadList();
        } catch (e) {
          toast("Time Policies", e.message || "Delete failed");
        }
      });
    });

    qsa("[data-pol-run-sleep]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polRunSleep);
        try {
          await Api.runPolicyNow(Store.getState().account.id, id, "SLEEP");
          toast("Time Policies", "Run-now SLEEP submitted.");
        } catch (e) {
          toast("Time Policies", e.message || "Run-now failed");
        }
      });
    });

    qsa("[data-pol-run-wake]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const id = Number(btn.dataset.polRunWake);
        try {
          await Api.runPolicyNow(Store.getState().account.id, id, "WAKE");
          toast("Time Policies", "Run-now WAKE submitted.");
        } catch (e) {
          toast("Time Policies", e.message || "Run-now failed");
        }
      });
    });
  }

  btnRefresh?.addEventListener("click", loadList);
  btnNew?.addEventListener("click", () => {
    resetEditorState();
    openPolicyModal("new");
  });

  await loadList();
}
