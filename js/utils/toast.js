import { qs, escapeHtml } from "./dom.js";

export function toast(title, msg) {
  const stack = qs("#ds-toaststack");
  if (!stack) return;

  const t = document.createElement("div");
  t.className = "ds-toast";
  t.innerHTML = `
    <div class="ds-toast__title"></div>
    <div class="ds-toast__msg"></div>
  `;
  t.querySelector(".ds-toast__title").textContent = title;
  t.querySelector(".ds-toast__msg").textContent = msg;

  stack.appendChild(t);
  setTimeout(() => {
    t.style.transition = "opacity 300ms ease, transform 300ms ease";
    t.style.opacity = "0";
    t.style.transform = "translateY(6px)";
    setTimeout(() => t.remove(), 300);
  }, 4000);
}

/**
 * Confirmation modal.
 *
 * Bug fixed: removed { once: true } on the host listener.
 * The old approach consumed the listener on the first click anywhere in the
 * host (including pricing DOM patches that bubble up), making the modal
 * unresponsive on subsequent clicks.
 * Now we use an explicit named handler that is removed only when the modal
 * resolves, regardless of what caused the removal.
 */
export function confirmModal({ title, body, confirmText = "Confirm", cancelText = "Cancel", danger = false }) {
  const host = qs("#ds-modalhost");
  if (!host) return Promise.resolve(false);

  return new Promise((resolve) => {
    host.innerHTML = `
      <div class="ds-modalbackdrop" data-backdrop="1"></div>
      <div class="ds-modal" role="dialog" aria-modal="true" aria-labelledby="ds-modal-title">
        <div class="ds-modal__head">
          <div class="ds-modal__title" id="ds-modal-title">${escapeHtml(title)}</div>
          <button class="ds-btn ds-btn--ghost ds-btn--icon" type="button" data-close="1" aria-label="Close">
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M1 1l12 12M13 1L1 13"/>
            </svg>
          </button>
        </div>
        <div class="ds-modal__body">${body}</div>
        <div class="ds-modal__foot">
          <button class="ds-btn ds-btn--ghost" type="button" data-cancel="1">${escapeHtml(cancelText)}</button>
          <button class="ds-btn ${danger ? "ds-btn--danger" : "ds-btn--primary"}" type="button" data-confirm="1">
            ${escapeHtml(confirmText)}
          </button>
        </div>
      </div>
    `;
    host.style.pointerEvents = "auto";

    function cleanup(val) {
      // Remove listener BEFORE clearing innerHTML to avoid stale references
      host.removeEventListener("click", handler);
      host.innerHTML = "";
      host.style.pointerEvents = "none";
      resolve(val);
    }

    function handler(e) {
      // Walk up to find a data-* button — handles clicks on SVG children etc.
      const btn = e.target?.closest("[data-backdrop],[data-close],[data-cancel],[data-confirm]");
      if (!btn) return;
      if (btn.dataset.backdrop || btn.dataset.close || btn.dataset.cancel) cleanup(false);
      else if (btn.dataset.confirm) cleanup(true);
    }

    host.addEventListener("click", handler);
  });
}
