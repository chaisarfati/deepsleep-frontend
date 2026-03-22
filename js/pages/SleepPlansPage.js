import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
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

function getPlanNames(config) {
  return Object.keys(config?.sleep_plans || {}).sort();
}

function normalizePrimitiveBySchema(value, schema) {
  const type = schema?.type;
  if (type === "integer" || type === "number") {
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
  }
  if (type === "boolean") {
    return !!value;
  }
  return value ?? "";
}

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
  const out = {};
  for (const [field, fieldSchema] of Object.entries(props)) {
    out[field] = defaultValueFromSchema(fieldSchema);
  }
  return out;
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

function getDeep(obj, path) {
  return path.split(".").reduce((acc, p) => (acc ? acc[p] : undefined), obj);
}

function dictToKvCsv(d) {
  if (!d || typeof d !== "object") return "";
  return Object.entries(d).map(([k, v]) => `${k}=${v}`).join(", ");
}

function kvCsvToDict(v) {
  const out = {};
  String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .forEach((entry) => {
      const idx = entry.indexOf("=");
      if (idx <= 0) return;
      const k = entry.slice(0, idx).trim();
      const val = entry.slice(idx + 1).trim();
      if (k) out[k] = val;
    });
  return out;
}

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function renderField(stepType, fieldName, fieldSchema, value, path) {
  const label = fieldSchema?.title || fieldName;
  const type = fieldSchema?.type;

  if (type === "boolean") {
    return `
      <label class="ds-badge" style="gap:10px;">
        <input type="checkbox" data-plan-path="${h(path)}" ${value ? "checked" : ""} />
        <span>${h(label)}</span>
      </label>
    `;
  }

  if (type === "integer" || type === "number") {
    return `
      <div class="ds-field" style="min-width:180px;">
        <div class="ds-label">${h(label)}</div>
        <input class="ds-input" data-plan-path="${h(path)}" type="number" value="${h(String(value ?? 0))}" />
      </div>
    `;
  }

  if (type === "array" && fieldSchema?.items?.type === "string") {
    return `
      <div class="ds-field" style="min-width:unset;flex:1;">
        <div class="ds-label">${h(label)} (CSV)</div>
        <input class="ds-input" data-plan-path="${h(path)}" value="${h((value || []).join(","))}" />
      </div>
    `;
  }

  if (type === "object") {
    return `
      <div class="ds-field" style="min-width:unset;flex:1;">
        <div class="ds-label">${h(label)} (CSV key=value)</div>
        <input class="ds-input" data-plan-path="${h(path)}" value="${h(dictToKvCsv(value || {}))}" />
      </div>
    `;
  }

  return `
    <div class="ds-field" style="min-width:unset;flex:1;">
      <div class="ds-label">${h(label)}</div>
      <input class="ds-input" data-plan-path="${h(path)}" value="${h(String(value ?? ""))}" />
    </div>
  `;
}

function serializeFieldValue(rawValue, schema) {
  if (schema?.type === "boolean") return !!rawValue;
  if (schema?.type === "integer" || schema?.type === "number") {
    const n = Number(rawValue);
    return Number.isFinite(n) ? n : 0;
  }
  if (schema?.type === "array" && schema?.items?.type === "string") {
    return csvToList(rawValue);
  }
  if (schema?.type === "object") {
    return kvCsvToDict(rawValue);
  }
  return rawValue;
}

function renderStepEditor(stepType, stepSchema, stepValue) {
  const props = stepSchema?.properties || {};
  const fields = Object.entries(props).map(([fieldName, fieldSchema]) => {
    const path = `${stepType}.${fieldName}`;
    const value = stepValue?.[fieldName];
    return renderField(stepType, fieldName, fieldSchema, value, path);
  });

  return `
    <div class="ds-panel" style="margin:0 0 12px 0;">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">${h(stepType)}</div>
          <div class="ds-panel__sub">${h(stepSchema?.title || "Step config")}</div>
        </div>
      </div>
      <div class="ds-row">${fields.join("")}</div>
    </div>
  `;
}

