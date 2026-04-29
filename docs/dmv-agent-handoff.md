# Contoso DMV Agent — AI Handoff Brief

> Purpose: Self-contained reference for another AI model to help build/extend the
> **Contact Center DMV Agent** (Microsoft Copilot Studio) integrated with the
> Contoso DMV Power Pages portal via Omnichannel for Customer Service. Includes
> the deployed Dataverse schema, the demo flow outlines, and the runtime
> context-variable contract between the portal chat widget and the bot.

---

## 1. Environment & Identifiers

| Item | Value |
|---|---|
| Dataverse environment URL | `https://orga381269e.crm9.dynamics.com` |
| Web API root | `/api/data/v9.2` |
| Solution unique name | `DMVDigitalServicesPortal` |
| Publisher prefix | `dmv_` |
| Power Pages portal URL | `https://site-y5jzr.powerappsportals.us/` |
| Website ID | `461a50ae-9496-419e-a58b-14d56165b009` |
| Parent agent (bot) ID | `90a9ebcd-4342-f111-88b4-001dd801f94a` |
| Agent schema name | `crd60_agent` |
| Agent display name | **Contact Center DMV Agent** |
| Connection reference (Dataverse) | `dmv_sharedcommondataserviceforapps_2ca64` (id `b75177e8-ed3c-f111-88b3-001dd801f94a`) |
| Channel | Omnichannel for Customer Service (live chat surface) embedded in Power Pages |

**Architecture in one line:** React/Vite SPA on Power Pages → Omnichannel Chat
SDK widget → Copilot Studio bot → Dataverse / model-driven app for back-office.

---

## 2. Dataverse Schema (deployed `dmv_*` tables)

All tables use the `dmv_` prefix. Names below are `LogicalName` (entity set name
in parens). Lookup columns are listed with their target table.

### 2.1 Citizen / Identity
The citizen is the standard **`contact`** Dataverse table (extended with custom
fields). The `contactid` is the value passed to the bot as `PortalContactId`.
All `dmv_*` records that belong to a citizen carry a `dmv_contactid` lookup back
to `contact`.

### 2.2 Tables

#### `dmv_driverlicense` (`dmv_driverlicenses`) — Driver License
| Column | Type | Notes |
|---|---|---|
| `dmv_licensenumber` | String | Primary identifier |
| `dmv_contactid` | Lookup → contact | Owner |
| `dmv_licenseclass` | Picklist | Class A/B/C/M etc. |
| `dmv_licensestatus` | Picklist | Active / Expired / Suspended / Revoked |
| `dmv_issuedate`, `dmv_expirationdate` | DateTime | |
| `dmv_daystoexpiration` | Integer | Computed |
| `dmv_realidcompliant` | Boolean | |
| `dmv_realidstatus` | Picklist | REAL ID application status |
| `dmv_onlineeligible` | Boolean | Eligible for online renewal |
| `dmv_renewaleligibledate` | DateTime | |
| `dmv_renewalcount` | Integer | |
| `dmv_renewalmethod` | Picklist | Online / In-Person / Mail |
| `dmv_endorsements`, `dmv_restrictions` | Virtual multi-select | |
| `dmv_photourl` | String | License photo |

#### `dmv_licenserenewal` (`dmv_licenserenewals`) — License Renewal Request
| Column | Type | Notes |
|---|---|---|
| `dmv_renewalid` | String | Auto-number `RNW-YYYY-####` |
| `dmv_contactid` | Lookup → contact | |
| `dmv_licenseid` | Lookup → dmv_driverlicense | |
| `dmv_renewalstatus` | Picklist | Submitted / Under Review / Approved / Rejected |
| `dmv_channel` | Picklist | Portal=100000003 / Mail / In-Person / Phone |
| `dmv_submitteddate`, `dmv_approveddate`, `dmv_newexpirationdate` | DateTime | |
| `dmv_visionok`, `dmv_seizures`, `dmv_lossofconsciousness` | Boolean | Medical screening |
| `dmv_renewalfee` | Money | Default $40 |
| `dmv_paymentmethod`, `dmv_paymentconfirmation` | Picklist / String | |
| `dmv_firstname`, `dmv_lastname`, `dmv_dateofbirth`, `dmv_ssn4`, `dmv_email`, `dmv_phone`, `dmv_streetaddress`, `dmv_city`, `dmv_state`, `dmv_zipcode` | Various | Snapshot of citizen at submission |

