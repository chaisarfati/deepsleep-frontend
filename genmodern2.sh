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
need "$ROOT/css/inventory.css"
need "$ROOT/js/components/Header.js"
need "$ROOT/js/components/Sidebar.js"
need "$ROOT/js/components/Pills.js"
need "$ROOT/js/pages/InventoryPage.js"
need "$ROOT/js/pages/SavingsPage.js"
need "$ROOT/js/pages/ActiveResourcesPage.js"

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
  --cloud: #b6c9ff;
  --tangerine: #e27133;
  --seafoam: #4cb7a3;
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
  --color_bg_app_bar: rgba(17, 17, 17, 0.04);
  --color_bg_app_bar_plain: #f1f1f1;
  --color_bg_app_bar_border: rgba(17, 17, 17, 0.12);

  --color_fg_bold: var(--charcoal2);
  --color_fg_default: var(--functional-gray-650);
  --color_fg_muted: var(--functional-gray-500);
  --color_fg_link: var(--charcoal2);
  --color_fg_link_primary: var(--sky);

  --color_border_default: var(--functional-gray-200);
  --color_border_strong: var(--functional-gray-250);
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

  --ds-radius-xs: 8px;
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
  color: var(--color_fg_link);
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
  grid-template-columns: 100%;
}

#ds-rail {
  padding: 12px 16px 0 16px;
}

#ds-topbar {
  padding: 10px 16px 0 16px;
}

#ds-main {
  width: min(calc(100% - 32px), var(--ds-shell-main-max));
  margin: 16px auto 0 auto;
  padding: 0 0 40px 0;
}

#ds-page {
  min-width: 0;
}

.ds-shell-card,
.ds-panel,
.ds-modal,
.ds-dropdown,
.ds-tablewrap,
.ds-search,
.ds-userchip,
.ds-navlink,
.ds-btn,
.ds-input,
.ds-select,
.ds-textarea,
.ds-badge {
  transition:
    background-color 140ms ease,
    border-color 140ms ease,
    color 140ms ease,
    box-shadow 140ms ease,
    transform 140ms ease;
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
  border-color: #f0c8c3;
  color: #761c17;
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

.ds-badge--reg {
  background: var(--success-bg);
  border-color: #cde7d5;
  color: var(--success);
}

.ds-badge--muted {
  background: var(--functional-gray-50);
  color: var(--color_fg_muted);
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
    margin-top: 12px;
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
#ds-topbar > * {
  width: min(100%, var(--ds-shell-bar-max));
  margin: 0 auto;
}

.ds-topbar {
  display: grid;
  grid-template-columns: minmax(220px, 1fr) auto;
  align-items: center;
  gap: 16px;
  min-height: 68px;
  padding: 0 20px;
  background: var(--color_bg_app_bar);
  border: 1px solid var(--color_bg_app_bar_border);
  border-radius: 20px;
  backdrop-filter: saturate(120%) blur(10px);
}

.ds-topbar__left {
  display: none;
}

.ds-topbar__center {
  display: flex;
  align-items: center;
  min-width: 0;
}

.ds-topbar__right {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  position: relative;
}

.ds-search {
  display: flex;
  align-items: center;
  gap: 10px;
  width: min(100%, 640px);
  min-height: 44px;
  padding: 0 14px;
  background: var(--functional-gray-0);
  border: 1px solid var(--color_border_default);
  border-radius: 999px;
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
  height: 42px;
  border: 0;
  background: transparent;
  color: var(--color_fg_bold);
  padding: 0;
}

.ds-search__input::placeholder {
  color: var(--functional-gray-450);
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

@media (max-width: 980px) {
  .ds-topbar {
    grid-template-columns: 1fr;
    gap: 12px;
    padding: 14px;
  }

  .ds-topbar__center,
  .ds-topbar__right {
    width: 100%;
  }

  .ds-topbar__right {
    justify-content: flex-end;
  }

  .ds-search {
    width: 100%;
  }
}
EOF

# ------------------------------------------------------------------
# 3) css/sidebar.css
# ------------------------------------------------------------------
cat > "$ROOT/css/sidebar.css" <<'EOF'
#ds-rail > * {
  width: min(100%, var(--ds-shell-bar-max));
  margin: 0 auto;
}

.ds-rail {
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: 18px;
  min-height: 64px;
  padding: 0 18px;
  background: var(--color_bg_app_bar);
  border: 1px solid var(--color_bg_app_bar_border);
  border-radius: 24px;
  backdrop-filter: saturate(120%) blur(10px);
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
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 6px;
  flex-wrap: wrap;
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
  background: rgba(255, 255, 255, 0.6);
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

@media (max-width: 1180px) {
  .ds-rail {
    grid-template-columns: 1fr;
    gap: 14px;
    padding: 14px;
  }

  .ds-rail__brand,
  .ds-rail__nav {
    justify-content: center;
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
  }

  .ds-navlink {
    flex: 0 0 auto;
  }
}
EOF

# ------------------------------------------------------------------
# 4) css/inventory.css
# ------------------------------------------------------------------
cat > "$ROOT/css/inventory.css" <<'EOF'
[data-table="discovery"],
[data-table="active"] {
  border-radius: var(--ds-radius-lg);
  overflow: auto;
}

#ds-page .ds-panel + .ds-panel {
  margin-top: 16px;
}

.ds-inv-check,
#ds-inv-check-all,
input[type="checkbox"] {
  width: 16px;
  height: 16px;
  accent-color: var(--sky);
  cursor: pointer;
}

#ds-region-chips .ds-badge {
  background: #eef0fd;
  border-color: #d7defd;
  color: #263588;
}

