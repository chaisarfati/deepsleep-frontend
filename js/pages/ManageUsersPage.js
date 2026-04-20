/**
 * ManageUsersPage.js — User management for admins
 * 2026 redesign: user cards + inline drawer
 */
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { fmtTime } from "../utils/time.js";
import * as Api from "../api/services.js";

function requireAdmin() {
  const s = Store.getState();
  if (!s.auth.token) { toast("Auth", "Please login."); location.hash = "#/login"; return false; }
  if (!(s.auth.roles || []).includes("ADMIN")) { toast("Users", "Admin only."); location.hash = "#/discovery"; return false; }
  return true;
}

function initials(email = "") {
  const parts = email.split("@")[0].split(/[\.\-_]/);
  return parts.length >= 2
    ? (parts[0][0] + parts[1][0]).toUpperCase()
    : email.slice(0, 2).toUpperCase();
}

function roleChip(role) {
  const isAdmin = role === "ADMIN";
  return `<span class="ds-badge ${isAdmin ? "ds-badge--accent" : ""}">${h(role)}</span>`;
}

function renderUserCard(user) {
  const accountCount = (user.account_ids || []).length;
  const rolesHtml = (user.roles || []).map(roleChip).join(" ") || `<span class="ds-badge">No roles</span>`;
  const activeChip = user.is_active
    ? `<span class="ds-badge ds-badge--success"><span class="ds-badge-dot"></span>Active</span>`
    : `<span class="ds-badge ds-badge--danger"><span class="ds-badge-dot"></span>Inactive</span>`;

  return `
    <div class="ds-policy-card" data-user-id="${user.id}">
      <!-- Avatar -->
      <div class="ds-userchip__avatar" style="width:40px;height:40px;border-radius:50%;font-size:14px;flex-shrink:0;">
        ${initials(user.email)}
      </div>

      <!-- Info -->
      <div class="ds-policy-card__body">
        <div class="ds-policy-card__name">${h(user.email)}</div>
        <div class="ds-policy-card__meta" style="display:flex;align-items:center;gap:6px;flex-wrap:wrap;margin-top:4px;">
          ${rolesHtml}
          ${activeChip}
          ${accountCount ? `<span class="ds-badge"><svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="1" y="3" width="10" height="7" rx="1"/><path d="M4 3V2a2 2 0 1 1 4 0v1"/></svg>${accountCount} account${accountCount > 1 ? "s" : ""}</span>` : ""}
          <span class="ds-mono" style="font-size:10.5px;color:var(--fg-faint);">ID #${user.id}</span>
        </div>
      </div>

      <!-- Actions -->
      <div class="ds-policy-card__actions">
        <button class="ds-btn ds-btn--sm" data-user-action="edit" data-user-id="${user.id}">
          <svg width="12" height="12" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.7">
            <path d="M10 2l2 2-8 8H2v-2l8-8z"/>
          </svg>
          Edit
        </button>
        <button class="ds-btn ds-btn--sm ds-btn--danger" data-user-action="delete" data-user-id="${user.id}">
          <svg width="12" height="12" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.7">
            <path d="M2 4h10M5 4V2h4v2M5 6v5M9 6v5M3 4l1 8h6l1-8"/>
          </svg>
          Delete
        </button>
      </div>
    </div>
  `;
}

function buildAccountCheckboxes(selectedIds) {
  const selected = new Set((selectedIds || []).map(Number));
  const accounts = Store.getState().accounts.list || [];
  if (!accounts.length) return `<div class="ds-mono" style="color:var(--fg-faint);font-size:12px;">No accounts available.</div>`;

  return `<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:8px;">
    ${accounts.map(acc => `
      <label style="display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid var(--border);border-radius:var(--r-md);cursor:pointer;transition:background var(--t-fast);" class="ds-account-option">
        <input type="checkbox" data-user-account="${acc.id}" ${selected.has(Number(acc.id)) ? "checked" : ""}
          style="accent-color:var(--accent);width:15px;height:15px;cursor:pointer;flex-shrink:0;"/>
        <span class="ds-mono" style="font-size:12px;">${h(acc.aws_account_id || String(acc.id))}</span>
      </label>
    `).join("")}
  </div>`;
}

