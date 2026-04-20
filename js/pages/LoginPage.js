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
        <div class="ds-login-logo">
          <div class="ds-login-logo__mark" aria-hidden="true">
            <svg width="20" height="20" viewBox="0 0 16 16" fill="none" stroke="white" stroke-width="1.8">
              <path d="M3 8h10M8 3v10"/>
              <rect x="1.5" y="1.5" width="13" height="13" rx="2"/>
            </svg>
          </div>
          <div>
            <div class="ds-login-logo__name">DeepSleep</div>
            <div class="ds-login-logo__tag">AWS FinOps · EKS · RDS · EC2</div>
          </div>
        </div>

        <div class="ds-login-title">Sign in</div>
        <div class="ds-login-sub">Access your cloud cost control plane.</div>

        <div class="ds-login-form">
          <div class="ds-field">
            <label class="ds-label" for="ds-login-email">Email</label>
            <input
              class="ds-input"
              id="ds-login-email"
              type="email"
              value="${s.auth.email || ""}"
              placeholder="you@company.com"
              autocomplete="email"
            />
          </div>

          <div class="ds-field">
            <label class="ds-label" for="ds-login-pass">Password</label>
            <input
              class="ds-input"
              id="ds-login-pass"
              type="password"
              placeholder="••••••••"
              autocomplete="current-password"
            />
          </div>

          <div class="ds-field">
            <label class="ds-label" for="ds-login-biz">Business ID</label>
            <input
              class="ds-input"
              id="ds-login-biz"
              value="${s.auth.business_id || ""}"
              placeholder="your-business-id"
              autocomplete="organization"
            />
          </div>

          <button class="ds-btn ds-btn--primary" id="ds-login-btn" type="button" style="width:100%;justify-content:center;min-height:42px;">
            Sign in
          </button>

          <div id="ds-login-error" style="display:none;" class="ds-badge ds-badge--danger" style="width:100%;justify-content:center;">
          </div>
        </div>
      </div>
    </div>
  `;

  const email  = qs("#ds-login-email");
  const pass   = qs("#ds-login-pass");
  const biz    = qs("#ds-login-biz");
  const btn    = qs("#ds-login-btn");
  const errBox = qs("#ds-login-error");

  function showError(msg) {
    errBox.textContent = msg;
    errBox.style.display = "inline-flex";
  }

  function clearError() {
    errBox.style.display = "none";
  }

  async function doLogin() {
    clearError();

    const payload = {
      email: email.value.trim(),
      password: pass.value,
      business_id: biz.value.trim(),
    };

    if (!payload.email || !payload.password || !payload.business_id) {
      showError("Please fill in all fields.");
      return;
    }

    btn.disabled = true;
    btn.textContent = "Signing in…";

    try {
      const resp = await Api.login(payload);
      const token = resp?.token;
      if (!token) throw new Error("No token returned from server.");

      const jwt = decodeJwtPayload(token) || {};
      const roles = Array.isArray(jwt.roles) ? jwt.roles : [];
      const businessId = String(jwt.business_id || payload.business_id || "");

      Storage.set("deepsleep.token", token);
      Storage.set("deepsleep.email", payload.email);
      Storage.set("deepsleep.business_id", businessId);
      Storage.set("deepsleep.roles", roles.join(","));

      Store.setState({
        auth: { token, email: payload.email, business_id: businessId, roles },
        account: { id: 0, aws_account_id: "" },
        accounts: { list: [], loaded: false },
      });

      const next = `${window.location.pathname}${window.location.search}#/discovery`;
      window.location.replace(next);
      window.location.reload();
    } catch (e) {
      btn.disabled = false;
      btn.textContent = "Sign in";
      showError(e.message || "Login failed.");
    }
  }

  btn.addEventListener("click", doLogin);

  [email, pass, biz].forEach((input) => {
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") doLogin();
    });
  });

  // Focus first empty field
  if (!email.value) email.focus();
  else if (!pass.value) pass.focus();
  else btn.focus();
}
