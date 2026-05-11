export function createRouter() {
  const routes = new Map();

  function parseHash() {
    const raw = location.hash.replace(/^#/, "");
    const path = raw.startsWith("/") ? raw : "/discovery";
    // Strip query string
    const [pathOnly, queryStr] = path.split("?");
    const parts = pathOnly.split("/").filter(Boolean);
    const name = parts[0] || "discovery";

    // Parse query params
    const params = {};
    if (queryStr) {
      new URLSearchParams(queryStr).forEach((v, k) => { params[k] = v; });
    }
    // Support path segments: /resource/EKS_CLUSTER/my-cluster/eu-west-1
    if (parts.length > 1) {
      params._segments = parts.slice(1);
    }

    return { name, params };
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
