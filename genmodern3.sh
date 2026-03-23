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
need "$ROOT/js/components/Pills.js"
need "$ROOT/js/pages/ActiveResourcesPage.js"
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
  --functional-gray-1000: #000000;

  --charcoal2: #191919;
  --violet: #7549f2;
  --sky: #3f59e4;
  --tangerine: #e27133;
  --success: #149750;
  --success-bg: #e6f4ec;
  --danger: #c32f26;
  --danger-bg: #fbeeed;
  --warning: #d8b437;
  --warning-bg: #fff5d6;
  --warning-fg: #7a6410;
  --violet-bg: #f2efff;
  --violet-fg: #5b43c8;

  --color_bg_page: var(--functional-gray-100);
  --color_bg_layer: var(--functional-gray-0);
  --color_bg_layer_alt: var(--functional-gray-50);
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

  --ds-shell-bar-max: 1120px;
  --ds-shell-main-max: 1344px;
}

html {
  -ms-text-size-adjust: 100%;
  -webkit-text-size-adjust: 100%;
  scrollbar-gutter: stable;
}

html,
body {
  width: 100%;
  min-height: 100%;
  background: var(--color_bg_page);
  color: var(--color_fg_default);
  font-family: var(--ds-font-sans);
  font-weight: 400;
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
  padding: 14px 16px 0 16px;
}

#ds-topbar {
  padding: 12px 16px 0 16px;
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
.ds-tabs {
  transition:
    background-color 140ms ease,
    border-color 140ms ease,
    color 140ms ease,
    box-shadow 140ms ease;
}

.ds-panel,
.ds-tablewrap {
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

.ds-rail {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: 18px;
}

.ds-rail__brand {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
  justify-self: start;
}

.ds-brand__mark {
  width: 28px;
  height: 28px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--sky);
}

.ds-brand__text {
  min-width: 0;
}

.ds-brand__name {
  font-size: 16px;
  font-weight: 600;
  color: var(--color_fg_bold);
  letter-spacing: -0.02em;
}

.ds-brand__tag {
  font-size: 12px;
  color: var(--color_fg_muted);
  white-space: nowrap;
}

.ds-rail__nav {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  flex-wrap: wrap;
  padding: 6px;
  background: rgba(17, 17, 17, 0.06);
  border: 1px solid rgba(17, 17, 17, 0.1);
  border-radius: 999px;
  justify-self: center;
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
  display: flex;
  align-items: center;
  justify-content: flex-end;
  justify-self: end;
  position: relative;
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

@media (max-width: 1180px) {
  .ds-rail {
    grid-template-columns: 1fr;
    gap: 14px;
  }

  .ds-rail__brand,
  .ds-rail__nav,
  .ds-rail__user {
    justify-self: center;
  }

  .ds-brand__text {
    text-align: center;
  }
}

@media (max-width: 700px) {
  .ds-rail__nav {
    justify-content: flex-start;
    overflow-x: auto;
    flex-wrap: nowrap;
    padding-bottom: 2px;
    scrollbar-width: thin;
    width: 100%;
  }

  .ds-navlink {
    flex: 0 0 auto;
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
    <div class="ds-rail">
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

let isBound = false;
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

      Store.setState({
        auth: { token: "" },
        account: { id: 0, aws_account_id: "" },
        accounts: { list: [], loaded: false },
      });

      toast("Session", "Logged out.");
      const chip = qs("#ds-userchip");
      const dd = qs("#ds-user-dropdown");
      if (chip) chip.setAttribute("aria-expanded", "false");
      if (dd) dd.hidden = true;
      location.hash = "#/login";
    });
  }

  isBound = true;
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
# 7) js/components/Pills.js
# ------------------------------------------------------------------
cat > "$ROOT/js/components/Pills.js" <<'EOF'
import { escapeHtml as h } from "../utils/dom.js";

function normalizeState(value) {
  return String(value || "").trim().toUpperCase();
}

