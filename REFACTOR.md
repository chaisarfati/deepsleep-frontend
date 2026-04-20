# DeepSleep — Refactor 2026

## Ce qui a changé

### API Breaking Changes fixées (`js/api/services.js`)

| Ancien endpoint (cassé) | Nouveau endpoint (unifié) | Payload |
|---|---|---|
| `POST /accounts/{id}/eks-clusters/{name}/sleep?region=&plan_name=` | `POST /accounts/{id}/sleep-resource` | `{resource_type, resource_name, region, plan_name}` |
| `POST /accounts/{id}/eks-clusters/{name}/wake?region=` | `POST /accounts/{id}/wake-resource` | `{resource_type, resource_name, region}` |
| `DELETE /accounts/{id}/eks-clusters/{name}/register?region=` | `POST /accounts/{id}/unregister-aws-resource` | `{resource_type, resource_name, region}` |
| `POST /accounts/{id}/rds-instances/{id}/sleep` | → idem `sleep-resource` | idem |
| `POST /accounts/{id}/rds-instances/{id}/wake` | → idem `wake-resource` | idem |
| `DELETE /accounts/{id}/rds-instances/{id}/register` | → idem `unregister-aws-resource` | idem |

**Nouvelles fonctions** dans `services.js` :
- `sleepResource(accountId, resourceType, resourceName, region, planName)`
- `wakeResource(accountId, resourceType, resourceName, region)`
- `registerResource(accountId, resourceType, resourceName, region)`
- `unregisterResource(accountId, resourceType, resourceName, region)`
- `enablePolicy(accountId, policyId)` — remplace `runPolicyNow` pour enable
- `disablePolicy(accountId, policyId)` — remplace `runPolicyNow` pour disable
- `listEc2InstanceStates(accountId)` — nouveau support EC2
- `getEc2InstancePrice / getEc2InstancePriceSavings` — nouveau

### Design System

**Layout** : Topbar horizontal → Sidebar verticale gauche (220px)
- Suppression de `css/header.css` et `css/inventory.css`
- Nouveau : `css/main.css`, `css/sidebar.css`, `css/components.css`
- Police : Inter (body) + Syne (display/titres) + JetBrains Mono (code)
- Accent froid : `#2c6bed` (electric indigo)

**Tokens CSS renommés** :
| Ancien | Nouveau |
|---|---|
| `--sky` | `--accent` |
| `--ds-radius-*` | `--r-*` |
| `--ds-font-sans` | `--font-ui` |
| `--ds-font-mono` | `--font-mono` |
| `--color_bg_layer` | `--bg-surface` |
| `--color_fg_bold` | `--fg-strong` |
| `--color_border_default` | `--border` |

**Classes CSS renommées** :
| Ancien | Nouveau |
|---|---|
| `ds-btn--wake` | `ds-btn--primary` |
| `ds-btn--sleep` | `ds-btn` (neutre) |
| `ds-login-shell` | Inchangé |
| `ds-badge--success-matte` | `ds-badge--success` |
| `ds-badge--danger-matte` | `ds-badge--danger` |

### Composants

- `Sidebar.js` : Entièrement réécrit. Absorbe `UserDropdown.js` (plus de fichier séparé)
- `Header.js` : Stub vide (la topbar n'existe plus)
- `ResourceRow.js` : Réécrit avec nouveaux tokens + support EC2
- `Toast.js` : Réécrit avec animations + `danger` flag sur `confirmModal`

### Pages refactorées intégralement

- `LoginPage.js` — Nouveau design carte centrée
- `InventoryPage.js` — Support EC2, nouveau design, batch via endpoints unifiés
- `ActiveResourcesPage.js` — `sleepResource/wakeResource` unifiés, EC2 support
- `SavingsPage.js` — Hero card savings, EC2 dans les tabs
- `HistoryPage.js` — Run cards redesignées

### Pages copiées + patchées (btn classes only)

- `TimePoliciesPage.js`
- `SleepPlansPage.js`
- `ManageUsersPage.js`
- `OnboardingPage.js`

## Déploiement nginx

Aucun changement nécessaire dans `nginx.conf`. Servir le dossier racine comme avant.
