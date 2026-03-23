#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

mkdir -p \
  "$ROOT/css" \
  "$ROOT/js/components" \
  "$ROOT/js/pages"

need() { [[ -f "$1" ]] || { echo "ERROR: missing $1"; exit 1; }; }

need "$ROOT/css/main.css"
need "$ROOT/css/header.css"
need "$ROOT/css/sidebar.css"
need "$ROOT/js/components/Header.js"
need "$ROOT/js/components/Sidebar.js"
need "$ROOT/js/components/UserDropdown.js"
need "$ROOT/js/pages/LoginPage.js"
need "$ROOT/app.js"

# ------------------------------------------------------------------
# 1) css/main.css
# ------------------------------------------------------------------
cat > "$ROOT/css/main.css" <<'EOF'
:root {
  --functional-gray-0: #ffffff;
  --functional-gray-50: #fbfbfb;
  --functional-gray-100: #f6f6f6;
  --functional-gray-150: #f1f1f1;
  --functional-gray-200: #e5e5e5;
  --functional-gray-250: #d7d7d7;
  --functional-gray-300: #c5c5c5;
  --functional-gray-350: #b9b9b9;
  --functional-gray-400: #ababab;
  --functional-gray-450: #8e8e8e;
  --functional-gray-500: #808080;
  --functional-gray-550: #686868;
  --functional-gray-600: #555555;
  --functional-gray-650: #3e3e3e;
  --functional-gray-700: #383838;
  --functional-gray-750: #2a2a2a;
  --functional-gray-800: #242424;
  --functional-gray-850: #1e1e1e;
  --functional-gray-900: #171717;
  --functional-gray-950: #111111;

  --charcoal2: #191919;
  --violet: #7549f2;
  --sky: #3f59e4;
  --success: #149750;
  --success-bg: #e6f4ec;
  --danger-bg: #fbeeed;
  --warning-bg: #fff5d6;
  --warning-fg: #7a6410;
  --violet-bg: #f2efff;
  --violet-fg: #5b43c8;

  --color_bg_page: var(--functional-gray-100);
  --color_bg_layer: var(--functional-gray-0);
  --color_fg_bold: var(--charcoal2);
  --color_fg_default: var(--functional-gray-650);
  --color_fg_muted: var(--functional-gray-500);
  --color_border_default: var(--functional-gray-200);
  --color_border_focus: var(--functional-gray-850);

  --color_bg_button: var(--functional-gray-0);
  --color_bg_button_hover: var(--functional-gray-150);
  --color_bg_button_pressed: #e8e8e8;
  --color_fg_on_button: var(--charcoal2);
  --color_border_button: var(--functional-gray-250);

  --color_bg_button_primary: var(--sky);
  --color_bg_button_primary_hover: #3449ba;
  --color_bg_button_primary_pressed: #263588;
  --color_fg_on_button_primary: #ffffff;

  --ds-font-sans: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  --ds-font-mono: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;

  --ds-radius-sm: 12px;
  --ds-radius-md: 16px;
  --ds-radius-lg: 20px;
  --ds-radius-xl: 24px;
  --ds-radius-pill: 999px;

  --ds-shadow-1: 0 1px 2px rgba(17, 17, 17, 0.04);
  --ds-shadow-2: 0 8px 24px rgba(17, 17, 17, 0.06);

  --ds-shell-main-max: 1344px;
}

html,
body {
  width: 100%;
  min-height: 100%;
  background: var(--color_bg_page);
  color: var(--color_fg_default);
  font-family: var(--ds-font-sans);
  font-weight: 400;
  -ms-text-size-adjust: 100%;
  -webkit-text-size-adjust: 100%;
  scrollbar-gutter: stable;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
  outline: none;
}

a {
  color: inherit;
  text-decoration: none;
}

button,
input,
select,
textarea {
  font: inherit;
  color: inherit;
}

button {
  cursor: pointer;
  border: 0;
  background: transparent;
}

body {
  overflow-x: hidden;
}

#ds-app {
  min-height: 100vh;
  display: grid;
  grid-template-rows: auto auto 1fr;
}

#ds-rail {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--color_bg_page);
  padding: 10px 16px 0 16px;
}

#ds-topbar {
  padding: 10px 16px 0 16px;
}

#ds-main {
  width: min(calc(100% - 32px), var(--ds-shell-main-max));
  margin: 12px auto 0 auto;
  padding: 0 0 40px 0;
}

