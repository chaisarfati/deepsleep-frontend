import { qs } from "../utils/dom.js";
import { renderStatePill } from "./Pills.js";
import { fmtTime } from "../utils/time.js";
import { Store } from "../store.js";

function patchCell(tr, col, value, lockedUntil) {
  const td = tr.querySelector(`td[data-col="${col}"]`);
  if (!td) return;
  if (col === "observed") {
    td.innerHTML = renderStatePill(value, lockedUntil);
    return;
  }
  td.textContent = String(value ?? "—");
}

export function patchActiveRow(key, newRow) {
  const tr = qs(`tr[data-key="${key.replaceAll('"','\\"')}"]`);
  if (!tr) return;

  const old = Store.getState().active.rowsByKey.get(key) || {};
  const changed =
    old.observed_state !== newRow.observed_state ||
    old.desired_state !== newRow.desired_state ||
    String(old.locked_until || "") !== String(newRow.locked_until || "") ||
    String(old.updated_at || "") !== String(newRow.updated_at || "") ||
    String(old.last_action || "") !== String(newRow.last_action || "") ||
    String(old.last_action_at || "") !== String(newRow.last_action_at || "");

  if (!changed) return;

  Store.getState().active.rowsByKey.set(key, newRow);

  patchCell(tr, "observed", newRow.observed_state, newRow.locked_until);
  patchCell(tr, "desired", newRow.desired_state, null);

  const lastText = newRow.last_action_at
    ? `${newRow.last_action || "—"} @ ${fmtTime(newRow.last_action_at)}`
    : "—";
  patchCell(tr, "last", lastText, null);

  patchCell(tr, "updated", newRow.updated_at ? fmtTime(newRow.updated_at) : "—", null);
}
