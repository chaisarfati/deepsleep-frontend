import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";
import { toast } from "../utils/toast.js";
import { qs } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";
import { renderUserInfo } from "../components/UserDropdown.js";

export async function LoginPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  const crumbs = qs("#ds-crumbs");
  if (crumbs) crumbs.textContent = "Login";

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
  const btnLogin = qs("#ds-login-btn");
  const btnClear = qs("#ds-login-clear");
  const tokenPreview = qs("#ds-token-preview");

  btnLogin.addEventListener("click", async () => {
    try {
      const payload = { email: email.value.trim(), password: pass.value, business_id: biz.value.trim() };
      if (!payload.email || !payload.password || !payload.business_id) throw new Error("Missing email/password/business_id.");

      const resp = await Api.login(payload);
      const token = resp?.token;
      if (!token) throw new Error("No token returned.");

      Storage.set("deepsleep.token", token);
      Storage.set("deepsleep.email", payload.email);
      Storage.set("deepsleep.business_id", payload.business_id);

      // account is now loaded from GET /accounts in dropdown logic
      Store.setState({
        auth: { token, email: payload.email, business_id: payload.business_id },
        account: { id: 0, aws_account_id: "" },
        accounts: { list: [], loaded: false },
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
    Storage.del("deepsleep.account_id");
    Storage.del("deepsleep.aws_account_id");

    Store.setState({
      auth: { token: "" },
      account: { id: 0, aws_account_id: "" },
      accounts: { list: [], loaded: false },
    });

    tokenPreview.textContent = "—";
    toast("Auth", "Token cleared.");
  });
}