.ds-table tbody td:nth-child(1),
.ds-table tbody td:nth-child(2) {
  color: var(--color_fg_bold);
}

.ds-table tbody td[data-col="compute-cost"],
.ds-table tbody td[data-col="compute-savings"] {
  font-family: var(--ds-font-mono);
  font-size: 13px;
  color: var(--color_fg_bold);
}

.ds-empty,
.ds-helper {
  padding: 20px;
  border: 1px dashed var(--color_border_default);
  border-radius: var(--ds-radius-lg);
  background: var(--functional-gray-50);
  color: var(--color_fg_muted);
}

.ds-modal .ds-panel {
  background: var(--functional-gray-50);
}

.ds-modal .ds-panel__head {
  padding-top: 16px;
}

.ds-modal .ds-row > .ds-field {
  flex: 1 1 220px;
}

.ds-modal__body .ds-tablewrap {
  border-radius: var(--ds-radius-md);
}

.ds-stat-card {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 18px;
  background: var(--color_bg_layer);
  border: 1px solid var(--color_border_default);
  border-radius: var(--ds-radius-lg);
}

.ds-stat-card__k {
  font-size: 13px;
  color: var(--color_fg_muted);
}

.ds-stat-card__v {
  font-size: 28px;
  line-height: 1.1;
  color: var(--color_fg_bold);
  letter-spacing: -0.03em;
}

#ds-users-results .ds-panel,
#ds-h-results .ds-panel,
#ds-sav-breakdown .ds-panel {
  overflow: hidden;
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

@media (max-width: 820px) {
  .ds-row {
    align-items: stretch;
  }

  .ds-btn {
    justify-content: center;
  }

  .ds-panel__head {
    padding-left: 16px;
    padding-right: 16px;
  }
}
EOF

