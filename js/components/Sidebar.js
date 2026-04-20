import { Store } from "../store.js";
import { qs, qsa } from "../utils/dom.js";
import { Storage } from "../utils/storage.js";
import { toast } from "../utils/toast.js";
import * as Api from "../api/services.js";

function isAdmin() {
  return (Store.getState().auth.roles || []).includes("ADMIN");
}

const NAV_ITEMS = [
  {
    route: "discovery",
    label: "Discovery",
    icon: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6">
      <circle cx="7" cy="7" r="4.5"/>
      <path d="M10.5 10.5L14 14"/>
    </svg>`,
  },
  {
    route: "active",
    label: "Active Resources",
    icon: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6">
      <rect x="2" y="2" width="12" height="12" rx="2"/>
      <path d="M5 8h6M5 5.5h4M5 10.5h3"/>
    </svg>`,
  },
  {
    route: "policies",
    label: "Time Policies",
    icon: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6">
      <circle cx="8" cy="8" r="6"/>
      <path d="M8 4.5V8l2.5 2"/>
    </svg>`,
  },
  {
    route: "settings",
    label: "Sleep Plans",
    icon: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5">
      <path d="M8 2C4.7 2 2 4.7 2 8s2.7 6 6 6 6-2.7 6-6-2.7-6-6-6z"/>
      <path d="M10 5.5C9.3 4.6 8.2 4 7 4c-2.2 0-4 1.8-4 4s1.8 4 4 4c1.2 0 2.3-.6 3-1.5"/>
    </svg>`,
  },
  {
    route: "savings",
    label: "Savings",
    icon: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6">
      <path d="M2 12h12M4 10V6M8 10V3M12 10V7"/>
    </svg>`,
  },
  {
    route: "history",
    label: "History",
    icon: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6">
      <path d="M2.5 8A5.5 5.5 0 1 0 8 2.5"/>
      <path d="M2.5 4v4h4"/>
      <path d="M8 5.5V8l2 1.5"/>
    </svg>`,
  },
];

