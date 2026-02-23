// app.js (ES6 module, single file, with internal modules: api/router/components + global state)
const API = (() => {
  const defaults = {
    baseUrl: localStorage.getItem("deepsleep.baseUrl") || "", // e.g. http://localhost:8000
  };

  function setBaseUrl(url) {
    defaults.baseUrl = (url || "").replace(/\/+$/, "");
    localStorage.setItem("deepsleep.baseUrl", defaults.baseUrl);
    UI.setApiIndicator(defaults.baseUrl || "—");
  }

  function getBaseUrl() {
    return defaults.baseUrl;
  }

  function authHeaders() {
    const token = State.get().auth?.token;
    return token ? { Authorization: `Bearer ${token}` } : {};
  }

  async function request(path, { method = "GET", query = null, body = null } = {}) {
    const baseUrl = getBaseUrl();
    if (!baseUrl) throw new Error("Missing API base URL. Go to Settings.");

    const url = new URL(baseUrl + path);
    if (query) Object.entries(query).forEach(([k, v]) => url.searchParams.set(k, String(v)));

    const res = await fetch(url.toString(), {
      method,
      headers: {
        "Content-Type": "application/json",
        ...authHeaders(),
      },
      body: body ? JSON.stringify(body) : null,
    });

    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = { raw: text }; }

    if (!res.ok) {
      const msg = (data && (data.detail || data.message)) ? (data.detail || data.message) : `HTTP ${res.status}`;
      throw new Error(msg);
    }
    return data;
  }

  // --- Auth
  const login = (payload) => request("/auth/login", { method: "POST", body: payload });
  const refresh = (payload) => request("/auth/refresh", { method: "POST", body: payload });

  // --- Resources
  const searchResources = (accountId, body) => request(`/accounts/${accountId}/resources/search`, { method: "POST", body });
  const batchRegister = (accountId, body) => request(`/accounts/${accountId}/resources/batch-register`, { method: "POST", body });

  // --- EKS states + orchestration
  const listClusterStates = (accountId) => request(`/accounts/${accountId}/cluster-states`);
  const sleepEKS = (accountId, clusterName, region, planName) =>
    request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/sleep`, {
      method: "POST",
      query: { region, plan_name: planName || "dev" },
    });
  const wakeEKS = (accountId, clusterName, region) =>
    request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/wake`, {
      method: "POST",
      query: { region },
    });

  // --- RDS states + orchestration
  const listRdsStates = (accountId) => request(`/accounts/${accountId}/rds-instance-states`);
  const sleepRDS = (accountId, dbInstanceId, region, planName) =>
    request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/sleep`, {
      method: "POST",
      query: { region, plan_name: planName || "rds_dev" },
    });
  const wakeRDS = (accountId, dbInstanceId, region) =>
    request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/wake`, {
      method: "POST",
      query: { region },
    });

  // --- Time policies
  const listPolicies = (accountId) => request(`/accounts/${accountId}/time-policies`);
  const createPolicy = (accountId, body) => request(`/accounts/${accountId}/time-policies`, { method: "POST", body });
  const updatePolicy = (accountId, policyId, body) => request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "PUT", body });
  const deletePolicy = (accountId, policyId) => request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "DELETE" });
  const runPolicyNow = (accountId, policyId, action) =>
    request(`/accounts/${accountId}/time-policies/${policyId}/run-now`, { method: "POST", body: { action } });

  return {
    setBaseUrl, getBaseUrl,
    login, refresh,
    searchResources, batchRegister,
    listClusterStates, sleepEKS, wakeEKS,
    listRdsStates, sleepRDS, wakeRDS,
    listPolicies, createPolicy, updatePolicy, deletePolicy, runPolicyNow,
    request,
  };
})();

const State = (() => {
  const state = {
    route: { name: "discovery", params: {} },
    ui: { search: "" },
    auth: {
      token: localStorage.getItem("deepsleep.token") || "",
      business_id: localStorage.getItem("deepsleep.business_id") || "",
      email: localStorage.getItem("deepsleep.email") || "",
      roles: (localStorage.getItem("deepsleep.roles") || "").split(",").filter(Boolean),
    },
    account: {
      id: Number(localStorage.getItem("deepsleep.account_id") || 0) || 0,
      aws_account_id: localStorage.getItem("deepsleep.aws_account_id") || "",
      name: localStorage.getItem("deepsleep.account_name") || "—",
    },

    // data caches
    discovery: {
      lastQuery: null,
      resources: [],      // normalized list
      selectedKeys: new Set(),
      onlyRegistered: false,
      regionsCsv: "eu-west-1,eu-central-1,us-east-1",
      resourceTypes: ["EKS_CLUSTER", "RDS_INSTANCE"],
    },

    active: {
      rowsByKey: new Map(), // key => { type, name, region, observed_state, desired_state, locked_until, ... }
      lastPollAt: null,
      plans: { EKS_CLUSTER: "dev", RDS_INSTANCE: "rds_dev" },
    },

    policies: {
      list: [],
      selectedId: null,
      editor: null, // object
      loading: false,
    },
  };

  const listeners = new Set();
  function get() { return state; }

  function set(patch) {
    deepMerge(state, patch);
    listeners.forEach((fn) => fn(state));
  }

  function subscribe(fn) { listeners.add(fn); return () => listeners.delete(fn); }

  function deepMerge(target, patch) {
    for (const [k, v] of Object.entries(patch)) {
      if (v && typeof v === "object" && !Array.isArray(v) && !(v instanceof Set) && !(v instanceof Map)) {
        if (!target[k] || typeof target[k] !== "object") target[k] = {};
        deepMerge(target[k], v);
      } else {
        target[k] = v;
      }
    }
  }

  return { get, set, subscribe };
})();

