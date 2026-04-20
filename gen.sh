#!/usr/bin/env bash
set -euo pipefail

BACKOFFICE_ROOT="${1:-../deepsleep-backoffice}"
FRONTEND_ROOT="${2:-.}"

need() { [[ -f "$1" ]] || { echo "ERROR: missing $1"; exit 1; }; }
need_dir() { [[ -d "$1" ]] || { echo "ERROR: missing dir $1"; exit 1; }; }

need_dir "$BACKOFFICE_ROOT/js/api"
need_dir "$BACKOFFICE_ROOT/js/components"
need_dir "$BACKOFFICE_ROOT/js/pages"

need "$BACKOFFICE_ROOT/js/api/services.js"
need "$BACKOFFICE_ROOT/js/components/Sidebar.js"
need "$BACKOFFICE_ROOT/js/pages/DashboardPage.js"
need "$BACKOFFICE_ROOT/app.js"

need_dir "$FRONTEND_ROOT/js/api"
need_dir "$FRONTEND_ROOT/js/pages"

need "$FRONTEND_ROOT/js/api/services.js"
need "$FRONTEND_ROOT/app.js"

# ==================================================================
# BACKOFFICE
# ==================================================================

cat > "$BACKOFFICE_ROOT/js/api/services.js" <<'EOF'
import { request } from "./client.js";

export const login = (payload) =>
  request("/auth/login", { method: "POST", body: payload });

export const createBusiness = (payload) =>
  request("/businesses", { method: "POST", body: payload });

export const createUser = (payload) =>
  request("/users", { method: "POST", body: payload });

export const listBusinesses = () =>
  request("/businesses");

export const listBusinessUsers = (businessId) =>
  request(`/businesses/${businessId}/users`);

export const listBusinessAccounts = (businessId) =>
  request(`/businesses/${businessId}/accounts`);
EOF

cat > "$BACKOFFICE_ROOT/js/components/Sidebar.js" <<'EOF'
import { Store } from "../store.js";

function isSuperAdmin() {
  return (Store.get().auth.roles || []).includes("SUPER_ADMIN");
}

export function renderSidebar(routeName) {
  return `
    <div class="bo-sidebar-card">
      <div class="bo-brand">
        <div class="bo-brand__logo" aria-hidden="true">
          <svg width="22" height="22" viewBox="0 0 20 20">
            <rect x="2" y="2" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"></rect>
            <path d="M6 10h8" stroke="currentColor" stroke-width="2"></path>
          </svg>
        </div>
        <div>
          <div class="bo-brand__name" style="font-size:22px;">DeepSleep</div>
          <div class="bo-brand__tag">Backoffice</div>
        </div>
      </div>

      <nav class="bo-nav">
        <a href="#/dashboard" ${routeName === "dashboard" ? 'aria-current="page"' : ""}>Dashboard</a>
        <a href="#/businesses-overview" ${routeName === "businesses-overview" ? 'aria-current="page"' : ""}>Businesses Overview</a>
        <a href="#/businesses" ${routeName === "businesses" ? 'aria-current="page"' : ""}>Create Business</a>
        <a href="#/users" ${routeName === "users" ? 'aria-current="page"' : ""}>Create User</a>
        ${isSuperAdmin() ? `<a href="#/security" ${routeName === "security" ? 'aria-current="page"' : ""}>Security Notes</a>` : ""}
        <a href="#/logout">Logout</a>
      </nav>
    </div>
  `;
}
EOF

cat > "$BACKOFFICE_ROOT/js/pages/DashboardPage.js" <<'EOF'
import { qs } from "../utils/dom.js";
import { Store } from "../store.js";

