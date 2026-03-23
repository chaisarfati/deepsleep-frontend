import { Store } from "../store.js";
import { Storage } from "../utils/storage.js";
import { toast } from "../utils/toast.js";
import { qs } from "../utils/dom.js";
import * as Api from "../api/services.js";

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

export async function LoginPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  page.innerHTML = `
    <div class="ds-login-shell">
      <div class="ds-login-card">
        <div class="ds-login-brand">
          <div class="ds-login-brand__mark" aria-hidden="true">
            <svg width="28" height="28" viewBox="0 0 20 20" role="img" aria-label="Logo">
              <rect x="2" y="2" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"></rect>
              <path d="M6 10h8" stroke="currentColor" stroke-width="2"></path>
            </svg>
          </div>
          <div>
            <div class="ds-login-brand__name">DeepSleep</div>
            <div class="ds-login-brand__tag">AWS FinOps • EKS/RDS</div>
          </div>
        </div>

        <div class="ds-panel" style="margin:0;box-shadow:none;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Login</div>
              <div class="ds-panel__sub">Business user authentication</div>
            </div>
          </div>

          <div style="padding:0 20px 20px 20px;display:grid;grid-template-columns:1fr;gap:12px;">
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
            </div>
          </div>
        </div>
      </div>
    </div>
  `;

  const email = qs("#ds-login-email");
  const pass = qs("#ds-login-pass");
  const biz = qs("#ds-login-biz");
  const btnLogin = qs("#ds-login-btn");

  btnLogin.addEventListener("click", async () => {
    try {
      const payload = {
        email: email.value.trim(),
        password: pass.value,
        business_id: biz.value.trim(),
      };

      if (!payload.email || !payload.password || !payload.business_id) {
        throw new Error("Missing email/password/business_id.");
      }

      btnLogin.disabled = true;

      const resp = await Api.login(payload);
      const token = resp?.token;
      if (!token) throw new Error("No token returned.");

      const jwt = decodeJwtPayload(token) || {};
      const roles = Array.isArray(jwt.roles) ? jwt.roles : [];
      const businessId = String(jwt.business_id || payload.business_id || "");

      Storage.set("deepsleep.token", token);
      Storage.set("deepsleep.email", payload.email);
      Storage.set("deepsleep.business_id", businessId);
      Storage.set("deepsleep.roles", roles.join(","));

      Store.setState({
        auth: {
          token,
          email: payload.email,
          business_id: businessId,
          roles,
        },
        account: { id: 0, aws_account_id: "" },
        accounts: { list: [], loaded: false },
      });

      toast("Auth", "Login OK.");

      const next = `${window.location.pathname}${window.location.search}#/discovery`;
      window.location.replace(next);
      window.location.reload();
    } catch (e) {
      btnLogin.disabled = false;
      toast("Auth", e.message || "Login failed");
    }
  });
}
