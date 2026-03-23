export function renderHeader() {
  return `
    <div class="ds-topbar">
      <div id="ds-crumbs" class="ds-hidden" aria-hidden="true"></div>

      <div class="ds-topbar__searchwrap">
        <label class="ds-search" aria-label="Recherche">
          <span class="ds-search__icon" aria-hidden="true">
            <svg width="18" height="18" viewBox="0 0 18 18">
              <circle cx="8" cy="8" r="5" fill="none" stroke="currentColor" stroke-width="1.7"/>
              <path d="M12.5 12.5L16 16" fill="none" stroke="currentColor" stroke-width="1.7"/>
            </svg>
          </span>
          <input
            id="ds-global-search"
            class="ds-search__input"
            type="search"
            placeholder="Filter resources by name / region / type…"
            autocomplete="off"
          />
        </label>
      </div>
    </div>
  `;
}