function renderPlansList(config) {
  const plans = config?.sleep_plans || {};
  const names = Object.keys(plans).sort();

  if (!names.length) {
    return `<div class="ds-mono-muted" style="padding:10px;">No plans found.</div>`;
  }

  return names.map((name) => {
    const p = plans[name] || {};
    const type = p.plan_type || "—";
    return `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head" style="margin-bottom:0;">
          <div>
            <div class="ds-panel__title">${h(name)}</div>
            <div class="ds-panel__sub">Type: ${h(type)}</div>
          </div>
          <div class="ds-row">
            <button class="ds-btn ds-btn--ghost" type="button" data-plan-action="edit" data-plan="${h(name)}">Edit</button>
            <button class="ds-btn ds-btn--danger" type="button" data-plan-action="delete" data-plan="${h(name)}">Delete</button>
          </div>
        </div>
      </div>
    `;
  }).join("");
}

async function ensurePlanCatalogLoaded() {
  const state = Store.getState();
  const cached = state.plansCatalog.supported || {};
  if (Object.keys(cached).length) return cached;

  const supported = await Api.getSupportedPlans();
  Store.setState({ plansCatalog: { ...state.plansCatalog, supported } });
  return supported;
}

async function ensurePlanSchemaLoaded(planType) {
  const state = Store.getState();
  const cached = state.plansCatalog.planSchemas?.[planType];
  if (cached) return cached;

  const schema = await Api.getPlanSchema(planType);
  const next = { ...(state.plansCatalog.planSchemas || {}), [planType]: schema };
  Store.setState({ plansCatalog: { ...state.plansCatalog, planSchemas: next } });
  return schema;
}