#ds-page {
  min-width: 0;
}

.ds-panel,
.ds-tablewrap,
.ds-modal,
.ds-dropdown,
.ds-search,
.ds-userchip,
.ds-navlink,
.ds-btn,
.ds-input,
.ds-select,
.ds-textarea,
.ds-badge,
.ds-tabs,
.ds-login-shell,
.ds-login-card {
  transition:
    background-color 140ms ease,
    border-color 140ms ease,
    color 140ms ease,
    box-shadow 140ms ease;
}

.ds-panel,
.ds-tablewrap,
.ds-login-card {
  background: var(--color_bg_layer);
  border: 1px solid var(--color_border_default);
  border-radius: var(--ds-radius-lg);
  box-shadow: var(--ds-shadow-1);
}

.ds-panel {
  margin: 0 0 16px 0;
}

.ds-panel__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding: 20px 20px 0 20px;
  margin-bottom: 16px;
}

.ds-panel__title {
  font-size: 18px;
  line-height: 1.35;
  font-weight: 500;
  color: var(--color_fg_bold);
  letter-spacing: -0.02em;
}

.ds-panel__sub {
  margin-top: 4px;
  font-size: 14px;
  line-height: 1.55;
  color: var(--color_fg_muted);
}

.ds-row {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.ds-field {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 180px;
}

.ds-label {
  font-size: 13px;
  line-height: 1.4;
  color: var(--color_fg_muted);
}

.ds-input,
.ds-select,
.ds-textarea {
  width: 100%;
  min-height: 44px;
  background: var(--functional-gray-0);
  border: 1px solid var(--color_border_default);
  border-radius: var(--ds-radius-md);
  padding: 10px 14px;
  color: var(--color_fg_bold);
}

.ds-input::placeholder,
.ds-textarea::placeholder {
  color: var(--functional-gray-450);
}

.ds-input:focus,
.ds-select:focus,
.ds-textarea:focus {
  border-color: var(--color_border_focus);
  box-shadow: 0 0 0 3px rgba(63, 89, 228, 0.12);
}

.ds-textarea {
  min-height: 120px;
  resize: vertical;
}

.ds-btn {
  min-height: 40px;
  padding: 8px 14px;
  border-radius: var(--ds-radius-pill);
  border: 1px solid var(--color_border_button);
  background: var(--color_bg_button);
  color: var(--color_fg_on_button);
  font-size: 14px;
  line-height: 1.3;
}

.ds-btn:hover {
  background: var(--color_bg_button_hover);
}

.ds-btn:active {
  background: var(--color_bg_button_pressed);
}

.ds-btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.ds-btn--wake {
  background: var(--color_bg_button_primary);
  border-color: var(--color_bg_button_primary);
  color: var(--color_fg_on_button_primary);
}

.ds-btn--wake:hover {
  background: var(--color_bg_button_primary_hover);
  border-color: var(--color_bg_button_primary_hover);
}

.ds-btn--wake:active {
  background: var(--color_bg_button_primary_pressed);
  border-color: var(--color_bg_button_primary_pressed);
}

.ds-btn--sleep {
  background: var(--functional-gray-0);
  border-color: var(--color_border_button);
  color: var(--charcoal2);
}

.ds-btn--ghost {
  background: transparent;
}

.ds-btn--danger {
  background: var(--danger-bg);
  border-color: #efcfc9;
  color: #8d231d;
}

.ds-btn--danger:hover {
  background: #f8e1df;
}

.ds-badge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-height: 32px;
  padding: 6px 12px;
  border-radius: var(--ds-radius-pill);
  border: 1px solid var(--color_border_default);
  background: var(--functional-gray-50);
  color: var(--color_fg_muted);
  font-size: 13px;
  line-height: 1.2;
}

.ds-badge--success-matte {
  background: var(--success-bg);
  border-color: #cde7d5;
  color: var(--success);
}

.ds-badge--warning-matte {
  background: var(--warning-bg);
  border-color: #efdf9f;
  color: var(--warning-fg);
}

.ds-badge--danger-matte {
  background: var(--danger-bg);
  border-color: #efcfc9;
  color: #8d231d;
}

.ds-badge--violet-matte {
  background: var(--violet-bg);
  border-color: #ddd4ff;
  color: var(--violet-fg);
}

.ds-mono-muted {
  color: var(--color_fg_muted);
  font-family: var(--ds-font-mono);
  font-size: 12px;
  line-height: 1.5;
}