#### `dmv_vehicle` (`dmv_vehicles`) — Vehicle
| Column | Type | Notes |
|---|---|---|
| `dmv_vin` | String | Primary identifier |
| `dmv_make`, `dmv_model`, `dmv_year`, `dmv_trim`, `dmv_color` | String | `dmv_year` is **String** (not Integer — locale grouping) |
| `dmv_bodystyle`, `dmv_fueltype`, `dmv_weightclass`, `dmv_platetype` | Picklist | |
| `dmv_platenumber`, `dmv_platestate` | String | |
| `dmv_ownercontactid` | Lookup → contact | Citizen owner |
| `dmv_owneraccountid` | Lookup → account | Dealer owner (alt) |
| `dmv_insurancecarrier`, `dmv_insurancepolicy`, `dmv_insuranceexp`, `dmv_insurancestatus` | Various | |
| `dmv_odometer`, `dmv_msrp`, `dmv_outofstate`, `dmv_salvagetitle` | Various | |

#### `dmv_vehicleregistration` (`dmv_vehicleregistrations`) — Vehicle Registration
Permanent record per vehicle/owner pair. Renewal stacks **terms** under it.
| Column | Type | Notes |
|---|---|---|
| `dmv_registrationid` | String | Auto-number `REG-YYYY-#####` |
| `dmv_vehicleid` | Lookup → dmv_vehicle | |
| `dmv_regcontactid` / `dmv_dealeracctid` | Lookup | Citizen or dealer registrant |
| `dmv_regstatus` | Picklist | Active / Expired / Pending / Rejected |
| `dmv_regtype` | Picklist | New / Renewal / Transfer |
| `dmv_currenttermid` | Lookup → dmv_registrationterm | Points to active term |
| `dmv_effectivedate`, `dmv_expirationdate`, `dmv_renewaleligible` | DateTime | Denormalized from current term — portal reads from here |
| `dmv_daystoexpiration` | Integer | |
| `dmv_onlineeligible` | Boolean | |
| `dmv_fee`, `dmv_latefee`, `dmv_totaldue` | Money | |
| `dmv_paymentstatus`, `dmv_paymentmethod`, `dmv_paymenttransactionid` | Various | |
| `dmv_submissionchannel`, `dmv_county`, `dmv_regyear` | Various | |

#### `dmv_registrationterm` (`dmv_registrationterms`) — Registration Term (history)
One per registration period. Renewing creates a new term; old term becomes Expired.
| Column | Type | Notes |
|---|---|---|
| `dmv_termnumber` | String | `TERM-YYYY-#####` |
| `dmv_vehicleregistrationid` | Lookup → dmv_vehicleregistration | Parent |
| `dmv_termtype` | Picklist | New / Renewal |
| `dmv_termstatus` | Picklist | Pending / Active / Expired |
| `dmv_startdate`, `dmv_enddate`, `dmv_issuedate` | DateTime | |

#### `dmv_registrationpayment` (`dmv_registrationpayments`) — Registration Payment
| Column | Type | Notes |
|---|---|---|
| `dmv_paymentref` | String | `PAY-YYYY-#####` |
| `dmv_registrationtermid` | Lookup → dmv_registrationterm | |
| `dmv_renewalid` | Lookup → dmv_registrationrenewal | (optional) |
| `dmv_amount`, `dmv_latefee`, `dmv_total` | Money | |
| `dmv_paymentstatus` | Picklist | Unpaid / Paid / Refunded |
| `dmv_paymentmethod`, `dmv_paymentdate`, `dmv_transactionid` | Various | |