async function openEditor({ mode, planName, existingPlan }) {
  const host = qs("#ds-modalhost");
  if (!host) return;

  const supported = await ensurePlanCatalogLoaded();
  const supportedPlanTypes = Object.keys(supported || {}).sort();
  const initialPlanType = existingPlan?.plan_type || supportedPlanTypes[0];
  const initialSchema = await ensurePlanSchemaLoaded(initialPlanType);

  let editorState = {
    name: planName || "",
    plan_type: initialPlanType,
    step_configs: {},
  };

  for (const [stepType, stepSchema] of Object.entries(initialSchema || {})) {
    const existingStep = existingPlan?.step_configs?.[stepType];
    editorState.step_configs[stepType] = buildInitialStepValue(stepSchema, existingStep);
  }

  function renderEditor() {
    const currentSchema = Store.getState().plansCatalog.planSchemas?.[editorState.plan_type] || {};
    const stepEditors = Object.entries(currentSchema).map(([stepType, stepSchema]) => {
      return renderStepEditor(stepType, stepSchema, editorState.step_configs?.[stepType] || {});
    }).join("");

    host.innerHTML = `
      <div class="ds-modalbackdrop" data-backdrop="1"></div>
      <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Sleep Plan Editor">
        <div class="ds-modal__head">
          <div class="ds-modal__title">${mode === "edit" ? `Edit Plan: ${h(editorState.name)}` : "Create New Plan"}</div>
          <button class="ds-btn ds-btn--ghost" type="button" data-close="1">Close</button>
        </div>
        <div class="ds-modal__body">
          <div class="ds-row" style="margin-bottom:12px;justify-content:space-between;">
            <span class="ds-badge">${mode === "edit" ? "EDIT" : "NEW"}</span>
            <span class="ds-badge ds-badge--muted">Source of truth: api/v1/plans + api/v1/schemas/plans/{plan_type}</span>
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
            <div>
              <div class="ds-field" style="min-width:unset;">
                <div class="ds-label">Plan Name</div>
                <input class="ds-input" id="ds-plan-name" value="${h(editorState.name)}" placeholder="ex: dev" ${mode === "edit" ? "disabled" : ""} />
              </div>

              <div style="height:10px"></div>

              <div class="ds-field" style="min-width:unset;">
                <div class="ds-label">Plan Type</div>
                <select class="ds-select" id="ds-plan-type" ${mode === "edit" ? "disabled" : ""}>
                  ${supportedPlanTypes.map((pt) => `<option value="${h(pt)}" ${pt === editorState.plan_type ? "selected" : ""}>${h(pt)}</option>`).join("")}
                </select>
              </div>

              <div style="height:12px"></div>
              <div id="ds-steps-container">${stepEditors}</div>

              <div class="ds-row">
                <button class="ds-btn" type="button" id="ds-plan-save">Save</button>
                <button class="ds-btn ds-btn--ghost" type="button" id="ds-plan-cancel">Cancel</button>
              </div>
            </div>

            <div>
              <div class="ds-label">Preview</div>
              <pre class="ds-textarea" id="ds-plan-preview" style="min-height:320px;white-space:pre;overflow:auto;"></pre>
            </div>
          </div>
        </div>
      </div>
    `;
    host.style.pointerEvents = "auto";

    bindEditor();
    updatePreview();
  }

  function close() {
    host.innerHTML = "";
    host.style.pointerEvents = "none";
  }

  async function onPlanTypeChange() {
    const select = qs("#ds-plan-type");
    const nextType = select?.value;
    if (!nextType || nextType === editorState.plan_type) return;

    editorState.plan_type = nextType;
    const schema = await ensurePlanSchemaLoaded(nextType);
    editorState.step_configs = {};
    for (const [stepType, stepSchema] of Object.entries(schema || {})) {
      editorState.step_configs[stepType] = buildInitialStepValue(stepSchema, undefined);
    }
    renderEditor();
  }

  function updatePreview() {
    const preview = qs("#ds-plan-preview");
    if (!preview) return;
    const name = editorState.name || "(plan_name)";
    preview.textContent = JSON.stringify({
      sleep_plans: {
        [name]: {
          plan_type: editorState.plan_type,
          step_configs: editorState.step_configs,
        },
      },
    }, null, 2);
  }

  function bindEditor() {
    const nameInput = qs("#ds-plan-name");
    const typeSelect = qs("#ds-plan-type");
    const cancelBtn = qs("#ds-plan-cancel");
    const saveBtn = qs("#ds-plan-save");

    host.addEventListener("click", (e) => {
      const t = e.target;
      if (t?.dataset?.backdrop || t?.dataset?.close) close();
    }, { once: true });

    nameInput?.addEventListener("input", () => {
      editorState.name = nameInput.value.trim();
      updatePreview();
    });

    typeSelect?.addEventListener("change", onPlanTypeChange);

    qsa("[data-plan-path]").forEach((el) => {
      el.addEventListener("input", () => {
        const path = el.dataset.planPath;
        const [stepType, fieldName] = path.split(".");
        const planSchema = Store.getState().plansCatalog.planSchemas?.[editorState.plan_type] || {};
        const fieldSchema = planSchema?.[stepType]?.properties?.[fieldName];
        const raw = el.type === "checkbox" ? el.checked : el.value;
        const nextVal = serializeFieldValue(raw, fieldSchema);
        setDeep(editorState.step_configs, path, nextVal);
        updatePreview();
      });
      el.addEventListener("change", () => {
        const path = el.dataset.planPath;
        const [stepType, fieldName] = path.split(".");
        const planSchema = Store.getState().plansCatalog.planSchemas?.[editorState.plan_type] || {};
        const fieldSchema = planSchema?.[stepType]?.properties?.[fieldName];
        const raw = el.type === "checkbox" ? el.checked : el.value;
        const nextVal = serializeFieldValue(raw, fieldSchema);
        setDeep(editorState.step_configs, path, nextVal);
        updatePreview();
      });
    });

    cancelBtn?.addEventListener("click", close);

    saveBtn?.addEventListener("click", async () => {
      try {
        const s = Store.getState();
        if (!editorState.name) throw new Error("Plan name required");

        const cfg = { ...(s.sleepPlans.config || { sleep_plans: {} }) };
        cfg.sleep_plans = { ...(cfg.sleep_plans || {}) };

        cfg.sleep_plans[editorState.name] = {
          plan_type: editorState.plan_type,
          step_configs: editorState.step_configs,
        };

        const saved = await Api.putAccountConfig(s.account.id, cfg);

        Store.setState({
          sleepPlans: {
            config: saved || cfg,
            names: getPlanNames(saved || cfg),
          },
        });

        toast("Sleep Plans", "Saved.");
        close();
        await SleepPlansPage();
      } catch (e) {
        toast("Sleep Plans", e.message || "Save failed");
      }
    });
  }

  renderEditor();
}

