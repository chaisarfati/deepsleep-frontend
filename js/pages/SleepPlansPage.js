/**
 * SleepPlansPage.js — Sleep plan configuration
 * Clean 2026 redesign: plan cards + slide-in drawer editor
 */
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import * as Api from "../api/services.js";

// ── Utilities ─────────────────────────────────────────────────────────────────

function requireAuthAndAccount() {
  const s = Store.getState();
  if (!s.auth.token)  { toast("Auth", "Please login."); location.hash = "#/login"; return false; }
  if (!s.account.id) { toast("Account", "Choose an account first."); return false; }
  return true;
}

function getPlanNames(config) { return Object.keys(config?.sleep_plans || {}).sort(); }

function defaultValueFromSchema(schema) {
  if (!schema) return null;
  if (schema.default !== undefined) return schema.default;
  if (schema.type === "boolean") return false;
  if (schema.type === "integer" || schema.type === "number") return 0;
  if (schema.type === "array") return [];
  if (schema.type === "object") return {};
  return "";
}

function buildInitialStepValue(stepSchema, existingValue) {
  if (existingValue !== undefined) return existingValue;
  const props = stepSchema?.properties || {};
  return Object.fromEntries(
    Object.entries(props).map(([f, fs]) => [f, defaultValueFromSchema(fs)])
  );
}

function setDeep(obj, path, value) {
  const parts = path.split(".");
  let cur = obj;
  while (parts.length > 1) {
    const p = parts.shift();
    if (!cur[p] || typeof cur[p] !== "object") cur[p] = {};
    cur = cur[p];
  }
  cur[parts[0]] = value;
}

function dictToKvCsv(d) {
  if (!d || typeof d !== "object") return "";
  return Object.entries(d).map(([k, v]) => `${k}=${v}`).join(", ");
}

function kvCsvToDict(v) {
  const out = {};
  String(v || "").split(",").map(s => s.trim()).filter(Boolean).forEach(e => {
    const i = e.indexOf("=");
    if (i > 0) out[e.slice(0, i).trim()] = e.slice(i + 1).trim();
  });
  return out;
}

function serializeField(raw, schema) {
  if (schema?.type === "boolean") return !!raw;
  if (schema?.type === "integer" || schema?.type === "number") {
    const n = Number(raw); return Number.isFinite(n) ? n : 0;
  }
  if (schema?.type === "array" && schema?.items?.type === "string")
    return String(raw || "").split(",").map(s => s.trim()).filter(Boolean);
  if (schema?.type === "object") return kvCsvToDict(raw);
  return raw;
}

// ── Catalog loading ───────────────────────────────────────────────────────────

async function ensureCatalog() {
  const s = Store.getState();
  if (Object.keys(s.plansCatalog.supported || {}).length) return s.plansCatalog.supported;
  const supported = await Api.getSupportedPlans();
  Store.setState({ plansCatalog: { ...s.plansCatalog, supported } });
  return supported;
}

async function ensurePlanSchema(planType) {
  const s = Store.getState();
  if (s.plansCatalog.planSchemas?.[planType]) return s.plansCatalog.planSchemas[planType];
  const schema = await Api.getPlanSchema(planType);
  Store.setState({ plansCatalog: { ...s.plansCatalog, planSchemas: { ...(s.plansCatalog.planSchemas || {}), [planType]: schema } } });
  return schema;
}

// ── Plan card ──────────────────────────────────────────────────────────────────

function planTypeLabel(planType) {
  const map = { EKS_CLUSTER_SLEEP: "EKS", RDS_SLEEP: "RDS", EC2_SLEEP: "EC2" };
  return map[planType] || planType;
}

function planTypeColor(planType) {
  if (planType?.includes("EKS")) return "ds-resource-chip--eks";
  if (planType?.includes("RDS")) return "ds-resource-chip--rds";
  if (planType?.includes("EC2")) return "ds-resource-chip--ec2";
  return "";
}