const ADMIN_NAV = {
  route: "users",
  label: "Manage Users",
  icon: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5">
    <circle cx="5.5" cy="6" r="2"/>
    <circle cx="10.5" cy="6" r="2"/>
    <path d="M1.5 13c.7-1.6 2-2.5 4-2.5s3.3 1 4 2.5"/>
    <path d="M7.5 13c.6-1.3 1.7-2 3-2s2.4.7 3 2"/>
  </svg>`,
};

function initials(email = "") {
  const parts = email.split("@")[0].split(/[\.\-_]/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return email.slice(0, 2).toUpperCase();
}

export function renderSidebar() {
  const admin = isAdmin();
  const items = admin ? [...NAV_ITEMS, ADMIN_NAV] : NAV_ITEMS;
  const email = Store.getState().auth.email || "User";

  return `
    <div class="ds-sidebar__brand">
      <div class="ds-brand__mark" aria-hidden="true">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.8">
          <path d="M3 8h10M8 3v10"/>
          <rect x="1.5" y="1.5" width="13" height="13" rx="2"/>
        </svg>
      </div>
      <div class="ds-brand__text">
        <div class="ds-brand__name">DeepSleep</div>
        <div class="ds-brand__tag">AWS FinOps</div>
      </div>
    </div>

    <div class="ds-sidebar__section-label">Platform</div>

    <nav class="ds-nav" aria-label="Navigation principale">
      ${items.map(({ route, label, icon }) => `
        <a class="ds-navlink" href="#/${route}" data-route="${route}" aria-label="${label}">
          <span class="ds-navlink__icon" aria-hidden="true">${icon}</span>
          <span class="ds-navlink__label">${label}</span>
        </a>
      `).join("")}
    </nav>

    <div class="ds-sidebar__spacer"></div>

    <div class="ds-sidebar__user">
      <div class="ds-sidebar__account">
        <div class="ds-sidebar__account-label">Account</div>
        <select class="ds-sidebar__account-select" id="ds-account-switch" aria-label="Switch account">
          <option value="">(loading…)</option>
        </select>
      </div>

      <div style="height:10px"></div>

      <div style="position:relative;">
        <button class="ds-userchip" id="ds-userchip" type="button" aria-haspopup="menu" aria-expanded="false">
          <div class="ds-userchip__avatar" aria-hidden="true">${initials(email)}</div>
          <div class="ds-userchip__info">
            <div class="ds-userchip__name">${email}</div>
            <div class="ds-userchip__role">${admin ? "Admin" : "Standard"}</div>
          </div>
          <svg class="ds-userchip__caret" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true">
            <path d="M3 5l4 4 4-4"/>
          </svg>
        </button>

        <div class="ds-dropdown" id="ds-user-dropdown" role="menu" aria-label="User menu" hidden>
          <div class="ds-dropdown__row">
            <div class="ds-dropdown__k">Email</div>
            <div class="ds-dropdown__v" id="ds-dd-name">—</div>
          </div>
          <div class="ds-dropdown__row">
            <div class="ds-dropdown__k">AWS Account</div>
            <div class="ds-dropdown__v" id="ds-dd-aws">—</div>
          </div>
          <div class="ds-dropdown__row">
            <div class="ds-dropdown__k">Business</div>
            <div class="ds-dropdown__v" id="ds-dd-biz">—</div>
          </div>
          <div class="ds-dropdown__sep" aria-hidden="true"></div>
          <div class="ds-dropdown__row">
            <button class="ds-btn ds-btn--ghost ds-btn--sm" id="ds-logout-btn" type="button" style="color:var(--danger);">
              <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.8">
                <path d="M5 2H2v10h3M9 9l4-2-4-3M13 7H5"/>
              </svg>
              Logout
            </button>
          </div>
        </div>
      </div>
    </div>
  `;
}

export function setActiveNav(routeName) {
  qsa(".ds-navlink").forEach((a) => {
    const hit = a.dataset.route === routeName;
    if (hit) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  });
}

/* ── UserDropdown logic (inlined from UserDropdown.js) ────── */

let docBound = false;

function rerenderCurrentRoute() {
  window.dispatchEvent(new Event("hashchange"));
}

export async function loadAccountsIntoDropdown() {
  const token = Store.getState().auth?.token;
  const select = qs("#ds-account-switch");
  if (!select) return;
  if (!token) {
    select.innerHTML = `<option value="">(login required)</option>`;
    return;
  }

  try {
    const resp = await Api.listAccounts();
    const accounts = resp?.accounts || [];

    Store.setState({ accounts: { list: accounts, loaded: true } });

    if (!accounts.length) {
      select.innerHTML = `<option value="">(no account)</option>`;
      return;
    }

    let currentId = Store.getState().account.id;
    let currentAws = Store.getState().account.aws_account_id;

    if (!currentId) {
      currentId = accounts[0].id;
      currentAws = accounts[0].aws_account_id || "";
      Storage.set("deepsleep.account_id", String(currentId));
      Storage.set("deepsleep.aws_account_id", currentAws);
      Store.setState({ account: { id: currentId, aws_account_id: currentAws } });
    }

    select.innerHTML = accounts.map((acc) => `
      <option value="${acc.id}" ${Number(acc.id) === Number(currentId) ? "selected" : ""}>
        ${acc.aws_account_id || acc.id}
      </option>
    `).join("");

    renderUserInfo();
  } catch (e) {
    select.innerHTML = `<option value="">(failed)</option>`;
    toast("Accounts", e.message || "Failed to load accounts");
  }
}

export function bindUserDropdown() {
  const userchip = qs("#ds-userchip");
  const dropdown = qs("#ds-user-dropdown");
  const logout = qs("#ds-logout-btn");
  const switcher = qs("#ds-account-switch");

  if (!userchip || !dropdown) return;

  userchip.onclick = () => {
    const expanded = userchip.getAttribute("aria-expanded") === "true";
    userchip.setAttribute("aria-expanded", expanded ? "false" : "true");
    dropdown.hidden = expanded;
  };

  if (!docBound) {
    document.addEventListener("click", (e) => {
      const chip = qs("#ds-userchip");
      const dd = qs("#ds-user-dropdown");
      if (!chip || !dd) return;
      if (!chip.contains(e.target) && !dd.contains(e.target)) {
        chip.setAttribute("aria-expanded", "false");
        dd.hidden = true;
      }
    });
    docBound = true;
  }

  if (switcher && !switcher.dataset.bound) {
    switcher.dataset.bound = "1";
    switcher.addEventListener("change", () => {
      const id = Number(switcher.value || 0);
      const account = (Store.getState().accounts.list || []).find((x) => Number(x.id) === id);
      if (!account) return;

      Storage.set("deepsleep.account_id", String(account.id));
      Storage.set("deepsleep.aws_account_id", account.aws_account_id || "");

      Store.setState({
        account: {
          id: account.id,
          aws_account_id: account.aws_account_id || "",
          name: account.name || "—",
        },
      });

      renderUserInfo();
      toast("Account", `Switched to ${account.aws_account_id || account.id}`);
      rerenderCurrentRoute();
    });
  }

  if (logout && !logout.dataset.bound) {
    logout.dataset.bound = "1";
    logout.addEventListener("click", () => {
      ["token","account_id","aws_account_id","roles","email","business_id","account_name"].forEach(
        (k) => Storage.del(`deepsleep.${k}`)
      );
      Store.setState({
        auth: { token: "", email: "", business_id: "", roles: [] },
        account: { id: 0, aws_account_id: "" },
        accounts: { list: [], loaded: false },
      });
      toast("Session", "Logged out.");
      const chip = qs("#ds-userchip");
      const dd = qs("#ds-user-dropdown");
      if (chip) chip.setAttribute("aria-expanded", "false");
      if (dd) dd.hidden = true;
      location.hash = "#/login";
      window.dispatchEvent(new Event("hashchange"));
    });
  }
}

export function renderUserInfo() {
  const s = Store.getState();
  const email = s.auth.email || "User";
  const chipName = qs("#ds-userchip-name");
  const avatar = qs(".ds-userchip__avatar");
  const ddName = qs("#ds-dd-name");
  const ddAws = qs("#ds-dd-aws");
  const ddBiz = qs("#ds-dd-biz");

  if (chipName) chipName.textContent = email;
  if (avatar) avatar.textContent = initials(email);
  if (ddName) ddName.textContent = email;
  if (ddAws) ddAws.textContent = s.account.aws_account_id || "—";
  if (ddBiz) ddBiz.textContent = s.auth.business_id || "—";
}

export function rebindUserDropdownAfterRerender() {
  bindUserDropdown();
  renderUserInfo();
}
