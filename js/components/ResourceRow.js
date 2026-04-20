import { escapeHtml as h } from "../utils/dom.js";
import { renderStatePill } from "./Pills.js";

function resourceChipClass(type) {
  if (type === "EKS_CLUSTER")  return "ds-resource-chip ds-resource-chip--eks";
  if (type === "RDS_INSTANCE") return "ds-resource-chip ds-resource-chip--rds";
  if (type === "EC2_INSTANCE") return "ds-resource-chip ds-resource-chip--ec2";
  return "ds-resource-chip";
}

function resourceTypeShort(type) {
  if (type === "EKS_CLUSTER")  return "EKS";
  if (type === "RDS_INSTANCE") return "RDS";
  if (type === "EC2_INSTANCE") return "EC2";
  return type;
}

function stateToStatus(state) {
  if (!state) return `<span class="ds-mono" style="color:var(--fg-faint)">—</span>`;
  const s = String(state).toLowerCase();
  if (s === "running" || s === "available" || s === "active") {
    return `<span class="ds-status ds-status--running"><span class="ds-status__dot"></span>${h(state)}</span>`;
  }
  if (s === "stopped" || s === "sleeping" || s === "asleep") {
    return `<span class="ds-status ds-status--sleeping"><span class="ds-status__dot"></span>${h(state)}</span>`;
  }
  if (s.includes("error") || s.includes("fail") || s === "dropped") {
    return `<span class="ds-status ds-status--stopped"><span class="ds-status__dot"></span>${h(state)}</span>`;
  }
  return `<span class="ds-status"><span class="ds-status__dot"></span>${h(state)}</span>`;
}

function renderLabels(labels = {}) {
  const entries = Object.entries(labels || {}).slice(0, 3);
  if (!entries.length) return `<span class="ds-mono" style="color:var(--fg-faint)">—</span>`;
  return entries.map(([k, v]) =>
    `<span class="ds-chip" style="margin:2px 2px 2px 0;">${h(k)}<span style="color:var(--fg-faint);margin:0 2px">=</span>${h(v)}</span>`
  ).join("");
}

/** Inventory table row */
export function renderInventoryRow(resource, isSelected) {
  const { key, resource_type, resource_name, region, registered, observed_state, labels } = resource;
  return `
    <tr data-key="${h(key)}">
      <td style="width:42px;">
        <input
          type="checkbox"
          class="ds-inv-check"
          data-key="${h(key)}"
          ${isSelected ? "checked" : ""}
          aria-label="Select ${h(resource_name)}"
          style="accent-color:var(--accent);width:15px;height:15px;cursor:pointer;"
        />
      </td>
      <td><span class="${resourceChipClass(resource_type)}">${resourceTypeShort(resource_type)}</span></td>
      <td><span class="ds-mono" style="font-size:12px;color:var(--fg-strong);">${h(resource_name)}</span></td>
      <td><span class="ds-mono" style="font-size:12px;">${h(region)}</span></td>
      <td>
        ${registered
          ? `<span class="ds-badge ds-badge--success"><span class="ds-badge-dot"></span>Registered</span>`
          : `<span class="ds-badge"><span class="ds-badge-dot" style="background:var(--stone-300)"></span>Unregistered</span>`
        }
      </td>
      <td>${stateToStatus(observed_state)}</td>
      <td>${renderLabels(labels)}</td>
    </tr>
  `;
}

/** Active resources table row — includes Unregister action */
export function renderActiveRow(row, options = {}) {
  const {
    key, resource_type, resource_name, region,
    observed_state, desired_state, locked_until,
  } = row;

  const { cost = null, savings = null } = options;

  const isLocked = locked_until && new Date(locked_until) > new Date();
  const lockBadge = isLocked
    ? `<span class="ds-badge ds-badge--warning" style="margin-left:6px;">
        <svg width="9" height="9" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8">
          <rect x="2" y="5" width="8" height="6" rx="1"/><path d="M4 5V3.5a2 2 0 1 1 4 0V5"/>
        </svg>Locked</span>`
    : "";

  const state = (observed_state || "").toUpperCase();
  const isDropped   = state === "DROPPED";
  const isSleeping  = state === "SLEEPING" || state === "STOPPED" || state === "ASLEEP";

  return `
    <tr data-key="${h(key)}">
      <td><span class="${resourceChipClass(resource_type)}">${resourceTypeShort(resource_type)}</span></td>
      <td>
        <span class="ds-mono" style="font-size:12px;color:var(--fg-strong);">${h(resource_name)}</span>
        ${lockBadge}
      </td>
      <td><span class="ds-mono" style="font-size:12px;">${h(region)}</span></td>
      <td data-col="observed">${renderStatePill(observed_state, locked_until)}</td>
      <td data-col="desired">${desired_state ? renderStatePill(desired_state, null) : `<span class="ds-mono" style="color:var(--fg-faint)">—</span>`}</td>
      <td data-col="compute-cost">
        <span class="ds-mono" style="font-size:12px;">${cost !== null ? `$${Number(cost).toFixed(4)}/hr` : "—"}</span>
      </td>
      <td data-col="compute-savings">
        <span class="ds-mono" style="font-size:12px;color:var(--success);">${savings !== null ? `$${Number(savings).toFixed(4)}/hr` : "—"}</span>
      </td>
      <td>
        <div class="ds-action-group">
          ${!isDropped ? `
            <button
              class="ds-btn ds-btn--sm ds-btn--primary"
              data-action="wake"
              data-resource-type="${h(resource_type)}"
              data-resource-name="${h(resource_name)}"
              data-region="${h(region)}"
              ${isLocked || !isSleeping ? "disabled" : ""}
              title="${!isSleeping ? "Resource is not sleeping" : "Wake this resource"}"
            >
              <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 2l7 4-7 4V2z"/></svg>
              Wake
            </button>
            <button
              class="ds-btn ds-btn--sm"
              data-action="sleep"
              data-resource-type="${h(resource_type)}"
              data-resource-name="${h(resource_name)}"
              data-region="${h(region)}"
              ${isLocked || isSleeping ? "disabled" : ""}
              title="${isSleeping ? "Resource is already sleeping" : "Put to sleep"}"
            >
              <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M10 7.5A5 5 0 0 1 4.5 2 5 5 0 1 0 10 7.5z"/></svg>
              Sleep
            </button>
          ` : ""}
          <!-- Unregister always available -->
          <button
            class="ds-btn ds-btn--sm ds-btn--danger"
            data-action="unregister"
            data-resource-type="${h(resource_type)}"
            data-resource-name="${h(resource_name)}"
            data-region="${h(region)}"
            ${isLocked ? "disabled" : ""}
            title="Remove from DeepSleep management"
          >
            <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8">
              <path d="M2 6h8"/>
            </svg>
            Unregister
          </button>
        </div>
      </td>
    </tr>
  `;
}