function openUserDrawer(mode, user, usersById, onSaved) {
  const overlay = document.createElement("div");
  overlay.style.cssText = `position:fixed;inset:0;z-index:180;background:rgba(19,19,16,.35);backdrop-filter:blur(3px);animation:fade-in 160ms ease;`;

  const drawer = document.createElement("div");
  drawer.style.cssText = `
    position:fixed;top:0;right:0;bottom:0;width:min(520px,100vw);
    background:var(--bg-surface);border-left:1px solid var(--border);
    box-shadow:var(--shadow-lg);z-index:181;display:flex;flex-direction:column;overflow:hidden;
    animation:drawer-in 220ms cubic-bezier(.2,.8,.4,1);
  `;

  const style = document.createElement("style");
  style.textContent = `@keyframes drawer-in { from { transform:translateX(100%); } to { transform:translateX(0); } }`;
  document.head.appendChild(style);
  document.body.appendChild(overlay);
  document.body.appendChild(drawer);

  const roles = new Set(user?.roles || []);
  const accountIds = user?.account_ids || [];
  const s = Store.getState();
  const bizId = s.auth.business_id || "";

  drawer.innerHTML = `
    <div style="display:flex;align-items:center;justify-content:space-between;padding:20px 24px;border-bottom:1px solid var(--border);flex-shrink:0;">
      <div>
        <div style="font-family:var(--font-display);font-size:16px;font-weight:700;color:var(--fg-strong);letter-spacing:-.02em;">
          ${mode === "edit" ? `Edit — ${h(user?.email || "")}` : "Invite user"}
        </div>
        <div style="font-size:12px;color:var(--fg-faint);margin-top:2px;">
          ${mode === "edit" ? `User #${user?.id}` : "Create a new business user"}
        </div>
      </div>
      <button class="ds-btn ds-btn--ghost ds-btn--icon" id="ds-udrawer-close" aria-label="Close">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M1 1l12 12M13 1L1 13"/>
        </svg>
      </button>
    </div>

    <div style="flex:1;overflow-y:auto;padding:24px;display:flex;flex-direction:column;gap:24px;">

      ${mode === "create" ? `
      <!-- Identity -->
      <div>
        <div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--fg-faint);margin-bottom:12px;">Identity</div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
          <div class="ds-field" style="grid-column:1/-1;">
            <label class="ds-label">Business ID</label>
            <input class="ds-input" id="ds-uform-bizid" value="${h(bizId)}" disabled />
          </div>
          <div class="ds-field">
            <label class="ds-label">Email</label>
            <input class="ds-input" id="ds-uform-email" type="email" placeholder="user@company.com" />
          </div>
          <div class="ds-field">
            <label class="ds-label">Password</label>
            <input class="ds-input" id="ds-uform-password" type="password" placeholder="••••••••" autocomplete="new-password"/>
          </div>
        </div>
      </div>
      ` : ""}

      <!-- Roles -->
      <div>
        <div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--fg-faint);margin-bottom:12px;">Roles</div>
        <div style="display:flex;gap:12px;">
          ${["STANDARD", "ADMIN"].map(role => `
            <label style="display:flex;align-items:center;gap:10px;padding:12px 16px;border:1px solid var(--border);border-radius:var(--r-md);cursor:pointer;flex:1;transition:border-color var(--t-fast);${roles.has(role) ? "border-color:var(--accent);background:var(--accent-dim);" : ""}">
              <input type="checkbox" id="ds-uform-role-${role.toLowerCase()}" ${roles.has(role) ? "checked" : ""}
                style="accent-color:var(--accent);width:15px;height:15px;cursor:pointer;"/>
              <div>
                <div style="font-weight:500;font-size:13px;color:var(--fg-strong);">${role}</div>
                <div style="font-size:11px;color:var(--fg-faint);">${role === "ADMIN" ? "Full access" : "Read + actions"}</div>
              </div>
            </label>
          `).join("")}
        </div>
      </div>

      <!-- Account access -->
      <div>
        <div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--fg-faint);margin-bottom:12px;">Account access</div>
        <div id="ds-uform-accounts">${buildAccountCheckboxes(accountIds)}</div>
      </div>

    </div>

    <div style="display:flex;justify-content:flex-end;gap:8px;padding:16px 24px;border-top:1px solid var(--border);background:var(--stone-50);flex-shrink:0;">
      <button class="ds-btn ds-btn--ghost" id="ds-udrawer-cancel">Cancel</button>
      <button class="ds-btn ds-btn--primary" id="ds-udrawer-save">
        <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="1.8">
          <path d="M2 7l4 4 6-7"/>
        </svg>
        ${mode === "edit" ? "Save changes" : "Create user"}
      </button>
    </div>
  `;

  function close() { overlay.remove(); drawer.remove(); style.remove(); }
  qs("#ds-udrawer-close")?.addEventListener("click", close);
  qs("#ds-udrawer-cancel")?.addEventListener("click", close);
  overlay.addEventListener("click", (e) => { if (e.target === overlay) close(); });

  function getSelectedRoles() {
    return ["STANDARD", "ADMIN"].filter(role =>
      qs(`#ds-uform-role-${role.toLowerCase()}`, drawer)?.checked
    );
  }

  function getSelectedAccountIds() {
    return Array.from(qsa("[data-user-account]", drawer))
      .filter(cb => cb.checked)
      .map(cb => Number(cb.dataset.userAccount));
  }

  qs("#ds-udrawer-save")?.addEventListener("click", async () => {
    const selectedRoles = getSelectedRoles();
    const selectedAccounts = getSelectedAccountIds();

    try {
      if (mode === "create") {
        const email    = qs("#ds-uform-email")?.value.trim();
        const password = qs("#ds-uform-password")?.value;
        if (!email || !password) return toast("Users", "Email and password are required.");

        await Api.createUser({
          business_id: Number(bizId),
          email,
          password,
          roles: selectedRoles,
          account_ids: selectedAccounts,
        });
        toast("Users", "User created.");

      } else {
        // Update roles
        await Api.updateUserRoles(user.id, { roles: selectedRoles });
        // Update accounts
        await Api.updateUserAccounts(user.id, { account_ids: selectedAccounts });
        toast("Users", "User updated.");
      }

      close();
      onSaved?.();
    } catch (e) {
      toast("Users", e.message || "Operation failed.");
    }
  });
}

