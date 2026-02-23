import { qs, qsa } from "../utils/dom.js";

export function applyTableFilter(tableSelector, query) {
  const q = (query || "").trim().toLowerCase();
  const tbody = qs(`${tableSelector} tbody`);
  if (!tbody) return;

  qsa("tr", tbody).forEach((tr) => {
    const hay = (tr.getAttribute("data-hay") || "").toLowerCase();
    tr.style.display = (!q || hay.includes(q)) ? "" : "none";
  });
}