export async function DashboardPage() {
  const page = qs("#bo-page");
  const auth = Store.get().auth;

  page.innerHTML = `
    <div class="bo-panel">
      <div class="bo-panel__title">Dashboard</div>
      <div class="bo-panel__sub">Internal backoffice for super-admin operations.</div>

      <div class="bo-row" style="margin-bottom:14px;">
        <span class="bo-badge">Authenticated</span>
        <span class="bo-badge">${(auth.roles || []).join(", ") || "NO_ROLE"}</span>
      </div>

      <div class="bo-grid bo-grid--2">
        <div class="bo-panel" style="margin:0;">
          <div class="bo-panel__title" style="font-size:18px;">Businesses Overview</div>
          <div class="bo-panel__sub">Inspect all registered businesses, then drill down into their users and AWS accounts.</div>
          <a class="bo-btn bo-btn--primary" href="#/businesses-overview">Open</a>
        </div>

        <div class="bo-panel" style="margin:0;">
          <div class="bo-panel__title" style="font-size:18px;">Create Business</div>
          <div class="bo-panel__sub">Use /businesses to provision a new customer business and its first ADMIN.</div>
          <a class="bo-btn bo-btn--primary" href="#/businesses">Open</a>
        </div>

        <div class="bo-panel" style="margin:0;">
          <div class="bo-panel__title" style="font-size:18px;">Create User</div>
          <div class="bo-panel__sub">Use /users to create the first managed ADMIN or later internal users.</div>
          <a class="bo-btn bo-btn--primary" href="#/users">Open</a>
        </div>
      </div>
    </div>
  `;
}
EOF

cat > "$BACKOFFICE_ROOT/js/pages/BusinessesOverviewPage.js" <<'EOF'
import { qs, escapeHtml as h } from "../utils/dom.js";
import { toast } from "../utils/toast.js";
import * as Api from "../api/services.js";

function renderBusinessRows(items) {
  if (!items.length) {
    return `<tr><td colspan="4" class="bo-mono">No businesses found.</td></tr>`;
  }

  return items.map((b) => `
    <tr>
      <td>${h(b.id)}</td>
      <td>${h(b.name)}</td>
      <td>${h(b.created_at || "—")}</td>
      <td>
        <button class="bo-btn" type="button" data-business-select="${h(b.id)}">Inspect</button>
      </td>
    </tr>
  `).join("");
}

function renderUserRows(items) {
  if (!items.length) {
    return `<tr><td colspan="5" class="bo-mono">No users for this business.</td></tr>`;
  }

  return items.map((u) => `
    <tr>
      <td>${h(u.id)}</td>
      <td>${h(u.email)}</td>
      <td>${h((u.roles || []).join(", ") || "—")}</td>
      <td>${h(u.business_id)}</td>
      <td>${h(u.created_at || "—")}</td>
    </tr>
  `).join("");
}

function renderAccountRows(items) {
  if (!items.length) {
    return `<tr><td colspan="5" class="bo-mono">No AWS accounts for this business.</td></tr>`;
  }

  return items.map((a) => `
    <tr>
      <td>${h(a.id)}</td>
      <td>${h(a.name || "—")}</td>
      <td>${h(a.aws_account_id || "—")}</td>
      <td>${h(a.role_arn || "—")}</td>
      <td>${h(a.business_id || "—")}</td>
    </tr>
  `).join("");
}

