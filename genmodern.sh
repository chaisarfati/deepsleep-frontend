#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

mkdir -p "$ROOT/css"

need() { [[ -f "$1" ]] || { echo "ERROR: missing $1"; exit 1; }; }

need "$ROOT/css/main.css"
need "$ROOT/css/header.css"
need "$ROOT/css/sidebar.css"
need "$ROOT/css/inventory.css"

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
  --warning: #f8d626;
  --warning-fg: #473d0b;

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

  --color_bg_state_success_subtle: var(--success-bg);
  --color_fg_on_state_success_subtle: var(--success);
  --color_border_state_success: #10783f;

  --color_bg_state_danger_subtle: var(--danger-bg);
  --color_fg_on_state_danger_subtle: #761c17;
  --color_border_state_danger: var(--danger);

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

  --ds-shell-max: 1280px;
  --ds-shell-pad: 24px;

  --ds-rail-h: 76px;
  --ds-topbar-h: 80px;
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
  position: sticky;
  top: 0;
  z-index: 80;
  background: var(--color_bg_page);
  border-bottom: 1px solid transparent;
}

#ds-topbar {
  position: sticky;
  top: var(--ds-rail-h);
  z-index: 70;
  background: var(--color_bg_page);
}

#ds-main {
  width: min(calc(100% - 32px), var(--ds-shell-max));
  margin: 0 auto;
  padding: 24px 0 40px 0;
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

.ds-shell-card,
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

.ds-panel__body,
.ds-panel__content {
  padding: 0 20px 20px 20px;
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
  box-shadow: none;
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
  box-shadow: none;
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
  background: var(--color_bg_state_danger_subtle);
  border-color: #f0c8c3;
  color: var(--color_fg_on_state_danger_subtle);
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
  background: var(--color_bg_state_success_subtle);
  border-color: #cde7d5;
  color: var(--color_fg_on_state_success_subtle);
}

.ds-badge--muted {
  background: var(--functional-gray-50);
  color: var(--color_fg_muted);
}

.ds-kbd {
  display: inline-flex;
  min-width: 22px;
  justify-content: center;
  align-items: center;
  height: 22px;
  border-radius: 8px;
  border: 1px solid var(--color_border_default);
  background: var(--functional-gray-0);
  color: var(--color_fg_bold);
  font-size: 12px;
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

.ds-state-pill {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-height: 30px;
  padding: 4px 10px;
  border-radius: var(--ds-radius-pill);
  border: 1px solid var(--color_border_default);
  background: var(--functional-gray-50);
  color: var(--color_fg_muted);
  font-size: 12px;
}

.ds-state-pill--running {
  background: var(--color_bg_state_success_subtle);
  color: var(--color_fg_on_state_success_subtle);
  border-color: #cde7d5;
}

.ds-state-pill--sleeping {
  background: #eef0fd;
  color: #263588;
  border-color: #cfd6fb;
}

.ds-state-pill--locked {
  background: #f7f7f7;
  color: #5b5b5b;
}

.ds-hidden {
  display: none !important;
}

@media (max-width: 1100px) {
  #ds-main {
    width: min(calc(100% - 20px), var(--ds-shell-max));
    padding-top: 20px;
  }

  .ds-panel__head {
    flex-direction: column;
    align-items: stretch;
  }
}

@media (max-width: 820px) {
  :root {
    --ds-shell-pad: 16px;
    --ds-rail-h: auto;
    --ds-topbar-h: auto;
  }

  #ds-topbar {
    top: 0;
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
  padding: 10px 16px 0 16px;
}

#ds-topbar > * {
  width: min(100%, var(--ds-shell-max));
  margin: 0 auto;
}

.ds-topbar__left,
.ds-topbar__center,
.ds-topbar__right {
  display: flex;
  align-items: center;
}

#ds-topbar {
  display: block;
}

#ds-topbar > div,
#ds-topbar > header,
#ds-topbar > .ds-topbar {
  display: grid;
  grid-template-columns: 1fr minmax(280px, 540px) auto;
  align-items: center;
  gap: 16px;
  min-height: 68px;
  padding: 0 20px;
  background: var(--color_bg_app_bar);
  border: 1px solid var(--color_bg_app_bar_border);
  border-radius: 20px;
  backdrop-filter: saturate(120%) blur(10px);
}