#### `dmv_registrationrenewal` (`dmv_registrationrenewals`) — Registration Renewal Request
Submitted via portal/chat; staff approves to materialize a new term.
| Column | Type | Notes |
|---|---|---|
| `dmv_renewalid` | String | `RREN-YYYY-####` (auto-number) |
| `dmv_confirmationnumber` | String | |
| `dmv_contactid` | Lookup → contact | |
| `dmv_registrationid` | Lookup → dmv_vehicleregistration | |
| `dmv_vehicleid` | Lookup → dmv_vehicle | |
| `dmv_renewalstatus` | Picklist | `100000000` Submitted / `100000001` Under Review / `100000002` Approved / `100000003` Rejected |
| `dmv_channel` | Picklist | `100000003` = Portal |
| `dmv_renewalfee` | Money | Default **$50** |
| `dmv_submitteddate`, `dmv_approveddate`, `dmv_newexpirationdate` | DateTime | |
| `dmv_insurancecarrier`, `dmv_insurancepolicy`, `dmv_insuranceexpiration` | Various | |
| `dmv_vehiclemake`, `dmv_vehiclemodel`, `dmv_vehicleyear`, `dmv_vehiclecolor`, `dmv_vin`, `dmv_platenumber` | String | Snapshot |
| `dmv_email`, `dmv_phone`, address fields | Various | Citizen snapshot |

#### `dmv_vehicletitle` (`dmv_vehicletitles`) — Vehicle Title
Linked to vehicle; carries `dmv_eltenabled`, `dmv_coownername`, etc.

#### `dmv_lien` (`dmv_liens`) — Lien on a Title
| Column | Type | Notes |
|---|---|---|
| `dmv_lienreference` | String | `LIEN-YYYY-####` |
| `dmv_titleid` / `dmv_vehicleid` | Lookup | |
| `dmv_lienstatus` | Picklist | Active / Released |
| `dmv_lienholdername`, `dmv_eltid`, `dmv_loanamount`, `dmv_loanterm`, `dmv_loanmaturity`, `dmv_releasedate`, `dmv_releasemethod` | Various | |

#### `dmv_temporarytag` (`dmv_temporarytags`) — Dealer Temp Tag
| Column | Type | Notes |
|---|---|---|
| `dmv_tagnumber` | String | `TT-YYYY-####` |
| `dmv_dealeracctid` / `dmv_buyercontactid` | Lookup | |
| `dmv_vehicleid` | Lookup → dmv_vehicle | |
| `dmv_tagstatus` | Picklist | Active / Voided / Expired |
| `dmv_issuedate`, `dmv_expirationdate` | DateTime | 30-day default |
| `dmv_saleprice`, `dmv_tagpdfurl`, `dmv_printcount`, `dmv_voidedreason` | Various | |

#### `dmv_appointment` (`dmv_appointments`) — DMV Office Appointment
| Column | Type | Notes |
|---|---|---|
| `dmv_appointmentnumber` | String | `APT-YYYY-####` |
| `dmv_contactid` / `dmv_officeid` | Lookup | |
| `dmv_appointmentdate`, `dmv_appointmenttime`, `dmv_duration` | Date/Time/Int | |
| `dmv_servicetype` | Picklist | License / Renewal / REAL ID / Registration / Title |
| `dmv_status` | Picklist | Scheduled / Confirmed / Checked-In / Completed / Cancelled / No-Show |
| `dmv_relatedlicenseid`, `dmv_relatedregid` | Lookup | Optional links |
| `dmv_checkintime`, `dmv_completiontime`, `dmv_cancelreason`, `dmv_notes` | Various | |

#### `dmv_dmvoffice` (`dmv_dmvoffices`) — DMV Office (location master)
`dmv_officecode`, `dmv_officename`, address, `dmv_latitude`/`dmv_longitude`,
`dmv_hours`, `dmv_phone`, `dmv_currentwait`, `dmv_maxappointments`,
`dmv_schedulingenabled`, `dmv_active`, `dmv_services` (multi-select).

#### `dmv_documentupload` (`dmv_documentuploads`) — Citizen/Dealer Document
`dmv_documentname`, `dmv_documenttype`, `dmv_fileurl`, `dmv_filetype`,
`dmv_filesize`, `dmv_uploaddate`, `dmv_expirationdate`, `dmv_verificationstatus`,
`dmv_verifieddate`, `dmv_rejectionreason`, `dmv_aiconfidence`,
`dmv_aiextracteddata`, links to contact / dealer / license / registration / title.