export async function BusinessesOverviewPage() {
  const page = qs("#bo-page");

  page.innerHTML = `
    <div class="bo-panel">
      <div class="bo-panel__title">Businesses Overview</div>
      <div class="bo-panel__sub">Global super-admin visibility across all SaaS customers.</div>

      <div class="bo-row" style="margin-bottom:16px;">
        <button class="bo-btn bo-btn--primary" id="bo-businesses-refresh" type="button">Refresh</button>
        <span class="bo-mono" id="bo-businesses-status">—</span>
      </div>

      <div style="overflow:auto;">
        <table style="width:100%;border-collapse:collapse;">
          <thead>
            <tr>
              <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">ID</th>
              <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Name</th>
              <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Created At</th>
              <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Actions</th>
            </tr>
          </thead>
          <tbody id="bo-businesses-tbody"></tbody>
        </table>
      </div>
    </div>

    <div class="bo-grid bo-grid--2">
      <div class="bo-panel">
        <div class="bo-panel__title">Business Users</div>
        <div class="bo-panel__sub">Users for the selected business.</div>
        <div class="bo-mono" id="bo-users-selected-business" style="margin-bottom:12px;">Selected business: none</div>

        <div style="overflow:auto;">
          <table style="width:100%;border-collapse:collapse;">
            <thead>
              <tr>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">ID</th>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Email</th>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Roles</th>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Business ID</th>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Created At</th>
              </tr>
            </thead>
            <tbody id="bo-users-tbody"></tbody>
          </table>
        </div>
      </div>

      <div class="bo-panel">
        <div class="bo-panel__title">Business Accounts</div>
        <div class="bo-panel__sub">AWS accounts attached to the selected business.</div>
        <div class="bo-mono" id="bo-accounts-selected-business" style="margin-bottom:12px;">Selected business: none</div>

        <div style="overflow:auto;">
          <table style="width:100%;border-collapse:collapse;">
            <thead>
              <tr>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">ID</th>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Name</th>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">AWS Account ID</th>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Role ARN</th>
                <th style="text-align:left;padding:10px;border-bottom:1px solid #e5e5e5;">Business ID</th>
              </tr>
            </thead>
            <tbody id="bo-accounts-tbody"></tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  const status = qs("#bo-businesses-status");
  const businessesTbody = qs("#bo-businesses-tbody");
  const usersTbody = qs("#bo-users-tbody");
  const accountsTbody = qs("#bo-accounts-tbody");
  const usersSelected = qs("#bo-users-selected-business");
  const accountsSelected = qs("#bo-accounts-selected-business");

  async function inspectBusiness(businessId) {
    try {
      usersSelected.textContent = `Selected business: ${businessId}`;
      accountsSelected.textContent = `Selected business: ${businessId}`;

      const [usersResp, accountsResp] = await Promise.all([
        Api.listBusinessUsers(businessId),
        Api.listBusinessAccounts(businessId),
      ]);

      usersTbody.innerHTML = renderUserRows(usersResp?.users || []);
      accountsTbody.innerHTML = renderAccountRows(accountsResp?.accounts || []);
    } catch (e) {
      toast("Inspect business failed", e.message || "Request failed", "error");
    }
  }

  async function loadBusinesses() {
    try {
      status.textContent = "Loading businesses…";
      const resp = await Api.listBusinesses();
      const businesses = resp?.businesses || [];
      businessesTbody.innerHTML = renderBusinessRows(businesses);
      status.textContent = `${businesses.length} business(es) loaded`;

      businessesTbody.querySelectorAll("[data-business-select]").forEach((btn) => {
        btn.addEventListener("click", () => inspectBusiness(btn.dataset.businessSelect));
      });

      if (businesses.length > 0) {
        await inspectBusiness(businesses[0].id);
      } else {
        usersTbody.innerHTML = renderUserRows([]);
        accountsTbody.innerHTML = renderAccountRows([]);
      }
    } catch (e) {
      status.textContent = "Failed";
      toast("Load businesses failed", e.message || "Request failed", "error");
    }
  }

  qs("#bo-businesses-refresh").addEventListener("click", loadBusinesses);

  await loadBusinesses();
}
EOF

cat > "$BACKOFFICE_ROOT/app.js" <<'EOF'
import { Store } from "./js/store.js";
import { createRouter } from "./js/utils/router.js";
import { qs } from "./js/utils/dom.js";
import { toast } from "./js/utils/toast.js";
import { isTokenExpired } from "./js/api/client.js";

import { renderHeader } from "./js/components/Header.js";
import { renderSidebar } from "./js/components/Sidebar.js";

import { LoginPage } from "./js/pages/LoginPage.js";
import { DashboardPage } from "./js/pages/DashboardPage.js";
import { BusinessesPage } from "./js/pages/BusinessesPage.js";
import { BusinessesOverviewPage } from "./js/pages/BusinessesOverviewPage.js";
import { UsersPage } from "./js/pages/UsersPage.js";
import { SecurityPage } from "./js/pages/SecurityPage.js";

const router = createRouter();

router.register("login", LoginPage);
router.register("dashboard", DashboardPage);
router.register("businesses-overview", BusinessesOverviewPage);
router.register("businesses", BusinessesPage);
router.register("users", UsersPage);
router.register("security", SecurityPage);
router.register("logout", async () => {
  Store.clearSession();
  hideShell();
  window.location.hash = "#/login";
});

function showShell(routeName) {
  qs("#bo-sidebar").classList.remove("bo-hidden");
  qs("#bo-header").classList.remove("bo-hidden");
  qs("#bo-sidebar").innerHTML = renderSidebar(routeName);
  qs("#bo-header").innerHTML = renderHeader();
}

function hideShell() {
  qs("#bo-sidebar").classList.add("bo-hidden");
  qs("#bo-header").classList.add("bo-hidden");
  qs("#bo-sidebar").innerHTML = "";
  qs("#bo-header").innerHTML = "";
}

async function guardAndRender(route) {
  const token = Store.get().auth.token;
  const authenticated = !!token;

  if (authenticated && isTokenExpired(token)) {
    Store.clearSession();
    toast("Session expired", "Please login again", "error");
    hideShell();
    window.location.hash = "#/login";
    return;
  }

  if (!authenticated) {
    hideShell();
    Store.set({ route: { name: "login", params: {} } });
    return router.render({ name: "login", params: {} });
  }

  if (route.name === "login") {
    window.location.hash = "#/dashboard";
    return;
  }

  showShell(route.name);
  Store.set({ route });
  return router.render(route);
}

router.start((route) => {
  guardAndRender(route);
});
EOF

# ==================================================================
# PUBLIC FRONTEND
# ==================================================================

cat > "$FRONTEND_ROOT/js/api/services.js" <<'EOF'
import { request } from "./client.js";

/* Auth */
export const login = (payload) => request("/auth/login", { method: "POST", body: payload });
export const refresh = (payload) => request("/auth/refresh", { method: "POST", body: payload });

/* Accounts */
export const listAccounts = () => request("/accounts");
export const createAccount = (payload) => request("/accounts", { method: "POST", body: payload });
export const getOnboardingInstructions = () => request("/accounts/onboarding-instructions", { method: "GET" });

/* Plan catalog / schemas */
export const getSupportedPlans = () => request("/plans");
export const getStepSchema = (stepType) => request(`/schemas/steps/${encodeURIComponent(stepType)}`);
export const getPlanSchema = (planType) => request(`/schemas/plans/${encodeURIComponent(planType)}`);

/* Account Config (Sleep Plans) */
export const getAccountConfig = (accountId) =>
  request(`/accounts/${accountId}/config`);

export const putAccountConfig = (accountId, body) =>
  request(`/accounts/${accountId}/config`, { method: "PUT", body });

/* Resources */
export const searchResources = (accountId, body) =>
  request(`/accounts/${accountId}/resources/search`, { method: "POST", body });

export const batchRegister = (accountId, body) =>
  request(`/accounts/${accountId}/resources/batch-register`, { method: "POST", body });

/* EKS states + orchestration */
export const listClusterStates = (accountId) =>
  request(`/accounts/${accountId}/cluster-states`);

export const sleepEKS = (accountId, clusterName, region, planName) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/sleep`, {
    method: "POST",
    query: { region, plan_name: planName || "dev" },
  });