function renderPlanCard(name, plan) {
  const type = plan?.plan_type || "—";
  const steps = Object.keys(plan?.step_configs || {});
  return `
    <div class="ds-policy-card" data-plan-name="${h(name)}">
      <div class="ds-policy-card__icon">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.6">
          <path d="M9 3v6l3 2"/><circle cx="9" cy="9" r="7"/>
        </svg>
      </div>
      <div class="ds-policy-card__body">
        <div class="ds-policy-card__name">${h(name)}</div>
        <div class="ds-policy-card__meta">
          <span class="ds-resource-chip ${planTypeColor(type)}">${planTypeLabel(type)}</span>
          ${steps.length ? `<span class="ds-mono" style="font-size:11px;color:var(--fg-faint);">${steps.length} step${steps.length > 1 ? "s" : ""}</span>` : ""}
        </div>
      </div>
      <div class="ds-policy-card__actions">
        <button class="ds-btn ds-btn--sm" data-plan-action="edit" data-plan="${h(name)}">
          <svg width="12" height="12" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.7">
            <path d="M10 2l2 2-8 8H2v-2l8-8z"/>
          </svg>
          Edit
        </button>
        <button class="ds-btn ds-btn--sm ds-btn--danger" data-plan-action="delete" data-plan="${h(name)}">
          <svg width="12" height="12" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.7">
            <path d="M2 4h10M5 4V2h4v2M5 6v5M9 6v5M3 4l1 8h6l1-8"/>
          </svg>
          Delete
        </button>
      </div>
    </div>
  `;
}

// ── Step field renderer ────────────────────────────────────────────────────────

function renderStepField(stepType, fieldName, fieldSchema, value, path) {
  const label = fieldSchema?.title || fieldName;
  const type = fieldSchema?.type;
  const desc = fieldSchema?.description ? `<div class="ds-mono" style="font-size:10.5px;color:var(--fg-faint);margin-top:3px;">${h(fieldSchema.description)}</div>` : "";

  if (type === "boolean") return `
    <div class="ds-field">
      <label style="display:flex;align-items:center;gap:10px;cursor:pointer;">
        <label class="ds-toggle"><input type="checkbox" data-plan-path="${h(path)}" ${value ? "checked" : ""}><span class="ds-toggle__track"></span></label>
        <span class="ds-label" style="margin:0;">${h(label)}</span>
      </label>
      ${desc}
    </div>`;

  if (type === "integer" || type === "number") return `
    <div class="ds-field">
      <label class="ds-label">${h(label)}</label>
      <input class="ds-input" data-plan-path="${h(path)}" type="number" value="${h(String(value ?? 0))}" style="max-width:160px;"/>
      ${desc}
    </div>`;

  if (type === "array" && fieldSchema?.items?.type === "string") return `
    <div class="ds-field" style="grid-column:1/-1;">
      <label class="ds-label">${h(label)} <span style="font-weight:400;color:var(--fg-faint)">(comma-separated)</span></label>
      <input class="ds-input" data-plan-path="${h(path)}" value="${h((value || []).join(","))}" placeholder="value1, value2"/>
      ${desc}
    </div>`;

  if (type === "object") return `
    <div class="ds-field" style="grid-column:1/-1;">
      <label class="ds-label">${h(label)} <span style="font-weight:400;color:var(--fg-faint)">(key=value, …)</span></label>
      <input class="ds-input" data-plan-path="${h(path)}" value="${h(dictToKvCsv(value || {}))}" placeholder="key=value, key2=value2"/>
      ${desc}
    </div>`;

  return `
    <div class="ds-field" style="grid-column:1/-1;">
      <label class="ds-label">${h(label)}</label>
      <input class="ds-input" data-plan-path="${h(path)}" value="${h(String(value ?? ""))}"/>
      ${desc}
    </div>`;
}

function renderStepSection(stepType, stepSchema, stepValue) {
  const props = stepSchema?.properties || {};
  if (!Object.keys(props).length) return "";
  const fields = Object.entries(props).map(([fn, fs]) =>
    renderStepField(stepType, fn, fs, stepValue?.[fn], `${stepType}.${fn}`)
  ).join("");

  return `
    <div style="margin-bottom:20px;">
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:14px;padding-bottom:10px;border-bottom:1px solid var(--border);">
        <span class="ds-badge ds-badge--accent">${h(stepType)}</span>
        ${stepSchema?.title ? `<span style="font-size:12px;color:var(--fg-muted);">${h(stepSchema.title)}</span>` : ""}
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
        ${fields}
      </div>
    </div>
  `;
}

