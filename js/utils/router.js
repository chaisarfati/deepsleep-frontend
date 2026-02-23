export function createRouter() {
  const routes = new Map();

  function parseHash() {
    const raw = location.hash.replace(/^#/, "");
    const path = raw.startsWith("/") ? raw : "/discovery";
    const [p] = path.split("?");
    const parts = p.split("/").filter(Boolean);
    const name = parts[0] || "discovery";
    return { name, params: {} };
  }

  function register(name, handler) { routes.set(name, handler); }
  function go(path) { location.hash = "#" + path; }

  function start(onRoute) {
    window.addEventListener("hashchange", () => onRoute(parseHash()));
    onRoute(parseHash());
  }

  function render(route) {
    const handler = routes.get(route.name) || routes.get("discovery");
    handler?.(route);
  }

  return { register, go, start, render };
}