export const wakeEKS = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/wake`, {
    method: "POST",
    query: { region },
  });

export const unregisterEKS = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/register`, {
    method: "DELETE",
    query: { region },
  });

/* EKS price / savings */
export const getEksClusterPrice = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/price`, {
    method: "GET",
    query: { region },
  });

export const getEksClusterPriceSavings = (accountId, clusterName, region) =>
  request(`/accounts/${accountId}/eks-clusters/${encodeURIComponent(clusterName)}/price-savings`, {
    method: "GET",
    query: { region },
  });

/* RDS states + orchestration */
export const listRdsStates = (accountId) =>
  request(`/accounts/${accountId}/rds-instance-states`);

export const sleepRDS = (accountId, dbInstanceId, region, planName) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/sleep`, {
    method: "POST",
    query: { region, plan_name: planName || "rds_dev" },
  });

export const wakeRDS = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/wake`, {
    method: "POST",
    query: { region },
  });

export const unregisterRDS = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/register`, {
    method: "DELETE",
    query: { region },
  });

/* RDS price / savings */
export const getRdsInstancePrice = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/price`, {
    method: "GET",
    query: { region },
  });

export const getRdsInstancePriceSavings = (accountId, dbInstanceId, region) =>
  request(`/accounts/${accountId}/rds-instances/${encodeURIComponent(dbInstanceId)}/price-savings`, {
    method: "GET",
    query: { region },
  });

/* Account aggregated savings */
export const getAccountPriceSavings = (accountId, body) =>
  request(`/accounts/${accountId}/price-savings`, {
    method: "POST",
    body,
  });

/* Time policies */
export const listPolicies = (accountId) =>
  request(`/accounts/${accountId}/time-policies`);

export const getPolicy = (accountId, policyId) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`);

export const createPolicy = (accountId, body) =>
  request(`/accounts/${accountId}/time-policies`, { method: "POST", body });

export const updatePolicy = (accountId, policyId, body) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "PUT", body });

export const deletePolicy = (accountId, policyId) =>
  request(`/accounts/${accountId}/time-policies/${policyId}`, { method: "DELETE" });

export const runPolicyNow = (accountId, policyId, action) =>
  request(`/accounts/${accountId}/time-policies/${policyId}/run-now`, { method: "POST", body: { action } });