// ── Page ──────────────────────────────────────────────────────────────────────

export async function ManageUsersPage() {
  const page = qs("#ds-page");
  if (!page) return;
  if (!requireAdmin()) return;

  page.innerHTML = `
    <div class="ds-page-header">
      <div>
        <div class="ds-page-title">Manage Users</div>
        <div class="ds-page-sub">Manage business users, their roles and AWS account access.</div>
      </div>
      <div class="ds-page-header__actions">
        <div id="ds-users-loading" style="display:none;align-items:center;gap:8px;">
          <div class="ds-spinner"></div>
          <span class="ds-mono" style="font-size:12px;color:var(--accent);">Loading…</span>
        </div>
        <!-- Filter -->
        <input class="ds-input" id="ds-users-search" placeholder="Filter users…"
          style="width:200px;min-height:32px;padding:5px 10px;font-size:12.5px;"/>
        <button class="ds-btn ds-btn--primary" id="ds-users-create">
          <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M7 2v10M2 7h10"/>
          </svg>
          Invite user
        </button>
      </div>
    </div>

    <!-- Stats bar -->
    <div class="ds-stat-grid" id="ds-users-stats" style="grid-template-columns:repeat(3,1fr);margin-bottom:20px;"></div>

    <!-- Users list -->
    <div id="ds-users-container">
      <div class="ds-empty"><div class="ds-spinner"></div></div>
    </div>
  `;

  const container = qs("#ds-users-container");
  const loadingEl = qs("#ds-users-loading");
  const statsEl   = qs("#ds-users-stats");
  const searchEl  = qs("#ds-users-search");
  const btnCreate = qs("#ds-users-create");

  let allUsers = [];

  function renderStats(users) {
    const total   = users.length;
    const admins  = users.filter(u => (u.roles || []).includes("ADMIN")).length;
    const active  = users.filter(u => u.is_active).length;
    statsEl.innerHTML = `
      <div class="ds-stat">
        <div class="ds-stat__label">Total users</div>
        <div class="ds-stat__value">${total}</div>
      </div>
      <div class="ds-stat ds-stat--accent">
        <div class="ds-stat__label">Admins</div>
        <div class="ds-stat__value">${admins}</div>
      </div>
      <div class="ds-stat ds-stat--success">
        <div class="ds-stat__label">Active</div>
        <div class="ds-stat__value">${active}</div>
      </div>
    `;
  }

  function renderList(users) {
    const q = (searchEl?.value || "").trim().toLowerCase();
    const filtered = q ? users.filter(u => u.email.toLowerCase().includes(q)) : users;

    if (!filtered.length) {
      container.innerHTML = `
        <div class="ds-empty" style="margin-top:40px;">
          <svg class="ds-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/>
          </svg>
          <div class="ds-empty__title">${q ? "No users match" : "No users yet"}</div>
          <div class="ds-empty__sub">${q ? "Try a different search." : "Invite your first team member."}</div>
        </div>`;
      return;
    }

    container.innerHTML = `<div style="display:grid;gap:8px;">${filtered.map(u => renderUserCard(u)).join("")}</div>`;
    bindListActions(users);
  }

  function bindListActions(users) {
    const usersById = Object.fromEntries(users.map(u => [u.id, u]));

    qsa("[data-user-action='edit']", container).forEach(btn => {
      btn.addEventListener("click", () => {
        const user = usersById[Number(btn.dataset.userId)];
        if (user) openUserDrawer("edit", user, usersById, () => loadAndRender());
      });
    });

    qsa("[data-user-action='delete']", container).forEach(btn => {
      btn.addEventListener("click", async () => {
        const user = usersById[Number(btn.dataset.userId)];
        if (!user) return;
        const ok = await confirmModal({
          title: `Delete ${user.email}?`,
          body: `<p class="ds-mono" style="font-size:13px;color:var(--fg-muted);">This user will lose access to DeepSleep. This cannot be undone.</p>`,
          confirmText: "Delete",
          danger: true,
        });
        if (!ok) return;
        try {
          await Api.deleteUser(user.id);
          toast("Users", "User deleted.");
          await loadAndRender();
        } catch (e) {
          toast("Users", e.message || "Delete failed.");
        }
      });
    });
  }

  async function loadAndRender() {
    loadingEl.style.display = "flex";
    try {
      const resp = await Api.listUsers();
      allUsers = resp?.users || (Array.isArray(resp) ? resp : []);
      Store.setState({ users: { list: allUsers } });
      renderStats(allUsers);
      renderList(allUsers);
    } catch (e) {
      container.innerHTML = `<div class="ds-empty"><div class="ds-empty__title">Failed to load</div><div class="ds-empty__sub">${h(e.message)}</div></div>`;
      toast("Users", e.message || "Load failed.");
    } finally {
      loadingEl.style.display = "none";
    }
  }

  searchEl?.addEventListener("input", () => renderList(allUsers));

  btnCreate.addEventListener("click", () =>
    openUserDrawer("create", null, {}, () => loadAndRender())
  );

  await loadAndRender();
}
