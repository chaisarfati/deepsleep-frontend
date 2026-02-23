DeepSleep Vanilla SPA (no framework) — Updated UX

Key changes:
- /login route is the landing page when not authenticated.
- Logout redirects to /login.
- Top-right user dropdown displays:
  - Email
  - Business ID
  - AWS Account (currently unknown => blank/—)
- "Sleep Plans" tab (route: /settings) is the UI editor for account sleep plans:
  - GET /accounts/{account_id}/config
  - PUT /accounts/{account_id}/config
- "Time Policies" tab is a full UI editor (no JSON), including window editor + plan_name_by_type.

Notes:
- API base URL is same-origin (internal), not user-configurable.
- account_id is internal; UI does not ask for it. Frontend attempts to infer it from JWT claims on login.
  If your JWT does not include it, set it server-side or add a lightweight "me" endpoint.