.ds-tablewrap {
  overflow: auto;
  padding: 0;
}

.ds-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  min-width: 860px;
}

.ds-table thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--functional-gray-50);
  color: var(--color_fg_muted);
  font-size: 12px;
  font-weight: 500;
  text-align: left;
  padding: 14px 16px;
  border-bottom: 1px solid var(--color_border_default);
  white-space: nowrap;
}

.ds-table tbody td {
  padding: 14px 16px;
  border-bottom: 1px solid var(--functional-gray-150);
  color: var(--color_fg_default);
  font-size: 14px;
  vertical-align: middle;
}

.ds-table tbody tr:last-child td {
  border-bottom: 0;
}

.ds-table tbody tr:hover td {
  background: #fafafa;
}

.ds-tabs {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px;
  background: var(--functional-gray-150);
  border: 1px solid var(--color_border_default);
  border-radius: 999px;
}

.ds-tab {
  min-height: 36px;
  padding: 0 14px;
  border-radius: 999px;
  border: 1px solid transparent;
  background: transparent;
  color: var(--color_fg_muted);
  font-size: 14px;
}

.ds-tab:hover {
  color: var(--color_fg_bold);
}

.ds-tab[aria-selected="true"] {
  background: var(--functional-gray-0);
  color: var(--color_fg_bold);
  border-color: var(--functional-gray-200);
}

.ds-modalbackdrop {
  position: fixed;
  inset: 0;
  background: rgba(17, 17, 17, 0.18);
  backdrop-filter: blur(3px);
  z-index: 100;
}

.ds-modal {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: min(900px, calc(100vw - 32px));
  max-height: 88vh;
  overflow: hidden;
  background: var(--color_bg_layer);
  border: 1px solid var(--color_border_default);
  border-radius: var(--ds-radius-xl);
  box-shadow: var(--ds-shadow-2);
  z-index: 101;
  display: flex;
  flex-direction: column;
}

.ds-modal__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 20px 20px 16px 20px;
  border-bottom: 1px solid var(--functional-gray-150);
}

.ds-modal__title {
  font-size: 18px;
  font-weight: 500;
  color: var(--color_fg_bold);
  letter-spacing: -0.02em;
}

.ds-modal__body {
  padding: 20px;
  overflow: auto;
}

.ds-modal__foot {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 16px 20px 20px 20px;
  border-top: 1px solid var(--functional-gray-150);
}

.ds-login-shell {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.ds-login-card {
  width: min(100%, 520px);
  padding: 28px;
  border-radius: var(--ds-radius-xl);
}

.ds-login-brand {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 20px;
}

.ds-login-brand__mark {
  width: 32px;
  height: 32px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--sky);
}

.ds-login-brand__name {
  font-size: 28px;
  line-height: 1.1;
  font-weight: 600;
  color: var(--color_fg_bold);
  letter-spacing: -0.03em;
}

.ds-login-brand__tag {
  margin-top: 4px;
  font-size: 13px;
  color: var(--color_fg_muted);
}

.ds-hidden {
  display: none !important;
}

@media (max-width: 1100px) {
  #ds-main {
    width: min(calc(100% - 20px), var(--ds-shell-main-max));
  }

  .ds-panel__head {
    flex-direction: column;
    align-items: stretch;
  }
}

@media (max-width: 820px) {
  #ds-main {
    width: min(calc(100% - 16px), var(--ds-shell-main-max));
    margin-top: 10px;
  }

  .ds-table {
    min-width: 760px;
  }

  .ds-modal {
    width: min(100vw - 16px, 900px);
    max-height: 92vh;
  }

  .ds-login-card {
    padding: 22px;
  }
}
EOF

# ------------------------------------------------------------------
# 2) css/header.css
# ------------------------------------------------------------------
cat > "$ROOT/css/header.css" <<'EOF'
#ds-topbar {
  width: min(calc(100% - 32px), var(--ds-shell-main-max));
  margin: 0 auto;
}

.ds-topbar {
  display: block;
}

.ds-topbar__searchwrap {
  width: 100%;
  display: flex;
  align-items: center;
}

.ds-search {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  min-height: 48px;
  padding: 0 14px;
  background: var(--functional-gray-0);
  border: 1px solid var(--color_border_default);
  border-radius: 16px;
  box-shadow: var(--ds-shadow-1);
}

