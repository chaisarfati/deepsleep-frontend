import { escapeHtml as h } from "../utils/dom.js";
import { renderStatePill } from "./Pills.js";
import { fmtTime } from "../utils/time.js";

export function renderInventoryRow(r, checked) {
  const labels = Object.entries(r.labels || {}).slice(0, 6).map(([k, v]) => `${k}:${v}`).join(", ");
  const reg = r.registered ? `<span class="ds-badge ds-badge--reg">REGISTERED</span>` : `<span class="ds-badge">NO</span>`;
  const observed = r.observed_state ? renderStatePill(r.observed_state) : `<span class="ds-mono-muted">—</span>`;
  const hay = `${r.resource_type} ${r.resource_name} ${r.region} ${labels}`;

  return `
    <tr data-key="${h(r.key)}" data-hay="${h(hay)}">
      <td><input type="checkbox" class="ds-inv-check" data-key="${h(r.key)}" ${checked ? "checked" : ""} /></td>
      <td>${h(r.resource_type)}</td>
      <td>${h(r.resource_name)}</td>
      <td>${h(r.region)}</td>
      <td>${reg}</td>
      <td>${observed}</td>
      <td class="ds-mono-muted">${h(labels || "—")}</td>
    </tr>
  `;
}

export function renderActiveRow(r) {
  const observed = renderStatePill(r.observed_state, r.locked_until);
  const desired = r.desired_state || "—";
  const last = r.last_action_at ? `${r.last_action || "—"} @ ${fmtTime(r.last_action_at)}` : "—";
  const updated = r.updated_at ? fmtTime(r.updated_at) : "—";
  const hay = `${r.resource_type} ${r.resource_name} ${r.region}`;

  const locked = !!(r.locked_until && new Date(r.locked_until).getTime() > Date.now());
  const sleepDisabled = locked || String(r.observed_state || "").toUpperCase() === "SLEEPING";
  const wakeDisabled = locked || String(r.observed_state || "").toUpperCase() === "RUNNING";
  const unregDisabled = locked; // backend may also refuse if sleeping; we let backend validate

  return `
    <tr data-key="${h(r.key)}" data-hay="${h(hay)}">
      <td>${h(r.resource_type)}</td>
      <td>${h(r.resource_name)}</td>
      <td>${h(r.region)}</td>
      <td data-col="observed">${observed}</td>
      <td data-col="desired">${h(desired)}</td>
      <td data-col="last">${h(last)}</td>
      <td data-col="updated">${h(updated)}</td>
      <td>
        <div class="ds-row">
          <button class="ds-btn ds-btn--sleep" type="button" data-action="sleep" data-key="${h(r.key)}" ${sleepDisabled ? "disabled" : ""}>Sleep</button>
          <button class="ds-btn ds-btn--wake" type="button" data-action="wake" data-key="${h(r.key)}" ${wakeDisabled ? "disabled" : ""}>Wake</button>
          <button class="ds-btn ds-btn--danger" type="button" data-action="unregister" data-key="${h(r.key)}" ${unregDisabled ? "disabled" : ""}>Unregister</button>
        </div>
      </td>
    </tr>
  `;
}
