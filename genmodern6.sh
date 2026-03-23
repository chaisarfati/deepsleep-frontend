#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

need() { [[ -f "$1" ]] || { echo "ERROR: missing $1"; exit 1; }; }

need "$ROOT/js/components/Header.js"
need "$ROOT/app.js"

# ------------------------------------------------------------------
# 1) js/components/Header.js
#    - restore hidden #ds-crumbs so pages stop crashing
# ------------------------------------------------------------------
cat > "$ROOT/js/components/Header.js" <<'EOF'
export function renderHeader() {
  return `
    <div class="ds-topbar">
      <div id="ds-crumbs" class="ds-hidden" aria-hidden="true"></div>

      <div class="ds-topbar__searchwrap">
        <label class="ds-search" aria-label="Recherche">
          <span class="ds-search__icon" aria-hidden="true">
            <svg width="18" height="18" viewBox="0 0 18 18">
              <circle cx="8" cy="8" r="5" fill="none" stroke="currentColor" stroke-width="1.7"/>
              <path d="M12.5 12.5L16 16" fill="none" stroke="currentColor" stroke-width="1.7"/>
            </svg>
          </span>
          <input
            id="ds-global-search"
            class="ds-search__input"
            type="search"
            placeholder="Filter resources by name / region / type…"
            autocomplete="off"
          />
        </label>
      </div>
    </div>
  `;
}
EOF

# ------------------------------------------------------------------
# 2) app.js
#    - align with real HTML structure (#ds-app instead of #ds-main)
#    - keep shell/login flow intact
# ------------------------------------------------------------------
cat > "$ROOT/app.js" <<'EOF'
import { Store } from "./js/store.js";
import { createRouter } from "./js/utils/router.js";
import { createPoller } from "./js/utils/poller.js";
import { qs } from "./js/utils/dom.js";
import { toast } from "./js/utils/toast.js";

import { renderSidebar, setActiveNav } from "./js/components/Sidebar.js";
import { renderHeader } from "./js/components/Header.js";
import { loadAccountsIntoDropdown, rebindUserDropdownAfterRerender } from "./js/components/UserDropdown.js";
import { bindGlobalSearch } from "./js/components/SearchBar.js";
import { applyTableFilter } from "./js/components/TableFilters.js";
import { patchActiveRow } from "./js/components/ActiveRowPatcher.js";

import { LoginPage } from "./js/pages/LoginPage.js";
import { InventoryPage } from "./js/pages/InventoryPage.js";
import { ActiveResourcesPage } from "./js/pages/ActiveResourcesPage.js";
import { TimePoliciesPage } from "./js/pages/TimePoliciesPage.js";
import { SleepPlansPage } from "./js/pages/SleepPlansPage.js";
import { HistoryPage } from "./js/pages/HistoryPage.js";
import { ManageUsersPage } from "./js/pages/ManageUsersPage.js";
import { SavingsPage } from "./js/pages/SavingsPage.js";

import * as Api from "./js/api/services.js";

function decodeJwtPayload(token) {
  try {
    const parts = String(token || "").split(".");
    if (parts.length < 2) return null;
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    return JSON.parse(atob(padded));
  } catch {
    return null;
  }
}

function isTokenExpired(token) {
  if (!token) return true;
  const jwt = decodeJwtPayload(token);
  if (!jwt || !jwt.exp) return false;
  const now = Math.floor(Date.now() / 1000);
  return now >= Number(jwt.exp);
}

function clearSession() {
  localStorage.removeItem("deepsleep.token");
  localStorage.removeItem("deepsleep.account_id");
  localStorage.removeItem("deepsleep.aws_account_id");
  localStorage.removeItem("deepsleep.roles");
  localStorage.removeItem("deepsleep.email");
  localStorage.removeItem("deepsleep.business_id");

  Store.setState({
    auth: { token: "", email: "", business_id: "", roles: [] },
    account: { id: 0, aws_account_id: "" },
    accounts: { list: [], loaded: false },
  });
}

