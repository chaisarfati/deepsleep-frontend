import { Store } from "./js/store.js";
import { createRouter } from "./js/utils/router.js";
import { createPoller } from "./js/utils/poller.js";
import { qs } from "./js/utils/dom.js";
import { toast } from "./js/utils/toast.js";

import {
  renderSidebar,
  setActiveNav,
  loadAccountsIntoDropdown,
  rebindUserDropdownAfterRerender,
} from "./js/components/Sidebar.js";

import { LoginPage }           from "./js/pages/LoginPage.js";
import { InventoryPage }       from "./js/pages/InventoryPage.js";
import { ActiveResourcesPage } from "./js/pages/ActiveResourcesPage.js";
import { TimePoliciesPage }    from "./js/pages/TimePoliciesPage.js";
import { SleepPlansPage }      from "./js/pages/SleepPlansPage.js";
import { HistoryPage }         from "./js/pages/HistoryPage.js";
import { ManageUsersPage }     from "./js/pages/ManageUsersPage.js";
import { SavingsPage }         from "./js/pages/SavingsPage.js";
import { OnboardingPage }      from "./js/pages/OnboardingPage.js";
import { patchActiveRow }      from "./js/components/ActiveRowPatcher.js";

import * as Api from "./js/api/services.js";

/* ── JWT helpers ─────────────────────────────────────────── */

function decodeJwtPayload(token) {
  try {
    const parts = String(token || "").split(".");
    if (parts.length < 2) return null;
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    return JSON.parse(atob(padded));
  } catch { return null; }
}

function isTokenExpired(token) {
  if (!token) return true;
  const jwt = decodeJwtPayload(token);
  if (!jwt || !jwt.exp) return false;
  return Math.floor(Date.now() / 1000) >= Number(jwt.exp);
}

function clearSession() {
  ["token","account_id","aws_account_id","roles","email","business_id","account_name"].forEach(
    (k) => localStorage.removeItem(`deepsleep.${k}`)
  );
  Store.setState({
    auth:     { token: "", email: "", business_id: "", roles: [] },
    account:  { id: 0, aws_account_id: "" },
    accounts: { list: [], loaded: false },
    // Reset page caches on logout
    discovery: { hasLoaded: false, resources: [], selectedKeys: new Set() },
    active:    { hasLoaded: false, rowsByKey: new Map(), pricingCache: new Map() },
  });
}

/* ── Shell visibility ────────────────────────────────────── */

function showShell() {
  const sidebar = qs("#ds-sidebar");
  if (sidebar) {
    sidebar.classList.remove("ds-hidden");
    sidebar.innerHTML = renderSidebar();
  }
  rebindUserDropdownAfterRerender();
}

function hideShell() {
  const sidebar = qs("#ds-sidebar");
  if (sidebar) {
    sidebar.innerHTML = "";
    sidebar.classList.add("ds-hidden");
  }
}

/* ── Router ──────────────────────────────────────────────── */

const router = createRouter();

router.register("login",     async () => LoginPage());
router.register("discovery", async () => InventoryPage());
router.register("active",    async () => ActiveResourcesPage());
router.register("policies",  async () => TimePoliciesPage());
router.register("settings",  async () => SleepPlansPage());
router.register("history",   async () => HistoryPage());
router.register("users",     async () => ManageUsersPage());
router.register("savings",   async () => SavingsPage());
router.register("onboarding",async () => OnboardingPage());

/* ── Initial route logic ─────────────────────────────────── */

