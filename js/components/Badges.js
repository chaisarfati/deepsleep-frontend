import { escapeHtml as h } from "../utils/dom.js";

export function renderBadge(text, variant = "") {
  const cls = variant ? `ds-badge ds-badge--${variant}` : "ds-badge";
  return `<span class="${cls}">${h(text)}</span>`;
}