#### `dmv_notification` (`dmv_notifications`) — Outbound Notification log
`dmv_notificationref`, `dmv_notificationtype`, `dmv_channel` (Email/SMS/Push),
`dmv_subject`, `dmv_previewtext`, `dmv_templatename`, `dmv_deliverystatus`,
`dmv_sentdate`, `dmv_retrycount`, recipient lookups, related-record lookups
(license/registration/appointment) + `dmv_relatedrecordtype`.

#### `dmv_transactionlog` (`dmv_transactionlogs`) — Transaction Log
Cross-cutting log table. `dmv_transactionid`, `dmv_transactiontype`,
`dmv_transactiondate`, `dmv_status`, `dmv_amount`, `dmv_paymentref`,
`dmv_channel`, `dmv_initiatedby` (User), plus contact/dealer + related entity
lookups (license/registration/title/vehicle).

#### `dmv_bulksubmission` (`dmv_bulksubmissions`) — Dealer Bulk Submission
`dmv_batchid`, `dmv_dealeracctid`, `dmv_submitteddate`, `dmv_fileurl`,
`dmv_totalrecords`, `dmv_processedrecords`, `dmv_failedrecords`, `dmv_totalfees`,
`dmv_batchstatus`, `dmv_paymentstatus`, `dmv_errorlogurl`.

### 2.3 Picklist Quick Reference (renewal-relevant)
- **`dmv_channel`**: `100000000` Mail · `100000001` In-Person · `100000002` Phone · `100000003` Portal
- **`dmv_renewalstatus`**: `100000000` Submitted · `100000001` Under Review · `100000002` Approved · `100000003` Rejected
- **`dmv_termstatus`**: `100000000` Pending · `100000001` Active · `100000002` Expired
- **`dmv_termtype`**: `100000000` New · `100000001` Renewal · `100000002` Transfer
- **`dmv_paymentstatus`** (registration term/payment): `100000000` Unpaid · `100000001` Paid · `100000002` Refunded

### 2.4 Relationship Map (renewal-centric)
```
contact ──< dmv_driverlicense ──< dmv_licenserenewal
        ──< dmv_vehicleregistration ──< dmv_registrationterm ──< dmv_registrationpayment
                                  └──< dmv_registrationrenewal
        ──< dmv_appointment >── dmv_dmvoffice
        ──< dmv_documentupload
        ──< dmv_notification
dmv_vehicle ──< dmv_vehicleregistration / dmv_vehicletitle ──< dmv_lien / dmv_temporarytag
```

---

## 3. Demo Flow Outlines

Two flagship demo scripts are wired end-to-end. Both can be initiated either via
the portal SPA **or** by talking to the bot in the Omnichannel chat widget — the
bot redirects the citizen to the matching SPA route.

### 3.1 Driver License Renewal

**Demo persona:** *Maria Jennings* (contact id `d2c23913-f238-f111-88b3-001dd801f94a`).

| Act | Actor | Steps | System effect |
|---|---|---|---|
| 1 | Citizen (portal) | Sign in → `/license-renewal` wizard → 1) identity 2) current details 3) **medical screen** (3 yes/no — fail = block + appointment CTA) 4) payment ($40) 5) confirmation (`RNW-YYYY-####`, status **Submitted**) | Creates `dmv_licenserenewal` row (channel=Portal, status=Submitted) |
| 2 | DMV staff (MDA) | Open `License Renewals` view → record → set `dmv_renewalstatus = Approved` | Form automation fills `dmv_approveddate = today`, `dmv_newexpirationdate = today + 10 years`. Power Automate flow `DMV - License Renewal Approved Email` (workflow id `9818b5e4-ed3c-f111-88b4-001dd80340cd`) sends approval email. |
| 3 | Citizen (portal) | Click email link → `/documents` → **My Temporary Licenses** → download PDF | PDF generated client-side from contact + license + renewal data |

**Bot involvement:** Topic *License Renewal* (intent: "renew my license") greets,
checks `Global.PortalContactId`, confirms intent, redirects to
`/license-renewal`. Bot does **not** create the row directly — the SPA does.

### 3.2 Vehicle Registration Renewal

**Demo persona:** *Maria Jennings*, vehicle `26def455-1d39-f111-88b4-001dd80340cd`
(2024 Tesla Model S, plate XYZ-5678), registration `b3d6565a-1d39-f111-88b3-001dd801f94a` (REG-2025-00891, expires 2026-06-10).

