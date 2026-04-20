import { qs } from "../utils/dom.js";
import { Store } from "../store.js";

export function bindGlobalSearch(onSearch) {
  const input = qs("#ds-global-search");
  if (!input) return;

  input.addEventListener("input", () => {
    Store.setState({ ui: { search: input.value } });
    onSearch?.(input.value);
  });
}
