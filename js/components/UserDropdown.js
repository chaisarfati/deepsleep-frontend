import { qs } from "../utils/dom.js";
import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { Storage } from "../utils/storage.js";
import * as Api from "../api/services.js";

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
        ${acc.aws_account_id}
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

  if (!userchip || !dropdown) return;

  userchip.addEventListener("click", async () => {
    const expanded = userchip.getAttribute("aria-expanded") === "true";
    userchip.setAttribute("aria-expanded", expanded ? "false" : "true");
    dropdown.hidden = expanded;
    if (!expanded) {
      await loadAccountsIntoDropdown();

      const switcher = qs("#ds-account-switch");
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
          toast("Account", `Switched to ${account.aws_account_id}`);
          rerenderCurrentRoute();
        });
      }
    }
  });

  document.addEventListener("click", (e) => {
    const inside = userchip.contains(e.target) || dropdown.contains(e.target);
    if (!inside) {
      userchip.setAttribute("aria-expanded", "false");
      dropdown.hidden = true;
    }
  });

  if (logout) {
    logout.addEventListener("click", () => {
      Storage.del("deepsleep.token");
      Storage.del("deepsleep.account_id");
      Storage.del("deepsleep.aws_account_id");

      Store.setState({
        auth: { token: "" },
        account: { id: 0, aws_account_id: "" },
        accounts: { list: [], loaded: false },
      });

      toast("Session", "Logged out.");
      userchip.setAttribute("aria-expanded", "false");
      dropdown.hidden = true;
      location.hash = "#/login";
    });
  }
}

export function renderUserInfo() {
  const s = Store.getState();
  const email = s.auth.email || "User";

  const chipText = qs("#ds-userchip-text");
  const ddName = qs("#ds-dd-name");
  const ddAws = qs("#ds-dd-aws");
  const ddBiz = qs("#ds-dd-biz");

  if (chipText) chipText.textContent = email;
  if (ddName) ddName.textContent = email;
  if (ddAws) ddAws.textContent = s.account.aws_account_id || "—";
  if (ddBiz) ddBiz.textContent = s.auth.business_id || "—";
}
