#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

need() { [[ -f "$1" ]] || { echo "ERROR: missing $1"; exit 1; }; }

need "$ROOT/css/sidebar.css"
need "$ROOT/js/pages/LoginPage.js"

# ------------------------------------------------------------------
# 1) css/sidebar.css
#    - reserve fixed space on the right for the user bubble
#    - keep main pill centered
#    - prevent overlap
# ------------------------------------------------------------------
cat > "$ROOT/css/sidebar.css" <<'EOF'
#ds-rail > * {
  width: min(calc(100% - 32px), var(--ds-shell-main-max));
  margin: 0 auto;
}

.ds-rail-shell {
  position: relative;
  min-height: 76px;
  padding-right: 240px;
}

.ds-rail-main {
  width: max-content;
  max-width: 100%;
  margin: 0 auto;
  display: grid;
  grid-template-columns: auto auto;
  align-items: center;
  gap: 18px;
  padding: 10px 20px;
  background: rgba(17, 17, 17, 0.06);
  border: 1px solid rgba(17, 17, 17, 0.1);
  border-radius: 999px;
}

.ds-rail__brand {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.ds-brand__mark {
  width: 28px;
  height: 28px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--sky);
  flex: 0 0 auto;
}

.ds-brand__text {
  min-width: 0;
}

.ds-brand__name {
  font-size: 16px;
  font-weight: 600;
  color: var(--color_fg_bold);
  letter-spacing: -0.02em;
  line-height: 1.1;
}

.ds-brand__tag {
  margin-top: 2px;
  font-size: 12px;
  color: var(--color_fg_muted);
  white-space: nowrap;
  line-height: 1.2;
}

.ds-rail__nav {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  flex-wrap: nowrap;
  min-width: 0;
}

.ds-navlink {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-height: 40px;
  padding: 0 14px;
  border-radius: 999px;
  color: var(--color_fg_muted);
  border: 1px solid transparent;
  background: transparent;
  white-space: nowrap;
  flex: 0 0 auto;
}

.ds-navlink:hover {
  color: var(--color_fg_bold);
  background: rgba(255, 255, 255, 0.7);
  border-color: var(--functional-gray-200);
}

.ds-navlink[aria-current="page"] {
  background: var(--functional-gray-0);
  color: var(--color_fg_bold);
  border-color: var(--functional-gray-200);
  box-shadow: var(--ds-shadow-1);
}

.ds-navlink__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: inherit;
}

.ds-navlink__label {
  font-size: 14px;
  line-height: 1;
  white-space: nowrap;
}

.ds-rail__user {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

.ds-userchip {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  min-height: 42px;
  padding: 6px 12px;
  border-radius: 999px;
  border: 1px solid var(--color_border_default);
  background: var(--functional-gray-0);
  color: var(--color_fg_bold);
  box-shadow: var(--ds-shadow-1);
  max-width: 220px;
}

.ds-userchip:hover {
  background: var(--functional-gray-50);
  border-color: var(--functional-gray-250);
}

.ds-userchip__dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: var(--sky);
  box-shadow: 0 0 0 4px rgba(63, 89, 228, 0.12);
}

.ds-userchip__text {
  font-size: 14px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.ds-userchip__caret {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--functional-gray-450);
  flex: 0 0 auto;
}

.ds-dropdown {
  position: absolute;
  top: calc(100% + 10px);
  right: 0;
  width: min(360px, calc(100vw - 24px));
  background: var(--color_bg_layer);
  border: 1px solid var(--color_border_default);
  border-radius: 20px;
  box-shadow: var(--ds-shadow-2);
  padding: 14px;
  z-index: 110;
}

.ds-dropdown__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  min-height: 40px;
  padding: 6px 4px;
}

.ds-dropdown__k {
  font-size: 13px;
  color: var(--color_fg_muted);
  flex: 0 0 auto;
}

.ds-dropdown__v {
  font-size: 14px;
  color: var(--color_fg_bold);
  text-align: right;
  min-width: 0;
  overflow-wrap: anywhere;
}

.ds-dropdown__sep {
  height: 1px;
  background: var(--functional-gray-150);
  margin: 8px 0;
}

@media (max-width: 1380px) {
  .ds-rail-shell {
    padding-right: 220px;
  }

  .ds-userchip {
    max-width: 200px;
  }
}

@media (max-width: 1180px) {
  .ds-rail-shell {
    min-height: unset;
    display: grid;
    gap: 12px;
    padding-right: 0;
  }

  .ds-rail-main {
    width: 100%;
    max-width: 100%;
    grid-template-columns: 1fr;
    justify-items: center;
    border-radius: 24px;
  }

  .ds-rail__nav {
    overflow-x: auto;
    width: 100%;
    justify-content: flex-start;
    padding-bottom: 2px;
    scrollbar-width: thin;
  }

  .ds-rail__user {
    position: static;
    transform: none;
    justify-content: center;
  }

  .ds-brand__text {
    text-align: center;
  }

  .ds-userchip {
    max-width: none;
  }
}
EOF

# ------------------------------------------------------------------
# 2) js/pages/LoginPage.js
#    - on successful login, force a clean route transition
#    - replace hash and reload once so login page disappears and app shell loads
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/LoginPage.js" <<'EOF'
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
EOF

echo "OK: rewrote css/sidebar.css"
echo "OK: rewrote js/pages/LoginPage.js"
echo "Done."