function showShell() {
  const rail = qs("#ds-rail");
  const topbar = qs("#ds-topbar");
  const app = qs("#ds-app");

  if (rail) {
    rail.classList.remove("ds-hidden");
    rail.innerHTML = renderSidebar();
  }

  if (topbar) {
    topbar.classList.remove("ds-hidden");
    topbar.innerHTML = renderHeader();
  }

  if (app) {
    app.style.marginTop = "0";
  }

  rebindUserDropdownAfterRerender();

  bindGlobalSearch((q) => {
    const route = Store.getState().route.name;
    if (route === "discovery") applyTableFilter('[data-table="discovery"]', q);
    if (route === "active") applyTableFilter('[data-table="active"]', q);
  });
}

function hideShell() {
  const rail = qs("#ds-rail");
  const topbar = qs("#ds-topbar");
  const app = qs("#ds-app");

  if (rail) {
    rail.innerHTML = "";
    rail.classList.add("ds-hidden");
  }

  if (topbar) {
    topbar.innerHTML = "";
    topbar.classList.add("ds-hidden");
  }

  if (app) {
    app.style.marginTop = "0";
  }
}

const router = createRouter();

router.register("login", async () => LoginPage());
router.register("discovery", async () => InventoryPage());
router.register("active", async () => ActiveResourcesPage());
router.register("policies", async () => TimePoliciesPage());
router.register("settings", async () => SleepPlansPage());
router.register("history", async () => HistoryPage());
router.register("users", async () => ManageUsersPage());
router.register("savings", async () => SavingsPage());

async function initialRoute(route) {
  const token = Store.getState().auth.token;
  const expired = isTokenExpired(token);

  if (expired && token) {
    clearSession();
    toast("Session", "Token expired. Please login again.");
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
  await loadAccountsIntoDropdown();

  Store.setState({ route });
  setActiveNav(route.name);
  await router.render(route);

  const input = qs("#ds-global-search");
  if (input) input.value = Store.getState().ui.search || "";
}

router.start((route) => {
  initialRoute(route);
});

window.addEventListener("hashchange", () => {
  const token = Store.getState().auth.token;

  if (token && isTokenExpired(token)) {
    clearSession();
    hideShell();
    toast("Session", "Token expired. Please login again.");
    if (location.hash !== "#/login") {
      location.hash = "#/login";
    }
  }
});

const poller = createPoller({
  intervalMs: 10000,
  guard: () => {
    const s = Store.getState();
    return !!(s.account.id && s.auth.token && s.route.name === "active" && !isTokenExpired(s.auth.token));
  },
  tick: async () => {
    const s = Store.getState();
    const accountId = s.account.id;

    try {
      const eks = await Api.listClusterStates(accountId);
      const clusters = eks?.clusters || [];

      for (const c of clusters) {
        const key = `EKS_CLUSTER|${c.cluster_name}|${c.region}`;
        patchActiveRow(key, {
          key,
          resource_type: "EKS_CLUSTER",
          resource_name: c.cluster_name,
          region: c.region,
          observed_state: c.observed_state,
          desired_state: c.desired_state,
          last_action: c.last_action,
          last_action_at: c.last_action_at,
          locked_until: c.locked_until,
          updated_at: c.updated_at,
        });
      }

      const rds = await Api.listRdsStates(accountId);
      const instances = rds?.instances || [];

      for (const r of instances) {
        const key = `RDS_INSTANCE|${r.db_instance_id}|${r.region}`;
        patchActiveRow(key, {
          key,
          resource_type: "RDS_INSTANCE",
          resource_name: r.db_instance_id,
          region: r.region,
          observed_state: r.observed_state,
          desired_state: r.desired_state,
          last_action: r.last_action,
          last_action_at: r.last_action_at,
          locked_until: r.locked_until,
          updated_at: r.updated_at,
        });
      }

      Store.setState({ active: { lastPollAt: new Date().toISOString() } });
    } catch (e) {
      if (String(e.message || "").includes("401") || String(e.message || "").includes("403")) {
        clearSession();
        hideShell();
        toast("Session", "Authentication lost. Please login again.");
        location.hash = "#/login";
        return;
      }

      toast("Polling", e.message || "Poll failed");
    }
  },
});

poller.start();
EOF

echo "OK: rewrote js/components/Header.js"
echo "OK: rewrote app.js"
echo "Done."