# ------------------------------------------------------------------
# 5) js/components/Header.js
# ------------------------------------------------------------------
cat > "$ROOT/js/components/Header.js" <<'EOF'
export function renderHeader() {
  return `
    <div class="ds-topbar">
      <div class="ds-topbar__left">
        <div class="ds-crumbs ds-hidden" id="ds-crumbs" aria-hidden="true"></div>
      </div>

      <div class="ds-topbar__center">
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

      <div class="ds-topbar__right">
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
EOF

# ------------------------------------------------------------------
# 6) js/components/Sidebar.js
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
# 8) js/pages/InventoryPage.js
#    - replace resource type checkboxes by tabs
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/InventoryPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast, confirmModal } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import { applyTableFilter } from "../components/TableFilters.js";
import { renderInventoryRow } from "../components/ResourceRow.js";
import * as Api from "../api/services.js";

function csvToList(v) {
  return String(v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function uniq(arr) {
  const out = [];
  const set = new Set();
  for (const x of arr) {
    const k = String(x || "").trim();
    if (!k || set.has(k)) continue;
    set.add(k);
    out.push(k);
  }
  return out;
}

function renderRegionChips(regions) {
  const list = regions || [];
  if (!list.length) return `<div class="ds-mono-muted" style="padding:6px 0;">No regions selected.</div>`;
  return `
    <div class="ds-row" style="gap:8px;flex-wrap:wrap;">
      ${list.map((r) => `
        <span class="ds-badge" style="gap:10px;">
          <span>${h(r)}</span>
          <button class="ds-btn ds-btn--ghost" type="button" data-region-remove="${h(r)}" style="padding:0 6px;box-shadow:none;">x</button>
        </span>
      `).join("")}
    </div>
  `;
}

function renderResourceTabs(currentKey) {
  return `
    <div class="ds-tabs" role="tablist" aria-label="Resource type filter">
      <button class="ds-tab" type="button" data-resource-tab="ALL" aria-selected="${currentKey === "ALL" ? "true" : "false"}">All Resources</button>
      <button class="ds-tab" type="button" data-resource-tab="EKS_CLUSTER" aria-selected="${currentKey === "EKS_CLUSTER" ? "true" : "false"}">EKS Clusters</button>
      <button class="ds-tab" type="button" data-resource-tab="RDS_INSTANCE" aria-selected="${currentKey === "RDS_INSTANCE" ? "true" : "false"}">RDS Instances</button>
    </div>
  `;
}

function tabKeyToTypes(tabKey) {
  if (tabKey === "EKS_CLUSTER") return ["EKS_CLUSTER"];
  if (tabKey === "RDS_INSTANCE") return ["RDS_INSTANCE"];
  return ["EKS_CLUSTER", "RDS_INSTANCE"];
}

export async function InventoryPage() {
  const s = Store.getState();
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Discovery / Inventory";

  const initialRegions = uniq(csvToList(s.discovery.regionsCsv || "eu-west-1,eu-central-1,us-east-1"));
  const currentTab = Store.getState().discovery.resourceTab || "ALL";

  Store.setState({
    discovery: {
      regionsList: initialRegions,
      resourceTab: currentTab,
      resourceTypes: tabKeyToTypes(currentTab),
    },
  });

  page.innerHTML = renderPanel({
    title: "Inventory",
    sub: "Raw discovery via /resources/search. Select rows then Register/Unregister.",
    bodyHtml: `
      <div class="ds-row" style="margin-bottom:12px;align-items:flex-start;">
        <div class="ds-field" style="min-width:340px;flex:1;">
          <div class="ds-label">Regions</div>
          <div class="ds-row" style="gap:10px;">
            <input class="ds-input" id="ds-region-input" placeholder="Type a region and press Add (e.g. eu-west-1)" />
            <button class="ds-btn" id="ds-region-add" type="button">Add</button>
          </div>
          <div style="height:8px"></div>
          <div id="ds-region-chips"></div>
        </div>

        <div class="ds-field" style="min-width:320px;">
          <div class="ds-label">Resources</div>
          <div id="ds-resource-tabs"></div>
        </div>

        <div class="ds-row" style="margin-left:auto;align-self:flex-end;">
          <button class="ds-btn" id="ds-inv-run" type="button">Run Search</button>
          <button class="ds-btn ds-btn--wake" id="ds-inv-batch-reg" type="button">Register</button>
          <button class="ds-btn ds-btn--danger" id="ds-inv-batch-unreg" type="button">Unregister</button>
        </div>
      </div>

      <div class="ds-mono-muted" id="ds-inv-status">—</div>
      <div style="height:10px"></div>

      <div class="ds-tablewrap" data-table="discovery">
        <table class="ds-table" aria-label="Inventory table">
          <thead>
            <tr>
              <th style="width:42px;"><input type="checkbox" id="ds-inv-check-all" aria-label="Select all"/></th>
              <th>Type</th>
              <th>Name</th>
              <th>Region</th>
              <th>Registered</th>
              <th>Observed</th>
              <th>Labels</th>
            </tr>
          </thead>
          <tbody id="ds-inv-tbody"></tbody>
        </table>
      </div>
    `,
  });

  const btnRun = qs("#ds-inv-run");
  const btnReg = qs("#ds-inv-batch-reg");
  const btnUnreg = qs("#ds-inv-batch-unreg");
  const status = qs("#ds-inv-status");

  const regionInput = qs("#ds-region-input");
  const regionAdd = qs("#ds-region-add");
  const chips = qs("#ds-region-chips");
  const tabsBox = qs("#ds-resource-tabs");

  function renderRegions() {
    const regions = Store.getState().discovery.regionsList || [];
    chips.innerHTML = renderRegionChips(regions);
    qsa("[data-region-remove]").forEach((b) => {
      b.addEventListener("click", () => {
        const r = b.dataset.regionRemove;
        const next = (Store.getState().discovery.regionsList || []).filter((x) => x !== r);
        Store.setState({ discovery: { regionsList: next, regionsCsv: next.join(",") } });
        renderRegions();
      });
    });
  }

  function renderTabs() {
    const current = Store.getState().discovery.resourceTab || "ALL";
    tabsBox.innerHTML = renderResourceTabs(current);

    qsa("[data-resource-tab]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const tab = btn.dataset.resourceTab;
        Store.setState({
          discovery: {
            resourceTab: tab,
            resourceTypes: tabKeyToTypes(tab),
          },
        });
        renderTabs();
      });
    });
  }

  regionAdd.addEventListener("click", () => {
    const v = (regionInput.value || "").trim();
    if (!v) return;
    const next = uniq([...(Store.getState().discovery.regionsList || []), v]);
    Store.setState({ discovery: { regionsList: next, regionsCsv: next.join(",") } });
    regionInput.value = "";
    renderRegions();
  });

  regionInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      regionAdd.click();
    }
  });

  function readSearchPayload() {
    const accountId = Store.getState().account.id;
    const regions = (Store.getState().discovery.regionsList || []);
    const types = Store.getState().discovery.resourceTypes || ["EKS_CLUSTER", "RDS_INSTANCE"];

    const payload = {
      resource_types: types.length ? types : ["EKS_CLUSTER", "RDS_INSTANCE"],
      regions: regions.length ? regions : null,
      selector_by_type: {},
      only_registered: false,
    };

    return { accountId, payload };
  }

  function renderInventoryRows() {
    const tbody = qs("#ds-inv-tbody");
    const { resources, selectedKeys } = Store.getState().discovery;

    tbody.innerHTML = resources.map((r) => renderInventoryRow(r, selectedKeys.has(r.key))).join("");

    qsa(".ds-inv-check", tbody).forEach((cb) => {
      cb.addEventListener("change", () => {
        const key = cb.dataset.key;
        const set = Store.getState().discovery.selectedKeys;
        if (cb.checked) set.add(key); else set.delete(key);
      });
    });

    const checkAll = qs("#ds-inv-check-all");
    checkAll.checked = false;
    checkAll.addEventListener("change", () => {
      const set = Store.getState().discovery.selectedKeys;
      set.clear();
      qsa(".ds-inv-check", tbody).forEach((cb) => {
        cb.checked = checkAll.checked;
        if (checkAll.checked) set.add(cb.dataset.key);
      });
    });
  }

  async function runSearch() {
    const { accountId, payload } = readSearchPayload();
    if (!accountId) return toast("Inventory", "Choose an account from Switch Account first.");
    status.textContent = "Searching…";

    try {
      const resp = await Api.searchResources(accountId, payload);
      const resources = (resp && resp.resources) ? resp.resources : [];

      const norm = resources.map((r) => ({
        key: `${r.resource_type}|${r.resource_name}|${r.region}`,
        resource_type: r.resource_type,
        resource_name: r.resource_name,
        region: r.region,
        labels: r.labels || {},
        registered: !!r.registered,
        observed_state: r.observed_state || null,
        desired_state: r.desired_state || null,
      }));

      Store.setState({ discovery: { resources: norm, selectedKeys: new Set(), lastQuery: payload } });
      renderInventoryRows();
      status.textContent = `OK — ${norm.length} resource(s).`;

      applyTableFilter('[data-table="discovery"]', Store.getState().ui.search);
    } catch (e) {
      status.textContent = "Error.";
      toast("Inventory", e.message || "Search failed");
    }
  }

  async function doBatch(mode) {
    const { accountId, payload } = readSearchPayload();
    const selected = Array.from(Store.getState().discovery.selectedKeys);

    if (!accountId) return toast("Batch", "Choose an account from Switch Account first.");
    if (!selected.length) return toast("Batch", "Select at least one row.");

    const ok = await confirmModal({
      title: mode === "REGISTER" ? "Register selected" : "Unregister selected",
      body: `<div class="ds-mono-muted">Selected: ${selected.length}. This will call /resources/batch-register.</div>`,
      confirmText: mode === "REGISTER" ? "Register" : "Unregister",
      cancelText: "Cancel",
    });
    if (!ok) return;

    const byType = new Map();
    for (const key of selected) {
      const [t, name] = key.split("|");
      if (!byType.has(t)) byType.set(t, []);
      byType.get(t).push(name);
    }

    const selector_by_type = {};
    for (const [t, names] of byType.entries()) {
      selector_by_type[t] = {
        include_names: names,
        exclude_names: [],
        include_labels: {},
        exclude_labels: {},
        include_namespaces: null,
        exclude_namespaces: [],
      };
    }

    const body = {
      search: {
        resource_types: payload.resource_types,
        regions: payload.regions,
        selector_by_type,
        only_registered: false,
      },
      mode,
      dry_run: false,
    };

    status.textContent = `${mode}…`;
    try {
      const resp = await Api.batchRegister(accountId, body);
      const results = resp?.results || [];
      const counts = results.reduce((acc, r) => {
        acc[r.action] = (acc[r.action] || 0) + 1;
        return acc;
      }, {});
      toast("Batch", `OK — ${Object.entries(counts).map(([k,v]) => `${k}:${v}`).join(" ") || "done"}`);
      await runSearch();
    } catch (e) {
      status.textContent = "Batch error.";
      toast("Batch", e.message || "Batch failed");
    }
  }

  btnRun.addEventListener("click", runSearch);
  btnReg.addEventListener("click", () => doBatch("REGISTER"));
  btnUnreg.addEventListener("click", () => doBatch("UNREGISTER"));

  renderRegions();
  renderTabs();

  if (s.auth.token && s.account.id) runSearch();
}
EOF

# ------------------------------------------------------------------
# 9) js/pages/SavingsPage.js
#    - replace resource type checkboxes by tabs
# ------------------------------------------------------------------
cat > "$ROOT/js/pages/SavingsPage.js" <<'EOF'
import { Store } from "../store.js";
import { toast } from "../utils/toast.js";
import { qs, qsa, escapeHtml as h } from "../utils/dom.js";
import { renderPanel } from "../components/Panel.js";
import * as Api from "../api/services.js";

function requireAuthAndAccount() {
  const s = Store.getState();
  if (!s.auth.token) {
    toast("Auth", "Please login.");
    location.hash = "#/login";
    return false;
  }
  if (!s.account.id) {
    toast("Account", "Choose an account from Switch Account first.");
    return false;
  }
  return true;
}

function formatUsd(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return "—";
  return `$${n.toFixed(2)}`;
}

function nowIsoMinusDays(days) {
  const d = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  return d.toISOString().slice(0, 16);
}

function renderBreakdown(data) {
  const breakdown = data?.savings_by_resource_type || {};
  const types = Object.keys(breakdown);

  if (!types.length) {
    return `<div class="ds-mono-muted">No savings data for this selection.</div>`;
  }

  return types.map((type) => {
    const resources = breakdown[type] || {};
    const rows = Object.entries(resources).sort((a, b) => Number(b[1]) - Number(a[1]));
    const total = rows.reduce((acc, [, v]) => acc + Number(v || 0), 0);

    return `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head">
          <div>
            <div class="ds-panel__title">${h(type)}</div>
            <div class="ds-panel__sub">Total: ${formatUsd(total)}</div>
          </div>
        </div>

        <div class="ds-tablewrap">
          <table class="ds-table">
            <thead>
              <tr>
                <th>Resource</th>
                <th>Savings</th>
              </tr>
            </thead>
            <tbody>
              ${rows.map(([name, value]) => `
                <tr>
                  <td>${h(name)}</td>
                  <td>${formatUsd(value)}</td>
                </tr>
              `).join("")}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }).join("");
}

