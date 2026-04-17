# Contoso DMV — Power Pages & Dataverse Reference

Everything needed to work on this project: architecture, environment IDs, deploy process, Liquid patterns, gotchas, and data model.

---

## Environment & IDs

| Item | Value |
|---|---|
| Dataverse Org URL | `https://orga381269e.crm9.dynamics.com` |
| Environment ID | `61c2148b-0c8a-ef0e-a3e6-f6b97c9253cb` |
| Cloud | **GCC** (US Government) |
| Portal URL | `https://site-y5jzr.powerappsportals.us/` |
| Website ID | `461a50ae-9496-419e-a58b-14d56165b009` |
| Header Web Template ID | `990d6c35-0a56-47ca-b151-bff1bad21af7` |
| PAC Auth Profile | "Kelly GCC" — `kelly.cason@testtestmsftgccfo.onmicrosoft.com` |
| Publisher Prefix | `dmv` |
| Publisher ID | `468d9adf-0b39-f111-88b4-001dd80340cd` |
| Solution | `DMVDigitalServicesPortal` (`a4f605dc-0b39-f111-88b3-001dd801f94a`) |
| Authenticated Users Web Role | `c7500f9c-350c-471b-a6da-e16f0f18009c` |
| Model-Driven App ID | `d6331d8d-a239-f111-88b4-001dd80a6132` |
| Sitemap ID | `98db46b0-896f-412f-a212-01d534198efb` |

### Demo User — Maria Jennings