| Act | Actor | Steps | System effect |
|---|---|---|---|
| 1 | Citizen (portal) | Sign in → `/vehicle-registration` → Tesla row shows **Expires Jun 10, 2026** (amber) → click **Renew** → confirm $50 fee → **Submit** | 4 Web API calls: (a) create new `dmv_registrationterm` (Renewal, Pending, today → today+1y); (b) create `dmv_registrationpayment` ($50, Unpaid, linked to new term); (c) update old term → Expired; (d) update `dmv_vehicleregistration.dmv_currenttermid` → new term, status Active |
| 2 | DMV staff (MDA) | Open registration → review new term → open payment → set Method=Credit Card, Date=today, Status=**Paid** → save → on term: Status=**Active**, optionally fill Sticker number → on registration: update `dmv_expirationdate` to new term end date | Term activated, payment captured. (In production, a flow would automate the expiration-date stamp.) |
| 3 | Citizen (portal) | Refreshes `/vehicle-registration` — Tesla now shows **Expires Apr 16, 2027** (green) | Portal reads `dmv_expirationdate` directly |

**Key invariant:** the registration record is **permanent**. Renewal stacks a
new term; the old term is preserved as audit trail. `dmv_currenttermid` always
points at the latest active term.

**Bot involvement:** Topic *Registration Renewal Actions* (parent-owned, topic
id `7726d1ef-1143-f111-88b4-001dd801f94a`). Triggers: `renew my registration`,
`renew my vehicle registration`, `renew my tags`, `renew my Tesla`,
`start my renewal`, `submit my registration renewal`. Currently structured as:
1) check `Global.PortalContactId` is present (else: ask user to sign in),
2) confirm with Yes/No, 3) on Yes, send the citizen to
`https://site-y5jzr.powerappsportals.us/vehicle-registration` where the SPA
performs the actual writes. We tried inline `InvokeConnectorAction` for
`CreateRecord` against `dmv_registrationrenewals`, but the Studio designer fails
to hydrate hand-authored Dataverse cards reliably; SPA-redirect is the
supported authoring path for now.

### 3.3 Other deployed demo paths (one-liners)

- **REAL ID upgrade** (`/real-id`) — citizen uploads 4 docs → `dmv_documentupload` rows + license `dmv_realidstatus` = "In Review"
- **Appointments** (`/appointments`) — pick office/service/date → `dmv_appointment`; flows `DMV - Appointment Confirmation/Reschedule/Cancellation` (built in `dataverse/56–58_*.ps1`) email the citizen
- **Dealer temp tags** (`/dealer/temp-tags`) — dealer issues `dmv_temporarytag`; flow `DMV - Generate Temp Tag PDF` writes the PDF URL
- **Dealer new registration / bulk** — dealer-side counterparts of citizen registration

---

## 4. Copilot Studio Agent Anatomy

### 4.1 Orchestration mode
**Generative.** The agent uses GPT-routed topics with `modelDescription` per
topic. Topics still have `triggerQueries` as fallback patterns.

### 4.2 Currently published topics (parent agent)
- **Conversation Start** — greeting, optionally personalized using `Global.ContactName`.
- **Fallback / Unknown Intent** — defers to `SearchAndSummarizeContent` against the website knowledge source (Contoso DMV knowledge articles).
- **License Renewal** — redirect to `/license-renewal`.
- **Registration Renewal Actions** — confirm + redirect to `/vehicle-registration`.
- **Appointments** — book/reschedule/cancel via `/appointments`.
- **REAL ID** — explain + redirect to `/real-id`.
- **Knowledge / FAQ** — generative answer over the website KS (`docs/knowledge-articles.md` contents are seeded into Dataverse Knowledge Articles).

### 4.3 Knowledge Sources
- **Public Website KS** scoped to the portal URL.
- **Native Dataverse `knowledgearticle` records** seeded from `docs/knowledge-articles.md` (script `dataverse/30_migrate_to_native_knowledge.ps1`).

### 4.4 Connection References
- `dmv_sharedcommondataserviceforapps_2ca64` — shared Microsoft Dataverse maker connection (used by power automate flows below). Inline `InvokeConnectorAction` cards in Studio are **not** the recommended call shape in this bot — use a Power Automate flow + `kind: InvokeFlowAction`, or redirect to the SPA.