export async function SleepPlansPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Sleep Plans";

  page.innerHTML = renderPanel({
    title: "Sleep Plans",
    sub: "Define, edit and delete sleep plan configurations stored in account config.",
    actionsHtml: `<button class="ds-btn ds-btn--wake" id="ds-plan-create" type="button">Create New Plan</button>`,
    bodyHtml: `
      <div class="ds-mono-muted" id="ds-plan-status">—</div>
      <div style="height:10px"></div>
      <div id="ds-plans-container"></div>
    `,
  });

  const status = qs("#ds-plan-status");
  const container = qs("#ds-plans-container");
  const btnCreate = qs("#ds-plan-create");

  if (!requireAuthAndAccount()) {
    status.textContent = "Not ready (missing auth/account).";
    return;
  }

  async function loadConfig() {
    const s = Store.getState();
    status.textContent = "Fetching configuration…";
    try {
      await ensurePlanCatalogLoaded();
      const cfg = await Api.getAccountConfig(s.account.id);
      const names = getPlanNames(cfg);
      Store.setState({ sleepPlans: { config: cfg, names } });
      status.textContent = `OK — ${names.length} plan(s).`;
      container.innerHTML = renderPlansList(cfg);
      bindListActions();
    } catch (e) {
      status.textContent = "Error.";
      toast("Sleep Plans", e.message || "Load failed");
      container.innerHTML = `<div class="ds-mono-muted" style="padding:10px;">Failed to load.</div>`;
    }
  }

  function bindListActions() {
    qsa('[data-plan-action="edit"]').forEach((b) => {
      b.addEventListener("click", async () => {
        const name = b.dataset.plan;
        const cfg = Store.getState().sleepPlans.config;
        const plan = (cfg.sleep_plans || {})[name];
        await openEditor({ mode: "edit", planName: name, existingPlan: plan });
      });
    });

    qsa('[data-plan-action="delete"]').forEach((b) => {
      b.addEventListener("click", async () => {
        const name = b.dataset.plan;
        const ok = await confirmModal({
          title: "Delete Sleep Plan",
          body: `<div class="ds-mono-muted">Delete plan <b>${h(name)}</b> ?</div>`,
          confirmText: "Delete",
          cancelText: "Cancel",
        });
        if (!ok) return;

        try {
          const s = Store.getState();
          const cfg = { ...(s.sleepPlans.config || { sleep_plans: {} }) };
          cfg.sleep_plans = { ...(cfg.sleep_plans || {}) };
          delete cfg.sleep_plans[name];

          const saved = await Api.putAccountConfig(s.account.id, cfg);
          Store.setState({
            sleepPlans: {
              config: saved || cfg,
              names: getPlanNames(saved || cfg),
            },
          });
          toast("Sleep Plans", "Deleted.");
          await loadConfig();
        } catch (e) {
          toast("Sleep Plans", e.message || "Delete failed");
        }
      });
    });
  }

  btnCreate?.addEventListener("click", async () => {
    await openEditor({ mode: "new", planName: "", existingPlan: null });
  });

  await loadConfig();
}