.ds-search:hover {
  border-color: var(--functional-gray-250);
}

.ds-search:focus-within {
  border-color: var(--color_border_focus);
  box-shadow: 0 0 0 3px rgba(63, 89, 228, 0.12);
}

.ds-search__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--functional-gray-450);
  flex: 0 0 auto;
}

.ds-search__input {
  width: 100%;
  min-width: 0;
  height: 44px;
  border: 0;
  background: transparent;
  color: var(--color_fg_bold);
  padding: 0;
}

.ds-search__input::placeholder {
  color: var(--functional-gray-450);
}
EOF

# ------------------------------------------------------------------
# 3) css/sidebar.css
# ------------------------------------------------------------------
cat > "$ROOT/css/sidebar.css" <<'EOF'
#ds-rail > * {
  width: min(calc(100% - 32px), var(--ds-shell-main-max));
  margin: 0 auto;
}

.ds-rail-shell {
  position: relative;
  min-height: 76px;
}

.ds-rail-main {
  width: max-content;
  max-width: calc(100% - 220px);
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
}

.ds-userchip__caret {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--functional-gray-450);
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

@media (max-width: 1280px) {
  .ds-rail-main {
    max-width: calc(100% - 180px);
  }
}

@media (max-width: 1120px) {
  .ds-rail-shell {
    min-height: unset;
    display: grid;
    gap: 12px;
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
}
EOF

# ------------------------------------------------------------------
# 4) js/components/Header.js
# ------------------------------------------------------------------
cat > "$ROOT/js/components/Header.js" <<'EOF'
export function renderHeader() {
  return `
    <div class="ds-topbar">
      <div class="ds-topbar__searchwrap">
        <label class="ds-search" aria-label="Recherche">
          <span class="ds-search__icon" aria-hidden="true">
            <svg width="18" height="18" viewBox="0 0 18 18">
              <circle cx="8" cy="8" r="5" fill="none" stroke="currentColor" stroke-width="1.7"/>
              <path d="M12.5 12.5L16 16" fill="none" stroke="currentColor" stroke-width="1.7"/>
            </svg>
          </span>
          <input id="ds-global-search" class="ds-search__input" type="search" placeholder="Filter resources by name / region / type…" autocomplete="off" />
        </label>
      </div>
    </div>
  `;
}
EOF

# ------------------------------------------------------------------
# 5) js/components/Sidebar.js
# ------------------------------------------------------------------
cat > "$ROOT/js/components/Sidebar.js" <<'EOF'
import { Store } from "../store.js";

function isAdmin() {
  return (Store.getState().auth.roles || []).includes("ADMIN");
}

export function renderSidebar() {
  const admin = isAdmin();

  return `
    <div class="ds-rail-shell">
      <div class="ds-rail-main">
        <div class="ds-rail__brand">
          <div class="ds-brand__mark" aria-hidden="true">
            <svg width="20" height="20" viewBox="0 0 20 20" role="img" aria-label="Logo">
              <rect x="2" y="2" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"></rect>
              <path d="M6 10h8" stroke="currentColor" stroke-width="2"></path>
            </svg>
          </div>
          <div class="ds-brand__text">
            <div class="ds-brand__name">DeepSleep</div>
            <div class="ds-brand__tag">AWS FinOps • EKS/RDS</div>
          </div>
        </div>

        <nav class="ds-rail__nav">
          <a class="ds-navlink" href="#/discovery" data-route="discovery">
            <span class="ds-navlink__icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 18 18">
                <path d="M2 7h14M2 11h14M4 3h10M4 15h10" fill="none" stroke="currentColor" stroke-width="1.7"/>
              </svg>
            </span>
            <span class="ds-navlink__label">Discovery</span>
          </a>

          <a class="ds-navlink" href="#/active" data-route="active">
            <span class="ds-navlink__icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 18 18">
                <path d="M4 14V4h10v10H4Z" fill="none" stroke="currentColor" stroke-width="1.7"/>
                <path d="M6 6h6M6 9h6M6 12h4" fill="none" stroke="currentColor" stroke-width="1.7"/>
              </svg>
            </span>
            <span class="ds-navlink__label">Active Resources</span>
          </a>

          <a class="ds-navlink" href="#/policies" data-route="policies">
            <span class="ds-navlink__icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 18 18">
                <path d="M3 4h12v10H3V4Z" fill="none" stroke="currentColor" stroke-width="1.7"/>
                <path d="M5 7h8M5 10h6" fill="none" stroke="currentColor" stroke-width="1.7"/>
              </svg>
            </span>
            <span class="ds-navlink__label">Time Policies</span>
          </a>

          <a class="ds-navlink" href="#/settings" data-route="settings">
            <span class="ds-navlink__icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 18 18">
                <path d="M9 11.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z" fill="none" stroke="currentColor" stroke-width="1.7"/>
                <path d="M3 9l1.6-.6.2-1.8L3.7 5.3 5.3 3.7l1.3 1.1 1.8-.2L9 3l.6 1.6 1.8.2 1.3-1.1 1.6 1.6-1.1 1.3.2 1.8L15 9l-1.6.6-.2 1.8 1.1 1.3-1.6 1.6-1.3-1.1-1.8.2L9 15l-.6-1.6-1.8-.2-1.3 1.1-1.6-1.6 1.1-1.3-.2-1.8L3 9Z" fill="none" stroke="currentColor" stroke-width="1.3"/>
              </svg>
            </span>
            <span class="ds-navlink__label">Sleep Plans</span>
          </a>

          <a class="ds-navlink" href="#/savings" data-route="savings">
            <span class="ds-navlink__icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 18 18">
                <path d="M3 13h12M5 11V6M9 11V4M13 11V8" fill="none" stroke="currentColor" stroke-width="1.7"/>
              </svg>
            </span>
            <span class="ds-navlink__label">Savings</span>
          </a>

          <a class="ds-navlink" href="#/history" data-route="history">
            <span class="ds-navlink__icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 18 18">
                <path d="M9 3v6l4 2" fill="none" stroke="currentColor" stroke-width="1.7"/>
                <circle cx="9" cy="9" r="6" fill="none" stroke="currentColor" stroke-width="1.7"/>
              </svg>
            </span>
            <span class="ds-navlink__label">History</span>
          </a>

          ${admin ? `
          <a class="ds-navlink" href="#/users" data-route="users">
            <span class="ds-navlink__icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 18 18">
                <circle cx="6" cy="7" r="2.2" fill="none" stroke="currentColor" stroke-width="1.5"/>
                <circle cx="12" cy="7" r="2.2" fill="none" stroke="currentColor" stroke-width="1.5"/>
                <path d="M2.8 14c.8-1.8 2.2-2.8 4.2-2.8s3.4 1 4.2 2.8" fill="none" stroke="currentColor" stroke-width="1.5"/>
                <path d="M8.8 14c.7-1.5 1.8-2.3 3.2-2.3 1.4 0 2.5.8 3.2 2.3" fill="none" stroke="currentColor" stroke-width="1.5"/>
              </svg>
            </span>
            <span class="ds-navlink__label">Manage Users</span>
          </a>
          ` : ""}
        </nav>
      </div>

      <div class="ds-rail__user">
        <button class="ds-userchip" id="ds-userchip" type="button" aria-haspopup="menu" aria-expanded="false">
          <span class="ds-userchip__dot" aria-hidden="true"></span>
          <span class="ds-userchip__text" id="ds-userchip-text">User</span>
          <span class="ds-userchip__caret" aria-hidden="true">
            <svg width="14" height="14" viewBox="0 0 14 14">
              <path d="M3 5l4 4 4-4" fill="none" stroke="currentColor" stroke-width="1.7"/>
            </svg>
          </span>
        </button>

        <div class="ds-dropdown" id="ds-user-dropdown" role="menu" aria-label="Profil" hidden>
          <div class="ds-dropdown__row">
            <div class="ds-dropdown__k">Name</div>
            <div class="ds-dropdown__v" id="ds-dd-name">—</div>
          </div>
          <div class="ds-dropdown__row">
            <div class="ds-dropdown__k">AWS Account</div>
            <div class="ds-dropdown__v" id="ds-dd-aws">—</div>
          </div>
          <div class="ds-dropdown__row">
            <div class="ds-dropdown__k">Business ID</div>
            <div class="ds-dropdown__v" id="ds-dd-biz">—</div>
          </div>
          <div class="ds-dropdown__row">
            <div class="ds-dropdown__k">Switch Account</div>
            <div class="ds-dropdown__v" style="min-width:180px;max-width:none;">
              <select class="ds-select" id="ds-account-switch" style="min-width:180px;">
                <option value="">(loading...)</option>
              </select>
            </div>
          </div>
          <div class="ds-dropdown__sep" aria-hidden="true"></div>
          <div class="ds-dropdown__row">
            <button class="ds-btn ds-btn--ghost" id="ds-logout-btn" type="button">Logout</button>
          </div>
        </div>
      </div>
    </div>
  `;
}

export function setActiveNav(routeName) {
  document.querySelectorAll(".ds-navlink").forEach((a) => {
    const hit = a.dataset.route === routeName;
    if (hit) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  });
}
EOF

# ------------------------------------------------------------------
# 6) js/components/UserDropdown.js
# ------------------------------------------------------------------
cat > "$ROOT/js/components/UserDropdown.js" <<'EOF'
import { qs } from "../utils/dom.js";
import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { Storage } from "../utils/storage.js";
import * as Api from "../api/services.js";

let docBound = false;

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
  const switcher = qs("#ds-account-switch");

  if (!userchip || !dropdown) return;

  userchip.onclick = async () => {
    const expanded = userchip.getAttribute("aria-expanded") === "true";
    userchip.setAttribute("aria-expanded", expanded ? "false" : "true");
    dropdown.hidden = expanded;
    if (!expanded) {
      await loadAccountsIntoDropdown();
    }
  };

  if (!docBound) {
    document.addEventListener("click", (e) => {
      const chip = qs("#ds-userchip");
      const dd = qs("#ds-user-dropdown");
      if (!chip || !dd) return;
      const inside = chip.contains(e.target) || dd.contains(e.target);
      if (!inside) {
        chip.setAttribute("aria-expanded", "false");
        dd.hidden = true;
      }
    });
    docBound = true;
  }

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

  if (logout && !logout.dataset.bound) {
    logout.dataset.bound = "1";
    logout.addEventListener("click", () => {
      Storage.del("deepsleep.token");
      Storage.del("deepsleep.account_id");
      Storage.del("deepsleep.aws_account_id");
      Storage.del("deepsleep.roles");

      Store.setState({
        auth: { token: "", email: "", business_id: "", roles: [] },
        account: { id: 0, aws_account_id: "" },
        accounts: { list: [], loaded: false },
      });

      toast("Session", "Logged out.");
      const chip = qs("#ds-userchip");
      const dd = qs("#ds-user-dropdown");
      if (chip) chip.setAttribute("aria-expanded", "false");
      if (dd) dd.hidden = true;
      location.hash = "#/login";
      window.dispatchEvent(new Event("hashchange"));
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

export function rebindUserDropdownAfterRerender() {
  bindUserDropdown();
  renderUserInfo();
}
EOF

# ------------------------------------------------------------------
# 7) js/pages/LoginPage.js
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
      location.hash = "#/discovery";
      window.dispatchEvent(new Event("hashchange"));
    } catch (e) {
      toast("Auth", e.message || "Login failed");
    }
  });
}
EOF