### 4.5 Power Automate flows in scope
| Flow name | workflowid | Trigger | Action |
|---|---|---|---|
| `DMV - License Renewal Approved Email` | `9818b5e4-ed3c-f111-88b4-001dd80340cd` | Update of `dmv_licenserenewal` where `dmv_renewalstatus = Approved` | Send templated email |
| `DMV - Approve Registration Renewal` | `9f8e7d6c-5b4a-4321-9876-abcdef012345` | Update of `dmv_registrationrenewal` to Approved | Materialize new term + email |
| Appointment confirmation / reschedule / cancellation | (see `dataverse/56-58_*.ps1`) | Create/update of `dmv_appointment` | Email citizen |
| Temp Tag PDF generation | (see `dataverse/35–37_*.ps1`) | Create of `dmv_temporarytag` | Write PDF to `dmv_tagpdfurl` |

---

## 5. Context Variable Contract (Omnichannel ↔ Bot)

The portal SPA initializes Omnichannel chat with `customContext` (a dictionary
of `{ value, isDisplayable }` pairs). Each key maps **1:1** to a Copilot Studio
**Global Variable** with `isExternalInitializationAllowed: true`. This is the
*only* sanctioned mechanism for the bot to know who the user is — the bot must
not attempt to derive identity from `System.User.*` because Omnichannel chat is
unauthenticated at the channel layer.

### 5.1 SPA → bot keys