// ── Drawer editor ─────────────────────────────────────────────────────────────

async function openDrawer({ mode, planName, existingPlan, onSaved }) {
  const overlay = document.createElement("div");
  overlay.id = "ds-plan-drawer-overlay";
  overlay.style.cssText = `
    position:fixed;inset:0;z-index:180;
    background:rgba(19,19,16,.35);backdrop-filter:blur(3px);
    animation:fade-in 160ms ease;
  `;

  const drawer = document.createElement("div");
  drawer.id = "ds-plan-drawer";
  drawer.style.cssText = `
    position:fixed;top:0;right:0;bottom:0;width:min(560px,100vw);
    background:var(--bg-surface);border-left:1px solid var(--border);
    box-shadow:var(--shadow-lg);z-index:181;
    display:flex;flex-direction:column;overflow:hidden;
    animation:drawer-in 220ms cubic-bezier(.2,.8,.4,1);
  `;

  const style = document.createElement("style");
  style.textContent = `
    @keyframes drawer-in { from { transform:translateX(100%); } to { transform:translateX(0); } }
  `;
  document.head.appendChild(style);
  document.body.appendChild(overlay);
  document.body.appendChild(drawer);

  const supported = await ensureCatalog();
  const supportedPlanTypes = Object.keys(supported || {}).sort();
  const initialType = existingPlan?.plan_type || supportedPlanTypes[0];

  let editorState = {
    name: planName || "",
    plan_type: initialType,
    step_configs: {},
  };

  async function loadSchemaAndInit(planType, existingSteps = null) {
    const schema = await ensurePlanSchema(planType);
    editorState.step_configs = {};
    for (const [stepType, stepSchema] of Object.entries(schema || {})) {
      editorState.step_configs[stepType] = buildInitialStepValue(stepSchema, existingSteps?.[stepType]);
    }
    return schema;
  }

  async function renderDrawer() {
    const schema = Store.getState().plansCatalog.planSchemas?.[editorState.plan_type] || {};
    const stepSections = Object.entries(schema).map(([st, ss]) =>
      renderStepSection(st, ss, editorState.step_configs?.[st] || {})
    ).join("");

    const preview = JSON.stringify({
      sleep_plans: {
        [editorState.name || "(name)"]: {
          plan_type: editorState.plan_type,
          step_configs: editorState.step_configs,
        },
      },
    }, null, 2);

    drawer.innerHTML = `
      <!-- Header -->
      <div style="display:flex;align-items:center;justify-content:space-between;padding:20px 24px;border-bottom:1px solid var(--border);flex-shrink:0;">
        <div>
          <div style="font-family:var(--font-display);font-size:16px;font-weight:700;color:var(--fg-strong);letter-spacing:-.02em;">
            ${mode === "edit" ? `Edit — ${h(editorState.name)}` : "New Sleep Plan"}
          </div>
          <div style="font-size:12px;color:var(--fg-faint);margin-top:2px;">
            ${mode === "edit" ? "Modify configuration and save" : "Configure a new plan for this account"}
          </div>
        </div>
        <button class="ds-btn ds-btn--ghost ds-btn--icon" id="ds-drawer-close" aria-label="Close">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M1 1l12 12M13 1L1 13"/>
          </svg>
        </button>
      </div>

      <!-- Body -->
      <div style="flex:1;overflow-y:auto;padding:24px;">
        <!-- Name + Type -->
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:24px;">
          <div class="ds-field">
            <label class="ds-label">Plan name</label>
            <input class="ds-input" id="ds-drawer-name" value="${h(editorState.name)}" placeholder="e.g. dev-nightly"
              ${mode === "edit" ? "disabled" : ""}/>
          </div>
          <div class="ds-field">
            <label class="ds-label">Plan type</label>
            <select class="ds-select" id="ds-drawer-type" ${mode === "edit" ? "disabled" : ""}>
              ${supportedPlanTypes.map(pt =>
                `<option value="${h(pt)}" ${pt === editorState.plan_type ? "selected" : ""}>${h(pt)}</option>`
              ).join("")}
            </select>
          </div>
        </div>

        <!-- Step configs -->
        <div style="margin-bottom:24px;">
          <div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--fg-faint);margin-bottom:14px;">Step configuration</div>
          <div id="ds-drawer-steps">${stepSections || '<div class="ds-mono" style="color:var(--fg-faint);">No steps for this plan type.</div>'}</div>
        </div>

        <!-- JSON preview -->
        <div>
          <div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--fg-faint);margin-bottom:10px;">Config preview</div>
          <pre id="ds-drawer-preview" style="
            background:var(--stone-900);color:var(--stone-200);
            border-radius:var(--r-md);padding:16px 18px;
            font-family:var(--font-mono);font-size:11.5px;line-height:1.65;
            overflow:auto;max-height:260px;white-space:pre;
          ">${h(preview)}</pre>
        </div>
      </div>

      <!-- Footer -->
      <div style="display:flex;justify-content:flex-end;gap:8px;padding:16px 24px;border-top:1px solid var(--border);background:var(--stone-50);flex-shrink:0;">
        <button class="ds-btn ds-btn--ghost" id="ds-drawer-cancel">Cancel</button>
        <button class="ds-btn ds-btn--primary" id="ds-drawer-save">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.8">
            <path d="M2 7l4 4 6-7"/>
          </svg>
          ${mode === "edit" ? "Save changes" : "Create plan"}
        </button>
      </div>
    `;

    bindDrawer();
  }

  function updatePreview() {
    const pre = qs("#ds-drawer-preview");
    if (!pre) return;
    pre.textContent = JSON.stringify({
      sleep_plans: {
        [editorState.name || "(name)"]: {
          plan_type: editorState.plan_type,
          step_configs: editorState.step_configs,
        },
      },
    }, null, 2);
  }

  function close() {
    overlay.remove();
    drawer.remove();
    style.remove();
  }

  function bindDrawer() {
    qs("#ds-drawer-close")?.addEventListener("click", close);
    qs("#ds-drawer-cancel")?.addEventListener("click", close);
    overlay.addEventListener("click", close);

    qs("#ds-drawer-name")?.addEventListener("input", (e) => {
      editorState.name = e.target.value.trim();
      updatePreview();
    });

    qs("#ds-drawer-type")?.addEventListener("change", async (e) => {
      const nextType = e.target.value;
      editorState.plan_type = nextType;
      await loadSchemaAndInit(nextType);
      await renderDrawer();
    });

    qsa("[data-plan-path]", drawer).forEach((el) => {
      const handler = () => {
        const path = el.dataset.planPath;
        const [stepType, fieldName] = path.split(".");
        const planSchema = Store.getState().plansCatalog.planSchemas?.[editorState.plan_type] || {};
        const fieldSchema = planSchema?.[stepType]?.properties?.[fieldName];
        const raw = el.type === "checkbox" ? el.checked : el.value;
        setDeep(editorState.step_configs, path, serializeField(raw, fieldSchema));
        updatePreview();
      };
      el.addEventListener("input", handler);
      el.addEventListener("change", handler);
    });

    qs("#ds-drawer-save")?.addEventListener("click", async () => {
      if (!editorState.name) return toast("Sleep Plans", "Plan name is required.");
      try {
        const s = Store.getState();
        const cfg = JSON.parse(JSON.stringify(s.sleepPlans.config || { sleep_plans: {} }));
        cfg.sleep_plans = cfg.sleep_plans || {};
        cfg.sleep_plans[editorState.name] = {
          plan_type: editorState.plan_type,
          step_configs: editorState.step_configs,
        };
        const saved = await Api.putAccountConfig(s.account.id, cfg);
        Store.setState({ sleepPlans: { config: saved || cfg, names: getPlanNames(saved || cfg) } });
        toast("Sleep Plans", mode === "edit" ? "Plan updated." : "Plan created.");
        close();
        onSaved?.();
      } catch (e) {
        toast("Sleep Plans", e.message || "Save failed.");
      }
    });
  }

  await loadSchemaAndInit(initialType, existingPlan?.step_configs);
  await renderDrawer();
}