function renderSavingsTabs(current) {
  return `
    <div class="ds-tabs" role="tablist" aria-label="Savings resource type filter">
      <button class="ds-tab" type="button" data-savings-tab="ALL" aria-selected="${current === "ALL" ? "true" : "false"}">All Resources</button>
      <button class="ds-tab" type="button" data-savings-tab="EKS_CLUSTER" aria-selected="${current === "EKS_CLUSTER" ? "true" : "false"}">EKS Clusters</button>
      <button class="ds-tab" type="button" data-savings-tab="RDS_INSTANCE" aria-selected="${current === "RDS_INSTANCE" ? "true" : "false"}">RDS Instances</button>
    </div>
  `;
}

function tabToResourceTypes(tab) {
  if (tab === "EKS_CLUSTER") return ["EKS_CLUSTER"];
  if (tab === "RDS_INSTANCE") return ["RDS_INSTANCE"];
  return ["EKS_CLUSTER", "RDS_INSTANCE"];
}

export async function SavingsPage() {
  const page = qs("#ds-page");
  if (!page) return;

  qs("#ds-crumbs").textContent = "Savings";

  const currentTab = Store.getState().savings?.resourceTab || "ALL";
  Store.setState({ savings: { resourceTab: currentTab } });

  page.innerHTML = renderPanel({
    title: "Savings Overview",
    sub: "Consult total compute savings for a date range, region and selected resource types.",
    bodyHtml: `
      <div class="ds-panel" style="margin:0 0 12px 0;">
        <div class="ds-panel__head">
          <div>
            <div class="ds-panel__title">Filters</div>
            <div class="ds-panel__sub">Uses POST /accounts/{account_id}/price-savings</div>
          </div>
        </div>

        <div class="ds-row">
          <div class="ds-field" style="min-width:240px;">
            <div class="ds-label">From</div>
            <input class="ds-input" id="ds-sav-from" type="datetime-local" value="${nowIsoMinusDays(7)}" />
          </div>

          <div class="ds-field" style="min-width:240px;">
            <div class="ds-label">To</div>
            <input class="ds-input" id="ds-sav-to" type="datetime-local" value="${new Date().toISOString().slice(0,16)}" />
          </div>

          <div class="ds-field" style="min-width:220px;">
            <div class="ds-label">Region</div>
            <input class="ds-input" id="ds-sav-region" value="eu-west-1" placeholder="eu-west-1" />
          </div>

          <div class="ds-field" style="min-width:320px;">
            <div class="ds-label">Resources</div>
            <div id="ds-savings-tabs"></div>
          </div>

          <div class="ds-row" style="align-self:flex-end;">
            <button class="ds-btn ds-btn--wake" id="ds-sav-run" type="button">Load Savings</button>
          </div>
        </div>
      </div>

      <div id="ds-sav-summary"></div>
      <div id="ds-sav-breakdown"></div>
    `,
  });

  if (!requireAuthAndAccount()) return;

  const summary = qs("#ds-sav-summary");
  const breakdown = qs("#ds-sav-breakdown");
  const tabsBox = qs("#ds-savings-tabs");

  function renderTabs() {
    const current = Store.getState().savings?.resourceTab || "ALL";
    tabsBox.innerHTML = renderSavingsTabs(current);

    qsa("[data-savings-tab]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const tab = btn.dataset.savingsTab;
        Store.setState({ savings: { resourceTab: tab } });
        renderTabs();
      });
    });
  }

  async function loadSavings() {
    try {
      const accountId = Store.getState().account.id;
      const from = qs("#ds-sav-from")?.value;
      const to = qs("#ds-sav-to")?.value;
      const region = (qs("#ds-sav-region")?.value || "").trim();
      const resource_types = tabToResourceTypes(Store.getState().savings?.resourceTab || "ALL");

      if (!from || !to) throw new Error("from/to are required");
      if (!region) throw new Error("region is required");

      const payload = {
        resource_types,
        region,
        from_date: new Date(from).toISOString(),
        to_date: new Date(to).toISOString(),
      };

      summary.innerHTML = `<div class="ds-mono-muted">Loading…</div>`;
      breakdown.innerHTML = "";

      const resp = await Api.getAccountPriceSavings(accountId, payload);

      summary.innerHTML = `
        <div class="ds-panel" style="margin:0 0 12px 0;">
          <div class="ds-panel__head">
            <div>
              <div class="ds-panel__title">Global Savings</div>
              <div class="ds-panel__sub">
                ${h(resp.from_date)} → ${h(resp.to_date)} • ${h(resp.currency || "USD")}
              </div>
            </div>
          </div>

          <div class="ds-row">
            <span class="ds-badge ds-badge--success-matte" style="font-size:16px;padding:10px 14px;">
              Total: ${formatUsd(resp.total_savings)}
            </span>
            <span class="ds-badge">Region: ${h(region)}</span>
            <span class="ds-badge">Types: ${h(resource_types.join(", "))}</span>
          </div>
        </div>
      `;

      breakdown.innerHTML = renderBreakdown(resp);
    } catch (e) {
      summary.innerHTML = `<div class="ds-mono-muted">Error.</div>`;
      breakdown.innerHTML = "";
      toast("Savings", e.message || "Load failed");
    }
  }

  qs("#ds-sav-run")?.addEventListener("click", loadSavings);
  renderTabs();
  await loadSavings();
}
EOF