# ------------------------------------------------------------------
# 8) app.js
# ------------------------------------------------------------------
cat > "$ROOT/app.js" <<'EOF'
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
  const main = qs("#ds-main");

  if (rail) {
    rail.classList.remove("ds-hidden");
    rail.innerHTML = renderSidebar();
  }
  if (topbar) {
    topbar.classList.remove("ds-hidden");
    topbar.innerHTML = renderHeader();
  }
  if (main) {
    main.style.marginTop = "12px";
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
  const main = qs("#ds-main");

  if (rail) {
    rail.innerHTML = "";
    rail.classList.add("ds-hidden");
  }
  if (topbar) {
    topbar.innerHTML = "";
    topbar.classList.add("ds-hidden");
  }
  if (main) {
    main.style.marginTop = "0";
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
    router.render({ name: "login", params: {} });
    return;
  }

  if (route.name === "login") {
    location.hash = "#/discovery";
    return;
  }

  showShell();
  await loadAccountsIntoDropdown();

  Store.setState({ route });
  setActiveNav(route.name);
  router.render(route);

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

echo "OK: rewrote css/main.css"
echo "OK: rewrote css/header.css"
echo "OK: rewrote css/sidebar.css"
echo "OK: rewrote js/components/Header.js"
echo "OK: rewrote js/components/Sidebar.js"
echo "OK: rewrote js/components/UserDropdown.js"
echo "OK: rewrote js/pages/LoginPage.js"
echo "OK: rewrote app.js"
echo "Done."
