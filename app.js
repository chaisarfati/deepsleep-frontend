import { Store } from "./js/store.js";
import { createRouter } from "./js/utils/router.js";
import { createPoller } from "./js/utils/poller.js";
import { qs } from "./js/utils/dom.js";
import { toast } from "./js/utils/toast.js";

import { renderSidebar, setActiveNav } from "./js/components/Sidebar.js";
import { renderHeader } from "./js/components/Header.js";
import { bindUserDropdown, renderUserInfo } from "./js/components/UserDropdown.js";
import { bindGlobalSearch } from "./js/components/SearchBar.js";
import { applyTableFilter } from "./js/components/TableFilters.js";
import { patchActiveRow } from "./js/components/ActiveRowPatcher.js";

import { LoginPage } from "./js/pages/LoginPage.js";
import { InventoryPage } from "./js/pages/InventoryPage.js";
import { ActiveResourcesPage } from "./js/pages/ActiveResourcesPage.js";
import { TimePoliciesPage } from "./js/pages/TimePoliciesPage.js";
import { SleepPlansPage } from "./js/pages/SleepPlansPage.js";

import * as Api from "./js/api/services.js";

/* ---------- Bootstrapping shell ---------- */
(function bootstrapShell(){
  const rail = qs("#ds-rail");
  if (rail) rail.innerHTML = renderSidebar();

  const topbar = qs("#ds-topbar");
  if (topbar) topbar.innerHTML = renderHeader();

  bindUserDropdown();
  renderUserInfo();

  bindGlobalSearch((q) => {
    const route = Store.getState().route.name;
    if (route === "discovery") applyTableFilter('[data-table="discovery"]', q);
    if (route === "active") applyTableFilter('[data-table="active"]', q);
  });

  // API indicator is internal now
  const apiIndicator = qs("#ds-api-indicator");
  if (apiIndicator) apiIndicator.textContent = "same-origin";
})();

/* ---------- Router ---------- */
const router = createRouter();

router.register("login", async () => LoginPage());
router.register("discovery", async () => InventoryPage());
router.register("active", async () => ActiveResourcesPage());
router.register("policies", async () => TimePoliciesPage());
router.register("settings", async () => SleepPlansPage());

function initialRoute(route) {
  const s = Store.getState();
  const hasToken = !!s.auth.token;

  // Landing: if not logged in -> /login
  if (!hasToken && route.name !== "login") {
    location.hash = "#/login";
    return;
  }

  // If logged in and user hits /login, redirect to discovery
  if (hasToken && route.name === "login") {
    location.hash = "#/discovery";
    return;
  }

  Store.setState({ route });
  setActiveNav(route.name);
  router.render(route);

  // keep search input in sync
  const input = qs("#ds-global-search");
  if (input) input.value = Store.getState().ui.search || "";
}

router.start((route) => initialRoute(route));

/* ---------- Polling (10s) ----------
   Fetch /accounts/{id}/cluster-states and patch only changed rows.
*/
const poller = createPoller({
  intervalMs: 10_000,
  guard: () => {
    const s = Store.getState();
    return !!(s.account.id && s.auth.token && s.route.name === "active");
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
      toast("Polling", e.message || "Poll failed");
    }
  },
});

poller.start();
