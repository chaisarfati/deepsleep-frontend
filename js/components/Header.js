export function renderHeader() {
  return `
    <div class="ds-topbar__left">
      <div class="ds-crumbs" id="ds-crumbs">DeepSleep</div>
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
  `;
}
