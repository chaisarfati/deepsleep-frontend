import { qs, escapeHtml } from "./dom.js";

export function toast(title, msg) {
  const stack = qs("#ds-toaststack");
  if (!stack) return;

  const t = document.createElement("div");
  t.className = "ds-toast";
  t.innerHTML = `<div class="ds-toast__title"></div><div class="ds-toast__msg"></div>`;
  t.querySelector(".ds-toast__title").textContent = title;
  t.querySelector(".ds-toast__msg").textContent = msg;

  stack.appendChild(t);
  setTimeout(() => t.remove(), 4200);
}

export function confirmModal({ title, body, confirmText = "Confirm", cancelText = "Cancel" }) {
  const host = qs("#ds-modalhost");
  if (!host) return Promise.resolve(false);

  return new Promise((resolve) => {
    host.innerHTML = `
      <div class="ds-modalbackdrop" data-backdrop="1"></div>
      <div class="ds-modal" role="dialog" aria-modal="true" aria-label="${escapeHtml(title)}">
        <div class="ds-modal__head">
          <div class="ds-modal__title">${escapeHtml(title)}</div>
          <button class="ds-btn ds-btn--ghost" type="button" data-close="1">Close</button>
        </div>
        <div class="ds-modal__body">${body}</div>
        <div class="ds-modal__foot">
          <button class="ds-btn ds-btn--ghost" type="button" data-cancel="1">${escapeHtml(cancelText)}</button>
          <button class="ds-btn" type="button" data-confirm="1">${escapeHtml(confirmText)}</button>
        </div>
      </div>
    `;
    host.style.pointerEvents = "auto";

    const cleanup = (val) => {
      host.innerHTML = "";
      host.style.pointerEvents = "none";
      resolve(val);
    };

    host.addEventListener("click", (e) => {
      const t = e.target;
      if (t && t.dataset && (t.dataset.backdrop || t.dataset.close || t.dataset.cancel)) cleanup(false);
      if (t && t.dataset && t.dataset.confirm) cleanup(true);
    }, { once: true });
  });
}