/* History */
export const listRuns = (accountId, params = {}) =>
  request(`/accounts/${accountId}/runs`, {
    method: "GET",
    query: params,
  });

/* Users */
export const listUsers = () => request("/users");
export const getUser = (userId) => request(`/users/${userId}`);
export const createUser = (body) => request("/users", { method: "POST", body });
export const updateUserRoles = (userId, body) => request(`/users/${userId}/roles`, { method: "PUT", body });
export const updateUserAccounts = (userId, body) => request(`/users/${userId}/accounts`, { method: "PUT", body });
export const deleteUser = (userId) => request(`/users/${userId}`, { method: "DELETE" });
EOF

cat > "$FRONTEND_ROOT/js/pages/OnboardingPage.js" <<'EOF'
import { qs, escapeHtml as h } from "../utils/dom.js";
import { toast } from "../utils/toast.js";
import * as Api from "../api/services.js";

function buildScript(data) {
  const deepsleepAccountId = data.deepsleep_account_id;
  const externalId = data.external_id;
  const roleName = data.role_name;
  const policyName = data.policy_name;

  return `# Variables
DEEPSLEEP_ACCOUNT_ID="${deepsleepAccountId}"
EXTERNAL_ID="${externalId}"
ROLE_NAME="${roleName}"
POLICY_NAME="${policyName}"

# 1. Creation of the Trust Policy
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::\${DEEPSLEEP_ACCOUNT_ID}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "\${EXTERNAL_ID}"
        }
      }
    }
  ]
}
EOF

# 2. Creation of the Role
aws iam create-role \\
  --role-name $ROLE_NAME \\
  --assume-role-policy-document file://trust-policy.json \\
  --description "Role assumed by Deep Sleep SaaS for FinOps automation"

# 3. Creation of the Permissions Policy
cat <<EOF > permissions-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "eks:ListClusters",
        "eks:DescribeCluster",
        "eks:ListNodegroups",
        "eks:DescribeNodegroup",
        "eks:UpdateNodegroupConfig",
        "eks:CreateAccessEntry",
        "eks:DeleteAccessEntry",
        "eks:AssociateAccessPolicy",
        "eks:DisassociateAccessPolicy",
        "rds:DescribeDBInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeSpotPriceHistory",
        "rds:StopDBInstance",
        "rds:StartDBInstance",
        "rds:ListTagsForResource",
        "pricing:DescribeServices",
        "pricing:GetAttributeValues",
        "pricing:GetProducts",
        "pricing:GetPriceListFileUrl",
        "autoscaling:DescribeAutoScalingGroups",
        "tag:GetResources",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# 4. Creation of the Policy in AWS
POLICY_ARN=$(aws iam create-policy \\
  --policy-name $POLICY_NAME \\
  --policy-document file://permissions-policy.json \\
  --query 'Policy.Arn' --output text)

# 5. Attach Policy to Role
aws iam attach-role-policy \\
  --role-name $ROLE_NAME \\
  --policy-arn $POLICY_ARN

# 6. Cleanup
rm trust-policy.json permissions-policy.json

echo "✅ AWS configuration complete. Role created: \${ROLE_NAME}"
echo "👉 Retrieve your role ARN with:"
echo "aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text"`;
}

