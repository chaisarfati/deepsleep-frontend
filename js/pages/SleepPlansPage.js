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
    toast("Setup", "Missing internal account_id. Backend should provide it in token claims.");
    // Keep user on page; but without account id we cannot call endpoints.
    return false;
  }
  return true;
}

function getPlanNames(config) {
  const plans = (config?.sleep_plans || {});
  return Object.keys(plans).sort();
}

function buildEmptyEKSPlan() {
  return {
    plan_type: "EKS_CLUSTER_SLEEP",
    step_configs: {
      K8S_WORKLOAD_SCALE: {
        sleep_replicas: 0,
        selector: { exclude_namespaces: ["kube-system", "kube-public"] },
      },
      EKS_NODEGROUP_SCALE: {
        sleep_min: 0,
        sleep_desired: 0,
        sleep_max: 1,
      },
    },
  };
}

function buildEmptyRDSPlan() {
  return {
    plan_type: "RDS_SLEEP",
    step_configs: {
      RDS_INSTANCE_POWER: {
        create_final_snapshot: false,
      },
    },
  };
}

function readCsvNamespaces(val) {
  return String(val || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function safeInt(v, fallback) {
  const n = Number.parseInt(String(v ?? ""), 10);
  return Number.isFinite(n) ? n : fallback;
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

function renderEditorBody(mode, planName, planType, plan) {
  // Normalize plan for form fields
  const p = plan || (planType === "RDS_SLEEP" ? buildEmptyRDSPlan() : buildEmptyEKSPlan());
  const type = planType || p.plan_type || "EKS_CLUSTER_SLEEP";

  const isEdit = mode === "edit";

  const eksK8s = (p.step_configs?.K8S_WORKLOAD_SCALE || {});
  const eksNg = (p.step_configs?.EKS_NODEGROUP_SCALE || {});
  const rdsPower = (p.step_configs?.RDS_INSTANCE_POWER || {});

  const excludeNs = (eksK8s.selector?.exclude_namespaces || []).join(",");

  return `
    <div class="ds-row" style="margin-bottom:12px;justify-content:space-between;">
      <span class="ds-badge">${isEdit ? "EDIT" : "NEW"}</span>
      <span class="ds-badge ds-badge--muted">Hard borders • Strict validation happens server-side</span>
    </div>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
      <div>
        <div class="ds-field" style="min-width:unset;">
          <div class="ds-label">Plan Name</div>
          <input class="ds-input" id="ds-plan-name" value="${h(planName || "")}" placeholder="ex: dev" ${isEdit ? "disabled" : ""} />
        </div>

        <div style="height:10px"></div>

        <div class="ds-field" style="min-width:unset;">
          <div class="ds-label">Plan Type</div>
          <select class="ds-select" id="ds-plan-type" ${isEdit ? "disabled" : ""}>
            <option value="EKS_CLUSTER_SLEEP" ${type === "EKS_CLUSTER_SLEEP" ? "selected" : ""}>EKS_CLUSTER_SLEEP</option>
            <option value="RDS_SLEEP" ${type === "RDS_SLEEP" ? "selected" : ""}>RDS_SLEEP</option>
          </select>
        </div>

        <div style="height:12px"></div>

        <div id="ds-plan-form-eks" ${type === "EKS_CLUSTER_SLEEP" ? "" : "hidden"}>
          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">K8S Workloads</div>
                <div class="ds-panel__sub">K8S_WORKLOAD_SCALE</div>
              </div>
            </div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Sleep Replicas</div>
              <input class="ds-input" id="ds-sleep-replicas" inputmode="numeric" value="${h(String(eksK8s.sleep_replicas ?? 0))}" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field" style="min-width:unset;">
              <div class="ds-label">Exclude Namespaces (CSV)</div>
              <input class="ds-input" id="ds-exclude-namespaces" value="${h(excludeNs)}" placeholder="kube-system,kube-public" />
            </div>
          </div>

          <div style="height:12px"></div>

          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">EKS Nodegroups</div>
                <div class="ds-panel__sub">EKS_NODEGROUP_SCALE (must satisfy min ≤ desired ≤ max, and max ≥ 1)</div>
              </div>
            </div>

            <div class="ds-row">
              <div class="ds-field" style="min-width:140px;">
                <div class="ds-label">Min</div>
                <input class="ds-input" id="ds-sleep-min" inputmode="numeric" value="${h(String(eksNg.sleep_min ?? 0))}" />
              </div>
              <div class="ds-field" style="min-width:140px;">
                <div class="ds-label">Desired</div>
                <input class="ds-input" id="ds-sleep-desired" inputmode="numeric" value="${h(String(eksNg.sleep_desired ?? 0))}" />
              </div>
              <div class="ds-field" style="min-width:140px;">
                <div class="ds-label">Max</div>
                <input class="ds-input" id="ds-sleep-max" inputmode="numeric" value="${h(String(eksNg.sleep_max ?? 1))}" />
              </div>
            </div>
          </div>
        </div>

        <div id="ds-plan-form-rds" ${type === "RDS_SLEEP" ? "" : "hidden"}>
          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">RDS Power</div>
                <div class="ds-panel__sub">RDS_INSTANCE_POWER</div>
              </div>
            </div>

            <div class="ds-row">
              <label class="ds-badge" style="gap:10px;">
                <input type="checkbox" id="ds-rds-final-snap" ${rdsPower.create_final_snapshot ? "checked" : ""} />
                <span>Create final snapshot on sleep</span>
              </label>
            </div>
          </div>
        </div>

        <div style="height:12px"></div>

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
  `;
}

function buildPlanFromEditor() {
  const name = (qs("#ds-plan-name")?.value || "").trim();
  const type = (qs("#ds-plan-type")?.value || "EKS_CLUSTER_SLEEP").trim();

  if (!name) throw new Error("Plan name required");

  if (type === "RDS_SLEEP") {
    const createFinal = !!qs("#ds-rds-final-snap")?.checked;
    return {
      name,
      plan: {
        plan_type: "RDS_SLEEP",
        step_configs: {
          RDS_INSTANCE_POWER: { create_final_snapshot: createFinal },
        },
      },
    };
  }

  // EKS
  const sleep_replicas = safeInt(qs("#ds-sleep-replicas")?.value, 0);
  const exclude_namespaces = readCsvNamespaces(qs("#ds-exclude-namespaces")?.value);
  const sleep_min = safeInt(qs("#ds-sleep-min")?.value, 0);
  const sleep_desired = safeInt(qs("#ds-sleep-desired")?.value, 0);
  const sleep_max = safeInt(qs("#ds-sleep-max")?.value, 1);

  return {
    name,
    plan: {
      plan_type: "EKS_CLUSTER_SLEEP",
      step_configs: {
        K8S_WORKLOAD_SCALE: {
          sleep_replicas,
          selector: { exclude_namespaces },
        },
        EKS_NODEGROUP_SCALE: {
          sleep_min,
          sleep_desired,
          sleep_max,
        },
      },
    },
  };
}

function updatePreview(config) {
  const preview = qs("#ds-plan-preview");
  if (!preview) return;

  try {
    const { name, plan } = buildPlanFromEditor();
    const tmp = { sleep_plans: { ...(config.sleep_plans || {}), [name]: plan } };
    preview.textContent = JSON.stringify(tmp, null, 2);
  } catch {
    preview.textContent = JSON.stringify(config, null, 2);
  }
}

async function openEditor({ mode, planName, existingPlan }) {
  const host = qs("#ds-modalhost");
  if (!host) return;

  const type = existingPlan?.plan_type || "EKS_CLUSTER_SLEEP";

  host.innerHTML = `
    <div class="ds-modalbackdrop" data-backdrop="1"></div>
    <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Sleep Plan Editor">
      <div class="ds-modal__head">
        <div class="ds-modal__title">${mode === "edit" ? `Edit Plan: ${h(planName)}` : "Create New Plan"}</div>
        <button class="ds-btn ds-btn--ghost" type="button" data-close="1">Close</button>
      </div>
      <div class="ds-modal__body">
        ${renderEditorBody(mode, planName, type, existingPlan)}
      </div>
    </div>
  `;
  host.style.pointerEvents = "auto";

  const close = () => {
    host.innerHTML = "";
    host.style.pointerEvents = "none";
  };

  host.addEventListener("click", (e) => {
    const t = e.target;
    if (t?.dataset?.backdrop || t?.dataset?.close) close();
  }, { once: true });

  const planTypeSel = qs("#ds-plan-type");
  const eksForm = qs("#ds-plan-form-eks");
  const rdsForm = qs("#ds-plan-form-rds");
  const cancelBtn = qs("#ds-plan-cancel");
  const saveBtn = qs("#ds-plan-save");

  const config = Store.getState().sleepPlans.config;

  function toggleType() {
    const v = planTypeSel.value;
    if (eksForm) eksForm.hidden = v !== "EKS_CLUSTER_SLEEP";
    if (rdsForm) rdsForm.hidden = v !== "RDS_SLEEP";
    updatePreview(config);
  }

  planTypeSel?.addEventListener("change", toggleType);

  // bind preview updates
  [
    "#ds-plan-name",
    "#ds-sleep-replicas",
    "#ds-exclude-namespaces",
    "#ds-sleep-min",
    "#ds-sleep-desired",
    "#ds-sleep-max",
    "#ds-rds-final-snap",
  ].forEach((sel) => {
    const el = qs(sel);
    if (!el) return;
    el.addEventListener("input", () => updatePreview(config));
    el.addEventListener("change", () => updatePreview(config));
  });

  cancelBtn?.addEventListener("click", close);

  saveBtn?.addEventListener("click", async () => {
    try {
      const s = Store.getState();
      const accountId = s.account.id;
      const cfg = { ...(s.sleepPlans.config || { sleep_plans: {} }) };
      cfg.sleep_plans = { ...(cfg.sleep_plans || {}) };

      const { name, plan } = buildPlanFromEditor();

      // write back plan
      cfg.sleep_plans[name] = plan;

      // PUT whole config
      const saved = await Api.putAccountConfig(accountId, cfg);

      Store.setState({
        sleepPlans: {
          config: saved || cfg,
          names: getPlanNames(saved || cfg),
        },
      });

      // also refresh plan dropdowns used elsewhere
      toast("Sleep Plans", "Saved.");
      close();
      // rerender page list
      await SleepPlansPage();
    } catch (e) {
      toast("Sleep Plans", e.message || "Save failed");
    }
  });

  toggleType();
  updatePreview(config);
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
