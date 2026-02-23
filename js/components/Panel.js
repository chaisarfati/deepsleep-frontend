import { escapeHtml as h } from "../utils/dom.js";

export function renderPanel({ title, sub, actionsHtml = "", bodyHtml = "" }) {
  return `
    <article class="ds-panel">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">${h(title)}</div>
          ${sub ? `<div class="ds-panel__sub">${h(sub)}</div>` : ""}
        </div>
        ${actionsHtml ? `<div class="ds-row">${actionsHtml}</div>` : ""}
      </div>
      ${bodyHtml}
    </article>
  `;
}
