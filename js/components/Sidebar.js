import { Store } from "../store.js";

function isAdmin() {
  return (Store.getState().auth.roles || []).includes("ADMIN");
}

export function renderSidebar() {
  const admin = isAdmin();

  return `
    <div class="ds-rail__brand">
      <div class="ds-brand__mark" aria-hidden="true">
        <svg width="20" height="20" viewBox="0 0 20 20" role="img" aria-label="Logo">
          <rect x="2" y="2" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"></rect>
          <path d="M6 10h8" stroke="currentColor" stroke-width="2"></path>
        </svg>
      </div>
      <div class="ds-brand__text">
        <div class="ds-brand__name">DeepSleep</div>
        <div class="ds-brand__tag">AWS FinOps • EKS/RDS</div>
      </div>
    </div>

    <nav class="ds-rail__nav">
      <a class="ds-navlink" href="#/discovery" data-route="discovery">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M2 7h14M2 11h14M4 3h10M4 15h10" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Discovery</span>
      </a>

      <a class="ds-navlink" href="#/active" data-route="active">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M4 14V4h10v10H4Z" fill="none" stroke="currentColor" stroke-width="1.7"/>
            <path d="M6 6h6M6 9h6M6 12h4" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Active Resources</span>
      </a>

      <a class="ds-navlink" href="#/policies" data-route="policies">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M3 4h12v10H3V4Z" fill="none" stroke="currentColor" stroke-width="1.7"/>
            <path d="M5 7h8M5 10h6" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Time Policies</span>
      </a>

      <a class="ds-navlink" href="#/settings" data-route="settings">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M9 11.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z" fill="none" stroke="currentColor" stroke-width="1.7"/>
            <path d="M3 9l1.6-.6.2-1.8L3.7 5.3 5.3 3.7l1.3 1.1 1.8-.2L9 3l.6 1.6 1.8.2 1.3-1.1 1.6 1.6-1.1 1.3.2 1.8L15 9l-1.6.6-.2 1.8 1.1 1.3-1.6 1.6-1.3-1.1-1.8.2L9 15l-.6-1.6-1.8-.2-1.3 1.1-1.6-1.6 1.1-1.3-.2-1.8L3 9Z" fill="none" stroke="currentColor" stroke-width="1.3"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Sleep Plans</span>
      </a>

      <a class="ds-navlink" href="#/savings" data-route="savings">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M3 13h12M5 11V6M9 11V4M13 11V8" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Savings</span>
      </a>

      <a class="ds-navlink" href="#/history" data-route="history">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <path d="M9 3v6l4 2" fill="none" stroke="currentColor" stroke-width="1.7"/>
            <circle cx="9" cy="9" r="6" fill="none" stroke="currentColor" stroke-width="1.7"/>
          </svg>
        </span>
        <span class="ds-navlink__label">History</span>
      </a>

      ${admin ? `
      <a class="ds-navlink" href="#/users" data-route="users">
        <span class="ds-navlink__icon" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 18 18">
            <circle cx="6" cy="7" r="2.2" fill="none" stroke="currentColor" stroke-width="1.5"/>
            <circle cx="12" cy="7" r="2.2" fill="none" stroke="currentColor" stroke-width="1.5"/>
            <path d="M2.8 14c.8-1.8 2.2-2.8 4.2-2.8s3.4 1 4.2 2.8" fill="none" stroke="currentColor" stroke-width="1.5"/>
            <path d="M8.8 14c.7-1.5 1.8-2.3 3.2-2.3 1.4 0 2.5.8 3.2 2.3" fill="none" stroke="currentColor" stroke-width="1.5"/>
          </svg>
        </span>
        <span class="ds-navlink__label">Manage Users</span>
      </a>
      ` : ""}
    </nav>

    <div class="ds-rail__foot">
      <div class="ds-foot__hint">
        <span class="ds-hint__label">Polling:</span>
        <span class="ds-hint__value" id="ds-polling-indicator">10s</span>
      </div>
      <div class="ds-foot__hint">
        <span class="ds-hint__label">API:</span>
        <span class="ds-hint__value" id="ds-api-indicator">same-origin</span>
      </div>
    </div>
  `;
}

export function setActiveNav(routeName) {
  document.querySelectorAll(".ds-navlink").forEach((a) => {
    const hit = a.dataset.route === routeName;
    if (hit) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  });
}