.ds-crumbs {
  font-size: 14px;
  color: var(--color_fg_muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.ds-search {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 44px;
  padding: 0 14px;
  background: var(--functional-gray-0);
  border: 1px solid var(--color_border_default);
  border-radius: 999px;
  box-shadow: none;
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

.ds-topbar__right {
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

.ds-topbar__right {
  position: relative;
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
  #ds-topbar > div,
  #ds-topbar > header,
  #ds-topbar > .ds-topbar {
    grid-template-columns: 1fr;
    gap: 12px;
    padding: 14px;
  }

  .ds-topbar__left,
  .ds-topbar__center,
  .ds-topbar__right {
    width: 100%;
  }

  .ds-topbar__right {
    justify-content: flex-start;
  }
}
EOF

# ------------------------------------------------------------------
# 3) css/sidebar.css
#    Transform left rail feeling into modern horizontal nav bar
# ------------------------------------------------------------------
cat > "$ROOT/css/sidebar.css" <<'EOF'
#ds-rail {
  padding: 12px 16px 0 16px;
}

#ds-rail > * {
  width: min(100%, var(--ds-shell-max));
  margin: 0 auto;
}

#ds-rail > div,
#ds-rail > aside,
#ds-rail > .ds-rail {
  display: grid;
  grid-template-columns: auto 1fr auto;
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
  justify-content: center;
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

.ds-rail__foot {
  display: inline-flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
}

.ds-foot__hint {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-height: 32px;
  padding: 0 10px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.55);
  border: 1px solid var(--functional-gray-200);
}

.ds-hint__label {
  font-size: 12px;
  color: var(--color_fg_muted);
}

.ds-hint__value {
  font-size: 12px;
  color: var(--color_fg_bold);
  font-family: var(--ds-font-mono);
}

@media (max-width: 1180px) {
  #ds-rail > div,
  #ds-rail > aside,
  #ds-rail > .ds-rail {
    grid-template-columns: 1fr;
    gap: 14px;
    padding: 14px;
  }

  .ds-rail__brand,
  .ds-rail__nav,
  .ds-rail__foot {
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

  .ds-rail__foot {
    flex-wrap: wrap;
  }
}
EOF

# ------------------------------------------------------------------
# 4) css/inventory.css
#    modern tables, cards, page-specific utilities
# ------------------------------------------------------------------
cat > "$ROOT/css/inventory.css" <<'EOF'
/* Panels and page sections */
[data-table="discovery"],
[data-table="active"] {
  border-radius: var(--ds-radius-lg);
  overflow: auto;
}

#ds-page .ds-panel + .ds-panel {
  margin-top: 16px;
}

/* Checkbox modernisation */
.ds-inv-check,
#ds-inv-check-all,
input[type="checkbox"] {
  width: 16px;
  height: 16px;
  accent-color: var(--sky);
  cursor: pointer;
}

/* Inputs in filter bars */
#ds-region-chips .ds-badge {
  background: #eef0fd;
  border-color: #d7defd;
  color: #263588;
}

#ds-types-box .ds-panel {
  background: var(--functional-gray-50);
  border-style: dashed;
}

/* Table hierarchy */
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

/* State cells */
td[data-col="observed"] .ds-badge,
td[data-col="observed"] .ds-state-pill {
  white-space: nowrap;
}

/* Empty/helper blocks */
.ds-empty,
.ds-helper {
  padding: 20px;
  border: 1px dashed var(--color_border_default);
  border-radius: var(--ds-radius-lg);
  background: var(--functional-gray-50);
  color: var(--color_fg_muted);
}

/* Forms inside modals/pages */
.ds-modal .ds-panel {
  background: var(--functional-gray-50);
}

.ds-modal .ds-panel__head {
  padding-top: 16px;
}

.ds-modal .ds-row > .ds-field {
  flex: 1 1 220px;
}

/* Make big editor modals comfortable */
.ds-modal__body .ds-tablewrap {
  border-radius: var(--ds-radius-md);
}

/* Savings / history style helpers */
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

/* User management, policy blocks, history cards */
#ds-users-results .ds-panel,
#ds-h-results .ds-panel,
#ds-sav-breakdown .ds-panel {
  overflow: hidden;
}

/* Responsive refinements */
@media (max-width: 820px) {
  .ds-row {
    align-items: stretch;
  }

  .ds-btn {
    justify-content: center;
  }

  .ds-panel__body,
  .ds-panel__content {
    padding-left: 16px;
    padding-right: 16px;
    padding-bottom: 16px;
  }

  .ds-panel__head {
    padding-left: 16px;
    padding-right: 16px;
  }
}
EOF

echo "OK: rewrote css/main.css"
echo "OK: rewrote css/header.css"
echo "OK: rewrote css/sidebar.css"
echo "OK: rewrote css/inventory.css"
echo "Done."