export async function OnboardingPage() {
  const page = qs("#ds-page");
  if (!page) return;

  page.innerHTML = `
    <div class="ds-panel">
      <div class="ds-panel__head">
        <div>
          <div class="ds-panel__title">Your business doesn't have any account attached</div>
          <div class="ds-panel__sub">Attach one now and start saving.</div>
        </div>
      </div>

      <div style="padding:0 20px 20px 20px;display:grid;gap:18px;">
        <div class="ds-badge ds-badge--violet-matte">Step 1 — Generate onboarding script</div>

        <div class="ds-row">
          <button class="ds-btn ds-btn--wake" id="ds-onboarding-load" type="button">Generate Script</button>
          <button class="ds-btn" id="ds-onboarding-copy" type="button">Copy Script</button>
        </div>

        <pre id="ds-onboarding-script" style="white-space:pre-wrap;overflow:auto;padding:16px;border:1px solid #e5e5e5;border-radius:16px;background:#fbfbfb;font-family:ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;font-size:12px;color:#3e3e3e;min-height:220px;"></pre>

        <div class="ds-badge ds-badge--violet-matte">Step 2 — Paste the resulting values</div>

        <div class="ds-row" style="align-items:flex-start;">
          <div class="ds-field" style="flex:1 1 240px;">
            <div class="ds-label">Account name</div>
            <input class="ds-input" id="ds-onboarding-account-name" placeholder="Production AWS" />
          </div>

          <div class="ds-field" style="flex:1 1 240px;">
            <div class="ds-label">AWS Account ID</div>
            <input class="ds-input" id="ds-onboarding-aws-account-id" placeholder="123456789012" />
          </div>
        </div>

        <div class="ds-field">
          <div class="ds-label">Role ARN</div>
          <input class="ds-input" id="ds-onboarding-role-arn" placeholder="arn:aws:iam::123456789012:role/deepsleep-control-plane-role" />
        </div>

        <div class="ds-field">
          <div class="ds-label">External ID</div>
          <input class="ds-input" id="ds-onboarding-external-id" placeholder="Auto-filled after Generate Script" />
        </div>

        <div class="ds-row">
          <button class="ds-btn ds-btn--wake" id="ds-onboarding-create-account" type="button">Attach Account</button>
        </div>

        <div class="ds-mono-muted" id="ds-onboarding-status">—</div>
      </div>
    </div>
  `;

  const scriptEl = qs("#ds-onboarding-script");
  const statusEl = qs("#ds-onboarding-status");

  let instructions = null;

  async function loadInstructions() {
    try {
      statusEl.textContent = "Generating onboarding instructions…";
      instructions = await Api.getOnboardingInstructions();
      const script = buildScript(instructions);
      scriptEl.textContent = script;
      qs("#ds-onboarding-external-id").value = instructions.external_id || "";
      statusEl.textContent = "Instructions ready.";
    } catch (e) {
      statusEl.textContent = "Failed.";
      toast("Onboarding", e.message || "Unable to load onboarding instructions");
    }
  }

  qs("#ds-onboarding-load").addEventListener("click", loadInstructions);

  qs("#ds-onboarding-copy").addEventListener("click", async () => {
    try {
      const text = scriptEl.textContent || "";
      if (!text.trim()) throw new Error("Generate the script first.");
      await navigator.clipboard.writeText(text);
      toast("Onboarding", "Script copied to clipboard.");
    } catch (e) {
      toast("Onboarding", e.message || "Copy failed");
    }
  });

  qs("#ds-onboarding-create-account").addEventListener("click", async () => {
    try {
      const payload = {
        name: qs("#ds-onboarding-account-name").value.trim(),
        aws_account_id: qs("#ds-onboarding-aws-account-id").value.trim(),
        role_arn: qs("#ds-onboarding-role-arn").value.trim(),
        external_id: qs("#ds-onboarding-external-id").value.trim() || null,
      };

      if (!payload.name || !payload.aws_account_id || !payload.role_arn) {
        throw new Error("Missing account name / aws_account_id / role_arn");
      }

      statusEl.textContent = "Attaching account…";
      await Api.createAccount(payload);
      statusEl.textContent = "Account attached.";
      toast("Onboarding", "Account attached successfully.");

      window.location.hash = "#/discovery";
      window.dispatchEvent(new Event("hashchange"));
      window.location.reload();
    } catch (e) {
      statusEl.textContent = "Attach failed.";
      toast("Onboarding", e.message || "Failed to attach account");
    }
  });

  await loadInstructions();
}
EOF

cat > "$FRONTEND_ROOT/app.js" <<'EOF'
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
import { OnboardingPage } from "./js/pages/OnboardingPage.js";

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
router.register("onboarding", async () => OnboardingPage());

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

  let accounts = [];
  try {
    await loadAccountsIntoDropdown();
    accounts = Store.getState().accounts?.list || [];
  } catch (e) {
    console.error("loadAccountsIntoDropdown failed:", e);
    toast("Accounts", "Unable to load account selector. Rendering page anyway.");
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
    console.error("route render failed:", e);
    toast("Render", e?.message || "Page rendering failed");
  }

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

echo "OK: updated backoffice api/services.js"
echo "OK: updated backoffice Sidebar.js"
echo "OK: updated backoffice DashboardPage.js"
echo "OK: created backoffice BusinessesOverviewPage.js"
echo "OK: updated backoffice app.js"

echo "OK: updated frontend api/services.js"
echo "OK: created frontend OnboardingPage.js"
echo "OK: updated frontend app.js"

echo "Done."