Source: [src/components/ChatWidget.tsx](src/components/ChatWidget.tsx#L60-L75)

| Key | Type | Set when signed in | Set when anonymous | `isDisplayable` |
|---|---|---|---|---|
| `ContactName` | string | `window.__PORTAL_USER__.name` | `"not signed in"` | `true` |
| `PortalContactId` | string (GUID) | `window.__PORTAL_USER__.id` (Dataverse `contactid`) | `"not signed in"` | `false` |
| `Email` | string | `window.__DMV_DATA__.citizen.email` | `"not signed in"` | `true` |
| `Phone` | string | `window.__DMV_DATA__.citizen.phone` | *(omitted)* | `false` |

`isDisplayable: true` lets Omnichannel show the value to a human agent in the
UCI chat panel; `false` keeps it bot-only.

### 5.2 Global variables in the bot

Source: queried from `botcomponents` componenttype=12 on bot
`90a9ebcd-4342-f111-88b4-001dd801f94a`.

| Name | scope | `isExternalInitializationAllowed` | `aIVisibility` | `isOutputToExternalCallers` |
|---|---|---|---|---|
| `ContactName` | User | true | `UseInAIContext` | true |
| `PortalContactId` | User | true | `UseInAIContext` | true |
| `Email` | User | true | `UseInAIContext` | true |
| `TestVar` | User | true | *(default — Hidden)* | true |

`UseInAIContext` means the orchestrator may read these values when generating
responses — i.e., the bot can naturally reference Maria's name/email without
explicit `SetVariable`.

### 5.3 Authoring rules for using these variables in topics

1. **Identity gate** — top of every "do something for me" topic:
   ```yaml
   - kind: ConditionGroup
     id: cg_signedIn
     conditions:
       - id: ci_notSignedIn
         condition: =IsBlank(Global.PortalContactId) || Lower(Global.PortalContactId) = "unknown" || Lower(Global.PortalContactId) = "not signed in"
         actions:
           - kind: SendActivity
             id: sa_signInPrompt
             activity: |-
               To do that I need you signed in. Please sign in at the portal and try again.
           - kind: EndDialog
             id: ed_notSignedIn
   ```
2. **Lookup binding** for any Dataverse write on behalf of the citizen:
   `item/dmv_contactid@odata.bind: ="contacts(" & Global.PortalContactId & ")"`.
3. **Never** set these globals manually with `SetVariable` in normal topics —
   they are externally provisioned. Use `Topic.*` for anything topic-local.
4. **Power Fx pitfalls observed** in this bot (do not reintroduce):
   - No row-scoped projections inside `Concat(rows.value, ...)` — produces
     `PowerFxError` at publish.
   - No `First(rows.value).field` / `CountRows(rows.value)`.
   - No `Text(DateTimeValue(...))` formatting tricks.
   - Inline `InvokeConnectorAction` Dataverse `CreateRecord` cards do not
     hydrate in the designer reliably even with full `dynamicInputSchema` /
     `dynamicOutputSchema` / `connectionProperties.name` — prefer
     `InvokeFlowAction` against a Power Automate flow, or redirect to the SPA.

### 5.4 Recommended additional context (not yet wired)

If you extend the SPA, these are obvious next slots that match data already on
the contact and would unlock more in-chat actions without round-tripping the
SPA:

| Proposed key | Source | Why |
|---|---|---|
| `LicenseNumber` | `__DMV_DATA__.license.licenseNumber` | Allow the bot to answer "when does my license expire" without a Dataverse lookup. |
| `LicenseExpiration` | `__DMV_DATA__.license.expirationDate` | Same. |
| `LicenseDaysToExpiration` | computed | Lets the bot proactively offer renewal. |
| `PreferredOfficeId` | nearest `dmv_dmvoffice` | For appointment booking. |
| `LocaleCountry` / `LocaleLanguage` | M365 / browser | JIT user-context skill (see `agent-customization` best practices). |

All proposed keys should be added as Global Variables with
`isExternalInitializationAllowed: true` and `aIVisibility: UseInAIContext`.

---

## 6. Build/deploy mechanics (for the AI to know what scripts already exist)

Numbered PowerShell scripts under [dataverse/](dataverse/) deploy schema, data,
flows, knowledge, and bot components. Highest-numbered script is most recent.
The bot itself is authored as `botcomponent` rows (`componenttype` 9=topic,
12=global var, 15=GPT settings, 16=knowledge source) and published with
`PublishAllXml`. The SPA is built with Vite and uploaded to Power Pages
`powerpagecomponent` `filecontent` (see playbook in user memory).

---

## 7. Open issues / things to know before extending

1. **Connector card hydration in Studio.** Hand-authored `InvokeConnectorAction`
   for Dataverse `CreateRecord` against `dmv_registrationrenewals` produced an
   endless designer spinner even with `connectionProperties.name`,
   `dynamicInputSchema`, and `dynamicOutputSchema` populated. The current
   Registration Renewal topic therefore avoids in-bot creates and redirects to
   `/vehicle-registration`. If you need a true in-chat submission, build a
   Power Automate cloud flow with a Copilot-trigger and call it via
   `kind: InvokeFlowAction` — that path renders correctly.
2. **Maker vs Invoker connections.** All current Dataverse references use
   `mode: Maker` against `dmv_sharedcommondataserviceforapps_2ca64`. If you
   author actions that must respect citizen permissions, switch to `Invoker`
   and ensure portal-table-permissions on `mspp_entitypermission` are scoped
   `Contact` (`756150001`) and granted to the *Authenticated Users* web role.
3. **SPA cache.** Any deploy of new SPA bundles takes 5–15 min for the Power
   Pages CDN to serve. Filenames are pinned in `vite.config.ts` —
   `index-CcBGzUdW.js` / `index-BksZUihr.css` — do not change them.
4. **Auto-numbers.** Several `dmv_*id` columns use Dataverse AutoNumber. Do
   **not** send a value for them on create; let Dataverse generate it and
   re-fetch the record by GUID to display the ref.
5. **Liquid in Power Pages.** Option-set `.Label` access in Liquid can silently
   crash an entire `<script>` block; quote everything and keep one risky
   expression per block while debugging.

---

## 8. Maria Jennings demo data (canonical)

| Record | ID |
|---|---|
| Contact (Maria Jennings) | `d2c23913-f238-f111-88b3-001dd801f94a` |
| Driver License | (current) — query by `dmv_contactid` |
| Vehicle (2024 Tesla Model S, plate XYZ-5678) | `26def455-1d39-f111-88b4-001dd80340cd` |
| Vehicle Registration (REG-2025-00891) | `b3d6565a-1d39-f111-88b3-001dd801f94a` |
| Original Term (Expires 2026-06-10) | `515dd7aa-cb39-f111-88b3-001dd801f94a` |

Use these IDs to seed test conversations and to verify that
`Global.PortalContactId == d2c23913-f238-f111-88b3-001dd801f94a` is being
honored by any new topic you build.
