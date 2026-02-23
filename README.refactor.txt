DeepSleep Vanilla SPA Refactor (no behavior changes)

Entry:
- index.html includes CSS and app.js (module)
- app.js renders Sidebar+Header into placeholders and routes pages.

Structure:
- css/main.css variables+reset+shared atoms
- css/sidebar.css, css/header.css, css/inventory.css module CSS

- js/store.js Pub/Sub-like Store (getState/setState/subscribe)
- js/api/client.js base URL + auth + request()
- js/api/services.js typed endpoints

- js/components/* pure render/bind helpers
- js/pages/* per-route page logic
- js/utils/* dom/time/storage/toast/router/poller

Run:
- Serve with any static server (e.g. python -m http.server) and set API Base URL in Settings.
