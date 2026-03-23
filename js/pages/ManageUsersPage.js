import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { fmtTime } from "../utils/time.js";
import * as Api from "../api/services.js";

function requireAdmin() {
  const s = Store.getState();
  if (!s.auth.token) {
    toast("Auth", "Please login.");
    location.hash = "#/login";
    return false;
  }
  if (!(s.auth.roles || []).includes("ADMIN")) {
    toast("Users", "Admin only.");
    location.hash = "#/discovery";
    return false;
  }
  return true;
}

function renderUsersTable(users) {
  const list = Array.isArray(users) ? users : [];
  if (!list.length) return `<div class="ds-mono-muted">No users.</div>`;

  return `
    <div class="ds-tablewrap">
      <table class="ds-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Email</th>
            <th>Roles</th>
            <th>Accounts</th>
            <th>Active</th>
            <th>Created</th>
            <th>Updated</th>
            <th style="width:260px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          ${list.map((u) => `
            <tr>
              <td>${u.id}</td>
              <td>${h(u.email)}</td>
              <td>${h((u.roles || []).join(","))}</td>
              <td>${h((u.account_ids || []).join(","))}</td>
              <td>${u.is_active ? "true" : "false"}</td>
              <td>${h(fmtTime(u.created_at))}</td>
              <td>${h(fmtTime(u.updated_at))}</td>
              <td>
                <div class="ds-row">
                  <button class="ds-btn ds-btn--ghost" type="button" data-user-edit="${u.id}">Edit</button>
                  <button class="ds-btn ds-btn--danger" type="button" data-user-delete="${u.id}">Delete</button>
                </div>
              </td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    </div>
  `;
}

function buildAccountOptions(selectedIds) {
  const selected = new Set(selectedIds || []);
  const accounts = Store.getState().accounts.list || [];
  return accounts.map((acc) => `
    <label class="ds-badge" style="gap:10px;">
      <input type="checkbox" data-user-account="${acc.id}" ${selected.has(acc.id) ? "checked" : ""} />
      <span>${h(acc.aws_account_id || String(acc.id))}</span>
    </label>
  `).join("");
}

function openUserModal(mode, user = null) {
  const host = qs("#ds-modalhost");
  if (!host) return;

  const roles = new Set(user?.roles || []);
  const accountIds = user?.account_ids || [];

  host.innerHTML = `
    <div class="ds-modalbackdrop" data-role="close"></div>
    <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Manage User" style="width:min(980px, calc(100vw - 32px)); max-height:88vh;">
      <div class="ds-modal__head">
        <div class="ds-modal__title">${mode === "edit" ? `Edit User #${user.id}` : "Create User"}</div>
        <button class="ds-btn ds-btn--ghost" type="button" data-role="close">Close</button>
      </div>
      <div class="ds-modal__body">
        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Identity</div>
              <div class="ds-panel__sub">Business user + auth microservice projection</div>
            </div>
          </div>

          <div class="ds-row">
            <div class="ds-field" style="min-width:unset;flex:1;">
              <div class="ds-label">Business ID</div>
              <input class="ds-input" id="ds-user-business-id" value="${h(Store.getState().auth.business_id || "")}" ${mode === "edit" ? "disabled" : ""} />
            </div>
            <div class="ds-field" style="min-width:unset;flex:1;">
              <div class="ds-label">Email</div>
              <input class="ds-input" id="ds-user-email" value="${h(user?.email || "")}" ${mode === "edit" ? "disabled" : ""} />
            </div>
            ${mode === "create" ? `
            <div class="ds-field" style="min-width:unset;flex:1;">
              <div class="ds-label">Password</div>
              <input class="ds-input" id="ds-user-password" type="password" value="" />
            </div>
            ` : ""}
          </div>
        </div>

        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Roles</div>
            </div>
          </div>
          <div class="ds-row">
            <label class="ds-badge" style="gap:10px;">
              <input type="checkbox" id="ds-user-role-standard" ${roles.has("STANDARD") ? "checked" : ""} />
              <span>STANDARD</span>
            </label>
            <label class="ds-badge" style="gap:10px;">
              <input type="checkbox" id="ds-user-role-admin" ${roles.has("ADMIN") ? "checked" : ""} />
              <span>ADMIN</span>
            </label>
          </div>
        </div>

        <div class="ds-panel" style="margin:0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Accounts Access</div>
            </div>
          </div>
          <div class="ds-row" style="flex-wrap:wrap;">
            ${buildAccountOptions(accountIds)}
          </div>
        </div>
      </div>
      <div class="ds-modal__foot">
        <button class="ds-btn ds-btn--ghost" type="button" data-role="cancel">Cancel</button>
        <button class="ds-btn" type="button" id="ds-user-save">${mode === "edit" ? "Save" : "Create"}</button>
      </div>
    </div>
  `;
  host.style.pointerEvents = "auto";

  const close = () => {
    host.innerHTML = "";
    host.style.pointerEvents = "none";
  };

  host.addEventListener("click", (e) => {
    const role = e.target?.dataset?.role;
    if (role === "close" || role === "cancel") close();
  });

  qs("#ds-user-save")?.addEventListener("click", async () => {
    try {
      const rolesOut = [];
      if (qs("#ds-user-role-standard")?.checked) rolesOut.push("STANDARD");
      if (qs("#ds-user-role-admin")?.checked) rolesOut.push("ADMIN");

      const account_ids = qsa("[data-user-account]").filter((x) => x.checked).map((x) => Number(x.dataset.userAccount));
      const business_id = Number(qs("#ds-user-business-id")?.value || 0);

      if (mode === "create") {
        const payload = {
          business_id,
          email: (qs("#ds-user-email")?.value || "").trim(),
          password: qs("#ds-user-password")?.value || "",
          roles: rolesOut,
          account_ids,
        };
        await Api.createUser(payload);
        toast("Users", "Created.");
      } else {
        await Api.updateUserRoles(user.id, { roles: rolesOut });
        await Api.updateUserAccounts(user.id, { account_ids });
        toast("Users", "Updated.");
      }

      close();
      await ManageUsersPage();
    } catch (e) {
      toast("Users", e.message || "Save failed");
    }
  });
}

export async function ManageUsersPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Manage Users";

  page.innerHTML = renderPanel({
    title: "Manage Users",
    sub: "Admin-only interface to create, inspect, update roles/accounts and delete business users.",
    actionsHtml: `
      <button class="ds-btn" id="ds-users-refresh" type="button">Refresh</button>
      <button class="ds-btn ds-btn--wake" id="ds-users-new" type="button">Create User</button>
    `,
    bodyHtml: `
      <div class="ds-mono-muted" id="ds-users-status">—</div>
      <div style="height:10px"></div>
      <div id="ds-users-results"></div>
    `,
  });

  if (!requireAdmin()) {
    qs("#ds-users-status").textContent = "Not allowed.";
    return;
  }

  const status = qs("#ds-users-status");
  const results = qs("#ds-users-results");

  async function loadUsers() {
    try {
      status.textContent = "Loading…";
      const resp = await Api.listUsers();
      const users = resp?.users || [];
      Store.setState({ users: { list: users } });
      results.innerHTML = renderUsersTable(users);
      status.textContent = `OK — ${users.length} user(s).`;
      bindActions();
    } catch (e) {
      status.textContent = "Error.";
      toast("Users", e.message || "Load failed");
    }
  }

  function bindActions() {
    qsa("[data-user-edit]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        try {
          const userId = Number(btn.dataset.userEdit);
          const user = await Api.getUser(userId);
          openUserModal("edit", user);
        } catch (e) {
          toast("Users", e.message || "Failed to load user");
        }
      });
    });

    qsa("[data-user-delete]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const userId = Number(btn.dataset.userDelete);
        const ok = await confirmModal({
          title: "Delete User",
          body: `<div class="ds-mono-muted">Delete user #${userId} ?</div>`,
          confirmText: "Delete",
          cancelText: "Cancel",
        });
        if (!ok) return;

        try {
          await Api.deleteUser(userId);
          toast("Users", "Deleted.");
          await loadUsers();
        } catch (e) {
          toast("Users", e.message || "Delete failed");
        }
      });
    });
  }

  qs("#ds-users-refresh")?.addEventListener("click", loadUsers);
  qs("#ds-users-new")?.addEventListener("click", () => openUserModal("create"));

  await loadUsers();
}