async function initialRoute(route) {
  const token   = Store.getState().auth.token;
  const expired = isTokenExpired(token);

  if (expired && token) {
    clearSession();
    toast("Session", "Token expired. Please sign in again.");
  }

  const hasToken = !!Store.getState().auth.token;

  if (!hasToken) {
    hideShell();
    Store.setState({ route: { name: "login", params: {} } });
    if (route.name !== "login") {
      location.hash = "#/login";
      return;
    }
    await router.render({ name: "login", params: {} });
    return;
  }

  if (route.name === "login") {
    location.hash = "#/discovery";
    return;
  }

  showShell();

  let accounts = [];
  try {
    const resp = await Api.listAccounts();
    accounts   = resp?.accounts || resp || [];
    Store.setState({ accounts: { list: Array.isArray(accounts) ? accounts : [], loaded: true } });
    try { await loadAccountsIntoDropdown(); } catch (e) { console.error("dropdown:", e); }
  } catch (e) {
    console.error("listAccounts:", e);
    toast("Accounts", "Unable to load accounts.");
  }

  if (Array.isArray(accounts) && accounts.length === 0 && route.name !== "onboarding") {
    location.hash = "#/onboarding";
    return;
  }

  if (Array.isArray(accounts) && accounts.length > 0 && route.name === "onboarding") {
    location.hash = "#/discovery";
    return;
  }

  Store.setState({ route });
  setActiveNav(route.name);

  try {
    await router.render(route);
  } catch (e) {
    console.error("Route render failed:", e);
    toast("Render", e?.message || "Page rendering failed.");
  }
}

router.start((route) => initialRoute(route));

/* ── Session guard on navigation ─────────────────────────── */

window.addEventListener("hashchange", () => {
  const token = Store.getState().auth.token;
  if (token && isTokenExpired(token)) {
    clearSession();
    hideShell();
    toast("Session", "Token expired. Please sign in again.");
    if (location.hash !== "#/login") location.hash = "#/login";
  }
});

/* ── Poller — silently refreshes Active Resources state ─────
   Uses the unified /resource-states endpoint.
   Does NOT re-fetch pricing — those are cached separately.    */

const PRICING_TTL_MS = 60 * 60 * 1000;

const poller = createPoller({
  intervalMs: 600000,
  guard: () => {
    const s = Store.getState();
    return !!(s.account.id && s.auth.token && s.route.name === "active" && !isTokenExpired(s.auth.token));
  },
  tick: async () => {
    const s = Store.getState();
    const accountId = s.account.id;

    try {
      // Step 1: fetch states from DB (fast)
      const resp   = await Api.listResourceStates(accountId);
      const states = resp?.states || [];

      for (const state of states) {
        const resourceName = state.resource_name ?? state.cluster_name ?? state.db_instance_id ?? state.instance_id;
        const key = `${state.resource_type}|${resourceName}|${state.region}`;
        patchActiveRow(key, {
          key,
          resource_type:  state.resource_type,
          resource_name:  resourceName,
          region:         state.region,
          observed_state: state.observed_state,
          desired_state:  state.desired_state,
          last_action:    state.last_action,
          last_action_at: state.last_action_at,
          locked_until:   state.locked_until,
          updated_at:     state.updated_at,
        });
      }

      Store.setState({ active: { lastPollAt: new Date().toISOString() } });

      // Step 2: opportunistic batch pricing for uncached resources
      const pCache = s.active.pricingCache;
      const uncached = states.filter(state => {
        const resourceName = state.resource_name ?? state.cluster_name ?? state.db_instance_id ?? state.instance_id;
        const key = `${state.resource_type}|${resourceName}|${state.region}`;
        const existing = pCache.get(key);
        if (existing && (Date.now() - existing.ts) < PRICING_TTL_MS) return false;
        const obs = (state.observed_state || "").toUpperCase();
        return obs === "RUNNING" || obs === "AVAILABLE" || obs === "ACTIVE"
            || obs === "SLEEPING" || obs === "STOPPED" || obs === "ASLEEP";
      }).map(state => ({
        resource_type:  state.resource_type,
        resource_name:  state.resource_name ?? state.cluster_name ?? state.db_instance_id ?? state.instance_id,
        region:         state.region,
        observed_state: state.observed_state,
      }));

      if (uncached.length) {
        Api.getResourcePricingBatch(accountId, uncached).then(resp => {
          const pricing = resp?.pricing || {};
          for (const [key, { cost, savings }] of Object.entries(pricing)) {
            pCache.set(key, { cost, savings, ts: Date.now() });
          }
        }).catch(() => {});
      }

    } catch (e) {
      const msg = String(e.message || "");
      if (msg.includes("401") || msg.includes("403")) {
        clearSession();
        hideShell();
        toast("Session", "Authentication lost. Please sign in again.");
        location.hash = "#/login";
      }
    }
  },
});

poller.start();
