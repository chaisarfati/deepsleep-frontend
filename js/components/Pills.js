import { escapeHtml as h } from "../utils/dom.js";

export function renderStatePill(state, lockedUntil) {
  const s = (state || "—").toUpperCase();
  if (lockedUntil) return `<span class="ds-pill ds-pill--locked">LOCKED</span>`;
  if (s === "RUNNING") return `<span class="ds-pill ds-pill--running">RUNNING</span>`;
  if (s === "SLEEPING") return `<span class="ds-pill ds-pill--sleeping">SLEEPING</span>`;
  return `<span class="ds-pill">${h(s)}</span>`;
}
