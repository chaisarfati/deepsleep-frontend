import { escapeHtml as h } from "../utils/dom.js";

function normalizeState(value) {
  return String(value || "").trim().toUpperCase();
}

function stateMeta(state, lockedUntil) {
  if (lockedUntil && new Date(lockedUntil).getTime() > Date.now()) {
    return {
      cls: "ds-badge--warning",
      label: "LOCKED",
    };
  }

  if (state === "RUNNING") {
    return {
      cls: "ds-badge--success",
      label: "RUNNING",
    };
  }

  if (state === "SLEEPING") {
    return {
      cls: "ds-badge--accent",
      label: "SLEEPING",
    };
  }

  if (state === "ERROR" || state === "FAILED") {
    return {
      cls: "ds-badge--danger",
      label: state || "ERROR",
    };
  }

  return {
    cls: "ds-badge--accent",
    label: state || "UNKNOWN",
  };
}

export function renderStatePill(state, lockedUntil = null) {
  const normalized = normalizeState(state);
  const meta = stateMeta(normalized, lockedUntil);
  return `<span class="ds-badge ${meta.cls}">${h(meta.label)}</span>`;
}
