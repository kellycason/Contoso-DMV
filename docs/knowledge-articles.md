# Contoso DMV — Knowledge Article Data Source

## What this is

FAQ + process-guide content for the citizen portal, stored as rows in the **native Dynamics 365 `knowledgearticle`** table so **humans** (portal users) and **AI agents** (Copilot Studio) read from the same source of truth.

- Table: `knowledgearticle` (out-of-the-box Dynamics 365 Customer Service entity)
- Entity set (Web API): `knowledgearticles`
- Seed file: [dataverse/knowledge_seed.json](../dataverse/knowledge_seed.json) (40 rows: 6 articles + 34 FAQs)
- Migration script: [dataverse/30_migrate_to_native_knowledge.ps1](../dataverse/30_migrate_to_native_knowledge.ps1) (idempotent — skips by `articlepublicnumber`)

> **Note:** An earlier version of this project used a custom table `dmv_knowledgearticle`. It was removed by [`dataverse/31_delete_custom_knowledge_table.ps1`](../dataverse/31_delete_custom_knowledge_table.ps1). The native table is now the single source of truth.

## Field mapping (seed → native)

| Seed field | Native column | Notes |
|---|---|---|
| `title` | `title` | Primary name |
| `summary` | `description` | Truncated to 250 chars |
| `body` (markdown) | `content` (HTML) | Converted by migration script (`##` → `<h3>`, `- ` → `<li>`, blank lines → `<p>`) |
| `slug` | `articlepublicnumber` | Stable public identifier |
| `type`, `category`, `order`, `readMinutes` | `keywords` | Encoded as `type=...;category=...;order=...;minutes=...` and parsed client-side |
| — | `languagelocaleid` | `en-US` (bound on create) |
| — | `isrootarticle` / `islatestversion` / `isprimary` | All `true` |
| — | `majorversionnumber` / `minorversionnumber` | `1.0` |
| — | `statecode=3, statuscode=7` | Published (set by migration script via PATCH) |

## Where it is consumed

### 1. Citizen portal (humans — anonymous and authenticated)

[src/pages/FAQ.tsx](../src/pages/FAQ.tsx) fetches via the **Power Pages Web API**:

```
GET /_api/knowledgearticles
    ?$select=knowledgearticleid,articlepublicnumber,title,description,content,keywords
    &$filter=statecode eq 3 and islatestversion eq true
```

Permissions (Global scope, read-only) are granted to both **Anonymous Users** and **Authenticated Users** web roles via the `Knowledge Article` table permission (powerpagecomponent type=18). Web API site settings:

- `Webapi/knowledgearticle/enabled = true`
- `Webapi/knowledgearticle/fields = *`

The `content` column is already HTML; the React page renders it with `dangerouslySetInnerHTML` and styles the result through the `.ka-body` CSS class in `src/styles/theme.css`.

### 2. Copilot Studio agent (AI)

Copilot Studio has **first-class support** for the native `knowledgearticle` table.

1. Open your agent in Copilot Studio.
2. **Knowledge** → **+ Add knowledge** → **Dynamics 365 knowledge base** (preferred) or **Dataverse** → select **Knowledge Article** table.
3. Pick the environment hosting this data (`orga381269e.crm9.dynamics.com`).
4. The agent reads only records where `statecode = Published` and `islatestversion = true`.
5. **Save**. Initial indexing takes a few minutes.

Add a **Search and summarize content** node in any topic and point it at this knowledge source. The agent returns grounded answers with citations.

## Keeping content fresh

Edit [`knowledge_seed.json`](../dataverse/knowledge_seed.json) and re-run:

```powershell
cd dataverse
.\30_migrate_to_native_knowledge.ps1
```

The script is idempotent — it **skips** articles whose `articlepublicnumber` already exists. To update an existing article, delete the row in Dataverse first (or unpublish → edit → republish in the Customer Service app) and re-run the script.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Portal FAQ shows "Could not load articles" | Open devtools → confirm `/_api/knowledgearticles` returns 200 JSON. If HTML auth page is returned, re-apply the table permission step in script 30. |
| Agent says "no results" | Confirm the agent's environment connection has access; re-index from the Knowledge pane; confirm articles are `Published` (`statecode=3`). |
| Anonymous users can't see articles | Confirm both `Anonymous Users` and `Authenticated Users` web roles are listed in the `adx_entitypermission_webrole` array on the `Knowledge Article` powerpagecomponent. |
