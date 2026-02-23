import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";
import { toast } from "../utils/toast.js";
import { qs } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { ApiClient } from "../api/client.js";
import * as Api from "../api/services.js";
import { renderUserInfo } from "../components/UserDropdown.js";

export async function SettingsPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Settings";

  page.innerHTML = renderPanel({
    title: "Connection & Auth",
    sub: "No framework. Vanilla state + manual render. Store minimal config in localStorage.",
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;">
        <span class="ds-badge">Neo-90s Matte</span>
        <span class="ds-badge ds-badge--muted">Hard borders • Hard shadows • Monospace</span>
      </div>

      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
        <div>
          <div class="ds-field">
            <div class="ds-label">API Base URL</div>
            <input class="ds-input" id="ds-set-baseurl" value="${ApiClient.getBaseUrl() || ""}" placeholder="e.g. http://localhost:8000" />
          </div>

          <div style="height:10px"></div>

          <div class="ds-field">
            <div class="ds-label">Account ID (internal)</div>
            <input class="ds-input" id="ds-set-accountid" inputmode="numeric" value="${s.account.id || ""}" placeholder="e.g. 1" />
          </div>

          <div style="height:10px"></div>

          <div class="ds-field">
            <div class="ds-label">AWS Account ID (display)</div>
            <input class="ds-input" id="ds-set-aws" value="${s.account.aws_account_id || ""}" placeholder="e.g. 123456789012" />
          </div>

          <div style="height:10px"></div>

          <div class="ds-field">
            <div class="ds-label">Business ID</div>
            <input class="ds-input" id="ds-set-biz" value="${s.auth.business_id || ""}" placeholder="UUID / int" />
          </div>

          <div style="height:12px"></div>

          <div class="ds-row">
            <button class="ds-btn" id="ds-set-save" type="button">Save Settings</button>
          </div>
        </div>

        <div>
          <div class="ds-panel" style="margin:0;">
            <div class="ds-panel__head">
              <div>
                <div class="ds-panel__title">Login</div>
                <div class="ds-panel__sub">Calls /auth/login (business_user) and stores token.</div>
              </div>
            </div>

            <div class="ds-field">
              <div class="ds-label">Email</div>
              <input class="ds-input" id="ds-login-email" value="${s.auth.email || ""}" placeholder="you@company.com" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field">
              <div class="ds-label">Password</div>
              <input class="ds-input" id="ds-login-pass" type="password" value="" placeholder="••••••••" />
            </div>

            <div style="height:10px"></div>

            <div class="ds-field">
              <div class="ds-label">Business ID</div>
              <input class="ds-input" id="ds-login-biz" value="${s.auth.business_id || ""}" placeholder="business_id" />
            </div>

            <div style="height:12px"></div>

            <div class="ds-row">
              <button class="ds-btn ds-btn--wake" id="ds-login-btn" type="button">Login</button>
              <button class="ds-btn" id="ds-token-clear" type="button">Clear Token</button>
            </div>

            <div style="height:12px"></div>
            <div class="ds-mono-muted">Token: <span id="ds-token-preview">${(s.auth.token || "").slice(0, 28) || "—"}</span></div>
          </div>
        </div>
      </div>
    `,
  });

  const baseUrl = qs("#ds-set-baseurl");
  const accountId = qs("#ds-set-accountid");
  const aws = qs("#ds-set-aws");
  const biz = qs("#ds-set-biz");
  const btnSave = qs("#ds-set-save");

  const email = qs("#ds-login-email");
  const pass = qs("#ds-login-pass");
  const biz2 = qs("#ds-login-biz");
  const btnLogin = qs("#ds-login-btn");
  const btnClear = qs("#ds-token-clear");
  const tokenPreview = qs("#ds-token-preview");

  btnSave.addEventListener("click", () => {
    ApiClient.setBaseUrl(baseUrl.value.trim());
    Storage.set("deepsleep.account_id", String(Number(accountId.value || 0) || ""));
    Storage.set("deepsleep.aws_account_id", aws.value.trim());
    Storage.set("deepsleep.business_id", biz.value.trim());

    Store.setState({
      account: { id: Number(accountId.value || 0), aws_account_id: aws.value.trim() },
      auth: { business_id: biz.value.trim() },
    });

    // update header chips
    renderUserInfo();
    const api = qs("#ds-api-indicator");
    if (api) api.textContent = ApiClient.getBaseUrl() || "—";

    toast("Settings", "Saved.");
  });

  btnLogin.addEventListener("click", async () => {
    try {
      ApiClient.setBaseUrl(baseUrl.value.trim());

      const payload = { email: email.value.trim(), password: pass.value, business_id: biz2.value.trim() };
      if (!payload.email || !payload.password || !payload.business_id) throw new Error("Missing email/password/business_id.");

      const resp = await Api.login(payload);
      const token = resp?.token;
      if (!token) throw new Error("No token returned.");

      Storage.set("deepsleep.token", token);
      Storage.set("deepsleep.email", payload.email);
      Storage.set("deepsleep.business_id", payload.business_id);

      Store.setState({ auth: { token, email: payload.email, business_id: payload.business_id } });
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
    renderUserInfo();
    toast("Auth", "Token cleared.");
  });
}