# ------------------------------------------------------------------
# 10) js/pages/ActiveResourcesPage.js
#     - async non-blocking pricing hydration
#     - cached 1h in memory
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
    const [priceResp, savingsResp] = await Promise.all([
      Api.getEksClusterPrice(accountId, row.resource_name, row.region).catch(() => null),
      Api.getEksClusterPriceSavings(accountId, row.resource_name, row.region).catch(() => null),
    ]);

    const cost = Number(priceResp?.hourly_price);
    const savings = Number(savingsResp?.hourly_savings);

    return {
      cost: Number.isFinite(cost) ? cost : null,
      savings: Number.isFinite(savings) ? savings : null,
    };
  }

  if (row.resource_type === "RDS_INSTANCE") {
    const [priceResp, savingsResp] = await Promise.all([
      Api.getRdsInstancePrice(accountId, row.resource_name, row.region).catch(() => null),
      Api.getRdsInstancePriceSavings(accountId, row.resource_name, row.region).catch(() => null),
    ]);

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

      await new Promise((resolve) => setTimeout(resolve, 0));

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

      schedulePricingHydration(rows, renderToken);
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
# 11) remove skip link "Aller au contenu" if present in index.html
# ------------------------------------------------------------------
if [[ -f "$ROOT/index.html" ]]; then
python3 - <<'PY' "$ROOT/index.html"
from pathlib import Path
import re, sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

patterns = [
    r'<a[^>]*>\s*Aller au contenu\s*</a>\s*',
    r'<button[^>]*>\s*Aller au contenu\s*</button>\s*',
    r'<div[^>]*>\s*Aller au contenu\s*</div>\s*',
]

for pat in patterns:
    txt = re.sub(pat, '', txt, flags=re.IGNORECASE | re.DOTALL)

p.write_text(txt, encoding="utf-8")
PY
  echo "OK: cleaned 'Aller au contenu' from index.html if present"
fi

echo "OK: rewrote css/main.css"
echo "OK: rewrote css/header.css"
echo "OK: rewrote css/sidebar.css"
echo "OK: rewrote css/inventory.css"
echo "OK: rewrote js/components/Header.js"
echo "OK: rewrote js/components/Sidebar.js"
echo "OK: rewrote js/components/Pills.js"
echo "OK: rewrote js/pages/InventoryPage.js"
echo "OK: rewrote js/pages/SavingsPage.js"
echo "OK: rewrote js/pages/ActiveResourcesPage.js"
echo "Done."