const UI = (() => {
  const els = {
    page: document.getElementById("page"),
    crumbs: document.getElementById("crumbs"),
    search: document.getElementById("global-search"),
    userchip: document.getElementById("userchip"),
    userchipText: document.getElementById("userchip-text"),
    dropdown: document.getElementById("user-dropdown"),
    ddName: document.getElementById("dd-name"),
    ddAws: document.getElementById("dd-aws"),
    ddBiz: document.getElementById("dd-biz"),
    logout: document.getElementById("logout-btn"),
    toaststack: document.getElementById("toaststack"),
    modalhost: document.getElementById("modalhost"),
    apiIndicator: document.getElementById("api-indicator"),
  };

  function setCrumbs(text) { els.crumbs.textContent = text; }
  function setApiIndicator(text) { els.apiIndicator.textContent = text; }

  function toast(title, msg) {
    const t = document.createElement("div");
    t.className = "toast";
    t.innerHTML = `<div class="toast__title"></div><div class="toast__msg"></div>`;
    t.querySelector(".toast__title").textContent = title;
    t.querySelector(".toast__msg").textContent = msg;
    els.toaststack.appendChild(t);
    setTimeout(() => t.remove(), 4200);
  }

  function confirmModal({ title, body, confirmText = "Confirm", cancelText = "Cancel" }) {
    return new Promise((resolve) => {
      els.modalhost.innerHTML = `
        <div class="modalbackdrop" data-backdrop="1"></div>
        <div class="modal" role="dialog" aria-modal="true" aria-label="${escapeHtml(title)}">
          <div class="modal__head">
            <div class="modal__title">${escapeHtml(title)}</div>
            <button class="btn btn--ghost" type="button" data-close="1">Close</button>
          </div>
          <div class="modal__body">${body}</div>
          <div class="modal__foot">
            <button class="btn btn--ghost" type="button" data-cancel="1">${escapeHtml(cancelText)}</button>
            <button class="btn" type="button" data-confirm="1">${escapeHtml(confirmText)}</button>
          </div>
        </div>
      `;
      els.modalhost.style.pointerEvents = "auto";

      const cleanup = (val) => {
        els.modalhost.innerHTML = "";
        els.modalhost.style.pointerEvents = "none";
        resolve(val);
      };

      els.modalhost.addEventListener("click", (e) => {
        const t = e.target;
        if (t && t.dataset && (t.dataset.backdrop || t.dataset.close || t.dataset.cancel)) cleanup(false);
        if (t && t.dataset && t.dataset.confirm) cleanup(true);
      }, { once: true });
    });
  }

  function bindGlobal() {
    // user dropdown
    els.userchip.addEventListener("click", () => {
      const expanded = els.userchip.getAttribute("aria-expanded") === "true";
      els.userchip.setAttribute("aria-expanded", expanded ? "false" : "true");
      els.dropdown.hidden = expanded;
    });

    document.addEventListener("click", (e) => {
      const inside = els.userchip.contains(e.target) || els.dropdown.contains(e.target);
      if (!inside) {
        els.userchip.setAttribute("aria-expanded", "false");
        els.dropdown.hidden = true;
      }
    });

    // global search
    els.search.addEventListener("input", () => {
      State.set({ ui: { search: els.search.value } });
      Renderer.updateFilteredRowsOnly();
    });

    // logout
    els.logout.addEventListener("click", () => {
      localStorage.removeItem("deepsleep.token");
      State.set({ auth: { token: "" } });
      toast("Session", "Token cleared. You can re-login in Settings.");
      Router.go("/settings");
      els.userchip.setAttribute("aria-expanded", "false");
      els.dropdown.hidden = true;
    });
  }

  function renderUserChip() {
    const s = State.get();
    const email = s.auth.email || "User";
    els.userchipText.textContent = email;
    els.ddName.textContent = email;
    els.ddAws.textContent = s.account.aws_account_id || "—";
    els.ddBiz.textContent = s.auth.business_id || "—";
  }

  function escapeHtml(str) {
    return String(str)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  return { els, toast, confirmModal, bindGlobal, renderUserChip, setCrumbs, setApiIndicator, escapeHtml };
})();

const Router = (() => {
  const routes = new Map(); // name => handler

  function parseHash() {
    const raw = location.hash.replace(/^#/, "");
    const path = raw.startsWith("/") ? raw : "/discovery";
    const [p] = path.split("?");
    const parts = p.split("/").filter(Boolean);
    const name = parts[0] || "discovery";
    return { name, params: { } };
  }

  function setActiveNav(routeName) {
    document.querySelectorAll(".navlink").forEach((a) => {
      a.setAttribute("aria-current", a.dataset.route === routeName ? "page" : "false");
      if (a.dataset.route !== routeName) a.removeAttribute("aria-current");
    });
  }

  function register(name, handler) { routes.set(name, handler); }

  function go(path) { location.hash = "#" + path; }

  function start() {
    window.addEventListener("hashchange", () => {
      const r = parseHash();
      State.set({ route: r });
      render();
    });

    const r = parseHash();
    State.set({ route: r });
    render();
  }

  function render() {
    const { name } = State.get().route;
    setActiveNav(name);
    const handler = routes.get(name) || routes.get("discovery");
    handler?.();
  }

  return { register, start, go, render };
})();

const Components = (() => {
  const { escapeHtml: h } = UI;

  function panel({ title, sub, actionsHtml = "", bodyHtml = "" }) {
    return `
      <article class="panel">
        <div class="panel__head">
          <div>
            <div class="panel__title">${h(title)}</div>
            ${sub ? `<div class="panel__sub">${h(sub)}</div>` : ""}
          </div>
          ${actionsHtml ? `<div class="row">${actionsHtml}</div>` : ""}
        </div>
        ${bodyHtml}
      </article>
    `;
  }

  function badge(text, variant = "") {
    const cls = variant ? `badge badge--${variant}` : "badge";
    return `<span class="${cls}">${h(text)}</span>`;
  }

  function pillState(state, lockedUntil) {
    const s = (state || "—").toUpperCase();
    if (lockedUntil) return `<span class="pill pill--locked">LOCKED</span>`;
    if (s === "RUNNING") return `<span class="pill pill--running">RUNNING</span>`;
    if (s === "SLEEPING") return `<span class="pill pill--sleeping">SLEEPING</span>`;
    return `<span class="pill">${h(s)}</span>`;
  }

  function hardTable({ columns, rowsHtml }) {
    const th = columns.map((c) => `<th scope="col">${h(c)}</th>`).join("");
    return `
      <div class="tablewrap">
        <table>
          <thead><tr>${th}</tr></thead>
          <tbody>${rowsHtml}</tbody>
        </table>
      </div>
    `;
  }

  return { panel, badge, pillState, hardTable };
})();

const Renderer = (() => {
  // For the polling requirement: update only affected rows (Active Resources page)
  function updateFilteredRowsOnly() {
    const route = State.get().route.name;
    if (route === "discovery") {
      applyDiscoveryFilter();
    }
    if (route === "active") {
      applyActiveFilter();
    }
  }

  function applyDiscoveryFilter() {
    const q = State.get().ui.search.trim().toLowerCase();
    const tbody = document.querySelector('[data-table="discovery"] tbody');
    if (!tbody) return;

    tbody.querySelectorAll("tr").forEach((tr) => {
      const hay = (tr.getAttribute("data-hay") || "").toLowerCase();
      tr.style.display = (!q || hay.includes(q)) ? "" : "none";
    });
  }

  function applyActiveFilter() {
    const q = State.get().ui.search.trim().toLowerCase();
    const tbody = document.querySelector('[data-table="active"] tbody');
    if (!tbody) return;

    tbody.querySelectorAll("tr").forEach((tr) => {
      const hay = (tr.getAttribute("data-hay") || "").toLowerCase();
      tr.style.display = (!q || hay.includes(q)) ? "" : "none";
    });
  }

  function patchActiveRow(key, newRow) {
    const tr = document.querySelector(`tr[data-key="${cssEscape(key)}"]`);
    if (!tr) return;

    const old = State.get().active.rowsByKey.get(key) || {};
    // Patch only if changed (cheap diff)
    const changed =
      old.observed_state !== newRow.observed_state ||
      old.desired_state !== newRow.desired_state ||
      String(old.locked_until || "") !== String(newRow.locked_until || "") ||
      String(old.updated_at || "") !== String(newRow.updated_at || "") ||
      String(old.last_action || "") !== String(newRow.last_action || "") ||
      String(old.last_action_at || "") !== String(newRow.last_action_at || "");

    if (!changed) return;

    // Update state map
    State.get().active.rowsByKey.set(key, newRow);

    // Patch cells by data-col
    patchCell(tr, "observed", newRow.observed_state, newRow.locked_until);
    patchCell(tr, "desired", newRow.desired_state, null);
    patchCell(tr, "last", newRow.last_action_at ? `${newRow.last_action || "—"} @ ${fmtTime(newRow.last_action_at)}` : "—", null);
    patchCell(tr, "updated", newRow.updated_at ? fmtTime(newRow.updated_at) : "—", null);
  }

  function patchCell(tr, col, value, lockedUntil) {
    const td = tr.querySelector(`td[data-col="${col}"]`);
    if (!td) return;
    if (col === "observed") {
      td.innerHTML = Components.pillState(value, lockedUntil);
      return;
    }
    td.textContent = String(value ?? "—");
  }

  function fmtTime(v) {
    try {
      const d = new Date(v);
      if (Number.isNaN(d.getTime())) return String(v);
      // compact local time
      const pad = (n) => String(n).padStart(2, "0");
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
    } catch {
      return String(v);
    }
  }

  function cssEscape(str) {
    // minimal escape for attribute selector
    return String(str).replaceAll('"', '\\"');
  }

  return { updateFilteredRowsOnly, patchActiveRow, applyDiscoveryFilter, applyActiveFilter, fmtTime };
})();

const Pages = (() => {
  function requireAccount() {
    const s = State.get();
    if (!s.account.id) {
      UI.toast("Setup", "Missing account_id. Configure it in Settings.");
      Router.go("/settings");
      return false;
    }
    return true;
  }

  async function discovery() {
    UI.setCrumbs("Discovery / Inventory");
    const s = State.get();

    UI.els.page.innerHTML = Components.panel({
      title: "Inventory",
      sub: "Raw discovery via /resources/search. Select rows then Batch Register.",
      actionsHtml: `
        <span class="badge badge--muted">Hint: use global search <span class="kbd">Ctrl</span>+<span class="kbd">F</span> in table</span>
      `,
      bodyHtml: `
        <div class="row" style="margin-bottom:12px;">
          <div class="field">
            <div class="label">Account ID</div>
            <input class="input" id="inv-account" inputmode="numeric" value="${s.account.id || ""}" placeholder="e.g. 1" />
          </div>
          <div class="field">
            <div class="label">Regions (CSV)</div>
            <input class="input" id="inv-regions" value="${s.discovery.regionsCsv}" placeholder="eu-west-1,us-east-1" />
          </div>
          <div class="field">
            <div class="label">Resource Types</div>
            <select class="select" id="inv-types" multiple size="2" aria-label="Resource types">
              <option value="EKS_CLUSTER" ${s.discovery.resourceTypes.includes("EKS_CLUSTER") ? "selected" : ""}>EKS_CLUSTER</option>
              <option value="RDS_INSTANCE" ${s.discovery.resourceTypes.includes("RDS_INSTANCE") ? "selected" : ""}>RDS_INSTANCE</option>
            </select>
          </div>
          <div class="field" style="min-width:260px;">
            <div class="label">Only Registered</div>
            <select class="select" id="inv-onlyreg">
              <option value="0" ${s.discovery.onlyRegistered ? "" : "selected"}>false</option>
              <option value="1" ${s.discovery.onlyRegistered ? "selected" : ""}>true</option>
            </select>
          </div>
          <div class="row" style="margin-left:auto;">
            <button class="btn" id="inv-run" type="button">Run Search</button>
            <button class="btn btn--wake" id="inv-batch-reg" type="button">Batch Register</button>
            <button class="btn btn--sleep" id="inv-batch-unreg" type="button">Batch Unregister</button>
          </div>
        </div>

        <div class="mono-muted" id="inv-status">—</div>
        <div style="height:10px"></div>

        <div class="tablewrap" data-table="discovery">
          <table aria-label="Inventory table">
            <thead>
              <tr>
                <th style="width:42px;"><input type="checkbox" id="inv-check-all" aria-label="Select all"/></th>
                <th>Type</th>
                <th>Name</th>
                <th>Region</th>
                <th>Registered</th>
                <th>Observed</th>
                <th>Labels</th>
              </tr>
            </thead>
            <tbody id="inv-tbody"></tbody>
          </table>
        </div>
      `,
    });

    // Bind
    const invAccount = document.getElementById("inv-account");
    const invRegions = document.getElementById("inv-regions");
    const invTypes = document.getElementById("inv-types");
    const invOnlyReg = document.getElementById("inv-onlyreg");
    const btnRun = document.getElementById("inv-run");
    const btnReg = document.getElementById("inv-batch-reg");
    const btnUnreg = document.getElementById("inv-batch-unreg");
    const status = document.getElementById("inv-status");

    function readSearchPayload() {
      const accountId = Number(invAccount.value || 0);
      const regions = invRegions.value.split(",").map((x) => x.trim()).filter(Boolean);
      const types = Array.from(invTypes.selectedOptions).map((o) => o.value);

      const only_registered = invOnlyReg.value === "1";

      const payload = {
        resource_types: types.length ? types : ["EKS_CLUSTER", "RDS_INSTANCE"],
        regions: regions.length ? regions : null,
        selector_by_type: {},
        only_registered,
      };

      // Persist minimal UX
      localStorage.setItem("deepsleep.account_id", String(accountId || ""));
      State.set({
        account: { id: accountId },
        discovery: { regionsCsv: invRegions.value, onlyRegistered: only_registered, resourceTypes: payload.resource_types },
      });

      return { accountId, payload };
    }

    async function runSearch() {
      const { accountId, payload } = readSearchPayload();
      if (!accountId) return UI.toast("Inventory", "Missing account_id.");
      status.textContent = "Searching…";

      try {
        const resp = await API.searchResources(accountId, payload);
        const resources = (resp && resp.resources) ? resp.resources : [];

        // Normalize
        const norm = resources.map((r) => ({
          key: `${r.resource_type}|${r.resource_name}|${r.region}`,
          resource_type: r.resource_type,
          resource_name: r.resource_name,
          region: r.region,
          labels: r.labels || {},
          registered: !!r.registered,
          observed_state: r.observed_state || null,
          desired_state: r.desired_state || null,
        }));

        State.set({ discovery: { resources: norm, selectedKeys: new Set(), lastQuery: payload } });
        renderInventoryRows();
        status.textContent = `OK — ${norm.length} resource(s).`;
        Renderer.applyDiscoveryFilter();
      } catch (e) {
        status.textContent = "Error.";
        UI.toast("Inventory", e.message || "Search failed");
      }
    }

    function renderInventoryRows() {
      const tbody = document.getElementById("inv-tbody");
      const { resources, selectedKeys } = State.get().discovery;

      tbody.innerHTML = resources.map((r) => {
        const labels = Object.entries(r.labels || {}).slice(0, 6)
          .map(([k, v]) => `${k}:${v}`).join(", ");
        const reg = r.registered ? `<span class="badge badge--reg">REGISTERED</span>` : `<span class="badge">NO</span>`;
        const observed = r.observed_state ? Components.pillState(r.observed_state) : `<span class="mono-muted">—</span>`;
        const hay = `${r.resource_type} ${r.resource_name} ${r.region} ${labels}`;
        return `
          <tr data-key="${UI.escapeHtml(r.key)}" data-hay="${UI.escapeHtml(hay)}">
            <td>
              <input type="checkbox" class="inv-check" data-key="${UI.escapeHtml(r.key)}" ${selectedKeys.has(r.key) ? "checked" : ""} />
            </td>
            <td>${UI.escapeHtml(r.resource_type)}</td>
            <td>${UI.escapeHtml(r.resource_name)}</td>
            <td>${UI.escapeHtml(r.region)}</td>
            <td>${reg}</td>
            <td>${observed}</td>
            <td class="mono-muted">${UI.escapeHtml(labels || "—")}</td>
          </tr>
        `;
      }).join("");

      // row bindings
      tbody.querySelectorAll(".inv-check").forEach((cb) => {
        cb.addEventListener("change", () => {
          const key = cb.dataset.key;
          const set = State.get().discovery.selectedKeys;
          if (cb.checked) set.add(key); else set.delete(key);
        });
      });

      const checkAll = document.getElementById("inv-check-all");
      checkAll.checked = false;
      checkAll.addEventListener("change", () => {
        const set = State.get().discovery.selectedKeys;
        set.clear();
        tbody.querySelectorAll(".inv-check").forEach((cb) => {
          cb.checked = checkAll.checked;
          if (checkAll.checked) set.add(cb.dataset.key);
        });
      });
    }

    async function doBatch(mode) {
      const { accountId, payload } = readSearchPayload();
      const selected = Array.from(State.get().discovery.selectedKeys);

      if (!accountId) return UI.toast("Batch", "Missing account_id.");
      if (!selected.length) return UI.toast("Batch", "Select at least one row.");

      const ok = await UI.confirmModal({
        title: `Batch ${mode}`,
        body: `<div class="mono-muted">Selected: ${selected.length}. This will call /resources/batch-register.</div>`,
        confirmText: `Run ${mode}`,
        cancelText: "Cancel",
      });
      if (!ok) return;

      // We reuse SearchRequest and rely on selector_by_type include_names for each type based on selection.
      const byType = new Map();
      for (const key of selected) {
        const [t, name] = key.split("|");
        if (!byType.has(t)) byType.set(t, []);
        byType.get(t).push(name);
      }

      const selector_by_type = {};
      for (const [t, names] of byType.entries()) {
        selector_by_type[t] = { include_names: names, exclude_names: [], include_labels: {}, exclude_labels: {}, include_namespaces: null, exclude_namespaces: [] };
      }

      const body = {
        search: {
          resource_types: payload.resource_types,
          regions: payload.regions,
          selector_by_type,
          only_registered: payload.only_registered,
        },
        mode,
        dry_run: false,
      };

      status.textContent = `Batch ${mode}…`;
      try {
        const resp = await API.batchRegister(accountId, body);
        const results = resp?.results || [];
        const counts = results.reduce((acc, r) => {
          acc[r.action] = (acc[r.action] || 0) + 1;
          return acc;
        }, {});
        UI.toast("Batch", `OK — ${Object.entries(counts).map(([k,v]) => `${k}:${v}`).join(" ") || "done"}`);
        await runSearch();
      } catch (e) {
        status.textContent = "Batch error.";
        UI.toast("Batch", e.message || "Batch failed");
      }
    }

    btnRun.addEventListener("click", runSearch);
    btnReg.addEventListener("click", () => doBatch("REGISTER"));
    btnUnreg.addEventListener("click", () => doBatch("UNREGISTER"));

    // Auto-run if we already have a token + account id
    if (s.auth.token && s.account.id) runSearch();
  }

  async function active() {
    if (!requireAccount()) return;
    UI.setCrumbs("Active Resources / Control Panel");

    const s = State.get();
    UI.els.page.innerHTML = Components.panel({
      title: "Control Panel",
      sub: "Registered resources with one-click Sleep/Wake. Polls every 10 seconds and patches only changed rows.",
      actionsHtml: `
        <span class="badge badge--reg">Registered</span>
        <span class="badge">Wake: blue</span>
        <span class="badge">Sleep: brick</span>
      `,
      bodyHtml: `
        <div class="row" style="margin-bottom:12px;">
          <div class="field">
            <div class="label">Account ID</div>
            <input class="input" id="cp-account" inputmode="numeric" value="${s.account.id}" />
          </div>

          <div class="field">
            <div class="label">EKS plan_name</div>
            <input class="input" id="cp-plan-eks" value="${s.active.plans.EKS_CLUSTER || "dev"}" />
          </div>

          <div class="field">
            <div class="label">RDS plan_name</div>
            <input class="input" id="cp-plan-rds" value="${s.active.plans.RDS_INSTANCE || "rds_dev"}" />
          </div>

          <div class="row" style="margin-left:auto;">
            <button class="btn" id="cp-refresh" type="button">Refresh Now</button>
          </div>
        </div>

        <div class="mono-muted" id="cp-status">—</div>
        <div style="height:10px"></div>

        <div class="tablewrap" data-table="active">
          <table aria-label="Active resources table">
            <thead>
              <tr>
                <th>Type</th>
                <th>Name</th>
                <th>Region</th>
                <th>Observed</th>
                <th>Desired</th>
                <th>Last</th>
                <th>Updated</th>
                <th style="width:220px;">Toggle</th>
              </tr>
            </thead>
            <tbody id="cp-tbody"></tbody>
          </table>
        </div>
      `,
    });

    const status = document.getElementById("cp-status");
    const inpAccount = document.getElementById("cp-account");
    const inpPlanEks = document.getElementById("cp-plan-eks");
    const inpPlanRds = document.getElementById("cp-plan-rds");
    const btnRefresh = document.getElementById("cp-refresh");

    function persistControlInputs() {
      const accountId = Number(inpAccount.value || 0);
      const eksPlan = inpPlanEks.value.trim() || "dev";
      const rdsPlan = inpPlanRds.value.trim() || "rds_dev";

      localStorage.setItem("deepsleep.account_id", String(accountId || ""));
      State.set({ account: { id: accountId }, active: { plans: { EKS_CLUSTER: eksPlan, RDS_INSTANCE: rdsPlan } } });
    }

    async function loadActiveInitial() {
      persistControlInputs();
      const accountId = State.get().account.id;
      if (!accountId) return UI.toast("Control Panel", "Missing account_id.");

      status.textContent = "Loading…";
      try {
        const [eks, rds] = await Promise.all([
          API.listClusterStates(accountId).catch(() => ({ clusters: [] })),
          API.listRdsStates(accountId).catch(() => ({ instances: [] })),
        ]);

        const map = new Map();
        for (const c of (eks.clusters || [])) {
          const key = `EKS_CLUSTER|${c.cluster_name}|${c.region}`;
          map.set(key, {
            key,
            resource_type: "EKS_CLUSTER",
            resource_name: c.cluster_name,
            region: c.region,
            observed_state: c.observed_state,
            desired_state: c.desired_state,
            last_action: c.last_action,
            last_action_at: c.last_action_at,
            locked_until: c.locked_until,
            updated_at: c.updated_at,
          });
        }
        for (const r of (rds.instances || [])) {
          const key = `RDS_INSTANCE|${r.db_instance_id}|${r.region}`;
          map.set(key, {
            key,
            resource_type: "RDS_INSTANCE",
            resource_name: r.db_instance_id,
            region: r.region,
            observed_state: r.observed_state,
            desired_state: r.desired_state,
            last_action: r.last_action,
            last_action_at: r.last_action_at,
            locked_until: r.locked_until,
            updated_at: r.updated_at,
          });
        }

        State.get().active.rowsByKey = map; // assign map directly
        renderActiveTable(map);
        status.textContent = `OK — ${map.size} registered resource(s).`;
        Renderer.applyActiveFilter();
      } catch (e) {
        status.textContent = "Error.";
        UI.toast("Control Panel", e.message || "Load failed");
      }
    }

    function renderActiveTable(map) {
      const tbody = document.getElementById("cp-tbody");
      const rows = Array.from(map.values()).sort((a, b) => a.resource_type.localeCompare(b.resource_type) || a.resource_name.localeCompare(b.resource_name));
      tbody.innerHTML = rows.map((r) => activeRowHtml(r)).join("");
      bindActiveRowActions();
    }

    function activeRowHtml(r) {
      const key = r.key;
      const observed = Components.pillState(r.observed_state, r.locked_until);
      const desired = r.desired_state || "—";
      const last = r.last_action_at ? `${r.last_action || "—"} @ ${Renderer.fmtTime(r.last_action_at)}` : "—";
      const updated = r.updated_at ? Renderer.fmtTime(r.updated_at) : "—";
      const hay = `${r.resource_type} ${r.resource_name} ${r.region}`;

      const locked = !!(r.locked_until && new Date(r.locked_until).getTime() > Date.now());
      const sleepDisabled = locked || String(r.observed_state || "").toUpperCase() === "SLEEPING";
      const wakeDisabled = locked || String(r.observed_state || "").toUpperCase() === "RUNNING";

      return `
        <tr data-key="${UI.escapeHtml(key)}" data-hay="${UI.escapeHtml(hay)}">
          <td>${UI.escapeHtml(r.resource_type)}</td>
          <td>${UI.escapeHtml(r.resource_name)}</td>
          <td>${UI.escapeHtml(r.region)}</td>
          <td data-col="observed">${observed}</td>
          <td data-col="desired">${UI.escapeHtml(desired)}</td>
          <td data-col="last">${UI.escapeHtml(last)}</td>
          <td data-col="updated">${UI.escapeHtml(updated)}</td>
          <td>
            <div class="row">
              <button class="btn btn--sleep" type="button" data-action="sleep" data-key="${UI.escapeHtml(key)}" ${sleepDisabled ? "disabled" : ""}>Sleep</button>
              <button class="btn btn--wake" type="button" data-action="wake" data-key="${UI.escapeHtml(key)}" ${wakeDisabled ? "disabled" : ""}>Wake</button>
            </div>
          </td>
        </tr>
      `;
    }

    function bindActiveRowActions() {
      document.querySelectorAll('[data-action="sleep"], [data-action="wake"]').forEach((btn) => {
        btn.addEventListener("click", async () => {
          persistControlInputs();
          const accountId = State.get().account.id;
          const key = btn.dataset.key;
          const row = State.get().active.rowsByKey.get(key);
          if (!row) return;

          const action = btn.dataset.action;

          const ok = await UI.confirmModal({
            title: `${action.toUpperCase()} ${row.resource_type}`,
            body: `<div class="mono-muted">${row.resource_name} • ${row.region}</div>`,
            confirmText: action === "sleep" ? "Sleep" : "Wake",
            cancelText: "Cancel",
          });
          if (!ok) return;

          try {
            btn.disabled = true;

            if (row.resource_type === "EKS_CLUSTER") {
              if (action === "sleep") await API.sleepEKS(accountId, row.resource_name, row.region, State.get().active.plans.EKS_CLUSTER);
              else await API.wakeEKS(accountId, row.resource_name, row.region);
            } else if (row.resource_type === "RDS_INSTANCE") {
              if (action === "sleep") await API.sleepRDS(accountId, row.resource_name, row.region, State.get().active.plans.RDS_INSTANCE);
              else await API.wakeRDS(accountId, row.resource_name, row.region);
            }

            UI.toast("Orchestrator", "Run submitted. Polling will update state.");
          } catch (e) {
            UI.toast("Orchestrator", e.message || "Action failed");
          } finally {
            btn.disabled = false;
          }
        });
      });
    }

    btnRefresh.addEventListener("click", loadActiveInitial);
    inpAccount.addEventListener("change", loadActiveInitial);

    // initial load
    await loadActiveInitial();
  }

  async function policies() {
    if (!requireAccount()) return;
    UI.setCrumbs("Time Policies / Editor");

    const s = State.get();
    UI.els.page.innerHTML = `
      ${Components.panel({
        title: "Time Policies",
        sub: "Create structured weekly windows (TimeWindowDTO) and attach SearchRequest + plan_name_by_type.",
        actionsHtml: `
          <button class="btn" id="pol-refresh" type="button">Refresh</button>
          <button class="btn btn--wake" id="pol-new" type="button">New Policy</button>
        `,
        bodyHtml: `
          <div class="grid-2">
            <div>
              <div class="mono-muted" id="pol-status">—</div>
              <div style="height:10px"></div>
              <div class="tablewrap">
                <table aria-label="Policies list">
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
                  <tbody id="pol-tbody"></tbody>
                </table>
              </div>
            </div>

            <div>
              <div class="panel" style="margin:0;">
                <div class="panel__head">
                  <div>
                    <div class="panel__title">Policy Editor</div>
                    <div class="panel__sub">JSON editor (safe baseline). You can paste TimePolicyCreateRequest / UpdateRequest fields.</div>
                  </div>
                </div>

                <div class="field" style="min-width:unset;">
                  <div class="label">Selected policy ID</div>
                  <input class="input" id="pol-selected-id" value="${s.policies.selectedId ?? ""}" placeholder="(none)" />
                </div>

                <div style="height:10px"></div>

                <div class="field" style="min-width:unset;">
                  <div class="label">Payload (Create or Update)</div>
                  <textarea class="textarea" id="pol-json" spellcheck="false" placeholder='{
  "name": "Night Sleep",
  "enabled": true,
  "timezone": "UTC",
  "search": { "resource_types": ["EKS_CLUSTER","RDS_INSTANCE"], "regions": null, "selector_by_type": {}, "only_registered": true },
  "windows": [ { "days": ["MON","TUE","WED","THU","FRI"], "start": "21:00", "end": "07:00" } ],
  "plan_name_by_type": { "EKS_CLUSTER": "dev", "RDS_INSTANCE": "rds_dev" }
}'></textarea>
                </div>

                <div style="height:12px"></div>

                <div class="row">
                  <button class="btn" id="pol-create" type="button">Create</button>
                  <button class="btn" id="pol-update" type="button">Update</button>
                  <button class="btn btn--danger" id="pol-delete" type="button">Delete</button>
                  <span style="flex:1"></span>
                  <button class="btn btn--sleep" id="pol-run-sleep" type="button">Run Now: SLEEP</button>
                  <button class="btn btn--wake" id="pol-run-wake" type="button">Run Now: WAKE</button>
                </div>
              </div>
            </div>
          </div>
        `,
      })}
    `;

    const status = document.getElementById("pol-status");
    const tbody = document.getElementById("pol-tbody");
    const btnRefresh = document.getElementById("pol-refresh");
    const btnNew = document.getElementById("pol-new");
    const inpSel = document.getElementById("pol-selected-id");
    const txt = document.getElementById("pol-json");
    const btnCreate = document.getElementById("pol-create");
    const btnUpdate = document.getElementById("pol-update");
    const btnDelete = document.getElementById("pol-delete");
    const btnRunSleep = document.getElementById("pol-run-sleep");
    const btnRunWake = document.getElementById("pol-run-wake");

    async function loadList() {
      const accountId = State.get().account.id;
      status.textContent = "Loading…";
      try {
        const resp = await API.listPolicies(accountId);
        const list = resp?.policies || [];
        State.set({ policies: { list } });
        renderList(list);
        status.textContent = `OK — ${list.length} policy(s).`;
      } catch (e) {
        status.textContent = "Error.";
        UI.toast("Time Policies", e.message || "Load failed");
      }
    }

    function renderList(list) {
      tbody.innerHTML = list.map((p) => {
        const next = p.next_transition_at ? Renderer.fmtTime(p.next_transition_at) : "—";
        return `
          <tr>
            <td>${p.id}</td>
            <td>${UI.escapeHtml(p.name)}</td>
            <td>${p.enabled ? `<span class="badge badge--reg">true</span>` : `<span class="badge">false</span>`}</td>
            <td>${UI.escapeHtml(p.timezone || "UTC")}</td>
            <td class="mono-muted">${UI.escapeHtml(next)}</td>
            <td>
              <div class="row">
                <button class="btn btn--ghost" type="button" data-pol="select" data-id="${p.id}">Select</button>
                <button class="btn btn--ghost" type="button" data-pol="copy" data-id="${p.id}">Copy JSON</button>
              </div>
            </td>
          </tr>
        `;
      }).join("");

      tbody.querySelectorAll('[data-pol="select"]').forEach((b) => {
        b.addEventListener("click", () => {
          const id = Number(b.dataset.id);
          State.set({ policies: { selectedId: id } });
          inpSel.value = String(id);
          UI.toast("Editor", `Selected policy ${id}.`);
        });
      });

      tbody.querySelectorAll('[data-pol="copy"]').forEach((b) => {
        b.addEventListener("click", () => {
          const id = Number(b.dataset.id);
          const p = State.get().policies.list.find((x) => x.id === id);
          if (!p) return;
          const payload = {
            name: p.name,
            enabled: p.enabled,
            timezone: p.timezone,
            search: p.search,
            windows: p.windows,
            plan_name_by_type: p.plan_name_by_type || {},
          };
          txt.value = JSON.stringify(payload, null, 2);
          UI.toast("Editor", "JSON copied into editor.");
        });
      });
    }

    function readJson() {
      const raw = txt.value.trim();
      if (!raw) throw new Error("Editor is empty.");
      return JSON.parse(raw);
    }

    btnRefresh.addEventListener("click", loadList);
    btnNew.addEventListener("click", () => {
      txt.value = `{
  "name": "Night Sleep",
  "enabled": true,
  "timezone": "UTC",
  "search": {
    "resource_types": ["EKS_CLUSTER", "RDS_INSTANCE"],
    "regions": null,
    "selector_by_type": {},
    "only_registered": true
  },
  "windows": [
    { "days": ["MON","TUE","WED","THU","FRI"], "start": "21:00", "end": "07:00" }
  ],
  "plan_name_by_type": { "EKS_CLUSTER": "dev", "RDS_INSTANCE": "rds_dev" }
}`;
      UI.toast("Editor", "Template inserted.");
    });

    btnCreate.addEventListener("click", async () => {
      try {
        const accountId = State.get().account.id;
        const body = readJson();
        await API.createPolicy(accountId, body);
        UI.toast("Time Policies", "Created.");
        await loadList();
      } catch (e) {
        UI.toast("Time Policies", e.message || "Create failed");
      }
    });

    btnUpdate.addEventListener("click", async () => {
      try {
        const accountId = State.get().account.id;
        const id = Number(inpSel.value || 0);
        if (!id) throw new Error("Missing selected policy ID.");
        const body = readJson();
        await API.updatePolicy(accountId, id, body);
        UI.toast("Time Policies", "Updated.");
        await loadList();
      } catch (e) {
        UI.toast("Time Policies", e.message || "Update failed");
      }
    });

    btnDelete.addEventListener("click", async () => {
      try {
        const accountId = State.get().account.id;
        const id = Number(inpSel.value || 0);
        if (!id) throw new Error("Missing selected policy ID.");

        const ok = await UI.confirmModal({
          title: "Delete Policy",
          body: `<div class="mono-muted">Policy ${id} will be deleted (executions too).</div>`,
          confirmText: "Delete",
          cancelText: "Cancel",
        });
        if (!ok) return;

        await API.deletePolicy(accountId, id);
        UI.toast("Time Policies", "Deleted.");
        inpSel.value = "";
        State.set({ policies: { selectedId: null } });
        await loadList();
      } catch (e) {
        UI.toast("Time Policies", e.message || "Delete failed");
      }
    });

    btnRunSleep.addEventListener("click", async () => {
      try {
        const accountId = State.get().account.id;
        const id = Number(inpSel.value || 0);
        if (!id) throw new Error("Missing selected policy ID.");
        await API.runPolicyNow(accountId, id, "SLEEP");
        UI.toast("Time Policies", "Run-now SLEEP submitted.");
      } catch (e) {
        UI.toast("Time Policies", e.message || "Run-now failed");
      }
    });

    btnRunWake.addEventListener("click", async () => {
      try {
        const accountId = State.get().account.id;
        const id = Number(inpSel.value || 0);
        if (!id) throw new Error("Missing selected policy ID.");
        await API.runPolicyNow(accountId, id, "WAKE");
        UI.toast("Time Policies", "Run-now WAKE submitted.");
      } catch (e) {
        UI.toast("Time Policies", e.message || "Run-now failed");
      }
    });

    await loadList();
  }

  async function settings() {
    UI.setCrumbs("Settings");

    const s = State.get();
    UI.els.page.innerHTML = `
      ${Components.panel({
        title: "Connection & Auth",
        sub: "No framework. Vanilla state + manual render. Store minimal config in localStorage.",
        bodyHtml: `
          <div class="row" style="margin-bottom:12px;">
            <span class="badge">Neo-90s Matte</span>
            <span class="badge badge--muted">Hard borders • Hard shadows • Monospace</span>
          </div>

          <div class="grid-2">
            <div>
              <div class="field">
                <div class="label">API Base URL</div>
                <input class="input" id="set-baseurl" value="${UI.escapeHtml(API.getBaseUrl() || "")}" placeholder="e.g. http://localhost:8000" />
              </div>

              <div style="height:10px"></div>

              <div class="field">
                <div class="label">Account ID (internal)</div>
                <input class="input" id="set-accountid" inputmode="numeric" value="${s.account.id || ""}" placeholder="e.g. 1" />
              </div>

              <div style="height:10px"></div>

              <div class="field">
                <div class="label">AWS Account ID (display)</div>
                <input class="input" id="set-aws" value="${UI.escapeHtml(s.account.aws_account_id || "")}" placeholder="e.g. 123456789012" />
              </div>

              <div style="height:10px"></div>

              <div class="field">
                <div class="label">Business ID</div>
                <input class="input" id="set-biz" value="${UI.escapeHtml(s.auth.business_id || "")}" placeholder="UUID / int" />
              </div>

              <div style="height:12px"></div>

              <div class="row">
                <button class="btn" id="set-save" type="button">Save Settings</button>
              </div>
            </div>

            <div>
              <div class="panel" style="margin:0;">
                <div class="panel__head">
                  <div>
                    <div class="panel__title">Login</div>
                    <div class="panel__sub">Calls /auth/login (business_user) and stores token.</div>
                  </div>
                </div>

                <div class="field">
                  <div class="label">Email</div>
                  <input class="input" id="login-email" value="${UI.escapeHtml(s.auth.email || "")}" placeholder="you@company.com" />
                </div>

                <div style="height:10px"></div>

                <div class="field">
                  <div class="label">Password</div>
                  <input class="input" id="login-pass" type="password" value="" placeholder="••••••••" />
                </div>

                <div style="height:10px"></div>

                <div class="field">
                  <div class="label">Business ID</div>
                  <input class="input" id="login-biz" value="${UI.escapeHtml(s.auth.business_id || "")}" placeholder="business_id" />
                </div>

                <div style="height:12px"></div>

                <div class="row">
                  <button class="btn btn--wake" id="login-btn" type="button">Login</button>
                  <button class="btn" id="token-clear" type="button">Clear Token</button>
                </div>

                <div style="height:12px"></div>
                <div class="mono-muted">Token: <span id="token-preview">${UI.escapeHtml((s.auth.token || "").slice(0, 28) || "—")}</span></div>
              </div>
            </div>
          </div>
        `,
      })}
    `;

    const baseUrl = document.getElementById("set-baseurl");
    const accountId = document.getElementById("set-accountid");
    const aws = document.getElementById("set-aws");
    const biz = document.getElementById("set-biz");
    const btnSave = document.getElementById("set-save");

    const email = document.getElementById("login-email");
    const pass = document.getElementById("login-pass");
    const biz2 = document.getElementById("login-biz");
    const btnLogin = document.getElementById("login-btn");
    const btnClear = document.getElementById("token-clear");
    const tokenPreview = document.getElementById("token-preview");

    btnSave.addEventListener("click", () => {
      API.setBaseUrl(baseUrl.value.trim());

      const aid = Number(accountId.value || 0);
      localStorage.setItem("deepsleep.account_id", String(aid || ""));
      localStorage.setItem("deepsleep.aws_account_id", aws.value.trim());
      localStorage.setItem("deepsleep.business_id", biz.value.trim());

      State.set({
        account: { id: aid, aws_account_id: aws.value.trim() },
        auth: { business_id: biz.value.trim() },
      });

      UI.renderUserChip();
      UI.toast("Settings", "Saved.");
    });

    btnLogin.addEventListener("click", async () => {
      try {
        API.setBaseUrl(baseUrl.value.trim());

        const payload = { email: email.value.trim(), password: pass.value, business_id: biz2.value.trim() };
        if (!payload.email || !payload.password || !payload.business_id) throw new Error("Missing email/password/business_id.");

        const resp = await API.login(payload);
        const token = resp?.token;
        if (!token) throw new Error("No token returned.");

        localStorage.setItem("deepsleep.token", token);
        localStorage.setItem("deepsleep.email", payload.email);
        localStorage.setItem("deepsleep.business_id", payload.business_id);

        State.set({ auth: { token, email: payload.email, business_id: payload.business_id } });
        tokenPreview.textContent = token.slice(0, 28);
        UI.renderUserChip();
        UI.toast("Auth", "Login OK.");

        // Convenience: go discovery
        Router.go("/discovery");
      } catch (e) {
        UI.toast("Auth", e.message || "Login failed");
      }
    });

    btnClear.addEventListener("click", () => {
      localStorage.removeItem("deepsleep.token");
      State.set({ auth: { token: "" } });
      tokenPreview.textContent = "—";
      UI.toast("Auth", "Token cleared.");
    });
  }

  return { discovery, active, policies, settings };
})();

const Poller = (() => {
  let timer = null;
  const intervalMs = 10_000;

  async function tick() {
    const s = State.get();
    if (!s.account.id || !s.auth.token) return; // do not poll if not configured

    // Only patch when Active Resources page is visible (requirement focuses on /cluster-states)
    const route = s.route.name;
    if (route !== "active") return;

    const accountId = s.account.id;
    try {
      const eks = await API.listClusterStates(accountId);
      const clusters = eks?.clusters || [];
      for (const c of clusters) {
        const key = `EKS_CLUSTER|${c.cluster_name}|${c.region}`;
        Renderer.patchActiveRow(key, {
          key,
          resource_type: "EKS_CLUSTER",
          resource_name: c.cluster_name,
          region: c.region,
          observed_state: c.observed_state,
          desired_state: c.desired_state,
          last_action: c.last_action,
          last_action_at: c.last_action_at,
          locked_until: c.locked_until,
          updated_at: c.updated_at,
        });
      }

      // Optional: also patch RDS on same interval for consistency
      const rds = await API.listRdsStates(accountId);
      const instances = rds?.instances || [];
      for (const r of instances) {
        const key = `RDS_INSTANCE|${r.db_instance_id}|${r.region}`;
        Renderer.patchActiveRow(key, {
          key,
          resource_type: "RDS_INSTANCE",
          resource_name: r.db_instance_id,
          region: r.region,
          observed_state: r.observed_state,
          desired_state: r.desired_state,
          last_action: r.last_action,
          last_action_at: r.last_action_at,
          locked_until: r.locked_until,
          updated_at: r.updated_at,
        });
      }

      State.set({ active: { lastPollAt: new Date().toISOString() } });
    } catch (e) {
      // keep silent-ish, but show a small toast occasionally
      UI.toast("Polling", e.message || "Poll failed");
    }
  }

  function start() {
    stop();
    timer = setInterval(tick, intervalMs);
    // fire once quickly for UX
    setTimeout(tick, 700);
  }

  function stop() {
    if (timer) clearInterval(timer);
    timer = null;
  }

  return { start, stop };
})();

/* ---------- Boot ---------- */
(function boot() {
  API.setBaseUrl(localStorage.getItem("deepsleep.baseUrl") || "");
  UI.bindGlobal();

  // render user chip + api indicator
  UI.renderUserChip();
  UI.setApiIndicator(API.getBaseUrl() || "—");

  // router registration
  Router.register("discovery", Pages.discovery);
  Router.register("active", Pages.active);
  Router.register("policies", Pages.policies);
  Router.register("settings", Pages.settings);

  // initial search input value from state
  UI.els.search.value = State.get().ui.search || "";

  // react to route changes (render crumbs etc. is done by pages)
  State.subscribe(() => {
    UI.renderUserChip();
  });

  Router.start();
  Poller.start();
})();
