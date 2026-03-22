import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";
import { toast } from "../utils/toast.js";
import { qs } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";
import { decodeJwtPayload } from "../utils/jwt.js";
import { renderUserInfo } from "../components/UserDropdown.js";

export async function LoginPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  // crumbs
  const crumbs = qs("#ds-crumbs");
  if (crumbs) crumbs.textContent = "Login";

  const storedAccountId = Storage.get("deepsleep.account_id") || "";

  page.innerHTML = renderPanel({
    title: "Login",
    sub: "Business user authentication. You will be redirected to Discovery after success.",
    bodyHtml: `
      <div style="display:grid;grid-template-columns:1fr;gap:12px;max-width:520px;">
        <div class="ds-field">
          <div class="ds-label">Email</div>
          <input class="ds-input" id="ds-login-email" value="${s.auth.email || ""}" placeholder="you@company.com" />
        </div>

        <div class="ds-field">
          <div class="ds-label">Password</div>
          <input class="ds-input" id="ds-login-pass" type="password" value="" placeholder="••••••••" />
        </div>

        <div class="ds-field">
          <div class="ds-label">Business ID</div>
          <input class="ds-input" id="ds-login-biz" value="${s.auth.business_id || ""}" placeholder="business_id" />
        </div>

        <div class="ds-field">
          <div class="ds-label">Account ID (internal)</div>
          <input class="ds-input" id="ds-login-account" inputmode="numeric" value="${s.account.id || storedAccountId || ""}" placeholder="account_id" />
        </div>

        <div class="ds-row">
          <button class="ds-btn ds-btn--wake" id="ds-login-btn" type="button">Login</button>
          <button class="ds-btn" id="ds-login-clear" type="button">Clear Token</button>
        </div>

        <div class="ds-mono-muted">Token: <span id="ds-token-preview">${(s.auth.token || "").slice(0, 28) || "—"}</span></div>
      </div>
    `,
  });

  const email = qs("#ds-login-email");
  const pass = qs("#ds-login-pass");
  const biz = qs("#ds-login-biz");
  const account = qs("#ds-login-account");
  const btnLogin = qs("#ds-login-btn");
  const btnClear = qs("#ds-login-clear");
  const tokenPreview = qs("#ds-token-preview");

  btnLogin.addEventListener("click", async () => {
    try {
      const accountIdRaw = (account.value || "").trim();
      if (accountIdRaw) Storage.set("deepsleep.account_id", accountIdRaw);

      const payload = { email: email.value.trim(), password: pass.value, business_id: biz.value.trim() };
      if (!payload.email || !payload.password || !payload.business_id) throw new Error("Missing email/password/business_id.");

      const resp = await Api.login(payload);
      const token = resp?.token;
      if (!token) throw new Error("No token returned.");

      // Save auth
      Storage.set("deepsleep.token", token);
      Storage.set("deepsleep.email", payload.email);
      Storage.set("deepsleep.business_id", payload.business_id);

      // If account_id wasn't provided manually, try to infer from JWT and store it
      let inferredAccountId =
        Number(accountIdRaw || 0) ||
        Number((decodeJwtPayload(token) || {}).account_id || (decodeJwtPayload(token) || {}).accountId || (decodeJwtPayload(token) || {}).aws_account_internal_id || 0) ||
        0;

      if (inferredAccountId) Storage.set("deepsleep.account_id", String(inferredAccountId));

      Store.setState({
        auth: { token, email: payload.email, business_id: payload.business_id },
        account: { id: inferredAccountId || Store.getState().account.id },
      });

      tokenPreview.textContent = token.slice(0, 28);
      renderUserInfo();
      toast("Auth", "Login OK.");

      location.hash = "#/discovery";
    } catch (e) {
      toast("Auth", e.message || "Login failed");
    }
  });

  btnClear.addEventListener("click", () => {
    Storage.del("deepsleep.token");
    Store.setState({ auth: { token: "" } });
    tokenPreview.textContent = "—";
    toast("Auth", "Token cleared.");
  });
}