| Item | Value |
|---|---|
| Contact ID | `d2c23913-f238-f111-88b3-001dd801f94a` |
| Honda Accord 2023 (vehicle) | `03def455-1d39-f111-88b4-001dd80340cd` |
| Honda Accord reg | `92e0b557-1d39-f111-88b4-001dd80a6132` (REG-2026-00142) |
| Honda Accord term | `fa04ebad-cb39-f111-88b4-001dd80a6132` (expires 2027-01-15) |
| Tesla Model S 2024 (vehicle) | `26def455-1d39-f111-88b4-001dd80340cd` |
| Tesla reg | `b3d6565a-1d39-f111-88b3-001dd801f94a` (REG-2025-00891) |
| Tesla term | `515dd7aa-cb39-f111-88b3-001dd801f94a` (expires 2026-06-10) |

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Browser (React 19 SPA)                                  │
│  ├─ Lazy-loaded pages via React Router 7                 │
│  ├─ Reads window.__PORTAL_USER__ for auth                │
│  ├─ Reads window.__DMV_DATA__ for server-injected data   │
│  └─ Calls /_api/* for Dataverse Web API (CRUD)           │
├──────────────────────────────────────────────────────────┤
│  Power Pages (hosting)                                   │
│  ├─ Liquid engine processes _header_v3.html              │
│  │   └─ FetchXML queries → injects JSON into globals     │
│  ├─ /_api/* proxies to Dataverse Web API                 │
│  └─ /_layout/tokenhtml serves antiforgery token          │
├──────────────────────────────────────────────────────────┤
│  Dataverse (GCC)                                         │
│  └─ 14+ custom tables (dmv_ prefix) + contact + account │
└──────────────────────────────────────────────────────────┘
```

| Layer | Tech |
|---|---|
| Frontend | React 19 + TypeScript 5.7 + React Router 7 |
| Build | Vite 6 → `dist/` |
| Hosting | Power Pages code site |
| Data | Dataverse Web API (`/_api/`) |
| Auth | Power Pages built-in (B2C), Liquid-injected `__PORTAL_USER__` |
| Server data | Liquid FetchXML → `window.__DMV_DATA__` |
| Deploy | `_deploy.ps1` patches Header web template via REST API |

---

## Build & Deploy

### Commands

```bash
# 1. Build the React SPA
npm run build

# 2. Upload React code to Power Pages
pac pages upload-code-site --rootPath . --compiledPath .\dist

# 3. Deploy the Liquid header template (CSS + data injection)
powershell -ExecutionPolicy Bypass -File .\_deploy.ps1
```

### What Each Step Does

- **`npm run build`**: TypeScript compile → Vite bundle → `dist/` (vendor chunk + app chunk)
- **`pac pages upload-code-site`**: Uploads `dist/` assets + web template HTML files to Power Pages
- **`_deploy.ps1`**: Reads `_header_v3.html`, escapes it, PATCHes it to the Header web template record (`mspp_webtemplates(990d6c35...)`) via Dataverse API. Uses `az account get-access-token` for auth.

### Token for Dataverse API (scripts)

```powershell
$envUrl = "https://orga381269e.crm9.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
$h = @{ Authorization = "Bearer $token"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0" }
```

---

## Liquid Header Template (`_header_v3.html`)

The core of server-side data injection. Processed by the Power Pages Liquid engine on every page load.

### Structure

1. **`window.__PORTAL_USER__`** — user name + ID (or null if anonymous)
2. **Antiforgery token fetch** — `/_layout/tokenhtml` → hidden div in DOM
3. **5 FetchXML queries** (all filtered by `{{ user.id }}`):
   - `contact_query` — address, phone
   - `license_query` — driver license (top 1)
   - `vehicles_query` — all owned vehicles
   - `regs_query` — all registrations (includes `dmv_expirationdate`)
   - `txn_query` — last 20 transactions
4. **`window.__DMV_DATA__`** — JSON object with citizen, license, vehicles, registrations, transactions
5. **Sign-in page CSS** — 50/50 split layout, only active on `/SignIn`, `/Account/*` routes

### `window.__DMV_DATA__` Shape

```javascript
{
  citizen: { id, fullName, address, phone },
  license: { id, licenseNumber, status, expirationDate, realIdCompliant, licenseClass, issueDate } | null,
  vehicles: [{ id, vin, year, make, model, plateNumber, color, insuranceStatus, insuranceExpiry }],
  registrations: [{ id, regId, status, statusLabel, currentTermId, vehicleId, expirationDate }],
  transactions: [{ id, transactionId, type, date, status, amount }]
}
```

### Liquid Syntax Rules (IMPORTANT)

| Pattern | Correct | Wrong |
|---|---|---|
| Option set integer | `{{ r.dmv_regstatus }}` | `{{ r.dmv_regstatus.Value }}` (crashes) |
| Option set label | `{{ r.dmv_regstatus.Label }}` | |
| Lookup GUID | `{{ r.dmv_vehicleid }}` | |
| Date format | `{{ r.dmv_date \| date: '%Y-%m-%d' }}` | |
| Boolean default | `{{ r.dmv_bool \| default: false }}` | |
| Escape strings | `{{ r.dmv_name \| escape }}` | |
| Loop comma | `{% unless forloop.last %},{% endunless %}` | |

### What CRASHES Liquid Templates

- **`r['alias.field']` bracket notation** — silently kills the entire template. Both `__PORTAL_USER__` and `__DMV_DATA__` become `undefined`. Never use link-entity alias + bracket access in Liquid output.
- **`.Value` on option sets** — option sets return integers directly, `.Value` returns nil.
- Any Liquid syntax error in the `<script>` block — the entire block disappears silently with no error.

---

## Dataverse Web API (Portal Side)

### Helpers (`src/hooks/useDataverse.ts`)

| Function | HTTP | Purpose |
|---|---|---|
| `dvQuery(entitySet, query)` | GET `/_api/{entitySet}?{query}` | Read records |
| `dvCreate(entitySet, data)` | POST `/_api/{entitySet}` | Create record, returns ID |
| `dvUpdate(entitySet, id, data)` | PATCH `/_api/{entitySet}({id})` | Update record |
| `fmt(record, column)` | — | Get formatted value annotation |

All mutating calls include `__RequestVerificationToken` from the DOM (injected via `/_layout/tokenhtml`).

### Auth (`src/hooks/useAuth.ts`)

Reads `window.__PORTAL_USER__` directly — no network calls. Returns `{ isAuthenticated, userName, userId }`.

---

## Table Inventory

| # | Schema Name | Entity Set | Primary Name | Notes |
|---|---|---|---|---|
| 1 | `dmv_dmvoffice` | `dmv_dmvoffices` | `dmv_officename` | Office locations |
| 2 | `dmv_driverlicense` | `dmv_driverlicenses` | `dmv_licensenumber` | → contact |
| 3 | `dmv_vehicle` | `dmv_vehicles` | `dmv_vin` | → contact (owner) |
| 4 | `dmv_vehicleregistration` | `dmv_vehicleregistrations` | `dmv_registrationid` | Lifecycle parent |
| 5 | `dmv_registrationterm` | `dmv_registrationterms` | `dmv_termnumber` | Period/term |
| 6 | `dmv_registrationpayment` | `dmv_registrationpayments` | `dmv_paymentref` | One per term |
| 7 | `dmv_appointment` | `dmv_appointments` | `dmv_appointmentnumber` | |
| 8 | `dmv_documentupload` | `dmv_documentuploads` | `dmv_documentname` | HasNotes=true |
| 9 | `dmv_vehicletitle` | `dmv_vehicletitles` | `dmv_titlenumber` | |
| 10 | `dmv_lien` | `dmv_liens` | `dmv_lienreference` | ELT |
| 11 | `dmv_temporarytag` | `dmv_temporarytags` | `dmv_tagnumber` | |
| 12 | `dmv_bulksubmission` | `dmv_bulksubmissions` | `dmv_batchid` | |
| 13 | `dmv_transactionlog` | `dmv_transactionlogs` | `dmv_transactionid` | |
| 14 | `dmv_notification` | `dmv_notifications` | `dmv_notificationref` | |

Plus native: `contact` (citizens), `account` (dealers).

---

## Registration Lifecycle (3-Table Model)

See [schema_vehicleregistration.md](schema_vehicleregistration.md) for full detail.

```
dmv_vehicleregistration  (parent — one per vehicle/owner)
  ├──► dmv_registrationterm  (one per period)
  │       └──► dmv_registrationpayment  (one per term)
  └── dmv_currenttermid ──► active term
```

### Picklist Values

**Registration Status** (`dmv_regstatus`): Active=100000000, Expired=100000001, Pending Payment=100000002, Pending Inspection=100000003, Suspended=100000004, Cancelled=100000005

**Term Type** (`dmv_termtype`): New=100000000, Renewal=100000001, Transfer=100000002

**Term Status** (`dmv_termstatus`): Active=100000000, Pending=100000001, Expired=100000002

**Payment Status** (`dmv_paymentstatus`): Unpaid=100000000, Paid=100000001, Refunded=100000002, Waived=100000003

**Payment Method** (`dmv_paymentmethod`): Credit Card=100000000, eCheck=100000001, Cash=100000002, Money Order=100000003

### How Expiration Dates Work

The portal reads `dmv_expirationdate` directly from `dmv_vehicleregistration`. This is a **denormalized** copy of `dmv_enddate` from the current term. It must be stamped whenever a new term is created or renewed.

The React code (`VehicleRegistration.tsx`) resolves expiration from two sources:
1. Web API: `dmv_expirationdate` on the registration record
2. Fallback: `expirationDate` from `window.__DMV_DATA__.registrations` (Liquid injection)

**Why not query `dmv_registrationterm` directly?** The portal Web API returns 403 for term records despite correct table permissions and site settings. Liquid FetchXML on the term table also returns 0 results. This is a known issue with newly created tables in Power Pages — permissions may not propagate. The workaround is to denormalize the expiration date onto the parent registration.

---

## Portal Permissions & Site Settings

### Table Permissions

Stored as `powerpagecomponent` records (type=18). Content is JSON:

```json
{
  "Append": true, "Write": true, "Create": true, "Delete": false,
  "Scope": 756150000, "AppendTo": true, "Read": true,
  "EntityLogicalName": "dmv_vehicle",
  "adx_entitypermission_webrole": ["c7500f9c-350c-471b-a6da-e16f0f18009c"]
}
```

- **Scope 756150000** = Global (all records)
- Web role association is embedded in `adx_entitypermission_webrole` array AND via M:N relationship `powerpagecomponent_powerpagecomponent`

### Web API Site Settings

Required for portal `/_api/` access. Stored as `mspp_sitesettings`:

```
Webapi/{entity_logical_name}/enabled = true
Webapi/{entity_logical_name}/fields = *
```

Must be scoped to the website (`_mspp_websiteid_value`).

### Key Gotcha

Table permissions for **newly created tables** (`dmv_registrationterm`, `dmv_registrationpayment`) may not work even when correctly configured. Both the Web API (403) and Liquid FetchXML (0 results) fail silently. The solution used here: denormalize critical data onto tables with working permissions.

---

## Page → Dataverse Interaction Map

| Page | Reads | Creates/Updates |
|---|---|---|
| MyDMV | `window.__DMV_DATA__` only | — |
| VehicleRegistration | `dmv_vehicles`, `dmv_vehicleregistrations` | vehicles, registrations, terms, payments |
| LicenseRenewal | — | `dmv_transactionlogs` ($45, type=License Renewal) |
| Appointments | `dmv_dmvoffices` | `dmv_appointments` |
| Documents | `dmv_documentuploads` | `dmv_documentuploads`, `dmv_transactionlogs` |
| DealerDashboard | `dmv_transactionlogs`, `dmv_vehicleregistrations`, `dmv_temporarytags`, `dmv_vehicletitles` | — |
| TempTags | active tags query | `dmv_vehicles`, `dmv_temporarytags` |
| ElectronicLienTitle | liens query | `dmv_vehicles`, `dmv_vehicletitles`, `dmv_liens` |
| BulkRegistration | submission history | `dmv_bulksubmissions` |
| Home, RealID, FAQ | — | — |

---

## React Router (12 Routes)

| Path | Component | Auth Required |
|---|---|---|
| `/` | Home | No |
| `/my-dmv` | MyDMV | Yes |
| `/license-renewal` | LicenseRenewal | Yes |
| `/vehicle-registration` | VehicleRegistration | Yes |
| `/real-id` | RealID | No |
| `/appointments` | Appointments | Yes |
| `/documents` | Documents | Yes |
| `/faq` | FAQ | No |
| `/dealer` | DealerDashboard | Yes |
| `/dealer/elt` | ElectronicLienTitle | Yes |
| `/dealer/bulk` | BulkRegistration | Yes |
| `/dealer/temp-tags` | TempTags | Yes |

All pages lazy-loaded. Layout: Header → main → Footer.

---

## Design System

- **Fonts**: IBM Plex Serif (headings), IBM Plex Sans (body), IBM Plex Mono (code/VINs)
- **Colors**: Primary `#1D3557`, Accent `#C42230`, Secondary `#457B9D`, Background `#F4F6FA`
- **Expiration warning color**: `#b45309` (dark amber, WCAG-compliant on white/gray)
- **Container**: max-width 1180px
- **CSS Variables**: `--color-primary`, `--color-accent`, `--color-secondary`, `--color-bg`, `--color-text`, `--color-text-muted`, `--color-success`, `--color-warning`, `--color-danger`

---

## Dataverse Scripts (`dataverse/`)

| Script | Purpose |
|---|---|
| `01_create_publisher_solution.ps1` | Creates `dmv` publisher + solution |
| `02_create_tables.ps1` | Creates initial tables |
| `02b_create_remaining_tables.ps1` | Creates remaining tables |
| `02c_fix_three_tables.ps1` | Fixes three tables |
| `03_add_all_columns.ps1` | Adds all columns and lookups |
| `04_fix_dmvoffice.ps1` | Fixes DMV Office table |
| `05_enable_webapi.ps1` | Enables portal Web API site settings |
| `05b_fix_permissions.ps1` | Fixes table permissions |
| `06_seed_maria_data.ps1` | Seeds Maria demo data |
| `07_migrate_to_native.ps1` | Migrates citizen→contact, dealer→account |
| `08_reseed_maria_native.ps1` | Re-patches Maria's Contact + child records |
| `09_create_model_driven_app.ps1` | Creates admin model-driven app |
| `10_create_contact_form_and_view.ps1` | DMV Citizen form + view |
| `11_update_views_forms_sitemap.ps1` | Updates all views, forms, sitemap |
| `12_fix_sitemap_png.ps1` | Fixes sitemap icons |
| `13_set_entity_icons.ps1` | Sets entity icons |
| `14_update_portal_permissions.ps1` | Adds Create+Write to table permissions |
| `15_refactor_registration.ps1` | Creates term + payment tables, seeds data |
| `16_update_mda_for_lifecycle.ps1` | Updates model-driven app for lifecycle |

All scripts use `az account get-access-token` and Dataverse REST API v9.2.

---

## Common Gotchas

1. **Liquid bracket notation crashes templates** — `r['alias.field']` kills the entire `<script>` block silently. Both `__PORTAL_USER__` and `__DMV_DATA__` become undefined.
2. **New table permissions may not work** — even when correctly created and associated with web role. Both Web API (403) and Liquid FetchXML (0 results) fail. Workaround: denormalize data.
3. **DateTime columns need `T00:00:00Z` suffix** when creating records via API.
4. **Antiforgery token** — no `Portal Web Api Antiforgery Token` Liquid tag in GCC. Use JS fetch to `/_layout/tokenhtml`.
5. **Permission content encoding** — PATCH requests to `powerpagecomponents` require UTF-8 byte encoding.
6. **Power Pages cache** — site setting changes can take minutes to propagate. Clear cookies + hard refresh when testing.
7. **`$PID` is reserved in PowerShell** — never use as a variable name in scripts.
8. **Option sets in Liquid** — return integers directly. `.Value` does NOT exist. `.Label` works.
9. **Always check PrimaryNameAttribute** before using `dmv_name` — each table has its own primary name column.
10. **Login loop after deploys** — clear portal cookies to fix. Rapid deploys can cause stale session state.