function stateMeta(state, lockedUntil) {
  if (lockedUntil && new Date(lockedUntil).getTime() > Date.now()) {
    return {
      cls: "ds-badge--warning-matte",
      label: "LOCKED",
    };
  }

  if (state === "RUNNING") {
    return {
      cls: "ds-badge--success-matte",
      label: "RUNNING",
    };
  }

  if (state === "SLEEPING") {
    return {
      cls: "ds-badge--violet-matte",
      label: "SLEEPING",
    };
  }

  if (state === "ERROR" || state === "FAILED") {
    return {
      cls: "ds-badge--danger-matte",
      label: state || "ERROR",
    };
  }

  return {
    cls: "ds-badge--violet-matte",
    label: state || "UNKNOWN",
  };
}

export function renderStatePill(state, lockedUntil = null) {
  const normalized = normalizeState(state);
  const meta = stateMeta(normalized, lockedUntil);
  return `<span class="ds-badge ${meta.cls}">${h(meta.label)}</span>`;
}
EOF

# ------------------------------------------------------------------
# 8) js/pages/ActiveResourcesPage.js
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/ActiveResourcesPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { applyTableFilter } from "../components/TableFilters.js";
import { renderActiveRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

const PRICING_TTL_MS = 60 * 60 * 1000;
const pricingCache = new Map();
let activeRenderToken = 0;

function sleepPlanTypeForResource(resourceType) {
  if (resourceType === "EKS_CLUSTER") return "EKS_CLUSTER_SLEEP";
  if (resourceType === "RDS_INSTANCE") return "RDS_SLEEP";
  return null;
}

function pricingKey(row) {
  return `${row.resource_type}|${row.resource_name}|${row.region}`;
}

function fmtMoneyPerHour(v) {
  if (v === null || v === undefined || v === "") return "—";
  const n = Number(v);
  if (!Number.isFinite(n)) return "—";
  return `$${n}/hour`;
}

function getCachedPricing(row) {
  const cached = pricingCache.get(pricingKey(row));
  if (!cached) return null;
  if ((Date.now() - cached.ts) > PRICING_TTL_MS) return null;
  return cached;
}

function setCachedPricing(row, cost, savings) {
  pricingCache.set(pricingKey(row), {
    cost,
    savings,
    ts: Date.now(),
  });
}

function patchPricingCells(key, cost, savings) {
  const tr = document.querySelector(`tr[data-key="${key.replaceAll('"','\\"')}"]`);
  if (!tr) return;

  const costTd = tr.querySelector('td[data-col="compute-cost"]');
  const savingsTd = tr.querySelector('td[data-col="compute-savings"]');

  if (costTd) costTd.textContent = fmtMoneyPerHour(cost);
  if (savingsTd) savingsTd.textContent = fmtMoneyPerHour(savings);
}

async function choosePlanForSleep(resourceType) {
  const accountId = Store.getState().account.id;
  const config = await Api.getAccountConfig(accountId);
  const wantedPlanType = sleepPlanTypeForResource(resourceType);

  const plans = Object.entries(config?.sleep_plans || {})
    .filter(([, plan]) => plan?.plan_type === wantedPlanType)
    .map(([name]) => name);

  if (!plans.length) {
    throw new Error(`No available ${wantedPlanType} sleep plan found for this account.`);
  }

  const host = qs("#ds-modalhost");
  if (!host) throw new Error("Modal host not found.");

  return new Promise((resolve) => {
    host.innerHTML = `
      <div class="ds-modalbackdrop" data-role="close"></div>
      <div class="ds-modal" role="dialog" aria-modal="true" aria-label="Choose Sleep Plan">
        <div class="ds-modal__head">
          <div class="ds-modal__title">Choose Sleep Plan</div>
          <button class="ds-btn ds-btn--ghost" type="button" data-role="close">Close</button>
        </div>
        <div class="ds-modal__body">
          <div class="ds-field" style="min-width:unset;">
            <div class="ds-label">Available plans for ${h(resourceType)}</div>
            <select class="ds-select" id="ds-sleep-plan-select">
              ${plans.map((name) => `<option value="${h(name)}">${h(name)}</option>`).join("")}
            </select>
          </div>
        </div>
        <div class="ds-modal__foot">
          <button class="ds-btn ds-btn--ghost" type="button" data-role="cancel">Cancel</button>
          <button class="ds-btn ds-btn--sleep" type="button" data-role="confirm">Sleep</button>
        </div>
      </div>
    `;
    host.style.pointerEvents = "auto";

    const onClick = (e) => {
      const role = e.target?.dataset?.role;
      if (role === "close" || role === "cancel") {
        cleanup(null);
      } else if (role === "confirm") {
        const selected = qs("#ds-sleep-plan-select")?.value || null;
        cleanup(selected);
      }
    };

    const cleanup = (value) => {
      host.removeEventListener("click", onClick);
      host.innerHTML = "";
      host.style.pointerEvents = "none";
      resolve(value);
    };

    host.addEventListener("click", onClick);
  });
}

async function fetchPricingForRow(row) {
  const accountId = Store.getState().account.id;

  if (row.resource_type === "EKS_CLUSTER") {
    const priceResp = await Api.getEksClusterPrice(accountId, row.resource_name, row.region).catch(() => null);
    let savingsResp = null;

    if (String(row.observed_state || "").toUpperCase() === "SLEEPING") {
      savingsResp = await Api.getEksClusterPriceSavings(accountId, row.resource_name, row.region).catch(() => null);
    }

    const cost = Number(priceResp?.hourly_price);
    const savings = Number(savingsResp?.hourly_savings);

    return {
      cost: Number.isFinite(cost) ? cost : null,
      savings: Number.isFinite(savings) ? savings : null,
    };
  }

  if (row.resource_type === "RDS_INSTANCE") {
    const priceResp = await Api.getRdsInstancePrice(accountId, row.resource_name, row.region).catch(() => null);
    let savingsResp = null;

    if (String(row.observed_state || "").toUpperCase() === "SLEEPING") {
      savingsResp = await Api.getRdsInstancePriceSavings(accountId, row.resource_name, row.region).catch(() => null);
    }

    const cost = Number(priceResp?.hourly_price);
    const savings = Number(savingsResp?.hourly_savings);

    return {
      cost: Number.isFinite(cost) ? cost : null,
      savings: Number.isFinite(savings) ? savings : null,
    };
  }

  return { cost: null, savings: null };
}

function schedulePricingHydration(rows, renderToken) {
  const queue = [...rows];
  const concurrency = Math.min(4, Math.max(1, queue.length));

  const worker = async () => {
    while (queue.length) {
      const row = queue.shift();
      if (!row) return;
      if (renderToken !== activeRenderToken) return;

      const cached = getCachedPricing(row);
      if (cached) {
        row.compute_cost_estimation = cached.cost;
        row.compute_savings_estimation = cached.savings;
        patchPricingCells(row.key, cached.cost, cached.savings);
        continue;
      }

      if (renderToken !== activeRenderToken) return;

      try {
        const result = await fetchPricingForRow(row);
        row.compute_cost_estimation = result.cost;
        row.compute_savings_estimation = result.savings;
        setCachedPricing(row, result.cost, result.savings);

        if (renderToken === activeRenderToken) {
          patchPricingCells(row.key, result.cost, result.savings);
        }
      } catch {
        row.compute_cost_estimation = null;
        row.compute_savings_estimation = null;
        if (renderToken === activeRenderToken) {
          patchPricingCells(row.key, null, null);
        }
      }
    }
  };

  for (let i = 0; i < concurrency; i += 1) {
    setTimeout(() => { worker(); }, 0);
  }
}

export async function ActiveResourcesPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  if (!s.account.id) {
    toast("Account", "Choose an account from Switch Account first.");
    location.hash = "#/discovery";
    return;
  }

  qs("#ds-crumbs").textContent = "Active Resources / Control Panel";

  page.innerHTML = renderPanel({
    title: "Control Panel",
    sub: "Registered resources with one-click Sleep/Wake/Unregister.",
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;">
        <div class="ds-row" style="margin-left:auto;">
          <button class="ds-btn" id="ds-cp-refresh" type="button">Refresh Now</button>
        </div>
      </div>

      <div class="ds-mono-muted" id="ds-cp-status">—</div>
      <div style="height:10px"></div>

      <div class="ds-tablewrap" data-table="active">
        <table class="ds-table" aria-label="Active resources table">
          <thead>
            <tr>
              <th>Type</th>
              <th>Name</th>
              <th>Region</th>
              <th>Observed</th>
              <th>Desired</th>
              <th>Cost of Compute</th>
              <th>Savings in Compute</th>
              <th>Last</th>
              <th>Updated</th>
              <th style="width:320px;">Actions</th>
            </tr>
          </thead>
          <tbody id="ds-cp-tbody"></tbody>
        </table>
      </div>
    `,
  });

  const status = qs("#ds-cp-status");
  const btnRefresh = qs("#ds-cp-refresh");

  async function loadActiveInitial() {
    const accountId = Store.getState().account.id;
    const renderToken = ++activeRenderToken;

    status.textContent = "Loading…";
    try {
      const [eks, rds] = await Promise.all([
        Api.listClusterStates(accountId).catch(() => ({ clusters: [] })),
        Api.listRdsStates(accountId).catch(() => ({ instances: [] })),
      ]);

      const rows = [];

      for (const c of (eks.clusters || [])) {
        rows.push({
          key: `EKS_CLUSTER|${c.cluster_name}|${c.region}`,
          resource_type: "EKS_CLUSTER",
          resource_name: c.cluster_name,
          region: c.region,
          observed_state: c.observed_state,
          desired_state: c.desired_state,
          last_action: c.last_action,
          last_action_at: c.last_action_at,
          locked_until: c.locked_until,
          updated_at: c.updated_at,
          compute_cost_estimation: null,
          compute_savings_estimation: null,
        });
      }

      for (const r of (rds.instances || [])) {
        rows.push({
          key: `RDS_INSTANCE|${r.db_instance_id}|${r.region}`,
          resource_type: "RDS_INSTANCE",
          resource_name: r.db_instance_id,
          region: r.region,
          observed_state: r.observed_state,
          desired_state: r.desired_state,
          last_action: r.last_action,
          last_action_at: r.last_action_at,
          locked_until: r.locked_until,
          updated_at: r.updated_at,
          compute_cost_estimation: null,
          compute_savings_estimation: null,
        });
      }

      const map = new Map();
      for (const row of rows) {
        const cached = getCachedPricing(row);
        if (cached) {
          row.compute_cost_estimation = cached.cost;
          row.compute_savings_estimation = cached.savings;
        }
        map.set(row.key, row);
      }

      Store.getState().active.rowsByKey = map;
      renderActiveTable(map);
      status.textContent = `OK — ${map.size} registered resource(s).`;

      applyTableFilter('[data-table="active"]', Store.getState().ui.search);

      setTimeout(() => {
        if (renderToken === activeRenderToken) {
          schedulePricingHydration(rows, renderToken);
        }
      }, 0);
    } catch (e) {
      status.textContent = "Error.";
      toast("Control Panel", e.message || "Load failed");
    }
  }

  function renderActiveTable(map) {
    const tbody = qs("#ds-cp-tbody");
    const rows = Array.from(map.values()).sort((a, b) => a.resource_type.localeCompare(b.resource_type) || a.resource_name.localeCompare(b.resource_name));
    tbody.innerHTML = rows.map((r) => renderActiveRow(r)).join("");
    bindActiveRowActions();
  }

  function removeRow(key) {
    const tr = document.querySelector(`tr[data-key="${key.replaceAll('"','\\"')}"]`);
    if (tr) tr.remove();
    Store.getState().active.rowsByKey.delete(key);
  }

  function bindActiveRowActions() {
    qsa('[data-action="sleep"], [data-action="wake"], [data-action="unregister"]').forEach((btn) => {
      btn.addEventListener("click", async () => {
        const accountId = Store.getState().account.id;
        const key = btn.dataset.key;
        const row = Store.getState().active.rowsByKey.get(key);
        if (!row) return;

        const action = btn.dataset.action;

        try {
          btn.disabled = true;

          if (action === "unregister") {
            const ok = await confirmModal({
              title: `UNREGISTER ${row.resource_type}`,
              body: `<div class="ds-mono-muted">${row.resource_name} • ${row.region}</div>`,
              confirmText: "Unregister",
              cancelText: "Cancel",
            });
            if (!ok) return;

            if (row.resource_type === "EKS_CLUSTER") {
              await Api.unregisterEKS(accountId, row.resource_name, row.region);
            } else if (row.resource_type === "RDS_INSTANCE") {
              await Api.unregisterRDS(accountId, row.resource_name, row.region);
            }
            toast("Registry", "Unregistered.");
            removeRow(key);
            status.textContent = `OK — ${Store.getState().active.rowsByKey.size} registered resource(s).`;
            return;
          }

          if (action === "sleep") {
            const selectedPlan = await choosePlanForSleep(row.resource_type);
            if (!selectedPlan) return;

            if (row.resource_type === "EKS_CLUSTER") {
              await Api.sleepEKS(accountId, row.resource_name, row.region, selectedPlan);
            } else if (row.resource_type === "RDS_INSTANCE") {
              await Api.sleepRDS(accountId, row.resource_name, row.region, selectedPlan);
            }
            toast("Orchestrator", `Sleep submitted with plan ${selectedPlan}.`);
            return;
          }

          if (action === "wake") {
            const ok = await confirmModal({
              title: `WAKE ${row.resource_type}`,
              body: `<div class="ds-mono-muted">${row.resource_name} • ${row.region}</div>`,
              confirmText: "Wake",
              cancelText: "Cancel",
            });
            if (!ok) return;

            if (row.resource_type === "EKS_CLUSTER") {
              await Api.wakeEKS(accountId, row.resource_name, row.region);
            } else if (row.resource_type === "RDS_INSTANCE") {
              await Api.wakeRDS(accountId, row.resource_name, row.region);
            }
            toast("Orchestrator", "Wake submitted.");
          }
        } catch (e) {
          toast("Action", e.message || "Action failed");
        } finally {
          btn.disabled = false;
        }
      });
    });
  }

  btnRefresh.addEventListener("click", loadActiveInitial);

  await loadActiveInitial();
}
EOF

# ------------------------------------------------------------------
# 9) app.js
# ------------------------------------------------------------------
cat > "$ROOT/app.js" <<'EOF'
import { Store } from "./js/store.js";
import { createRouter } from "./js/utils/router.js";
import { createPoller } from "./js/utils/poller.js";
import { qs } from "./js/utils/dom.js";
import { toast } from "./js/utils/toast.js";

import { renderSidebar, setActiveNav } from "./js/components/Sidebar.js";
import { renderHeader } from "./js/components/Header.js";
import { bindUserDropdown, renderUserInfo, loadAccountsIntoDropdown, rebindUserDropdownAfterRerender } from "./js/components/UserDropdown.js";
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

(function bootstrapShell() {
  const rail = qs("#ds-rail");
  if (rail) rail.innerHTML = renderSidebar();

  const topbar = qs("#ds-topbar");
  if (topbar) topbar.innerHTML = renderHeader();

  bindUserDropdown();
  renderUserInfo();

  bindGlobalSearch((q) => {
    const route = Store.getState().route.name;
    if (route === "discovery") applyTableFilter('[data-table="discovery"]', q);
    if (route === "active") applyTableFilter('[data-table="active"]', q);
  });
})();

const router = createRouter();

router.register("login", async () => LoginPage());
router.register("discovery", async () => InventoryPage());
router.register("active", async () => ActiveResourcesPage());
router.register("policies", async () => TimePoliciesPage());
router.register("settings", async () => SleepPlansPage());
router.register("history", async () => HistoryPage());
router.register("users", async () => ManageUsersPage());
router.register("savings", async () => SavingsPage());

async function rerenderSidebar() {
  const rail = qs("#ds-rail");
  if (rail) rail.innerHTML = renderSidebar();
  rebindUserDropdownAfterRerender();
}

async function initialRoute(route) {
  const s = Store.getState();
  const hasToken = !!s.auth.token;

  if (!hasToken && route.name !== "login") {
    location.hash = "#/login";
    return;
  }

  if (hasToken && route.name === "login") {
    location.hash = "#/discovery";
    return;
  }

  if (hasToken) {
    await loadAccountsIntoDropdown();
  }

  await rerenderSidebar();

  Store.setState({ route });
  setActiveNav(route.name);
  router.render(route);

  const input = qs("#ds-global-search");
  if (input) input.value = Store.getState().ui.search || "";
}

router.start((route) => {
  initialRoute(route);
});

const poller = createPoller({
  intervalMs: 10_000,
  guard: () => {
    const s = Store.getState();
    return !!(s.account.id && s.auth.token && s.route.name === "active");
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
echo "OK: rewrote js/components/Pills.js"
echo "OK: rewrote js/pages/ActiveResourcesPage.js"
echo "OK: rewrote app.js"
echo "Done."