// ── Page ──────────────────────────────────────────────────────────────────────

export async function SleepPlansPage() {
  const page = qs("#ds-page");
  if (!page) return;
  if (!requireAuthAndAccount()) return;

  page.innerHTML = `
    <div class="ds-page-header">
      <div>
        <div class="ds-page-title">Sleep Plans</div>
        <div class="ds-page-sub">Configure automation plans that define how resources are put to sleep and woken up.</div>
      </div>
      <div class="ds-page-header__actions">
        <div id="ds-plans-loading" style="display:none;align-items:center;gap:8px;">
          <div class="ds-spinner"></div>
          <span class="ds-mono" style="font-size:12px;color:var(--accent);">Loading…</span>
        </div>
        <button class="ds-btn ds-btn--primary" id="ds-plan-create">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M7 2v10M2 7h10"/>
          </svg>
          New Plan
        </button>
      </div>
    </div>

    <!-- Empty / list container -->
    <div id="ds-plans-container">
      <div class="ds-empty" style="margin-top:40px;">
        <div class="ds-spinner"></div>
      </div>
    </div>
  `;

  const container  = qs("#ds-plans-container");
  const loadingEl  = qs("#ds-plans-loading");
  const btnCreate  = qs("#ds-plan-create");

  async function loadAndRender() {
    loadingEl.style.display = "flex";
    try {
      await ensureCatalog();
      const cfg = await Api.getAccountConfig(Store.getState().account.id);
      const names = getPlanNames(cfg);
      Store.setState({ sleepPlans: { config: cfg, names } });

      if (!names.length) {
        container.innerHTML = `
          <div class="ds-empty" style="margin-top:60px;">
            <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <circle cx="12" cy="12" r="8"/><path d="M12 6v6l3 2"/>
            </svg>
            <div class="ds-empty__title">No sleep plans yet</div>
            <div class="ds-empty__sub">Create your first plan to start automating resource schedules.</div>
            <button class="ds-btn ds-btn--primary" id="ds-plan-create-empty" style="margin-top:16px;">
              <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M7 2v10M2 7h10"/>
              </svg>
              Create first plan
            </button>
          </div>`;
        qs("#ds-plan-create-empty")?.addEventListener("click", () => openDrawer({ mode: "new", planName: "", existingPlan: null, onSaved: loadAndRender }));
        return;
      }

      container.innerHTML = `
        <div style="display:grid;gap:8px;">
          ${names.map(name => renderPlanCard(name, cfg.sleep_plans[name])).join("")}
        </div>
      `;

      bindListActions(cfg);
    } catch (e) {
      container.innerHTML = `<div class="ds-empty"><div class="ds-empty__title">Failed to load</div><div class="ds-empty__sub">${h(e.message)}</div></div>`;
      toast("Sleep Plans", e.message || "Load failed.");
    } finally {
      loadingEl.style.display = "none";
    }
  }

  function bindListActions(cfg) {
    qsa("[data-plan-action='edit']", container).forEach((btn) => {
      btn.addEventListener("click", () => {
        const name = btn.dataset.plan;
        const plan = cfg.sleep_plans[name];
        openDrawer({ mode: "edit", planName: name, existingPlan: plan, onSaved: loadAndRender });
      });
    });

    qsa("[data-plan-action='delete']", container).forEach((btn) => {
      btn.addEventListener("click", async () => {
        const name = btn.dataset.plan;
        const ok = await confirmModal({
          title: `Delete plan "${name}"?`,
          body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">This cannot be undone. Time policies using this plan will lose their configuration.</p>`,
          confirmText: "Delete",
          danger: true,
        });
        if (!ok) return;
        try {
          const s = Store.getState();
          const cfg = JSON.parse(JSON.stringify(s.sleepPlans.config || { sleep_plans: {} }));
          delete cfg.sleep_plans[name];
          const saved = await Api.putAccountConfig(s.account.id, cfg);
          Store.setState({ sleepPlans: { config: saved || cfg, names: getPlanNames(saved || cfg) } });
          toast("Sleep Plans", "Deleted.");
          await loadAndRender();
        } catch (e) {
          toast("Sleep Plans", e.message || "Delete failed.");
        }
      });
    });
  }

  btnCreate.addEventListener("click", () =>
    openDrawer({ mode: "new", planName: "", existingPlan: null, onSaved: loadAndRender })
  );

  await loadAndRender();
}
